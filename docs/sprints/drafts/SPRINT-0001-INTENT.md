# Sprint 0001 Intent: Day Pass single-flow checkout in Online Join (UI + BFF)

## Seed

Build the **Day Pass single-flow checkout** specified by the interactive prototype `docs/prd/day-pass.html` into the split-out Online Join stack: `repos/online-join-ui` (React) and `repos/online-join-bff` (Koa). The legacy `repos/mico` monolith is **reference only** this sprint and must not change.

The prototype is the requirements source. Its behaviour, in order:

1. **Identify** — one page: a pre-selected pass offer card (name, price, perks) beside a single "Mobile number or email" field and Continue. Sidebar shows a skeleton Order Summary until an order exists.
2. **Lookup** by the typed channel (email or phone) at the home club.
   - **Match** → a 6-digit one-time code is sent via that channel; the code entry appears **inline on the same page** (no redirect, nothing about the person disclosed yet). Visitor can Change contact (unbinds), Resend, or switch channel if the other contact is on file. Verify binds the browser session to the **member ID**; the wallet owner is resolved **by member ID (owner type MEMBER)** and the stored card is shown.
   - **No match** → "Welcome — a few details": first/last name, an optional second contact (the other channel, "so we can find your saved card if you use a different email/number next time"), card entry, "Save this card for next time" (default on).
3. **Recognized** — "Welcome back, {first}": masked contact details, saved card chip (brand, last4, source), "Use a different card" toggles a card form with the save checkbox.
4. **Sidebar** (both paths) — "Day pass applies on" date picker (min today), line item, total, Terms & conditions checkbox (separate affirmative act) with a modal that has "Agree and close", and a Pay button enabled only when day + terms are set. Fine print: "No membership. No recurring billing. Your card stays on file at the club — not on this website."
5. **Pay** — recognized + saved card: authorize on stored card, card never re-entered. Recognized + new card: authorize, and if save is on, add a new wallet entry to the **existing** owner (no second wallet). New visitor: authorize, persist the **prospect record → member ID** ("agreement number: none — not PROSP as identity"), **then** create the wallet owner by member ID and save the card if consented; store the second contact as an additional lookup key. Card not saved → prospect exists, no wallet entry.
6. **Done** — "You're in, {first}": QR/pass block ("1-day pass · {day}", show at desk or say your name, emailed/texted to masked contact), saved-card confirmation ("Next time — here, in the app, or at the desk — you'll just verify your {channel} and pay"), receipt sidebar, "Get the Core app" and "Start again".

The prototype also has a "Behind the scenes" event log and demo controls. Those are **demo affordances**, not product requirements, though a dev-only diagnostics panel behind a flag is acceptable if cheap.

## Context

Orientation summary (2026-09-09):

