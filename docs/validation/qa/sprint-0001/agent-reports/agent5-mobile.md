# agent5-mobile — Responsive / mobile QA of the Day Pass flow

Scratchpad root: `$S` = /private/tmp/claude-502/-Users-bjornloftis-claudeprojects-prospects-ui/069fdd27-8017-422c-ba01-40725c36dc93/scratchpad
Scripts: `$S/qa/agent5-mobile/run.mjs` (13 viewports, full flow), `cause.mjs` (root-cause proof at 360), `demo.mjs` (Riverside demo at 6 widths). Raw data: `$S/qa/agent5-mobile/merged.json`, `demo-results.json`. Screenshots: `$S/qa/shots/agent5-mobile/vNN-WxH-{1-identify,2-newvisitor-filled,3-terms-modal,4-processing,5-done,6-verify}.png`, `demo-WxH-{1-identify,2-newvisitor}.png`, `cause-360-page-minmax-fix.png`.

## 1. Environment and what I ran

- Target: http://localhost:3000/signup/day-pass?club=90030 (BFF mock mode), headless Google Chrome via playwright-core, mobile emulation (`isMobile:true, hasTouch:true`, mobile UA, listed DPR). Playwright device descriptors used where they exist (iPhone 13, iPhone 15, iPhone 15 Pro Max, iPhone 12 Mini, iPhone 11, iPhone SE, Pixel 7); custom contexts for the rest. Page `<meta name=viewport>` is `width=device-width, initial-scale=1.0`.
- Viewports (CSS px, portrait unless noted): 1) 390x844@3 2) 393x852@3 3) 430x932@3 4) 375x812@3 5) 414x896@2 6) 375x667@2 7) 412x915@2.625 8) 360x800@3 9) 402x874@3 10) 440x956@3; extras 11) 360x740@3, 12) 844x390@3 landscape, 13) 320x568@2 pathological.
- Flow per viewport (real UI, tap events): identify -> new visitor (Qa / Mobile<n> / phone 55501955<nn>, test card visa-4242) -> date changed to today+3 via the native date input -> Terms modal opened, "Agree and close" -> Pay -> done (/signup/pass) -> "Start again" -> same contact re-identified (now known) -> verify screen -> "Start over". Checks run programmatically on every screen (overflow walk, header clipping, summary position, tap-target rects, inputmode/autocomplete, fonts < 12px, fixed/sticky elements, inputs < 16px).
- "Processing…" was caught by delaying `POST …/purchases` 1.5 s with `page.route` (does not alter the request); caught 12/12 where enabled.
- Personas: qa5-1 … qa5-13@mobile.test (one per viewport) plus qa5-14@mobile.test for the root-cause run. No fixture personas touched. qa5-1 was run twice (smoke run + full run; the second run correctly went to verify because qa5-1 was already known, so data for v1 comes from the smoke run).
- Console: no page errors. Every viewport logs `console.error: Warning: findDOMNode is deprecated in StrictMode … Transition` (MUI Dialog under React StrictMode, dev only) and Redux `SerializableStateInvariantMiddleware/ImmutableStateInvariantMiddleware took >32ms` warnings (dev only). No 4xx/5xx responses anywhere.

## 2. Findings table

