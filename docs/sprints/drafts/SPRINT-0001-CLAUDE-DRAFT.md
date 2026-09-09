# Sprint 0001: Day Pass single-flow checkout — identify by contact, verify by code, pay by Pay Page, wallet by member ID (online-join-ui + online-join-bff)

**Status:** draft (Claude lane), 2026-09-09. Proposed window 2026-09-10 → 2026-09-23. Source intent: `docs/sprints/drafts/SPRINT-0001-INTENT.md`.
**Inputs:** `docs/prd/day-pass.html` (requirements prototype; copy and states are normative), `docs/SEMANTIC-INDEX.md`, sibling `prospects1/docs/prd/short-term-passes-prospect-identity-prd.md` §4.3, §4.4, §5, §6, `prospects1/docs/prd/prospect-wallet-plan-v2.md` Phase 3, `prospects1/docs/sprints/SPRINT-0001.md` (backend, in progress).
**Verified locally (token cache `repos/`):** `online-join-ui` (`@abc/online-join-ui` 8.32.14; React 17, react-router v5, RTK 1.x, MUI v4, `@abc/pay-page-sdk` 8.1.0), `online-join-bff` (1.1.15; Koa 3, `@koa/router` 13, `@abc/bff-toolkit` 11.29.1, `@abc/shared-types` 8.136), `mico` (reference only). Paths below: `UI/` = `repos/online-join-ui/src/`, `UI-T/` = `repos/online-join-ui/__tests__/`, `BFF/` = `repos/online-join-bff/src/`.
**Verified via index (`prospects1/docs/semantic-index/`):** `themes/identity-by-member-id.md`, `themes/agreement-number-and-prosp.md`, `repos/universal-wallet/identity/owner.md`, `repos/universal-wallet/walletentry/credit-card.md`, `repos/commerce-universal-wallet-sdk/sdk.md`.
**Not verified locally:** datatrak-service (`/member/addProspect.spr`, `/pos/*`), email-publisher-service, any SMS provider, Ignite Payment Gateway and Order Service behaviour beyond the toolkit typings, LaunchDarkly project configuration. Cited only as contracts; no behaviour claimed.
**Chapter:** none (`docs/chapters/` does not exist).

## Pyramid Index

- **L0:** Ship the prototype's Day Pass checkout as a single page under `/signup/day-pass`, dark behind a club-scoped LaunchDarkly flag, where the typed contact only finds a candidate, a one-time code proves possession, a signed BFF cookie binds the browser to the Ignite member ID, cards are collected only through the existing Pay Page session routes, and every wallet and prospect call goes through typed BFF ports with mock adapters so all three prototype paths demo locally before the upstream services exist.
- **L1:**
  - **A — Foundations (both repos).** LD flag `oj-stp-day-pass-checkout` (kind `club`) evaluated server-side and delivered as `window.featureFlags.oj_stp_day_pass_checkout`; BFF routes 404 with the flag off; UI route unreachable with the flag off or `onlineProspects` false. `dt-*` / `--ig-*` tokens productised as `UI/styles/dt/` scss scoped under `.stp-root` plus eight thin React primitives in `UI/components/dt/`; the existing signup flow imports none of it.
  - **B — BFF identity, code, session (`/api/short-term-pass`).** `identify` (lookup by normalised email or phone at the club; match → challenge + code; no match → signed identify-token), `identify/resend`, `identify/switch-channel`, `verify` (sets `STP-SESSION`, an httpOnly `jose` HS256 cookie carrying `memberId`, never any agreement value), `session` (rehydrate / clear), `terms/accept`. In-memory challenge store with hashed codes, 10-minute expiry, 5 attempts, resend cooldown, per-contact and per-IP send caps; ports for identity directory and message delivery with mock adapters seeded from the prototype fixture.
  - **C — BFF purchase orchestration.** `config` (offer, terms, club), `purchase` in three modes (`SAVED_CARD`, `NEW_CARD`, `NEW_VISITOR`). Card data reaches the BFF only as a Pay Page `sessionId`; the BFF re-reads the session server-side for the vault `tokenId` (= wallet `pgToken`). Order of operations for a new visitor is fixed: sell → persist prospect → member ID → wallet owner by `(externalId=memberId, MEMBER, locationId)` → `createCreditCard({ pgToken, ownerIds })` only with consent. Ports: `PassCatalogPort`, `PassSalePort`, `ProspectPort`, `WalletPort`, `IdentityDirectoryPort`, `MessageDeliveryPort`, `PayPageSessionReader`; adapter set chosen by `STP_ADAPTER_MODE=mock|platform`. Only `PayPageSessionReader` and `WalletPort.readEntries` get a `platform` adapter this sprint; the rest ship as documented contracts with mock adapters.
  - **D — UI flow.** One route, one slice (`UI/reducers/shortTermPass/`), four steps rendered in place (identify → recognized | new-visitor → done) with the persistent Order Summary sidebar (skeleton → date picker, line item, total, terms checkbox + modal with "Agree and close", Pay button enabled only when day and terms are set). Card capture is the existing `PayPageEmbed` rendered into the card slot, submitted by the sidebar Pay button, with a `MockCardCapture` for `STP_ADAPTER_MODE=mock`. Reload rehydrates from `GET /session`.
  - **E — Proof.** Security-regression tests in the BFF assert: no `PROSP`, `agreementNumber`, or `dt_agreementNumber` in any owner/entry payload; owner `externalId` equals the verified `memberId`; recognized + new card adds to the existing owner and never calls `createWalletOwner`; new-visitor call order is sell → prospect → owner → entry; the PRD §4.4 failure matrix; client-supplied `memberId`, `saveCard` on a saved card, or terms flags are ignored. Both suites at or above thresholds (UI 80 lines/statements; BFF 84 lines/statements, 67 branches/functions). A scripted local demo covers the three prototype paths (four runs) with the fixture `m@m.com` / `(555) 019-2231` / Visa 4242.
- **L2:** §Overview (what ships, what does not, corrections to the intent) · §Use Cases (U1–U14 exercisable; W1–W6 written down) · §Architecture (route map, sequence, session and code stores, ports and adapters, identity rules, payment path, design-system packaging) · §Implementation Plan (A–F with files and tasks) · §Files Summary · §Definition of Done (gate register by lane) · §Risks · §Dependencies · §Open Questions (answered by this draft vs requested).

## Overview

The prototype (`docs/prd/day-pass.html`, 2,821 bytes of markup, ~27 KB of behaviour, ~18 KB of tokens and styles) describes one page with a main widget and a sidebar. The main widget moves through `identify → recognized | newvisitor → done`; the sidebar carries the order, the date, the terms gate, and the Pay button. This sprint builds that page in `online-join-ui` and the routes it needs in `online-join-bff`, without touching `mico`, the wallet services, or datatrak.

**What ships.** (1) A club-scoped flag, dark everywhere, that gates both the UI route and every BFF route. (2) The `dt-*` design system as scoped scss and eight React primitives, applied only to the new flow. (3) Seven BFF routes under `/api/short-term-pass` implementing lookup, code send/verify, session binding, terms acceptance, config, and purchase, with request validation, self-contained error handling, redacted logging, and abuse controls. (4) A port/adapter layer for every upstream the flow needs, with a deterministic mock adapter set seeded from the prototype fixture and a `platform` adapter only where the toolkit already types the call and the BFF already holds credentials (Pay Page session read; universal-wallet entry read). (5) The full UI flow with all prototype states and copy, Pay Page card capture, reload rehydration, and a dev-only diagnostics panel. (6) Tests to threshold in both repos, a demo script, and a contract document for each upstream the mocks stand in for.

