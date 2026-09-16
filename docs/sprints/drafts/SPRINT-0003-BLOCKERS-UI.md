# Sprint 0003 — UI lane blockers, deviations and contract questions (Phase C)

Executor: Claude Fable 5.1, 2026-09-16 (UI lane, single session, tasks C1–C8 then the UI half of E1). Clone `repos/online-join-ui`, branch `prospect-wallet/sprint-0003` (was `b6ae307`, now `6243e8b`), **not pushed**. Nothing committed in the planning repo; `docs/sprints/ledger.yaml` untouched. The BFF clone was not read or touched — every call is coded against contract v3 (`docs/contracts/short-term-pass-bff.md`) and `src/interfaces/api/shortTermPass.ts`.

## Blockers

| ID | Status | What | Effect on this lane | Owner / next |
|---|---|---|---|---|
| PA-1 (carried from Phase A) | **open, not a UI blocker** | `koa2-connect-history-api-fallback` does not rewrite the dotted `/signup/pass/pv1.<id>.<exp>.<sig>` path to the SPA entry (dot rule) → 404 in a browser | C5 is complete and pinned in jest (`App.test.tsx`, `PassViewPage.test.tsx`); the page **cannot be opened in a browser** until B5 lands the rewrite `{from:/^\/signup\/pass\/pv1\.[A-Za-z0-9_.-]+$/, to:'/'}` | BFF lane (B5); orchestrator re-checks in E2 |
| PC-1 | **open, DESIGN** | No v4 design exists for the pass page, the `pending` / `failed` / `not-attempted` done-page sentences beyond AD-13, the resend toasts, or the pass-page receipt fine print | Shipped PROPOSED with the copy pinned in `copy.test.ts` (see §Deviations for the exact strings) | D2 records them; DESIGN reviews |

No task was skipped or scaled down. All eight C tasks and the UI half of E1 are done.

## Baseline accepted as-is (not fixed, not worsened)

| Item | Before Phase C | After Phase C |
|---|---|---|
| `npx tsc --noEmit -p tsconfig.json` | 8 errors: `routes/PaymentPage/PaymentPage.tsx` ×3, `routes/PaymentPage/PaymentPageWithPayPage.tsx` ×3, `__tests__/hooks/usePayPageSession.test.tsx` ×1, `__tests__/routes/PaymentPage/PayPageEmbed.test.tsx` ×1 | **identical 8**, none under `routes/ShortTermPass`, `reducers/shortTermPass`, `selectors`, `services`, `interfaces/api`, `App.tsx` or the new tests |
| jest | 104 suites / 651 tests, 1 pre-existing failure `__tests__/helpers/transformers.test.ts › transformAgreement builds the agreement payload using today payment info` (timezone) | 109 suites / 734 tests, **the same single failure** (accepted exception, never counted green) |
| eslint `src/` | 0 errors / 756 warnings | 0 errors / **760 warnings** (+4: `react/no-danger` on the `<noscript>` PNG in `PassCredential.tsx` — deliberate; `complexity` on `format.ts` `displayMessage`-adjacent arrow, `services/shortTermPass.ts` `getPassView`, and the slice's `absorbOfferUnavailable`; the repo's `complexity`/`max-lines` rules already warn on every step component) |

## Deviations from the plan (with reasons)

