# Agent 6 — Entry gating, club variants, sessions/cookies, navigation, resilience, a11y (desktop 1440x900)

## 1. Environment + what was run
- Desktop Chrome (channel `chrome`, headless) via playwright-core, viewport 1440x900, one fresh browser context per scenario unless the scenario is about sharing a context (two tabs).
- Entry `http://localhost:3000/signup/day-pass?club=…` against the running BFF (:3000, mock adapters) and webpack dev server (:3001). No servers touched.
- Personas: only unknown contacts `qa6-1@gating.test` … `qa6-22@gating.test` plus `qa6-22@gating-alt.test` (all new visitors, mock card `visa-4242` / `mastercard-4444`). No fixture personas used.
- Scripts: `$S/qa/agent6-gating-session/t1-gating.mjs` (club variants, malformed club, iframe, flag, direct /signup/pass, headers, nav, axe), `t2-session.mjs` + `t2a/t2b/t2c/t2d/t2e` (reload per step, two tabs, cookie deletion, offline, injected 500/502/429/hang/3 s-slow), `t3-keyboard-axe.mjs`, `t4-twotab-expired.mjs`, `t5-keyboard-done.mjs`, `t6-twotab-domain.mjs`. Raw output in the matching `*.out` files.
- Screenshots: `$S/qa/shots/agent6-gating-session/*.png` (names referenced below).
- API-level probes (marked as such): `curl -i` on the HTML entry for headers; node `fetch` POST `/api/short-term-pass/checkouts` for club 99999 / 90031 / 90030 (no Origin header → 403; 404 envelopes for bad clubs). Everything else was driven through the real UI. `page.route` was used only to inject BFF failures/latency.

## 2. Findings table

