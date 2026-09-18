# Sprint 0004 — Codex critique of Claude and Gemini drafts

Reviewed 2026-09-17. Scope: the intent, its four product/design inputs, Sprint 0003, both competing drafts, and targeted source inspection in `repos/online-join-bff`, `repos/online-join-ui`, and `repos/mico`. The wallet semantic-index entrypoint, identity and DT-sync themes, and DT data-access leaf were also consulted. This is a document and source review; no live DT, payment, deployment, webhook, or scanner behavior was verified.

## Recommendation

Use **Claude as the synthesis base**, with substantive corrections before execution. It supplies the reconciliation inventory, contract, file-level work, dependency registers, and proof vocabulary that Gemini lacks. Its strongest discovery is that MICO reaches DT through HTTP services rather than establishing the direct Oracle connection presumed by the intent. However, several of its detailed prescriptions would break the existing integration or overstate recovery guarantees.

**Gemini is a useful direction-setting outline, not an executable sprint plan.** Preserve its focus on one configured single-visit item and its recognition that failed compensation needs an operational owner beyond the browser. Do not adopt its MICO architecture premise, unspecified background sweep, or definition of done without expansion.

| Evaluation | Claude | Gemini |
|---|---|---|
| Architectural soundness | Strong source investigation and useful ports; serious routing, compensation, and production-fallback defects remain | Sensible reuse direction, but incorrect MICO premise and largely unspecified transaction model |
| Requirements completeness | Broad coverage; several material DT/email/enablement gaps and contradictory details | Main visible changes covered; returning lane, configuration, evidence, and owner handoffs substantially incomplete |
| Phasing and ordering | Contract first and two lanes are good; feasibility must precede freeze, and shared-file ownership needs clarification | Parallel UI/BFF outline is plausible; missing MICO and hosting work hides dependencies |
| Risk coverage | Much stronger register; unknown payment, cross-purchase restore races, and actual live readiness need correction | Two risks are insufficient; proposed crash mitigation does not work with current stores |
| Two-lane, 1–2-week feasibility | Near the two-week ceiling for a mock-proven change; not credible as a live pilot delivery without external work | Appears shorter because substantial work is absent from the estimate |
| Definition of done | Specific and measurable, but some gates pass while their advertised capability remains pending | Too generic to distinguish completed implementation from unverified integration |

## Open Questions 1–3: comparative assessment

### 1. Reconciliation with Sprint 0003

Both drafts correctly give the newly supplied Rounds 5–7 precedence. The authority is the intent's explicit source-precedence instruction, not an inference from timestamps. Claude's claim that the dates “prove” the order of intent is unnecessary and stronger than the evidence warrants.

Claude's **remove rather than hide** recommendation is the better default for the public pass page, token routes, and BFF QR renderer. D63 cancels that renderer, and the recorded future credential design is a different DT/engagement-owned direction. Keeping source in Git is sufficient. Its capability-by-capability table correctly retains the offers grid, selection lifecycle, immutable receipt, OTP, and payment capture while naming most removal paths and environment keys. Keeping a clearly labeled mock email stand-in without a generated QR is a useful distinction.

Gemini's configurable preservation is an allowable proposal for the interview, but not a complete reconciliation. It alternates between `STP_QR_V2_ENABLED` and `STP_V2_CREDENTIALS`, supplies no default/production guard, and does not enumerate `/passes/:token`, `/qr.png`, owner-only `pass-link`, history rewrites, delivery calls, dependencies, or the three `STP_PASS_LINK`/public-base settings. Hiding a React page would not disable the public BFF credential surface. Receipt and pass-email disposition are also missing. “BFF credential generation + rotation” conflates existing link rotation with rotating QR, which Sprint 0003 explicitly did not implement.

For either approach, **contract days are a redemption window, not multiple visits**. Do not remove inclusive calendar-date arithmetic just because selectable multi-day access is tabled. Retain the useful date helpers, compute expiration as begin + contract days − 1, and replace the commercial model and copy. Claude does this substantially better than Gemini's ambiguous “multi-day validity logic hidden.”

### 2. Home and repository

Both recommend retaining the OJ React/Koa repositories under a standalone host. That is defensible: `online-join-ui/src/App.tsx` already branches into `ShortTermPassPage` before `SignupShell`, and the BFF has a separate short-term-pass router, ports, stores, and consent model. Reusing these does not inherently sell a membership agreement. Explain this as a **proposed interpretation of D60 for Bjorn to decide**, not as CF-11 already answered.

