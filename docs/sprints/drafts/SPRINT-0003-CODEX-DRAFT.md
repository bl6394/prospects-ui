# Sprint 0003: Design v4 — multi-day passes, emailed credentials and View your pass

**Status:** planning draft, 2026-09-15. Proposals below are for the sprint interview and Phase A freeze; no implementation or prior sprint gate is declared complete by this document.
**Inputs:** `SPRINT-0003-INTENT.md`; `docs/prd/Change_Requests_2026-09-15.md` CR-10…CR-17, PR-05/06, CF-04…CF-07; `docs/prd/day-passv4.html` (D46 design source); PRD v3.4 D18/D41, FR-P6/P7, §4.5, §5A.6 and Q19; contract v2; Sprint 0001/0002 plans, Sprint 0002 execution summary and UI blockers.
**Verified baseline:** UI `151846d`, BFF `53e549e`; clean clone worktrees when inspected. Continue `prospect-wallet/sprint-0001`, PRs UI #524 / BFF #96; preserve `daypass` prerelease configuration and `STP_NON_PRODUCTION`. Implementation commits start `Sprint 0003`.
**Chapter:** none selected; `docs/chapters/` does not exist. Sprint plans, ledger and execution evidence retain their own status authority.
**Path conventions:** `UI/` = `repos/online-join-ui/src/`; `UI-T/` = `repos/online-join-ui/__tests__/`; `BFF/` = `repos/online-join-bff/src/`; `STP/` = `BFF/services/shortTermPass/`. Paths labelled NEW are proposed files.

## Pyramid Index

- **L0:** Bring the existing checkout to Design v4: select a club-owned 1/3/5-day product, record the correct price and inclusive validity in consent and sale, deliver the QR and receipt by email, and provide a revocable, login-free pass link. Prove the complete flow locally without starting the deferred harness or implying live admission readiness.
- **L1:**
  - **A — Contract and decisions:** freeze v3, selection before verification, validity semantics, credential lifecycle, transport strategy, fixtures, security boundaries and v4 parity inputs.
  - **B — Catalog/order slice:** authoritative offer selection, club-local range arithmetic, consent refresh, Core Kelly fixture, issuance/receipt snapshots; integrate with UI early.
  - **C — Credentials and delivery:** signed pass-scoped links, separate credential storage, public read/image endpoints, QR-capable email, honest failure handling.
  - **D — UI:** accessible offer grid, v4 copy/layout, dynamic validity, QR-free done page and independent public pass page.
  - **E — Evidence:** route/unit/regression tests, 1440/375 browser smoke for all three products, Mailpit QR decoding and link checks, documentation and readiness register. Parity and agent runs stay deferred.
- **L2:** §Overview records source conflicts and actual code findings; §Use Cases maps requirements to proof; §Architecture defines v3 and trust boundaries; §Implementation Plan assigns phased files/tasks/exits; §Files Summary inventories changes; §Definition of Done separates local gates from inherited live gates; §Risks, §Dependencies and §Open Questions expose decisions and limits.

## Overview

Sprint 0001 supplied the checkout session, adapter boundaries, payment orchestration and wallet rules. Sprint 0002 implemented v1.2/PRD consent, email OTP for every buyer, hosted capture policy and local email. Its A–C implementation is complete; D/E1/E2 remain user-deferred, S5 remains pending B1, and live publisher delivery was blocked by a 503. This sprint extends that implementation rather than reopening its completed work or treating its unexecuted gates as passed.

**Ships locally:** Core South `90033` has Gym Floor 1-day/$25, 3-day/$60 and 5-day/$90 selectable before identify; server-derived inclusive ranges flow through checkout, Pass Terms, receipt, issued pass and email. The done page loses its QR and gains “View your pass”; the email contains a receipt, static QR and the same pass link. A fresh browser can open the link without email OTP, checkout cookie, app or membership session. Links expire and can be revoked. The mobile delivery promise is removed from both visitor paths, while the operational SMS notice remains.

**Bounded scope:** provisional catalog data, mock sale/issuance/payment and process-local storage remain explicit. No production enablement, live charge, real card, wallet-repo or MICO modification, membership Pay Page change, door verifier, rotating QR, public resend service, durable store migration or broad accessibility overhaul. Updating parity inputs is included; installing, implementing or running the deferred parity/agent harness is excluded. Ordinary unit tests and an orchestrator-operated browser smoke are included.

### Source reconciliation and retrieved prior art

| Finding | Consequence for this plan |
|---|---|
| The semantic entrypoint in `prospects1/docs/semantic-index/README.md` routes through `topics.md` and `themes/identity-by-member-id.md` to `repos/universal-wallet/identity/owner.md`. Cited `owner/vo/WalletEntryOwnerBaseVO.java` and `owner/validator/WalletEntryOwnerValidator.java` confirm UUID/type/location ownership requirements. There is no indexed offer, pass-link or email implementation for this seed. | Preserve wallet identity rules; use the actual unindexed Online Join files for architecture. Targeted `rg` and file reads were confined to named Online Join areas and exact wallet leaf citations; `repos/mico` was not scanned. |
| CR-10 says `offerId` already exists on the order request; actual `routes/shortTermPass/schemas.ts:OrderRequest` and UI request mirror have no such field. `requireOffer`, `consentSetFor` and checkout bootstrap take the first offer. `requireOrder` refuses pre-verification edits. | v3 needs an explicit early-selection API and selected-offer propagation through bootstrap, verify, order updates and purchase validation. A UI-only radio change cannot satisfy CR-10. |
| CR-10 asks to add Riverside multi-day offers; the concentrated intent and its success criteria explicitly retain Riverside's single product. | Proposed scope: Riverside `90030` stays 1-day/$18; Core gets 1/3/5. Record this discrepancy under CF-04 and in traceability. |
| `App.tsx` already bypasses `SignupShell` for Day Pass. `PAGES.shortTermPassDone` is `/pass`, under the `/signup` basename. | Match `/pass/:token` exactly before the existing `/pass` checkout branch. Do not mount the public page inside membership initialization or let it bootstrap a new checkout. |
| The intent names `adapters/mock/outbox.ts`; `MockOutbox` actually lives in `adapters/mock/verification.ts`. Consent-event cases are included in the current route tests rather than the named standalone test file. | Use real paths below; add dedicated test files only where useful. |
| `inputMode="tel"` and `autoComplete="tel"` already exist on both mobile paths. | Remove the obsolete helper and preserve/test the attributes and SMS notice; do not claim the attributes are new work. |
| SMTP `passEmail()` hard-codes 1-day; publisher imports it, then sends only base64 HTML/plain text. Its pass call currently omits club context. | Extract shared pass/receipt rendering, add explicit image transport handling, and pass seller/club context to fix billing/display metadata. |
| The mock QR is `STP1|passId|club|visitDate|sig`, with a truncated unkeyed digest; no desk verifier is present. | Preserve its classification as a demo credential; extend its fixture range representation deliberately. A signed link does not turn that payload into a production admission credential. |
| v4 removes the done QR; older PRD passages say it appears immediately. v4 also contains a refund sentence that conflicts with the PRD. | Follow CR-12/v4 for done presentation, CR-13 for the additional link, and PRD D15/D22 for refunds. Static-first web QR is a recorded CF-06/07 staging decision, not completion of §5A rotation. |

