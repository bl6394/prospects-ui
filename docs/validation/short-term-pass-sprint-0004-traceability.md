# Sprint 0004 — traceability: Change Requests v3 (2026-09-10) → what was built

**Status:** drafted at Phase D (2026-09-18); evidence columns completed at E5. Vocabulary per CR v3 row: **implemented** (built this sprint, mock-proven), **verified existing** (already true, pinned by a test), **cancelled** (per D-decision; code removed), **external gate** (another owner's work; register row), **deferred** (v2). Sources: `docs/prd/Change_Requests_2026-09-10_v3.md`; plan `docs/sprints/SPRINT-0004.md`; contract `docs/contracts/short-term-pass-bff.md`. Use-case ids (U1–U27) are the plan's. Evidence names the test suite or document that pins the row; "mock" always means the mock adapters — nothing here claims live DataTrak, hosted capture or pilot readiness.

## A. Guest Pass page (Bjorn; design Mark)

| CR | Item | Status | Evidence (E5) |
|---|---|---|---|
| CR-01 | Consent control and Pay in the right-hand Order Summary panel | verified existing | UI `ConsentBlock`, `OrderSummary.test.tsx`, `copy.test.ts` |
| CR-02 | §4.5 terms in the T&C modal (content PROPOSED) | verified existing + implemented (Pass Terms `2026-09.3`, `marketing` document) | BFF `consentTemplates.test.ts`; UI `DocumentDialog` via `ConsentBlock` tests |
| CR-04 | No saved-card dropdown for a first-time buyer | verified existing | UI `NewVisitorStep.test.tsx` |
| CR-07 | Remove generator explanatory text | verified existing | UI `copy.test.ts` (no generator copy) |
| CR-08 | Visual parity with HTML v1.2 | superseded by Design v6 (D46) | approved deltas in `SPRINT-0004-BLOCKERS.md`; UI `copy.test.ts`, `layout.test.ts`; screenshots `docs/validation/screenshots/sprint-0004/` |
| CR-09 (revised) | Marketing/SMS opt-in: legal-written single checkbox, long text in a mobile-friendly modal, value on the create call checked or not | implemented (U7, U13) | BFF `order.test.ts` / `purchase.test.ts` (snapshot `marketingOptIn {optedIn, templateVersion, renderedHash, at}`, explicit `false` on create/repaint); UI `ConsentBlock`/`MarketingOptIn` tests |
| CR-13 | Numeric keyboard on the OTP field | verified existing + pinned (`inputMode="numeric"`, `pattern="[0-9]*"`) | UI `InlineCodeEntry` tests (U19) |
| CR-14 (revised) | Returning lane: Pass Terms and waiver every purchase; no 18+ | implemented (U13) | BFF waiver reset per purchase (`order.test.ts`); UI `RecognizedStep.test.tsx` |
| CR-15 | Returning lane: expired card on file → different card via the Pay Page | implemented (U14) | BFF `wallet.test.ts` (`expired:true`), `purchase.test.ts` (400 on an expired `selectionRef`); UI `SavedCardChip` expired state, hosted slot auto-selected |
| CR-16 | Thank-you page shows the QR | cancelled (D63) — QR and pass page removed | BFF: `GET /passes/*` → 404 test; UI: no `svg`/`.qr` on the done page (`DoneStep.test.tsx`); `rg` proof in both lane summaries |
| CR-22 | Keep the 18+ checkbox | reversed (D66) — removed | UI static scan "18 or older" absent from UI copy; BFF `adult` absent from every schema and snapshot |
| CR-25 (new) | Success page says the QR was emailed; no QR rendered | implemented (U16, U17) | UI `PassBlock` / `DoneStep` tests (sent / delegated / pending / failed / not-attempted variants) |
| CR-26 (new) | Remove the 18+ checkbox | implemented | as CR-22 |
| CR-27 (new) | Standalone Guest Pass URL; repo home confirmed | implemented as **existing repos + standalone host** (CF-11, interview 2026-09-17) (U22) | BFF `standaloneHost.test.ts`; UI basename derivation test; helm PR #3090 (open); dev proof pending #3090 deploy |
| CR-28 (revised) | Page lists every flagged catalog item with real prices; v1 configured with one single-visit pass | implemented (U1–U3) | BFF `catalog.test.ts` (v1 filter hides the 3-visit and unflagged items), `checkouts.test.ts`; UI `OfferCards.test.tsx` |
| CR-35 (new) | Remove the start-date picker; "You have X days to use this pass" with X from the item | implemented (U4, U5) | BFF `order.test.ts` (no `visitDate`, `useBy` quote, 400 on stale clients); UI `OrderSummary.test.tsx` (no `input[type=date]`, validity row) |
| CR-29 (new) | OTP email from Chancy's HTML template with the code injected; club name only | implemented as a **template slot** (`STP_OTP_TEMPLATE_PATH`, placeholders `{{code}}` / `{{clubName}}`, built-in PROPOSED template until the HTML arrives) (U18) | BFF `verificationCode` / mailer tests; CR-34 external |
| CR-30 (new) | 5-minute timer on the OTP page | implemented (U19) — BFF `CODE_TTL_MS = 5 min` (was 10) + UI countdown from `expiresAt` | BFF `challenge.test.ts`, `identify.test.ts`; UI `InlineCodeEntry` tests |
| CR-31 (new) | Read flagged items, days/visits, prospect terms and waiver language from DT (like Myko) | implemented as the **DataTrak service-layer adapter** unit-pinned against labelled synthetic fixtures; **live read blocked** (CF-13 fields absent, CF-14 member-less query refused) | BFF `datatrakServiceCatalog.test.ts`; contract §8a; blockers file |

## B. BFF / API package (Mark)

| CR | Item | Status | Evidence (E5) |
|---|---|---|---|
| CR-03 | Pay Page embed as membership online join does | verified existing; hosted capture **unverified locally** (B1 credentials); dev result recorded in the smoke doc | `payPageSession.test.ts`; smoke §dev |
| CR-05 | Email OTP for both lanes | verified existing | `identify.test.ts`, `verify.test.ts` |
| CR-06 (revised) | Save-card writes the token only on a successful auth | implemented (U15) — `WALLET_RESULT` follows `AUTHORIZED` only; declined → no wallet write | `purchase.test.ts` |
| CR-10 | Email OTP 6 digits, 5 min, 2 sends/hour | implemented (constants were 10 min / 5 sends on `main` despite "Done" in CR v3) (U19) | `challenge.test.ts` |
| CR-11 | Barcode → QR renderer in the BFF | cancelled (D63) — `qr.ts`, `qrcode`, `jsqr`, `pngjs` removed | lockfile diff; `rg` proof |
| CR-12 (revised) | Prospect create/update sends begin = today, expiration = today + contract days − 1, visits (1), opt-in, item, wallet token; deactivate on failure | implemented on the **mock** `ProspectPort` v4 (U8, U9, U12); platform port `notEnabled` (CF-15) | `purchase.test.ts`, `compensation.test.ts`, `identityDirectory.test.ts`; demo 1 / 3 / 4 |
| CR-23 | API package behind a flag to production | external gate (Mark) | — |
| CR-32 (new) | Create → pay → deactivate on failure; same webhooks; log attempts; Cloudflare rate limiting | implemented on mock (U9, U10, U24: deactivate/revert, `RECONCILING`, `compensate`, sweep, `purchase.attempt` log, 10/IP/hour); webhook propagation and Cloudflare are external gates (V-P2, V-P3) | `compensation.test.ts`, `purchase.test.ts`, `log.test.ts`; pilot gates doc |

## C. DataTrak (Chancy)

| CR | Item | Status | Evidence |
|---|---|---|---|
| CR-17 (revised) | Club settings → Online: waiver language field | external gate; the BFF maps `waiverText` to the waiver override when present (CF-18 fallback) | `consentTemplates.test.ts` (waiverText override) |
| CR-18 (revised) | Oracle columns on the catalog-item table | external gate (DBA, Terry Smith); synthetic fixture names the fields | `fixtures/datatrak/saleItems.synthetic.json` |
| CR-19 (revised) | Prospect email type: static QR, pass date, acknowledgement text, no 18+ line | external gate (RQ-0, RQ-3); mock stand-in email documents the expected content (U21) | `prospectMailStandIn` tests; Mailpit in the smoke |
| CR-20 | LaunchDarkly flag; off = existing behaviour | implemented as key `guest-pass-online` + eligible-items gate (U23); flag creation is a PLATFORM ticket (CF-17) | `requireShortTermPass.test.ts`, `flag.test.ts`; UI `ShortTermPassPage.test.tsx` |
| CR-21 (revised) | Enablement guidance | documented in `docs/validation/guest-pass-pilot-gates.md` §Enabling a club | — |
| CR-24 | POS receipt email continues; pass email subject unmistakable | external gate (Chancy) | — |
| CR-33 (revised) | Catalog item flag "Guest pass online" opening contract days and visits | external gate (Chancy's DT PR → PK); the adapter reads exactly these fields | `datatrakServiceCatalog.test.ts` |
| CR-34 (new) | Send Bjorn the OTP email HTML template | external (pending); slot ready | B9 |

## D. Process and test-harness requests

| PR | Item | Status |
|---|---|---|
| PR-01 | Visual-parity loop against HTML v1.2 | superseded (v6); parity inputs left at v4 (RQ-6) |
| PR-02 / PR-03 / PR-04 | Simulated agents, OTP mail sink, sandbox cards | mail sink (Mailpit) and fixture cards exist; agents deferred (V-P5, user decision) |
| PR-05 | DBA ticket for the catalog-item columns | external (Chancy → Terry Smith) |
| PR-06 | Desk-scanner test | external (V-P4) |
| PR-07 | Maintenance-server check | external (V-P6a) |
| PR-08 | Product-marketing hand-off | external (V-P6c) |
| PR-09 | Reporting and insights requirements | parked (deferred) |
| PR-10 | Jira epics to Chancy | external (Bjorn; RQ-8) |
| PR-11 | Chancy's DT PR to PK | external |
| PR-12 | Opt-in modal mockup to legal; Twilio | external (CF-09; V-P3b) |
| PR-13 | PK confirms no rule requires the pre-payment record | external (CF-10) |
| PR-14 | Webhook propagation check | external (V-P2) |
| PR-15 / PR-16 / PR-17 | M&O future-range test; pre-begin check-in; Terry Smith fields | external (Chancy; D74) |

## E–H. Confirmations, confirmed-correct, cancelled, inputs

- **CF-01, CF-02, CF-04, CF-05** carried (PROPOSED content; deferrals confirmed). **CF-06, CF-07, CF-12** closed. **CF-08** (waiver with no age gate; fallback text still says "18 or older") — Kelly + Legal, open; the text is not rewritten. **CF-09** (opt-in modal; Twilio) — Kelly, open; inline variant is a copy switch. **CF-10** — PK, open. **CF-11** — answered: existing repos + standalone host. **CF-13 / CF-14 / CF-15** — recorded 2026-09-18 (blocked / refused / unanswered) in contract §8a and the blockers file. **CF-16** — PRD refund sentence stays. **CF-17** — flag key renamed; creation pending. **CF-18** — fallback template ships.
- **§F confirmed correct:** email-only identity; "Welcome back" lane with the record repainted (mock); save-card position; check-in enforces prospect dates (DT); scanners read a plain barcode QR (DT); create call accepts the fields (per Chancy — CF-15 pending for names); phase-one fields first / last / email / mobile.
- **§G cancelled or reversed:** BFF QR renderer and on-page QR (removed), 18+ checkbox (removed), club-settings item picker (never built), dynamic-link QR app (v2), link-use counter (not needed), start-date picker (removed), multi-day / multi-visit passes (fixtures carry them to prove arithmetic; v1 filter hides multi-visit; not a pilot configuration), service modelling (product).
- **§H inputs:** Design v6 — have; §4.5 terms — PROPOSED; Pay Page embed — have (credentials for a local run absent); OTP — done; OTP HTML — pending (slot ready); save-card — mock-proven; sandbox cards and mail sink — have (fixture cards, Mailpit); legal opt-in language — have (v6 paragraph, `{legalName}` interpolated); catalog columns — pending; QR library — DT's; Jira epics — pending (Bjorn); repo decision — answered.

## Use cases → gates (E5 verdicts)

| Gate | Use cases | Verdict at E5 |
|---|---|---|
| V0 Contract v4 and reconciliation | — | *E5* |
| V1 Catalog-driven single-visit checkout | U1–U6 | *E5* |
| V2 Design v6 parity | U1, U5, U7, U13, U14, U16, U17, U19 | *E5* |
| V3 Purchase order and recovery | U8–U12, U15, U24 | *E5* |
| V4 No QR, no pass page, no age gate | U16, U25 | *E5* |
| V5 Consent and opt-in evidence | U6, U7, U13 | *E5* |
| V6 Quality | regression row | *E5* |
| V7 Hosting and proof | U22, U23, U27 | *E5* (each item its own verdict) |
| V8 Docs and status | — | *E5* |