Claude discusses ingress, origins, flags, future extraction, and a fallback if the decision remains open; Gemini mostly asserts that DNS/Cloudflare will make the page standalone immediately. Neither alternative cost is demonstrated: Claude's 6–10 engineering weeks and Gemini's month assume a full Java/UI rewrite. A MICO-hosted asset/proxy arrangement that reuses the React bundle and BFF is another possible scope. It may still be unattractive, but should be considered before presenting a rewrite estimate as the only MICO option. “New OJ” favors a reusable checkout boundary and explicit membership isolation; it does not settle repo governance by itself.

**Claude's proposed hosting implementation has two concrete defects:**

1. `online-join-ui/src/index.tsx:18` hard-codes `<BrowserRouter basename="/signup">`. Adding `/guest-pass` in `App.tsx` and serving the entry HTML at `/` does not by itself make the advertised root URL route to the checkout. Include the router base, root redirect/route, completion navigation, refresh, asset paths, and existing `/signup` behavior in the migration. `index.tsx` is absent from the task/file list.
2. Architecture §6 would reject every API outside `/api/short-term-pass`. The actual capture client in `online-join-ui/src/services/shortTermPass.ts:70` uses `/api/pay-page`, and `online-join-bff/src/routes/payPage/index.ts` owns short-term-pass session creation, reads, and closure. The proposed restriction would break the only authorized card-entry path. Allow the precise guest-pass Pay Page routes with their existing ownership controls; verify a hosted-card checkout on the new host, not merely entry-document rendering.

Both need cookie/origin/CSRF and feature-flag-off regression evidence across the old and new hosts. Claude at least names these boundaries. Until CF-11 is settled, keep local/dev implementation host-independent and report the standalone host as pending rather than complete.

### 3. DataTrak read path

**Claude wins this question, with important qualifications.** Source supports HTTP access to the DT service layer:

- `mico/build.gradle:75–76,92` excludes JDBC/JPA starters.
- `mico/src/main/java/com/abcfs/feignclients/OrasvcClient.java:50,95–96` declares the configurable HTTP client and `saleItems.spr`, taking both `club` and `memberId`.
- `mico/src/main/java/com/abcfs/repository/WsClubDefaults.java:221–226` reads club defaults through `oraSvcRestTemplate`, using `properties.getDtServices()` and `?clubNumber={club}`.
- `mico/src/main/java/com/abcfs/repository/WSProspect.java` delegates prospect creation to `OrasvcClient`; `ProspectController.java:196–219` does not demonstrate the new dates/visits/item fields.

Thus Gemini's statement that MICO “already has the Oracle link established” is incorrect for the inspected code. A small MICO facade remains a reasonable alternative because it can own credentials, mapping, and compatibility, but it still needs an upstream contract and a Java owner/release. Gemini budgets neither and names no MICO files or endpoint shape.

Claude correctly identifies the **pre-identity catalog problem**: the existing sale-items method requires a member id, while offers appear before OTP. Its day-one probe, explicit unknown columns, normalized fixtures, and fail-closed adapter are strong ideas. Bypassing MICO can avoid an extra release, but also moves authentication, mapping, and DT compatibility into the BFF. A facade is not merely an unnecessary hop if it preserves those responsibilities.

Correct Claude's overclaims before freezing the contract:

- Not all these reads use `OrasvcClient`: club defaults use a separate RestTemplate path. The sale-items Feign declaration advertises JSON output and XML input; an XML-only mapper and a new parser dependency are premature without checking actual responses. Verify content type, query names, base-path composition, auth, and timeouts separately for each endpoint.
- Finding the service layer explains “like Myko”; it does **not prove** that consuming it directly satisfies D64's literal database instruction or that Chancy's current PR adds the fields to these particular responses. Mark that interpretation and endpoint scope for confirmation. Synthetic future-column fixtures must be labeled synthetic, not “recorded” responses.
- The new adapter must still supply the full `CatalogClub` needed by Pay Page/wallet, including organization/location resolution, and an authoritative timezone. Today's `PlatformClubCatalog` resolves organization/location separately and hard-codes `America/Chicago` (`adapters/platform/catalog.ts:20`). Neither draft closes that timezone gap while promising club-local purchase dates.
- Price mapping needs currency, rounding, and tax semantics. `catalogPrice` plus a `taxed` boolean is not evidence that the displayed “including tax” total equals the eventual sale amount.

