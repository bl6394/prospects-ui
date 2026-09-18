# QA report — agent4-returning (returning-visitor path)

Paths below: `S` = `/private/tmp/claude-502/-Users-bjornloftis-claudeprojects-prospects-ui/069fdd27-8017-422c-ba01-40725c36dc93/scratchpad`; shots in `S/qa/shots/agent4-returning/`; per-run logs (all API requests, non-2xx, console) in `S/qa/agent4-returning/*.log`; scripts `lib.mjs`, `j1.mjs`, `persona.mjs` in the same dir.
UI repo: `/Users/bjornloftis/claudeprojects/prospects-ui/repos/online-join-ui`, BFF repo: `/Users/bjornloftis/claudeprojects/prospects-ui/repos/online-join-bff`.

## 1. Environment and what I ran

- Entry `http://localhost:3000/signup/day-pass?club=90030`, BFF mock mode, Chrome headless via playwright-core. Club-local today from the BFF = `2026-09-10` (a Thursday, so "Today · Thu, Sep 10" is correct; the task text's "Wed, Sep 10" was a guess).
- Viewports: desktop 1440x900 for everything; `devices['iPhone 12']` (390x844, DPR 3, touch) for one Jordan happy path.
- Flow driven through the real UI only (no API-level probing). Code always `123456`.
- Runs (code sends per contact, all within the 5/15 min cap):
  - Jordan `jordan.reyes@email.com` — 4 sends: J1a (aborted by my own test-script bug after recognized; no purchase), J1 desktop full run (saved card, date change, reload, double-Pay, done, reload, Back, Start again), J2 (aborted by a script issue before Pay: the save-card `<input>` is visually hidden — not a product bug), J3 iPhone 12 happy path.
  - Casey `casey@example.com` (member) — 1 run, saved Mastercard 4444 → done.
  - Riley `riley@example.com` — 2 runs: (1) no card → new Visa 4242, save on → done; (2) now has a saved card → "Use a different card" → Mastercard 4444, save OFF → done.
  - Dana `dana@example.com` — 2 runs: (1) expired card → new Visa 4242 → done; (2) peek only: recognized step to see whether the newly saved card appears.
  - Morgan `morgan@example.com` — 2 runs: (1) saved Visa 0002 declines → Try again → different card 4242 → done; (2) decline → Try again → same card declines again → Start again.
- Console: only Redux-toolkit dev middleware timing warnings (`SerializableStateInvariantMiddleware took NNms`) on every run; no page errors. Network: zero 4xx/5xx across all 11 runs.

## 2. Findings table

| ID | Sev | Title | Viewport | Repro |
|---|---|---|---|---|
| A4-01 | P1 | Declined purchase shows a "Receipt … Paid $18.00 … Paid with Visa •• 0002 … Receipt emailed to …" sidebar next to the "We couldn't complete your purchase" alert; URL moves to `/signup/pass` | 1440x900 | 3/3 |
| A4-02 | P2 | Terms checkbox (and Pay enablement) only toggles after the `PUT /order` round trip — 480–835 ms lag on localhost, no optimistic update | 1440x900, iPhone 12 | 11/11 |
| A4-03 | Q | Paying with an already-saved card shows "✓ Visa •••• 4242 saved to your wallet" and the receipt says "Your card stays on file" — copy implies a new save (prototype-faithful) | both | 4/4 |
| A4-04 | P3 | Card label inconsistency on one screen: chip/pill "Visa •••• 4242", sidebar "Visa •• 4242"; prototype uses "Visa ••4242" (no space) | both | 11/11 |
| A4-05 | Q | Dana's expired card is silently hidden; copy reads "No card on file yet. Enter a new card below." with no hint that her card on file expired | 1440x900 | 1/1 |
| A4-06 | P3 | After a decline, "Try again" returns to recognized with the declined card still pre-selected, Pay enabled and no decline message; one click re-declines with the same card | 1440x900 | 2/2 |
| A4-07 | Q | Visitor who already has a saved card pays with a new card, save OFF: done page says "You chose not to save a card. Next time you'll enter it again." and the receipt drops "Your card stays on file" — but a card does stay on file | 1440x900 | 1/1 |
| A4-08 | Q | Browser Back from the done page leaves the site (about:blank); every step uses `history.replace`, so there is no in-app Back | 1440x900 | 1/1 |
| A4-09 | P3 | iPhone 12: the Order summary / Receipt card has ~100 px of empty space above its heading | iPhone 12 | 2/2 |
| A4-10 | P3 (env) | Five simultaneous cold page loads: identify step did not render within 15 s (bundle from webpack dev server); sequential/2-at-a-time loads were fine | 1440x900 | 5/5 then 0/9 |

## 3. Detailed findings

### A4-01 — P1 — FAILED purchase rendered with a "Receipt / Paid" sidebar
- Viewport: 1440x900 (Morgan runs 1 and 2; the second decline in run 2 reproduced it a third time).
- Steps: 1) Enter `morgan@example.com`, Continue. 2) Enter `123456`, Verify. 3) On recognized, tick "I agree to the Terms & conditions". 4) Click "Pay $18.00 and get my pass" with the pre-selected saved Visa •••• 0002.
- Expected: the failure is shown honestly everywhere. `DoneStep.tsx:42` handles `purchase.state === 'FAILED'` honestly in the main panel ("driven only by confirmed result fields"), and the requirement (addendum row "Fine print", demo-2) defines the receipt variant only for a completed purchase. The sidebar should stay "Order summary / Pick a day / Total", or show a neutral failed state — never "Paid".
- Actual (exact sidebar text): `Receipt` / `1-day pass $18.00` / `Valid Today · Thu, Sep 10` / `Paid with Visa •• 0002` / `Paid $18.00` / `Receipt emailed to m•••••@example.com.` — while the main panel says `We couldn't complete your purchase` / `Your card was declined.` with `Try again` and `Start again`. The date picker is gone (replaced by the read-only "Valid" row). The URL is `/signup/pass?club=90030` for a failed purchase.
- Evidence: `S/qa/shots/agent4-returning/morgan-decline-desktop-04-after-pay.png`, `morgan2-decline-twice-04-after-pay.png`, `morgan2-decline-twice-05-second-decline.png`; logs `morgan-decline-desktop.log`, `morgan2-decline-twice.log` (both `POST …/purchases` 2xx — the BFF reports FAILED in a 2xx body, as designed).
- Repro: 3/3.
- Suspected cause: `src/routes/ShortTermPass/components/OrderSummary.tsx:41` `const done = step === 'complete'` and `:63` `if (done && purchase)` key everything (title, "Paid with", "Paid", "Valid" row, receipt fine print) off the step, not `purchase.state === 'COMPLETE'`. The slice sets `step = 'complete'` for any purchase result including FAILED (`shortTermPassSlice.ts` ~588), and `ShortTermPassPage.tsx:89` redirects to the done URL on `step === 'complete'`. Fix is a `purchase.state === 'COMPLETE'` guard in OrderSummary (and probably in the redirect).

