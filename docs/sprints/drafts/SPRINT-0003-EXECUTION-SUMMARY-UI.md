# Sprint 0003 — execution summary, UI lane (Phase C: C1–C8 and the UI half of E1)

**Sprint:** Design v4 (`docs/sprints/SPRINT-0003.md`). **Date:** 2026-09-16. **Executor:** Claude Fable 5.1, one session, tasks C1 → C8 in order, then lint / tsc / jest-with-coverage / webpack build in the foreground.
**Clone / branch:** `repos/online-join-ui`, `prospect-wallet/sprint-0003` — from `b6ae307` (Phase A) to **`6243e8b`**, 7 commits, working tree clean. **Not pushed.** Prerelease version and the `daypass` dist-tag untouched. The BFF clone was neither read nor modified; everything is coded against contract v3 and `src/interfaces/api/shortTermPass.ts`.
**Planning repo:** nothing committed. New, uncommitted: this file and `docs/sprints/drafts/SPRINT-0003-BLOCKERS-UI.md`.
**Phase C exit (plan):** *U1–U3, U6, U7, U11, U12, U20 (UI half), U21, U22 in jest; no QR on the done page; lint/build clean; coverage ≥ 80/80; summary and blockers written* — **met**. The browser check of `/signup/pass/:token` stays blocked on PA-1 (BFF history-fallback rewrite, B5).

## 1. Commits (`git log b6ae307..6243e8b`)

| Hash | Task | Content |
|---|---|---|
| `44026f5` | C1 | Slice: `CheckoutInfo.offers`, `offerId` (from `snapshot.offerId ?? selectedOfferId ?? offer`), `offerRollback`, `offerRequestsInFlight`, `passLink` status; thunks `selectOffer` (optimistic, serialized with order writes, rollback, applies `consent` + `generation`, toast "{label} · {money}"), `loadPassLink`, `resendPassEmail`; `OFFER_UNAVAILABLE` absorbed with the refreshed catalog; optimistic `validUntil` on date edits; `submitPurchase`/`loadPurchase` mark the link state. Selectors `offersSelector`, `selectedOfferSelector`, `offerPendingSelector`, `offerSelectableSelector`; `canPay` holds while a selection is pending. Services `selectOffer`, `getPassLink`, `resendPassLink` (checkout client, CSRF + generation), `getPassView` (plain `fetch`, `credentials:'omit'`, no CSRF), `PASS_TOKEN_PATTERN` / `isPassTokenShape`, `passQrImageUrl`. `format.ts`: `validityLabel`, `dateFieldLabel`, `validUntilOf`, `addDaysIso`, `offerToast`, `resendToast`, `durationLabel`/`lineItemLabel` honour `label`. Tests: NEW `shortTermPassSliceV3.test.ts`; `services/shortTermPass.test.ts` (+3), `selectors/shortTermPass.test.ts` (+3); fixtures `checkoutInfo.offers`, `coreCheckoutInfo`. |
| `72858ab` | C2 | NEW `components/OfferCards.tsx` (`.offers`, `role="radiogroup"`, `aria-label="Choose a pass"`, `.single` for one offer, disabled while pending or once an order exists); `OfferCard.tsx` selectable (`id="offer-{offerId}"`, `name="pass"`, `.days`, `checked`, `onChange` → `selectOffer`); `IdentifyStep` renders `<OfferCards/>` on identify **and** code entry and holds Continue; `InlineCodeEntry` holds Verify. Tests: NEW `OfferCards.test.tsx`; `IdentifyStep.test.tsx` rewritten for three cards. |
| `37af94e` | C3 + C4 | `OrderSummary`: `dateFieldLabel(order.durationDays)` ("Day pass applies on" / "Pass starts on"), help = `validityLabel`, Receipt "Valid" = range, line item from `order.label`/`offerName` (or the receipt snapshot `item`), "View your pass" Receipt row. `PassBlock` rewritten without `.qr` / `qrcode.react` (v4 sentence, AD-13 variants, "View your pass" `target="_blank"`, "Resend pass email"). `DoneStep` passes `label`/`validity`/`viewPath`, dispatches `loadPassLink` once when `viewPath` is missing, shows the 429/409 resend copy. Tests: NEW `PassBlock.test.tsx`; `DoneStep.test.tsx` rewritten (v4, Kelly 3-day); `OrderSummary.test.tsx` (+5), `format.test.ts` (+5). |
| `ad1ef91` | C5 | `PAGES.passView = '/pass/:token'`; `App.tsx` `matchPath(pathname, {path: PAGES.passView, exact: true})` **before** the `/day-pass` \| `/pass` branch; NEW `PassViewPage.tsx` (loading \| view \| not-found \| expired \| error; local state, plain fetch, no Redux, no CSRF singleton, no `?club=`, no flag hint, never bootstraps a checkout; malformed token → not-found without a request; Retry on generic errors), NEW `PassCredential.tsx` (QR via `qrcode.react` from `qr.payload`, `<noscript>` hosted PNG, "{label} · {validity}", first name, pill Upcoming / Valid today / Expired, desk sentence, "Get the {Brand} app"), NEW `PassReceipt.tsx`; `CheckoutShell` gains `sidebarLabel` + `withToast`. Tests: NEW `PassViewPage.test.tsx`; `App.test.tsx` (+2 routing precedence tests). |
| `d1ee1d7` | C6 | `MOBILE_HELP` deleted in `NewVisitorStep` and `RecognizedStep`; help = SMS notice only; `inputMode="tel"` / `autoComplete="tel"` pinned in both step tests. |
| `1f23204` | C8 + C7 | SCSS: `.identify-row > .lead {flex:1 1 300px; max-width:545px}`, `.offers {display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:s4; flex:0 1 560px; min-width:0}`, `.offer` `min-width:0`, `svg` 32 px, `.price` 32 px/600/−.02em, `.name` base/600, `.days` sm/500/muted/−4px, `ul` sm/22px, `@media (max-width:1250px)` column + `.offers {flex-basis:auto; width:100%; max-width:640px}`, `@media (max-width:640px)` single column (`minmax(0,1fr)`), 1100 px rule and 260 px card removed, `.offers.single` centred, `.qr` moved under NEW `.pass-view` (+ `.pill-*`, `.pass-links`). `layout.test.ts` (+4 guards). NEW `copy.test.ts`: every v4 string, CR-14 static scan (no "text your pass here on the day" / `MOBILE_HELP` under `routes/ShortTermPass/**`), CR-12 scan (`qrcode.react` imported only by `PassCredential.tsx`), design-source needle check against `docs/prd/day-passv4.html`. |
| `6243e8b` | tidy | jsdoc comment shape in the slice (lint warning). |

