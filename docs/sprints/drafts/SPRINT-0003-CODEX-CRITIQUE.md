# Sprint 0003 — Codex critique of Claude and Gemini drafts

Reviewed 2026-09-15 against `SPRINT-0003-INTENT.md` and the current source. **Use Claude's draft as the basis for the merged plan, with architectural corrections before freezing v3.** Gemini offers a readable outline and an explicit default-offer identifier, but leaves required security behavior undecided and changes the requested done-page scope.

This is a source review, not implementation or runtime proof. I used targeted `rg` searches and file reads under `repos/online-join-ui/src` and `repos/online-join-bff/src`; I did not scan `repos/mico`. I also checked the local v4 prototype and change-request rows where scope was disputed. Branch/PR status, dependency versions, coverage results, live publisher availability and email-client compatibility were not independently verified. References below use `UI/` and `BFF/` for those two source roots; line numbers refer to the reviewed source.

## Code findings that affect both plans

| Finding | Evidence and implication |
|---|---|
| Offer selection must precede order creation. | `BFF/services/shortTermPass/identify.ts:189–218` creates the order after directory resolution for both recognized and new visitors. `BFF/routes/shortTermPass/schemas.ts:74–83` has no `OrderRequest.offerId`. Both drafts correctly propose a pre-order selection endpoint. |
| Changing the order shell alone will leave consents wrong. | `BFF/services/shortTermPass/order.ts:36–56,83–90` always selects the first catalog offer; `BFF/routes/shortTermPass/checkouts.ts:60–63` independently takes the first offer; `BFF/services/shortTermPass/purchaseOrchestrator.ts:150` re-renders consent at purchase validation. Thread the effective offer through every path. Claude identifies this correctly, although `buildCheckoutResponse` directly reads the catalog rather than calling `requireOffer`. |
| Attestation comparison does not detect a consistently wrong offer renderer. | The consent set is re-rendered at validation using that same first-offer helper. If both browser and validation receive the wrong set, matching hashes can still pass. Claude's R1 claim that the attestation would also refuse the mismatch is insufficient; tests must assert the actual chosen label, amount and validity as well as hash agreement. |
| The existing purchase record is insufficient for a standalone receipt. | `BFF/services/shortTermPass/ports/purchaseStore.ts:58–82` stores results, internals and consent evidence, but no purchased item/amount/currency snapshot. `PurchaseResult` (`schemas.ts:308–323`) has payment metadata, first name, receipt number and QR, but no amount or offer name. Both plans need an immutable purchase/receipt snapshot independent of the checkout and mutable catalog. First name can come from `result.person.firstName` (`purchaseOrchestrator.ts:426–431`). |
| The delivery port and publisher require coordinated changes. | `BFF/services/shortTermPass/ports/delivery.ts:5–13` lacks QR, amount, offer label and club mail context. `adapters/smtp/mailer.ts:25–41` hard-codes one day and includes a receipt number, but not a full receipt. `adapters/publisher/emailPublisher.ts`, `deliver` and `buildEngineRequest`, send HTML/text without an attachment field and pass an undefined club, producing the default billing code. Claude correctly catches this. This proves a limitation of the current adapter contract, not the upstream service's entire capability. |
| Routing must change in `App.tsx`. | `UI/App.tsx:12–21` captures the `/pass` subtree before `SignupShell`; `ShortTermPassPage.tsx:144–160` requires the club query parameter and flag hint. A route added only inside `SignupShell` cannot work. Claude names the correct interception point; Gemini's architecture recognizes the problem but its implementation file list does not. |
| Token resolution and long-lived recovery are new capabilities. | `PurchaseStorePort` has no token/pass-ID lookup. Checkout lifetime is 30 minutes idle / two hours absolute (`BFF/services/shortTermPass/ports/checkoutStore.ts`, lifetime constants and `isCheckoutExpired`). `routes/shortTermPass/purchase.ts:34–39` returns the stored result on replay. A pass link lasting days cannot depend on checkout state, and resend needs an explicit recovery policy. |
| Small UI and fixture claims are correct. | Both mobile steps already have `inputMode="tel"` and `autoComplete="tel"`; their helper strings remain. `BFF/services/shortTermPass/fixtures/directory.ts:73–80` still calls the Core visitor Jordan. Catalog fixtures currently contain one-day offers. `UI/routes/ShortTermPass/components/PassBlock.tsx` renders the QR and truthful delivery variants; `OrderSummary.tsx` renders the receipt. |