**What does not ship.** No change to `mico`, universal-wallet, wallet-account-sync, datatrak, spring-cloud-config, or `@abc/bff-toolkit`. No real prospect creation, pass sale, code delivery, or wallet write in any environment: those adapters are contracts with mock implementations and are wired only behind `STP_ADAPTER_MODE=platform`, which no environment sets this sprint. No multi-day pass product, no "stay logged in and buy again" beyond the session cookie's lifetime, no Class / Membership / Visit tabs (rendered as static links), no i18n. No edits to `BFF/routes/payPage/index.ts`; its OAuth and location helpers are re-implemented as a shared service and converge in a later sprint so the template and its 60 security tests stay untouched.

**Corrections to the intent, verified 2026-09-09.**
- There is no `window.env`. The BFF injects a frozen `window.process.env` (`REACT_APP_RECAPTCHA_SITEKEY`, `REACT_APP_GTAG_ID`, `REACT_APP_CLUB_REDIRECT_URL`, `PAY_PAGE_ORIGIN`) and `window.featureFlags` from `BFF/routes/static/index.html.ts:82-103`; the UI reads only `window.featureFlags` (`UI/utils/featureFlags.ts`, 17 lines, three flags) and `PAY_PAGE_ORIGIN` (`UI/routes/PaymentPage/PaymentPageWithPayPage.tsx:38`).
- The Pay Page SDK delivers no token in any callback (`MESSAGE_TYPE.SUCCESS` payload is `never`, `pay-page-sdk/dist/src/client/types.d.ts`). The existing UI polls `GET /api/pay-page/session/:id` and reads `result.NEW_PAYMENT_METHOD.TOKEN[0]` (`UI/routes/PaymentPage/hooks/usePayPageSession.ts:119-144`). That `tokenId` is the Ignite Payment Gateway vault token, which is exactly the `pgToken` universal-wallet requires on `POST /wallet-entry/credit-card` (index leaf `walletentry/credit-card.md`, `CreditCardBaseVO.pgToken @NotNull`). The plan re-reads the session server-side rather than trusting a client-posted token.
- `BFF/utils/cookies.ts` (`SESSION-ID`) is called by nothing in `src`; there is no server-side session store, `PublicState` is empty (`BFF/types/koaCustomized.ts:15`), and `jose` and `keygrip` are declared but unused. `jest.config.js:14` maps `jose` to `src/__mocks__/jose.ts`, which does not exist; the first import of `jose` will break the suite unless the mock is created or the mapping removed.
- The BFF has no global error middleware, no rate limiter, no CSRF or origin allowlist, no validator in use (`ajv` is a dependency with zero references), and no toolkit platform client initialised anywhere; `payPage` hand-rolls OAuth with global `fetch` (`BFF/routes/payPage/index.ts:24-55`) and caches club → location forever in a `Map` (`:68,125`). Logging is unredacted (`proxyFactory.ts:159` logs `authorization`; `payPage/index.ts:321` logs session bodies).
- `guestProfileFieldsSlice` is not a file; it is inline in `UI/reducers/index.ts:215-236` (329 lines of mostly `any`). The per-feature template to copy is `UI/reducers/locations/locations.ts`.
- MICO's `/trial/submit` requires street, city, state, zip, home phone, country, campaign, signature and a session CSRF token (`mico/.../ProspectController.java:63-150`), so it cannot create a day-pass prospect from name plus one contact. MICO's `/shop/*` routes are `@Secured("ROLE_USER")` and take `memberId` from the logged-in app user (`ShopController.java:53-56, 166-183`), so they cannot sell to an anonymous or code-verified prospect. Neither is a viable real adapter this sprint; both are recorded as contract gaps in §Open Questions.
- The toolkit's `telephony` client exposes only IVR calls; there is no SMS surface anywhere in the token cache.
- The UI dev server proxies only `/iclub` (`webpack.dev.config.js`), but the local stack loads the UI through the BFF on `:3000`, so `/api/short-term-pass` needs no dev-proxy entry; the demo URL is `http://localhost:3000/signup/day-pass?club=NNNNN`.

## Use Cases

### Exercisable this sprint (eng), all against `STP_ADAPTER_MODE=mock` unless noted

| ID | Use case | Prototype step / PRD | Proof |
|---|---|---|---|
| U1 | Flag off (or `onlineProspects` false) → `/signup/day-pass` renders the existing "This page is not available" block; every `/api/short-term-pass/*` route returns 404 | Constraint "dark by default" | A5, A6 |
| U2 | Flag on → identify page: pre-selected offer card ($25 Gym Floor, three perks), single "Mobile number or email" field, Continue; sidebar shows two skeleton blocks and no fine print | Step 1 | D3, D9 |
| U3 | Invalid contact → inline error "Enter a mobile number or an email address.", `aria-invalid`, focus stays | `identify()` / `go()` | D3 |
| U4 | Known email or phone → code entry appears inline, header "We know you — enter the code we sent to **{masked}**", field read-only, Change / Resend / "Text me instead" or "Email me instead" (only when the other contact is on file), Verify disabled until six digits; nothing about the person is disclosed (response carries only masked contact and channel availability) | Step 2 match | B4, B10, D4 |
| U5 | Change contact → challenge discarded, field editable, no session cookie set | `changeContact` | B4, D4 |
| U6 | Verify correct code → `STP-SESSION` cookie set; recognized page "Welcome back, {first}" with masked or full contact per typed channel, saved card chip (brand, last4, source), "Use a different card"; sidebar switches to date, line item, total, terms, Pay | Step 3 | B5, B6, D5 |
| U7 | Wrong code ×5 → challenge locked, "Start over"; expired code → "That code expired, resend"; resend inside cooldown → 429 with `retryAfter` | Abuse controls | B4, B9 |
| U8 | Unknown contact → "Welcome — a few details" with first/last name, optional second contact (other channel, prototype help text), card slot, "Save this card for next time" checked | Step 2 no match | D6 |
| U9 | Pay disabled until day (min today) and terms are both set; terms checkbox and modal "Agree and close" are each an affirmative act recorded by `POST /terms/accept` before purchase | Step 4 | B7, D8, D9 |
| U10 | Recognized + saved card → Pay → `purchase{SAVED_CARD}` charges the stored entry; card never re-entered; done page "You're in, {first}", pass block, receipt sidebar "Paid with Visa ••4242" | Step 5a | C6, D10 |
| U11 | Recognized + new card + save on → Pay Page capture → `purchase{NEW_CARD}` → new entry on the **existing** owner (`ownerIds=[ownerId]`, `createWalletOwner` never called); done page shows saved-card confirmation | Step 5b | C6, C9, D10 |
| U12 | New visitor + save on → `purchase{NEW_VISITOR}` → sell → prospect → member ID → owner by member ID → entry; second contact stored as lookup key; the new contact is thereafter recognized (fixture directory grows) | Step 5c | C6, C9, D10 |
| U13 | New visitor + save off → prospect exists, no owner or entry created; done page "You chose not to save a card." | Step 5c | C6, D10 |
| U14 | Reload mid-flow after verify → `GET /session` rehydrates recognized state; "Start again" → `DELETE /session`, identify page with the last contact prefilled | Reload gap | B6, D11 |

### Written down, not exercisable this sprint

| Journey | Lane | Trigger |
|---|---|---|
| W1 Real code delivery by email (email-publisher-service) and SMS (provider unknown) | eng, product | provider decision (OQ-R1) |
| W2 Real prospect creation from name + one contact (lean datatrak/MICO endpoint) | eng (MICO or datatrak owners) | OQ-R2 |
| W3 Real pass sale and charge (`onlineSale.spr` vs Payment Gateway charge + POS record) | eng, product | OQ-R3 |
| W4 Real wallet write behind universal-wallet G8 fix (sibling SPRINT-0001 A) at a pilot club | eng | sibling sprint ships; `prospect-wallet-enabled` club flag |
| W5 Pass in the Core app, QR scanned at the desk | product | pass-issuance service (OQ-R5) |
| W6 Member (not prospect) recognized and buying a pass | product | OQ-R4 policy |