## 2. Quality — UI half of E1 (all foreground, after `6243e8b`)

| Check | Result | Baseline (Phase A summary) |
|---|---|---|
| `npx tsc --noEmit -p tsconfig.json` | **8 errors — the identical pre-existing list**: `src/routes/PaymentPage/PaymentPage.tsx` ×3, `src/routes/PaymentPage/PaymentPageWithPayPage.tsx` ×3, `__tests__/hooks/usePayPageSession.test.tsx` ×1, `__tests__/routes/PaymentPage/PayPageEmbed.test.tsx` ×1; none new | 8 |
| `npm run lint` (`eslint src/ --ext .ts,.tsx`) | **0 errors**, 760 warnings | 0 / 756 |
| `npx jest --coverage` | **109 suites: 108 passed, 1 failed; 734 tests: 733 passed, 1 failed** — the failure is the pre-existing `__tests__/helpers/transformers.test.ts › transformAgreement builds the agreement payload using today payment info` (timezone baseline; accepted exception, not counted green). All 21 `routes/ShortTermPass` suites, `reducers/shortTermPass` ×2, `selectors`, `services/shortTermPass`, `App` green | 104 / 651, same failure |
| Coverage (stmts / branches / funcs / lines) | **92.90 / 85.65 / 88.46 / 92.90** — floors 80 / 80 hold; no threshold lowered, no exclusion added | 92.47 / 84.2 / 87.5 / 92.47 |
| `npm run build` (webpack 5 production) | **exit 0**, compiled with the 3 pre-existing asset-size warnings | same |
| `git status` | clean | — |

## 3. Use cases → tests

