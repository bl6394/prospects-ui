# Sprint 0001: Day Pass single-flow checkout in Online Join (UI + BFF)

**Status:** done, 2026-09-10 — executed 2026-09-09/10 on `prospect-wallet/sprint-0001` (PRs BFF #96, UI #524). Gates G0, G1, G3, G5–G8 met; **G2 (design parity) and G4 (hosted Pay Page) transferred to SPRINT-0002 gates S2 and S5 — transferred, not passed.** Originally planned 2026-09-09.
**Inputs:** `docs/sprints/drafts/SPRINT-0001-INTENT.md`; requirements prototypes `docs/prd/prospect-wallet-demo-1-first-visit.html` and `docs/prd/prospect-wallet-demo-2-returning-visit.html` (**authoritative** for screens, copy and states — see `docs/prd/day-pass-requirements-addendum.md`, adopted 2026-09-09 after phase A) with `docs/prd/day-pass.html` for design tokens, masking and validation copy and for the Terms & conditions gate, which is kept; `docs/SEMANTIC-INDEX.md`; sibling `prospects1/docs/prd/short-term-passes-prospect-identity-prd.md` §4.3, §4.4, §5, §6 and `prospect-wallet-plan-v2.md`; drafts, critiques and `SPRINT-0001-MERGE-NOTES.md` under `docs/sprints/drafts/`.
**Verified locally (token cache `repos/`):** `online-join-ui` @ `f3242b1` (React 17, react-router v5, RTK, MUI v4, webpack 5, `@abc/pay-page-sdk` 8.1.0), `online-join-bff` @ `bc8a4bd` (Koa, `@koa/router`, `@abc/bff-toolkit` 11.29.1, Node ≥ 22; one uncommitted `src/server.ts` patch that skips the CDN manifest fetch when `OJ_UI_URL` is set — preserve it), `mico` @ `5dad4d66` (read-only reference).
**Not verified locally:** datatrak-service, email-publisher-service, any SMS provider, Ignite Payment Gateway and Order Service behaviour beyond toolkit typings, LaunchDarkly project configuration, deployed universal-wallet version. Cited as contracts only.
**Path conventions:** `UI/` = `repos/online-join-ui/src/`, `UI-T/` = `repos/online-join-ui/__tests__/`, `BFF/` = `repos/online-join-bff/src/`.
**Chapter:** none (`docs/chapters/` does not exist).

## Pyramid Index

- **L0:** Build the prototype's single-page Day Pass checkout at `/signup/day-pass?club=NNNNN`, dark behind a club-scoped flag, where a typed contact only finds a candidate, a one-time code proves possession, an opaque server-side checkout session binds the browser to an Ignite member ID, cards are collected only through Pay Page hosted fields, and every upstream is a typed adapter with a deterministic mock so all prototype paths run locally before the real lookup, code delivery, prospect, sale and wallet services exist.
- **L1:**
  - **A — Foundations.** Contract freeze, flag and club gating on both sides, dedicated route shell, scoped `--ig-*`/`dt-*` styles, env and jest housekeeping, Pay Page capture spike with real dev credentials.
  - **B — BFF trust boundary.** `/api/short-term-pass` router; opaque `OJ-PASS-SESSION` cookie with a server-side checkout store; contact lookup, challenge, verify, member-ID binding; CSRF, origin, rate limits; pass-scoped Pay Page session with purpose tagging.
  - **C — BFF purchase orchestration.** Server-owned order (date, terms, consent); synchronous idempotent purchase: authorize → persist prospect → consented wallet write → finalize sale → issue → deliver, with the failure table; adapters and stateful mocks.
  - **D — UI flow.** Identify → verify (own step) → recognized | new visitor → done; Order summary sidebar always showing the single 1-day pass line item and a date that defaults to today; terms checkbox and modal plus the Pay button in the main panel; hosted card slot reusing `PayPageEmbed`; truthful result copy. Screens follow the Riverside demos (`docs/prd/day-pass-requirements-addendum.md`).
  - **E — Proof.** Scripted local demo through the BFF (executed as eight mock runs plus reload and fault runs; the hosted-capture run is blocked pending Pay Page credentials), security and identity regression tests, existing signup regressions, coverage and lint at thresholds, a contract and readiness register naming every live gap.
- **L2:** §Overview (what ships, what does not, corrections to the intent) · §Use Cases (U1–U14) · §Architecture (route and gating, session and OTP, browser contract, adapters, identity rules, payment ordering and recovery, design packaging, UI state) · §Implementation Plan (A–E with files) · §Files Summary · §Definition of Done (G0–G8 sprint gates; L1–L5 live gates) · §Risks · §Dependencies · §Open Questions.

## Overview

The prototypes describe one page: a main panel that moves `identify → verify → recognized | newvisitor → done` with the Pay button (and the kept terms gate) at the bottom of the recognized and new-visitor steps, and an Order summary sidebar that always shows the single 1-day pass line item, a "Pick a day" date defaulting to today, and the total. This sprint builds that page in `online-join-ui` and the routes it needs in `online-join-bff`.

**Requirements addendum (2026-09-09, after phase A):** the Riverside demos (`prospect-wallet-demo-1-first-visit.html`, `prospect-wallet-demo-2-returning-visit.html`) supersede `day-pass.html` for screens, copy, fixture and flow shape; the terms gate is retained by decision. `docs/prd/day-pass-requirements-addendum.md` lists every difference. In short: no offer card (one fixed product per club), the code entry is its own "Check your email / texts" step with Start over, the date defaults to club-local today, the sidebar never shows a skeleton, the Pay button and the terms checkbox live in the main panel, the save-card control is a toggle, the nav reads "Classes · Memberships · Day pass · Visit", and the default fixture is Riverside Athletic Club at $18.00 with Jordan Reyes `jordan.reyes@email.com` / `(555) 019-2231`. Phase A work (route shell, tokens, primitives, contract, gating) is unaffected; phases C and D absorb the changes. It is the first consumer-facing surface for the prospect wallet identity model fixed by the backend plan: a person-owned Universal Wallet keyed by Ignite member UUID with owner type `MEMBER`; `PROSP`, phone, email, barcode and any placeholder agreement number are never identity.

**What ships.** (1) A club-scoped LaunchDarkly flag, dark everywhere, enforced server-side together with the club's `onlineProspects` setting on every pass route and the UI route. (2) The `dt-*` design system as scoped SCSS and five small React primitives, applied only to the new flow. (3) A BFF router with eleven browser routes and one pass-scoped Pay Page session route, request validation, a common error envelope, redacted logging, abuse controls, and an opaque server-side checkout session. (4) Typed ports for every upstream (catalog, identity directory, prospect, verification/delivery, payment, wallet, pass sale/issuance, Pay Page session), a deterministic stateful mock adapter set seeded from the prototype fixture, and platform adapters for Pay Page session reads (live in dev) and wallet entry reads (dark until the spike proves a supported query). (5) The full UI flow with every prototype state and copy, real hosted card capture, reload recovery through the checkout session, and Start again. (6) Tests to threshold in both repos, a scripted demo, a contract document, and a readiness register separating what is proven locally from what needs a live service.

**What does not ship.** No change to `mico`, universal-wallet, wallet-account-sync, datatrak, spring-cloud-config or `@abc/bff-toolkit`. No real code delivery, prospect creation, pass sale, or wallet write in any environment: those adapters are contracts with mocks and are wired only behind `STP_ADAPTER_MODE=platform` plus per-capability switches that no environment sets this sprint. No multi-day pass product (types carry `durationDays` so it is not a rewrite), no embedded (iframe) checkout, no "remember me" beyond the checkout session, no Class / Membership / Visit tabs (static links or omitted), no metrics dashboard, no diagnostics panel. Existing signup, guest and Pay Page routes are not modified except for the purpose refusal on generic poll/close.

**Corrections to the intent, verified against the code (2026-09-09).** Runtime config reaches the UI as `window.process.env` and `window.featureFlags` from `BFF/routes/static/index.html.ts`; there is no `window.env`. The Pay Page SDK delivers no token in any callback; the UI polls `GET /api/pay-page/session/:id` and reads `result.NEW_PAYMENT_METHOD.TOKEN[0]`. The due-today session is an add-token session with `deferAuthorizationToPayment: true`, so a token is not a charge. The generic Pay Page poll/close routes check only session UUID shape and club, never browser ownership. `BFF/utils/cookies.ts` (`SESSION-ID`) is called by nothing in production code and is `sameSite:'none', partitioned` for iframe use. `jose` and `ajv` are declared but unused, and `jest.config.js` maps `jose` to a mock file that does not exist. `getFeatureFlagContext` returns `{kind:'user', key:'ANONYMOUS'}` when there is no session, and nothing populates one. MICO `/trial/submit` requires address, signature, campaign and a session CSRF token; MICO `/shop/*` requires a logged-in member; neither is a viable adapter. The toolkit's `getWalletEntries(externalId)` is deprecated and documented as QA-only.

## Use Cases

Fixture (default mock club): **Riverside Athletic Club**, one product "1-day pass" at USD 18.00; Jordan Reyes, `jordan.reyes@email.com`, `(555) 019-2231`, Visa `4242` "Saved in the app last week". A second mock club (Core Health and Fitness Club — South, "Gym Floor" USD 25.00) exists for multi-club tests. Demo runs are named **Demo 1 · First visit** and **Demo 2 · Returning visit**. Fixture identities use fixed valid UUIDs. The mock directory also seeds: a same-club member with a card (member-match case), a prospect with no card, two prospects sharing one phone (ambiguous case), an expired card, and a decline card (last4 `0002`). All against `STP_ADAPTER_MODE=mock` unless noted.

| ID | Behaviour and required result | Proof |
|---|---|---|
| U1 | Flag off, missing/invalid club, or `onlineProspects` false → UI renders the existing unavailable block; every `/api/short-term-pass/*` route returns 404; legacy signup and guest paths unaffected | A2, A5, E3 |
| U2 | Flag on → identify screen: "Get your day pass" / "Start with how we can reach you. Either works.", one "Mobile number or email" field with the demo placeholder, the returning-vs-new help line, Continue in the main panel; sidebar already shows "1-day pass $18.00", "Pick a day" defaulting to today, Total, and the fine print "No membership. No recurring billing. Change plan any time before you pay." | D3, D8 |
| U3 | Invalid contact → the help line becomes the error "Enter a mobile number or an email address.", field marked invalid, focus stays | D3 |
| U4 | Unique match → **verify step**: "Check your email" / "Check your texts", "We sent a 6-digit code to **{masked}**.", six inputs, "Resend code" · "Text me instead" / "Email me instead" only when the other contact is on file · "Start over", Verify disabled until six digits; response carries only masked contact, channel availability, expiry and resend time — no name, member ID, wallet data or alternate address | B3, B4, D4, E2 |
| U5 | Start over (verify step) or Edit (new-visitor step) → challenge and any binding revoked server-side, fresh identify screen with the last contact prefilled; stale responses from the old challenge are discarded | B3, D4 |
| U6 | Correct code → session rotated and bound to member UUID; banner "✓ Welcome back, {first}", Your info with masked or full contact per typed channel, Payment with saved card chip (brand, last4, source) and "Use a different card"; terms checkbox and "Pay $18.00 and get my pass" at the bottom of the panel; sidebar adds "Paying with" and fine print "Valid {day}. Your card stays on file at {Club} — not on this website." | B4, B5, D5 |
| U7 | Wrong code ×5 → locked; expired → "That code expired"; resend inside cooldown → 429 with `retryAfterSeconds`; limits shared across resend, switch and fresh cookies | B3, E2 |
| U8 | No match → "Welcome — a few details" with "{Email|Mobile} **{contact}** Edit": first/last, optional second contact with channel-specific label, placeholder and help text, Payment section with the hosted card slot and the "Save this card for next time" toggle (on), terms checkbox, "Pay $18.00 and get my pass" | D6, D7 |
| U9 | Ambiguous match (more than one person) → unresolved-contact state with desk-help copy; no code sent, no prospect created | B3, D4 |
| U10 | Date defaults to club-local today (min today; changing it toasts "Day pass for {Today|Wed, Sep 9}"); Pay disabled until terms are accepted and the payment method is ready; checkbox and modal "Agree and close" are each an affirmative act recorded server-side with terms version and method before purchase; opening the modal is not acceptance | C1, D8, D9 |
| U11 | Recognized + saved card → Pay → authorize on stored entry, card never re-entered; done page banner "✓ You're in, {first}", pass block "1-day pass · {day}", "Get the {Club} app" and "Start again", browser URL becomes `…/pass`; sidebar "Receipt" with "Paid with Visa ••4242" and fine print "Receipt emailed/texted to {masked}. Your card stays on file at {Club} — not on this website." | C3, C5, D10 |
| U12 | Recognized + new card, save on → hosted capture → authorize → entry added to the **existing** owner (`createWalletOwner` never called) → sale → done shows saved-card confirmation. Save off → no wallet call, existing entries untouched | C3, C4, D10, E2 |
| U13 | New visitor, save on → authorize → prospect persisted → member UUID → owner by `(memberId, MEMBER, org)` → entry → sale → issue → deliver; second contact stored as a lookup key; the new contacts are recognized on the next run. Save off → prospect and second contact persisted, no owner or entry; done says "You chose not to save a card." | C3, C4, C5, E1, E2 |
| U14 | Recognized person with no usable card → verifies normally, enters a new card. Wallet **unavailable** shows Retry and is distinct from **empty** | B5, D5 |
| U15 | Existing **member** matches → proceeds as member: verify, bind, list their wallet, sell; no metadata or lifecycle change | B4, C4, E2 |
| U16 | Double-click, lost response, refresh mid-purchase, authorization decline or timeout, prospect failure, wallet failure, sale failure, delivery failure → no duplicate charge, person, entry or pass; truthful independent status for payment, save and delivery | C2, C5, E2 |
| U17 | Reload after verify → recognized state rehydrated from the checkout session; Start again → checkout revoked, identify page with the last contact prefilled; a new visitor's checkout grants access to that order's result only, later wallet retrieval needs a code | B2, B6, D11 |
| U18 | Page loaded inside an iframe → renders a link to open checkout top-level; no legacy card entry fallback | D1 |

## Architecture

### Route, shell, gating

```
UI  /signup/day-pass?club=NNNNN        BrowserRouter basename="/signup" (UI/index.tsx); PAGES.shortTermPass = '/day-pass'
    App.tsx: isShortTermPassRoute → <ShortTermPassPage/> in its own shell, before the existing signup
             initialization (club fetches, trackers, stepper); existing routes move under <SignupShell/> unchanged.
             flag off || !onlineProspects || no club → existing "This page is not available" block.

BFF /api/short-term-pass               new KoaRouter mounted in publicRouter before staticRouter; avoids the /api/online-join/(.*) proxy
    every route: resolveClub(query|checkout) → LD `oj-short-term-pass-checkout` {kind:'club', key: 5-digit padded} AND club.onlineProspects
                 → 404 {code:'NOT_FOUND'} when either is false or the club cannot be resolved (fail closed on LD or settings errors)
```

Flag delivery: the BFF evaluates `oj-short-term-pass-checkout` in the parallel block of `BFF/routes/static/index.html.ts` with an explicit club context built from the validated `club` query parameter (today the context is `ANONYMOUS`; this is task A2) and serializes `window.featureFlags.oj_short_term_pass_checkout`. The UI reads it through `FEATURE_FLAGS` in `UI/utils/featureFlags.ts`. The HTML flag is a UI hint; the API check is the authorization. `STP_LOCAL_FLAG_OVERRIDE=true` is honoured only when `NODE_ENV !== 'production'`. Pay Page's location lookup pads clubs to six digits while LD pads to five; both mappings stay distinct and tested.

### Session, challenge, abuse controls

- **Checkout cookie** `OJ-PASS-SESSION`: opaque random ID; HttpOnly, Secure, `SameSite=Lax`, host-only, path `/`; non-Secure allowed only for HTTP localhost in mock mode. Server-side `CheckoutStore` record: checkout ID, club/org/location (bound at creation, immutable), state, candidate and bound member UUID, challenge, order, consents, CSRF token, hosted-session references, generation counter, idle 30 min / absolute 2 h. In-memory store behind `CheckoutStorePort`; the production contract (shared, atomic) is written in the contract doc and required by live gate L4.
- **CSRF**: token issued by `POST /checkouts`, required on every mutation, bound to the checkout. **Origin**: allowlist `STP_ALLOWED_ORIGINS`, fail-closed whenever the flag can be on; missing or disallowed Origin on a mutation → 403.
- **Challenge**: six digits from `crypto.randomInt`, stored as `HMAC-SHA256(STP_CODE_SECRET, challengeId + code)`, compared with `timingSafeEqual`; expiry 10 min; 5 attempts then locked; resend cooldown 30 s; 5 sends per contact+club per 15 min; 20 identify calls per IP per 15 min; 300 ms minimum response latency on identify. Resend, switch and Change invalidate the old challenge; limits are shared across them. Verify atomically consumes the challenge and rotates the session ID. Mock mode uses `STP_MOCK_OTP_CODE` (default `123456`) and echoes it only in a mock-only `debug` field; platform mode never logs or returns a code (test-pinned).
- **Disclosure**: before verification the browser receives only the outcome (`challenge` | `newVisitor` | `ambiguous`), the submitted-channel mask, whether an alternate channel exists, expiry and resend time. Switching sends to the server-held alternate contact and shows "Code sent by text/email", never a mask of an unsubmitted address. The prototype's distinct no-match state makes full anti-enumeration impossible; the residual disclosure is recorded for security review.
- **Identity binding**: verify binds the checkout to the candidate's member UUID and home club. A new visitor's checkout is bound to the order it creates, not to a verified contact; wallet reads on that checkout are refused until a code is verified.
- Typed authorization errors (401 expired, 403 CSRF/origin, 429) so they never trigger the existing global "network blocked" modal.

### Browser-facing contract (`/api/short-term-pass`)

Bodies never accept `memberId`, owner/user/entry IDs, org/location, agreement metadata, price, terminal ID or PG token; schemas use `additionalProperties:false` and reject. Every response is `no-store`. Error envelope `{code, message, retryable, correlationId, retryAfterSeconds?}`; 400 validation, 401 expired/unverified, 403 CSRF/origin/ownership, 404 disabled or not owned, 409 ambiguity or idempotency conflict, 429 throttled, 502/503 upstream.

| Method / path | Request | Server work / response |
|---|---|---|
| `POST /checkouts` | `{clubNumber}` | Gates; create checkout; set cookie; return `checkoutId`, `csrfToken`, club (name, number, timezone, links), offer (`offerId`, name, `amountMinor`, currency, perks, `durationDays`), terms (`version`, html), `captureMode: 'paypage' | 'mock'` |
| `POST /checkouts/:id/identify` | `{contact}` | Normalize (email lower-case; phone → 10 digits, strip leading 1); lookup at club; `challenge` (send first code) \| `newVisitor` \| `ambiguous` |
| `POST /checkouts/:id/challenge` | `{action: 'resend' | 'switch-channel'}` | Rotate code / switch to server-held alternate; shared limits |
| `POST /checkouts/:id/verify` | `{code}` | Consume challenge, rotate session, bind member UUID; return `{person:{firstName,lastName,email|emailMasked,phone|phoneMasked}}` and create the order shell |
| `DELETE /checkouts/:id/identity` | — | Change contact / re-identify: revoke challenge, binding, hosted session and order; keep the safe contact hint |
| `GET /checkouts/:id/wallet` | — | Verified sessions only; `{status:'ok', cards:[{selectionRef, brand, last4, source}]}` \| `{status:'unavailable'}`; empty is `ok` with `[]` |
| `PUT /checkouts/:id/order` | `{visitDate, terms:{accepted, method:'checkbox'|'modal'}, saveCard}` | Validate club-local date (min today; max from catalog if any); record terms version, method, server time; return order summary with authoritative `amountMinor` |
| `POST /checkouts/:id/purchases` | `Idempotency-Key`; `{payment: {kind:'saved', selectionRef} | {kind:'hosted', payPageSessionId}, profile?: {firstName, lastName, secondaryContact?}}` | Validate gates, ownership, order readiness; run the orchestrator synchronously; return purchase result (see below) |
| `GET /checkouts/:id/purchases/:pid` | — | Sanitized status for refresh recovery: payment, person, wallet, sale, issuance, delivery as independent fields |
| `POST /checkouts/:id/purchases/:pid/wallet-retry` | — | Retry only the failed wallet step for this purchase; never authorizes or sells again; requires a verified identity |
| `DELETE /checkouts/:id` | — | Start again: revoke browser access; durable operation records are kept |

Pay Page: `POST /api/pay-page/session/short-term-pass` `{checkoutId}` creates a due-today add-token session with server-fixed `paymentMethods:['CARD']` and deferred authorization, tagged `purpose:'short-term-pass'` and owned by the checkout; returns session URL/ID only. The BFF re-reads the session for `tokenId`, brand, last4, expiry and holder when executing the purchase. The generic `GET /session/:id` and `PUT /session/:id/close` refuse sessions carrying a pass purpose (fail closed); existing signup sessions are otherwise untouched.

Purchase result: `{purchaseId, state, payment:{status, brand, last4}, person:{created:boolean}, wallet:{status:'saved'|'not-requested'|'failed-retryable'|'unavailable'}, sale:{status, receiptNumber}, pass:{status, passId, visitDate, qrPayload}, delivery:{status:'sent'|'pending'|'failed', channel, masked}}`. The UI shows "Paid", "saved to your wallet", and "We emailed/texted it" only from the corresponding confirmed field.

### Upstream adapters and mock strategy

`STP_ADAPTER_MODE=mock|platform` selects the adapter set at boot; production refuses `mock` and any flag override; live capabilities are individually switched (`STP_WALLET_READS`, `STP_WALLET_WRITES`, later others) and default off; a missing live operation fails closed with `NOT_ENABLED`, never a fixture success. Every adapter has a runtime-validated response schema, timeout, sanitized error mapping and a capability report exposed to the readiness register.

| Port | Operations | Mock (ships) | Platform this sprint | Real upstream (contract only) |
|---|---|---|---|---|
| `ClubCatalogPort` | club → org/location/timezone/branding/links; offer(s) with `amountMinor`, currency, `durationDays`, terms version and html | per-club fixture; default = prototype offer; terms from club `prospectTerms` when set, else the prototype template, `version = sha256(html)` | club name via existing MICO `getClub` pattern; org/location via a shared `LocationResolver` (TTL cache) extracted from the payPage pattern | POS sale items (`/pos/saleItems.spr` needs a member); product owner decides |
| `IdentityDirectoryPort` | `findByContact(club, channel, value) → none | unique | ambiguous`; `getPerson(memberId)`; `addContact` | seeded in-memory directory; `ProspectPort.create` appends; persists across Start again | — | none exists (MICO has no lookup by contact); OQ-1 |
| `ProspectPort` | `create({club, first, last, email?, phone?}, idempotencyKey) → memberId`; conflict on contact race | mints UUID | — | lean endpoint needed; MICO `/trial/submit` and datatrak `/member/addProspect.spr` require far more fields; OQ-1 |
| `VerificationPort` | `send(channel, destination, code)`, provider status | records to an inspectable outbox; `debug` echo in mock mode only | — | email-publisher-service + SMS provider (none in the token cache); OQ-2 |
| `PaymentPort` | `authorize(source, amountMinor)`, `finalize`, `void`, `status`; `source` = server-verified hosted token or stored entry | deterministic; declines last4 `0002`; timeout fixture | — | Payment Gateway via toolkit or POS; whether POS sale captures is OQ-3 |
| `WalletPort` | `resolveOwner(memberId, org)`, `listEntries(ownerId)`, `createOwner`, `createCreditCard({pgToken, ownerIds, card metadata, metadata})` | in-memory owners/entries seeded with Visa 4242 | `listEntries` behind `STP_WALLET_READS` after spike A6 picks a supported owner-scoped query (not the deprecated `getWalletEntries`); writes typed against `ICreateWalletOwner` / `ICreateWalletCreditCard` but throw `NOT_ENABLED` until `STP_WALLET_WRITES` | universal-wallet `/wallet-entry-owner`, `/wallet-entry/credit-card` |
| `PassSalePort` | `finalizeSale(purchaseKey, authorization) → receipt`, `issue → {passId, qrPayload}`, `status` | receipt + pass + demo QR payload | — | datatrak `/pos/onlineSale.spr` or gateway charge + POS record; issuance service unknown; OQ-3, OQ-5 |
| `DeliveryPort` | `send(channel, destination, receipt/pass) → sent|pending|failed` | outbox | — | email-publisher + SMS; OQ-2 |
| `PayPageSessionReader` | `read(sessionId) → {tokenId, brand, last4, exp, holder, status}` | fixture by session prefix | **live in dev** with the payPage OAuth client-credentials via a shared `OAuthTokenService` | Order Service session API (already used by payPage) |

Mocks run the same routers, gates, schemas and orchestrator as live adapters. A test-harness-only fault switch (never a browser API) selects decline, timeout, prospect failure, wallet failure, sale failure, delivery failure.

### Identity and wallet write rules (test-pinned in C6)

1. Recognized visitors: member UUID and home club come from the verified checkout, never the body. Resolve the existing `MEMBER` owner by `(externalId = memberId, type = MEMBER, org)` and validate org/location before listing or charging an entry. No agreement-number lookups; no remote-club owner helpers.
2. New visitors: authorize first; persist the prospect; validate the returned canonical member UUID and home club. A datatrak agreement row may internally carry `PROSP`; that value never enters wallet identity or metadata.
3. Save consent false → no owner, user or entry created for storage; prospect and second contact persisted regardless.
4. Save consent true → resolve or create the `MEMBER` owner (and a `MEMBER` authorized user only if the payment consumer demonstrably requires it) by the same UUID; new prospect metadata is exactly `{dt_clubNumber, dt_memberId, dt_vpdId?, dt_memberType:'PROSPECT'}` from trusted persistence data; `dt_agreementNumber`, `dt_memberNumber`, `dt_memberOrdinal` are omitted. Existing members keep their real lifecycle and metadata.
5. Entry creation uses the server-verified `pgToken`, `ownerIds:[ownerId]`, `type:CREDIT_CARD`, gateway-supplied card metadata, and `providedId` for idempotency where supported. A Pay Page session ID is not a PG token.
6. The web read path is owner-association based. No `PRIMARY`, `ALTERNATE`, `CLUB_ACCOUNT` or `CARD_ON_FILE` assignment is created to make a call work. An upstream that requires such roles blocks that live adapter.
7. A new card for a recognized person adds an entry to the existing owner; it never replaces or deletes one; cards are never deduplicated by last4.
8. A recursive scan of every payload the BFF sends fails the suite if `PROSP`, `agreementNumber`, `dt_agreementNumber`, `dt_memberNumber` or `dt_memberOrdinal` appears.

### Payment ordering, consent, recovery

The visit date is a calendar date in the club's timezone, **defaulting to club-local today** when the order shell is created (verify or new-visitor path), minimum today, any maximum from the catalog; the BFF re-validates at purchase time. Amounts are integer minor units with currency; the browser never computes price. Terms checkbox starts false and is independent of the default-on save consent; a price or terms revision requires a refreshed order and fresh acceptance. Pay is enabled when date, terms and payment readiness are all set and the flow is not busy; the BFF enforces the same rules.

**New-card sequence (fixes the prototype's implied gate):** Pay click → validate → `PayPageEmbed.submit()` → bounded poll of the pass-scoped session status until a token exists (timeout → typed error, no purchase) → `POST /purchases {kind:'hosted', payPageSessionId}`. Pay is never gated on a token that does not yet exist.

Each purchase has a durable operation record keyed by checkout + `Idempotency-Key` with a request fingerprint; same key + same payload replays the stored outcome, different payload → 409; one active attempt per checkout, enforced atomically in the store. Checkpoints recorded: `VALIDATED → AUTHORIZED → PERSON_PERSISTED → WALLET_RESULT → SALE_FINALIZED → ISSUED → COMPLETE` plus `FAILED` / `RECONCILING`. Execution is synchronous this sprint; the `202` / status-poll path and reconciliation ownership are contract vocabulary for Sprint 002.

| Failure boundary | Required behaviour |
|---|---|
| Hosted token invalid or authorization declined | No prospect, wallet or sale; the visitor may correct and retry after the final decline is known |
| Authorization timeout / unknown | `status()` by provider reference; show processing; never a second authorization |
| Prospect persistence fails after authorization | Void the authorization; no owner/user/entry; if the void outcome is unknown, `RECONCILING` with an order reference and no success claim |
| Contact race or conflict at create | Do not treat the returned candidate as authenticated; void or reconcile; return to verification |
| Owner/user/entry creation fails after prospect commit | Keep prospect and existing entries; `wallet.status:'failed-retryable'`; continue the sale; never say saved; `wallet-retry` resumes only the wallet step |
| Sale finalization fails after wallet save | Keep prospect and consented wallet; void or refund per confirmed payment state; no pass; explain sale failure separately from save outcome |
| Issuance fails after sale | Resume issuance by purchase ID; no second charge; permanent failure → refund and `pass.status:'not-issued'` |
| Delivery fails | Pass and receipt stay visible; `delivery.status:'failed'`; bounded delivery retry; never claim "emailed/texted" |
| Refresh, browser loss, session expiry | Recover through `GET /purchases/:pid` on the owned checkout; re-verify to regain wallet access |

### Design-system packaging

`UI/styles/short-term-pass.scss` declares the prototype's `--ig-*` variables on `.short-term-pass` (never `:root`) and nests every `.dt-*` and page-local class (`.offer`, `.otp`, `.paysel`, `.pass`, `.srow`, `.total`, `.skeleton`, `.fine`, `.toast`, `.fade`) under it; no `body`, `:root` or universal-selector overrides are ported. Five primitives in `UI/components/dt/`: `DtButton`, `DtField` (label, input, help/error), `DtCheckbox`, `DtAlert`, `DtWidget` (with header); the terms modal is MUI v4 `Dialog` with the scoped class on its portal; links are plain elements. `PayPageEmbed` is reused as is. Inter loads from Google Fonts only if `setSecurityHeaders.ts` already allows `fonts.googleapis.com` / `fonts.gstatic.com`; otherwise `--ig-font` falls back to `system-ui`. Prototype geometry (1440 px layout, 424 px sidebar, stacked below 960 px) and reduced-motion support are kept. The new shell does not wait on `colorSchemaReady`; it uses the `--ig-*` tokens and the trusted club name from `POST /checkouts`. Header (per the Riverside demos) shows the club logo and name, the nav "Classes · Memberships · Day pass · Visit" with "Day pass" active, and "🔒 Secure checkout"; no location switcher; nav items render as links only for destinations the catalog supplies, otherwise as non-interactive labels; no `href="#"` controls. The save-card control is styled as a toggle switch (the demos' `.toggle`/`.switch`), keeping the checkbox semantics. The Pay button and the terms row sit at the bottom of the main panel on the recognized and new-visitor steps; the sidebar carries no buttons.

### UI state

`UI/reducers/shortTermPass/shortTermPassSlice.ts` holds a discriminated `step` (`bootstrapping | identify | verify | recognized | newVisitor | submitting | complete | unavailable`; `verify` is its own screen), `checkout` (id, csrf, club, offer, terms, captureMode), `contact` (raw, channel, normalized, masked), `challenge` (expiry, resendAfter, altChannelAvailable, locked), `person`, `wallet` (`status`, cards), `paymentChoice` (`useSaved`, `selectionRef`, `saveCard`), `capture` (sessionId, status), `order` (visitDate, terms accepted/method, amount), `purchase` (result), `error`, and a `generation` counter used to drop stale responses. OTP digits stay component-local; tokens, PANs and session secrets never enter Redux or storage. Thunks mirror the routes. `visitDate` is initialised to the club-local today returned by the BFF, so `canPaySelector = terms.accepted && (useSaved ? !!selectionRef : capture.status === 'ready') && (step !== 'newVisitor' || profileComplete)`.

## Implementation Plan

**Sizing:** 12–15 engineering days across a BFF lane and a UI lane, QA shared; A first (both), then B ∥ D and C ∥ D against frozen fixtures, then E. Assign owners at kickoff. Tests are written per task, not at the end.

### A — Foundations · ~2.5 days · both lanes

| # | Task | Files |
|---|---|---|
| A1 | Contract freeze: browser DTOs, error envelope, state transitions, order/consent rules, fixture identities, failure scenarios, adapter mode rules, env matrix; capability register skeleton | NEW `docs/contracts/short-term-pass-bff.md` (this repo); `UI/interfaces/api/shortTermPass.ts`; `BFF/routes/shortTermPass/schemas.ts` |
| A2 | Flag + club gating: evaluate `oj-short-term-pass-checkout` at HTML render with an explicit club context from the validated query; serialize `window.featureFlags.oj_short_term_pass_checkout`; `requireShortTermPass` middleware (LD + `onlineProspects` + club resolution, fail closed, `STP_LOCAL_FLAG_OVERRIDE` non-production only) | MODIFY `BFF/routes/static/index.html.ts`, `BFF/utils/getFeatureFlagContext.ts` (+ tests); NEW `BFF/utils/middlewares/requireShortTermPass.ts` |
| A3 | Env and boot: `optionalEnv` += `STP_ADAPTER_MODE`, `STP_SESSION_SECRET`, `STP_CODE_SECRET`, `STP_MOCK_OTP_CODE`, `STP_ALLOWED_ORIGINS`, `STP_LOCAL_FLAG_OVERRIDE`, `STP_WALLET_READS`, `STP_WALLET_WRITES`, `UNIVERSAL_WALLET_API_URL`; `.env.example` entries; boot guard: production refuses mock mode and any override, requires secrets when the flag can be on; feature-off production still boots | MODIFY `BFF/env.ts`, `.env.example`, `BFF/server.ts`, `BFF/services/healthCheck.ts` |
| A4 | Housekeeping: create `src/__mocks__/jose.ts` (passthrough) or remove the dangling `moduleNameMapper`; verify CSP for fonts; add `/api/short-term-pass` and `/api/pay-page` proxy entries to `webpack.dev.config.js` for :3001 developers | `BFF/jest.config.js` / `BFF/__mocks__/jose.ts`; `UI/webpack.dev.config.js`; read `BFF/utils/setSecurityHeaders.ts` |
| A5 | UI route and shell: `PAGES.shortTermPass`, `FEATURE_FLAGS.OJ_SHORT_TERM_PASS_CHECKOUT`; `App.tsx` branch renders `ShortTermPassPage` before signup initialization; existing routes extracted into `SignupShell` unchanged; iframe detection → top-level link; unavailable block for flag off / no club / `onlineProspects` false; tests for each | MODIFY `UI/App.tsx`, `UI/common/constants.ts`, `UI/utils/featureFlags.ts`; NEW `UI/routes/SignupShell.tsx`, `UI/routes/ShortTermPass/ShortTermPassPage.tsx`; `UI-T/App.test.tsx` |
| A6 | Spikes (time-boxed, 1 day total): (a) real Pay Page session create → embed → submit → poll with the dev credentials, recording the exact status sequence and the token shape; (b) toolkit vs HTTP client for an owner-scoped wallet entry query; (c) LD project access for the flag key. Outcomes recorded in the contract doc | `docs/contracts/short-term-pass-bff.md` |
| A7 | Scoped styles and primitives with tests; isolation test that existing `Header`/`Footer`/`GuestPage` markup carries no `.dt-*` and `:root` has no `--ig-*` | NEW `UI/styles/short-term-pass.scss`, `UI/components/dt/{DtButton,DtField,DtCheckbox,DtAlert,DtWidget}.tsx`, `UI-T/components/dt/*.test.tsx` |

**Exit:** schemas and fixtures executable in both suites; flag off yields 404/unavailable everywhere; Pay Page spike recorded; no task depends on an assumed upstream.

### B — BFF trust boundary · ~3.5 days · BFF lane

| # | Task | Files |
|---|---|---|
| B1 | Router skeleton mounted before static; per-route validation (`ajv`, `additionalProperties:false`), error envelope, `no-store`, CSRF and Origin middleware, typed auth errors; history-fallback regression test for API paths | NEW `BFF/routes/shortTermPass/{index,identify,challenge,verify,wallet,order,purchase,session}.ts`; MODIFY `BFF/routes.ts`; NEW `BFF/utils/middlewares/{csrf,originAllowlist,rateLimit}.ts` |
| B2 | `CheckoutStore` port + in-memory adapter (sweep, generation counter, atomic state transitions); `OJ-PASS-SESSION` cookie set/rotate/revoke; `POST /checkouts`, `DELETE /checkouts/:id`, `DELETE /checkouts/:id/identity` | NEW `BFF/services/shortTermPass/{checkoutStore,session}.ts`, `adapters/mock/checkoutStore.ts` |
| B3 | Contact normalization and masking per the prototype; identify / challenge (resend, switch) / verify with hashed codes, expiry, attempt cap, cooldown, per-contact and per-IP limits, timing floor, ambiguous outcome; mock-only `debug` echo | NEW `BFF/services/shortTermPass/{contact,challenge,identify}.ts`; ports `identityDirectory`, `verification`; mock adapters and `fixtures/directory.ts` |
| B4 | Verify binds member UUID and home club; member vs prospect both proceed; person read with masked-vs-full by typed channel; response key allowlist pinned | `verify.ts`; `BFF/services/shortTermPass/person.ts` |
| B5 | `GET /wallet`: owner resolution by `(memberId, MEMBER, org)`, `ok`/`unavailable` distinction, opaque `selectionRef`s; `WalletPort` mock; platform `listEntries` behind `STP_WALLET_READS` per spike A6(b) | `BFF/services/shortTermPass/wallet.ts`, `ports/wallet.ts`, `adapters/{mock,platform}/wallet.ts`, `BFF/services/platform/{locationResolver,oauthToken,toolkit}.ts` |
| B6 | Pass-scoped Pay Page session route with purpose tag and checkout ownership; generic poll/close refuse pass-purpose sessions; `PayPageSessionReader` mock and **live** platform adapter; shared OAuth token service extracted without changing payPage behaviour | MODIFY `BFF/routes/payPage/index.ts` (+ existing tests extended); NEW `BFF/services/payPage/{sessionOwnership,client}.ts`, `BFF/services/shortTermPass/adapters/{mock,platform}/payPageSession.ts` |
| B7 | Redacted logging helper (`checkoutId`, `challengeId`, outcome; never code, contact, name, token, memberId); tests: contact table, challenge lifecycle, verify wrong/expired/locked/replayed, cookie attributes, CSRF/origin, cross-checkout substitution, `debug` absent in platform mode, redaction | `BFF/services/shortTermPass/log.ts`; `BFF/routes/shortTermPass/__tests__/*.test.ts`; `BFF/services/shortTermPass/__tests__/*.test.ts` |

**Exit:** U4–U7, U9, U14, U15, U17 pass at the router level; a forged cookie, body or generic Pay Page route never retrieves another checkout's data; existing payPage tests green.

### C — BFF purchase orchestration · ~3.5 days · BFF lane

| # | Task | Files |
|---|---|---|
| C1 | `ClubCatalogPort` + mock (default club Riverside, $18.00 "1-day pass"; second club Core, $25.00); order shell created on verify / new-visitor with `visitDate` = club-local today; `PUT /order`: club-local date validation (timezone from catalog; default recorded as an open question), terms version/method/time, save consent, authoritative `amountMinor` | `BFF/services/shortTermPass/{catalog,order,terms}.ts`, `ports/clubCatalog.ts`, `adapters/mock/catalog.ts` |
| C2 | Operation store and idempotency: `Idempotency-Key` + fingerprint, one active attempt per checkout, stored outcomes, checkpoints, `GET /purchases/:pid` | `BFF/services/shortTermPass/{purchaseStore,idempotency}.ts` |
| C3 | Orchestrator: validate → authorize (saved entry via `selectionRef` ownership check, or hosted token via `PayPageSessionReader`) → persist prospect (new) with second contact and conflict handling → consented wallet write → finalize sale → issue → deliver; the failure table; typed result | `BFF/services/shortTermPass/purchaseOrchestrator.ts`; ports `payment`, `prospect`, `passSale`, `delivery`; mock adapters incl. decline/timeout/fault switch |
| C4 | Wallet writes: idempotent `createOwner` / `createCreditCard` with metadata allowlist, existing-owner reuse, `providedId`; platform adapter typed but `NOT_ENABLED` without `STP_WALLET_WRITES`; `wallet-retry` route | `wallet.ts`, `adapters/platform/wallet.ts`, `purchase.ts` |
| C5 | Pass issuance and delivery mocks with inspectable outbox and demo QR payload; result field independence | `adapters/mock/{passSale,delivery}.ts` |
| C6 | **Identity, ordering and recovery tests**: recursive payload scan; owner externalId = bound memberId with type MEMBER and org; recognized+new card → existing owner, `createOwner` never; new-visitor call order authorize → prospect → owner → entry → sale; save off → no wallet calls; hostile bodies rejected; saved entry must belong to the bound member (403); every failure boundary; idempotent replay, different payload 409, concurrent second attempt refused; wallet-retry never re-authorizes; member-match path | `BFF/routes/shortTermPass/__tests__/purchase.test.ts`, `BFF/services/shortTermPass/__tests__/{orchestrator,idempotency,wallet}.test.ts` |
| C7 | Adapter selection module, capability report, contract doc completion (each port: request/response, upstream it stands in for, decision needed, owner) | `BFF/services/shortTermPass/adapters/index.ts`; `docs/contracts/short-term-pass-bff.md` |

**Exit:** U11–U13, U16 pass through real router and orchestrator code with ordered mock assertions and state inspection; unknown payment outcomes never trigger a second authorization.

### D — UI flow · ~4 days · UI lane

| # | Task | Files |
|---|---|---|
| D1 | Service module (`axios.create({baseURL:'/api/short-term-pass', withCredentials:true})`, CSRF header), typed interfaces, slice, thunks, selectors, generation-based stale-response drop; store registration | `UI/services/shortTermPass.ts`, `UI/interfaces/api/shortTermPass.ts`, `UI/reducers/shortTermPass/shortTermPassSlice.ts`, `UI/selectors/shortTermPass.ts`; MODIFY `UI/configureStore.ts` |
| D2 | Bootstrap: `POST /checkouts` on mount, unavailable and iframe states, shell header with trusted club data | `ShortTermPassPage.tsx`, `components/CheckoutShell.tsx` |
| D3 | `IdentifyStep` (Riverside demo): "Get your day pass" / "Start with how we can reach you. Either works."; contact field (`inputmode="email"`, `autocomplete="username"`, placeholder `you@email.com or (555) 555-0123`); help line "Bought with us before? …"; Continue on click/Enter; help line becomes the error on invalid input. No offer card. | `steps/IdentifyStep.tsx` |
| D4 | `VerifyStep` (own screen): "Check your email" / "Check your texts", "We sent a 6-digit code to **{masked}**."; six inputs with auto-advance, backspace, paste; "Resend code" with countdown; switch link only when available; "Start over"; Verify disabled until six digits; locked/expired/ambiguous states | `steps/VerifyStep.tsx` |
| D5 | `RecognizedStep`: banner "✓ Welcome back, {first}", Your info with masking per typed channel, Payment with saved card chip and source, "Use a different card" ↔ "Use {brand} •••• {last4} instead", no-card and unavailable (Retry) states; terms row and Pay button at the bottom (`components/PayBar.tsx`) | `steps/RecognizedStep.tsx`, `components/SavedCardChip.tsx`, `components/PayBar.tsx` |
| D6 | `NewVisitorStep`: "Welcome — a few details" with "{Email|Mobile} **{contact}** Edit", first/last, optional second contact with channel-specific label/placeholder/help, Payment with card slot and save toggle, the prototype's three validation messages, terms row and Pay button at the bottom | `steps/NewVisitorStep.tsx`, `components/SaveCardToggle.tsx` |
| D7 | `CardCaptureSlot`: `PayPageEmbed` when `captureMode==='paypage'` (pass-scoped session on mount, imperative `submit`, bounded poll to `ready`), `MockCardCapture` otherwise; readiness only, never a token in state | `components/CardCaptureSlot.tsx`, `components/MockCardCapture.tsx`, `hooks/useShortTermPassCapture.ts` (reuses `usePayPageSession` polling) |
| D8 | `OrderSummary` sidebar (no skeleton, no buttons): title "Order summary" / "Receipt"; line item "1-day pass $18.00"; "Pick a day" date input defaulting to today (`min` today, toast "Day pass for {Today|Wed, Sep 9}" on change); Valid / Paying with / Paid with rows; Total / Paid; three fine-print variants per the addendum | `components/OrderSummary.tsx` |
| D9 | `TermsDialog` on MUI `Dialog`: Close and "Agree and close"; the `PayBar` checkbox and the modal both `PUT /order`; opening is not acceptance; form values survive open/close and date changes | `components/TermsDialog.tsx`, `components/PayBar.tsx` |
| D10 | Pay action (`PayBar`, label `Pay $18.00 and get my pass`): validate → (hosted) submit and poll → `POST /purchases` with idempotency key; toasts with prototype copy; `DoneStep`: banner "✓ You're in, {first}", pass block with QR from `qrPayload`, "1-day pass · {day}", delivery sentence by `delivery.status`, "saved to your wallet" pill and "Next time…" line only when `wallet.status==='saved'`, wallet-retry affordance, "Get the {Club} app" (configured link or omitted), "Start again"; URL changes to `/signup/pass?club=…` via history replace with recovery on reload | `steps/DoneStep.tsx`, `components/PassBlock.tsx`, `ShortTermPassPage.tsx`; `qrcode.react` |
| D11 | Rehydrate on mount from checkout state and purchase status; Start again → `DELETE /checkouts/:id` → identify with contact prefilled; toast component | `ShortTermPassPage.tsx`, `components/Toast.tsx` |
| D12 | Tests: every step and component (RTL, repo `useSelector`/`useDispatch` convention), slice/thunk tests, `canPaySelector` table, masking, QR payload, copy assertions for every prototype string, stale-response drop, iframe link | `UI-T/routes/ShortTermPass/**`, `UI-T/reducers/shortTermPass/*`, `UI-T/selectors/shortTermPass.test.ts` |

**Exit:** all prototype states and layout match, with documented hosted-field and navigation deviations; modal and date changes do not erase entered values or remount the iframe.

### E — Proof, demo, readiness · ~2 days · both lanes

| # | Task | Files / evidence |
|---|---|---|
| E1 | Demo script (`npm run demo:short-term-pass` in the BFF, runner dependency added deliberately): boots against `STP_ADAPTER_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `OJ_UI_URL`; runs grouped as **Demo 1 · First visit** (new visitor save on; new visitor save off; Start again then re-verify by the secondary contact) and **Demo 2 · Returning visit** (saved card; recognized new card save on; recognized new card save off; decline `0002`) — asserting API results, mock wallet state and outbox, plus a reload run; one **real hosted capture** run against Pay Page dev with mock sale/wallet, labelled as such (blocked until the six `PAY_PAGE_*`/`ABC_CORE_API_URL` variables exist locally; see BLOCKERS B1) | NEW `BFF/scripts/short-term-pass-demo.ts`; `docs/demos/short-term-pass-local-demo.md` |
| E2 | Security and fault matrix executed: pre-verify leakage, OTP wrong/expired/replayed, channel invalidation, cookie/CSRF/origin, cross-club and cross-checkout substitution, generic Pay Page bypass, price/date/terms tampering, concurrent purchase, every failure checkpoint, wallet-retry, member match, ambiguous match | B7, C6 suites; results in validation doc |
| E3 | UI regressions: existing signup, guest and Pay Page flows; deep-link refresh; disabled/missing club; history fallback; manual browser check of the existing signup route and the new page at 1440 and 375 px; keyboard, focus, labels and status announcements on the new page | `UI-T/App.test.tsx` and existing suites; `docs/validation/short-term-pass-ui.md` |
| E4 | Full `npm run lint`, `npm run build`, `npm run test:cov -- --runInBand` in both repos; record commands, SHAs, coverage numbers; no lowered thresholds or exclusions | `docs/validation/short-term-pass-bff.md`, UI validation doc; sprint ledger |
| E5 | Readiness register: each live capability classified proven / blocked with owner and evidence; `docs/SEMANTIC-INDEX.md` note that the three online-join repos remain unindexed and where the new code lives | `docs/contracts/short-term-pass-bff.md`; `docs/SEMANTIC-INDEX.md` |

Local demo: UI on :3001, BFF on :3000, open `http://localhost:3000/signup/day-pass?club=<fixtureClub>` through the BFF so cookies and runtime flags are exercised. No MICO change required. Optional wallet compose validation uses the sibling infrastructure unchanged and is labelled separately.

## Files Summary

| Repo | Paths | Action |
|---|---|---|
| online-join-bff | `src/routes.ts` | MODIFY: mount `shortTermPassRouter` |
| online-join-bff | `src/routes/shortTermPass/{index,schemas,identify,challenge,verify,wallet,order,purchase,session}.ts` + `__tests__/*` | NEW |
| online-join-bff | `src/services/shortTermPass/{checkoutStore,session,contact,challenge,identify,person,wallet,catalog,order,terms,purchaseStore,idempotency,purchaseOrchestrator,log}.ts`; `ports/*.ts`; `adapters/{index,mock/*,platform/*}.ts`; `fixtures/*.ts`; `__tests__/*` | NEW |
| online-join-bff | `src/services/platform/{locationResolver,oauthToken,toolkit}.ts`; `src/services/payPage/{sessionOwnership,client}.ts` (+ tests) | NEW |
| online-join-bff | `src/utils/middlewares/{requireShortTermPass,csrf,originAllowlist,rateLimit}.ts` (+ tests) | NEW |
| online-join-bff | `src/routes/payPage/index.ts` (+ `__tests__/index.test.ts`) | MODIFY: pass-scoped session route; purpose refusal on generic poll/close |
| online-join-bff | `src/routes/static/index.html.ts`, `src/utils/getFeatureFlagContext.ts` (+ tests) | MODIFY: flag with explicit club context |
| online-join-bff | `src/env.ts`, `.env.example`, `src/server.ts`, `src/services/healthCheck.ts` | MODIFY: env, boot guard (preserve the existing manifest-skip patch) |
| online-join-bff | `jest.config.js` or `src/__mocks__/jose.ts` | MODIFY / NEW |
| online-join-bff | `scripts/short-term-pass-demo.ts`, `package.json` (+ lockfile if needed) | NEW / MODIFY |
| online-join-ui | `src/App.tsx`, `src/common/constants.ts`, `src/utils/featureFlags.ts`, `src/configureStore.ts`, `webpack.dev.config.js`, `package.json` (`qrcode.react`) | MODIFY |
| online-join-ui | `src/routes/SignupShell.tsx` | NEW: existing signup shell, behaviour unchanged |
| online-join-ui | `src/routes/ShortTermPass/{ShortTermPassPage.tsx,steps/*.tsx,components/*.tsx,hooks/*.ts}` | NEW |
| online-join-ui | `src/styles/short-term-pass.scss`; `src/components/dt/{DtButton,DtField,DtCheckbox,DtAlert,DtWidget}.tsx`, `index.ts` | NEW |
| online-join-ui | `src/reducers/shortTermPass/shortTermPassSlice.ts`, `src/selectors/shortTermPass.ts`, `src/services/shortTermPass.ts`, `src/interfaces/api/shortTermPass.ts` | NEW |
| online-join-ui | `__tests__/routes/ShortTermPass/**`, `__tests__/components/dt/**`, `__tests__/reducers/shortTermPass/**`, `__tests__/selectors/shortTermPass.test.ts`, `__tests__/App.test.tsx` | NEW / MODIFY |
| this repo | `docs/contracts/short-term-pass-bff.md`, `docs/demos/short-term-pass-local-demo.md`, `docs/validation/short-term-pass-{bff,ui}.md` | NEW |
| this repo | `docs/SEMANTIC-INDEX.md`, `docs/sprints/ledger.yaml` | MODIFY |
| Handoffs (not in cache) | LD flag `oj-short-term-pass-checkout` (club kind, default off); per-environment `STP_*` values; decisions OQ-1…OQ-9 | contracts with named owners |

Not modified: `mico/**`; any wallet repo; `BFF/utils/proxyFactory.ts`; `BFF/utils/cookies.ts`; existing UI routes, `Header`, `Footer`, `reducers/index.ts`; existing signup Pay Page session semantics beyond the purpose refusal.

## Definition of Done

Role slots: UI, BFF, QA, SECURITY, PRODUCT, DESIGN (the UI lead may sign G2 with a documented deviation list if no designer is assigned), PAYMENTS, IDENTITY, WALLET, PLATFORM. Owners named at kickoff; a gate with no name does not sign off. Scope is recorded at A1 and not silently changed when an upstream is unavailable.

### Sprint delivery gates

| Gate | Lane · owner | Passes when |
|---|---|---|
| G0 — Ready | (eng) UI+BFF | Contract doc frozen; source SHAs and the existing server patch recorded; spikes A6 recorded; LD flag created or requested with owner; env in `.env.example`; owners named |
| G1 — Product flow | (product) PRODUCT+QA | U2–U18 run locally through the BFF via the demo script; all save on/off variants; next visit by secondary contact; identity, wallet and outbox state inspected, not inferred from copy |
| G2 — Prototype parity | (design) DESIGN | Side-by-side with `docs/prd/day-pass.html`: all steps, both sidebar modes, terms modal, every copy string (D12), masking, disabled states, 1440/375 px; hosted-field and navigation deviations documented |
| G3 — Identity boundary | (eng, security) BFF+SECURITY | C6 and B7 green: payload scan; owner by bound member UUID, type MEMBER, org; existing-owner reuse; call order; hostile bodies rejected; entry ownership; cross-checkout and cross-club substitution refused; no pre-verify disclosure; attempt/rate limits; redaction |
| G4 — PCI boundary | (eng, security) PAYMENTS+QA | No PAN/CVC/expiry input or state in `UI/routes/ShortTermPass/**` (static test); `/purchases` schema rejects `pan`, `cvc`, `expiry`, `tokenId`; **real Pay Page dev run recorded** (session create → embed → submit → poll → BFF re-read), separately from the mock capture proof |
| G5 — Transaction integrity | (eng) BFF+QA | Ordered authorize → persist → consented save → sale → issue → deliver; no-save persistence; every failure boundary; idempotent replay, 409 on payload change, concurrent attempt refused; wallet-retry never re-authorizes; no false paid/saved/sent status |
| G6 — Dark and isolated | (eng) UI+BFF | Flag off → 404 on every registered pass route (test iterates the router stack) and unavailable UI; both checks server-side; production refuses mock mode and overrides; existing signup, guest and Pay Page suites green; generic Pay Page routes refuse pass-purpose sessions |
| G7 — Quality | (eng) UI+BFF+QA | Lint and build clean; UI ≥ 80 % lines/statements; BFF ≥ 84 % lines/statements and ≥ 67 % branches/functions; no lowered thresholds or exclusions; manual browser check of existing signup route recorded |
| G8 — Operable local delivery | (eng) BFF+QA | Demo script deterministic; adapter mode and capability report visible; faults reproducible via the harness; redacted correlation logs; readiness register complete with owners |

**Completion vocabulary:** G0–G8 pass = *sprint implementation complete; local checkout complete; live integration blocked* while any L-gate is open. If Pay Page dev access fails during the sprint, G4 stays pending and the report says "mock demo complete; hosted capture unverified". Passing G0–G8 does not authorize production enablement.

### Live-enablement gates (registered now, owned separately)

| Gate | Owner | Required evidence |
|---|---|---|
| L1 — Identity and code delivery | IDENTITY+SECURITY | Real club-scoped lookup by contact; duplicate and reassigned-contact policy; lean prospect creation from name + contacts; provider send/verify; abuse limits on a shared store |
| L2 — Charge, sale, issuance | PAYMENTS+PASS | Token-to-PG mapping and stored-card authorization proven without an agreement; capture/void/refund semantics; server price/tax/date; redeemable pass and delivery status; reconciliation exercised |
| L3 — Wallet readiness | WALLET | Deployed universal-wallet handles a `MEMBER` owner with no agreement number (confirm whether the dedup-key change seen in the wallet-repos snapshot is deployed); prospect-safe sync lane per sibling SPRINT-0001; supported owner-scoped read and charge path without assignment roles; scopes and tenant controls |
| L4 — Durability and operations | PLATFORM+BFF | Shared atomic checkout, rate-limit and operation stores; reconciliation owner; restart and multi-instance recovery; token retention policy; production config default off |
| L5 — Product claims | PRODUCT+DESIGN | Approved terms and stored-credential wording; catalog, timezone and eligibility per club; app and navigation destinations; app/desk reuse proven before unconditional cross-channel copy |

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | Local success mistaken for a live contract | Capability report per adapter; G4 real hosted run; L-gates; completion vocabulary |
| R2 | Pay Page token assumed to charge or to be a wallet `pgToken` | Spike A6(a); explicit `PaymentPort.authorize`; token compatibility is L2 evidence, not an assumption |
| R3 | Generic Pay Page poll/close bypass pass authorization | Purpose tag on pass sessions; generic routes refuse them; existing payPage tests extended |
| R4 | OTP brute force, replay, enumeration | Hashed codes, atomic consumption, attempt cap, cooldown, per-contact and per-IP limits, timing floor, minimal disclosure; Turnstile and shared store before flag-on (L1) |
| R5 | Household-shared or colliding contacts | Ambiguous state; no heuristic selection; unverified second contact is a lookup key, never merge authority; conflict at create returns to verification |
| R6 | In-memory stores lose state or double-charge after restart | Memory is mock-only by declaration; production refuses mock; durable stores are L4 |
| R7 | Prospect creation fails after authorization | Void; `RECONCILING` if void outcome unknown; no wallet identity; no success claim |
| R8 | Save fails after payment | Independent `wallet.status`; wallet-only retry; prospect kept; never "saved" |
| R9 | Pay button deadlock on new cards | Readiness-based gate; submit → bounded poll → purchase; tested with the real embed interface in A6(a) and E1 |
| R10 | `dt` styles leak into signup; new route inherits signup initialization | Scoped under `.short-term-pass`; no `:root`/`body` overrides; `SignupShell` extraction; isolation test; manual browser check |
| R11 | LD evaluated with `ANONYMOUS` context at render | A2 builds an explicit club context; API re-checks; fail closed |
| R12 | Wallet helper is QA-only or re-homes owners | Spike A6(b); owner resolved by member UUID + type + org; reads behind `STP_WALLET_READS`; no last4 dedup |
| R13 | Club timezone unknown for "today" | Catalog supplies timezone; default and midnight tests recorded; OQ-6 |
| R14 | Developers on :3001 hit the MICO proxy for new APIs | A4 dev-proxy entries |
| R15 | Coverage floors with many new files | Tests per task; G7 tracked daily |
| R16 | `jose` mock mapping breaks the BFF suite on first import | A4 on day one |
| R17 | Scope exceeds staffing | Trimmed scope fixed at A1; cut order if needed: real wallet read adapter, then the sixth demo run, never OTP, hosted fields, identity rules, failure behaviour or tests |

## Dependencies

- **Code/infra:** clones current (`git pull --ff-only`, preserving the uncommitted BFF server patch); Node ≥ 22; local BFF `.env` with `OJ_UI_URL`, `LAUNCHDARKLY_SDKKEY`, `STP_ADAPTER_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_SESSION_SECRET`, `STP_CODE_SECRET`, `STP_ALLOWED_ORIGINS=http://localhost:3000`; `qrcode.react` in the UI; Artifactory access for installs.
- **Access:** Pay Page dev credentials already used by the payPage route (confirmed available); LaunchDarkly write access or a named owner to create `oj-short-term-pass-checkout`; universal-wallet dev URL and client authorities only if `STP_WALLET_READS` is exercised.
- **Backend alignment:** sibling `prospects1` SPRINT-0001 (in progress) establishes the prospect-safe wallet lane; `STP_WALLET_WRITES` is never true before it ships and L3 is signed. Its decision register should record OQ-1…OQ-9 alongside R-03 (web day pass in v1).
- **People/decisions:** UI, BFF, QA, SECURITY, PRODUCT owners by 2026-09-11; owners for OQ-1…OQ-9.
- **Index leaves consulted:** `themes/identity-by-member-id.md`, `themes/agreement-number-and-prosp.md` (hazards #1, #4, #5, #10, #11), `repos/universal-wallet/identity/owner.md`, `repos/universal-wallet/walletentry/credit-card.md` (`pgToken @NotNull`, `ownerIds`, `providedId`), `repos/commerce-universal-wallet-sdk/sdk.md`.

## Open Questions

**Decided in this sprint (from drafts, critiques, interview and the 2026-09-09 addendum):** the Riverside demos are authoritative for screens and copy, with the terms gate kept; verify is its own step; Pay and terms live in the main panel; route `/signup/day-pass` under the existing basename with its own shell; scoped SCSS plus five primitives and MUI `Dialog`; opaque server-side checkout session, `SameSite=Lax`, top-level only; date picker kept, defaulting to club-local today, min today; diagnostics panel dropped; catalog adapter with fixture offer locally; Pay Page hosted capture with real dev credentials; ambiguous match → unresolved state; existing member → proceed as member; both LD and `onlineProspects` enforced server-side; internal naming `ShortTermPass`.

**Requested (owner and date set at kickoff; unanswered questions block only the corresponding live capability):**

| # | Question | Owner slot | Effect if unanswered |
|---|---|---|---|
| OQ-1 | Which service provides lookup by phone/email at a club and lean idempotent prospect creation from name + contacts (MICO `/trial/submit` and datatrak `addProspect.spr` require far more)? | IDENTITY | Mock identity only |
| OQ-2 | Which email and SMS providers deliver the code and the pass; consent language for a texted code; normalization and reassigned-number policy | IDENTITY+SECURITY | Mock verification and delivery only |
| OQ-3 | Does the Pay Page token map to a wallet `pgToken`, can it authorize before a person exists, and does the POS sale capture the authorization or charge separately? Which status/void/refund APIs exist? | PAYMENTS+WALLET | No live authorization, sale or saving |
| OQ-4 | Which wallet club flags and deployed prospect-lane guarantees are required; is a `MEMBER` authorized user needed by the payment consumer; is the dedup-key change deployed? | WALLET | No live wallet traffic |
| OQ-5 | What generates the desk-scannable credential and delivers it; can issuance be retried independently? | PASS/DELIVERY | Mock pass and outbox only |
| OQ-6 | Catalog, tax, timezone, date horizon, terms version and member eligibility per club; legal review of the prototype's placeholder terms | PRODUCT | Fixture catalog only |
| OQ-7 | Shared store for atomic limits and durable purchase recovery; who owns unresolved transactions | PLATFORM+BFF | Live mode unavailable |
| OQ-8 | Valid Class / Membership / Visit, location and app destinations for the shell header | PRODUCT+DESIGN | Non-interactive labels; documented deviation |
| OQ-9 | Embedded (iframe) checkout in a later sprint: required? drives cookie model and origin policy | PRODUCT | Top-level only stays |

**Carried to Sprint 002 regardless:** durable stores and the async purchase/status path; metrics; Turnstile on identify; converge payPage OAuth/location helpers onto `services/platform/*`; multi-day pass product (`durationDays`, "applies from"); embedded checkout decision; accessibility audit beyond the basics in E3; extend the semantic index over the three online-join repos.