## Use Cases

All purchase runs use mock payment/sale. UI widths are 1440×1000 and 375×900, with a pinned club-local test date.

| ID | Behaviour and required result | Requirement / proof |
|---|---|---|
| U1 | Core shows a keyboard-operable “Choose a pass” radiogroup, default 1-day, with unique radio ids, 1/3/5 labels, prices and shared perks. Accepted selection toasts `{label} · {price}`. | CR-10/15; B1, D1, E2 |
| U2 | Select 3/5-day before entering email; selection survives code entry, reload, verification and identity Change. Recognized and new-visitor order shells use that selection. Starting an entirely new checkout restores the default. | CR-10; B2, D1/D2 |
| U3 | Unknown, another club's, disabled or removed offer is refused without changing selection or charging; browser-supplied price/duration/end date is rejected. | CR-10; B1/B2 route tests |
| U4 | Changing offer/date updates amount, duration, validity, Pass Terms revision and Pay text together. Existing valid start date is retained; an incompatible horizon is refused with an actionable date error. | CR-10/11/17; B2/B3, D2/D3 |
| U5 | 1-day keeps “Day pass applies on”; multi-day uses “Pass starts on”. Calendar addition handles month/year/leap-day/DST boundaries and a browser in another timezone. A 3-day pass beginning 2026-09-10 ends 2026-09-12. | CR-11/CF-05; B3, D3 |
| U6 | A stale consent revision or concurrent order edit is refused before authorization. One purchase records exactly one matching consent/order snapshot; replay returns the same pass/link and never recharges or sends another email. | CR-10/17; B2/B4, C2, E1 |
| U7 | Core `m@m.com` is Kelly Reyes with the existing saved-card fixture; Riverside Jordan and its $18 single-offer behaviour remain intact. | CR-16; B1, E2 |
| U8 | Done shows `{label} · {validity}`, the v4 sent-email sentence and a View link, with no QR node/canvas/SVG. The receipt section also links to the pass. | CR-12/13; D4 |
| U9 | A Mailpit pass email contains a displayed PNG QR, plain-text fallback, pass label/range, receipt number, item, amount/currency, seller/location and View link. Decode the image and compare to the issued payload. | CR-12/PR-06; C3, E3 |
| U10 | Open the email link in a fresh browser, without `?club=`, cookies or login. Show only club/pass information, first name, masked contact and QR; refresh and opening after checkout expiry still work. | CR-13; C1/C2, D5, E3 |
| U11 | Malformed/tampered/unknown/expired/revoked links fail closed without identity information. Rate limits return 429. Link/image requests cause no sale, email, redemption or one-use token consumption. | CR-13; C1/C2 security tests |
| U12 | A future pass is labelled not yet valid; after its pass window the grace-period page says expired and hides the QR. At link expiry the page is unavailable. Revocation disables both API and image retrieval immediately. | CR-11/13/CF-06; C1/C2, D5 |
| U13 | SMTP failure or QR-render failure does not refund an issued pass or repeat payment. Done retains the working View link and says email failed/pending truthfully. No link is advertised for an unissued/refunded pass. | CR-12/13; C2/C3, D4 |
| U14 | Both mobile paths omit “We'll text your pass here on the day.”, retain tel attributes and the transactional-SMS notice; required mobile and marketing/save defaults do not change. | CR-14; D4 |
| U15 | Offer cards stack at v4's 1250/640 breakpoints without horizontal overflow; dialogs, Pay and existing hosted-frame lifecycle remain usable. | CR-15; D1/D3, E2 |
| U16 | A frozen v4 inventory covers the eleven inherited states plus identify-3-day/identify-5-day, with cited deltas and no executed parity/agent run. | PR-05; A3, E4 |

Regression baseline: OTP for every buyer, lookup only after verification, wallet ownership/UUID `providedId`, save default off, one active purchase, every payment failure boundary, checkout CSRF/origin/gates, hooks-only mock capture and existing membership/guest/Pay Page suites.

## Architecture

### 1. Contract v3 and selection before an order exists

**Proposed choice: dedicated `PUT /checkouts/:id/offer`.** It separates an unverified catalog choice from an order's verified-person consent state. Keep `PUT /order` for date/consent/preferences. Both call the same internal order-recalculation service when an order exists; do not create two competing implementations. The interview alternative is an offer-only pre-verification branch on `PUT /order`; choose one at A2, not both.

| Surface | v3 proposal |
|---|---|
| `POST /checkouts` | Return `offers: OfferSummary[]`, `selectedOfferId`, and retain `offer` as the selected summary for migration. Persist selection at creation; resumed responses resolve the stored selection, not index zero. Return current selected consent preview and snapshot. |
| `CheckoutRecord` / snapshot | Add `selectedOfferId`. No order/acceptance is created before verification. Selection is preserved through identity reset, while identity, order, consent acceptance and hosted sessions still reset. Full revoke/new checkout resets selection. |
| `PUT /checkouts/:id/offer` | `{offerId, generation}` with cookie, CSRF, Origin and club gate. Allowed in `identify`, `challenge`, `verified`, `recognized`, `newVisitor`; refuse completed/revoked or active-purchase states. Return `{offer, selectedOfferId, consent, order?, generation}`; absent `order` before verification. No client price, duration or club accepted. |
| `PUT /order` | Existing fields plus mandatory v3 generation. `OrderSummary` adds `durationDays`, `validUntil`; selected offer supplies all commercial fields. |
| Purchase result | Issued `pass` adds `offerName`, `durationDays`, `validUntil`, `viewUrl`, `linkExpiresAt`; receipt snapshot adds item, amount/currency, seller, dates and View URL. Preserve existing result statuses and consent summary. Checkout-owned `qrPayload` may remain for compatibility, but is never rendered on done. |
| Public pass | `GET /api/short-term-pass/passes/:token` → explicit allowlisted `PublicPassResponse`; `GET /api/short-term-pass/passes/:token/qr.png` → image only. Both independent of checkout ownership. No public mutation endpoint. |

