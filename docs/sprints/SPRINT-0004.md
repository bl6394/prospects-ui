# Sprint 0004: Guest Pass v1 — catalog-flagged single-visit passes from DataTrak, begin-on-purchase validity, DT-rendered QR by email, legal opt-in, create → pay → deactivate, and a standalone Guest Pass host

**Status:** planned, 2026-09-17 (three drafts, three critiques, interview and merge complete; see `docs/sprints/drafts/SPRINT-0004-*`). Owners named at kickoff.

**Sources (precedence in this order):** `docs/prd/Consolidated_PRD_v3.6.md` (Rounds 5–7, D48–D74; §4.6 rewritten; §9 non-goals), `docs/prd/Change_Requests_2026-09-10_v3.md` (CR v3; ids below are CR v3 unless qualified), `docs/prd/Next_Steps_2026-09-10_v2.md`, `docs/prd/day-passv6.html` (design source of truth under D46; supersedes v4). Where these contradict Sprint 0003's sources (`Change_Requests_2026-09-15.md`, `day-passv4.html`, PRD v3.4), the new files win (interview 2026-09-17).

## Pyramid Index

- **L0:** Re-aim the merged Day Pass build at the Round 5–7 product: a Guest Pass page, in the two Online Join repos but served at its own standalone host, that lists the catalog products a club flagged "Guest pass online" (read through the DataTrak service layer MICO uses), sells one single-visit item whose window starts at purchase ("You have X days to use this pass · use by {date}"), creates the DT prospect before payment with begin = today, expiration = today + contract days − 1 and visits = 1, deactivates it on a confirmed decline, saves the card only after a successful authorization, records the legal opt-in as consent evidence, removes the 18+ checkbox, the date picker, the on-page QR and the pass page, leaves QR rendering and the credential email to DataTrak, and corrects the one-time code to 5 minutes / 2 sends per hour — proven with mock adapters in two weeks, with live DataTrak reads and writes, hosted capture, the standalone host and the pilot checks as separately owned gates.
- **L1:**
  - **A — Contract v4 freeze, reconciliation, fixtures, feasibility (both lanes, ~2 days).** Per-capability keep/remove list executed as `rg`-provable removal inventories; `OfferSummary {contractDays, visits, validityLabel}` replaces `durationDays`/`validUntil`; server-owned `beginDate`/`expirationDate`/`useBy`; no writable `visitDate`/`adult`; `marketing` consent document; `ProspectPort {create, repaint, deactivate, revert}`; day-one probe of the DataTrak service endpoints; SPRINT-0002 closed in the ledger.
  - **B — BFF (CR-06, 09, 12, 14, 15, 20, 25, 28, 29, 31, 32, 35; D61, D62, D65, D71, D72; ~5.5 days).** OTP constants to D58/D59 first; catalog port on contract days + visits with the v1 single-visit filter and no fixture fallback in production; gate = flag AND eligible flagged items (not `onlineProspects`); purchase order `VALIDATED → PERSON_PERSISTED → AUTHORIZED → WALLET_RESULT → SALE_FINALIZED → COMPLETE` with deactivate/revert compensation, the `unknown` authorization branch kept as a status lookup, `RECONCILING` and an owner-only compensate route; opt-in as a versioned consent document; expired saved cards refused; OTP template slot; DataTrak service catalog adapter; host-scoped routing; production guard extended.
  - **C — UI (CR-09, 13, 14, 15, 25, 26, 35; Design v6; ~4.5 days).** Offer cards from flagged items with the validity line; no date field; "use by" row; waiver + optional marketing checkbox with the legal text in a dialog on both lanes; no 18+; five-minute expiry countdown beside the resend cooldown; expired-card chip → hosted Pay Page; returning lane re-accepts Pass Terms and waiver; done page with the v6 copy and truthful delivery variants; `/guest-pass` route; router base made host-aware.
  - **D — Standalone host and platform wiring (orchestrator + PLATFORM, ~2 days, from day 3).** `guestpass.dev.abcfitness.net` on the existing BFF ingress, `STP_STANDALONE_HOSTS`, both origins allowed, guest-pass Pay Page routes allowed on that host, the three pass-link keys removed from helm, LD flag `guest-pass-online`, Cloudflare and DT-credential tickets, the pilot-gate checklist with owners.
  - **E — Proof (~2 days).** Unit and route tests per CR; demo 0–5; local browser smoke (Mailpit, fixture cards, decline → deactivate, decline → revert, expired card, flag off, alias route); dev smoke on the existing host and the standalone host with the pinned code, hooks via `kubectl port-forward`; contract v4, traceability, registers, code map, ledger.
- **L2:** §Overview (positions on the three decisions; disposition table; corrections) · §Use Cases (U1–U27) · §Architecture (catalog and DT read path; validity; purchase order and recovery; consent and opt-in; OTP template; hosting; UI structure) · §Implementation Plan (A–E with files and "done when") · §Files Summary · §Definition of Done (V0–V8; pilot gates V-P0…V-P6; completion vocabulary) · §Risks & Mitigations · §Dependencies · §Open Questions (RQ/CF registers; deferred-to-v2 list).

## Overview

Sprints 0001–0003 built a Day Pass checkout inside Online Join and merged it to `main` on 2026-09-17 (UI 8.33.0-daypass.2, BFF 1.2.0), dark behind a flag, deployed to the dev cluster in mock adapter mode with a pinned one-time code (helm-configs #3083, #3088). The four files dated 2026-09-10 (Rounds 5–7) describe a different v1 from the one Sprint 0003 built from Design v4 on 2026-09-15: single-visit passes configured on catalog products, no start date, DataTrak as the only QR renderer, no age gate, a legal opt-in, create-then-deactivate on payment failure, and a standalone Guest Pass URL. This sprint changes the existing implementation to that v1. It does not rebuild it, does not fork MICO, does not start the deferred harness lane, and does not claim live DataTrak behaviour it cannot observe.

### Decision 1 — reconciliation with Sprint 0003 (interview: remove)

Rounds 5–7 supersede Sprint 0003's sources. Cancelled surfaces are **removed**, not hidden: dead public credential routes are a security surface, a dual-mode test burden and a temptation a dev value can flip on. Git (`main` history, tag `prospect-wallet/sprint-0003-history-20260917`) preserves the work. Contract days remain a redemption window, so the inclusive calendar arithmetic and date helpers stay; the commercial model and copy change.

| Sprint 0003 capability | Fate | Code paths |
|---|---|---|
| Offer selection grid (`PUT /checkouts/:id/offer`, `selectedOfferId`, generation bump) | **Keep** — repurposed as the list of flagged catalog items (D61, D68, CR-28); `.days` line becomes the item's validity sentence | `BFF/routes/shortTermPass/offer.ts`, `checkouts.ts`; `UI/routes/ShortTermPass/components/{OfferCards,OfferCard}.tsx`; slice `selectOffer` |
| Multi-day validity range (`durationDays`, `validUntil`, range labels, `STP2` payload, `maxDaysAhead`) | **Remove the range model**; replace with `contractDays` + `visits` and `useBy`/`expirationDate` computed from the purchase day (D62, D71, D72); keep calendar-day helpers | `STP/validity.ts` (rewrite), `STP/order.ts`, `ports/passSale.ts`, `adapters/mock/passSale.ts`, `STP/receipt.ts`, schemas; UI `format.ts`, `OrderSummary.tsx` |
| Start-date picker (`visitDate`, `minVisitDate`, `maxVisitDate`, "Pass starts on") | **Remove** (D71, CR-35); client `visitDate` rejected by schema | `UI/…/OrderSummary.tsx` date field, `.dayfield` in `short-term-pass.scss`; `OrderRequest.visitDate`, `isVisitDateAllowed`, `dateFieldLabelOf`; fixture `maxDaysAhead` |
| Pass page and QR routes (`GET /passes/:token{,/qr.png}`, `pv1` tokens, credential store, pass-link routes, hooks revoke, history-fallback rewrite, log redaction, AppDynamics skip) | **Remove** (D63, §9); retired paths answer the router's generic 404 | `BFF/routes/shortTermPass/passes.ts`, `purchase.ts` (pass-link), `testing/routes.ts` (revoke), `STP/{passCredentials,passView,qr}.ts`, `ports/passCredentialStore.ts`, `adapters/mock/passCredentialStore.ts`, `utils/middlewares/historyFallback.ts` (`PASS_VIEW_REWRITE`), `utils/logRedaction*`, `routes/static/index.html.ts` skip; UI `PassViewPage.tsx`, `components/{PassCredential,PassReceipt}.tsx`, `PAGES.passView`, `App.tsx` `matchPath`, `services/shortTermPass.ts getPassView`, thunks `loadPassLink`/`resendPassEmail`; deps `qrcode`, `@types/qrcode`, `jsqr`, `pngjs`, `qrcode.react`; env `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS` (config, boot guard, `.env.example`, helm) |
| Pass email with QR image (`renderPassMail`, CID / hosted PNG) | **Mock mode only** as a labelled stand-in for the DT prospect email — no QR image, barcode as text; platform mode sends nothing for the pass (`delivery.renderer:'dt'`) | `adapters/smtp/templates/passEmail.ts` → `prospectMailStandIn.ts`, `adapters/smtp/mailer.ts` (drop CID), `adapters/publisher/emailPublisher.ts`, `ports/delivery.ts` |
| 18+ checkbox (`adult`, `ADULT_TITLE`, `orderReady` rule, snapshot `adult`) | **Remove** (D66, CR-26); historical snapshots untouched; fallback waiver copy containing "18 or older" goes to Kelly (CF-08), never rewritten silently | `UI/…/ConsentBlock.tsx`; `OrderRequest.adult`, `OrderConsents.adult`, `orderReady`, `PurchaseConsentSnapshot.adult`, `buildConsentSnapshot`; `fixtures/consentTemplates.ts` |
| Receipt snapshot and on-page receipt | **Keep** with `beginDate`/`expirationDate` instead of `visitDate`/`validUntil` (D52 POS receipt still arrives from DT) | `STP/receipt.ts`, `ports/purchaseStore.ts`, `OrderSummary.tsx` receipt rows |
| Done-page copy, "View your pass", "Resend pass email" | **Replace** with v6 copy; resend is a DT concern (RQ-2) | `UI/…/PassBlock.tsx`, `steps/DoneStep.tsx` |
| Kelly Reyes fixture, mobile-helper removal, `generation` rule, OTP for every buyer, consent set with hashes, one snapshot per purchase, Pay Page capture, loopback-only test hooks | **Keep unchanged** | — |

### Decision 2 — home and repo (interview: existing repos, standalone host; CF-11 answered)

The merged build never touched the membership model: it has its own route, shell, BFF router, stores and consent set. What D60 asks for — a URL a club can put behind a "Buy a day pass" button, not inside the join funnel — is a **hosting** change: a second host (`guestpass.dev.abcfitness.net`, later `guestpass.abcfitness.com`) on the existing BFF ingress, host-scoped routing so `/` and `/guest-pass` on that host serve the Guest Pass entry document and membership paths answer 404 there, the guest-pass Pay Page routes (`/api/pay-page/*` used by card capture) allowed with their existing ownership controls, both origins in `STP_ALLOWED_ORIGINS`, the UI router base made host-aware (`index.tsx` hard-codes `basename="/signup"` today). Cost ~2 days plus tickets. Alternatives recorded: a MICO fork (Java port of OTP, session, consent, Pay Page, orchestration: 6–10 weeks, loses ~1,400 tests, re-enters the monolith) and new `guest-pass-*` repos (~1 week extraction plus CI/publishing/helm/Sonar/LD — the right v2 step if the product grows past a checkout).

### Decision 3 — DT read path (interview: DataTrak service layer, as MICO does)

MICO has no Oracle connection (`build.gradle` excludes the JDBC/JPA starters). Every DataTrak read and write goes through the `OrasvcClient` Feign client or `oraSvcRestTemplate` to DT's `.spr` web services: `/pos/saleItems.spr` (online sale items — `catalogItemName`, `catalogPrice`, `taxed`, `unlimited`), `/external/club/getClubDefaultExternal.spr` (club online settings, `prospectTerms`), `/member/addProspect.spr`, `/pos/onlineSale.spr`. "Read DT configuration like Myko" therefore means that layer. New adapter `DatatrakServiceCatalog` implements `ClubCatalogPort` behind `STP_CATALOG_SOURCE=datatrak` with the same credential MICO uses (via `envsecretRefs`), a short cache, an authoritative club timezone, fail-closed per club when a field is missing, and recorded (or, until Chancy's DT PR lands, clearly labelled **synthetic**) response fixtures. Direct Oracle (driver, credentials, network path, VPD context call, schema nobody here holds: 4–6 days plus approvals) and a MICO facade endpoint (Java owner + MICO release + one more hop) are recorded alternatives; wallet-account-sync is the wrong owner and the wrong data.