| ID | Sev | Title | Repro |
|---|---|---|---|
| A6-01 | P1 | Lost/deleted session cookie is a dead end: Pay / Continue / date change show a raw "Not found" alert, no session-expired toast, no restart | 3/3 |
| A6-02 | P1 | Two tabs, same cookie: identifying in tab B silently re-binds the checkout; tab A still shows the old contact and pays — pass/receipt go to tab B's contact, person created under the wrong contact | 2/2 |
| A6-03 | P1 | Reload on the new-visitor step: Pay can never be enabled again (mock card selected, "ready" 201, terms accepted) — visitor stuck until "Edit" | 2/2 |
| A6-04 | P2 | Session-expired toast "Your session expired. Let's start again." never renders — `resetForNewCheckout` wipes `toast` in the same tick | 1/1 (+code) |
| A6-05 | P2 | Bootstrap `POST /checkouts` returning 200 with a non-JSON/HTML body crashes the reducer (`Cannot read properties of undefined (reading 'contactHint')`) and leaves "Loading your checkout…" forever | 1/1 |
| A6-06 | P2 | Purchase request with no response hangs in "Processing…" indefinitely (no client timeout, no message, no way out but reload) | 1/1 (15 s observed) |
| A6-07 | P2 | Transient network failure during bootstrap shows the permanent copy "This page is not available. Please contact the club." (same as flag-off/unknown club) | 2/2 |
| A6-08 | P2 | Tab A after tab B completed the purchase: card/terms actions fail with "Identify yourself before adding a card." / "…before changing the order." — no recovery path offered (reload does recover) | 2/2 |
| A6-09 | P2 | a11y: `<html>` has no `lang`; two `<main>` landmarks (`#app` from BFF HTML + `#main` in UI); unavailable page has no h1 (uses `<h6>`); done page has no h1 | 4/4 pages |
| A6-10 | P2 | a11y: primary button text contrast fails WCAG AA (white #FCFCFC on #239CD3, ~3.0:1 at 16 px) — `#continue`, `#pay`, `#again`; `.d` help text #727272 at 12 px also flagged | 4/4 |
| A6-11 | P2 | 429 THROTTLED on identify: message shown but `retryAfterSeconds` (42) is not surfaced; Continue re-enabled immediately | 1/1 |
| A6-12 | P3 | Slow network (3 s): Terms checkbox does not tick until the server acks (no pending state); date input keeps the old value while the toast already announces the new day | 2/2 |
| A6-13 | P3 | Terms modal: initial focus lands on the MUI dialog container, not the first control; React `findDOMNode` StrictMode console.error from MUI Transition when the modal opens | 2/2 |
| A6-14 | Q | Header nav "Classes · Memberships · Visit" are dead, non-focusable `<span>`s styled like tabs (catalog supplies no links); QR is an unlabelled `<svg>` | 3/3 |
| A6-15 | Q | Production CSP sets `frame-ancestors *` (BFF `setSecurityHeaders`), so embedding is only blocked by the client-side iframe check; no `X-Frame-Options`. Dev serves no security headers at all (by design, `isProduction` gate) | API-level |
| A6-16 | Q | Core South (90033) offer has perks `Classes, Steam & Sauna, Basketball court` in the catalog but the UI shows none of them anywhere | 1/1 |
| A6-17 | Q | Reload on the new-visitor step loses first/last name, second contact and the selected card but keeps the accepted terms and the chosen date (server-side); reload on identify loses typed-but-unsubmitted text and a date picked before identify | 2/2 |

## 3. Detailed findings

### A6-01 (P1) Deleted/lost session cookie → "Not found" dead end
- Viewport: 1440x900.
- Steps: 1) Load entry (club 90030). 2) Identify `qa6-6@gating.test` → new-visitor step. 3) Fill Qa / Six, pick `visa-4242`, tick terms (Pay enabled). 4) Delete cookies (`context.clearCookies()`). 5) Click Pay. Variant U: delete cookie on the identify step, then Continue with `qa6-18@gating.test`. Variant C4: delete cookie on the new-visitor step, change the date.
- Expected (brief §Flow: "Session-expired -> toast 'Your session expired. Let's start again.' and restart"; ShortTermPassPage.tsx:79-84).
- Actual: red alert with the literal text **"Not found"** under the terms row (C1-cookie-deleted-pay.png). Form stays as-is, Pay stays enabled, every further click repeats "Not found". On identify: same "Not found" alert, Continue keeps failing (U1-cookie-deleted-identify.png). Date change: toast "Day pass for Sun, Sep 13" fires, the date snaps back to 09/10 and "Not found" appears (C4-cookie-deleted-date.png). Only a manual reload recovers (new checkout).
- Evidence: `[http 404] POST …/checkouts/chk_…/purchases`, `[http 404] PUT …/order`, `[http 404] POST …/identify`; body `{"code":"NOT_FOUND","message":"Not found"}`.
- Repro 3/3.
- Suspected cause: BFF `src/routes/shortTermPass/context.ts:107-110` `withCheckout` answers 404 `NOT_FOUND` whenever the cookie is missing/unknown (only a *known but expired* record yields 401 `CHECKOUT_EXPIRED`). The UI only restarts on `CHECKOUT_EXPIRED` (ShortTermPassPage.tsx:80) and otherwise renders `error.message` verbatim (PayBar.tsx:57-61, IdentifyStep.tsx:52). A cookie that is gone (cleared site data, cookie blocked, browser restart with session cookies dropped, BFF restart/in-memory store loss) is the realistic case and it produces a dead end with an untranslated server message.

### A6-02 (P1) Two tabs on one cookie: purchase delivered to a contact the paying tab never showed
- Steps: 1) Tab A loads entry (cookie issued). 2) Tab B loads entry, identifies `qa6-21@gating.test`, reaches new-visitor, types Qa / TwentyOne. 3) Tab A identifies `qa6-22@gating-alt.test` → new-visitor. 4) Back in tab B (header still reads "Email qa6-21@gating.test Edit"): pick `visa-4242`, tick terms, Pay.
- Expected: the checkout tab B is paying for is the contact tab B shows, or tab B is told the checkout changed.
- Actual: purchase succeeds; the done page in tab B says **"We emailed it to q•••••@gating-alt.test too."** and "Receipt emailed to q•••••@gating-alt.test" — tab A's contact — while the person/wallet were created under that contact (T6-tabB-done-wrong-contact.png; T2-tabB-done-after-identity-switch.png). No 4xx anywhere; all 200/201.
- Repro 2/2 (t4 with same-domain contacts, t6 with a different domain to prove which contact won; the mask caps at 5 bullets so same-length contacts are indistinguishable on screen).
- Suspected cause: `services/shortTermPass/identify.ts:76-82` overwrites `draft.contact` and replaces the order shell for the same checkout; the UI has no version/etag on the checkout, so a stale tab keeps operating on the re-bound record (capture/mock, PUT order, purchases all accept it). Suggest a checkout revision check (409 on stale snapshot) or re-hydrating on `visibilitychange`/focus.