The pre-verification sidebar remains the v4 skeleton until a verified order exists. Selection immediately changes the selected card and consent preview, and determines all later sidebar/payment content. Do not invent an early payable order to display a total. After verification, every affected surface reads the server's order, never `checkout.offer` from the original bootstrap.

Audit every `requireOffer`/`consentSetFor`/`createOrderShell` call, including `identify.ts` lookup completion and purchase validation. Offer resolution requires membership in this checkout's club catalog. Removed selected offers trigger a typed conflict and refresh, never silent repricing to the first item. Bootstrap handles an empty catalog as unavailable.

**Concurrency:** current UI latest-request filtering does not prevent stale writes at the BFF. Use the checkout generation as the compare-and-set boundary for offer and order mutations: compare inside `CheckoutStore.update`, apply against the current record, increment on committed commercial/order edits, return the new generation. Resolve async catalog inputs first, then recheck generation/state/active purchase in the atomic commit. Serialize UI offer/order writes (including the automatic SMS-notice write); hold Continue/Verify/Pay during a pending selection and Pay during any pending order change. Rehydrate after a generation conflict; never automatically retry a purchase or acceptance. Preserve hosted fields/profile input while updates complete.

At A2, enumerate generation handling on **all existing checkout mutations**, including challenge, consent events, capture creation, wallet retry and DELETE paths, and mirror request/header rules in schemas, clients and demo helpers. Creation has no existing generation; public reads have none. State-changing handlers must recheck inside their atomic operation. Do not overload challenge's own generation with order revision or invalidate a valid OTP when only a product changes. Add races for offer-versus-verify, date-versus-offer and order-versus-purchase; an active purchase locks the purchased order snapshot.

### 2. Calendar ranges, commercial snapshots and consent

- Compute `validUntil = addDays(visitDate, durationDays - 1)` in the BFF using validated ISO calendar dates and the existing UTC-based calendar helper. `visitDate`/`validUntil` are club-local dates, not timestamps. Catalog timezone supplies today; browser timezone does not control eligibility.
- Propose consecutive calendar days for these fixtures (CF-05). `maxDaysAhead` constrains the **start date**; the end can fall later. Preserve a date on offer switch if allowed; reject the entire switch when it is not, unless the request design frozen in A2 explicitly supports an atomic replacement date. Do not clamp silently. Validate again at purchase, including midnight rollover.
- Add a BFF validity helper used by order, consent, issued-pass metadata and email. UI formatting mirrors the documented examples: one day `Today · Thu, Sep 10`; three days `Today – Sat, Sep 12`; future ranges show both formatted dates. Use absolute dates in durable email/receipt details so “Today” does not become misleading when opened later. Public page uses current club-local today returned by the BFF.
- Carry `durationDays` and `validUntil` through `StoredOrder`, summaries, `FinalizeSaleInput`, `IssuePassInput`, `IssuedPass` and `DeliveryInput`. Store an immutable purchase commercial snapshot alongside the existing one-time consent snapshot. Public pass and receipt render purchased facts even if the catalog later changes.
- Pass Terms uses duration label (`3-day pass`), legal seller and validity; line item uses duration plus product name without duplicating Riverside's `1-day pass`. Bump only the changed template version. Preserve the exact PRD refund sentence and per-club override precedence.
- Preserve adult/save/marketing state on a product change. Preserve waiver acceptance **only if its rendered hash is unchanged**; otherwise clear it and require acceptance of the current document. An offer/date/amount change always invalidates the previous purchase attestation. Bind the consent revision to the canonical selected commercial fields as well as document hashes, notices and Pay text, so static club-authored terms or equal-price offers cannot hide a changed range/product. Update purchase recomputation and fingerprint tests accordingly.

### 3. Pass link, storage and public trust boundary

Use a small versioned HMAC-signed capability, not a JWT dependency: fixed format `v1.<randomId>.<expiresEpoch>.<signature>`, with a cryptographically random 32-byte base64url id and HMAC-SHA256 over version, purpose, id and expiry. Use a dedicated `STP_PASS_LINK_SECRET`, strict lengths/encoding, constant-time signature comparison and no algorithm choice supplied by the client. The token contains no email, member, checkout, receipt or club identifier. Fixed purpose prevents reuse as checkout authentication or a payment token.

Add `PassCredentialStorePort` and a process-local adapter with atomic `getOrCreateForPurchase`, lookup, revoke and expiry cleanup. Its record binds one credential to one issued pass, purchase, person and club internally, with immutable display/QR facts, issue time, expiry and revocation time. Store the random id and signed claims so the same URL is deterministically reconstructed for retry/replay; do not regenerate links on GET. The store is independent of the 30-minute/two-hour checkout lifetimes. Start again revokes the checkout only, not a purchased pass.

**Proposed lifetime:** usable for viewing immediately after issuance; expires 24 hours after the exclusive end of the last valid club-local day. The admission window remains `[start-of-visitDate, start-of-day-after-validUntil)`. The 24-hour grace grants view access only, never admission. Convert local day boundaries with a tested timezone-aware helper; never compute the end using `durationDays × 24h`. During grace return `status:'expired'` without QR; after link expiry return the generic unavailable response. Before the pass starts, display the dates and “Not yet valid”; the static QR may be shown, but admission still depends on the verifier's window check.

Revocation is an internal service/store operation with unit/route proof. Add a narrowly scoped test-only revocation hook if browser proof needs it, under existing loopback/key/`STP_TEST_HOOKS` protection. No unauthenticated revocation or resend API. Refund/revoked purchase state must invalidate credentials on read and in any future refund integration. A restart loses local records and invalidates links; distributed/durable storage, production keys, key rotation and operational revocation ownership remain L4/live-readiness work. Do not enable this in production using an in-memory credential store.