Direct Oracle from Node introduces credentials, networking, connection/VPD context, schema ownership, and deployment work; it is the highest-risk option for this sprint. The wallet DT-access precedent establishes those costs, not a ready guest-pass catalog service. Keep wallet-account-sync out of the runtime catalog path. A normalized catalog port with deterministic fixtures can ship while live reads remain gated.

## Claude draft: detailed critique

### Architectural soundness and risk coverage

**C1 — High: the proposed compensation graph treats unknown payment as decline.** Architecture §3 sends “declined / unknown / throws” into deactivate/restore and then `FAILED` when compensation succeeds. An unknown charge can already have succeeded. The existing `PaymentPort` explicitly requires a status lookup for `unknown` (`ports/payment.ts`), and `purchaseOrchestrator.ts:414–456` distinguishes unresolved authorization from a confirmed decline. Preserve that distinction and improve thrown-call handling rather than copying its current limitations. Specify authorization status reconciliation, sale failure, capture uncertainty, void/refund uncertainty, and the customer's retry permission for each state. A confirmed decline can compensate; an unresolved charge must not become “try another card” merely because deactivation returned success. After a later sale/capture failure, access written before payment also needs an explicit disposition.

The suggestion that `onlineSale.spr` could stand in for authorization while finalization becomes record-only needs a separate adapter contract. Current `finalizeSale` calls `payments.capture` after recording the sale (`purchaseOrchestrator.ts:616–691`). Do not accidentally charge twice or claim that a captured sale can be voided like an authorization.

**C2 — High: recovery claims exceed the existing persistence and identity guarantees.** `adapters/index.ts` instantiates in-memory purchase and checkout stores in both modes. `adapters/mock/purchaseStore.ts` explicitly loses state on restart and has no global pending-operation scan. Storing `previousAccess` there cannot guarantee crash recovery. Re-reading by email before creating is not idempotency: a competing request can create after the read, or the lookup can find an unrelated/ambiguous record. The current conflict path resets identity rather than adopting a new candidate (`purchaseOrchestrator.ts:468–543`). Preserve that security property.

The owner-only `/compensate` route is useful for bounded mock proof, but a buyer who closes the tab or loses the checkout cannot be the sole recovery mechanism. Either bound this sprint explicitly to in-process mock recovery and retain a named live-readiness gate, or budget an authoritative operation record and service-owned reconciliation. “Attempts logged, not persisted” forbids a new failed-attempt reporting feature; it should not be used to claim that transaction recovery needs no durable evidence.

**C3 — High: returning-prospect restore is a valuable proposal, not a settled D65 rule.** Avoiding accidental deactivation of previously paid access is thoughtful. However, neither the product direction nor MICO's inspected API establishes a `restore` operation. Confirm behavior with DT/Mark, including webhook semantics. A snapshot of dates and visits alone omits active/deactivated state, and a delayed restore can overwrite a later successful purchase or replenish a visit consumed in the meantime. One active purchase per checkout does not serialize two checkouts for the same prospect. Require club/member scoping plus a version/conditional-update or equivalent ownership rule before adopting automatic restore live.

Claude's new-buyer decline demo expects a second prospect on retry. Current `MockIdentityDirectory.create` checks contact conflicts even under a new purchase key (`adapters/mock/identityDirectory.ts:54–75`). Deactivation is not deletion. Define whether the retry reuses/reactivates the known record or resolves it again; test retry and subsequent OTP recognition without duplicate people or ambiguous contact matches.

**C4 — High: fixture fallback can escape the stated production guard.** The proposed `STP_CATALOG_SOURCE=mico` retains today's fixture offers, while production rejects only `fixture`. The existing `PlatformClubCatalog.getOffers()` literally returns `FIXTURE_OFFER`. Reject every fixture-bearing offer source in production, including this hybrid source, and test the configuration matrix. Otherwise the “never hard-coded” and fail-closed claims are false.

**C5 — High: DT email ownership lacks the data and timing contract.** Delegating QR rendering is correct. But create/repaint shapes carry only the opt-in boolean, not the acknowledged Pass Terms/waiver/opt-in text required by D52 and CR-19. Name how DT receives or reproducibly resolves the exact purchase snapshot, including club text changing between checkout and send. Also establish what triggers email on a returning repaint, whether create-before-pay sends an email before payment, and what delivery acknowledgement exists. `delivery.status='delegated'` alone does not establish “we've sent your QR.” Keep the requested success copy, but make successful DT handoff and truthful failure/pending behavior an integration requirement. Add POS receipt continuity and distinguishable subjects (CR-24) to pilot evidence.