| ID | Sev | Title | Viewports |
|---|---|---|---|
| A5-01 | P1 | New-visitor step forces horizontal overflow (document 393 px wide) on every phone narrower than 393 px; 33 px on 360 (most common Android), 73 px on 320 | 320, 360x800, 360x740, 375x812, 375x667, 390 (3 px) |
| A5-02 | P2 | Header overflows the viewport by 84 px in landscape / 641–~930 px widths ("Secure checkout" pushed off-screen, whole page shrinks) | 844x390; inferred for iPad-portrait widths 768–834 |
| A5-03 | P2 | iOS zoom-on-focus: every text input, the test-card select and the date input are 14 px (#ident, #first, #last, #second, #mockCard, #day) | all iPhone viewports |
| A5-04 | P2 (synthetic) | Long unbreakable email in the new-visitor header (`Email <b>…</b> Edit`) widens the document (467 px at 360) — no `overflow-wrap` | 360 (DOM-tampered text) |
| A5-05 | P2 | Tap targets under 44 px: text links 17 px tall (#resend, #startover, #switchCh, #editContact, Terms link), #termsCb 16x16 (label 21 px tall), #day 36 px tall, OTP boxes 40x48 at 360 and 33x48 at 320 | all |
| A5-06 | P3 | Header renders as three rows (123 px) at widths ≤ 402: "Secure checkout" wraps under the brand instead of sharing row 1 as the SCSS comment intends | 320–402 |
| A5-07 | P3 / Q | Nav row scrolls at ≤ 360 with "Visit" clipped and no affordance; demo hides nav entirely below 700 px | 360, 320 |
| A5-08 | P3 | ~56 px of dead space above "Order summary" inside the summary card on mobile (demo has none) | all |
| A5-09 | P3 | Verify links wrap leaving an orphan "·" separator at end of line | 375–402, 320 |
| A5-10 | P3 | Done page overflows 5 px at 320 (main widget 309 px in a 288 px column) | 320 only |
| A5-11 | P3 | "Pick a day" label wraps to two lines at 320 | 320 only |
| A5-12 | Q | Order summary (with the date picker) sits below the Pay button on every phone and is not sticky; a user can pay without ever seeing "Pick a day". Matches demo ordering, but worth a design call | all portrait |
| A5-13 | P3 | `findDOMNode is deprecated in StrictMode` console.error from the Terms dialog on every load (dev StrictMode) | all |
| A5-14 | Q | Deviations from the Riverside demo at phone widths: nav shown vs hidden; controls 40 px tall vs 45 px; first/last name stacked (≤ 520) vs two columns; brand allowed to wrap to two lines in the demo | 320–430 |

## 3. Detailed findings

### A5-01 — P1 — New-visitor step widens the document to 393 px (horizontal overflow on phones < 393 px)
- Viewports: 320x568 (doc 394, +74), 360x800 and 360x740 (doc 393, +33), 375x812 and 375x667 (doc 393, +18), 390x844 (doc 393, +3). Not present at ≥ 393. Identify, verify and done screens at the same widths are fine (except A5-10 at 320).
- Steps: 1) open entry URL at 360x800 mobile emulation 2) enter `qa5-8@mobile.test`, Continue 3) land on "Welcome — a few details" (nothing else needed; the overflow exists before any input).
- Expected: `.dt-header` comment in src/styles/short-term-pass.scss ("Nothing may push the document wider than the viewport") and the demo (`prospect-wallet-demo-1` stays at 360/360, see demo-360x800-2-newvisitor.png).
- Actual: `document.scrollingElement.scrollWidth` 393 > 360; `window.innerWidth` grows to 393 because mobile Chrome shrinks the layout viewport to fit; `main#main` measures 377 px wide in a 328 px grid column and both `main` and `aside` overflow (`right: 393`). Visually the header stays 360 wide and the two cards hang past the right edge (v08-360x800-2-newvisitor-filled.png; v13-320x568-2-newvisitor-filled.png where the effect is dramatic).
- Root cause (proven with cause.mjs at 360, persona qa5-14): `select#mockCard` has an intrinsic min-content width of 240 px + paddings (card-slot 12+12, widget 24+24) = 377 px, and the mobile grid `.page { grid-template-columns: 1fr }` (short-term-pass.scss, `@media (max-width: 960px)` block) uses `1fr` = `minmax(auto, 1fr)`, so the column grows to the child's min-content. Desktop uses `minmax(0, 1fr) 424px` and is not affected. Injecting either `.mock-capture select { width:100%; min-width:0 }` or `@media (max-width:960px){ .page { grid-template-columns: minmax(0,1fr) } }` brings the page back to 360/360 (baseline `{"iw":393,"sw":393,"main":377}` -> `{"iw":360,"sw":360,"main":328}`; screenshot cause-360-page-minmax-fix.png).
- Caveat: `MockCardCapture` only renders in mock capture mode; production shows the Pay Page iframe (CardCaptureSlot). The grid weakness is production code though, so any wide child (iframe with a fixed width, long email — see A5-04) will reproduce it. Recommend `minmax(0, 1fr)` on the mobile grid plus `min-width: 0` on the widgets.
- Evidence: v08-360x800-2-newvisitor-filled.png, v11-360x740-2-newvisitor-filled.png, v04/v06 375 shots, v13-320x568-2-newvisitor-filled.png; merged.json `steps.newVisitor.checks` (`layoutGrew:true`, `overflowers`).
- Repro: 7/7 (six viewport runs + cause run).