**Public route chain:** common error/no-store pipeline → strict token parsing and IP limiter → signature/record/expiry/revocation validation → pass-derived club gate → allowlisted response. Reuse `requireShortTermPass` with club resolved from the validated credential, not `?club=`; retain its feature/club fail-closed behaviour. Document that turning the checkout flag off also disables this demo's issued-pass retrieval; separating sale and credential availability is a rollout decision. Do not reuse `checkoutChain`, which requires a cookie. GET requires neither CSRF nor OTP and does not mutate the pass.

Proposed response: `{club:{name,locationLabel,timezone}, pass:{label,offerName,visitDate,validUntil,status}, firstName, maskedContact, today, linkExpiresAt, qrPayload?}`. Exclude surname, unmasked contact, member/org ids, payment/card/wallet fields and receipt detail. A receipt link opens the pass, not an account portal. Return the same 404/error body for malformed, tampered, unknown, revoked and link-expired tokens; 429 includes retry delay. Suggested local limits: 60 requests/minute/IP and 30/minute/credential across JSON/image endpoints, bounded/expiring limiter entries. Tune with email-proxy behaviour before live use.

Set `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex, nofollow` on API/image **and token HTML document**. Restrict PNG content type and add `nosniff`; no redirects derived from request input. Build absolute URLs only from configured `STP_PUBLIC_BASE_URL` (including `/signup` handling), never Host headers. HTTPS required outside explicit local development.

Audit BFF access logging, HTML history fallback, AppDynamics initialization and client tracking before token pages load: redact token paths, suppress URL-capturing third-party scripts on this surface, and omit tokens/QRs from diagnostics, Redux persistence and committed smoke artifacts. `SignupShell` avoidance alone is insufficient because the HTML entrypoint injects scripts. Keep membership instrumentation unchanged. Public links are bearer credentials: forwarding grants access; scanner/prefetch GETs must not consume them. Link revocation cannot recall a CID image or screenshot already delivered; only a real desk verifier can reject its admission later.

### 4. QR rendering and delivery

Create a Node QR renderer (`qrcode`, types if required; pinned through the BFF lockfile) behind a small service interface. Render the exact issued payload to a high-contrast PNG with a quiet zone and a readable 240–320 px display size. Bound payload size. Test by decoding generated bytes, not merely checking that a Buffer exists. Reuse `qrcode.react` only for the public browser page; it leaves the done component.

**Static-first choice:** email and web page encode the same issued payload. Extend the mock format/version to cover both dates and its server-side person/purchase binding; document the format as mock-only. Do not imply that its digest authenticates a production pass. Rotating signatures, scan freshness, single-visit consumption, anomaly thresholds and a production verifier remain explicit CF-06/07/L2 entries; no unused “rotation” flag that appears to fulfill the requirement.

| Transport | Image choice and rationale | Proof / limitation |
|---|---|---|
| SMTP / Mailpit | Nodemailer CID PNG attachment (`Content-ID` matched by `<img src="cid:…">`) plus HTML and text. No external fetch needed to display the locally delivered QR. | Inspect MIME, rendered inbox and decode attachment. Required PR-06 lane. |
| Publisher | Same template with absolute token-protected `/passes/:token/qr.png` image URL and visible View link. Current `EmailEngineRequest` supports base64 HTML/plain text but no attachment contract. Do not invent one. | Unit-test decoded publisher HTML and locally exercise image endpoint. Public HTTPS reachability, image proxies/client blocking and actual publisher delivery stay unverified while 503 persists. |
| Mock outbox | Store sanitized delivery metadata for inspection, including range and receipt facts. Keep raw credential URLs out of generic state dumps. | Test hooks can obtain a fixture link deliberately for local browser proof; reports redact it. Outbox recording alone is not SMTP success. |

Avoid data-URI QR as the default: rendering compatibility needs broader client proof, whereas CID is directly demonstrable in Mailpit and hosted images fit the existing publisher DTO. The same token authorizes the same pass-only information on both public endpoints; no unauthenticated `passId` image lookup. Remote-image requests during the grace/expired state must not expose an active QR. External image caches may retain previously fetched pixels despite no-store; admission expiry cannot rely on image retrieval.

Extract `renderPassReceiptMail` alongside the verification template, taking a transport-selected image source. Reuse its legal-name/location header, table layout, inline styles, escaped interpolation and “Sent on behalf of … by ABC Fitness” footer. Include receipt number, item/quantity, paid total/currency, absolute validity, seller/address when configured, purchase timestamp, document links and View CTA. Do not invent a tax breakdown; totals retain the fixture's existing including-tax semantics. Pass `toClubMailContext(club)` to publisher delivery so billing is not `00000`.

Orchestration remains validate → authorize → prospect → wallet → sale/capture → issue → credential registration → delivery → complete. Persist the pass and commercial facts at ISSUED; register the credential idempotently before sending. QR rendering/SMTP/publisher failures stay in delivery and do not undo a successful issue. If credential storage fails, preserve the issued sale, mark retrieval unavailable and do not fabricate a link; report the capability failure separately and block the local link-completion gate until fixed. Existing purchase replay must return the stored outcome without resending; wallet-only retry must not mint credentials or deliver mail. A public resend UI is deferred; authenticated delivery recovery needs a separate bounded contract before implementation.

### 5. UI route, state and copy

Add an exact `/pass/:token` match in `App.tsx` before the existing Day Pass branches, using the current router basename. `/signup/pass?club=90033` remains checkout completion; `/signup/pass/<token>` renders `ViewPassPage` without `ShortTermPassPage`, `CheckoutController`, `SignupShell`, gym requests or trackers. Public service calls do not use the checkout CSRF singleton and do not bootstrap checkout on 404. Test direct navigation, refresh, browser history and API history-fallback exclusion.

Use a small public-page loading/error state rather than putting the token into the checkout slice. A provisional layout reuses scoped Inter/tokens: club header, first name, duration/product, explicit validity, clear status, QR and desk instructions; no app/login requirement, payment information or misleading “Secure checkout” label. Accessible textual status remains when QR cannot render. No page-specific design exists; record the proposed layout for DESIGN review, not as v4 pixel parity.