| UC | Pinned by |
|---|---|
| U1 identify header, `.offers` radiogroup, three cards (ids, `name="pass"`, chip only on checked, `$25/$60/$90`, "Gym Floor", `.days`, perks), 1-day default, keyboard = native radios | `OfferCards.test.tsx` (U1), `IdentifyStep.test.tsx` (U1, header), `copy.test.ts` |
| U2 select → chip moves, toast "3-day pass · $60.00", `PUT /offer {offerId, generation}`, generation bump adopted, reload restores `snapshot.offerId`, Change keeps / Start again drops, cards on code entry, rejected PUT rolls back, Continue/Verify/Pay held | `shortTermPassSliceV3.test.ts` (bootstrap + selectOffer blocks), `OfferCards.test.tsx` (U2 ×2, code entry), `IdentifyStep.test.tsx` (U2 Continue held), `selectors/shortTermPass.test.ts` (canPay hold) |
| U3 Riverside single pre-selected card, `.offers.single` (AD-11) | `OfferCards.test.tsx` (U3), `IdentifyStep.test.tsx`, `layout.test.ts` |
| U6 multi-day sidebar: "Pass starts on", "Today – Fri, Sep 11" / "Today – Sun, Sep 13", line item "3-day pass · Gym Floor", totals, Pay sentence, date → Sep 16 → "Wed, Sep 16 – Fri, Sep 18", past `maxVisitDate` never sent/clamped | `OrderSummary.test.tsx` (U6 ×3), `format.test.ts` (validity block), `shortTermPassSliceV3.test.ts` (optimistic `validUntil`) |
| U7 1-day: "Day pass applies on", "Today · Wed, Sep 9" | `OrderSummary.test.tsx` (U7, U10), `format.test.ts` |
| U11 done page: "You're in, Kelly" / "Your pass is ready", block without QR "3-day pass · Wed, Sep 16 – Fri, Sep 18" + v4 sentence, "View your pass" under the block **and** as a Receipt row (new tab), Receipt Valid range, saved/not-saved/retry alerts, two buttons | `DoneStep.test.tsx` (U11, Riverside, wallet cases), `PassBlock.test.tsx` (U11), `OrderSummary.test.tsx` (U11 receipt row), `copy.test.ts` (CR-12 scan) |
| U12 truthful variants pending / failed / not-attempted, "Resend pass email" → `POST …/pass-link` with toast per `delivery.status`, reload → `GET …/pass-link` shows the link without a resend, 404 → CTA hidden | `DoneStep.test.tsx` (U12 ×6, reload, 404, throttled), `PassBlock.test.tsx` (U12), `shortTermPassSliceV3.test.ts` (pass link block), `format.test.ts` (resend toast) |
| U20 (UI half) `/signup/pass/pv1.x` → pass page and **not** `ShortTermPassPage`; `/signup/pass` still the done flow; `/signup/day-pass` still the checkout; `window.featureFlags` absent; no dispatch; no checkout bootstrap, no CSRF singleton, plain fetch without credentials | `App.test.tsx` (U20 ×2), `PassViewPage.test.tsx` (U21 first test asserts `createCheckout`/`setCsrfToken` never called, no `?club=`), `services/shortTermPass.test.ts` (fetch init `credentials:'omit'`, no CSRF header, axios instances untouched, identical 404) |
| U21 page: shell brand + location, QR from `qr.payload`, "{label} · {validity}", first name only, pill, desk sentence, "Get the {Brand} app", Receipt sidebar (number, item, amount, Valid), states loading / not-found / expired (no QR) / error + retry, no card or ids on the page | `PassViewPage.test.tsx` (6 tests), `copy.test.ts` |
| U22 no "We'll text your pass here on the day." under `routes/ShortTermPass/**`; help = SMS notice; `inputMode`/`autoComplete` tel | `NewVisitorStep.test.tsx`, `RecognizedStep.test.tsx`, `copy.test.ts` (static scan) |
| Regression: 320 px three cards never overflow; v1.2 rules kept; no `<select>`; PCI scan | `layout.test.ts` (v4 grid block), `pci.test.ts`, `isolation.test.ts` |

## 4. Deviations from the plan

Listed with reasons in `SPRINT-0003-BLOCKERS-UI.md` §Deviations. Headline: `rel="noopener noreferrer"` (lint rule); PROPOSED copy for `not-attempted`, the resend toasts and the pass-page chrome (no v4 design — PC-1 for DESIGN); expired = credential without QR + alert; malformed tokens short-circuit to not-found; token passed as a prop; `CheckoutShell` props; browser-side optimistic `validUntil`; `GET …/pass-link` failures silent by design; `offers[]` fallback for a v2 response.

## 5. What the orchestrator must know for the browser smoke (E2)

**Blocked until B5 (PA-1):** `/signup/pass/<token>` returns 404 from the history fallback until the BFF rewrite lands; the checkout flow itself is unaffected.