## Claude draft

### Architectural soundness

The strongest architecture of the two: it preserves ports/adapters, selects the offer before verification, follows it through consent generation, handles routing precedence, and makes a concrete SMTP/publisher image choice. Opaque random tokens with hashed lookup are compatible with the existing session helper (`BFF/services/shortTermPass/session.ts:11`) and permit individual revocation. Deferring real QR rotation and durable infrastructure is appropriate for the local mock scope.

The following need correction before contract freeze:

1. **Persist the data needed by the public page and resend.** B5 says `PassView` is built from the purchase record and club, but that record cannot supply the proposed receipt amount, currency or offer name. Adding `passView` token metadata and `pass.label/validUntil` does not fill that gap. Persist the purchased item, amount/currency, dates, seller details needed for historical receipts, and sanitized payment metadata. Both initial delivery and resend should consume that same snapshot. Test after checkout expiry and after a catalog price/name change.
2. **Specify atomic offer selection versus verification.** The draft permits selection in `verified` and deliberately does not increment generation. Directory resolution currently awaits external work, then creates and stores an order (`identify.ts:166–218`). A concurrent selection can therefore acknowledge a new offer while resolution commits an order based on an older checkout snapshot. UI `busy` does not protect multiple tabs. Check state and selection revision atomically at commit, or retry resolution on conflict; carry generation on the new mutating routes. Test selection racing with verify/retry-lookup and identity reset.
3. **Define rotation, resend and response-loss semantics.** B6 revokes the existing hash before sending the replacement. A failed delivery invalidates the old email link; concurrent resends can deliver an already-revoked link. Losing the creating 201 response also loses the only browser copy of `viewPath`, since replay returns stored results. Define serialization/idempotency and a failure policy, and distinguish deliberate revocation from ordinary resend. Test a lost response, delivery failure, simultaneous resend requests and refresh. A UI toast must follow the returned delivery status; the unconditional “Pass email sent” wording in the draft is wrong on failure.
4. **Do not claim restart recovery through `pass-link`.** R5 proposes re-minting after an in-memory restart, but both purchase and checkout stores lose their records (`adapters/mock/purchaseStore.ts` explicitly documents this). There is then no purchase to recover. Record this as a local-demo limitation. Separately define how, or whether, a buyer discovers and resends an existing purchase after checkout expiry: `loadOwnedPurchase(..., true)` supports an already-known purchase ID for a verified member, not purchase discovery.
5. **Turn token confidentiality into concrete middleware work.** `no-store` and excluding tokens from `result` are good, but do not establish “never in logs.” `BFF/services/application.ts:19` installs a general logger, and `utils/middlewares/historyFallback.ts:10–14` forwards debug messages from history fallback. Audit/redact token paths there and in deployed access logs, and specify `Referrer-Policy: no-referrer` for the token HTML page and image/API surfaces. The current source does not establish what the external logger records; this is an unresolved verification task, not a confirmed leak. The hooks outbox is also an explicit exception to the claimed “exactly three ways” raw tokens leave the BFF.

### Completeness

Coverage of CR-10–17, PR-05/06, provisional prices, refund-copy preservation, Riverside regression, fixture corrections and carried blockers is strong. Keep the precise delivery input, publisher billing fix, code-entry offer cards, standalone page states and local proof vocabulary.

Remaining gaps:

- CR-13 explicitly asks for the link on the receipt as well as the done page and email. The draft specifies receipt validity and a pass-block link, but not a receipt link. Name the placement and acceptance test, or record an intentional scope decision.
- Distinguish pass validity from link lifetime. A grace-period link may display an expired pass, but its QR must not imply current admission. Define the expired/upcoming presentation, exact club-local expiry instant and enforcement boundary. Revoking a link cannot invalidate a PNG already attached to an email; the mock QR is not proof of desk enforcement.
- The proposed `PassView` contains no server-provided “today,” whereas existing UI formatting explicitly uses BFF club-local `minVisitDate` (`UI/routes/ShortTermPass/format.ts:24–29`). Supply a date anchor or use absolute dates on the public page; do not silently switch to browser-local today.
- “No PII beyond first name and masked contact” conflicts with exposing payment brand/last4 in the bearer-accessible `PassView.receipt`. Resolve the allowed field set explicitly before pinning the leak test; email receipt requirements do not automatically authorize the same public response.
- The current change-request document already contains the offer-field and FR-P22/P23 corrections. Treat those as checked context rather than outstanding mandatory edits. Claude also attributes the Riverside expansion note to the intent, although the intent explicitly preserves Riverside's single-offer behavior.