### A4-02 — P2 — Terms checkbox is server-round-trip controlled, no optimistic state
- Viewport: both.
- Steps: on recognized, click the "I agree to the Terms & conditions" checkbox; observe when it becomes checked and when Pay enables.
- Expected: immediate visual feedback on click (standard checkbox behavior); the server write may follow.
- Actual: the box stays unchecked until `PUT /order` returns. Measured click→checked: 515, 700, 835 ms (J1: check, uncheck, re-check), 634 (Casey), 667 (Riley), 720 (Dana), 479/677 (Morgan), 672 (J2), 485 (J3), 588 (Dana 2), 652 (Riley 2) — all on localhost with a mock BFF. My first automated `check()` failed with "Clicking the checkbox did not change its state" because of this. On a real network the lag will be longer, and quick double clicks race (three PUTs in flight; last response wins client-side).
- Evidence: `S/qa/agent4-returning/j1-jordan-desktop.log` lines "accept terms -> {ok:true, ms:515}" etc.
- Repro: 11/11.
- Suspected cause: `shortTermPassSlice.ts:542-548` — `updateOrder.pending` only clears `error`; `state.order` (which `PayBar.tsx` reads as `accepted = !!order?.terms.accepted`) is replaced only in `updateOrder.fulfilled`. Same pattern affects the save-card toggle (`SaveCardToggle.tsx`) and the date input value.

### A4-03 — Q — "saved to your wallet" when paying with an already-saved card
- Viewport: both (Jordan J1, J3; Casey; Dana run 2 would too).
- Steps: Jordan → verify → recognized with saved Visa 4242 → terms → Pay.
- Expected: unclear. Prototype demo-2 shows the pill in this case (`${brand} •••• ${last4} saved to your wallet` whenever `saved`), so the implementation matches the prototype. But the card was already on file; "saved to your wallet" reads as a new save, and the receipt adds "Your card stays on file at Riverside — not on this website." (that part is accurate).
- Actual: `✓ Visa •••• 4242 saved to your wallet` / `Next time — here, in the app, or at the desk — you'll just verify your email and pay.`; receipt fine print `Receipt emailed to j•••••@email.com. Your card stays on file at Riverside — not on this website.`
- Evidence: `j1-jordan-desktop-08-done.png`, `j3-jordan-iphone12-04-after-pay.png`, `casey-member-desktop-04-after-pay.png`.
- Suspected cause (BFF): `src/services/shortTermPass/purchaseOrchestrator.ts:322-324` sets `result.wallet = { status: 'saved', brand, last4 }` for `source.kind === 'saved'`. Consider a distinct status (e.g. `on-file`) and copy such as "Paid with your saved Visa •••• 4242".