### Decision 4 — delivery bar (interview: mock-proven in two weeks, live gated)

Sprint gates V0–V8 pass on mock adapters locally and in dev (mock mode, pinned code). Live catalog read, live prospect create/update/deactivate, hosted capture (B1), the standalone dev host, and every pilot check carry their own verdict and owner (V-P0…V-P6). Passing V0–V8 never authorises enabling a club.

### Corrections recorded

- **OTP constants:** `challenge.ts` on `main` has `CODE_TTL_MS = 10 min`, `SENDS_PER_ADDRESS = 5`; D58/D59 say 5 minutes and 2 sends per address per hour. CR-10/CR-30 are marked "Done" in CR v3 but are not implemented; B1 fixes them first. The 30 s resend cooldown stays; the UI shows the five-minute expiry as its own countdown.
- **Numeric keypad (CR-13):** already present (`inputMode="numeric"`); this sprint pins it.
- **"Live" catalog:** `PlatformClubCatalog.getOffers()` returns `FIXTURE_OFFER` and hard-codes `America/Chicago`; production must refuse every fixture-bearing source, not only `STP_CATALOG_SOURCE=fixture`.
- **Production guard:** does not refuse `STP_MOCK_OTP_CODE` (set in dev helm); B10 adds it.
- **Gate coupling:** `requireShortTermPass` still requires the club's free-trial `onlineProspects` setting; D61 replaces the enable switch with the presence of eligible flagged items.
- **Design v6 is a prototype, not a spec, in four places:** `VALID_DAYS = 30` and `today + 30` arithmetic (D71: days from the item, inclusive `− 1`); `adultCb` still gates Pay in its script (D66); the refund sentence "before the pass is first used" contradicts PRD D15/D22 (CF-16; PRD sentence stays); "Core South" hard-coded in the marketing paragraph (`{legalName}` interpolated). Recorded as approved deltas.
- CR-08 "visual parity with HTML v1.2" is superseded by v6 under D46.

## Use Cases

Fixtures (mock adapters): **90030 Riverside Athletic Club** — pilot shape: one flagged product `day-pass` "Day Pass" USD 18.00, contract days 1, visits 1; Jordan Reyes `jordan.reyes@email.com` (returning, saved Visa 4242, `access` from a past pass). **90033 Core Health and Fitness Club — South** — layout club: three flagged **single-visit** products `core-day-pass` "Day Pass" $25 / 1 day, `core-flex-pass` "Flex Day Pass" $30 / 7 days, `core-anytime-pass` "Anytime Day Pass" $35 / 30 days, plus one flagged `visits: 3` item that v1 must hide, and one unflagged item; Kelly Reyes `m@m.com` (returning, saved Visa 4242, `marketingOptIn` known); Priya Patel `priya@example.com` (returning, saved Mastercard **expired** 2026-08). Windows other than 1 day prove arithmetic and layout; they are not permission to configure a multi-day pilot.