The offer grid follows v4 `.offers`, 32 px price/icon, `.days`, perks line height, lead flex sizing and 1250/640 breakpoints. Keep existing `minmax(0,1fr)` and shrink protections. Use a shared `OfferCard` with `selected`, `disabled`, `onSelect` and unique ids; preserve native radio keyboard semantics and show selection errors without losing the prior confirmed offer. Avoid stale optimistic price/consent combinations; authoritative success adopts selection/order/consent together.

Done's sent copy is exactly: “We emailed your pass and door QR code to {masked}. Show it at the door, or just say your name at the front desk.” Pending: “We're sending your pass and door QR code to {masked}. You can view your pass here.” Failed: “We couldn't email your pass and door QR code to {masked}. You can view your pass here, or say your name at the front desk.” Only offer the link when available. Update receipt fine print as well as PassBlock, since it currently claims delivery independently. Publisher acknowledgement means queued, not inbox delivery; propose mapping pass delivery to `pending` for that acknowledgement, without changing OTP success handling. Preserve failed/reconciling purchase and wallet-retry UI. CR-13's link placement and truthful delivery variants are cited deltas from the static prototype.

## Implementation Plan

**Sizing:** approximately 15–19 engineering days plus review availability: A 1–2, B 3–4, C 4–5, D 4–5, E 2–3. Workstreams are ownership boundaries, not authorization to start extra agent sessions. Freeze A first; integrate B1–B3 with D1–D3 for the first functioning slice, then C with D4/D5, then E. Tests accompany each task. Assign named owners at kickoff.

### A — Decisions, contract v3 and proof baseline

| # | Task | Files | Done when |
|---|---|---|---|
| A1 | Record current SHAs/branches, preserve prerelease settings and baseline failures; name owners; record CF-04…07 proposals and inherited deferred/pending gates. | Contract §10; sprint ledger and execution notes during implementation | No old gate is silently closed; scope/decision owners recorded. |
| A2 | Freeze v3 request/response examples, generation matrix, state transitions, immutable receipt, link/image errors, configuration and public route boundary. Include no-order selection, stale offer, changed waiver and expiry examples. | `docs/contracts/short-term-pass-bff.md`; `BFF/routes/shortTermPass/schemas.ts`; `UI/interfaces/api/shortTermPass.ts` | UI/BFF agree on executable DTO fixtures; compatibility impact documented before feature coding. |
| A3 | Inventory v4 source/checksum, 13 parity states, selector mappings, masks and cited deltas; specify proposed pass email/page layout separately. | NEW `docs/validation/parity/sprint-0003/{baseline.md,states.json,elements.json,approved-deltas.json}` | Inputs parse and reference v4; marked “inputs only — harness deferred”; no runner started or scaffold modified. |
| A4 | Time-box implementation feasibility checks: Node QR package/build shape, local public URL/base path, timezone boundary utility, token-path instrumentation exposure, CID MIME shape. | Design notes in contract/validation; BFF `package.json` + lock only when adding renderer | Chosen strategy has no assumed publisher attachment capability; failures become explicit tasks/risks. |

### B — Catalog, order and validity

| # | Task | Files | Done when |
|---|---|---|---|
| B1 | Core 1/3/5 catalog, provisional marker in capability data, Kelly fixture; retain existing one-day offer id and Riverside default. | `STP/fixtures/{catalog,directory}.ts`, `ports/clubCatalog.ts`, `adapters/{mock,platform}/catalog.ts` | Catalog tests pin ownership/prices/duration; provisional data never masquerades as approved live catalog. |
| B2 | Persist selection; new offer route; bootstrap/resume/identity-reset/verify propagation; atomic generation checks and purchase lock; audit mutation clients. | `BFF/routes/shortTermPass/{offer,checkouts,order,index,schemas,verify,challenge,consentEvents,session,purchase}.ts`; `STP/{order,identify,challenge}.ts`, `ports/checkoutStore.ts`; relevant clients/helpers | U2/U3/U6 pass; pre-verify selection cannot accept consent or enable capture; stale commits cannot overwrite selection. |
| B3 | Inclusive range helper and dynamic consent context; horizon validation, template bump, revision commercial binding, waiver-hash preservation. | NEW `STP/validity.ts`; `STP/order.ts`, `fixtures/consentTemplates.ts`, `ports/clubCatalog.ts`; consent/order tests | Range and override cases pass across timezone/date boundaries; stale attestation refused before authorization. |
| B4 | Snapshot purchased facts; propagate range through sale, issue, result, receipt and demo QR. | `STP/purchaseOrchestrator.ts`, `ports/{passSale,purchaseStore,delivery}.ts`, `adapters/mock/passSale.ts`; purchase tests | Each offer purchases at its catalog total; one consent/commercial snapshot; failure and idempotency tests green. |

**First demonstrable exit (B1–B3 + D1–D3):** select 5-day before email, verify, change start date, inspect matching sidebar/Pass Terms/Pay text, then show the server order. No email/link completion claim at this checkpoint.

### C — Pass credential and email

| # | Task | Files | Done when |
|---|---|---|---|
| C1 | Signed token service, independent credential port/store, idempotent issuance, revoke/expiry, configuration and capability report. | NEW `STP/{passCredentials,qrRenderer}.ts`, `ports/passCredentialStore.ts`, `adapters/mock/passCredentialStore.ts`; MODIFY `STP/{config,adapters/index}.ts`, `BFF/env.ts`, BFF `.env.example`, package + lock | Token tampering/expiry/revocation/store-loss tests pass; no use of session/code secrets; no production in-memory enablement. |
| C2 | Public JSON/image routes, pass-derived club gate, independent limiter, allowlisted response; orchestrator registration; redact hooks; token-safe HTML entry. | NEW `BFF/routes/shortTermPass/passes.ts`; MODIFY `index.ts`, `context.ts`, `testing/routes.ts`, `STP/purchaseOrchestrator.ts`, `STP/log.ts`; `BFF/routes/static/index.html.ts`, applicable middleware/logging configuration | Fresh-cookie read works after checkout expiry; 404/429/no-store/no-referrer tests pass for HTML/API/image; no tracking token leak. |
| C3 | Shared pass/receipt template, SMTP CID attachment, publisher hosted image/club context, bounded QR rendering and transport-specific delivery state. | NEW `STP/adapters/smtp/templates/passReceipt.ts`; MODIFY `adapters/{smtp/mailer,publisher/emailPublisher,mock/verification}.ts`, `ports/delivery.ts`; reuse `ports/verification.ts` context | MIME/decoded QR/template/escaping tests pass; publisher body uses AMZ/base64 HTML and valid image/View URLs; faults leave issued pass accessible. |
| C4 | Extend mock HTTP demo for 1/3/5-day purchase, immutable receipt and public-pass retrieval without cookie; replay and wallet retry checks. | BFF `scripts/short-term-pass-demo.ts`; route testing harness/helpers | Existing checks and additions green; output redacts links, keys and QR payloads. |