### Phasing and ordering

Contract-first, then UI/BFF work and proof, is sensible. The stated dependencies need tightening:

- A2's exit requires both applications to type-check after replacing `offer` with `offers[]`, while caller migration is deferred to B1/C1. Freeze the contract separately, then include minimal consumer migration before requiring both builds to pass.
- The advertised first vertical slice omits B3, although B3 is what propagates validity into issuance/results. Include B3 if the milestone promises a completed purchase with range-bearing pass data.
- B4 needs the token supplied by B5. Establish snapshot and token lifecycle first, then integrate email; avoid two independently evolving purchase-orchestrator changes.
- D2's screenshots depend on implemented email and page surfaces. Split early parity inventory work from later design evidence.

### Risk coverage

Substantially stronger than Gemini: it covers delivery failure, gated routes, state loss, provisional pricing, scope and live-proof limitations. Add the snapshot, race, resend and logging risks above, plus date boundary tests (month/year/leap-day, DST and differing browser/club zones). Retain the current explicit rejection of invalid dates (`order.ts:177–181`); B2's unexplained “clamp” must not silently accept a different requested date. A limit on start date is also distinct from a limit on the final valid day.

### Feasibility

Feasible as a local mock sprint after those decisions. The estimate is optimistic for two new public routes, a new page, token lifecycle, resend, two email modes and broad regression proof. Its own subtotals sum to roughly **14 engineering days**, not 13 (1.5 + 5 + 4.5 + 1 + 2), and parallel elapsed time depends on named staffing. Re-estimate after snapshot and concurrency work, and identify the critical path. Do not let provisional local defaults imply production readiness.

### Definition of done

V0–V9 is useful, reviewable and mostly faithful to the intent. Keep it, adding explicit tests for the architectural gaps. Tighten these checks:

- Require an independent QR decode of the actual attachment. B4's alternative of re-encoding equality is not evidence that the delivered image is decodable.
- Prove the page works with no checkout cookie, then again after checkout expiry; omitting `Set-Cookie` alone is insufficient evidence.
- Assert the selected product's content and charged amount, not merely equality between hashes from the same faulty renderer.
- Define whether baseline test failures are accepted exceptions or blockers; “suites green” and “pre-existing failures listed” are not interchangeable.
- Test expired/revoked access on both JSON and PNG routes, including headers on errors, and include the receipt-link requirement.

**Strongest ideas to keep:** exhaustive offer/consent threading; concrete image transport split; `App.tsx` route precedence; opaque revocable links; truthful delivery states; local QR decoding proof; explicit separation of completed local work from deferred/live gates.

## Gemini draft

### Architectural soundness

The basic separation into catalog, validity, delivery and a standalone page is sound. `offers[]` plus an explicit `defaultOfferId` is clearer than making array position part of the API contract; combine that with a resumed `selectedOfferId`. Server-owned inclusive validity and an early selection endpoint are good foundations.

However, the token design is not complete enough to freeze:

- A stateless signature with expiry provides no individual revocation mechanism. U6 is labeled expiry/revocation but only tests expiry. Add a lookup/version/revocation record, or adopt an opaque token store. If signed tokens remain, select one key policy and define token purpose, validation and rotation rather than “JWT-like” and “or a dedicated secret.”
- The proposed claims lack the QR payload, receipt and first name, and the current purchase store cannot resolve `passId`. Explain how validation locates authoritative pass data. Pure stateless reconstruction would require a materially different payload and privacy decision.
- No rate limiter, club gate, cache/referrer policy, log-redaction task or resend/recovery path is specified. All are material to the intent's public credential surface.
- The offer architecture adds both pre-order selection and live `PUT /order` re-pricing without identifying a post-verify UI requirement. That expands scope into price/date/consent/payment concurrency. Prefer the bounded pre-order path; if live re-pricing is retained, specify transitions, max-date behavior, consent invalidation and purchase-in-progress rejection.
- Phase C lists `SignupShell.tsx`, but implementation must change `App.tsx` first, as the verified routing finding above shows.