## Architecture

### Route map and gating

```
UI  /signup/day-pass?club=NNNNN          (BrowserRouter basename="/signup", UI/index.tsx:18)
    App.tsx: isDayPassRoute && flag && onlineProspects → <ShortTermPassPage/> in its own <DtShell/>
             (existing <Header/>/<Footer/> not rendered for this path; guestMode logic untouched)
             flag off || !onlineProspects → existing "This page is not available" block (App.tsx:167-172)

BFF /api/short-term-pass                 (new KoaRouter, mounted in BFF/routes.ts publicRouter before staticRouter)
    every route: requireFlag(clubNumber) → 404 when LD `oj-stp-day-pass-checkout` is false for {kind:'club', key:padded}
    GET    /config?club=                → { offer, terms:{html,version}, club:{name,number}, captureMode }
    POST   /identify                    → CODE_SENT | NEW_VISITOR
    POST   /identify/resend             → CODE_SENT (new code, same challenge)
    POST   /identify/switch-channel     → CODE_SENT (new challenge on the other channel)
    POST   /verify                      → sets STP-SESSION; { person, savedCards }
    GET    /session                     → { person, savedCards } | 401
    DELETE /session                     → clears STP-SESSION
    POST   /terms/accept                → { acceptanceId, acceptedAt, termsVersion }
    POST   /purchase                    → { passId, day, receiptNumber, paidWith, cardSaved, cardSaveError?, delivery }
```

Flag delivery to the UI: add `oj-stp-day-pass-checkout` to the parallel evaluation in `BFF/routes/static/index.html.ts:69-79` and the `window.featureFlags` block at `:82-103` as `oj_stp_day_pass_checkout`; add the key to `FEATURE_FLAGS` in `UI/utils/featureFlags.ts`. A second flag `oj-stp-diagnostics` gates the dev-only panel. Local override: `STP_LOCAL_FLAG_OVERRIDE=true` is honoured only when `NODE_ENV !== 'production'`, so the local stack does not depend on LD targeting for the demo.

### Sequence (happy paths)

```
identify   UI ──POST /identify {clubNumber, contact}──▶ BFF: normalise (email lower-case; phone → 10 digits, strip leading 1)
                                                        rate-limit(ip, contactHash) → IdentityDirectoryPort.findByContact(club, channel, value)
             match     ◀── {outcome:CODE_SENT, challengeId, channel, masked, altChannelAvailable, resendAfterSec}
                          BFF: ChallengeStore.put({challengeId, memberId, channel, destination, codeHash, expiresAt, attempts:0})
                               MessageDeliveryPort.sendCode(channel, destination, code)          (mock: log + debug echo)
             no match  ◀── {outcome:NEW_VISITOR, channel, normalized, identifyToken}             (identifyToken = signed, 15 min, binds contact)
verify     UI ──POST /verify {challengeId, code}──▶ BFF: constant-time compare against hash; attempts++; lock at 5
                                                     ok → SessionCookie.set({sid, memberId, clubNumber, channel, contactMasked, exp:+30m})
                                                          WalletPort.readEntries(memberId) → savedCards (brand, last4, source, walletEntryId)
                                                          IdentityDirectoryPort.getPerson(memberId) → first, last, email, phone
           ◀── {person:{firstName,lastName,email|emailMasked,phone|phoneMasked}, savedCards[]}      (memberId never in the body)
terms      UI ──POST /terms/accept {termsVersion, via:'checkbox'|'modal'}──▶ BFF: bind to session or identifyToken → {acceptanceId}
capture    UI (NEW_CARD / NEW_VISITOR): POST /api/pay-page/session/due-today {clubNumber} (existing route, unchanged)
              PayPageEmbed.renderToNode(cardSlot, url); sidebar Pay → submit(); poll GET /api/pay-page/session/:id until TOKEN[0]
purchase   UI ──POST /purchase {mode, day, acceptanceId, saveCard?, payPageSessionId?, walletEntryId?, visitor?, identifyToken?}──▶ BFF
             1 validate body (ajv schema), day in [today-1, today+30] server date, acceptanceId valid and bound to this principal
             2 principal: SAVED_CARD/NEW_CARD → memberId from STP-SESSION; NEW_VISITOR → contact from identifyToken (no session yet)
             3 payment source: SAVED_CARD → entry ∈ WalletPort.readEntries(memberId) else 403
                               NEW_CARD/NEW_VISITOR → PayPageSessionReader.read(payPageSessionId) → {tokenId, brand, last4, exp, holder}
             4 PassSalePort.sell({club, memberId?, offer, day, payment}) → {receiptNumber, passId}
             5 NEW_VISITOR: ProspectPort.create({club, first, last, email?, phone?}) → memberId; then IdentityDirectoryPort.addContact(second)
             6 saveCard && tokenId: WalletPort.getOrCreateOwner({externalId:memberId, ownerType:'MEMBER', locationId, metadata})
                                    WalletPort.createCreditCard({pgToken:tokenId, ownerIds:[ownerId], brand, last4, exp, holder, locationId})
             7 MessageDeliveryPort.sendPass(channel, destination, pass) → delivered:boolean
             8 NEW_VISITOR: SessionCookie.set(memberId) so the visitor is bound like a recognized one
           ◀── {passId, day, receiptNumber, paidWith:{brand,last4}, cardSaved, cardSaveError?, delivery:{channel,masked,delivered}}
```

Failure handling in step order (PRD §4.4): 4 fails → 402/502 with `code:'PAYMENT_DECLINED'|'SALE_FAILED'`, nothing else runs. 5 fails → pass is issued, response `recordCreated:false, cardSaved:false, cardSaveError:'PROSPECT_FAILED'`, error logged with receipt number, no wallet call. 6 owner fails → `cardSaved:false, cardSaveError:'RETRYABLE'`, prospect kept. 6 entry fails → same, owner kept. 7 fails → `delivery.delivered:false`; done page drops "We emailed it to…" and keeps "Show this at the front desk, or just say your name". The UI never says "saved to your wallet" unless `cardSaved === true`.

### Session, challenge, and abuse controls

- **Challenge store** (`BFF/services/shortTermPass/challengeStore.ts`): `Map<challengeId, Challenge>` with a sweep timer; `challengeId = randomUUID()`; code = 6 digits from `crypto.randomInt`; stored as `HMAC-SHA256(STP_CODE_SECRET, challengeId + code)`; `expiresAt = now + 10 min`; `attempts ≤ 5` then `locked`; `resendAfter = 30 s`; per-contact sends `≤ 3 / 15 min`; per-IP identify calls `≤ 20 / 15 min` (`BFF/utils/middlewares/rateLimit.ts`, in-memory token bucket keyed by `ctx.ip`, `app.proxy` already set in production). The store is a `ChallengeStorePort` so Redis can replace it without touching routes; v1 is single-instance and says so in `docs/contracts/short-term-pass-bff.md`.
- **Mock code**: in `mock` mode the code is fixed to `STP_MOCK_OTP_CODE` (default `123456`) and echoed in the response's `debug` object only when `STP_ADAPTER_MODE=mock`; in `platform` mode `debug` is never present (test-pinned).
- **Session cookie** `STP-SESSION`: `jose` `SignJWT` HS256 with `STP_SESSION_SECRET` (≥ 32 bytes, required when the flag can be on), claims `{ sid, memberId, clubNumber, channel, contactMasked, iat, exp:+30 min }`, cookie options mirror `BFF/utils/cookies.ts:4-9` (`httpOnly`, `sameSite:'none'`, `partitioned`, `overwrite`, `secure` via `secureCookieMiddleware`). Stateless; `DELETE /session` clears it. `memberId` never leaves the BFF in a body; the UI sees `firstName` and masked contacts only.
- **Identify token** for new visitors: `jose` JWT, 15 minutes, claims `{ clubNumber, channel, contact }`, so `/purchase{NEW_VISITOR}` can prove which contact was typed without a code. It carries no identity because there is none yet.
- **Enumeration**: the flow requires revealing match / no-match. The BFF equalises response time for both outcomes (fixed minimum latency of 300 ms), rate-limits per IP and per contact, and never returns name or unmasked contact before `verify`. Cloudflare Turnstile is not added this sprint; the hook point (`ReviewPage.tsx:90-91, 659-680` pattern, club `turnstileSiteKey`) is recorded in OQ-R6.