### A6-03 (P1) Reload on the new-visitor step → Pay can never be enabled
- Steps: 1) Identify `qa6-10@gating.test`. 2) Fill Qa / Ten, pick `mastercard-4444` ("Paying with Mastercard •• 4444" appears), tick terms → Pay enabled. 3) Reload. 4) Re-enter Qa / Ten, pick `visa-4242` (BFF answers 201 `{"status":"ready","brand":"Visa","last4":"4242"}`), terms already ticked (server-side). 5) Un-tick and re-tick terms (PUT /order 200, `ready:true`).
- Expected: Pay enabled ("Pay is enabled by readiness", PayBar.tsx; selectors.paymentReadySelector).
- Actual: Pay stays disabled, "Paying with" row never appears, no error anywhere (A3b-after-reload-reselect-card.png, A3-reload-newvisitor.png). Only "Edit" → identify again gets the visitor out.
- Repro 2/2 (t2 and t2a).
- Suspected cause: `shortTermPassSlice.ts` `applySnapshot` case `'newVisitor'` (line ~306) only sets `step`; it does not set `paymentChoice = { useSaved: false }` the way `identifyContact.fulfilled` does (line ~433). Initial state has `useSaved: true`, so `paymentReadySelector` looks for a saved-card `selectionRef` that a new visitor can never have, and `payingWithSelector` hides the captured card.

### A6-04 (P2) Session-expired toast never renders
- Steps: new-visitor step for `qa6-19@gating.test`, card + terms; `page.route` the purchase call to answer `401 {"code":"CHECKOUT_EXPIRED",…}` (the only way to get this code while the cookie is still valid — see A6-01).
- Expected: toast "Your session expired. Let's start again." then restart (ShortTermPassPage.tsx:79-84).
- Actual: no toast at any point (polled `.toast.show` every 50 ms for 5 s; V1-checkout-expired-toast.png). The flow did reset and re-bootstrap (which, with a still-valid cookie, resumed the same new-visitor snapshot).
- Suspected cause: the effect dispatches `showToast` then `resetForNewCheckout`; the latter returns `{...initialShortTermPassState, generation, contact}` (slice ~line 400) which has no `toast`, so the toast is erased before the Toast component's next render. Dispatch the toast after the reset, or preserve `toast` in the reset.

### A6-05 (P2) Non-JSON 200 on bootstrap → reducer crash, infinite "Loading your checkout…"
- Steps: `page.route('**/api/short-term-pass/checkouts')` → `200 text/html "<html>gateway</html>"`, load entry.
- Actual: `[pageerror] Cannot read properties of undefined (reading 'contactHint')`; page shows header without club name and "Loading your checkout…" forever (E1c-bootstrap-garbage.png). Realistic for captive portals / WAF interstitials / misrouted proxies answering 200 HTML.
- Suspected cause: `bootstrapCheckout.fulfilled` → `applySnapshot` dereferences `response.snapshot` without validating the shape (slice ~line 290). A shape check should route to the unavailable/retry state.

### A6-06 (P2) Purchase with no response: "Processing…" forever
- Steps: new-visitor ready; `page.route('**/purchases', r => { /* hold */ })`; click Pay; wait 15 s.
- Actual: button "Processing…", date input disabled, no message after 3 s or 15 s (E4-purchase-hang.png). Releasing the request later completed the purchase (E4c). There is no client-side timeout for the purchase call (axios instance in `services/shortTermPass.ts` has no `timeout`), so a stalled connection is indistinguishable from progress.

### A6-07 (P2) Network failure on bootstrap shows the "unavailable" copy
- Steps: abort `POST /checkouts` with `connectionfailed` (or go offline before first load).
- Actual: "This page is not available. Please contact the club." (E1b-bootstrap-netfail.png), identical to flag-off/unknown club. A `500` on the same call does the same (E1-bootstrap-500.png). Neither offers retry.
- Suspected cause: `bootstrapCheckout.rejected` → `step = 'unavailable'` regardless of `status`/`retryable` (slice ~line 300).

### A6-08 (P2) Stale tab after another tab completed
- Continuation of A6-02: in tab A (still on new-visitor form), selecting a card → 409 "Identify yourself before adding a card."; ticking terms → 409 "Identify yourself before changing the order." (T5-tabA-after-B-completed.png). Copy is misleading (the visitor did identify) and there is no CTA; reload lands on the done page (B6-tabA-reload.png).

