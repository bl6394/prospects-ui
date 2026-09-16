# Validation — short-term pass UI (Sprint 0001, E3/E4)

**Repo:** `repos/online-join-ui`, branch `prospect-wallet/sprint-0001`. **Executor:** Claude Fable 5.1, 2026-09-09/10.
**Commands:** `npm run lint` (`eslint src/ --ext .ts,.tsx`) · `npm run build` (`cross-env NODE_ENV=production webpack`) · `npx jest` (coverage on by default).

## Numbers (after Phase D)

| Check | Result |
|---|---|
| `npm run lint` | 0 errors (warnings only: pre-existing style warnings plus `complexity` / `react/no-array-index-key` in the new steps) |
| `npm run build` | webpack 5.105.0 compiled with 3 warnings (bundle-size recommendations, pre-existing) |
| `npx jest` | 100 suites: 99 passed, 1 failed (pre-existing, unrelated: `__tests__/helpers/transformers.test.ts` "transformAgreement builds the agreement payload using today payment info" — month label depends on the machine timezone); 578 tests: 577 passed, 1 failed |
| Coverage (all files) | **92.97 % statements · 82.18 % branches · 87.55 % functions · 92.97 % lines** against floors 80/80 lines/statements; thresholds untouched |
| `tsc --noEmit` | only the 25 pre-existing errors in PaymentPage / PayPageEmbed tests; none in the new code |

## Existing-flow regressions (E3)

- `__tests__/App/App.test.tsx`: `/day-pass`, `/day-pass/`, `/day-pass/anything`, `/pass`, `/pass/` render the pass shell; `/day-passes` does not; existing routes still run the signup initialization.
- `__tests__/routes/ShortTermPass/isolation.test.ts`: every `--ig-*` token and `.dt-*` rule sits under `.short-term-pass`; `Header`, `Footer`, `GuestPage`, `SignupShell`, `App.scss`, `index.scss` carry none.
- All existing route, component, reducer, hook and service suites pass unchanged (PlanPage, ProfilePage, DetailsPage, PaymentPage incl. `PayPageEmbed` and `usePayPageSession`, ReviewPage, GuestPage, GuestReviewPage).
- HTTP smoke through the restarted dev BFF (2026-09-10): see `docs/demos/short-term-pass-local-demo.md` "Browser demo".

## New-page proof (D12)

| Area | Test |
|---|---|
| Identify copy, placeholder, help → error, focus, ambiguous state, Enter submits | `__tests__/routes/ShortTermPass/IdentifyStep.test.tsx` |
| Verify titles by channel, masked contact, six inputs (auto-advance, backspace, paste), Verify gate, resend countdown, switch link only when on file, lock, Start over with hint | `VerifyStep.test.tsx` |
| Welcome banner, Your info masking per typed channel, saved card chip and source, Use a different card ↔ Use … instead, wallet unavailable (Retry) vs empty, saved and hosted purchases with idempotency key | `RecognizedStep.test.tsx` |
| New-visitor title, contact + Edit, channel-specific second contact, the three validation messages, purchase with profile | `NewVisitorStep.test.tsx` |
| Done banner, QR from `qrPayload`, "1-day pass · Today · Wed, Sep 9", delivery sentence by status, saved pill + next-time copy, not-saved copy, wallet retry only when verified, FAILED / RECONCILING, Get the app, Start again | `DoneStep.test.tsx` |
| Sidebar: no skeleton or button, line item, Pick a day defaulting to today with min, toast copy, Paying with / Paid with, three fine-print variants, Receipt mode, no card-on-file claim when not saved | `OrderSummary.test.tsx` |
| Terms gate: Pay disabled until accepted, checkbox and modal each recorded with method, opening is not acceptance, withdrawal, Processing… | `PayBar.test.tsx` |
| Page: flag off / no club / iframe / BFF 404 → unavailable or top-level link; bootstrap; rehydrate recognized; complete snapshot loads the purchase and moves to `/pass`; `/pass` without a completed checkout returns to `/day-pass` | `ShortTermPassPage.test.tsx` |
| Slice, selectors (`canPay` table, payment readiness incl. hosted form readiness), service client (routes, CSRF interceptor, error normalization), format helpers | `__tests__/reducers/shortTermPass/*`, `__tests__/selectors/shortTermPass.test.ts`, `__tests__/services/shortTermPass.test.ts`, `format.test.ts` |
| PCI static guard: no PAN / CVC / expiry input or state in `src/routes/ShortTermPass/**`; hosted embed only through `PayPageEmbed`; no token read | `pci.test.ts` |

## Not performed by the executor

- Manual browser check of the new page and the existing signup route at 1440 and 375 px (no browser tooling in this session). Left for the design gate G2 / G7 with the dev servers running as described in the demo doc.
- Keyboard / screen-reader pass beyond the automated roles and labels.
- Real Pay Page hosted capture in the browser (BLOCKERS B1).

## Deviations from the demos recorded for G2

- Hosted card fields are the Pay Page iframe (or the mock capture select in mock mode), not the demo's inline inputs.
- Nav items are non-interactive labels unless the catalog supplies destinations (OQ-8); no location switcher.
- Fine print on the identify/verify steps uses the plan's U2 sentence ("No membership. No recurring billing. Change plan any time before you pay."); the new-visitor step uses "Defaults to today — pick another day…"; receipt fine print omits "Your card stays on file…" when the card was not saved (truthful copy).
- "Restart demo", the browser-chrome frame and the "Behind the scenes" panel are not implemented by decision.
- A hosted-form "ready" state before a token exists is represented by the mounted embed (Pay Page gives no onLoad callback through `PayPageEmbed`); `submit()` rejecting is reported as "Please complete the card details."