### A4-04 — P3 — "Paying with" dot count differs from the chip and pill
- Actual: chip `Visa •••• 4242`, `#useSaved` link `Use Visa •••• 4242 instead`, done pill `Visa •••• 4242`, but sidebar `Paying with Visa •• 4242` / `Paid with Visa •• 4242`. Prototype demo-2 renders `${brand} ••${last4}` (two dots, no space) in the sidebar, so the implementation is neither the chip format nor the prototype format.
- Evidence: any `*-02-recognized.png`, `j1-jordan-desktop-08-done.png`.
- Suspected cause: `OrderSummary.tsx:106` `cardLabel(payingWith.brand, payingWith.last4, '••')`.

### A4-05 — Q — Expired card on file is invisible to Dana
- Steps: `dana@example.com` → `123456` → recognized.
- Actual: Payment section `No card on file yet. Enter a new card below.` + test-card slot + save toggle (default on). No chip, no `#useSaved`, no mention of the expired Visa •••• 1111. Pay with Visa 4242 succeeds; done shows `✓ Visa •••• 4242 saved to your wallet`. Run 2 (peek): the new card now appears as `Visa •••• 4242 / Saved online`; the expired card is still hidden — filtering is consistent.
- Expected: the BFF deliberately hides non-usable entries (`online-join-bff/src/services/shortTermPass/wallet.ts:9-15 isUsableEntry`: `INACTIVE` or expired), which is safe. Whether the visitor should be told "Your card on file has expired — enter a new one" is a design question; "No card on file yet" is technically untrue for Dana.
- Evidence: `dana-expired-desktop-02-recognized.png`, `dana2-peek-02-recognized.png`.

### A4-06 — P3 — Try again after a decline keeps the declining card selected
- Steps: Morgan → Pay with saved Visa 0002 → FAILED → click `Try again`.
- Actual: URL back to `/signup/day-pass`, recognized step with `Visa •••• 0002 / Saved online ✓` still selected, terms still accepted, Pay enabled, no alert or hint about the decline (`.dt-alert` count 0). Clicking Pay again immediately re-declines (run 2: 2 `POST /purchases`, both declined, no duplicate charge; a fresh idempotency key is minted because `retryAfterFailure` clears `purchaseKey`). "Use a different card" → Visa 4242 → Pay works (run 1) and the done page is correct.
- Expected: the addendum/prototype do not specify; UX would benefit from keeping the decline message visible on the recognized step or defaulting to the new-card slot.
- Evidence: `morgan-decline-desktop-05-after-try-again.png`, `morgan-decline-desktop-06-retry-done.png`, `morgan2-decline-twice-05-second-decline.png`.
- Suspected cause: `shortTermPassSlice.ts:358-364 retryAfterFailure` resets purchase/error/capture but not `paymentChoice`.

### A4-07 — Q — "You chose not to save a card. Next time you'll enter it again." when a card is already on file
- Steps: Riley run 2 (Riley now has Visa 4242 saved from run 1) → `Use a different card` → Mastercard 4444 → toggle save OFF (`label.toggle` click; input flips to unchecked after the PUT) → Pay.
- Actual: done page has no pill, help text `You chose not to save a card. Next time you'll enter it again.`; receipt fine print `Receipt emailed to r••••@example.com.` (no "stays on file" clause). Sidebar `Paid with Mastercard •• 4444`. Correct for the *new* card, but Riley's Visa 4242 remains on file, so "Next time you'll enter it again" is wrong for her.
- Evidence: `riley2-nocard-nosave-03-newcard.png`, `riley2-nocard-nosave-04-after-pay.png`.
- Cause: `DoneStep.tsx` `purchase.wallet.status === 'not-requested'` branch; the result does not carry "other cards on file".

### A4-08 — Q — Back button from done exits the site
- Steps: J1: land on done → `page.goBack()`.
- Actual: navigates to `about:blank` (the entry before the app). `goForward()` returns to `/signup/pass` and rehydrates the done page correctly.
- Cause: `ShortTermPassPage.tsx:89,91` use `history.replace`; no step pushes history. Intended (URL "stays at /signup/day-pass until complete"), so a design question only: users expecting Back to revisit the pass will lose the page unless they use Forward.

### A4-09 — P3 — Mobile sidebar card has large empty top padding
- iPhone 12: the "Order summary"/"Receipt" card starts ~100 px below its top edge (looks like desktop sticky/top-offset carried into the stacked layout). Evidence: `j3-jordan-iphone12-02-recognized.png`, `j3-jordan-iphone12-04-after-pay.png`. Otherwise the mobile layout is fine (no horizontal scroll, chip/links/buttons well sized).