### Ports and adapters (`BFF/services/shortTermPass/ports/`)

| Port | Methods | `mock` adapter (ships) | `platform` adapter | Real upstream (contract only) |
|---|---|---|---|---|
| `IdentityDirectoryPort` | `findByContact`, `getPerson`, `addContact` | in-memory directory seeded with Jordan Reyes (`m@m.com`, `5550192231`, memberId fixed UUID); `ProspectPort.create` appends | — | none exists (MICO has no lookup by phone/email); OQ-R2 |
| `ChallengeStorePort` | `put/get/consume/lock/sweep` | in-memory Map | — | Redis later |
| `MessageDeliveryPort` | `sendCode`, `sendPass` | logs + `debug` echo | — | email-publisher-service (MICO `application-local.yml:100-102`) + SMS provider TBD; OQ-R1 |
| `PassCatalogPort` | `getOffer(clubNumber)` | `STP_CATALOG_JSON` env, default the prototype's `Gym Floor $25.00` with perks | — | `/pos/saleItems.spr` needs a member; OQ-R3 |
| `PassSalePort` | `sell` | returns `receiptNumber`, `passId`; declines when last4 = `0002` for the failure demo | — | Payment Gateway charge + POS record, or `onlineSale.spr`; OQ-R3 |
| `ProspectPort` | `create` | mints UUID, appends to directory | — | lean add-prospect endpoint; OQ-R2 |
| `WalletPort` | `readEntries(memberId)`, `getOrCreateOwner`, `createCreditCard` | in-memory owner/entry maps seeded with Visa 4242 "Saved in the app last week" | `readEntries` via `universalWallet.getWalletEntries(externalId)` with `withTenancy(orgId)` (toolkit `clients/UniversalWallet.d.ts:22`, deprecated but typed); `getOrCreateOwner`/`createCreditCard` typed against `ICreateWalletOwner`/`ICreateWalletCreditCard` but **not enabled** until sibling SPRINT-0001 A ships | universal-wallet `/wallet-entry-owner`, `/wallet-entry/credit-card` |
| `PayPageSessionReader` | `read(sessionId, clubNumber)` | fixture Visa 4242 / Mastercard 5555 by session id prefix | `GET ${PAY_PAGE_API_URL}/…/session/:id` with the shared OAuth token (same call `payPage/index.ts:447-473` makes) | Order Service session |
| `LocationResolver` (service) | `byClubNumber` → `{locationId, organizationId}` | fixture UUIDs | re-implementation of `payPage/index.ts:74-125` with a 15-minute TTL cache in `BFF/services/platform/locationResolver.ts` | Pay Page API `/location?q=number==` |