**Identify / code entry (1440 and 375):**
- Group: `.offers[role="radiogroup"][aria-label="Choose a pass"]`; three `label.offer[for="offer-<offerId>"]` with `input#offer-<offerId>[name="pass"]` — ids `offer-day-pass-gym-floor`, `offer-day-pass-gym-floor-3`, `offer-day-pass-gym-floor-5`; Riverside `.offers.single` with `#offer-day-pass-1-day`.
- Checked card: `.offer.selected` (exactly one) with `.offer.selected .chosen` = "Selected"; `.offer .price` "$25" / "$60" / "$90"; `.offer .name` "Gym Floor"; `.offer .days` "1-day pass" / "3-day pass" / "5-day pass"; `.offer li` perks.
- Selecting: click the label or the input; arrow keys move within the native radio group. While the PUT is in flight every radio is `disabled` and `#continue` / `#verifyBtn` are disabled.
- Toast: `.toast.show[role="status"]` text "3-day pass · $60.00" (visible ~1.8 s; `.toast` stays in the DOM without `.show`).
- Sidebar before verify: two `.skeleton` blocks (unchanged).

**Sidebar after verify:** `label[for="day"]` text "Pass starts on" (multi-day) / "Day pass applies on" (1-day); `#day` (date, `min` = club-local today); `.dayfield .dt-help` = validity ("Today – Fri, Sep 11", "Wed, Sep 16 – Fri, Sep 18"); line item `.srow .k` ("3-day pass · Gym Floor"); `.total`; Pay button text from `consent.payButtonText`.

**Done page:** `[data-testid="pass-block"] .big` = "3-day pass · Wed, Sep 16 – Fri, Sep 18"; `.sm` = the delivery sentence; **no** `.qr`, `svg` or `canvas` inside `main`; `[data-testid="pass-links"] a[data-testid="view-pass"]` (`href="/signup/pass/pv1.…"`, `target="_blank"`, `rel` contains `noopener`) and `button#resendPass` ("Resend pass email"); Receipt row `[data-testid="receipt-view-pass"] a` with the same href; `aside .srow` "Valid" → range. After a reload the link appears once `GET …/pass-link` answers (no resend is sent). Resend toast text: "Pass email sent to {masked}" / "Sending your pass email to {masked}" / "We couldn't send the pass email to {masked}"; a 429 shows `.dt-alert.danger` "… Try again in Ns.". Open the link by reading `href` and navigating a **fresh** context (it targets a new tab).

**Pass page (`/signup/pass/<token>`, fresh context, no cookie, no `?club=`):**
- Loading: `[data-testid="pass-loading"][aria-busy="true"]` "Loading your pass…".
- View: `header.dt-header .dt-brand .word` = club brand, `[data-testid="location"]`; `main h1` = "Your pass"; `[data-testid="pass-credential"].pass-view.status-{upcoming|active|expired}`; `[data-testid="pass-qr"] svg` (present for upcoming/active, **absent** for expired; the `<noscript>` inside carries `/api/short-term-pass/passes/<token>/qr.png`); `[data-testid="pass-title"]` "{label} · {validity}" (uses the server's `today`); `[data-testid="pass-holder"]` first name; `[data-testid="pass-status"].pill.pill-{status}` "Upcoming" / "Valid today" / "Expired"; `.pass-view .sm` "Show this at the door, or just say your name at the front desk."; `a#getApp` "Get the {Brand} app" when `club.links.app` exists.
- Expired: additionally `[data-testid="pass-expired"]` (`.dt-alert.warning`) "This pass link has expired. Your receipt is in your email; the front desk can look you up by name."
- Receipt sidebar: `aside[aria-label="Receipt"] [data-testid="pass-receipt"]` rows item/amount, "Valid" (absolute dates), "Receipt number", total "Paid"; fine print "Receipt emailed to {masked}. No membership. No recurring billing." No card brand/last4, no ids.
- Not found (tampered / revoked / expired link / malformed): `[data-testid="pass-not-found"] h1` = "This link isn't valid." (empty brand in the header). Malformed tokens never hit the API.
- Other errors: `[data-testid="pass-error"] .dt-alert.danger` "Something went wrong. Please try again." + `button#retryPass`.
- No `role="status"` toast on this page; `window.featureFlags` is never read; the request is `GET /api/short-term-pass/passes/<token>` with `credentials: 'omit'` and no `X-STP-CSRF`.

**Overflow check 320–440 px:** `.offers` is `repeat(3, minmax(0,1fr))` down to 640 px and a single `minmax(0,1fr)` column below; the identify row stacks below 1250 px — pinned by `layout.test.ts`, visual confirmation is E2's.

## 6. Next

Orchestrator: review this summary and `SPRINT-0003-BLOCKERS-UI.md`, answer or forward the seven contract questions to the BFF lane, push `prospect-wallet/sprint-0003` (UI head `6243e8b`) when both lanes are in, and run E2 once B5's rewrite (PA-1) is in the running BFF.