### A5-02 — P2 — Header overflows in landscape / mid widths (641–~930 px)
- Viewport: 844x390 landscape (v12), every screen.
- Steps: open the entry URL at 844x390.
- Expected: header fits; the demo at 844x390 stays 844/844.
- Actual: `scrollWidth` 928 vs 844 on all five screens; `span.end.secure` right edge at 928 (entirely off-screen), the header background ends at 844 and the page shrinks (v12-844x390-1-identify.png, -2-newvisitor-filled.png, -3-terms-modal.png). Header content = brand 210 + gap 40 + `.dt-tabs` (padding 0 48px + 4 tabs + gaps) ~563 + gap 40 + secure 147 > 844; `flex-wrap` only applies ≤ 640.
- Suspected cause: `.dt-header { gap: var(--ig-s10) }`, `.dt-tabs { padding: 0 48px }`, `.secure { white-space: nowrap }` with the wrap breakpoint at 640 in short-term-pass.scss. Widths between 641 and ~930 are affected, which includes iPad portrait (768/820/834 — not run, inferred from the arithmetic).
- Repro: 1 viewport, 5/5 screens.

### A5-03 — P2 — Inputs under 16 px trigger iOS Safari zoom on focus
- Viewports: all iPhone viewports (1–6, 9, 10, 12, 13).
- Measured computed font-size: #ident 14, #first 14, #last 14, #second 14, select#mockCard 14, #day 14 (`.dt-input { font-size: var(--ig-text-sm) }`, `.mock-capture select { font: inherit }`). OTP boxes are 20 px (fine). Buttons 16 px (fine).
- Expected: ≥ 16 px on focusable text controls on iOS, or accept the zoom. Note the demo has the same weakness (14.5 px inputs, 12.5 px date), so this is inherited from the prototype rather than a regression; still flagged because a zoom on #ident is the very first interaction.
- Evidence: merged.json `checks.inputsUnder16` per screen. Emulated Chrome cannot reproduce the zoom itself; this is a static check.
- Repro: 13/13.

### A5-04 — P2 (synthetic, layout-only DOM tamper) — Long email in the new-visitor header is unbreakable
- Viewport: 360x800, with the A5-01 grid fix injected so the measurement isolates this element.
- Steps: on the new-visitor step, set the header `<b>` text to `a.very.long.email.address.for.overflow@subdomain.example-company.com` via page.evaluate.
- Actual: document width 467 px (`b` right edge 467 in a 328 px column). Without the grid fix the same text would also push the grid column wider (A5-01 mechanism).
- Suspected cause: NewVisitorStep.tsx renders `Email <b>{contact.display}</b> Edit` inside `.dt-widget-header p` with no `overflow-wrap: anywhere` / `word-break`. Real emails of ~40 characters (common corporate addresses) exceed 328 px at 14 px bold.
- Repro: 1/1 (synthetic).

### A5-05 — P2 — Tap targets below 44x44 CSS px
Measured (identical across viewports unless noted):
- Text links (`.dt-link`, 14 px, no padding): #resend 126.5x17, #startover 65.6x17, #switchCh 106x17, #editContact 25.4x17, "Terms & conditions" 128.3x17 — 17 px tall, 27 px below Apple HIG 44 / Material 48. P2.
- #termsCb 16x16; its `<label>` is 329x21 so the effective target is 21 px tall. P2 (the terms gate is mandatory).
- #day (date input) 170x36 (`.dayrow .dt-input { height: var(--ig-control-sm) }`). P3.
- OTP boxes: 48.3x48 (≥ 412), 47x48 (402), 45x48 (390), 42.5x48 (375), 40x48 (360), 33.3x48 (320). P3 at 360, P2 at 320 (v13-320x568-6-verify.png).
- Primary controls: #continue 103x40, #pay 248x40, #verifyBtn 79.5x40, #again 117x40, #getApp 198x40, all inputs 40 tall, select 40 tall — the 40 px Ignite token; P3 only.
- `.toggle .switch` is 40x23 but the whole `label.toggle` (329x85) is clickable — pass.
- Evidence: merged.json `steps.*.m`.