Adapter selection: `BFF/services/shortTermPass/adapters/index.ts` reads `STP_ADAPTER_MODE` (`mock` default outside production; production refuses to boot with `mock` when the flag exists, test-pinned). `platform` requires `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `UNIVERSAL_WALLET_API_URL`; all four are added to `BFF/env.ts` `optionalEnv` and `.env.example`.

### Identity rules (non-negotiable, test-pinned in C9)

- Contact finds; code proves; session binds to `memberId`; wallet resolves by `(externalId = memberId, ownerType = MEMBER, locationId)`. The word `PROSP` and the keys `agreementNumber`, `dt_agreementNumber`, `dt_memberNumber`, `dt_memberOrdinal` appear nowhere in any payload the BFF sends; a recursive payload scan in tests fails the suite if they do.
- Owner metadata on create: `{ dt_clubNumber, dt_memberId, dt_memberType: 'PROSPECT' }` only (sibling SPRINT-0001 contract; hazard #10 means universal-wallet must carry the G8 fix before `platform` wallet writes are enabled).
- Recognized + new card → `createCreditCard({ ownerIds: [existingOwnerId] })`; `createWalletOwner` is never called for an existing owner.
- New visitor → `sell` before `create` before `getOrCreateOwner` before `createCreditCard`; `InOrder`-style assertions on the mock adapters.
- Client-supplied `memberId`, `ownerId`, `agreementNumber`, `terms:true`, or `saveCard` on `SAVED_CARD` are ignored (schema `additionalProperties:false`; tests post hostile bodies as `payPage/__tests__/index.test.ts:534-566` does).

### Payment path (PCI)

Card entry is the existing Pay Page iframe. `NEW_CARD` and `NEW_VISITOR` call the unchanged `POST /api/pay-page/session/due-today` (server fixes `paymentMethods:['CARD']`, `deferAuthorizationToPayment:true`, `payPage/index.ts:363-371`), render it with `PayPageEmbed` (`UI/routes/PaymentPage/components/PayPageEmbed.tsx`, `renderToNode` + imperative `submit()`), and poll `GET /api/pay-page/session/:id` with `usePayPageSession` until `TOKEN[0]` exists. The UI then posts only `payPageSessionId`; the BFF re-reads the session for `tokenId`, `creditCardBrand`, `lastFour`, expiry, holder. No PAN, CVC, or expiry field exists in React; the prototype's `cardForm()` inputs are replaced by the iframe slot. `MockCardCapture` (mock mode only) is a single "Use test card Visa •••• 4242" button that yields a fixture `payPageSessionId`, so the demo does not depend on Pay Page dev availability. The saved-card charge sends `walletEntryId` only; the BFF resolves the entry and its token.

### Design-system packaging (`dt-*` / `--ig-*`)

`UI/styles/dt/_tokens.scss` declares the prototype's `--ig-*` variables on `.stp-root` (not `:root`) so the existing flow sees none of them; `UI/styles/dt/_components.scss` nests every `.dt-*` and page-local class (`.offer`, `.otp`, `.paysel`, `.pass`, `.srow`, `.total`, `.skeleton`, `.fine`, `.toast`, `.fade`) under `.stp-root`; `UI/styles/dt/index.scss` imports both and is imported once by `DtShell`. Eight primitives in `UI/components/dt/`: `DtButton`, `DtField` (label + input + help/error), `DtCheckbox`, `DtAlert`, `DtLink`, `DtModal` (focus trap, Escape, backdrop click, "Agree and close" slot), `DtWidget` (+ header), `DtShell` (header with brand, location switcher stub, "Secure checkout", tabs). They render plain elements with class names, no MUI. Inter is loaded from Google Fonts only if the CSP `fontSrc`/`styleSrc` already allow it (A4 verifies against `BFF/utils/setSecurityHeaders.ts`); otherwise `--ig-font` falls back to `system-ui`. Reduced-motion media query kept.

### State (UI)

`UI/reducers/shortTermPass/shortTermPassSlice.ts`: `{ step, contact:{raw, channel, normalized}, challenge:{id, masked, altChannelAvailable, resendAfter, locked}, person, savedCards, paymentChoice:{useSaved, walletEntryId, saveCard}, capture:{payPageSessionId, sessionUrl, status}, day, terms:{accepted, acceptanceId, version}, offer, result, error, diagnostics:[] }`. Thunks mirror the routes (`identify`, `resend`, `switchChannel`, `verify`, `loadSession`, `logout`, `acceptTerms`, `purchase`, `loadConfig`). Each thunk appends a diagnostics entry with the prototype's log wording (kind `ok|warn|''`). Selectors in `UI/selectors/shortTermPass.ts` (`canPaySelector = day && terms.accepted && (useSaved || capture.status === 'TOKENIZED')`).

## Implementation Plan

Sequencing: A first (1.5 days, both engineers); then B ∥ D, C ∥ D; E after C6/D10; F last. Two lanes (BFF, UI). Estimates assume one engineer per lane.

### A — Foundations · ~1.5 days · both repos

| # | Task | Files |
|---|---|---|
| A1 | LD flags: evaluate `oj-stp-day-pass-checkout` and `oj-stp-diagnostics` in the parallel block; add `oj_stp_day_pass_checkout`, `oj_stp_diagnostics` to the `window.featureFlags` script; test that both default false and serialize as raw booleans | `BFF/routes/static/index.html.ts` (+ `__tests__/index.test.ts`) |
| A2 | `requireFlag` middleware: builds `{kind:'club', key: padded}` from `clubNumber` (query or body), `getFeatureVariation(key, false, ctx)`; 404 `{error:'NOT_FOUND'}` when false; honours `STP_LOCAL_FLAG_OVERRIDE` only outside production | `BFF/utils/middlewares/requireFlag.ts` (+ test) |
| A3 | Env: `optionalEnv` += `STP_ADAPTER_MODE`, `STP_SESSION_SECRET`, `STP_CODE_SECRET`, `STP_MOCK_OTP_CODE`, `STP_CATALOG_JSON`, `STP_LOCAL_FLAG_OVERRIDE`, `UNIVERSAL_WALLET_API_URL`; also document the already-read `PAY_PAGE_*`, `ABC_CORE_API_URL` gap; `.env.example` entries with comments; startup check: flag-capable + production ⇒ secrets present and mode ≠ mock | `BFF/env.ts`, `.env.example`, `BFF/server.ts` (one guard call) |
| A4 | `jose` test mock (`src/__mocks__/jose.ts` real-implementation passthrough or remove the `moduleNameMapper` line); verify CSP allows `fonts.googleapis.com`/`fonts.gstatic.com`, else drop the Inter link | `BFF/__mocks__/jose.ts`, `jest.config.js`; `BFF/utils/setSecurityHeaders.ts` (read only) |
| A5 | UI route: `PAGES.dayPass = '/day-pass'`; `FEATURE_FLAGS.OJ_STP_DAY_PASS_CHECKOUT`, `OJ_STP_DIAGNOSTICS`; `App.tsx` branch renders `<ShortTermPassPage/>` inside `SessionProvider`/`ThemeProvider` without `Header`/`Footer`; flag off or `!onlineProspects` → existing unavailable block; test both | `UI/common/constants.ts`, `UI/utils/featureFlags.ts`, `UI/App.tsx`, `UI-T/App.test.tsx` |
| A6 | `dt` tokens and components scss scoped under `.stp-root`; `DtShell` imports it; snapshot test that the existing `Header` markup has no `.dt-*`/`--ig-*` | `UI/styles/dt/{_tokens,_components,index}.scss`, `UI/components/dt/DtShell.tsx`, `UI-T/components/dt/DtShell.test.tsx` |
| A7 | Eight `dt` primitives with props typed and tests (render, disabled, error, focus trap for modal) | `UI/components/dt/{DtButton,DtField,DtCheckbox,DtAlert,DtLink,DtModal,DtWidget}.tsx`, `UI/components/dt/index.ts`, `UI-T/components/dt/*.test.tsx` |
| A8 | Contract doc skeleton listing every route, port, and env var (filled by B/C) | `docs/contracts/short-term-pass-bff.md` (this repo) |

### B — BFF identity, code, session · ~3 days · BFF lane

| # | Task | Files |
|---|---|---|
| B1 | Router skeleton `/api/short-term-pass`, mounted before `staticRouter`; per-route try/catch → `{error, code}` with 400/401/403/404/409/429/502/500 mapping; ajv schemas per body with `additionalProperties:false`; response helper that strips `debug` unless mock | `BFF/routes/shortTermPass/index.ts`, `BFF/routes/shortTermPass/schemas.ts`, `BFF/routes.ts` |
| B2 | Contact normalisation and masking (`isEmail`, `isPhone` 10 or 11-with-1, `normPhone`, `maskEmail` first char + 3–5 dots, `maskPhone` `(555) •••-2231`) as the prototype defines | `BFF/services/shortTermPass/contact.ts` (+ test table) |
| B3 | Ports and mock adapters: `IdentityDirectoryPort`, `ChallengeStorePort`, `MessageDeliveryPort` with fixture seed and `debug` echo | `BFF/services/shortTermPass/ports/{identityDirectory,challengeStore,messageDelivery}.ts`, `BFF/services/shortTermPass/adapters/mock/*.ts`, `BFF/services/shortTermPass/fixtures/directory.ts` |
| B4 | `POST /identify`, `/identify/resend`, `/identify/switch-channel`: rate limit, lookup, challenge, code send, fixed-minimum-latency, outcomes and error codes (`INVALID_CONTACT`, `RATE_LIMITED`, `CHALLENGE_LOCKED`, `ALT_CHANNEL_UNAVAILABLE`) | `BFF/routes/shortTermPass/identify.ts`, `BFF/utils/middlewares/rateLimit.ts` |
| B5 | `POST /verify`: HMAC compare (`crypto.timingSafeEqual`), attempt cap, expiry, consume challenge, set `STP-SESSION`, read person and saved cards, masked-vs-full contact by typed channel | `BFF/routes/shortTermPass/verify.ts`, `BFF/services/shortTermPass/sessionCookie.ts` |
| B6 | `GET /session` (401 when absent/expired/invalid signature), `DELETE /session` | `BFF/routes/shortTermPass/session.ts` |
| B7 | `POST /terms/accept`: bound to session `sid` or identify-token; `acceptanceId` stored in the challenge store with 30-minute TTL; `termsVersion` must equal `/config`'s | `BFF/routes/shortTermPass/terms.ts` |
| B8 | Redacted logging helper: logs `challengeId`, `sid`, channel, outcome; never code, contact, name, token, or memberId | `BFF/services/shortTermPass/log.ts` |
| B9 | Tests: contact table; challenge lifecycle (expiry, 5 attempts → locked, resend cooldown, per-contact and per-IP caps); verify wrong/expired/locked/replayed; cookie attributes; `debug` absent in platform mode; timing floor | `BFF/routes/shortTermPass/__tests__/{identify,verify,session,terms}.test.ts`, `BFF/services/shortTermPass/__tests__/*.test.ts` |
| B10 | Disclosure pin: `identify` CODE_SENT body has exactly the allowed keys; no name, no unmasked contact, no memberId in any response of B4–B7 | in B9 |

### C — BFF purchase orchestration · ~3 days · BFF lane

| # | Task | Files |
|---|---|---|
| C1 | `LocationResolver` (TTL cache) and `OAuthTokenService` (client-credentials, same token endpoint as payPage, expiry minus 60 s) as shared services; payPage untouched | `BFF/services/platform/{locationResolver,oauthToken}.ts` (+ tests with `global.fetch` mocks) |
| C2 | Ports: `PassCatalogPort`, `PassSalePort`, `ProspectPort`, `WalletPort`, `PayPageSessionReader`; mock adapters incl. decline fixture (last4 `0002`) and wallet owner/entry maps | `BFF/services/shortTermPass/ports/{passCatalog,passSale,prospect,wallet,payPageSession}.ts`, `adapters/mock/*.ts` |
| C3 | Platform adapters (typed, dark): `PayPageSessionReader.platform` (GET session with bearer), `WalletPort.platform.readEntries` (`universalWallet.withTenancy(orgId).getWalletEntries(memberId)` mapped to `{walletEntryId, brand, last4, source:'Saved at the club'}`); `getOrCreateOwner`/`createCreditCard` implemented against `ICreateWalletOwner`/`ICreateWalletCreditCard` but throw `NOT_ENABLED` unless `STP_WALLET_WRITES=true` | `adapters/platform/{payPageSession,wallet}.ts`, `BFF/services/platform/toolkit.ts` (initialise `universalWallet` once) |
| C4 | `GET /config`: offer from catalog port, terms html from club `prospectTerms` when non-empty else default template (prototype text) with `termsVersion` = sha256 of html, club name from MICO `getClub` (existing pattern `payPage/index.ts:193-220`), `captureMode: 'paypage'|'mock'` | `BFF/routes/shortTermPass/config.ts`, `BFF/services/shortTermPass/terms.ts` |
| C5 | `PurchaseOrchestrator` implementing the eight steps and the §4.4 failure matrix; typed result union | `BFF/services/shortTermPass/purchaseOrchestrator.ts` |
| C6 | `POST /purchase` route: schema per mode, principal resolution, 402/403/409 codes, idempotency key (`Idempotency-Key` header or `acceptanceId`) so a double click never sells twice | `BFF/routes/shortTermPass/purchase.ts` |
| C7 | Adapter selection module and boot guard | `BFF/services/shortTermPass/adapters/index.ts` |
| C8 | Contract doc: every port's request/response, the upstream each stands in for, and the decision needed (OQ-R1…R5) | `docs/contracts/short-term-pass-bff.md` |
| C9 | **Identity and order-of-operations security tests**: recursive payload scan for `PROSP`/agreement keys; owner externalId = memberId and type MEMBER; recognized+new card → `ownerIds=[existing]` and `createWalletOwner` never; new visitor call order; save off → no wallet calls; hostile bodies (client `memberId`, `ownerId`, `saveCard` on SAVED_CARD, `terms:true`) ignored; saved-card entry must belong to the session's member (403 otherwise); §4.4 matrix (sale fail → nothing else; prospect fail → no wallet; owner fail → prospect kept; entry fail → owner kept; delivery fail → `delivered:false`); idempotent replay | `BFF/routes/shortTermPass/__tests__/purchase.test.ts`, `BFF/services/shortTermPass/__tests__/purchaseOrchestrator.test.ts` |

### D — UI flow · ~4 days · UI lane

| # | Task | Files |
|---|---|---|
| D1 | Service module (`axios.create({ baseURL: '/api/short-term-pass', withCredentials: true })`), typed request/response interfaces matching `docs/contracts/short-term-pass-bff.md` | `UI/services/shortTermPass.ts`, `UI/interfaces/api/shortTermPass.ts` |
| D2 | Slice, thunks, selectors, diagnostics reducer; register in `configureStore.ts` | `UI/reducers/shortTermPass/shortTermPassSlice.ts`, `UI/selectors/shortTermPass.ts`, `UI/configureStore.ts` |
| D3 | `IdentifyStep`: offer card (radio, "Selected" pill, icon, price without `.00`, perks), contact field (`inputmode="email"`, `autocomplete="username"`), Continue on click/Enter, inline error | `UI/routes/ShortTermPassPage/steps/IdentifyStep.tsx`, `OfferCard.tsx` |
| D4 | `CodeEntry` inline: six single-digit inputs (auto-advance, backspace, paste), "Sent by email/text", Resend with cooldown countdown, switch-channel link only when `altChannelAvailable`, Change, Verify disabled until 6 digits, locked/expired states | `UI/routes/ShortTermPassPage/steps/CodeEntry.tsx` |
| D5 | `RecognizedStep`: success alert, Your info (name, email, mobile with masking per typed channel), Payment (saved chip with source, "Use a different card" ↔ "Use {brand} •••• {last4} instead"), card slot with save checkbox | `steps/RecognizedStep.tsx`, `components/SavedCardChip.tsx` |
| D6 | `NewVisitorStep`: header with contact + Edit, first/last, optional second contact with channel-specific label/placeholder/help, card slot with save checkbox, form error alert with the prototype's three messages | `steps/NewVisitorStep.tsx` |
| D7 | `CardCaptureSlot`: `PayPageEmbed` in the slot when `captureMode==='paypage'` (creates due-today session on mount, exposes `submit`, polls to `TOKENIZED`), `MockCardCapture` otherwise | `components/CardCaptureSlot.tsx`, `components/MockCardCapture.tsx` |
| D8 | `OrderSummary` sidebar: skeleton on identify; date input (`min` today, "Today · Wed, Sep 9" label), line item, Valid/Paying with/Paid with rows, total, terms row, Pay button `Pay $25.00 and get my pass`, fine print (two variants), Receipt mode on done | `components/OrderSummary.tsx` |
| D9 | `TermsModal` on `DtModal` with Close and "Agree and close"; both the checkbox and the modal button dispatch `acceptTerms`; opening the modal is not gated | `components/TermsModal.tsx` |
| D10 | Pay action per step: validates day/terms/capture (toast copy from the prototype), submits Pay Page when needed, dispatches `purchase`; `DoneStep`: pass block with QR (`qrcode.react`, encodes `passId`), "1-day pass · {day}", delivery sentence conditioned on `delivered`, saved-card alert only when `cardSaved`, "Get the Core app" toast, "Start again" | `steps/DoneStep.tsx`, `components/PassBlock.tsx`, `ShortTermPassPage.tsx` |
| D11 | Rehydrate on mount (`loadSession` → recognized), `Start again` → `logout` then identify with `contact.raw` kept; toast component | `ShortTermPassPage.tsx`, `components/Toast.tsx` |
| D12 | Tests: each step and component with the repo's `useSelector`/`useDispatch` mocking convention; slice reducer/thunk tests; `canPaySelector` table; masking helpers; QR renders `passId`; copy assertions for every prototype string | `UI-T/routes/ShortTermPassPage/**`, `UI-T/reducers/shortTermPass/*.test.ts`, `UI-T/selectors/shortTermPass.test.ts` |

### E — Proof, demo, docs · ~1.5 days · both lanes

| # | Task | Files |
|---|---|---|
| E1 | Demo script: boot BFF (`STP_ADAPTER_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `OJ_UI_URL`), boot UI, four runs (saved card; new card save on; new visitor save on; new visitor save off), a decline run (last4 `0002`), the reload run; expected diagnostics lines per run | `docs/demos/short-term-pass-local-demo.md` |
| E2 | Coverage and lint to threshold in both repos; record numbers in the sprint ledger | — |
| E3 | Contract doc finalised; `docs/SEMANTIC-INDEX.md` note that `online-join-*` remain unindexed and where the new code lives | `docs/contracts/short-term-pass-bff.md`, `docs/SEMANTIC-INDEX.md` |
| E4 | Threat notes: enumeration, code brute force, session theft, replay, CSRF (state-changing routes require `Origin` ∈ allowlist `STP_ALLOWED_ORIGINS` when set), logging redaction; each with the test that pins it | appendix of the contract doc |

### F — Diagnostics panel · ~0.5 day · optional, UI lane

| # | Task | Files |
|---|---|---|
| F1 | `DiagnosticsPanel` under the sidebar rendering `diagnostics[]` with the prototype's styling, visible only when `oj_stp_diagnostics` is true and `process.env.NODE_ENV !== 'production'`; toggle button in `DtShell` | `UI/routes/ShortTermPassPage/components/DiagnosticsPanel.tsx` (+ test) |

## Files Summary

| Repo | File | Action |
|---|---|---|
| online-join-bff | `src/routes.ts` | MODIFY: mount `shortTermPassRouter` |
| online-join-bff | `src/routes/shortTermPass/{index,schemas,identify,verify,session,terms,config,purchase}.ts` | NEW |
| online-join-bff | `src/routes/shortTermPass/__tests__/*.test.ts` | NEW |
| online-join-bff | `src/services/shortTermPass/{contact,sessionCookie,log,terms,purchaseOrchestrator}.ts`; `ports/*.ts`; `adapters/{index,mock/*,platform/*}.ts`; `fixtures/directory.ts`; `__tests__/*` | NEW |
| online-join-bff | `src/services/platform/{locationResolver,oauthToken,toolkit}.ts` (+ tests) | NEW |
| online-join-bff | `src/utils/middlewares/{requireFlag,rateLimit}.ts` (+ tests) | NEW |
| online-join-bff | `src/routes/static/index.html.ts` (+ test) | MODIFY: two flags |
| online-join-bff | `src/env.ts`, `.env.example`, `src/server.ts` | MODIFY: env, boot guard |
| online-join-bff | `src/__mocks__/jose.ts` or `jest.config.js` | NEW / MODIFY |
| online-join-ui | `src/App.tsx`, `src/common/constants.ts`, `src/utils/featureFlags.ts`, `src/configureStore.ts` | MODIFY |
| online-join-ui | `src/styles/dt/{_tokens,_components,index}.scss` | NEW |
| online-join-ui | `src/components/dt/*.tsx`, `index.ts` | NEW |
| online-join-ui | `src/routes/ShortTermPassPage/ShortTermPassPage.tsx`, `steps/*.tsx`, `components/*.tsx` | NEW |
| online-join-ui | `src/reducers/shortTermPass/shortTermPassSlice.ts`, `src/selectors/shortTermPass.ts`, `src/services/shortTermPass.ts`, `src/interfaces/api/shortTermPass.ts` | NEW |
| online-join-ui | `package.json` | MODIFY: `qrcode.react` |
| online-join-ui | `__tests__/routes/ShortTermPassPage/**`, `__tests__/components/dt/**`, `__tests__/reducers/shortTermPass/**`, `__tests__/selectors/shortTermPass.test.ts`, `__tests__/App.test.tsx` | NEW / MODIFY |
| this repo | `docs/contracts/short-term-pass-bff.md`, `docs/demos/short-term-pass-local-demo.md` | NEW |
| this repo | `docs/SEMANTIC-INDEX.md` | MODIFY: note |
| **Handoffs (not in cache)** | LD flags `oj-stp-day-pass-checkout`, `oj-stp-diagnostics` (kind `club`, default off); env values per environment; upstream decisions OQ-R1…R6 | written as contracts; owner named |

Not modified: `mico/**`; `BFF/routes/payPage/**`; `BFF/utils/proxyFactory.ts`; `BFF/utils/cookies.ts`; existing UI routes, `Header`, `Footer`, `reducers/index.ts`; any wallet service.

## Definition of Done

Role slots: UI (online-join-ui engineer), BFF (online-join-bff engineer), SEC (security reviewer), PRODUCT, DESIGN. Owners TBD by 2026-09-11; a gate with no name does not sign off.

### Live gates

| Gate | Lane · owner | Passes when |
|---|---|---|
| E0 — Ready | (eng) UI+BFF | Source SHAs recorded (`online-join-ui`, `online-join-bff` HEAD); LD flag keys created or requested with owner; `STP_*` env present in `.env.example`; owners named |
| E1 — Dark | (eng) BFF+UI | U1: flag off → 404 on all seven routes (test iterates the router stack, as `payPage/__tests__/index.test.ts:590-607` does) and the UI route renders the unavailable block; flags default false in `index.html.ts`; `STP_LOCAL_FLAG_OVERRIDE` ignored when `NODE_ENV=production` |
| E2 — Identity rules | (eng, security) BFF+SEC | C9 green: payload scan, owner by memberId, existing owner reuse, call order, hostile bodies, entry ownership check, §4.4 matrix, idempotent replay |
| E3 — Disclosure and abuse | (eng, security) BFF+SEC | B9/B10 green: response key allowlist before verify; 5-attempt lock; 10-min expiry; resend cooldown; per-contact and per-IP caps; constant-time compare; `debug` absent in platform mode; redaction test that no log line contains code, contact, name, token, or memberId |
| E4 — Session | (eng) BFF | Cookie attributes (`httpOnly`, `sameSite:'none'`, `partitioned`, 30-min `exp`); tampered or expired token → 401; `DELETE` clears; `memberId` appears in no response body (grep-style test over every route's responses) |
| E5 — PCI path | (eng, security) UI+SEC | No input with `autocomplete="cc-*"` or card-number pattern exists in `UI/routes/ShortTermPassPage/**` (static test); `/purchase` schema rejects `pan`, `cvc`, `expiry`, `tokenId` (client-posted token ignored); capture goes through `PayPageEmbed` or `MockCardCapture` only |
| E6 — Prototype parity | (design, product) DESIGN+PRODUCT | Side-by-side with `docs/prd/day-pass.html`: all four steps, both sidebar modes, the terms modal, all copy strings (D12 asserts each), masking rules, disabled states; sign-off recorded |
| E7 — Three paths | (eng, product) UI+BFF+PRODUCT | E1 demo script run end to end on the local stack: U10, U11, U12, U13 plus decline and reload; diagnostics lines match the script |
| E8 — Suites | (eng) UI+BFF | UI ≥ 80 lines/statements; BFF ≥ 84 lines/statements and ≥ 67 branches/functions; lint clean; existing payPage tests untouched and green |
| E9 — Contracts | (eng, product) BFF+PRODUCT | `docs/contracts/short-term-pass-bff.md` names for each port the request/response, the upstream it stands in for, and the open decision; OQ-R1…R6 each have an owner and date |
| E10 — Design system isolation | (eng, design) UI+DESIGN | A6 snapshot: existing `Header`/`Footer`/`GuestPage` markup and computed styles unchanged (no `.dt-*`, no `--ig-*` on `:root`); Inter loads or falls back per A4 |

### Deferred gates (registered now, not this sprint's success)

| Gate | Lane · owner | Trigger |
|---|---|---|
| F1 — Real code delivery (email + SMS) with deliverability and cost review | (eng, product) | OQ-R1 decided |
| F2 — Real prospect creation, real sale, real wallet write at one pilot club with `prospect-wallet-enabled`; universal-wallet G8 fix deployed | (eng, product) | sibling SPRINT-0001 A shipped; OQ-R2/R3 decided |
| F3 — Stored card actually charged at the desk and in the app after a web save (PRD H6) | (product) | F2 |
| F4 — Enumeration and bot defence in production (Turnstile on identify; Redis-backed limits) | (security) | before flag-on for any club |
| F5 — Member-vs-prospect policy (OQ-R4), multi-match policy, club time zone for "today" | (product) | before flag-on |
| F6 — Accessibility audit (OTP inputs, modal focus trap, live regions) | (design) | before flag-on |

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | Upstream contracts (lookup, code delivery, prospect, sale) do not exist; the sprint could become a mock-only demo with no path to production | Ports with typed contracts and a `platform` adapter for the two calls that are typed today; contract doc with named decision per port (E9); F2 registered |
| R2 | Real wallet writes for an agreement-less owner trip hazard #10 (`deduplication-job.member` error) | `STP_WALLET_WRITES` default false; dependency on sibling SPRINT-0001 A; owner metadata carries `dt_memberType=PROSPECT` and never an agreement number |
| R3 | Enumeration via match / no-match outcome | Rate limits per IP and contact, timing floor, masked-only disclosure, F4 for Turnstile |
| R4 | In-memory challenge and rate-limit stores break with more than one BFF instance | Ports; single-instance stated in the contract; production boot guard requires `platform` mode and documents the Redis follow-up |
| R5 | `jose` import breaks jest through the dangling `moduleNameMapper` | A4 first day |
| R6 | Pay Page dev environment unavailable during the demo | `MockCardCapture` and `PayPageSessionReader.mock`; demo script runs fully in mock mode |
| R7 | Double submit sells twice | Idempotency key on `/purchase` bound to `acceptanceId`; UI disables Pay while pending |
| R8 | Charge succeeds, prospect creation fails → paid pass with no record | Response flags `recordCreated:false`; receipt number logged; done page keeps "say your name at the desk"; OQ-R7 asks whether prospect-first is acceptable when the real adapters exist |
| R9 | `dt` styles leak into the existing signup flow | All selectors nested under `.stp-root`; A6 snapshot gate E10 |
| R10 | Adding routes to `App.tsx` with no `<Switch>` causes double rendering | The day-pass branch returns early before the existing `<Route>` list |
| R11 | Redux state lost on reload mid-flow | `GET /session` rehydrate (D11); new visitors before purchase restart, which the prototype also does |
| R12 | Pay Page session polling copied from `PaymentPageWithPayPage` drifts | Reuse `usePayPageSession` as is; only the target node and submit trigger differ |
| R13 | Terms text source unclear (club `prospectTerms` vs prototype template) | C4 rule: club text when non-empty, else template; `termsVersion` hash pins what was accepted; OQ-R8 |
| R14 | Club-scoped LD evaluation needs the club key before the session exists | `requireFlag` builds the context from the validated `clubNumber` (padded as `getFeatureFlagContext.ts:12-13` does) |
| R15 | Coverage floors with many new files | Tests written per task, not at the end; E8 tracked daily |
| R16 | `getWalletEntries(externalId)` is deprecated in the toolkit | Typed but isolated behind `WalletPort`; replacement (`getAllWalletEntries` with RSQL by owner) noted in the contract |
| R17 | Unredacted logging habit in the BFF leaks PII from the new routes | Dedicated `log.ts` helper; redaction test in E3; no `loggerService.info(body)` in the new routes (lint rule or review checklist) |

## Dependencies

- **Code/infra:** token cache clones current (`git pull --ff-only`); Node ≥ 22 for the BFF; local BFF `.env` with `OJ_UI_URL`, `LAUNCHDARKLY_SDKKEY` (still required at boot), `STP_ADAPTER_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_SESSION_SECRET`, `STP_CODE_SECRET`; the uncommitted `server.ts` S3-manifest skip (or its committed equivalent) so the BFF boots without CDN access; `qrcode.react` added to the UI.
- **Access:** LaunchDarkly project write access to create the two flags (or a named owner to do it); Pay Page dev credentials already used by the payPage route for the `platform` session reader; universal-wallet dev URL and client authorities for `readEntries` (optional this sprint).
- **Sibling sprint:** `prospects1` SPRINT-0001 workstream A (dedup fallback) must ship before `STP_WALLET_WRITES` is ever true; workstream D's decision register should record this sprint's OQ-R1…R8 alongside R-03 (web day-pass in v1).
- **People/decisions:** UI, BFF, SEC, PRODUCT, DESIGN owners by 2026-09-11; OQ-R1…R8 owners.
- **Index leaves consulted:** `themes/identity-by-member-id.md`, `themes/agreement-number-and-prosp.md` (hazards #1, #4, #5, #10, #11), `repos/universal-wallet/identity/owner.md` (owner create needs only externalId, type, locationId; `ABCFS-TENANT-ID` = organization UUID), `repos/universal-wallet/walletentry/credit-card.md` (`pgToken @NotNull`, `ownerIds`, `providedId` for idempotent creates), `repos/commerce-universal-wallet-sdk/sdk.md`.

## Open Questions

**Answered by this draft (recorded for the merge):**
1. *Route and entry point (intent Q3).* `/signup/day-pass?club=NNNNN` under the existing basename; own `DtShell` header and static tabs; no new basename.
2. *Design system (Q4).* Scoped scss under `.stp-root` plus eight plain React primitives in `UI/components/dt/`; no MUI theme overrides; no shared package yet.
3. *Session model (Q5).* Stateless `jose`-signed `STP-SESSION` cookie, 30 minutes, `memberId` inside the token only; `SESSION-ID` helpers left unused; "stay logged in and buy again" is bounded by that lifetime and `Start again` clears it.
4. *Date selection (Q9).* Keep the picker, blank by default with `min` today, exactly as the prototype; server accepts `[today-1, today+30]` pending a club time-zone source (OQ-R9).
5. *Demo diagnostics (Q10).* Ship behind `oj-stp-diagnostics` and non-production build; entries come from the UI thunks with the prototype's wording; `debug` from the BFF only in mock mode.
6. *Where the pass product comes from (Q2), v1.* `PassCatalogPort` with an env-configured offer; the prototype's fixture is the default.
7. *PCI.* Pay Page `due-today` session via the unchanged route; BFF re-reads the session for the token; the UI never posts a token.
8. *Multiple matches (Q7), v1 rule.* The mock directory forbids duplicates; the port returns `candidates[]` and the route treats `length > 1` as no match plus a counter, so a duplicate never receives a code. Product policy requested (OQ-R4).

**Requested (owner + date to be set at the interview):**
- **OQ-R1** Code delivery providers: email-publisher-service contract for a 6-digit code template; which SMS provider (none in the token cache); consent language for a texted code.
- **OQ-R2** Lean prospect creation: a MICO or datatrak endpoint taking club, first, last, one contact, optional second contact, no address or signature; also a lookup by phone/email at a club returning member IDs only.
- **OQ-R3** Sale and charge: Payment Gateway charge via toolkit (`realtimeChargeSale`) plus a POS record, or datatrak `onlineSale.spr` with a token; who owns the pass entitlement the desk sees.
- **OQ-R4** Policy when the contact matches a member rather than a prospect (proceed as member with their wallet, or redirect), and for multiple matches (household sharing).
- **OQ-R5** Pass issuance and delivery: what generates the desk-scannable QR and the email/text; v1 encodes `passId` and shows a receipt.
- **OQ-R6** Bot and enumeration defence before flag-on: Turnstile on identify (club `turnstileSiteKey` already exists), Redis-backed limits.
- **OQ-R7** Order of operations when real adapters exist: the intent fixes sell → prospect → wallet; a declined card then creates no prospect, but a prospect failure leaves a paid sale without a record. Confirm or invert.
- **OQ-R8** Terms source and versioning: club `prospectTerms` vs a short-term-pass template; legal review of the prototype's placeholder text.
- **OQ-R9** Club time zone for "today" in the date rule; whether `getClub` exposes it.
- **OQ-R10** Flag gating: LD club flag only, or LD flag AND `onlineProspects` (this draft uses both for the UI route and LD only for the BFF routes).

**Carried to Sprint 002 regardless:** Redis-backed challenge and rate-limit stores; converge `payPage` OAuth/location helpers onto `BFF/services/platform/*`; replace deprecated `getWalletEntries`; multi-day pass product (`durationDays`, "applies from"); Class / Membership / Visit tabs; accessibility audit (F6).
