# QA findings — agent3-newvisitor-pay (New Visitor step, payment, terms gate, Done page)

## 1. Environment and what I ran
- Desktop Chrome (playwright-core, channel chrome, headless), viewport 1440x900; one run of the terms modal at 1440x500 to check modal scrolling.
- Entry http://localhost:3000/signup/day-pass?club=90030, BFF mock mode (adapters + capture), shared in-memory state.
- Personas used (all unknown contacts, my allocation only): qa3-1, qa3-2, qa3-3, qa3-4, qa3-5, qa3-6, qa3-7, qa3-9, qa3-10, qa3-11, qa3-12, qa3-13, qa3-14, qa3-15, qa3-16, qa3-17, qa3-18 @newvisitor.test; phones 555-030-0001, -0002, -0003, -0004, -0019.
- Scripts: $S/qa/agent3-newvisitor-pay/{lib.mjs,t1_validation.mjs,t1b_phonefirst.mjs,t2_done.mjs,t2b_names.mjs,t3_cards.mjs,t4_terms_edit.mjs,t5_reload_retry.mjs,t6_reload_min.mjs}. Raw outputs: t2.out, t2b.out, t3.out, t4.out in the same dir.
- Screenshots: $S/qa/shots/agent3-newvisitor-pay/*.png (numbered 01–50, referenced below).
- Every run collected console errors/warnings, pageerrors and all /api responses (status, Idempotency-Key header, POST body). Source read before testing: NewVisitorStep, DoneStep, PayBar, MockCardCapture, SaveCardToggle, TermsDialog, CardCaptureSlot, OrderSummary, PassBlock, usePayAction, useShortTermPassCapture, shortTermPassSlice, selectors/shortTermPass, services/shortTermPass; BFF purchase.ts, idempotency.ts, purchaseOrchestrator.ts, schemas.ts, mock payment.ts / payPageSession.ts.
- Two findings are API-level (marked as such): H (CSRF/terms gate probe) and the GET-list 405 note.

## 2. Findings table
| ID | Sev | Title | Repro |
|---|---|---|---|
| A3-01 | P1 | Reload on the New Visitor step leaves Pay permanently disabled (and hides "Paying with") until the visitor does Edit → Continue | 4/4 (2 email, 2 phone) |
| A3-02 | P1 | Declined purchase (FAILED) shows a "Receipt … Paid with Visa •• 0002 … Paid $18.00 … Receipt emailed to …" sidebar although nothing was charged or sent | 2/2 |
| A3-03 | P2 | Names containing `<` or `>` or longer than 60 chars pass the UI and are rejected by the BFF with a raw technical message shown to the visitor: `Invalid request: profile.firstName must match pattern "^[^\r\n<>]{1,60}$"` | 2/2 |
| A3-04 | P2 | "Try again" after a decline wipes first/last name (and the optional contact) so the visitor must retype before choosing another card | 2/2 |
| A3-05 | P2 | Inline form error (#formErr) is stale: it stays on screen after the visitor fixes the field or changes card, until Pay is pressed again; invalid field gets no aria-invalid and keeps no focus (focus remains on Pay) | 3/3 |
| A3-06 | P3 | With nothing filled, Pay is disabled and no hint tells the visitor what is missing (no "first" error ever appears because the button cannot be pressed) | 3/3 |
| A3-07 | P3 / Q | Editing the contact (#editContact) silently resets a chosen visit date back to today; no toast | 2/2 |
| A3-08 | Q | "Start again" leaves the identify field empty although shortTermPassSlice's comment says the contact hint is prefilled; brief says "resets everything" — confirm intent | 2/2 |
| A3-09 | Q | "Authorization timeout" test card (visa-0003) completes as a normal successful purchase in mock mode (the mock resolves `unknown` → `authorized`); no UI path exercises the RECONCILING screen from the browser | 1/1 |
| A3-10 | P3 | Second-contact error copy is channel-of-field based, so entering an email into the "Mobile number" field (or the primary email itself) says "That mobile number doesn't look right." — acceptable but a duplicate-of-primary is not called out | 2/2 |

## 3. Detailed findings

### A3-01 — P1 — Reload on New Visitor step leaves Pay permanently disabled
- Viewport: 1440x900.
- Steps:
  1. Open entry URL, enter `qa3-18@newvisitor.test` (also `555-030-0019`, `qa3-12@…`, `qa3-14@…`), Continue → "Welcome — a few details".
  2. Press browser reload (F5). Page rehydrates to the same step (cookie).
  3. Fill First `Re`, Last `Load`, choose Test card "Visa •••• 4242 (approved)" (help text becomes "Visa •••• 4242 ready."), tick "I agree to the Terms & conditions".
- Expected: Pay enabled ("Pay is enabled by readiness" — PayBar.tsx doc comment; brief: "Reload mid-flow should rehydrate from the OJ-PASS-SESSION cookie"). The sidebar should show "Paying with Visa •• 4242".
- Actual: `#pay` stays disabled; sidebar shows no "Paying with" row even though the card slot says ready. Same after reloading during "Processing…" (t5 D1) and after reloading a FAILED (declined) done page (t5 F) — both rehydrate to New Visitor and the visitor is stuck. Doing Edit → Continue (re-identify) recovers (Pay enables).
- Evidence: shots 50-reload-newvisitor-qa318newvisitortest.png, 50-reload-newvisitor-5550300019.png, 40-d1-after-reload.png, 44-failed-reload.png; t6 output `pay disabled true` ×2 then `after Edit+Continue: pay disabled false`. No console errors, all API 2xx.
- Suspected cause: `applySnapshot` in online-join-ui/src/reducers/shortTermPass/shortTermPassSlice.ts (case `'newVisitor'`) only sets `step`; it never sets `state.paymentChoice = { useSaved: false }`. Initial state is `paymentChoice: { useSaved: true }`, so after a reload `paymentReadySelector` (selectors/shortTermPass.ts) returns `!!selectionRef` → false, and `payingWithSelector` ignores the captured card. `identifyContact.fulfilled` does set `useSaved:false`, which is why the live path works. Fix: mirror that in `applySnapshot` for the newVisitor snapshot (and reset `capture`).

### A3-02 — P1 — FAILED purchase page presents a paid receipt
- Steps: `qa3-4@newvisitor.test` (repeat `qa3-14@…`), names `Card`/`Tester`, card "Visa •••• 0002 (declined)", terms, Pay.
- Expected: honest failure. DoneStep.tsx says FAILED results "are shown honestly"; the sidebar should not claim payment or a receipt (prd demo: receipt/“Paid” only after a completed purchase).
- Actual (URL /signup/pass): main column alert "We couldn’t complete your purchase / Your card was declined." with buttons "Try again", "Start again" (correct). Sidebar reads: `Receipt · 1-day pass $18.00 · Valid Today · Thu, Sep 10 · Paid with Visa •• 0002 · Paid $18.00 · Receipt emailed to q••••@newvisitor.test.` Nothing was charged (BFF payment.status = declined) and no receipt/pass was sent (delivery not-attempted).
- Evidence: shot 20-declined.png; POST /purchases → 201 with state FAILED; no console errors.
- Suspected cause: online-join-ui/src/routes/ShortTermPass/components/OrderSummary.tsx uses `done = step === 'complete'` and `finePrintReceipt(...)` whenever `purchase` exists, without checking `purchase.state === 'COMPLETE'`; `payingWithSelector` also uses `purchase.payment.brand/last4` for declined payments. The "Paid" total line and "Paid with" row should be suppressed (or read "Not charged") for FAILED/RECONCILING.

### A3-03 — P2 — HTML-like and >60-char names: raw regex error surfaced to the visitor
- Steps: `qa3-9@newvisitor.test`; First `<b>x</b>`, Last `<img src=x onerror=alert(1)>`, Visa 4242, terms, Pay. Then First = 200×`A`, Last `Long`, Pay.
- Expected: either the UI blocks/limits the input (maxlength 60, strip `<>`) or a human message; VALIDATION_MESSAGES in purchaseOrchestrator.ts only covers name-empty ("Please add your first and last name.").
- Actual: POST /purchases → 400 VALIDATION_FAILED, and #formErr shows `Invalid request: profile.firstName must match pattern "^[^\r\n<>]{1,60}$"` both times. Inputs have no `maxlength`. The visitor can correct and pay (D'Artagnan-Émile / Van der Berg-O'Neil then succeeded → "You’re in, D'Artagnan-Émile").
- Evidence: shots 16-html-name.png, 17-long-name.png, 18-dartagnan-done.png; network `400 {"code":"VALIDATION_FAILED","message":"Invalid request: profile.firstName must match pattern ...","details":{"field":"profile.firstName"}}`; console `Failed to load resource: 400`.
- Cause: BFF schemas.ts `NAME_PATTERN = '^[^\\r\\n<>]{1,60}$'` + `validateBody` message passthrough (schemas.ts:388); UI NewVisitorStep.tsx has no length/character guard and shows any VALIDATION_FAILED message verbatim (`shownError`).
- Positive: rendering is safe — `You’re in, José 😀`, `Anne-Marie`, `O'Brien` rendered as text; React escapes; no markup injected (welcome innerHTML checked). No raw card numbers anywhere in requests/responses (regex scan of all POST bodies; only fixture keys `mock-visa-4242-…` and last4).

### A3-04 — P2 — "Try again" after decline loses typed names
- Steps: after A3-02, click "Try again".
- Expected: back on the New Visitor step with the visitor's data preserved so they can "pick another card and pay again without starting over" (slice comment on `retryAfterFailure`: "the visitor may correct and retry from the step they were on").
- Actual: First/Last/optional contact empty; card cleared (by design, `capture` reset); terms still ticked; date kept. Pay disabled until names are retyped. After retyping and choosing Visa 4242, purchase succeeded with a NEW Idempotency-Key (correct) → "You’re in, Card", pill "Visa •••• 4242 saved to your wallet".
- Evidence: shot 21-after-try-again.png, 22-retry-success.png; POSTs: `201 idem=oj_d609… card=visa-0002` then `201 idem=oj_b624… card=visa-4242`.
- Cause: names live in NewVisitorStep `useState`; DoneStep unmounts it. Keep the profile in the slice (or in the BFF order) so retry restores it.

### A3-05 — P2 — Stale inline error and no field-level a11y
- Steps: `qa3-1@…`, names `Test`/`User`, Visa 4242, terms; Second contact `12345`, Pay → "That mobile number doesn't look right." Then clear the field / change card to expired.
- Actual: message stays visible after the field is fixed (until next Pay press); focus remains on `#pay`; `#second` has no `aria-invalid`, `#formErr` is a role=alert div not linked to the field. Expected-copy check passed: email-first → "That mobile number doesn't look right."; phone-first (555-030-0001) `not-an-email` → "That email doesn't look right."
- Evidence: shots 03-second-invalid-phone.png, 04-expired-card.png (error still visible with the expired card chosen), 05-phone-first-second-invalid.png.
- Cause: NewVisitorStep.tsx `formError` state only set in `onPay`; no onChange clearing; DtField `error` prop unused.

### A3-06 — P3 — Empty form gives no guidance
- With nothing filled Pay is disabled (good: no purchase request even with a forced click) but there is no message about what is missing; whitespace-only names also keep Pay disabled silently (trim). Focus on arrival is `#first` (good). Design question whether an always-enabled Pay that surfaces the first error (name → card → contact per `onPay` order) was intended; today the order-of-errors logic in `onPay` is unreachable for names/card because `canPay` already gates them.
- Evidence: shot 01-newvisitor-initial.png, 02-whitespace-names.png.

### A3-07 — P3/Q — Edit resets the chosen date
- Steps: `qa3-10@…`, set Pick a day to 2026-09-12 (PUT /order 200 visitDate), click Edit (#editContact) → identify with `qa3-10@newvisitor.test` prefilled (good), day shows 2026-09-10; Continue → New Visitor, day still 2026-09-10 (order recreated with today), no toast.
- Evidence: shot 32-after-edit.png, 33-reentered.png; `DELETE /identity 200` then `POST /identify 200`.
- Cause: BFF `resetIdentity` revokes the order; UI `resetToIdentify` sets `order = undefined` without a `pendingVisitDate`.

### A3-08 — Q — Start again does not prefill the contact
- After a completed purchase, "Start again" → `DELETE /checkouts/:id 200`, `POST /checkouts 201`; identify field is empty, date reset to today, sidebar back to "Order summary / Total". Everything resets (matches the brief), but `startAgain.fulfilled` sets `contact.hint` from `contactHint`, and the slice comment says "with the contact hint prefilled" — the BFF revoke apparently returns no hint. Confirm which is intended.
- Evidence: shots 13-start-again.png, 15-start-again-b.png.

### A3-09 — Q — visa-0003 "authorization timeout" ends COMPLETE
- `qa3-5@…`, Visa 0003 → 201 COMPLETE, "You’re in, Card", pill "Visa •••• 0003 saved to your wallet", no warning. Per adapters/mock/payment.ts the mock answers `unknown` once and `authorized` on status(), so the UI RECONCILING branch ("We’re confirming your payment") is not reachable from a browser test card. Suggest a fixture that stays `unknown` so demo/QA can see that screen.
- Evidence: shot 23-timeout.png.

### A3-10 — P3 — Duplicate-of-primary second contact
- Email-first, Second = `qa3-1@newvisitor.test` (same as primary) → "That mobile number doesn't look right." (correct by field type, but not explanatory). Phone-first, Second = `5550300001` → "That email doesn't look right." No request sent (good).

## 4. What passed
- Pay label `Pay $18.00 and get my pass` equals sidebar Total `$18.00`; after purchase sidebar "Paid $18.00", "Paid with Visa •• 4242" matches the pill last4.
- Phone-first vs email-first second field: "Email · optional / you@email.com / …different number next time" vs "Mobile number · optional / (555) 555-0123 / …different email next time"; header "Mobile (555) 030-0001 Edit" / "Email qa3-1@… Edit".
- Test cards: visa-4242 and mastercard-4444 approve; visa-0002 → alert "We couldn’t complete your purchase / Your card was declined." with Try again + Start again (retryable true); visa-1111-expired → "That card can't be used. Choose another test card." and Pay stays disabled, no "Paying with" row.
- Terms gate: Pay disabled with names+card until terms ticked; unticking re-disables (PUT /order `{"terms":{"accepted":false}}`). Checkbox → `method:"checkbox"`, modal "Agree and close" → checkbox ticked, `method:"modal"`. Escape, backdrop click, "Close", and × all close WITHOUT accepting; focus trap cycles ×/Close/Agree (MUI Dialog), focus restored to the Terms link on close; `aria-labelledby=stp-terms-title`; body scrolls inside the modal at 500px viewport with Agree still visible.
- Save-card toggle: on → "✓ Visa •••• 4242 saved to your wallet" + "Next time — here, in the app, or at the desk — you’ll just verify your email and pay."; off → PUT `{"saveCard":false}`, done page "You chose not to save a card. Next time you’ll enter it again.", no pill, fine print omits "card stays on file".
- Double-click Pay: exactly one POST /purchases; inputs, card select, toggle, terms, date disabled while "Processing…" (Edit link and name inputs stay enabled — minor).
- Network failure on POST /purchases (route abort): alert "Something went wrong. Please try again.", form intact, second Pay reuses the SAME `Idempotency-Key` (oj_d57b… twice) → one charge, done page OK.
- Reload with the purchase response in flight (server processed it): rehydrates straight to the done page via `GET /purchases/:pid` (shot 41). Reload on the done page: pass, QR, pill re-render (shot 11). Browser Back from done page leaves the site (history.replace; no re-entry into the flow, no second charge).
- Done page: "You’re in, <first>" for Anne-Marie / O'Brien / José 😀 / D'Artagnan-Émile; QR SVG present with non-empty payload (path length ≈3.6k); "1-day pass · Today · Thu, Sep 10" and "1-day pass · Sun, Sep 13" for a future date; delivery "We emailed it to q••••@newvisitor.test too." / "We texted it to (555) •••-0003 too." matching channel and masked contact; "Get the Riverside app" href https://example.com/riverside-app, target=_blank, rel="noopener noreferrer", opens a new tab with `window.opener === null`; "Start again" resets date/identify/sidebar.
- Edit (#editContact) returns to identify with the contact prefilled; re-Continue gives a clean New Visitor form.
- No raw PAN in any UI text or network traffic; only fixture keys and last4. Only 4xx seen: the expected 400 (A3-03), and my API-level probes (403 CSRF_REJECTED when POSTing /purchases without X-STP-CSRF with terms unaccepted — good; 405 on GET /checkouts/:id/purchases list). Console: only Redux dev middleware timing warnings and the resource-load lines for those 4xx.

## 5. Not tested / blocked
- RECONCILING done page and wallet "failed-retryable"/"unavailable" copy: not reachable from a browser test card (A3-09); fault switches are process-internal.
- Real Pay Page hosted capture (paypage mode): BFF runs STP_CAPTURE_MODE=mock.
- Actual email/SMS delivery content: mock delivery only reports status.
- Mobile viewports and returning-visitor (recognized) step: other agents' slices.
- API-level terms-gate 409 with a valid CSRF token: not attempted (would need to lift the token out of module state); the 403 CSRF result already shows the raw POST is refused.