### A5-06 — P3 — Header is three rows tall (123 px) at ≤ 402 px
- Viewports 1, 2, 4, 6, 8, 9, 11, 13 (all ≤ 402). At 412–440 the header is 97 px (two rows).
- Expected: SCSS comment at the 640 breakpoint: "brand + 'Secure checkout' on the first row, the nav on its own scrollable row below."
- Actual: `.dt-brand` (flex-basis auto = 210 px incl. logo) + 16 gap + `.secure` 147 = 373 > available (viewport − 32), so the flex line wraps before the brand shrinks (`flex: 1 1 auto` + `min-width: 0` only shrink after wrapping decisions). `.secure` lands on row 2 (top 44) and the nav on row 3. Screenshots v01…v09 -1-identify.png.
- Fix idea: `flex-basis: 0` / `min-width:0; flex: 1 1 0` on `.dt-brand` or allow the name to ellipsize (it already has `text-overflow: ellipsis`).

### A5-07 — P3 / Q — Nav row clipped at ≤ 360 with no scroll affordance
- 360: `.dt-tabs` scrollWidth 335 vs clientWidth 328 — "Visit" is cut at its last few px (v08-360x800-1-identify.png). 320: 335 vs 288 — "Visit" is fully hidden (v13-320x568-6-verify.png shows Classes / Memberships / Day pass only). `overflow-x: auto` with no fade or indicator.
- The demo hides `.links` at ≤ 700 px entirely (demo-390x844-*.png). Q: should the phone shell show the nav at all? If yes, add an overflow fade or reduce tab gap/padding at ≤ 360.

### A5-08 — P3 — Dead space above "Order summary" on mobile
- All viewports, all screens: the summary card starts with ~56 px of white space before the "Order summary" title (widget padding 24 + `.dt-widget-content { margin-top: var(--ig-s8) }` on the OrderSummary root). On desktop this aligns with the main widget's header; stacked on mobile it reads as a rendering gap. Demo has the title flush at the top of the side panel.
- Evidence: any -1-identify.png; demo-390x844-1-identify.png for comparison.

### A5-09 — P3 — Verify links wrap with an orphan separator
- 375–402: "Resend code (30s) · Text me instead ·" / "Start over" (v01-390x844-6-verify.png). 320: "Resend code (30s) ·" / "Text me instead · Start over". Separators are standalone `<span>·</span>` in `.row-links` with `flex-wrap: wrap` (VerifyStep.tsx), so they can be the last item on a line. At 440 everything fits on one line. Fix: attach the dot to the following link (`::before`) or hide separators on wrap.

### A5-10 — P3 — Done page overflows by 5 px at 320
- 320x568 only: `main#main` 309 px in a 288 px column, scrollWidth 325. Likely the `.pill-ok` inline-flex (284 px wide, "✓ Visa •••• 4242 saved to your wallet") or the `.pass` block (96 px QR + text) exceeding min-content. Same `1fr` mechanism as A5-01.

### A5-11 — P3 — "Pick a day" label wraps to two lines at 320 (v13-320x568-6-verify.png). Pathological width only.

### A5-12 — Q — Summary/date picker below the Pay button on phones
- On every portrait viewport the order summary (`aside`) is stacked below `main` (aside top 938 vs Pay button top 858 at 390) and is `position: relative` (not sticky). The Pay button and terms checkbox are reachable without horizontal scroll (once A5-01 is fixed), but "Pick a day" is only visible after scrolling past Pay. This mirrors the demo (side panel below main at ≤ 860), so not a defect against the requirement, but a first-time phone user may buy a pass for today while intending another day. Consider surfacing the day picker (or a compact "Today · $18.00 · change" line) above the Pay bar on mobile.

### A5-13 — P3 — Console error on every load
- `[console.error] Warning: findDOMNode is deprecated in StrictMode. findDOMNode was passed an instance of Transition …` — MUI v4 Dialog (TermsDialog.tsx) under React StrictMode. Dev only, but it is a red console line on every page load. Also Redux invariant-middleware timing warnings (dev only). No `pageerror`, no non-2xx responses in any run.