### Completeness against the requirements

The draft covers most changed page requirements well: optional opt-in with recorded text/hash, no age field, numeric OTP already present, template fallback, expired saved-card rejection on the server, per-purchase terms/waiver, calendar-day boundary tests, receipt retention, attempt logs, and rate limits. It also separates scanner/webhook/Cloudflare proof from mock checkout evidence and retains the deferred harness decision.

Remaining gaps and corrections:

- **D61 enablement:** `requireShortTermPass.ts:67` still gates on `club.onlineProspects`, potentially coupling the paid pass to the free-trial configuration. Claude carries that field without deciding whether it remains an independent prerequisite. D61/FR-P19 say flagged products enable the offering and free-trial defaults stay untouched. Test a flagged paid item with online free trials disabled, and a club with no flagged items; confirm the intended gate rather than silently inheriting it.
- **D70 product type:** the proposed filter checks flag, visits, days, and positive price, but not product versus service. Require an upstream product-only contract or a mapped item-type check. Keep the primary fixture one item/one visit; three single-visit windows can exercise layout and data handling without being advertised as multi-day access. Explain the policy for invalid flagged items rather than silently weakening “list every flagged item.”
- **D66 versus v6:** the HTML still contains `adultCb`, Pay gating on `S.adult`, and “I confirm I am 18 or older” inside the waiver. The current BFF fallback waiver has that same sentence (`fixtures/consentTemplates.ts:121`). Removing `OrderRequest.adult` and `ConsentBlock` is insufficient if mandatory waiver acceptance preserves the age attestation. Record the design override and review the fallback copy with Kelly; do not rewrite club-supplied legal text silently.
- **CR-12 wallet token:** `validatePurchase` already resolves a server-verified token for both saved and hosted cards (`purchaseOrchestrator.ts:236–287`). RQ-7's default of omitting the token for hosted-card creation is not justified by token availability. Distinguish a Pay Page session id, a verified PG token, and a saved wallet entry, then settle the upstream field/side effects without violating save-only-after-auth.
- **Expired-card implementation:** B7 references `WalletPort.listCards` and `expiresAt`; actual ports expose `listEntries`, `expMonth`, and `expYear`. Specify expiration at the end of the expiry month, disabled presentation, and server revalidation using those fields.
- **Consent wording:** U5 mentions a Pass Terms checkbox, but architecture/C4 and v6 use Pay-tap acceptance plus a separate waiver checkbox. Freeze one consistent acceptance model; preserve one snapshot per purchase and reset waiver acceptance on the next purchase.
- **Inherited D12 gap:** RQ-4 treats member eligibility as unanswered, but D12 already blocks active/frozen/past-due/banned members. If lifecycle enforcement remains outside this delta sprint, retain it as an explicit production gap, not a permissive product default. Do not repaint a membership record as a prospect.

### Phasing, feasibility, and definition of done

The contract-first, vertical-slice, two-lane structure is worth keeping. Move A4's DT and hosting findings **before final contract freeze**, especially the payment failure table, token field, and returning compensation semantics. A2 currently promises all consumers type-check before B0/C0 delete and migrate many required fields; either budget that consumer migration in A or freeze fixtures/schema first and let each lane perform its migration atomically. Assign one owner for shared BFF files touched by both B and hosting work.

The stated calendar is approximately **2 + 5.5 + 2 = 9.5 working days**, assuming D really overlaps and separate orchestration/platform capacity exists. That leaves little contingency within two weeks. The 16-engineering-day headline undercounts if A/E are genuinely staffed by both lanes. Treat one week as a reduced mock slice; two weeks may cover the corrected mock/UI work and bounded adapters. Live payments, identity, DT writes, and durable recovery remain external dependencies. Remove unnecessary flag renaming and the undeveloped `STP_CREATE_BEFORE_PAY` switch from the critical path. Reversing this state machine later is not a one-line reorder; v2 should not become another configuration/test matrix now.