### Completeness

Two explicit scope regressions must be removed. U3 removes the on-page receipt, but v4 retains it (`docs/prd/day-passv4.html:610` sets the done sidebar title to “Receipt”). CR-12 removes the QR, not the receipt. OQ5 also demotes the done-page link in favor of email, contrary to CR-13's required placements. Preserve the receipt and specify links on done, email and receipt.

Other omissions include all-path consent rendering, a purchase snapshot, UI API/types/slice migration, selection restoration on reload/Change, Riverside regression, exact multi-day label/Pay text, refund-copy preservation, failed/pending delivery copy, per-club overrides, layout breakpoints and explicit CF-04–07 register rows. These are implementation and acceptance gaps, even if some are implied by headings. The change should remove the helper in both mobile steps while retaining their existing telephone attributes.

### Phasing and ordering

The phase outline is easy to follow but inconsistent with OQ9: phases put token/page before email, while OQ9 orders email before token/page. Resolve dependencies explicitly: contract and snapshot → offers/validity end to end → token lifecycle → email/page integration → proof. Keep the done-page QR removal paired with working alternative credential access. Phase E covers inventory edits, but there is no adequate proof phase for the required browser matrix, security failures and traceability.

### Risk coverage

Three generic risk bullets are insufficient for the new bearer surface. Missing cases include revocation, enumeration/rate limiting, token leakage, checkout expiry, restart, send failure, resend races, purchase replay, stale selection and club-local date boundaries. A short expiration does not resolve timezone semantics; compute the precise expiry in the club's timezone. Moving a static QR from the page to email also does not itself establish the claimed security improvement.

The publisher image strategy is unresolved and internally inconsistent: Architecture says CID for SMTP and data URI or hosted image for publisher; OQ3 falls back to CID despite the current publisher request having no attachment field. Choose the transport strategy before freezing v3. Provider acceptance of HTML is not evidence of rendered images in recipient clients. Local Mailpit proof must remain separate from live/client compatibility claims.

### Feasibility

Not estimable as an execution plan yet: there are no task-level exit criteria, sizing, owners or complete file impacts, while live re-pricing adds work beyond Claude's proposal. Branching anew is a permissible interview alternative, but the intent's default remains the existing branches/PRs unless changed. `STP_NON_PRODUCTION` is not sufficient to guarantee mock payment: `BFF/services/shortTermPass/config.ts:109–125` selects adapter and capture modes separately. Record explicit mock settings and retain the no-real-cards/no-live-charges constraints.

### Definition of done

The current bullets could pass despite missing revocation, absent done/receipt links and no regression proof. Replace them with concrete gates covering all CRs, contract/type/schema agreement, selected offer through purchase, exact receipt fields, attachment decoding, standalone no-cookie access, expiry/revocation/gating/rate-limit failures, and 1440/375 smoke for each Core duration plus Riverside. State the actual coverage floors (UI 80/80; BFF 84/67/67/84), lint/build checks, CF register rows, traceability and the intent's full completion vocabulary. Preserve the prohibition on running the parity/agent harness.

**Strongest ideas to keep:** explicit `defaultOfferId`; concise capability-based organization; server-computed validity; recognition that selection happens before an order exists; static QR as the initial scope with rotation deferred. The signed-token alternative is worth documenting as a tradeoff, but not adopting without revocation and authoritative data resolution.

## Recommended merged-plan decisions

1. Start from Claude's bounded pre-order selection design; add Gemini's explicit default identifier and an atomic selected-offer/order-creation rule.
2. Freeze v3 only after specifying immutable purchase/receipt data, token resolution, allowed public fields, exact expiry and resend/replay behavior.
3. Keep Claude's concrete SMTP CID / publisher hosted-image proposal, with delivery failure semantics and local proof clearly separated from live claims.
4. Preserve the done receipt, remove only its on-page QR, and make all three required link placements explicit. Do not replace direct access with mandatory resend on refresh without an accepted recovery decision.
5. Reorder work around the dependency chain and use Claude's gates, strengthened by the failure/concurrency/date tests above. Keep harness execution, desk enforcement, hosted Pay Page proof and live publisher proof explicitly outside claims of local completion.