## Visual pass (orchestrator, 2026-09-10, headless Chrome via puppeteer-core against the local BFF on :3000)

Screenshots in `docs/validation/screenshots/sprint-0001/` (full-page, 1440×900 and 375×812 viewports). Driven end to end through the real router and mock adapters; the numbered files follow the flow.

| Shot | Screen | Result |
|---|---|---|
| 01 | Identify, 1440 and 375 | Matches the Riverside demo: heading, help line, one field, Continue; sidebar shows the line item, "Pick a day" defaulting to today, Total, fine print. **375: fixed** — the header previously overflowed the viewport (page scrolled horizontally, brand wrapped to three lines); it now wraps to brand + Secure checkout on the first row and a scrollable nav row. |
| 02 | Verify (own step) | "Check your email", masked address, six inputs, Resend with cooldown, "Text me instead", Start over, disabled Verify; mock code hint shown in mock mode only. |
| 03 | Recognized, 1440 and 375 | Welcome banner, Your info with masking per typed channel, saved card chip, Use a different card, terms checkbox, disabled Pay; sidebar adds Paying with and the "Valid …" fine print. |
| 04 | Terms modal | Close and Agree and close; Agree enables Pay. |
| 05 | Done (returning), 1440 and 375 | URL moved to `/signup/pass?club=90030`; QR pass block, saved-card pill, "Next time…" copy, Get the Riverside app, Start again; sidebar Receipt with Paid with / Paid. |
| 06–07 | New visitor, 1440 and 375 | Header with contact + Edit, names, optional second contact, mock test-card select, save toggle, terms checkbox, Pay. |
| 08 | Done (first visit) | "You're in, Alex", texted to the masked mobile, card saved pill. |
| 09 | Start again | Back on `/signup/day-pass`, identify screen with the last contact prefilled. |
| 10 | Identify error | Help line becomes the red error, field outlined. |
| 11 | Legacy signup `/signup/plan?club=09003` | Renders as before; the page contains 0 `dt-*` elements and `:root` carries no `--ig-*` variable (checked in-page). |

**Defect found and fixed during the pass:** on the new-visitor step the terms checkbox was disabled, so only the modal could accept terms and Pay stayed disabled. Cause: `PayBar` disabled the checkbox while the slice had no `order`, and the new-visitor identify response carried no order even though the BFF had created the order shell. Fix: the BFF returns `order` on the `newVisitor` outcome, the slice stores it, and the checkbox is disabled only while submitting. Route, slice and component tests updated.

**Not covered by this pass:** real Pay Page hosted fields (mock capture used; gate G4 still pending B1); design sign-off by a named owner (G2 evidence is now available for that review).

## Sprint 0003 — parity inputs re-baselined on Design v4 (D1, orchestrator, 2026-09-16; harness NOT run)

`tools/day-pass-harness/parity/elements.json` v2 and `approved-deltas.json` v2 now describe `docs/prd/day-passv4.html` (sha256 `c0a5fd8d3f511705145687037a3cc7a02a3163ad75d902a4282eefc391316616`). The parity loop and the agent runs stay **deferred by the user**; nothing under `tools/` was executed.

**Thirteen states × two widths (1440×1000, 375×900):**

| State | Prototype reaches it by | Build reaches it by | v4 lines |
|---|---|---|---|
| identify | load | `/signup/day-pass?club=90033` | 160–190, 451–466 |
| identify-offer-3day | click `#offer-d3` | click `#offer-day-pass-gym-floor-3` (toast masked) | 465, 735 |
| identify-offer-5day | click `#offer-d5` | click `#offer-day-pass-gym-floor-5` (toast masked) | 465, 735 |
| code-entry | enter `m@m.com`, Continue | same (cards stay selectable) | 192–214 |
| recognized | code 000000 | code from the hooks outbox | 520–560 |
| recognized-new-card | "Use a different card" | same (hosted frame masked, AD-04) | 540–560 |
| new-visitor | `parity-new-visitor@stp.test` | same | 480–518 |
| done-saved | pay with save on | same — **no `.qr`** | 585–592, 610 |
| done-not-saved | pay with save off | same | 585–592 |
| dialog-waiver / dialog-pass-terms / dialog-stored-card / dialog-privacy | open from the sidebar consent block | same | 360–398 |

**Selector coverage:** 105 elements; the 14 v4 additions (radiogroup, `.days`, per-card ids, `.lead`, View-your-pass rows) were completed against the UI lane's shipped selectors (`OfferCards`, `OfferCard`, `PassBlock`, `OrderSummary`); `done.qr` and the `qr-modules` mask were removed. Build-only elements (`done.view`, `side.row.view`) carry `buildOnly: true` and `proto: null`.

**Approved deltas:** AD-01…AD-10 re-cited against v4; AD-11 single-offer grid (Riverside), AD-12 "View your pass" link + Receipt row + "Resend pass email" (build-only; CR-13), AD-13 truthful delivery variants of the v4 sentence (`pending` / `failed` / `not-attempted`). AD-11…AD-13 are approved by the sprint plan and await DESIGN review (blocker PC-1).