### A4-10 — P3 (environment) — Concurrent cold loads stall the identify step
- Five headless Chromes loading the entry URL at once: `POST /api/short-term-pass/checkouts` fired in each, but `#ident` was not visible within 15 s in any (screenshot at ERR shows the page eventually rendered fine). Re-running sequentially / two at a time succeeded every time. Almost certainly webpack-dev-server bundle serving under load, not the product; noted because it consumed no code sends and because the other agents may hit it.

## 4. What passed

- Identify → verify: `Check your email` / `We sent a 6-digit code to <masked>.` Masking matches `contact.ts maskEmail` (first char + 3–5 dots + domain): `j•••••@email.com`, `c••••@example.com`, `r••••@example.com`, `d•••@example.com`, `m•••••@example.com`. `Test mode — your code is 123456.` shown. `Resend code (30s)` countdown present.
- Verify-step channel switch availability: `Text me instead` (`#switchCh`) present for Jordan, Casey, Riley, Morgan (phone on file); absent for Dana (no phone). `Start over` always present.
- Recognized banner `✓ Welcome back, <first>` for all five. Your info: typed channel in clear, other masked — e.g. `Email jordan.reyes@email.com`, `Mobile (555) •••-2231`; Dana shows only Name + Email (no Mobile row).
- Jordan/Casey/Morgan saved-card chip with brand/last4 and source (`Saved in the app last week`, `Saved at the front desk`, `Saved online`) plus `Use a different card`; save-card toggle NOT rendered while paying with the saved card; sidebar `Paying with` present.
- `#diffCard` → `Enter a new card. Use Visa •••• 4242 instead` + `#mockCard` slot + save toggle (default on); `Paying with` row disappears until a test card is picked, then tracks the new card (`Mastercard •• 4444`); `#useSaved` restores the chip, removes slot/toggle, `Paying with` back to `Visa •• 4242`, Pay stays enabled.
- Riley (no card): `No card on file yet. Enter a new card below.`, slot, toggle on, no `#useSaved`, `Paying with` appears after pick; done shows `✓ Visa •••• 4242 saved to your wallet`; the card persists to the next visit (run 2 chip `Visa •••• 4242 / Saved online`).
- Casey (member): identical behavior to a prospect — recognized, saved Mastercard, purchase COMPLETE, done page. Consistent with the sprint decision "existing member → proceed as member"; there is no member-specific copy (nothing in the requirements asks for any).
- Fine print on recognized: `Valid Today · Thu, Sep 10. Your card stays on file at Riverside — not on this website.`; after date change `Valid Fri, Sep 11. …`. Pay label `Pay $18.00 and get my pass`, disabled until terms; unchecking terms disables it again.
- Date change on recognized: `#day` min `2026-09-10`, no max; picking `2026-09-11` shows toast `Day pass for Fri, Sep 11`, `PUT /order`, and the done page reads `1-day pass · Fri, Sep 11`, receipt `Valid Fri, Sep 11`.
- Reload on recognized: rehydrates to recognized (`POST /checkouts` + `GET /wallet`), chip, terms checked, chosen date, Pay enabled all restored.
- Double Pay: two synchronous `#pay` clicks + a forced third → exactly 1 `POST /purchases`; button shows `Processing…`/disabled during submit.
- Done (Jordan): `✓ You're in, Jordan`, pass block with QR, `1-day pass · Fri, Sep 11`, `Show this at the front desk, or just say your name. We emailed it to j•••••@email.com too.`, `Get the Riverside app` + `Start again`; receipt sidebar `Paid with`, `Paid $18.00`, `Receipt emailed to j•••••@email.com. Your card stays on file at Riverside — not on this website.` Reload on done rehydrates (`GET /purchases/<id>`) with identical content. `Start again` → `DELETE /checkouts/<id>`, new checkout, identify step with empty input and the initial fine print. Start again from FAILED also works.
- Decline copy: `We couldn't complete your purchase` / `Your card was declined.` with `Try again` (retryable) and `Start again`; Try again lets the visitor pick a different card and complete.
- iPhone 12 Jordan happy path: all of the above copy identical; no console errors; layout stacks main card over summary.
- No 4xx/5xx in any run; no `pageerror`.

## 5. Not tested / blocked

- Jordan's phone `5550192231` and the phone-typed "Your info" variant — owned by another agent.
- Jordan "Use a different card" all the way to done with save ON (J2 aborted by my script clicking the hidden `#saveCard` input; budget kept for J3). Covered functionally by Riley run 2 (save OFF) and Riley run 1 (new card, save ON).
- Terms modal "Agree" path on recognized (only the checkbox path exercised); wallet-unavailable / wallet-failure faults; Visa 0003 authorization-timeout from the recognized step; reload while on the FAILED page; session expiry on recognized/done; resend and wrong-code paths (other agent).
- Time cap (~35 min) reached after the runs above.