### A6-09 / A6-10 axe-core 4.x (wcag2a/aa, 21a/aa, best-practice) — impact summary
- identify (90030): serious 2 (`color-contrast` #continue, `html-has-lang`), moderate 3 (`landmark-main-is-top-level` #main, `landmark-no-duplicate-main` #app, `landmark-unique` #app).
- new visitor: serious 2 (`color-contrast` `.d` help text, `html-has-lang`), moderate 3 (same landmarks).
- terms modal open: serious 2 (`color-contrast` ×2 incl. `.dt-btn` secondary, `html-has-lang`).
- done: serious 2 (`color-contrast` #again, `html-has-lang`), moderate 4 (landmarks ×3, `page-has-heading-one`).
- unavailable (99999): serious 1 (`html-has-lang`), moderate 4 (landmarks ×3, `page-has-heading-one`; the message is an `<h6>`).
- Measured: `#continue` color rgb(252,252,252) on rgb(35,156,211), 16 px/500 → ≈3.0:1 (needs 4.5:1). `.d` rgb(114,114,114) at 12 px on white ≈4.9:1 but axe flags against the grey card background.
- Causes: BFF `src/routes/static/index.html.ts:126` `<html>` without `lang` and `:149` `<main id="app">`; UI `CheckoutShell.tsx:53` renders another `<main id="main">`; `Unavailable()` in ShortTermPassPage.tsx:41 uses `<h6>`.

### A6-11 (P2) THROTTLED copy without retry seconds
- Route identify → `429 {"code":"THROTTLED","message":"Too many attempts. Please wait and try again.","retryAfterSeconds":42}`. UI shows the message verbatim in a danger alert (E2-identify-429.png); `retryAfterSeconds` is carried into `error.retryAfterSeconds` (slice `toUiError`) but no step renders it, and Continue is immediately re-enabled. The real BFF copy for challenge throttling is "Please wait before requesting another code." / "Too many codes were sent…" (challenge.ts:64/72) — neither includes the wait.

### A6-12 (P3) Slow network states (3 s delay on every `/checkouts/**` call)
- Identify: Continue disabled while busy (good), input still editable (fine). Card select: no pending indicator for 3 s. Terms checkbox: clicking it does nothing visible for 3 s (controlled by `order.terms.accepted`; Playwright's `check()` even reports "did not change its state"), then ticks. Date: toast "Day pass for Mon, Sep 14" fires instantly but the input shows 09/10 until the PUT returns. Pay: "Processing…" + date disabled (good). Screens: E5a-identify-busy.png, E5b-capture-busy.png, E5g-pay-busy.png.

### A6-13 (P3) Terms modal focus + console error
- Opening via keyboard: focus goes to `div.MuiDialog-container`, first Tab reaches "Close terms" ×; Tab cycles ×/Close/Agree/container (trap works). Escape closes and restores focus to the "Terms & conditions" link (good). Console: `Warning: findDOMNode is deprecated in StrictMode … Transition` (React/MUI, dev-only noise but it is a console.error on every open).

### A6-14 (Q) Dead nav + unlabelled QR
- Header renders `Classes`, `Memberships`, `Day pass` (aria-current=page), `Visit` as `<span class="dt-tab">` with no href, tabindex -1; clicking does nothing (URL unchanged). Per CheckoutShell.tsx comment this is intended when the catalog supplies no links (OQ-8), but visually they read as tabs. The pass QR is a bare `<svg>` with no `role="img"`/`aria-label`.

### A6-15 (Q) Framing protection is client-side only
- `curl -i -H 'Accept: text/html' /signup/day-pass?club=90030` → no CSP, no X-Frame-Options (dev; `setSecurityHeaders` is gated on `isProduction`). In production `src/utils/setSecurityHeaders.ts:13` sets `frameAncestors: '*'`. The in-iframe UI ("Checkout opens in its own window." + `Open secure checkout` → `/signup/day-pass?club=90030`, `target=_top rel=noopener`) works (iframe-host.png) and no `/api` call or cookie is issued inside the frame — but that relies on JS in the framed document, not on a header. Flag for security review if clickjacking of the top-level link matters.

### A6-16 (Q) Core South perks not shown
- 90033 sidebar: "Gym Floor $25.00", Pay label "Pay $25.00 and get my pass", done page "Get the CORE app" → https://example.com/core-app (c90033-newvisitor.png, c90033-done.png). Catalog perks `Classes, Steam & Sauna, Basketball court` appear nowhere. Riverside demos have no perks so this may be by design; day-pass.html (lowest-priority requirement) shows them.

### A6-17 (Q) What reload keeps / loses
- identify: typed-but-unsubmitted contact lost; a date picked before identifying (pendingVisitDate) lost (A1-reload-identify.png).
- new visitor: step + contact kept (rehydrated via `POST /checkouts` `resumed:true`), accepted terms and chosen date kept (server), first/last/second contact/selected card lost, and Pay cannot be re-enabled (A6-03).
- done: fully rehydrated ("You're in, Qa", pass, receipt) at `/signup/pass?club=90030` (A5-reload-done.png). Browser Back from done lands on about:blank (history.replace, expected). Visiting the entry URL again after done redirects to the done page; "Start again" issues a fresh checkout and refocuses `#ident`.

## 4. What passed
- Club 90030: identify screen, sidebar "1-day pass $18.00", min/value date = club-local today, cookie `OJ-PASS-SESSION` HttpOnly, SameSite=Lax, Path=/, host-only, session-scoped (`expires:-1`), Secure=false on local HTTP (BFF `session.ts:39-46`; Secure is `ctx.secure`-driven and 403s insecure production).
- 90031 (onlineProspects false), 99999, no `club`, `club=`, `club=<script>…` (encoded and raw), `club=' OR 1=1`, 40-char club: all render exactly "This page is not available. Please contact the club."; no script executed, no cookie issued; BFF answers 404 `NOT_FOUND` for 90031/99999 and the client never calls the API for malformed/missing clubs (sanitizer `^[A-Za-z0-9-]{1,16}$` on both sides).
- `club=90030&club=90031` → first value wins (Riverside); `club=90031&club=90030` → unavailable (consistent with `Array.isArray(club) ? club[0]`).
- 90032 Northside: header "Riverside Athletic Club — Northside", Terms modal shows the club-authored HTML `<h3>Northside club terms</h3><p>Club-authored terms for the Northside location.</p>` (c90032-terms-modal.png). Timezone difference not observable today (Chicago and New York share the date at test time).
- 90033 Core South: name, "Gym Floor" $25.00, "Pay $25.00 and get my pass", "Get the CORE app" link, full purchase OK.
- Feature flag: `window.featureFlags.oj_short_term_pass_checkout === true` in the page; forcing it `false` via `addInitScript` renders the unavailable block (flag-off.png). (The `Cannot redefine property: featureFlags` pageerror there is caused by my override colliding with the BFF inline script, not a product bug.)
- Direct `/signup/pass?club=90030` with no session → redirected to `/signup/day-pass?club=90030` identify step, no crash; with club 99999 → unavailable.
- Iframe: correct copy, link `href=/signup/day-pass?club=90030 target=_top rel=noopener`, no API calls, no cookie.
- Offline on Continue: alert "Something went wrong. Please try again."; back online, Continue succeeds with the typed contact intact. Offline on Pay: same alert; back online, one click on Pay completes the purchase with name/card/terms intact (idempotency key retained on status 0) (D1/D3/D5 screenshots).
- Injected 500 on purchase: alert shows the BFF message ("Something broke server-side"), form intact, Pay re-enabled; 502 with HTML body → generic "Something went wrong. Please try again."; real purchase afterwards succeeded.
- Two tabs: tab A reload after tab B paid lands on the done page (B6).
- Keyboard: `#ident` autofocused; Tab order identify → Continue → date → (nav skipped); Enter submits identify; Space toggles terms; Enter on Pay pays; done page Tab order Get app → Start again; Enter on Start again restarts and refocuses `#ident`. Focus visible on all controls (2 px solid outline on buttons, 3 px ring on inputs). Modal: trap + Escape + focus restore OK; "Agree and close" via Enter ticks the checkbox.
- No console errors other than the ones listed (dev HMR / AppD / Redux-toolkit "middleware took Nms" warnings ignored).

## 5. Not tested / blocked
- Northside `America/New_York` date boundary: both fixture timezones are on the same calendar day at test time; would need a run between 00:00 and 01:00 America/New_York.
- Production security headers (CSP hashes, `frame-ancestors`): dev server does not send them (`isProduction` gate); assessed from source only.
- Real `CHECKOUT_EXPIRED` from the BFF (record past TTL) — could not wait out the TTL; simulated via `page.route` (A6-04). Real cookie loss is covered in A6-01.
- Keyboard-only change of the `<select id="mockCard">` (ArrowDown did not change the value in headless Chrome — Playwright limitation on native selects; not reported as a finding).
- Mobile viewports, OTP/verify step, returning-visitor step, date edge cases — other agents' slices.