### A5-14 — Q — Layout deviations from the Riverside demo at phone widths (demo.mjs, same viewports)
- Demo hides the site nav ≤ 700 px; UI shows a nav row (A5-07).
- Demo brand text wraps to two lines and keeps "SECURE CHECKOUT" on row 1; UI keeps the brand on one line and drops "Secure checkout" to row 2 (A5-06).
- Demo controls are 45 px tall (inputs 14.5 px text, buttons 14.5 px); UI controls are 40 px (14 px inputs, 16 px buttons).
- Demo keeps First/Last name in two columns at 390 (134 px each); UI stacks them at ≤ 520 (`.grid2` breakpoint). UI is arguably better here.
- Demo has no top gap in the summary panel (A5-08).
- Demo date input is 12.5 px text, 32 px tall; UI 14 px, 36 px tall — both below the iOS zoom threshold (A5-03).
- Done page: both stack "Get the Riverside app" (secondary) above "Start again" (primary) at ≤ 402 and put them side by side from 412 — pass.

## 4. What passed

- Full purchase flow completed on 13/13 viewports; URL moved to /signup/pass on done; heading "✓ You're in, Qa"; pass block "1-day pass · Sun, Sep 13" reflecting the changed date.
- No horizontal overflow on identify, verify and done screens at 360–440 (only the new-visitor step, A5-01; 320 done, A5-10; landscape header, A5-02).
- Club name "Riverside Athletic Club" never clipped/ellipsized (scrollWidth == clientWidth at every width, even 320). Nav labels not truncated inside their own boxes.
- Order summary stacks below the form on every portrait viewport and in landscape (single column ≤ 960); no sticky/fixed element covers content — the only fixed element is the toast (`pointer-events: none`, hidden when idle). Toast briefly covers the fine print for 1.8 s at the bottom of the viewport (acceptable).
- Pay button (`#pay`, left 40 / right 288) and terms checkbox fully inside the viewport on every width; Pay disabled until terms accepted, enabled after "Agree and close" (13/13); "Processing…" label shown with the button disabled and the date input disabled while submitting (v02-393x852-4-processing.png).
- Terms modal: fits inside the viewport on all 13 (paper ≤ viewport, `max-height: 85vh`), body scrolls internally when needed (375x667, 360x740, 320x568, landscape), "Agree and close" and "Close" inside the viewport and 40 px tall on all; body `overflow: hidden` while open and wheel-scrolling behind moved 0 px (13/13); focus trap/portal carries `.short-term-pass` tokens (styled correctly).
- Date input: native `type=date` (appearance auto), min = club-local today `2026-09-10`, initial value = today; `fill('2026-09-13')` accepted, value read back `2026-09-13`, toast "Day pass for Sun, Sep 13", summary and done page reflect the day. 
- inputmode/autocomplete: #ident `inputmode=email autocomplete=username type=text` (matches the demo; note `inputmode=email` still gives a keyboard with digits on iOS/Android so phone entry works); OTP digit 1 `autocomplete=one-time-code inputmode=numeric`, digits 2–6 `autocomplete=off inputmode=numeric`; #second `inputmode=tel autocomplete=tel` when the primary contact is an email (label "Mobile number · optional").
- No text under 12 px on any screen (smallest is 12 px `--ig-text-xs`).
- QR block 96x96 (SVG 80x80) on every width; done page buttons stack at ≤ 402 and sit side by side ≥ 412, no overflow.
- Landscape 844x390: aside stacks below main; modal fits (600x332) with internal scroll.

## 5. Not tested / blocked