### D — v4 checkout and public page

| # | Task | Files | Done when |
|---|---|---|---|
| D1 | Offers radiogroup/grid, selected state, toast, loading/error behaviour, Kelly labels. | `UI/routes/ShortTermPass/{steps/IdentifyStep,components/OfferCard}.tsx`, `UI/styles/short-term-pass.scss` | U1/U7/U15 component tests pass; keyboard selection and unique ids verified. |
| D2 | v3 service/slice/selectors, generation-aware serialized updates, restore selection, retain profile/capture, guard pending mutations. | `UI/{services/shortTermPass.ts,reducers/shortTermPass/shortTermPassSlice.ts,selectors/shortTermPass.ts}`; `components/CheckoutController.tsx`, `hooks/usePayAction.ts` | Races/rollback/reload/reset tests pass; no new iframe session on offer/date changes. |
| D3 | Duration/range formatters; selected order drives labels, total, receipt, dialogs and Pay. | `UI/routes/ShortTermPass/{format.ts,components/OrderSummary.tsx,components/ConsentBlock.tsx}`; fixture/test data | U4/U5 exact examples and stale-consent gates pass; early sidebar retains skeleton. |
| D4 | Remove done QR, add View CTA in pass/receipt, truthful delivery variants, remove both mobile promises. | `steps/{Done,NewVisitor,Recognized}Step.tsx`, `components/{PassBlock,OrderSummary}.tsx` | No QR on done for any product; sent/pending/failed and wallet outcomes accurate; tel attributes/SMS notice retained. |
| D5 | Public page/service and exact route split before completion branch; responsive/accessibility states. | NEW `UI/routes/ShortTermPass/ViewPassPage.tsx`, `UI/services/passCredentials.ts`; MODIFY `UI/{App.tsx,common/constants.ts,styles/short-term-pass.scss}` | Fresh direct link/refresh requires no club query/login; public errors never create checkout; membership and completion routing tests pass. |

### E — Integration, smoke, evidence and handoff

| # | Task | Evidence / exit |
|---|---|---|
| E1 | Run targeted route/service/component tests, then full lint/build/coverage in each repo; existing signup/guest/Pay Page tests; baseline demo. | Exact commands, SHAs, totals and failures in `docs/validation/short-term-pass-sprint-0003-smoke.md`. BFF floors 84 statements / 67 branches / 67 functions / 84 lines; UI 80 statements/lines. No lowered thresholds/exclusions. |
| E2 | Orchestrator browser smoke through BFF :3000 for 1/3/5 at 1440/375: select before email, verify, accept current terms, purchase, inspect receipt. Cover new save-on/off and Kelly saved-card across matrix; Riverside regression; spot-check 1250/640 boundaries. | Six Core product×width completions plus Riverside; screenshots and sanitized state correlate chosen offer, range, amount and consent revision. Include delivery-failure and stale-tab cases. This is not the deferred parity loop. |
| E3 | Mailpit at :8025 / SMTP :2525: inspect pass mail for all durations, decode CID QR, compare issued/page payload, open email/receipt/done links in fresh browser, test checkout expiry, token expiry/revocation and image endpoint. | PR-06 checklist with MIME/image/link evidence; no raw bearer URL in committed screenshots/reports. Publisher tests labelled simulated; live 503 remains unresolved without real delivery evidence. |
| E4 | Finalize parity input files against actual selectors, remove done-QR mask, preserve only justified hosted-frame masks; link to source citations and proposal approval status. | 13 states inventoried; no parity report or agent verdict claimed; `tools/day-pass-harness/` unchanged. |
| E5 | Update contract/readiness, traceability, demo, semantic code map, sprint status and PR descriptions. | `docs/validation/short-term-pass-sprint-0003-traceability.md`: each CR/PR → task → commit → test/evidence → verdict; CF owner/status rows; `docs/sprints/drafts/SPRINT-0003-EXECUTION-SUMMARY.md`; ledger updates reflect actual results. |

Quality commands during implementation: `npm run lint`, `npm run build`, `npm run test:cov -- --runInBand` in each clone; BFF `npm run demo:short-term-pass`. Use UI `npm install --legacy-peer-deps` only if install is needed; keep BFF husky/lint-staged active. Record the established timezone for the pre-existing `transformers.test.ts` baseline rather than hiding it. Do not execute parity/agents commands. B1 hosted proof remains a separately labelled inherited task, using sandbox capture and mock charge/sale only if credentials become available.

## Files Summary