V0–V8 are stronger than Gemini's DoD, but V7 accepts pending hosting/LD while advertising a hosting gate, and “Rounds 5–7 changes complete” is too broad with P23/P26 and live P24/P27 unproven. Use separate verdicts: **implementation/mock acceptance complete**, **standalone dev host verified**, **live integration blocked/verified**, **pilot eligible**. Keep existing L1–L5 prerequisites explicitly alongside new V-P gates; the platform identity/prospect/payment/pass-sale adapters are still `notEnabled`. Those six new pilot gates alone cannot authorize launch.

Closing Sprint 0002 with documented deferrals is reasonable ledger housekeeping only if its schema distinguishes delivery completion from deferred/unverified gates. Do not make changing a historical status a functional release criterion.

## Gemini draft: detailed critique

### Architectural soundness and completeness

**G1 — High: the central integration work is not planned.** The MICO endpoint is a statement, not a design: no route, DTO, Java files, service-layer mapping, credentials/tenancy contract, terms/waiver payload, owner, or live-read fallback. It cannot be treated as a ready dependency. Its “direct connectivity” title also obscures the proposed indirect service path.

**G2 — High: create → authorize → deactivate is underspecified.** `ProspectPort` currently has only `create`; returning buyers bypass that call in `persistPerson`. The draft does not define repainting, begin/expiration/visits/item/token fields on the actual port, contact conflicts, existing access on decline, unknown authorization, sale/capture failure, or compensation failure response. “Guarantee idempotent recovery” is an acceptance aspiration, not an implementation. Its background sweep cannot recover lost in-memory purchases after a crash and needs a store, scan/claim interface, ownership, retry bounds, and tests if it is to be real.

**G3 — High: CR-14/15 and consent evidence are missing.** There is no returning-purchase use case for re-accepted Pass Terms/waiver, no expired-card fixture or server rejection, and no per-purchase opt-in timestamp/text-hash plan. A `marketingOptIn` boolean alone does not preserve the existing consent evidence architecture. Make modal opening independent from checking the optional box; it should not unexpectedly opt the buyer in or gate Pay.

**G4 — High: credential retirement is ambiguous.** Feature-flag names conflict, routes/env keys are not inventoried, and success still proceeds through `issue`/`deliver` with no explanation of how the existing BFF issuer/mailer stops generating credentials. Explicitly assign pass email and QR to DT, preserve the receipt, and test absence of all public QR routes. If code is retained for the interview's preferred v2 strategy, specify unreachable defaults and production rejection of the old mode.

**G5 — Medium: the catalog/validity contract is too small.** Replacing `visitDate`/`validUntil` with `contractDays`/`visits` loses the computed begin/expiration/use-by fields consumers and receipts still need. It omits selection/generation, flag/type/price/currency, no-offer behavior, timezone, midnight rollover, current contract-days revalidation, and terms/waiver provenance. Its 30-day use case is illustrative, but needs an explicit fixture value to prevent hard-coding. v1 has one configured item; the API should not truncate all catalogs to one item.

**G6 — Medium: several alleged tasks are already implemented or mislocated.** Numeric OTP input is already in `InlineCodeEntry.tsx:123`; the done `PassBlock` already has no QR. The remaining QR surface is the separate pass page and BFF/email path. Pin the existing keypad/timer behavior and target the actual removal paths. The draft's five-entry Files Summary omits most consumers, schemas, fixtures, tests, MICO, and hosting changes.

### Phasing, risk coverage, feasibility, and definition of done

The shared contract phase followed by UI/BFF lanes is sensible and easy to follow. However, the 2 + max(4,3) + 2 day schedule excludes MICO endpoint delivery, standalone hosting, authentication/network work, compensation infrastructure, and integration churn. Those cannot all be silently assigned to the BFF's four days. Add a day-one endpoint/hosting feasibility cutoff and let fixtures unblock the two lanes.

“Wait on Chancy's template” contradicts the intent's fallback requirement. Build a compatible PROPOSED template and record its status. Cloudflare needs a concrete owner, deployment gate, and observable rate-limit evidence; “rate limit heavily” is not a policy. Attempt logging without tokens/PAN, the existing mock-production boot guard, club feature gating, cold-start recovery limitations, and old membership-route regressions need explicit work and tests.

The proof phase is not credible as written. It names Cypress/Selenium without tying into the existing demo and browser-smoke workflow. A mock barcode scan cannot establish that a DT prospect's real emailed QR admits, then refuses expired/used access. “Zeroes out downstream CRM states” is also not CR-32: verify the deactivation event reaches every create recipient with the required inactive status; do not invent destructive CRM cleanup. Give scanner and webhook checks owners and gate them on the real DT path, while running local deterministic proof independently.