- Real iOS Safari behaviour (zoom-on-focus, native date sheet, rubber-band scroll behind the modal) — only Chromium mobile emulation is available; A5-03 is a static font-size check.
- Tablet widths 641–960 other than the 844 landscape sample (A5-02 impact on iPad portrait is inferred from the header arithmetic, not measured).
- Recognized/returning path on mobile (agent4's slice); only the verify screen of a now-known contact was checked here.
- Production Pay Page iframe sizing inside CardCaptureSlot (mock capture mode only) — A5-01's trigger element differs in production, the grid weakness does not.
- Long real-world emails were only tested by DOM tampering (A5-04) to stay inside the qa5-<n>@mobile.test allocation.

## 6. Per-viewport matrix

Legend: ✓ pass, ✗ fail, ~ minor. Columns: OV-id/nv/done/ver = horizontal overflow on identify / new visitor / done / verify; Hdr = header rows (2 intended); Nav = nav fully visible; Modal = fits + Agree reachable + scroll-locked; Pay = pay/terms reachable; Date = value applied + toast; OTP = OTP box ≥ 44 wide; Links = link tap height ≥ 44; Zoom = no inputs < 16 px (iPhone only); Font = no text < 12 px; Stack = done buttons (S stacked / R row).

| # | Viewport | OV-id | OV-nv | OV-done | OV-ver | Hdr | Nav | Modal | Pay | Date | OTP | Links | Zoom | Font | Stack | Issues |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | 320x568@2 | ✓ | ✗ +74 | ✗ +5 | ✓ | ✗ 3 rows | ✗ Visit hidden | ✓ | ✓ | ✓ | ✗ 33 | ✗ 17 | ✗ | ✓ | S | 8 |
| 8 | 360x800@3 | ✓ | ✗ +33 | ✓ | ✓ | ✗ 3 rows | ✗ clipped | ✓ | ✓ | ✓ | ~ 40 | ✗ 17 | n/a | ✓ | S | 5 |
| 11 | 360x740@3 | ✓ | ✗ +33 | ✓ | ✓ | ✗ 3 rows | ✗ clipped | ✓ | ✓ | ✓ | ~ 40 | ✗ 17 | n/a | ✓ | S | 5 |
| 4 | 375x812@3 | ✓ | ✗ +18 | ✓ | ✓ | ✗ 3 rows | ✓ | ✓ | ✓ | ✓ | ~ 42.5 | ✗ 17 | ✗ | ✓ | S | 5 |
| 6 | 375x667@2 | ✓ | ✗ +18 | ✓ | ✓ | ✗ 3 rows | ✓ | ✓ (body scrolls) | ✓ | ✓ | ~ 42.5 | ✗ 17 | ✗ | ✓ | S | 5 |
| 12 | 844x390@3 land. | ✗ +84 | ✗ +84 | ✗ +84 | ✗ +84 | ✓ 1 row (overflowing) | ✓ | ✓ (body scrolls) | ✓ | ✓ | ✓ | ✗ 17 | ✗ | ✓ | R | 4 |
| 1 | 390x844@3 | ✓ | ✗ +3 | ✓ | ✓ | ✗ 3 rows | ✓ | ✓ | ✓ | ✓ | ✓ 45 | ✗ 17 | ✗ | ✓ | S | 4 |
| 2 | 393x852@3 | ✓ | ✓ | ✓ | ✓ | ✗ 3 rows | ✓ | ✓ | ✓ | ✓ | ✓ 45.5 | ✗ 17 | ✗ | ✓ | S | 3 |
| 9 | 402x874@3 | ✓ | ✓ | ✓ | ✓ | ✗ 3 rows | ✓ | ✓ | ✓ | ✓ | ✓ 47 | ✗ 17 | ✗ | ✓ | S | 3 |
| 7 | 412x915@2.625 | ✓ | ✓ | ✓ | ✓ | ✓ 2 rows | ✓ | ✓ | ✓ | ✓ | ✓ 48 | ✗ 17 | n/a | ✓ | R | 1 |
| 5 | 414x896@2 | ✓ | ✓ | ✓ | ✓ | ✓ 2 rows | ✓ | ✓ | ✓ | ✓ | ✓ 48 | ✗ 17 | ✗ | ✓ | R | 2 |
| 3 | 430x932@3 | ✓ | ✓ | ✓ | ✓ | ✓ 2 rows | ✓ | ✓ | ✓ | ✓ | ✓ 48 | ✗ 17 | ✗ | ✓ | R | 2 |
| 10 | 440x956@3 | ✓ | ✓ | ✓ | ✓ | ✓ 2 rows | ✓ | ✓ | ✓ | ✓ | ✓ 48 | ✗ 17 | ✗ | ✓ | R | 2 |

Cross-cutting on all rows: A5-08 summary dead space, A5-12 summary below Pay, A5-13 console error (not counted in "Issues").

Ranking (worst first): 320x568 > 360x800 = 360x740 > 375x812 = 375x667 > 844x390 landscape > 390x844 > 393x852 = 402x874 > 414/430/440 > 412x915 (cleanest: Android, so no zoom risk, two-row header, no overflow).