| ID | Behaviour and required result | CR / PRD | Tasks |
|---|---|---|---|
| U1 | Identify at Core: "Get your day pass!"; three `.offer` cards (radiogroup "Choose a pass") with price, catalog name and validity line "One time use only, valid today" (1 day) / "One time use only, valid for 7 days" / "… 30 days"; the 3-visit item and the unflagged item are **absent**; first card pre-selected; sidebar skeleton | CR-28, D68, D72 | B2, C2 |
| U2 | Identify at Riverside: one card `.offers.single` "Day Pass · $18 · One time use only, valid today" | CR-28 | C2 |
| U3 | Select another card: toast "{name} · ${price}", `PUT /offer {offerId, generation}` persisted, survives reload and Change; stale generation → 409 `STALE_GENERATION` rollback (Sprint 0003 behaviour kept) | CR-28 | B2, C1 |
| U4 | Verify → order shell: `{offerId, offerName, amountMinor, currency, contractDays, visits: 1, useBy, consents, saveCard, ready}`; **no** `visitDate`, `minVisitDate`, `maxVisitDate`, `durationDays`; `useBy` = club-local today + contractDays − 1 (a quote; recomputed at purchase) | CR-35, D71 | B3 |
| U5 | Sidebar: **no date field**; line item "{name}" and amount; "Valid" row "One time use only, valid for 7 days · use by Wed, Sep 23" (1 day: "One time use only, valid today · Thu, Sep 17"); waiver checkbox; marketing checkbox; Pay "Pay $30.00 and get my pass" carrying the Pass Terms attestation; `order.ready` = waiver accepted when required — no adult term | CR-35, CR-26, D66, D71 | B3, C3, C4 |
| U6 | Pass Terms dialog (template `2026-09.3`): "Flex Day Pass to Core Health and Fitness Club — South. One time use only, valid for 7 days · use by Wed, Sep 23. Price $30.00 including tax. One-time purchase — no membership, no renewal, no recurring billing." + PRD refund sentence; `consentRevision` binds `offerId\|amount\|currency\|contractDays\|visits\|useBy` | CR-02, D71, CF-16 | A3, B3 |
| U7 | Marketing opt-in: checkbox "Yes, send me **marketing** offers (Optional)"; "marketing" opens `DocumentDialog('marketing')` with the legal-written text (`{legalName}` interpolated; `approval:'PROPOSED'` until CF-09); unchecked by default; opening the dialog does not opt in; never gates Pay; shown on **both** lanes; `PUT /order {marketingOptIn}` records `{optedIn, templateVersion, renderedHash, at}`; snapshot keeps the exact text hash; explicit `false` reaches the create/repaint call | CR-09, D67, CF-09 | B5, C4 |
| U8 | New visitor Pay: `POST /purchases` → **prospect created first** (mock directory) with `{firstName, lastName, email, phone, beginDate: today(club), expirationDate: today + contractDays − 1, visits: 1, marketingOptIn, saleItemId, paymentTokenReference}` → authorize → wallet save (only if asked) → sale → COMPLETE; `person.created:true`; `pass = {status:'issued', label, beginDate, expirationDate, visits:1}`; **no** `qrPayload`, **no** `viewPath`; `delivery = {status:'delegated', renderer:'dt'}` in platform mode, `sent` from the stand-in in mock mode | CR-12, CR-32, D62, D71, D72 | B4 |
| U9 | New visitor, confirmed decline (mock fault `decline` / fixture card): prospect created → authorization declined → **prospect deactivated** (`ProspectPort.deactivate(memberId, {purchaseId})`, stable key) → `FAILED {failure.step:'authorize', person:{created:true, deactivated:true}, payment:{status:'declined'}, wallet:{status:'not-requested'}}`; UI: "Payment didn't go through" → "Try another card" starts a new purchase on the same checkout; the retry reuses the known (now inactive) record's identity resolution without creating an ambiguous duplicate; attempt log line `purchase.attempt {club, purchaseId, outcome}` without PAN, token or email | CR-32, CR-06, D65 | B4, B7, C5 |
| U10 | Deactivate fails (fault `deactivate-failure`): one immediate retry then `RECONCILING {failure.step:'deactivate'}`, log `prospect.deactivate-failed {memberId, purchaseId}`; UI safe message with reference and no second Pay; owner-only `POST …/purchases/:pid/compensate` retries only the deactivate; a process-local sweep retries pending compensations while the process lives; already-inactive → `ok` | D65, PR-14 | B4 |
| U11 | Authorization **unknown** (timeout/throw): `PaymentPort.status` lookup by stable reference; unresolved → `RECONCILING`; **never** treated as a decline, **never** deactivates a possibly paid prospect (existing behaviour kept, thrown-transport path tightened) | D65 | B4 |
| U12 | Returning buyer (Kelly) Pay: existing club-scoped record **repainted** (`ProspectPort.repaint(memberId, {beginDate, expirationDate, visits, marketingOptIn, saleItemId})`) with the previous access snapshot kept on the purchase; decline → **revert** to the previous begin/expiration/visits (mock proves it; live semantics gated on CF-15/RQ-4); success → COMPLETE with `person.created:false`; club default trial settings never touched | CR-12, D53, D62 | B4 |
| U13 | Returning lane re-accepts Pass Terms (Pay-tap attestation) **and** the waiver every purchase; no 18+ anywhere; marketing checkbox present with the stored value pre-filled when known | CR-14, CR-26, D53 | B5, C4, C6 |
| U14 | Returning buyer with an **expired** card (Priya): `GET /wallet` → `cards[].expired:true` (end of `expMonth/expYear`, club-local); chip disabled "This card has expired"; hosted slot is the only option; `POST /purchases {payment:{kind:'saved'}}` with an expired `selectionRef` → 400 `VALIDATION_FAILED` "That card has expired. Add a different card." | CR-15, D53 | B8, C6 |
| U15 | Save card only on success: with `saveCard:true`, a declined authorization writes nothing to the wallet; `WALLET_RESULT` follows `AUTHORIZED` only; wallet-only retry reuses the same `providedId` and never re-charges | CR-06, D65 | B4 |
| U16 | Done page (v6): "You're in, Kelly" / "Your pass is ready"; `.big` "Flex Day Pass · use by Wed, Sep 23"; `.sm` "**Check your email** — we've sent your QR access code directly to m•••@m.com. Show it at the door, or just say your name at the front desk."; **no** "View your pass", **no** "Resend pass email", **no** QR, no `svg`/`.qr`; receipt with number, item, amount, "Valid · use by …" | CR-25, D63 | C5 |
| U17 | Done page truthful variants: mock `delivery.failed` → "We couldn't send your QR access code to {masked}. Say your name at the front desk — your pass is ready."; `pending`/`unknown` → "Your QR access code is on its way to {masked}…"; platform `delegated` → the v6 sentence | CR-25 | C5 |
| U18 | OTP email from the template slot (`STP_OTP_TEMPLATE_PATH` or the built-in PROPOSED template) with `{{code}}` and `{{clubName}}` only; club name from the catalog club; Mailpit shows the injected code; dropping in Chancy's HTML changes no test | CR-29, CR-34, D59 | B9 |
| U19 | Code entry: six digits; `inputMode="numeric"`, `autoComplete="one-time-code"`, `pattern="[0-9]*"`; **five-minute expiry countdown** from the server `expiresAt`, distinct from the 30 s resend cooldown; 2 sends per address per hour across checkouts → `THROTTLED` with `retryAfterSeconds`; "change email" without consuming a send | CR-10, CR-13, CR-30, D54, D58 | B1, C7 |
| U20 | Catalog via the DataTrak service layer (`STP_CATALOG_SOURCE=datatrak`, dev, gated CF-13/14): club defaults and flagged items mapped; an item missing `contractDays`/`visits`/price is skipped with a capability warning; `visits > 1` skipped in v1; service-type items skipped (D70); mapper tests run against the recorded/synthetic fixtures; capability report separates club, offers, consent texts, timezone | CR-31, D61, D64, D70 | B11, A4 |
| U21 | Mock stand-in for the DT prospect email (mock mode only): subject "Your Day Pass at {club}", banner "Stand-in for the DataTrak prospect email — DataTrak sends the real one with the QR", barcode as text, pass dates, acknowledged Pass Terms / waiver / opt-in texts (D52), receipt block; **no QR image**, no link; platform mode sends nothing from the BFF for the pass | D52, D63 | B6 |
| U22 | Standalone host (`STP_STANDALONE_HOSTS=guestpass.dev.abcfitness.net`): `GET https://guestpass.dev…/?club=90030` and `/guest-pass?club=90030` render the checkout (router base host-aware); `/signup/plan` → 404 on that host, 200 on `onlinejoin.dev…`; `/api/short-term-pass/*` and the guest-pass `/api/pay-page/*` routes work on the new host; other APIs 404 there; `Origin` allowlist includes both; a hosted-card checkout completes on the new host; cookie `Secure` behaviour unchanged (PR #106) | D60, CR-27 | B12, C8, D1–D3 |
| U23 | LaunchDarkly flag `guest-pass-online` (club context) AND at least one eligible flagged item gate every route and the UI hint; flag off or no items → 404 / unavailable block; a flagged paid item with online free trials disabled still sells; `STP_LOCAL_FLAG_OVERRIDE` unchanged | CR-20, D50, D55, D61 | A2, B2, B12, C8 |
| U24 | Purchase rate limit: 10 `POST /purchases` per IP per hour → 429 `THROTTLED`; identify limiter unchanged; capability report names the Cloudflare rule as the outer limit | CR-32, D65 | B7 |
| U25 | Production boot guard refuses: every fixture-bearing catalog source, mock adapters, hooks, the flag override, `STP_MOCK_OTP_CODE`, a missing DT credential in platform mode; it no longer knows the three pass-link keys | D65, R7 | A2, B10 |
| U26 | Demo (`npm run demo:short-term-pass`): 0 OTP indistinguishable; 1 Riverside new visitor success; 2 Kelly returning, Core, three items; 3 new visitor decline → deactivate → retry success; 4 Kelly decline → revert; 5 Priya expired card → 400 then hosted; 6 deactivate failure → RECONCILING → compensate | all | B13 |
| U27 | Dev smoke against `onlinejoin.dev.abcfitness.net` and, after D1/D2, `guestpass.dev…` (mock mode, pinned code, Pay Page test card): identify → code → Kelly → done copy; state read through `kubectl port-forward` to the pod (loopback rule intact) shows `pass.beginDate = today` and no `viewPath`; the browser never reads `/testing/*` through the ingress | PR-02, Q8 | E3 |

Regression (always): Sprint 0001–0003 suites green minus deleted files; OTP for every buyer and lookup after consumption; one active purchase per checkout; hooks-only mock capture; no third-party fonts; no horizontal overflow 320–440 px with three cards; membership signup and Pay Page suites untouched; D12 member block unchanged (recognized members still cannot buy).

## Architecture

### 1. Catalog model and DT read path (D61, D64, D70, D72; CR-28, CR-31)

`CatalogOffer {offerId (= saleItemId), catalogItemId, type:'product', guestPassOnline, name, amountMinor, currency, taxed, contractDays, visits, sourceRevision}`; `CatalogClub` gains `waiverText?`, `timezone` (authoritative), `legalName`. `requireOffers` applies the v1 filter (flagged, product, `visits === 1`, positive price, valid days) and reports skipped items in the capability report; purchase **refuses** a multi-visit item rather than coercing visits. `STP_CATALOG_SOURCE ∈ {fixture, datatrak}`; production refuses `fixture` and any source that can return fixture offers (the old `mico` hybrid is removed). `DatatrakServiceCatalog`: `resolveClub` ← `getClubDefaultExternal.spr` (name, timezone, `prospectTerms`, waiver text); `getOffers` ← `saleItems.spr` filtered on the new flag/days/visits fields (Chancy's DT PR; CF-13) — content type, query names, base path, auth and timeouts verified per endpoint in A4, not assumed; pre-identity call without a member id is CF-14. Cache 60 s per club; commercial fields re-read before side effects; a change returns a refreshed 409, never a silent reprice.

### 2. Validity (D48, D62, D71, D72)

`beginDate` = club-local purchase date; `expirationDate = beginDate + contractDays − 1` (inclusive); `visits` from the item (1 in v1); `useBy` shown before purchase is a quote recomputed at `validatePurchase`; midnight rollover between render and Pay → 409 `CONSENT_REVISION` with the refreshed order. Browser timezone and DST cannot move the dates (tests: month/year/leap day, DST, browser zone ≠ club zone). Never hard-coded: a static scan for numeric literals in customer copy is part of V1.

### 3. Purchase order and recovery (D65, CR-32, CR-06, CR-12, PR-14)

```
validate (identity, eligibility, owned payment source, catalog, consent revision)
→ reserve idempotent purchase + one consent snapshot
→ PERSON_PERSISTED: create new / repaint existing club-scoped prospect
   {begin, expiration, visits, marketingOptIn, saleItemId, paymentTokenReference}
→ AUTHORIZED: authorize against that prospect (unknown → status lookup → RECONCILING)
→ WALLET_RESULT: save card only if auth succeeded AND save-card consent on
→ SALE_FINALIZED: record product sale + confirm capture
→ COMPLETE (delivery status may still be pending / delegated)
```

| Outcome | Recovery and visible result |
|---|---|
| Contact conflict / validation before create | No payment; re-verify; no binding from an untrusted create response |
| Create definite failure | No authorization; retry only if no mutation occurred |
| Create response lost | Lookup by operation key; reuse; unresolved → `RECONCILING`, no fresh create/auth |
| Authorization confirmed declined | `deactivate` (new record, key `{purchaseId}:deactivate`) or `revert` (repainted record); no wallet save, no sale; `FAILED` only after compensation confirmed |
| Deactivate / revert failure or timeout | one immediate retry → `RECONCILING`; owner-only compensate route and process-local sweep retry only that step; no create/pay replay |
| Authorization unknown | status lookup by stable reference; unresolved → `RECONCILING`; never "not charged", never blind deactivate |
| Wallet failure after confirmed auth | retryable wallet outcome, sale continues; wallet-only retry with the same `providedId` |
| Sale failure before capture | void auth, compensate prospect; unknown void/compensation → `RECONCILING` |
| Capture unknown after sale | resolve provider status; no second sale/capture; no success claim until confirmed |
| Confirmed payment, DT delivery failure | paid receipt kept, truthful delivery status, desk fallback; no BFF credential fallback |
| Replay / concurrent | same key + fingerprint → same result; different body → conflict; unresolved purchase blocks a new one for that checkout |

"Attempts logged, not persisted" (D65) forbids a failed-attempt reporting feature; it does not permit dropping idempotency or compensation state. Stores are in-memory in both modes today: durable checkpoints and service-owned reconciliation are a named live-readiness gate (V-P1), not sprint scope. Compensation for a repainted record is scoped to the prepared mutation/revision; the overlapping-active-pass case is excluded from the pilot until DT's conditional-update semantics are confirmed (CF-15, RQ-4). No `STP_CREATE_BEFORE_PAY` switch: the v2 direction (no record until payment) is a register row.

### 4. Consent set, opt-in and the create call (D67, CR-09, D52, D53)

One acceptance model: Pass Terms attested on the Pay tap (as built), waiver as a separate required checkbox, marketing as an optional checkbox whose document is `marketing` in the §4.5 set with `templateVersion` and `renderedHash`. `OrderConsents.marketingOptIn {optedIn, templateVersion, renderedHash, at}`; the purchase snapshot records checked state, timestamp and hash; the value (explicit `false` included) travels on create/repaint. Waiver acceptance resets each purchase. `adult` leaves every schema and snapshot. Fallback waiver copy that still says "18 or older" is a CF-08 item for Kelly, not a silent rewrite. DT receives the opt-in flag; how DT reproduces the acknowledged texts in its prospect email (D52) is RQ-3.

### 5. OTP: constants and template slot (D58, D59, CR-29, CR-34)

`CODE_TTL_MS = 5 min`, `SENDS_PER_ADDRESS = 2` per hour, six digits; resend cooldown 30 s stays; generic responses and lockout unchanged. Template loader `STP_OTP_TEMPLATE_PATH` with placeholder validation at boot (`{{code}}`, `{{clubName}}` only), built-in PROPOSED template until Chancy's HTML lands; both transports use it; club name from the catalog club.

### 6. Hosting: standalone Guest Pass host on the existing BFF (D60, CR-27, CF-11)

`STP_STANDALONE_HOSTS` (comma list; empty = today). Middleware `standaloneHost` tags requests whose `ctx.hostname` (behind the ingress: verified in A4 via `X-Forwarded-Host`) matches; on such hosts `GET /` and `GET /guest-pass` serve the Guest Pass entry document, the history fallback maps `/`, `/guest-pass`, `/pass` to the SPA, membership SPA paths and every API outside `/api/short-term-pass/*` and the guest-pass `/api/pay-page/*` routes answer 404. UI: `PAGES.guestPass = '/guest-pass'`; `index.tsx` derives the router `basename` from the entry document (`/signup` today, `/` on the standalone host); `App.tsx` treats `/guest-pass` like `/day-pass`; completion still moves to `/pass`. Helm (Phase D): second host + TLS on `ingress[0]`, `STP_STANDALONE_HOSTS`, both origins, `STP_CATALOG_SOURCE=fixture`, the three pass-link keys removed. LD flag `guest-pass-online` (club kind) replaces the never-created `oj-short-term-pass-checkout` (CF-17). Prod host and Cloudflare rules are PK's gate (V-P3).

### 7. UI structure after this sprint

```
index.tsx                       basename from the entry document (/signup | /)
App.tsx                         /day-pass | /guest-pass | /pass → ShortTermPassPage; else SignupShell   (no /pass/:token branch)
routes/ShortTermPass/
  ShortTermPassPage.tsx         flag key renamed; unavailable block when flag off / no items
  steps/IdentifyStep.tsx        <OfferCards/> (flagged items)
  steps/NewVisitorStep.tsx      profile fields (first, last, email, mobile); MarketingOptIn moves to the sidebar
  steps/RecognizedStep.tsx      saved-card chip (expired → disabled + hosted slot); waiver + marketing re-shown; no 18+
  steps/DoneStep.tsx            PassBlock v6 copy; delivery variants; decline block "Try another card"
  components/OfferCard.tsx      .days → validity line
  components/OrderSummary.tsx   no .dayfield; Valid row = useBy; consent block; receipt rows begin/expiration
  components/ConsentBlock.tsx   waiver checkbox + MarketingOptIn (DocumentDialog 'marketing'); no adult
  components/InlineCodeEntry.tsx  expiry countdown + resend cooldown, distinct
  components/PassBlock.tsx      "{name} · use by {date}" + "Check your email — …" + failed/pending variants
  components/SavedCardChip.tsx  expired state
  format.ts                     useByLabel, validityLine, offerToast; validityLabel/dateFieldLabel deleted
  (deleted) PassViewPage.tsx, PassCredential.tsx, PassReceipt.tsx
slice      checkout.offers[] (contractDays/visits/validityLine), order.useBy, no visitDate/adult, purchase.pass.{beginDate,expirationDate,visits}, delivery.status; compensate thunk; loadPassLink/resendPassEmail deleted
```

## Implementation Plan

**Sizing:** ~16 engineering days — A shared (~2), then B (BFF, ~5.5) ∥ C (UI, ~4.5) ∥ D (orchestrator + PLATFORM, ~2, from day 3), then E (~2). **Vertical slice first:** A → B1 + B2 + B3 + B4 → C1 + C2 + C3 + C5 shows a Riverside buyer with one flagged item, no date field, "use by" copy, prospect created before payment, decline → deactivate, and the v6 done copy — before the opt-in modal, the DataTrak adapter or the host work. **Removal first in each lane** (B0/C0). **Cuts if the lanes run long, in order:** B11 live adapter → gate; second-order recovery rows (capture unknown, late compensation) → gate; D2/D3 → pending register rows. Never cut B0/C0, the vertical slice, B1 or the decline/deactivate tests. Execution model as Sprints 0002–0003: A by one session, then two detached lanes coding against the frozen contract with their own blockers and summary files; the orchestrator owns D and E.

### A — Contract v4 freeze, reconciliation, fixtures, feasibility · ~2 days · both lanes

| # | Task | Files | Done when |
|---|---|---|---|
| A1 | Branches `prospect-wallet/sprint-0004` off `main` in both clones (PRs to `main`); ledger `SPRINT-0004 in-progress`; **close SPRINT-0002 as `done`** with the note "phases D/E1/E2 deferred by the user 2026-09-10; S2/S7 not run; S5 pending B1" (no gate marked passed); record heads and the pre-existing UI baseline failures by name | both clones; `docs/sprints/ledger.yaml` | branches pushed; ledger updated |
| A2 | **Feasibility time-box first (½ day)** because it can change the contract: (a) `curl` the dev DataTrak service `getClubDefaultExternal.spr` and `saleItems.spr` with MICO's dev credential and no member id — record shapes (content type, query names, auth) as `STP/fixtures/datatrak/*` or the refusal (CF-13/CF-14); (b) confirm `ctx.hostname` / `X-Forwarded-Host` behind the ingress; (c) `kubectl port-forward` to the dev BFF pod → `GET 127.0.0.1:8080/api/short-term-pass/testing/state` with the dev key answers 200; (d) ask Mark/Chancy for the `addProspect` field names and whether a deactivate/conditional-update exists (CF-15) | contract §8a; `BFF/package.json` if a parser is needed | each check recorded as done or as an explicit CF |
| A3 | **Contract v4** (`docs/contracts/short-term-pass-bff.md`): `OfferSummary {offerId, name, amountMinor, currency, contractDays, visits, validityLine}`; `OrderRequest {waiver?, saveCard?, marketingOptIn?, smsNoticeShown?, generation?}` (no `visitDate`, no `adult`; stale clients sending them → 400); `OrderSummary {…, contractDays, visits, useBy, consents, saveCard, ready}`; `OrderConsents.marketingOptIn`; document `marketing`; `PurchaseResult.pass {status, label, beginDate, expirationDate, visits}`, `person {created, deactivated?, reverted?}`, `delivery {status: sent\|pending\|failed\|unknown\|delegated, renderer, channel, masked}`, `receipt {…, beginDate, expirationDate}`; `wallet.cards[].expired`; `POST …/purchases/:pid/compensate`; `contractVersion` guard; retired routes → generic 404; `ProspectPort {create, repaint, deactivate, revert, lookupByOperation}`; flag key; source-qualified CR ids (CR v3 vs 2026-09-15) | contract §2, §4, §4a, §5, §6, §7, §8, §10 | frozen and mirrored in BFF/UI schemas; recovery states and acceptance cases reviewable |
| A4 | **Fixtures and validity:** Riverside one item; Core three single-visit items + one 3-visit + one unflagged; Priya with an expired Mastercard; `access` on prospect fixtures; `marketing` document (v6 legal paragraph with `{legalName}`); Pass Terms `2026-09.3`; `STP/validity.ts` rewrite with boundary tests; UI test factories | `STP/fixtures/{catalog,directory,consentTemplates}.ts`, `STP/validity.ts`, `UI-T/routes/ShortTermPass/shortTermPassTestData.ts` | `getOffers('90033')` returns three items and hides two; boundary tests green |
| A5 | **Removal inventory** written into `SPRINT-0004-BLOCKERS.md` with the exact file list and dependencies so B0/C0 are mechanical | `docs/sprints/drafts/SPRINT-0004-BLOCKERS.md` | list matches `rg` results in both repos |

**Exit:** v4 frozen; fixtures and validity tested; feasibility recorded; removal list agreed; branches and ledger updated.

### B — BFF · ~5.5 days · BFF lane

| # | Task | Files | Done when |
|---|---|---|---|
| B0 | **Removal.** Delete `passes.ts`, `passCredentials.ts`, `passView.ts`, `qr.ts`, `ports/passCredentialStore.ts`, `adapters/mock/passCredentialStore.ts`, pass-link routes, hooks revoke, `PASS_VIEW_REWRITE`, `logRedaction*`, AppDynamics skip, pass limiters, the three env keys (config, guard, `.env.example`), `qrcode`/`@types/qrcode`/`jsqr`/`pngjs`; drop `visitDate`/`adult`/`durationDays`/`validUntil`/`maxDaysAhead` from order, ports, schemas | as listed in §Overview | `rg 'pv1\|viewPath\|qrPayload\|validUntil\|durationDays\|visitDate\|adult\|PASS_LINK' src/` returns only the changelog comment; build clean |
| B1 | **OTP constants and expiry (D58/D59).** `CODE_TTL_MS = 5 min`, `SENDS_PER_ADDRESS = 2`; `expiresAt` in the challenge response; tests updated | `STP/challenge.ts`, `routes/shortTermPass/{identify,challenge}.ts`, tests | U19 (BFF half) pinned |
| B2 | **Catalog port v4 and gate (CR-28, D61, D70, D72).** `CatalogOffer` fields; v1 filter + capability listing of skipped items; `STP_CATALOG_SOURCE` (`fixture` \| `datatrak`); production refuses every fixture-bearing source; gate = flag AND eligible items, `onlineProspects` decoupled; flag key `guest-pass-online` | `ports/clubCatalog.ts`, `STP/order.ts`, `adapters/{mock,platform}/catalog.ts` (platform fixture fallback removed), `STP/{config,flag}.ts`, `utils/middlewares/requireShortTermPass.ts`, `routes/shortTermPass/checkouts.ts`; tests | U1, U2, U23, U25 (part) at the router level |
| B3 | **Order and validity (CR-35, D71).** Order shell without dates; `useBy` from club-local today; `applyOrderUpdate` accepts `waiver`, `saveCard`, `marketingOptIn`, `smsNoticeShown` only; `orderReady`; `consentSetFor(catalog, club, offerId, now)`; revision binds `offerId\|amount\|currency\|contractDays\|visits\|useBy`; `validatePurchase` recomputes dates and refuses a stale revision | `STP/order.ts`, `purchaseOrchestrator.ts` (validate), `routes/shortTermPass/{order,checkouts}.ts`, `fixtures/consentTemplates.ts`; tests | U4–U6 pinned; midnight test-clock → 409 with refreshed `useBy` |
| B4 | **Purchase order v4 (D65, D62, CR-12, CR-32, CR-06).** `ProspectPort` v4 + `ProspectAccess`; mock directory persists `access`, supports faults `create-failure`, `deactivate-failure`, `revert-failure`, `auth-unknown`; orchestrator per §3 with the recovery table; `PERSON_DEACTIVATED`/`PERSON_REVERTED`; `RECONCILING`; owner-only `compensate`; process-local compensation sweep; `PassSalePort.finalizeSale` only; `pass` derived from access; `delivery.renderer`; retry after a decline resolves the known record without duplicates | `ports/{prospect,passSale,payment,purchaseStore}.ts`, `adapters/mock/{identityDirectory,passSale,payment,purchaseStore,faults}.ts`, `purchaseOrchestrator.ts`, NEW `STP/prospectCompensation.ts`, `routes/shortTermPass/purchase.ts`; tests NEW `compensation.test.ts`, MODIFY orchestrator tests | U8–U12, U15 pinned; ordered-call tests; same-key replay; no wallet on decline |
| B5 | **Opt-in as a consent document (D67, CR-09).** `marketing` in the set; `OrderConsents.marketingOptIn`; snapshot; value on create/repaint (explicit `false`); document-opened event; both lanes | `ports/clubCatalog.ts` (ids), `fixtures/consentTemplates.ts`, `STP/order.ts`, `purchaseOrchestrator.ts`, `routes/shortTermPass/consentEvents.ts`; tests | U7, U13 pinned |
| B6 | **Delivery v4 (D52, D63).** Mock stand-in email; SMTP mailer without CID; publisher sends no pass email in platform mode; `DeliveryPort` only in mock mode; outbox leak scan asserts no `qr`/`pv1`/`viewPath` | `adapters/smtp/templates/prospectMailStandIn.ts` (renamed), `adapters/smtp/mailer.ts`, `adapters/publisher/emailPublisher.ts`, `adapters/mock/verification.ts`, `ports/delivery.ts`, `purchaseOrchestrator.ts`; tests | U21 pinned; `rg 'image/png\|cid:' adapters/` empty |
| B7 | **Limits and attempt log (D65, CR-32).** `purchaseLimiter` 10/IP/hour; `purchase.attempt` log line with a redaction test; `/testing/reset` clears it | `routes/shortTermPass/{index,context,purchase}.ts`, `STP/log.ts`, `testing/routes.ts`; tests | U24 pinned |
| B8 | **Expired card (CR-15, D53).** `expired` from `expMonth`/`expYear` (end of month, club-local) on `listEntries`; `GET /wallet` exposes it; `resolvePaymentSource` refuses an expired `selectionRef` | `ports/wallet.ts`, `adapters/{mock,platform}/wallet.ts`, `routes/shortTermPass/wallet.ts`, `purchaseOrchestrator.ts`; tests | U14 (BFF half) pinned |
| B9 | **OTP template slot (D59, CR-29).** Loader, placeholder validation at boot, built-in PROPOSED template; both transports | `adapters/smtp/templates/verificationCode.ts`, `adapters/smtp/mailer.ts`, `adapters/publisher/emailPublisher.ts`, `STP/config.ts`, `.env.example`; tests | U18 pinned |
| B10 | **Production guard v4.** Refuses fixture-bearing sources, `STP_MOCK_OTP_CODE`, missing DT credential in platform mode; forgets the pass-link keys | `STP/config.ts`; `config.test.ts` | U25 pinned |
| B11 | **DataTrak service catalog adapter (CR-31, D64).** Two endpoint calls, mapper, cache, authoritative timezone, fail-closed, split capability report; recorded/synthetic fixtures labelled | NEW `adapters/platform/datatrakServiceCatalog.ts`, `STP/fixtures/datatrak/*`; `adapters/index.ts`, `STP/config.ts`; tests | U20 pinned against fixtures; live read recorded done/blocked (CF-13/14) |
| B12 | **Host-scoped routing (D60, CR-20).** `standaloneHost` middleware; entry document on `/` and `/guest-pass`; membership paths and non-guest-pass APIs 404 on standalone hosts; guest-pass Pay Page routes allowed; history fallback additions; `STP_STANDALONE_HOSTS`; entry-document `basename` hint | NEW `utils/middlewares/standaloneHost.ts`; `services/application.ts`, `routes/static/index.html.ts`, `utils/middlewares/historyFallback.ts`; tests | U22 (BFF half) pinned |
| B13 | **Demo.** Demos 0–6 per U26; codes and keys redacted; capability report printed | `scripts/short-term-pass-demo.ts` | demo exits 0; count recorded |

**Exit:** U1–U15, U18–U25 at the router level; demo green; production boot refuses every hook, fixture source and mock; coverage ≥ 84/67/67/84; `SPRINT-0004-EXECUTION-SUMMARY-BFF.md` and `-BLOCKERS-BFF.md` written.

### C — UI · ~4.5 days · UI lane

| # | Task | Files | Done when |
|---|---|---|---|
| C0 | **Removal.** Delete `PassViewPage.tsx`, `PassCredential.tsx`, `PassReceipt.tsx`, `PAGES.passView`, the `matchPath` branch, `getPassView`/`getPassLink`/`resendPassLink`, `loadPassLink`/`resendPassEmail`, `qrcode.react`; remove the date field, `dateFieldLabel`, range `validityLabel`, `.dayfield`, the 18+ checkbox and `adult` from the slice; delete their tests | as listed | `rg 'passView\|viewPath\|qrcode\|validUntil\|durationDays\|visitDate\|adult\|ADULT_' src/ __tests__/` empty; build clean |
| C1 | **Slice, selectors, service (v4).** `offers[]` v4 fields; `order.useBy`; `purchase.pass.{beginDate,expirationDate,visits}`; `delivery.status`; `updateOrder` without `visitDate`/`adult`; `wallet.cards[].expired`; `compensate` thunk; contract-version mismatch → restart with a clear message | `reducers/shortTermPass/shortTermPassSlice.ts`, `selectors/shortTermPass.ts`, `services/shortTermPass.ts`, `interfaces/api/shortTermPass.ts`; tests | slice tables green against v4 fixtures |
| C2 | **Offer cards (CR-28, D68).** Name, price, validity line in `.days`; `.offers.single`; three-card overflow guard | `components/{OfferCard,OfferCards}.tsx`; tests | U1–U3 pinned |
| C3 | **Sidebar without a date (CR-35).** No `.dayfield`; Valid row = `useBy`; receipt rows begin/expiration; `format.ts useByLabel`/`validityLine` mirror the BFF | `components/OrderSummary.tsx`, `format.ts`; tests | U5 pinned for 1/7/30-day items; static scan: no `input[type=date]` |
| C4 | **Consent block v6 (CR-26, CR-09, D67).** Waiver checkbox + `MarketingOptIn` with the "marketing" `DocumentDialog`; document-opened event; no adult; both lanes; `NewVisitorStep` no longer renders it inline; modal focus/keyboard | `components/{ConsentBlock,MarketingOptIn,DocumentDialog}.tsx`, `steps/{NewVisitorStep,RecognizedStep}.tsx`, `short-term-pass.scss`; tests | U7, U13 pinned; Pay enabled with the checkbox unchecked; static scan: no "18 or older" in UI copy |
| C5 | **Done page v6 (CR-25).** `PassBlock` copy table with `sent`/`delegated`/`pending`/`failed` variants; no link/resend/QR; decline block → "Try another card" → new hosted session on the same checkout; `RECONCILING` → safe message, no second Pay | `components/PassBlock.tsx`, `steps/DoneStep.tsx`, `steps/{NewVisitor,Recognized}Step.tsx`, `hooks/usePayAction.ts`; tests | U9 (UI half), U10 (UI half), U16, U17 pinned |
| C6 | **Expired card and returning lane (CR-14, CR-15).** `SavedCardChip` expired state; auto-select the hosted slot when every saved card is expired; recognized lane re-shows waiver + marketing | `components/SavedCardChip.tsx`, `steps/RecognizedStep.tsx`; tests | U13, U14 (UI half) pinned |
| C7 | **Code entry (CR-13, CR-30).** Five-minute expiry countdown from `expiresAt`, distinct from the resend cooldown; `pattern="[0-9]*"`; expiry survives re-render; "change email" spends no send | `components/InlineCodeEntry.tsx`; tests | U19 (UI half) pinned |
| C8 | **Routes, base and flag (D60, CR-20).** `PAGES.guestPass`; `index.tsx` basename from the entry document; `App.tsx` branch; `FEATURE_FLAGS.GUEST_PASS_ONLINE`; unavailable block when flag off or no items | `index.tsx`, `App.tsx`, `common/constants.ts`, `utils/featureFlags.ts`, `routes/ShortTermPass/ShortTermPassPage.tsx`; tests | U22 (UI half), U23 pinned |
| C9 | **Copy table and layout.** Every v6 string pinned; `.marketing` under `.agree`; overflow guard 320–440 px; 1440/375 screenshots | `copy.test.ts`, `layout.test.ts`; `short-term-pass.scss` | tables green |

**Exit:** U1–U3, U5, U7, U9, U10, U13, U14, U16, U17, U19, U22, U23 in jest; lint/build clean; coverage ≥ 80/80; `SPRINT-0004-EXECUTION-SUMMARY-UI.md` and `-BLOCKERS-UI.md` written.

### D — Standalone host and platform wiring · ~2 days · orchestrator + PLATFORM · from day 3

| # | Task | Files | Done when |
|---|---|---|---|
| D1 | **helm-configs PR (signed: `/usr/bin/git -c gpg.format=ssh -c user.signingkey=~/.ssh/id_ed25519_signing.pub`):** `guestpass.dev.abcfitness.net` on `ingress[0]` hosts + tls; `STP_STANDALONE_HOSTS`; `STP_ALLOWED_ORIGINS` both origins; `STP_CATALOG_SOURCE=fixture`; **remove** `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS`; comment block rewritten | `helm-configs/online-join-bff/dev.yaml` | PR opened; values apply on the next dev deploy |
| D2 | **DNS/TLS/host check** after deploy: `dev-wildcard` covers the host; entry document served on `/?club=90030`; a hosted-card checkout completes on the new host | `docs/deploy/dev.md` | recorded |
| D3 | **Tickets (outside the cache):** Cloudflare rules for the prod host (PK); LD flag `guest-pass-online` (club kind, default off) in dev and prod; DT service credential into `platform-online-join-bff` (PLATFORM) once CF-13 holds | register rows | ticket ids in contract §10 |
| D4 | **Pilot gate checklist** as steps with owners and "effect if not done" (Next Steps 8–12, PR-06, PR-14, RQ-0) | NEW `docs/validation/guest-pass-pilot-gates.md` | written |

### E — Proof · ~2 days · both lanes + orchestrator

| # | Task | Evidence |
|---|---|---|
| E1 | **Quality.** Lint, build, coverage in both repos; membership suites; demo 0–6; baseline failures listed by name; Sonar conventions; Sonar gates green on both PRs | validation docs; ledger |
| E2 | **Local browser smoke** (puppeteer-core, one BFF process, Mailpit, fixture cards): Riverside Jordan success at 1440; Core Kelly 7-day item at 375 (opt-in checked → snapshot hash; "use by"); Core new visitor decline → deactivated → "Try another card" → success; Kelly decline → reverted; Priya expired chip → hosted slot; deactivate failure → RECONCILING → compensate; flag off; `/guest-pass?club=` alias; overflow 320–440; Mailpit: OTP from the template slot, stand-in prospect email without an image part; state shows no `viewPath`/`qr`/`pv1` | NEW `docs/validation/short-term-pass-sprint-0004-smoke.md`, `screenshots/sprint-0004/**` |
| E3 | **Dev smoke** against `onlinejoin.dev.abcfitness.net` and `guestpass.dev…` (after D1/D2): pinned code, Kelly, Pay Page test card, done copy; state via `kubectl port-forward`; hosted capture result recorded truthfully (B1) | smoke doc §dev; `docs/deploy/dev.md` |
| E4 | **Live DataTrak read** (gated CF-13/14): one `STP_CATALOG_SOURCE=datatrak` boot against a dev club Chancy flags; offers, terms, timezone observed or the refusal recorded | contract §8a |
| E5 | **Docs, status, PRs.** Contract v4 final; traceability for every CR v3 §A–H row (implemented / verified existing / cancelled / external gate / deferred); `docs/SEMANTIC-INDEX.md` Sprint 0004 code map incl. removals and the MICO → DataTrak-service fact; demo doc; pilot-gate checklist; ledger; PR descriptions (Conventional Commits: `feat:` UI → 8.34.0-daypass.1 line kept; BFF `feat:` → next minor); execution summary | as named |

Local commands:

```text
# BFF .env: STP_ADAPTER_MODE=mock STP_CAPTURE_MODE=mock STP_TEST_HOOKS=true STP_TEST_HOOKS_KEY=… STP_LOCAL_FLAG_OVERRIDE=true
#           STP_EMAIL_TRANSPORT=smtp STP_SMTP_URL=smtp://localhost:2525 STP_CATALOG_SOURCE=fixture
#           STP_STANDALONE_HOSTS=guestpass.localhost   STP_OTP_TEMPLATE_PATH=   (unset → built-in template)
docker start stp-mailpit || docker run -d --name stp-mailpit -p 2525:1025 -p 8025:8025 axllent/mailpit
cd repos/online-join-bff && npm ci --ignore-scripts && npm run build && node --env-file=.env dist/src/server   # :3000
npm run demo:short-term-pass                                                                                    # Demo 0–6
cd repos/online-join-ui && npm ci --ignore-scripts && npm start                                                 # :3001
open http://localhost:3000/guest-pass?club=90030      # one item, Riverside
open http://localhost:3000/guest-pass?club=90033      # three single-visit items, Core
# dev hooks through the pod (loopback rule intact):
kubectl --context k8s-lower-wlr -n dev port-forward deploy/online-join-bff 18080:8080
curl -H "X-STP-TEST-KEY: $KEY" 'http://127.0.0.1:18080/api/short-term-pass/testing/state?checkoutId=…'
```

## Files Summary

| Repo | Paths | Action |
|---|---|---|
| online-join-bff | `src/routes/shortTermPass/{schemas,checkouts,order,purchase,wallet,index,context,identify,challenge}.ts`, `testing/routes.ts` | MODIFY: v4 shapes, no date/adult, compensate route, purchase limiter, expired card, delegated delivery, OTP expiry |
| online-join-bff | `src/routes/shortTermPass/passes.ts` (+ test), `src/services/shortTermPass/{passCredentials,passView,qr}.ts` (+ tests), `ports/passCredentialStore.ts`, `adapters/mock/passCredentialStore.ts`, `utils/logRedaction*` | **DELETE** |
| online-join-bff | `src/services/shortTermPass/{order,validity,receipt,purchaseOrchestrator,challenge,config,flag,log}.ts`; `ports/{clubCatalog,prospect,passSale,payment,purchaseStore,identityDirectory,wallet,delivery}.ts`; `adapters/{index,mock/*,platform/catalog,platform/wallet,smtp/mailer,smtp/templates/verificationCode,publisher/emailPublisher}.ts`; `fixtures/{catalog,directory,consentTemplates}.ts`; `utils/middlewares/{requireShortTermPass,historyFallback}.ts`; `services/application.ts`; `routes/static/index.html.ts`; `.env.example`; `package.json` + lockfile (remove `qrcode`, `@types/qrcode`, `jsqr`, `pngjs`); `scripts/short-term-pass-demo.ts` | MODIFY |
| online-join-bff | `adapters/platform/datatrakServiceCatalog.ts`, `fixtures/datatrak/*`, `utils/middlewares/standaloneHost.ts`, `services/shortTermPass/prospectCompensation.ts`, `adapters/smtp/templates/prospectMailStandIn.ts` (renamed), tests `{compensation,datatrakServiceCatalog,standaloneHost}.test.ts` | NEW |
| online-join-ui | `src/routes/ShortTermPass/PassViewPage.tsx`, `components/{PassCredential,PassReceipt}.tsx`, their tests | **DELETE** |
| online-join-ui | `src/index.tsx`, `src/App.tsx`, `src/common/constants.ts`, `src/utils/featureFlags.ts`, `src/interfaces/api/shortTermPass.ts`, `src/services/shortTermPass.ts`, `src/reducers/shortTermPass/shortTermPassSlice.ts`, `src/selectors/shortTermPass.ts`, `src/routes/ShortTermPass/{format.ts,ShortTermPassPage.tsx,hooks/usePayAction.ts,steps/*,components/{OfferCard,OfferCards,OrderSummary,ConsentBlock,MarketingOptIn,DocumentDialog,PassBlock,SavedCardChip,InlineCodeEntry,CheckoutShell}.tsx}`, `src/styles/short-term-pass.scss`, `package.json` (remove `qrcode.react`), tests | MODIFY / DELETE |
| helm-configs | `online-join-bff/dev.yaml` | MODIFY (signed PR): host, `STP_STANDALONE_HOSTS`, both origins, `STP_CATALOG_SOURCE`; remove three pass-link keys |
| this repo | `docs/contracts/short-term-pass-bff.md` (v4), `docs/demos/short-term-pass-local-demo.md`, `docs/deploy/dev.md`, `docs/SEMANTIC-INDEX.md`, `docs/sprints/ledger.yaml` | MODIFY |
| this repo | `docs/validation/short-term-pass-sprint-0004-{smoke,traceability}.md`, `docs/validation/guest-pass-pilot-gates.md`, `docs/validation/screenshots/sprint-0004/**`, `docs/sprints/drafts/SPRINT-0004-{BLOCKERS,EXECUTION-SUMMARY}{,-BFF,-UI}.md` | NEW |
| Handoffs | CF-08/CF-09/CF-16 (Kelly + Legal); CF-10 (PK); CF-13/CF-14/CF-15/RQ-0 (Chancy / Mark, DT PR to PK); Cloudflare + prod host (PK); LD flag + DT credential secret (PLATFORM); B1 Pay Page credentials (PAYMENTS); Jira epics to Chancy (PR-10, Bjorn) | outside the cache |

Not modified: `mico/**` (reference only); wallet repos; `BFF/routes/payPage/**` beyond allowing its guest-pass routes on the standalone host; existing UI membership routes and shells; `tools/day-pass-harness/**` (harness still deferred; parity inputs stale against v6 — register row RQ-6).

## Definition of Done

Role slots: UI, BFF, QA, SECURITY, PRODUCT, DESIGN, PAYMENTS, PLATFORM, LEGAL, DT (Chancy), PK. A gate with no named owner does not sign. An unrun check is pending, not passed. Sprint gates V0–V8; pilot gates V-P0…V-P6 are **not** part of sprint completion.

| Gate | Owner | Passes when |
|---|---|---|
| V0 — Contract v4 and reconciliation | UI+BFF | Contract frozen (A3); removal inventories executed with `rg` proof (B0, C0); fixtures and validity tested; A2 feasibility recorded; Sprint 0002 closed in the ledger; `.env.example` and helm dev values carry only v4 keys |
| V1 — Catalog-driven single-visit checkout | PRODUCT+QA | U1–U6 through the real UI and BFF for Riverside (one item) and Core (three items; 3-visit and unflagged hidden); no date field; "use by" and validity copy from the item; `visits`, `contractDays`, price never hard-coded (static scan) |
| V2 — Design v6 parity | UI+DESIGN(observer) | Identify with offers, code entry (numeric keypad, expiry countdown, resend cooldown), new visitor with the opt-in modal and no 18+, recognized lane with re-accepted waiver and the expired-card path, order summary with "use by", success copy — at 1440/375; every v6 string pinned; deviations recorded as approved deltas (VALID_DAYS, adultCb, refund sentence CF-16, "Core South") |
| V3 — Purchase order and recovery | BFF+QA+PK(observer) | Create before pay; decline → deactivate (new) / revert (returning); unknown auth → status lookup → RECONCILING, never deactivate; compensation failure → RECONCILING + compensate retry + sweep; same-key replay never double-creates or double-charges; attempt log without PAN/token/email; per-IP purchase limiter; save card only after AUTHORIZED; no second Pay while RECONCILING |
| V4 — No QR, no pass page, no age gate | SECURITY+BFF+UI | `GET /api/short-term-pass/passes/anything` → generic 404 (route absent); no `qrPayload`, `viewPath`, `pv1` in any response, state, DOM or log (leak tests); no image part in any BFF email; `adult` absent from every schema and snapshot; boot guard forgets the pass-link keys; dependencies removed from both lockfiles |
| V5 — Consent and opt-in evidence | LEGAL(observer)+BFF | `marketing` document versioned with `renderedHash`; snapshot records checked state, timestamp and hash; explicit value on create/repaint; unchecked never gates Pay; both lanes; waiver reset per purchase; club waiver text used when present |
| V6 — Quality | UI+BFF+QA | Lint and build clean; UI ≥ 80/80; BFF ≥ 84/67/67/84; Sprint 0001–0003 suites green minus deleted files; demo 0–6 green; Sonar gates green on both PRs; no floor lowered; baseline failures listed by name; OTP constants 5 min / 2 sends pinned |
| V7 — Hosting and proof | PLATFORM+QA | Host-scoped routing tested (U22) incl. a hosted-card checkout on the standalone host; helm PR merged and deployed **or** recorded pending with the PR link; dev smoke E3 with the pinned code on the existing host passes; LD flag key renamed and created **or** recorded pending; DataTrak adapter unit-pinned, live read recorded done **or** blocked (CF-13/14) — each item carries its own verdict |
| V8 — Docs and status | BFF+UI | Contract v4, registers (CF-08…CF-11, CF-13…CF-18, RQ-0…RQ-9, deferred-to-v2), traceability for every CR v3 row, smoke docs, pilot-gate checklist, demo doc, `docs/SEMANTIC-INDEX.md`, ledger, PR descriptions, execution summary; completion vocabulary applied |

**Completion vocabulary (four separate verdicts, never merged):** *(1) Implementation and mock acceptance: Rounds 5–7 changes complete; single-visit catalog checkout, create → pay → deactivate/revert and consent evidence proven with mock adapters locally and in dev with the pinned code. (2) Standalone dev host: {verified with a hosted-card checkout \| pending helm/Cloudflare}. (3) Live integration: DataTrak catalog read {done \| blocked CF-13/14}; prospect create/update/deactivate {mock only — platform port `notEnabled`}; hosted capture {verified \| unverified B1}; QR, prospect email and access enforcement are DataTrak's and unverified from this build. (4) Pilot: not eligible until V-P0…V-P6 pass.* A failed gate is named in the sentence, never absorbed.

### Pilot gates (registered now, owned separately)

| Gate | Owner | Evidence |
|---|---|---|
| V-P0 — DT email trigger safe with create-before-pay (RQ-0) | Chancy + Mark | DT sends the prospect email with the QR only after payment, or the deactivate reliably precedes any send; otherwise no pilot |
| V-P1 — Real data and durable operations | Mark + Chancy + Terry Smith | catalog columns and DT PR live in a lower environment (flagged item visible through the service layer; waiver field in club settings → Online); platform identity/prospect/payment/sale ports replaced and proven; durable checkout/idempotency/compensation state across pod restarts |
| V-P2 — Webhook propagation of the deactivate (PR-14) | Chancy + Kyle | a page-driven declined purchase's deactivate correlation id matched in every CRM the create reached |
| V-P3 — Cloudflare rules and public surface | PK + Kelly | rate limiting and bot rules "as on OJ" on the prod Guest Pass host; counsel and Twilio decisions on the opt-in modal and no age gate; no mock/test config in production |
| V-P4 — Desk-scanner test (PR-06) | Chancy + Mark | emailed QR admits on the pass day; refused after expiration and after the single visit |
| V-P5 — Simulated-user agents end to end (PR-02/03/04) | Mark | mail sink + sandbox cards; harness lane in this repo remains deferred until the user says |
| V-P6 — Maintenance server and baselines | Chancy + product | running at pilot clubs; baselines at clubs 31239 and 31590 captured (D27); product-marketing three-button hand-off (PR-08) |

### Carried gates and confirmations

Sprint 0002 S5 (hosted Pay Page, B1) and S2/S7 (harness, deferred) carry unchanged. Sprint 0003 rows this sprint **closes by cancellation:** rotating QR + desk verifier, CF-06 link lifetime, CF-07 static vs link-only, durable credential store, publisher image fetch, PA-1/PA-2 (routes removed). Rows that **stay** as register items: durable stores and async purchase status (now V-P1), live re-pricing after verify (not built; Change/Start again re-selects), staff revoke/discovery (a DT concern), sprint-wide `generation` matrix, metrics, Turnstile, accessibility audit, semantic-index expansion; CF-04 pricing (per item from the catalog — closes with V-P1); CF-05 window semantics (closed by D48/D71: inclusive calendar days from purchase).

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | DT sends the prospect email with the QR on create, before payment (RQ-0) | Asked on day 1; pilot gate V-P0; the deactivate is immediate and correlated; no pilot without the answer |
| R2 | Chancy's DT PR does not expose the new columns or the waiver through the service layer (CF-13), or `saleItems.spr` needs a member (CF-14) | A2 probe; adapter fails closed per club; fixtures keep every lane moving; the smallest fix (fields on two responses) named for the DT PR before PK's review |
| R3 | `addProspect` field names differ from D62, or no deactivate / conditional update exists (CF-15) | `ProspectPort` v4 is the seam; the platform adapter waits for the owner contract; mock proves the order |
| R4 | Deactivate does not propagate to CRM automation (Kyle) | Compensation immediate and retried; correlation ids logged; V-P2 before any club |
| R5 | A returning buyer's active paid pass is overwritten or destroyed on a decline | Repaint keeps `previousAccess`; compensation for `created:false` is revert; overlapping-active-pass case excluded from the pilot until CF-15/RQ-4 settle; serialized per person/club in mock |
| R6 | Unknown authorization treated as a decline | Existing `unknown` branch kept and its thrown-transport path tightened; RECONCILING; tested with `auth-unknown` fault |
| R7 | Fixture prices or the pinned OTP reach production | Guard refuses every fixture-bearing source and `STP_MOCK_OTP_CODE`; configuration matrix tested; capability report separates fixture from live |
| R8 | Removing Sprint 0003 code breaks suites and the demo mid-lane | B0/C0 first against the frozen v4; demo rewritten in B13; `rg` proof lists; coverage checked after B0/C0 |
| R9 | The standalone host breaks routing, cookies or card capture | `index.tsx` basename from the entry document; guest-pass Pay Page routes allowed; hosted-card checkout on the new host is part of V7; `Secure` cookie path unchanged since PR #106; dev first, prod behind V-P3 |
| R10 | Card testing on the open endpoint before Cloudflare is live | Per-IP purchase and identify limiters + attempt logging in the BFF; the URL stays dark (flag off) until V-P3 |
| R11 | Twilio refuses SMS with the opt-in text behind a modal (CF-09) | The document is data: an inline variant is a copy switch, not a rebuild |
| R12 | Hard-coded days/visits/prices creep back from the v6 prototype | Static scan for numeric literals in customer copy; fixtures carry the values; D71 named in V1; deltas recorded |
| R13 | Midnight rollover between render and Pay | Dates computed at `validatePurchase`; revision binds `useBy`; 409 refresh path tested with the test clock |
| R14 | Dev smoke cannot read state because hooks are loopback-only | `kubectl port-forward` to the pod (A2c); no policy change; if it fails, the dev smoke asserts through the UI and `GET /purchases/:pid` only, recorded as such |
| R15 | Estimate at the top of the two-week box | Cut order fixed (B11 → gate; second-order recovery rows → gate; D2/D3 → pending); B0/C0, vertical slice, B1 and decline tests protected |
| R16 | The wallet team's review of the prospect lane (`concerns.txt`) blocks the wallet write | `STP_WALLET_WRITES` stays false in dev; save-on-success proven against the mock |

## Dependencies

- **Code/infra:** both clones on `main`; Node ≥ 22 (`npm ci --ignore-scripts` on node 26); Chrome; Mailpit; `kubectl` context `k8s-lower-wlr`, namespace `dev`; helm-configs signing key (`~/.ssh/id_ed25519_signing`, `/usr/bin/git -c gpg.format=ssh`); BFF PR #106 (1.2.3) merged before the dev smoke.
- **Access:** MICO's dev credential for the DataTrak service layer (A2, read-only probe); B1 Pay Page dev credentials (unchanged); LD dev project rights or a PLATFORM ticket for `guest-pass-online`; `platform-online-join-bff` secret update for the DT credential.
- **Other owners' work (dependency with fallback, never a blocker):** DBA columns and Chancy's DT PR (V-P1; fixtures until then); Chancy's OTP HTML (B9 slot; PROPOSED template until then); Kelly's legal answers CF-08/CF-09/CF-16 (PROPOSED texts until then); PK's CF-10 (D65 order ships; v2 direction recorded); Mark's API package (platform prospect/payment adapters stay `notEnabled`; the v4 port surface is the handoff); RQ-0 answer (V-P0).
- **Decided at the interview (2026-09-17):** remove rather than hide; existing repos + standalone host (CF-11); DataTrak service layer for reads; mock-proven bar with live gates.
- **Index leaves consulted:** `themes/identity-by-member-id.md` (prospect owns a wallet by member UUID — unchanged assumption); `themes/dt-to-wallet-sync.md` and `datatrak-data-access.md` (Oracle/VPD precedent and its cost — the reason to prefer the service layer); `themes/feature-flags.md` (LD naming).

## Open Questions

**Decided in this sprint (drafts, critiques, interview):** Rounds 5–7 supersede Sprint 0003's sources; cancelled surfaces removed; existing repos at a standalone host; DataTrak service layer for reads; mock-proven bar; OTP constants corrected; gate decoupled from `onlineProspects`; unknown authorization never treated as a decline; no `STP_CREATE_BEFORE_PAY` switch; no hooks-policy change (pinned code + port-forward); SPRINT-0002 closed with a deferral note.

**Requested (owner and date at kickoff; unanswered questions block only the named capability):**

| # | Question | Owner slot | Effect if unanswered |
|---|---|---|---|
| RQ-0 | Does DT send the prospect email (with the QR) on create, i.e. before payment, or on an explicit trigger? | Chancy + Mark | **No pilot enablement** (V-P0); mock flow unaffected |
| CF-08 | Waiver enforceability with no age gate; fallback waiver copy still saying "18 or older" | Kelly + Legal | Waiver ships as PROPOSED text with no gate; no DOB field (v2) |
| CF-09 | Opt-in text in a modal acceptable to legal and Twilio | Kelly | Modal ships; inline variant ready |
| CF-10 | Any rule requiring the pre-payment prospect record (D65) | PK | D65 order ships; v2 direction recorded |
| CF-11 | Repo home | Bjorn — **answered 2026-09-17:** existing repos + standalone host | — |
| CF-13 | DataTrak service layer exposes `guestPassOnline`, `contractDays`, `visits`, waiver text | Chancy → PK | `STP_CATALOG_SOURCE=fixture` in dev; adapter fails closed |
| CF-14 | `saleItems.spr` answers for a club with no member | Chancy | same as CF-13; alternative: club-scoped query in the DT PR |
| CF-15 | `addProspect` field names for begin/expiration/visits/item/opt-in (one value vs four `comm*` flags); idempotency; deactivate / conditional update | Chancy / Mark | Platform `ProspectPort` stays `notEnabled`; mock proves the order; overlapping-active-pass case excluded from pilot |
| CF-16 | v6 refund sentence vs PRD D15/D22 | PM + Legal | PRD sentence stays |
| CF-17 | Flag key `guest-pass-online` replaces `oj-short-term-pass-checkout` | PLATFORM / Bjorn | Rename ships (the old flag never existed in LD); override stays in dev |
| CF-18 | Club with no waiver text: fall back to the US template or no waiver | Kelly + Chancy | Fallback template ships |
| RQ-1 | Exact copy for 1-contract-day validity and the pending/failed delivery variants | DESIGN | Draft copy ships and is pinned; deltas recorded |
| RQ-2 | Whether DT can re-send the prospect email on request | Chancy | No resend on the page; desk fallback sentence only |
| RQ-3 | How DT reproduces the acknowledged Pass Terms / waiver / opt-in texts in its prospect email (D52) when it receives only the opt-in flag | Chancy | Stand-in email documents the expected content; register row |
| RQ-4 | Returning prospect with unconsumed paid access whose repaint purchase fails: revert, refuse, or extend? | Kelly + Chancy + Mark | Case excluded from pilot; mock proves revert |
| RQ-5 | Prod host name and Cloudflare rule set | PK | Dev host only this sprint |
| RQ-6 | Parity inputs (`tools/day-pass-harness/parity/*.json`) re-baseline on v6 now or when the harness lane starts | Bjorn | Left at v4; register row |
| RQ-7 | Whether the create call needs the payment token before a successful auth (D62 lists it; D65 saves only on success) | Mark | Create carries a server-resolved `paymentTokenReference` for linking; nothing is saved to the wallet before `AUTHORIZED` |
| RQ-8 | Jira epics for the DT stories (PR-10) | Bjorn → Chancy | Traceability cites CR ids only |
| RQ-9 | Recognized **members** (D12): existing block kept | PRODUCT | Existing behaviour stays; explicit production gap row |

**Deferred to v2 (recorded so nobody rebuilds cancelled items — CR v3 §G, Next Steps):** multi-day / multi-visit passes and any future start date; pass extension on repeat purchase; guest definition revisit (D73); no prospect record unless payment succeeds; the dynamic-link credential (public web app, PK's team); the BFF QR renderer and the "View your pass" page (cancelled — D63); link-use counter; 18+ checkbox (reversed — D66); minimum age via M&O, DOB, minor queue; waiver versioning and once-per-club state; "what's included" copy per item; reporting and insights; service modelling (D70); club-settings item picker (D61); new `guest-pass-*` repos as the "new OJ" home; harness lane and agents (user decision); durable stores and service-owned reconciliation (V-P1).