The DoD must name executable tests, evidence locations, and blocked capability outcomes. “Contract v4 implemented,” “UI passes design,” and “gated checks finalized” can all be claimed without a working returning purchase, standalone URL, real catalog, or compensation boundary. Add CF-08…CF-11 and PK/D65 registers with effects if unanswered, plus a complete cancellation/deferred list.

## Cross-draft requirements and handoff gaps

The sprint need not implement other teams' DT or operational changes, but every request should have a disposition: built, regression-pinned, externally owned/gated, cancelled, or deferred. Neither draft provides that complete map.

| Requirement group | Claude | Gemini | Required synthesis correction |
|---|---|---|---|
| Existing checkout/OTP/Pay Page, CR-01–08, CR-10, CR-13/30 | Mostly retained and tested | Retained implicitly | Pin right-panel consent, first-time no saved-card selector, OTP limits/timer, hosted-only capture, and membership regression |
| Opt-in/no age/returning, CR-09/14/15/26 | Detailed, with copy/port inconsistencies above | Returning cases omitted | Cover both lanes, optional unchecked state, repeat waiver acceptance, expired card, and fallback waiver age text |
| DT catalog/create, CR-12/17/18/21/28/31/33/35 | Strong seams, unverified mappings | Endpoint assertion only | Product-only model; one-item pilot; actual terms/waiver, dates, token and price mapping; no trial-setting mutation; club enablement guide |
| Email and credentials, CR-11/16/19/24/25/29/34 | Good removal/template plan; DT handoff incomplete | Retirement and template dependency vague | Cancel BFF QR, preserve POS receipt, acknowledged text and subjects, returning email trigger, truthful handoff status |
| Release/security, CR-20/23/27/32 | Hosting/flags/limits specified, defects above | Mostly prose | Whole-path flag, precise API allowlist, durable-readiness gate, Mark's separately owned API-package release, Cloudflare before public enablement |
| PR-01–04, PR-06–08, PR-12–14 | Most pilot checks named; product-marketing/enablement handoff thin | Scanner/webhook only | Mail sink + sandbox cards; keep harness deferment explicit; real scanner and CRM evidence; maintenance monitor/baselines; three-button club-site guide; legal mockup |
| PR-05/10/11/15–17; D69/D74 | DBA/review/Jira partly registered; future-begin tests mainly deferred by prose | Mostly absent | Track Chancy/Terry/PK handoffs and future-begin/pre-begin findings as external research, not permission to rebuild the picker |
| CF-01–12 and cancellations | Strong new CF register, not a full disposition map | No register | Carry older unresolved confirmations; close CF-06/07/12 by the recorded decisions; distinguish cancelled BFF QR from separately owned v2 credential work |

## Strongest ideas to keep and merge conditions

**From Claude:** the source-backed MICO correction; explicit removal inventory including environment keys; normalized catalog fixtures and pre-identity feasibility probe; separation of contract days and visits; consent-revision binding to the use-by date; expired-card validation on both sides; mock-only DT-email stand-in; concrete test/use-case tables; and named pilot gates that do not masquerade as local proof.

**From Gemini:** the concise one-item v1 framing; reuse of existing React/Koa work; a thin MICO facade as a legitimate alternative if service ownership/auth makes it preferable; and recognition that compensation must eventually run independently of a buyer's tab. Preserve these ideas without accepting its unsupported implementation assumptions.

Before merging a plan:

1. Record Q1–Q3 as recommendations awaiting the intent's interview, with host-independent/mock fallbacks. Prefer removal of cancelled credential surfaces and reuse of the existing checkout behind a correctly routed standalone host.
2. Freeze a payment/access failure table before the v4 API: decline versus unknown, new versus returning, sale/capture failures, safe retries, contact conflicts, and explicit recovery limits.
3. Validate the actual DT service contracts before committing to XML, field names, or a MICO facade. Keep fixture/live capability status distinct and forbid fixture-priced production sources.
4. Resolve the host router base and Pay Page allowlist; make new-host hosted-card smoke mandatory for declaring that host functional.
5. Add the missing DT email/acknowledgement contract, product/enablement rules, v6 override list, and complete request-disposition register.
6. Commit to a two-week mock-proven implementation scope with a separate, honest live-integration and pilot verdict. Cut optional flag churn and speculative v2 switches before cutting failure-path tests.