| Deviation | Reason |
|---|---|
| Links open with `rel="noopener noreferrer"` (plan: `rel="noopener"`) | the repo's `react/jsx-no-target-blank` lint rule is an **error** without `noreferrer`; `noreferrer` implies `noopener`, the link is same-origin so no referrer is lost. Tests assert `rel` *contains* `noopener`. |
| `not-attempted` done-page sentence = "Just say your name at the front desk." (plan: "desk sentence") | v4 has no text for a pass that was never emailed; the v4 second sentence ("Show it at the door…") presumes a QR was sent. Pinned in `PassBlock.test.tsx` / `copy.test.ts`; DESIGN row PC-1. |
| Resend toasts: "Pass email sent to {masked}" / "Sending your pass email to {masked}" / "We couldn't send the pass email to {masked}" | plan says only "toast follows the returned `delivery.status`"; no v4 text exists. Pinned in `format.test.ts`, `DoneStep.test.tsx`. |
| "Resend pass email" is offered whenever a resend is possible (issued pass, delivery attempted), not only on `failed` | plan §6: "appears on `failed` (and as a secondary action otherwise)"; hidden for `not-attempted` because there is no address to resend to. The BFF's 3/hour limiter surfaces as the contract 429 copy with the countdown. |
| Pass-page copy beyond the two pinned sentences: h1 "Your pass" + club name; not-found help "Your receipt is in your email; the front desk can look you up by name."; receipt rows "Receipt number", "Paid"; fine print "Receipt emailed to {masked}. No membership. No recurring billing."; status pills "Upcoming" / "Valid today" / "Expired" | no design (PC-1); the pinned strings from the plan ("This link isn't valid.", the expired sentence, "Show this at the door, or just say your name at the front desk.", "Get the {Brand} app", "Door QR code") are used verbatim. |
| `expired` is rendered as the credential **without QR** plus the expired alert (not a bare message) | U18 requires dates to stay visible during grace and U21 lists an "Expired" pill; both hold. |
| A token that fails the contract regex (`PASS_TOKEN_PATTERN`) renders not-found **without a request** | saves a public-route request per junk path; the copy is the identical 404 sentence, so the outcome equals the server's. Any well-formed token is always fetched. |
| `PassViewPage` takes `token` as a prop from `App.tsx` (`matchPath` result) rather than `useParams` | `App.tsx` already matches the path; no `<Route>` context needed, and the page is testable without a router. |
| `CheckoutShell` gained `sidebarLabel` and `withToast` props | the checkout `Toast` reads Redux; the pass page has no store (U20). Defaults keep the checkout unchanged (`CheckoutShell.test.tsx` green). |
| Optimistic `validUntil` is recomputed in the browser while a `PUT /order` date edit is in flight (`format.validUntilOf`) | otherwise the help would flash "Wed, Sep 16 – Fri, Sep 11" until the server answers; the server's `validUntil` always replaces it. The browser still never computes price. |
| Offer and order writes are serialized through one module-level chain (`selectOffer` behind previous offer writes; `updateOrder` waits for pending offer writes) rather than a store queue | matches plan §1 "UI serializes offer/order writes"; `updateOrder` keeps its existing out-of-order protection and the Sprint 0002 tests untouched. |
| `GET …/pass-link` failures (404 no credential, 409) never set `state.error` | the done page must ship with the CTA hidden and no alert (plan C4 "shippable with the CTA hidden"); `passLink: 'failed'` stops retries. |
| `checkout.offers` falls back to `[checkout.offer]` when a response has no `offers[]` | tolerates a v2 BFF during the stacked-PR window; `selectedOfferSelector` still resolves. |
| `checkoutInfo` fixture gained `offers: [offer]`; new `coreCheckoutInfo` fixture | `CheckoutInfo.offers` is required in the slice; test data is this lane's. |

## Contract questions for the BFF lane

1. **`GET /checkouts/:id/purchases/:pid/pass-link` after reload.** The UI calls it from the done page once per purchase when `pass.viewPath` is missing (`passLink: 'idle'`), including after `POST /checkouts` resumed a `complete` snapshot. Please confirm the owner check (`loadOwnedPurchase(allowVerifiedMember)`) passes for a **resumed** checkout in state `complete` whose session cookie was rotated at verify — the UI has no other way to show the link after a refresh (U12).
2. **`POST …/pass-link` with `delivery.status:'failed'`.** The UI adopts whatever `viewPath` the response carries (contract: the **old** one) and keeps the old delivery masked address; it does not re-fetch. Confirm the failed response also carries `linkExpiresAt` (typed as required in `PassLinkRotateResponse`).
3. **`PUT /offer` in state `verified` (lookup retry pending).** The UI keeps the cards enabled while `step === 'identify' && !order`, which includes the `verified` / `lookupRetryable` case the contract lists as accepted. Confirm `retryLookup` reads `selectedOfferId` inside the committing mutation exactly like verify (plan races "offer vs retryLookup").
4. **`generation` on `PUT /offer`.** The UI sends `state.generation ?? 0`; after bootstrap `generation` is always set from `snapshot.generation ?? response.generation`. A 409 `STALE_GENERATION` rolls the card back and the page re-bootstraps (existing P1-4 handling) — confirm the offer route bumps `generation` on commit so the **next** `PUT /order` from the same tab is not refused as stale (the UI takes `generation` from the `OfferResponse`).
5. **404 body shape on `GET /passes/:token`.** The UI maps **any** 404 to not-found and every other status to the generic error with retry; a 429 is therefore shown as generic + "Try again" (no countdown, since `Retry-After` copy is not part of the public page). Fine by the plan; flagging in case the BFF expects the 429 copy to reach the visitor.
6. **`PassView.club.links`.** Typed as `{app?}` only; the shell therefore shows the four tabs as static labels and the brand as text on the pass page. If the BFF ever adds `website` there, the UI will not link it until `toClubSummary` is extended.
7. **`OrderSummary.label` / `PurchaseReceiptSummary.item`.** The receipt sidebar prefers `purchase.receipt.item` ("3-day pass · Gym Floor") when present and otherwise builds it from `order.label` + `order.offerName` with the Riverside "1-day pass" collapse. Confirm the snapshot `item` for Riverside is exactly "1-day pass" (the UI factory `makeReceipt` pins it so).

## Notes for the orchestrator (E2 smoke)

- "View your pass" opens in a **new tab** (`target="_blank"`): puppeteer should read `href` from `[data-testid="view-pass"]` (or `[data-testid="receipt-view-pass"] a`) and open it in a fresh context rather than waiting for a popup.
- The page QR is a client-rendered **SVG** (`qrcode.react`), not a PNG; to prove the payload, `curl …/api/short-term-pass/passes/<token>/qr.png` and decode with `jsqr` (as the BFF tests do), and assert the page shows `[data-testid="pass-qr"] svg` for `upcoming` / `active` and none for `expired`.
- `window.featureFlags` is not consulted on the pass page; the `?club=` query is ignored; no cookie is sent (`credentials: 'omit'`).