- **Project state.** `prospects-ui` is a planning repo (docs + skills). The code lives in three gitignored clones under `repos/`: `mico` (Spring Boot 3.2, Java 17, `/iclub` on :8080), `online-join-ui` (React 17, TypeScript, Redux Toolkit, MUI v4, webpack 5, `npm start` on :3001), `online-join-bff` (Koa, TypeScript, Node ≥22, `npm start` on :3000). All three run locally today; the BFF serves the UI from :3001 and proxies `/api/online-join/*` to MICO in dev (`api-onlinejoin.dev.abcfitness.net/iclub`, reachable without VPN). A local uncommitted patch in `online-join-bff/src/server.ts` skips the S3 asset-manifest fetch when `OJ_UI_URL` is set.
- **Recent direction.** This is the first sprint in this repo. The sibling `prospects1` repo owns the **backend** Prospect Wallet plan (`docs/prd/prospect-wallet-plan-v2.md`) and its SPRINT-0001, which makes `wallet-account-sync` and `universal-wallet` prospect-safe (G8 dedup-key fix, dark prospect sync lane). That plan fixes the identity model this UI must honour: **person-owned Universal Wallet keyed by Ignite member UUID, owner/user type MEMBER; `PROSP`, phone, email, barcode are never identity.**
- **Semantic prior art** (from `prospects1/docs/semantic-index`): owners/users are keyed `(externalId, type, org_id)` and need **no agreement number** to be created; entries are created via `POST /wallet-entry/credit-card` with a payment-gateway `pgToken` and `ownerIds`; `PROSP` breaks dedup keys, transfer regexes, and sync queries, so prospect owners must carry `dt_memberType=PROSPECT` and **no** `dt_agreementNumber` until conversion (hazards #1, #4, #5, #10, #11 in `themes/agreement-number-and-prosp.md`). The BFF toolkit already exposes an unused wallet API surface (`universalWallet`, `getWalletEntries`, `createAddWalletEntrySession` appear in `online-join-bff/src/__mocks__/@abc/bff-toolkit.ts`).
- **Key code areas (UI).** Routing is inline in `src/App.tsx` with `BrowserRouter basename="/signup"` and paths from `PAGES` in `src/common/constants.ts`; the guest/trial flow (`src/routes/GuestPage.tsx`, `GuestReviewPage.tsx`, `guestProfileFieldsSlice`, `gymService.submitTrial` → `POST /trial/submit`) is the closest analogue; state is Redux Toolkit with most slices and thunks in `src/reducers/index.ts`; services are axios instances in `src/services/index.ts` (`/api/online-join`) and `src/services/payPage.ts` (`/api/pay-page`); payment uses `@abc/pay-page-sdk` via `src/routes/PaymentPage/components/PayPageEmbed.tsx` and `hooks/usePayPageSession.ts`; config and flags reach the UI only as `window.env` / `window.featureFlags` injected by the BFF (`src/utils/featureFlags.ts`); tests are RTL + jest in top-level `__tests__/` mirroring `src/`, 80% line coverage floor.
- **Key code areas (BFF).** `src/routes.ts` composes routers; `src/routes/payPage/index.ts` is the template for a **non-proxy** route (OAuth client-credentials token cache, club→location/org resolution, server-fixed session options, security-regression tests in `__tests__/index.test.ts`); `src/utils/proxyFactory.ts` is the MICO proxy; `src/services/launchDarkly.ts` + `src/utils/getFeatureFlagContext.ts` evaluate flags server-side and serialize them in `src/routes/static/index.html.ts`; `src/utils/cookies.ts` manages the `SESSION-ID` cookie (httpOnly, sameSite none, partitioned). Coverage floor 84% lines.
- **What does not exist anywhere yet.** Day pass / short-term pass product, phone-or-email lookup, one-time code send/verify, saved-card retrieval, wallet-by-member-ID calls, prospect creation from the BFF, and the `dt-*` / `--ig-*` design system (only in the prototype's inline `<style>`; `@abc/ui-configs` ships lint configs, no CSS).
- **What MICO already offers, for reference.** `ProspectController` `/trial/submit` creates a prospect through `OrasvcClient.addProspect` (`/member/addProspect.spr` on datatrak-service); `/pos/saleItems.spr`, `/pos/onlineSale.spr`, `/pos/cardOnFile.spr` exist on the same client; `/account/personalLookup` is session-bound (by member ID), and there is **no lookup by phone or email** and no one-time-code capability in MICO.

## Pyramid Index

- L0: Ship the prototype's Day Pass single-flow checkout in online-join-ui and online-join-bff, with identity by member ID and wallet by member ID, without touching MICO.
- L1:
  - New UI flow (identify → recognized | new visitor → done) with a persistent Order Summary sidebar, date, terms gate, and pay; productize the `dt-*` design tokens.
  - New BFF routes for lookup, one-time code send/verify, session binding to member ID, saved-card read, pass purchase, prospect creation, wallet entry add; feature-flagged and dark by default.
  - Payment must go through the existing Pay Page SDK / BFF session routes, not raw card fields, to stay out of PCI scope.
  - The backend contract behind the BFF (which service answers lookup, code delivery, prospect create, pass sale, wallet) is the main uncertainty; drafts must propose a contract and a mock/adapter strategy so the UI can be demoed before those services exist.
  - Proof: jest suites in both repos at or above coverage floors, a scripted local demo against the compose stack or mocks, and security regression tests for the identity rules.
- L2:
  - Seed → prototype behaviour list; Context → code areas and prior art; Constraints; Success Criteria; Open Questions.
  - `docs/prd/day-pass.html` (source of truth for copy and states); `docs/SEMANTIC-INDEX.md`; `prospects1/docs/prd/short-term-passes-prospect-identity-prd.md` §4.3, §5, §6; `prospects1/docs/prd/prospect-wallet-plan-v2.md`.

## Semantic Index

- **Available (partial)** — Token cache: `/Users/bjornloftis/claudeprojects/prospects-ui/repos/` (mico, online-join-ui, online-join-bff) and `/Users/bjornloftis/claudeprojects/wallet-repos/` (wallet stack). Index entrypoint: `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/README.md` — covers the wallet stack only. Access: read entrypoint, follow `themes/identity-by-member-id.md` and `themes/agreement-number-and-prosp.md`, open leaf citations (they resolve under `wallet-repos/`); use `rg` directly against `prospects-ui/repos/` for the three online-join repos (never scan `mico/src/main/webapp` whole). Prior art retrieved: wallet owner/user creation needs only `(externalId=member UUID, type=MEMBER, locationId)`; card entries need a payment-gateway `pgToken`; `PROSP` must never reach `dt_agreementNumber`; the BFF toolkit has an unused wallet client surface.

Planning agents drafting this sprint must read the index entrypoint, follow the two identity themes, and run `rg` searches against the token cache (`online-join-ui/src`, `online-join-bff/src`, and narrowly in `mico/src/main/java`) before proposing architecture or implementation approaches. Do not attempt to scan the full token cache; use the index and targeted `rg` to sniff relevant areas first.

## Chapter Context

No chapter link selected. `docs/chapters/` does not exist in this repo. The long-range direction lives in the sibling repo's PRDs and is referenced above.

## Recent Sprint Context

First sprint in `prospects-ui`. Related backend sprint: `/Users/bjornloftis/claudeprojects/prospects1/docs/sprints/SPRINT-0001.md` (in progress) — makes wallet-account-sync and universal-wallet safe for prospect owners with no agreement number; it does **not** provision any prospect wallet or build any UI. This sprint is the first consumer-facing surface for that identity model.

## Relevant Codebase Areas

online-join-ui:
- `src/App.tsx`, `src/common/constants.ts` (`PAGES`, step lists), `src/index.tsx` (`basename="/signup"`)
- `src/routes/GuestPage.tsx`, `src/routes/GuestReviewPage.tsx` (closest existing flow), `src/routes/PaymentPage/**` (Pay Page SDK embed and session hook), `src/routes/ReviewPage/components/CreateMemberAccount.tsx` (memberId usage)
- `src/reducers/index.ts`, `src/reducers/states.ts`, `src/selectors/`, `src/configureStore.ts`
- `src/services/index.ts`, `src/services/gym.ts`, `src/services/payPage.ts`, `src/interfaces/api/gym.ts` (`onlineProspects`, `prospectTerms`)
- `src/components/` (FormInput, Modal, TermsAndConditions, HeadingBox), `src/utils/featureFlags.ts`
- `__tests__/**`, `jest.config.js`, `webpack.dev.config.js` (port 3001, `/iclub` proxy)

online-join-bff:
- `src/server.ts`, `src/routes.ts`, `src/routes/payPage/index.ts` + `__tests__/index.test.ts` (template), `src/routes/proxy/index.ts`, `src/utils/proxyFactory.ts`
- `src/routes/static/index.html.ts` + `utils/getAssets.ts` (`window.env`, `window.featureFlags`), `src/services/launchDarkly.ts`, `src/utils/getFeatureFlagContext.ts`
- `src/utils/cookies.ts`, `src/utils/setSecurityHeaders.ts` (CSP), `src/env.ts` (required env list), `src/__mocks__/@abc/bff-toolkit.ts` (wallet API surface)
- `.env.example`, `jest.config.js`

mico (read-only reference): `controller/ProspectController.java`, `controller/SignupController.java`, `feignclients/OrasvcClient.java` (`addProspect`, `personalLookup`, `pos/*`), `resources/application-local.yml` (dev service hosts).

wallet stack (read-only via index): `universal-wallet` owner/user/entry endpoints; `commerce-universal-wallet-sdk` request VOs.

## Constraints

- Scope is **online-join-ui + online-join-bff only**. No changes to `mico`, wallet services, datatrak, or spring-cloud-config in this sprint. Anything those systems must eventually provide is written as a contract and mocked/adapted in the BFF.
- Identity rules are non-negotiable: the phone/email only *finds* a candidate; the code proves possession; the session binds to the **Ignite member ID**; wallet owner/user are resolved by member ID with type MEMBER; `PROSP`, phone, email, barcode, and any placeholder agreement number are never identity and never written to `dt_agreementNumber`.
- Order of operations for a new visitor: authorize payment → persist prospect → **then** create wallet owner/entry, only with consent. Failure handling per PRD §4.4 (prospect persist failure → no wallet identity; wallet failure → keep prospect, retryable error, never claim the card was saved).
- **PCI**: the prototype's raw card inputs are illustrative. Production must collect cards through the existing Pay Page SDK / `/api/pay-page/session/*` routes (or an equivalent hosted field), never through React inputs posted to the BFF.
- Feature-flagged and **dark by default** (LaunchDarkly, club-scoped, evaluated server-side and delivered via `window.featureFlags`); gated additionally by the club's `onlineProspects` setting unless a draft argues otherwise.
- Follow existing repo conventions: TypeScript, Redux Toolkit slices + thunks, axios service modules, MUI v4 + scss components, RTL/jest tests in `__tests__/` (UI, ≥80% lines) and `src/**/__tests__/` (BFF, ≥84% lines); BFF routes follow the payPage pattern (server-fixed options, no client-derived security decisions, security-regression tests). Node ≥22 for the BFF.
- Copy and states come from the prototype; wording "day pass" may be kept in UI copy for this sprint, but internal naming should be **short-term pass** friendly (PRD FR-P1) so multi-day passes are not a rewrite.
- No secrets in tracked files; BFF credentials for any new upstream go in `.env` with entries added to `.env.example` and `src/env.ts`.
- One-time-code abuse controls (rate limit, attempt cap, expiry, no enumeration of whether a contact exists beyond what the flow requires) must be designed even if v1 uses a simple in-memory store.

## Success Criteria

- A club with the flag on can open `/day-pass?club=NNNNN` (or the chosen path) on the local stack and complete all three paths of the prototype: returning visitor with saved card; returning visitor with a new card; new visitor with and without saving a card.
- Every backend interaction goes through typed BFF routes with a documented contract; when the real upstream is absent locally, a mock adapter (selected by env/flag) makes the demo scriptable and deterministic, with the prototype's fixture (`m@m.com` / `(555) 019-2231`, Visa 4242) reproducible.
- Session binding, wallet resolution, and prospect creation use member ID only; tests assert that no `PROSP`/agreement value is ever sent as identity and that a new card for a recognized visitor is added to the existing owner.
- Payment collection uses the Pay Page SDK session routes; no PAN touches UI state or the BFF.
- `dt-*`/`--ig-*` tokens exist as a real stylesheet or component set in `online-join-ui`, applied to the new flow, without regressing the existing signup flow.
- Both repos' jest suites pass at or above their coverage thresholds; lint passes; the flow is unreachable with the flag off.
- Terms acceptance is a separate affirmative act recorded before payment; Pay is disabled until day and terms are set.

## Open Questions

1. **Backend contract.** Which service answers each call, and do the drafts propose the BFF calls them directly (with client-credentials, as payPage does) or through a future MICO/datatrak endpoint? Calls: lookup by phone/email at a club; send/verify one-time code (SMS provider and email path — `email-publisher-service` exists in MICO's config; is there an SMS service?); create prospect (datatrak `/member/addProspect.spr` exists behind MICO's `/trial/submit`); sell the pass (`/pos/onlineSale.spr` and `/pos/saleItems.spr` exist on datatrak-service); wallet owner/entry read and add (universal-wallet via `@abc/bff-toolkit`).
2. **Where does the pass product come from** — POS sale items for the club, a hardcoded per-club config for v1, or the online-join plan list? Price and perks in the prototype are fixtures.
3. **Route and entry point.** New top-level route under the existing `/signup` basename (e.g. `/signup/day-pass`), a new basename, or a new tab in the prototype's Class / Membership / Day Pass / Visit nav? The header in the prototype (club brand, location switcher, "Secure checkout") differs from the existing signup header.
4. **Design system.** Build `dt-*` as scss + small React components inside `online-join-ui`, or as MUI theme overrides, or start a shared package? Which is cheapest without regressing the existing flow?
5. **Session model.** After code verification, is the bound member ID kept in the existing `SESSION-ID` cookie (server-side store?) or a new short-lived signed cookie/JWT? Lifetime? Does "stay logged in and buy again" (Iron 24 benchmark) apply in v1?
6. **Recognized member vs prospect.** If lookup matches an existing *member*, proceed as member with their wallet, or redirect? (PRD §6 leaves this open.)
7. **Multiple matches** for one phone/email (household sharing) — pick most recent, ask, or treat as no match?
8. **Pass issuance and delivery** — what generates the QR/pass and sends the email/text? Is v1 a receipt only?
9. **Date selection** — keep the "Day pass applies on" picker (PRD FR-P4 says evaluate for web) or default to today?
10. **Demo diagnostics** — ship the "Behind the scenes" log behind a dev flag, or drop it?