| Area | Paths | Action |
|---|---|---|
| BFF contract/routes | `src/routes/shortTermPass/{schemas,index,context,checkouts,order,verify,challenge,consentEvents,session,purchase}.ts`, `testing/{routes,harness}.ts` | MODIFY as required by v3/generation matrix |
| BFF new routes | `src/routes/shortTermPass/{offer,passes}.ts` | NEW |
| BFF domain | `src/services/shortTermPass/{order,identify,challenge,purchaseOrchestrator,config,log}.ts`; `ports/{clubCatalog,checkoutStore,purchaseStore,passSale,delivery}.ts`; `fixtures/{catalog,directory,consentTemplates}.ts` | MODIFY |
| BFF credential services | `src/services/shortTermPass/{validity,passCredentials,qrRenderer}.ts`, `ports/passCredentialStore.ts`, `adapters/mock/passCredentialStore.ts` | NEW |
| BFF adapters | `src/services/shortTermPass/adapters/index.ts`, `{mock,platform}/catalog.ts`, `mock/{passSale,verification}.ts`, `smtp/mailer.ts`, `publisher/emailPublisher.ts` | MODIFY |
| BFF template/config/HTML | `adapters/smtp/templates/passReceipt.ts`; `src/env.ts`, `.env.example`, `package.json`, `package-lock.json`, `src/routes/static/index.html.ts` and token-path security/log middleware if required | NEW template; MODIFY remaining |
| BFF tests/demo | Route `__tests__/{checkouts,order,identify,verify,purchase,session,testingRoutes}.test.ts`; service consent/catalog/purchase/SMTP/publisher/config/adapters tests; NEW offer, public-pass, credential, validity, QR/template tests; `scripts/short-term-pass-demo.ts` | MODIFY / NEW; confirm exact existing test filenames with `rg` |
| UI contract/state | `src/interfaces/api/shortTermPass.ts`, `src/services/shortTermPass.ts`, `src/reducers/shortTermPass/shortTermPassSlice.ts`, `src/selectors/shortTermPass.ts` | MODIFY |
| UI checkout | `src/routes/ShortTermPass/{format.ts,steps/{Identify,NewVisitor,Recognized,Done}Step.tsx,components/{OfferCard,OrderSummary,PassBlock,ConsentBlock,CheckoutController}.tsx,hooks/usePayAction.ts}` | MODIFY |
| UI public pass | `src/routes/ShortTermPass/ViewPassPage.tsx`, `src/services/passCredentials.ts` | NEW |
| UI routing/styles/tests | `src/{App.tsx,common/constants.ts,styles/short-term-pass.scss}`; `__tests__/{App,routes/ShortTermPass,reducers/shortTermPass,selectors,services}/…` and shared pass test data | MODIFY / NEW tests |
| Planning/evidence during execution | Contract, demo doc, `docs/SEMANTIC-INDEX.md`, ledger; NEW Sprint 0003 smoke/traceability, parity-input files, screenshots and execution summary | MODIFY / NEW only during implementation |

This planning turn creates only `docs/sprints/drafts/SPRINT-0003-CODEX-DRAFT.md`. No source, contract, ledger, harness, chapter or prior sprint file is changed by drafting it.

## Definition of Done

Use **T0–T8** for this sprint, distinct from Sprint 0001 G-gates and Sprint 0002 S-gates. Assign named owners before sign-off; an owner slot alone does not sign a gate.

| Gate | Owner slot | Passes when |
|---|---|---|
| T0 — Contract ready | UI+BFF | v3 frozen at A2 with selected-offer lifecycle, range, generation and public credential contract; decisions/provisional defaults documented. |
| T1 — Multi-product checkout | PRODUCT+QA | U1–U7 pass through actual UI/BFF for Core; Riverside unchanged; selected amount/range survives verification/reload and appears in immutable purchase/consent evidence. |
| T2 — v4 UI | UI+DESIGN | CR-12/14/15/16 copy/layout checked at 1440/375 and breakpoint edges; done has no QR; provisional pass-page/email designs reviewed with recorded deltas. This is browser review, not parity termination. |
| T3 — Credential boundary | SECURITY+BFF | Cookie-free retrieval, club binding, bounded signed token, expiry/revocation, no-store/referrer protections, rate limits, PII allowlist and tracking/log-redaction tests pass; no public mutation or payment access. |
| T4 — Local pass email | QA+BFF | PR-06 proves CID QR rendered and decoded, complete receipt, working fresh-browser link for every duration; failed delivery leaves an accessible issued pass and honest copy. |
| T5 — Transaction/consent integrity | BFF+QA | Stale state refused before authorization; one consent/commercial snapshot; replay preserves link/pass without duplicate charge/mail; wallet retry isolated; existing compensation tests pass. |
| T6 — Quality and regressions | UI+BFF+QA | Lint/build/coverage meet unchanged floors; existing signup/guest/Pay Page, identity and wallet suites pass; explicit baseline failures remain visible and do not count as a clean run. |
| T7 — Traceability and deferred inputs | PRODUCT+QA | CR-10…17, PR-05/06 and CF-04…07 accounted for; v4 parity inputs complete; harness/agents still recorded deferred and unrun. |
| T8 — Handoff/status | UI+BFF | Evidence, contract/register, demo, code map, ledger and PR descriptions accurate; execution summary separates local proof from production gaps. |

**Completion vocabulary after these gates actually pass:** *v4 changes complete; pass email + link proven locally (Mailpit); live email unverified (publisher 503); hosted capture unverified (B1); parity and agents deferred*. Add *static QR only; desk verification and rotation unverified*. If a gate fails, identify it explicitly rather than using that completion sentence unqualified.

Sprint 0002's deferred parity/agent gates and pending S5 remain attached to their original status/evidence. L1–L5 remain open where previously open. New readiness rows: CF-04 pricing/catalog; CF-05 calendar-window/start-horizon policy; CF-06 link lifetime/recovery/admit interval/anomalies; CF-07 static versus link-only email; durable credential store and operational revocation; public HTTPS/image-proxy support; production issuer/verifier and rotating QR; pass-email/page design approval. Counsel action (e) template feasibility can cite Sprint 0002 evidence; it does not mean counsel approved the text. CF-01…03 remain open.

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | Product choice is lost at verify/reset or mismatches consent/amount. | Persist selected id, update every first-offer call site, atomic generation tests, immutable purchase snapshot. |
| R2 | Existing latest-request UI logic masks stale server writes. | Serialize edits; compare generation at store commit; race with verify/purchase; reject rather than silently overwrite. |
| R3 | DST/browser timezone or a changed date horizon shortens a pass. | Calendar-date arithmetic plus tested local-boundary conversion; keep start-horizon semantics explicit; reject invalid combinations. |
| R4 | Static club terms fail to reflect product changes. | Revision binds commercial fields even under overrides; retain override precedence and test stale acceptance. |
| R5 | Public route falls into completion bootstrap or membership loading. | Exact token-route match first; fresh-browser/no-club integration tests; independent public service and API fallback tests. |
| R6 | Tokens leak through referrers, instrumentation, screenshots or generic state hooks. | Protect HTML as well as JSON/image; suppress URL tracking on token surface; redact paths/evidence and allowlist DTOs. |
| R7 | CID and publisher HTML behave differently; external images are blocked or cached. | Transport-specific image strategy, text/View fallback, Mailpit MIME/decode proof, distinct live publisher gate. |
| R8 | A static PNG or signed web link is mistaken for a secure door credential. | Explicit mock payload classification; same-payload tests only; real window/revocation/reuse verification is L2, rotation deferred. |
| R9 | Checkout sweep/restart destroys access to paid passes. | Separate store lifetime from checkout; prove checkout-expiry survival; label process restart limitation and block production until durable storage. |
| R10 | Credential/email failure causes duplicate charge or refund of an issued pass. | Separate registration/delivery outcomes; no automatic purchase retry; idempotent registration and replay/fault tests. |
| R11 | Pricing, layouts or window decisions arrive late. | Isolate catalog data and templates; proposed defaults at A2; register unresolved live policy rather than invent approval. |
| R12 | Harness work or inherited defects expand the sprint. | Inputs only for PR-05; bounded smoke; keep Q-1 brand casing and Q-2 recognized-mobile persistence visible unless explicitly included by interview. |
| R13 | Club sales flag disables retrieval of an already-paid pass. | Retain current fail-closed gate for local scope, test it, and require a separate credential-availability policy before rollout. |

## Dependencies

- UI React 17/router v5/RTK/MUI v4/webpack/Jest; BFF Node ≥22, Koa, TypeScript `erasableSyntaxOnly`. Use ordinary fields/private fields rather than parameter properties. Existing branch/prerelease/Husky behaviour must be preserved.
- BFF Node QR renderer plus typings if needed; test-only decoder for scannability proof or an existing local decoder. Confirm compatible package versions at implementation time; this draft does not assert a registry version. No browser QR library in the mailer.
- Mailpit running locally on SMTP :2525/inbox :8025; BFF :3000 serves/proxies UI with working `/signup` history routing. Local mock adapters, hooks and clock continue existing boot restrictions. Never print `.env` values or secret-bearing URLs.
- New explicit public base URL and dedicated signing-secret configuration; platform durable credential store/key provisioning is a rollout dependency, not a local demo prerequisite. A maintained timezone utility may be needed if existing BFF date facilities cannot reliably resolve local midnight.
- PRODUCT/PM for CF-04/05/07, ENGINEERING+SECURITY+PM for CF-06, DESIGN for two new surfaces, PLATFORM for public ingress/log redaction/durability, QA for evidence. Name people/dates at kickoff.
- B1 credentials and publisher availability remain external blockers to their own proofs. No hosted or live email claim follows from mock tests. Wallet writes remain gated behind existing L3 prerequisites.
- Semantic prior art: index routing confirms wallet ownership invariants only. Primary implementation evidence is the actual Online Join source map above; no full cache scan or semantic-index rebuild is required.

## Open Questions

The proposals below make implementation reviewable. They are not silent claims that CF items have been approved. Freeze answers/defaults at A2; unresolved commercial/live policy blocks the named capability, not unrelated local work.

| # | Decision surface | Proposed answer | Owner / effect if unanswered |
|---|---|---|---|
| OQ-1 | Dedicated offer route or pre-verification `PUT /order`? | Dedicated `PUT /offer`, selected id on checkout, no pre-verification order. Return `offers[]` plus selected `offer` for migration. | UI+BFF; settle before v3 freeze. |
| OQ-2 | Preserve start date and acceptance on selection? | Keep valid date/adult/preferences; reset waiver only if its hash changes; reject incompatible horizon; always refresh purchase attestation. | PRODUCT+BFF; documented A2 default. |
| OQ-3 / CF-04 | Which clubs/durations/prices and real catalog source? | Core 1/3/5 at $25/$60/$90, latter two marked provisional in capability data; Riverside single $18. Explicitly resolve CR-10 text discrepancy. | PRODUCT; fixture demo proceeds, live catalog blocked. |
| OQ-4 / CF-05 | Calendar days or elapsed hours; does max booking date constrain end; maximum duration? | Consecutive inclusive calendar days; maxDaysAhead constrains start; only 1/3/5 configured here; Q19 remains open. | PM; broader product/live semantics blocked. |
| OQ-5 / CF-06 | Link lifetime, resend, revocation operations and admit interval? | View immediately through end-of-window +24h, no admission grace, internal revoke, no public resend; production recovery/admit/anomaly rules deferred. | ENGINEERING+SECURITY+PM; local proposal testable, rollout blocked. |
| OQ-6 / CF-07 | Static QR everywhere or link-only per club; rotation now? | Static same payload in email/page for this sprint; CID locally, hosted image for publisher. Record link-only configuration and rotating verifier as follow-on unless expressly chosen. | PM+PASS; do not claim full D41/§5A completion. |
| OQ-7 | Missing email/page design and done-link placement? | Reuse verification-email language and scoped pass UI; link beneath done pass copy and in receipt. Record explicit DESIGN-reviewed additions. | DESIGN; local proposed layout proceeds, design gate needs review. |
| OQ-8 | Failed/pending delivery and publisher queue acknowledgement? | Keep truthful variants; publisher pass acknowledgement maps to pending, SMTP accepted send to sent. Receipt fine print follows same status. | PRODUCT+BFF; freeze result semantics with v3. |
| OQ-9 | Generation migration on older clients and all mutating calls? | Coordinate UI/BFF deploy; v3 mutations carry generation (DELETE/header cases specified at freeze); old clients must reload, no silent stale writes. | UI+BFF; resolve request/header matrix before coding. |
| OQ-10 | Do sales flags also disable access to issued passes? | Retain existing pass-derived gate locally; split sales enablement from issued-pass retrieval only after explicit policy approval. | PRODUCT+SECURITY; production retrieval policy remains open. |
| OQ-11 | Include inherited Q-1 brand casing/Q-2 recognized-mobile persistence? | Carry visibly; this sprint changes mobile helper only. Reproduce if encountered; add a scoped fix only if needed for selected acceptance cases or interview expands scope. | PRODUCT+UI+BFF; do not claim those older defects resolved. |
| OQ-12 | Branches, workstreams and harness authorization? | Same branches/PRs, contract first, catalog/UI vertical slice before credentials; parity input files only. | Existing direction applies; no harness execution until user explicitly authorizes it. |

The next review should settle the v3 selection/generation contract and CF-04…07 defaults first; those choices determine the remaining implementation without changing the inherited payment, identity or sprint-status boundaries.
