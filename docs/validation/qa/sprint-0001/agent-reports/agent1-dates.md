# QA report — agent1-dates: picking the visit date ("Pick a day", `#day`)

## 1. Environment + what I ran

- Date/time of run: Thu 2026-09-10, 10:57–11:30 PDT (17:57–18:30 UTC). Machine/browser time zone: **America/Los_Angeles (PDT, UTC-7)**. Club 90030/90033 are America/Chicago (CDT, UTC-5) → club-local today = browser today = **2026-09-10** for the whole run (Chicago was 12:57–13:30). Club 90032 America/New_York also 2026-09-10. Not near midnight, so the timezone-mismatch cases were produced with Playwright `timezoneId` emulation (Pacific/Auckland, where browser today was already **2026-09-11**) — see A1-01/A1-02. "Browser behind club" (e.g. a Californian at 22:00–24:00 PDT) could not be produced at this hour; it is analysed from source only (A1-02, second half).
- Browser: Google Chrome (channel `chrome`), headless, viewport 1440×900 desktop, playwright-core. Machine was heavily loaded by concurrent QA agents (load avg 7–10, ~90 Chrome processes); some steps took >30 s, which caused two of my own scripts to time out on selectors (reruns succeeded, no product flakiness observed).
- Entry URL: http://localhost:3000/signup/day-pass?club=90030 (also club=90032, club=90033). BFF mock mode, shared in-memory state.
- Personas used (all NEW visitors, no OTP sends except A1-T9): qa1-0, qa1-1, qa1-22, qa1-23, qa1-33, qa1-4, qa1-5, qa1-6a, qa1-6c, qa1-71, qa1-72 @dates.test. Full purchases completed: qa1-22 (2026-09-19; script crashed on a selector after the purchase POST succeeded, done page not captured), qa1-23 (Sat, Sep 19, R-000045), qa1-33 (Today · Thu, Sep 10, R-000047), qa1-6c (Core South, see §4). qa1-23 was re-identified afterwards (now a known contact with a saved card) to reach the recognized step — one OTP send on my own persona.
- Scripts: `$S/qa/agent1-dates/*.mjs` (lib.mjs shared; t0 explore, t1 values, t2 pending purchase, t3 processing/today purchase, t4 race, t5 API, t6 clubs, t7b timezone, t8 tz check, t9 recognized). Raw outputs `$S/qa/agent1-dates/out-*.txt`. Screenshots `$S/qa/shots/agent1-dates/`.
- Source read: UI `src/routes/ShortTermPass/components/OrderSummary.tsx`, `ShortTermPassPage.tsx`, `format.ts`, `components/Toast.tsx`, `steps/DoneStep.tsx`, `reducers/shortTermPass/shortTermPassSlice.ts`; BFF `src/services/shortTermPass/order.ts`, `src/routes/shortTermPass/order.ts`, `schemas.ts`, `fixtures/catalog.ts`.

## 2. Findings table

| ID | Sev | Title | Repro |
|---|---|---|---|
| A1-01 | P1 | Browser time zone ahead of club: "Day pass for **Today**" toast, but the order/pass is for club-**tomorrow** | 2/2 |
| A1-02 | P2 | Before identify the picker defaults to and is clamped by the *browser's* today, then silently jumps to club today after identify (no toast); club-today unpickable pre-identify when browser is ahead | 2/2 |
| A1-03 | P2 | Success toast "Day pass for Mon, Jan 1" fires for a date the server then rejects (400); error lands in the main form, not by the picker | 3/3 |
| A1-04 | P2 | Typing a year with the keyboard fires one PUT per keystroke with partial years (0002, 0020, 0202…) → 3–8 spurious 400s, red error flashes, stale error left behind | 2/2 |
| A1-05 | P2 | Out-of-order PUT /order responses: the visitor's *last* pick is lost, UI and server settle on the earlier date with no notice | 1/1 (deterministic with injected delay) |
| A1-06 | P3 | While "Processing…" on the new-visitor step the fine print flips to the recognized copy "Valid Today · Thu, Sep 10. Your card stays on file at Riverside…" — even though save-card may be off and the addendum says this variant is for recognized only | 1/1 |
| A1-07 | Q | No upper bound on the visit date: 9999-12-31 and +10 years accepted by UI and BFF (`maxDaysAhead` undefined for every fixture offer → no `max` attribute) | 3/3 |
| A1-08 | P3 | Toast/receipt labels omit the year: 2027-09-10 → "Fri, Sep 10", 9999-12-31 → "Fri, Dec 31", 2020-01-01 → "Wed, Jan 1" | 3/3 |
| A1-09 | Q | Identify-step fine print is "No membership. No recurring billing. Change plan any time before you pay." while the addendum table lists identify under "Defaults to today — pick another day…" | n/a |
| A1-10 | P3 | After a rejected date the form error "Pick a day from today onwards." persists until the *next successful* order update; clearing the field or typing garbage leaves it in place | 2/2 |
| A1-11 | P2 | Recognized step: a rejected date (400) shows **no error at all** — only the misleading success toast; input silently reverts | 1/1 |

## 3. Detailed findings

### A1-01 (P1) Browser ahead of club: toast says "Today", pass is for club-tomorrow
- Viewport: 1440×900 Chrome, context `timezoneId: 'Pacific/Auckland'` (browser date 2026-09-11 06:17 NZST; club 90030 date 2026-09-10).
- Steps: 1. Open /signup/day-pass?club=90030. 2. On identify, change `#day` to 2026-09-20 then back to 2026-09-11 (the browser's "today"; the UI already defaulted to it). 3. Observe toast. 4. Identify as qa1-72@dates.test → new-visitor step. 5. Observe `#day` and PUT /order.
- Expected: `format.ts` doc-comment: "`today` is the club-local date the BFF reported as `minVisitDate`, never the browser's clock". Addendum: "Defaults to club-local today". A toast that says "Today" must mean the club's today.
- Actual: toast **"Day pass for Today"** for 2026-09-11; after identify the pending date is applied: `PUT /order {"visitDate":"2026-09-11"} → 200 visitDate 2026-09-11`, sidebar shows 09/11/2026 (club's tomorrow), min 2026-09-10. Had the visitor paid, the pass would be for Fri Sep 11 although the UI called it "Today". (Contrast: after identify, picking 2026-09-10 correctly toasts "Day pass for Today".)
- Evidence: `out-t7b.txt` ("after picking browser-today: 2026-09-11 toast \"Day pass for Today\"", "PUTs: 200 {visitDate:2026-09-11} -> 2026-09-11"); shots `t7b-picktoday-picked-today.png`, `t7b-picktoday-newvisitor.png`; `t8-tzcheck.mjs` output confirms browser Date = Sep 11 while `#day` default/min = 2026-09-11.
- Suspected cause: `OrderSummary.tsx` `const today = order?.minVisitDate ?? browserToday()` — before the order shell exists `today` is the browser date, so `dayLabel(value, today, true)` says "Today" for the browser's date. The BFF never tells the client its club-local today until `/identify` returns the order. Fix idea: include `minVisitDate`/club today in `POST /checkouts` response (it already carries `club.timezone`), or compute club today client-side from `checkout.club.timezone` with Intl.

### A1-02 (P2) Pre-identify default/min use browser today; silent jump after identify
- Same emulated context as A1-01 (Pacific/Auckland).
- Steps: 1. Open the page. 2. Read `#day` value/min. 3. Identify as qa1-71@dates.test without touching the date. 4. Read `#day`.
- Expected: default = club-local today (2026-09-10) and `min` = club today, so the visitor can pick the club's today from the first screen; any change to the visible date should be announced (the toast is the only feedback channel for the date).
- Actual: identify step shows **09/11/2026** with `min=2026-09-11` (club today 09/10 is un-pickable via the picker). After identify the input silently becomes **09/10/2026**, `min=2026-09-10`; no toast, 0 PUTs. The visitor who saw "11" and continued now has an order for the 10th.
- Reverse case (analysis from source, not reproducible at this hour): a browser *behind* the club (e.g. Los Angeles 22:00–24:00 PDT, club Chicago already tomorrow): default shows club-yesterday, `min` allows it, toast would say "Today"; on identify `ShortTermPassPage.tsx` effect drops the pending date because `pendingVisitDate < order.minVisitDate` — again silently — and the order is club today. Only a picked date ≥ club today survives; a picked "today" (browser) that is club-yesterday is discarded with no message.
- Evidence: `out-t7b.txt` case 1; shots `t7b-nopick-identify.png` (09/11/2026), `t7b-nopick-newvisitor.png` (09/10/2026).
- Cause: `OrderSummary.tsx` `browserToday()` fallback for `today`/`min`; `ShortTermPassPage.tsx` pending-date effect has no user-visible feedback when it discards or when the default changes.

### A1-03 (P2) Confirmation toast for a rejected date; error placed in the main form
- Viewport 1440×900, club 90030, new-visitor step (qa1-1@dates.test).
- Steps: 1. Identify as new visitor. 2. `page.fill('#day','2028-02-29')` (accepted). 3. `page.fill('#day','1900-01-01')` (below `min`; the native picker would not offer it but the value can be set by typing/programmatically). 4. Also via `page.evaluate` setting value 2020-01-01 + input/change events.
- Expected: the UI should either not announce the change until the BFF confirms it, or announce the failure. The addendum: "changing shows toast 'Day pass for {Today|Wed, Sep 9}'" — meant for a successful change.
- Actual: toast **"Day pass for Mon, Jan 1"** (and "Day pass for Wed, Jan 1" for 2020-01-01) while `PUT /order` returns **400 VALIDATION_FAILED "Pick a day from today onwards."**. The input reverts to the previous good value (02/29/2028 — correct, controlled input), and the red text "Pick a day from today onwards." appears in `#formErr` between the save-card toggle and the terms checkbox in the *main panel*, i.e. nowhere near the date field in the sidebar. Console: `Failed to load resource: 400`.
- Evidence: shot `t1-values-1900.png` (shows toast + reverted date + form error together), `t1-values-eval-past.png`; `out-t1.txt` lines "== 1900", "== eval-past".
- Cause: `OrderSummary.tsx` `onDateChange` dispatches `showToast` unconditionally right after `updateOrder`; the rejection only reaches `state.error`, which `NewVisitorStep.tsx:72` renders in `#formErr`.

### A1-04 (P2) Keyboard year entry sends a PUT per keystroke → spurious 400s
- Viewport 1440×900, new-visitor step. Steps: 1. Click `#day` (focus lands on the month segment). 2. Type `abcd` (ignored) then `99999999` and Tab.
- Expected: at most one order update once a complete valid date is entered; no error while the visitor is still typing.
- Actual: Chrome emits `change` on every keystroke in the year segment; each fired `PUT /order {"visitDate":"0009-09-13"}` → **8 × 400 VALIDATION_FAILED**, the red "Pick a day from today onwards." error flashed under the form, and the toast said "Day pass for Mon, Sep 13" (year dropped, see A1-08). Input ended back at 2026-09-13 (reverted by React) but `#formErr` still showed the error. A normal user typing "2027" for the year produces the same pattern with 0002/0020/0202 before 2027 (each a 400) — confirmed by the mechanism, 2/2 on the 9999 sequence.
- Evidence: `out-t1.txt` "== KEYBOARD garbage" block (8 PUT 400 lines, NON-2xx list), shot `t1-values-keyboard.png`.
- Cause: `OrderSummary.tsx` uses `onChange` on `type=date` with an immediate `updateOrder`; no debounce, no `min` check client-side before the PUT, no year sanity check.

### A1-05 (P2) Race: delayed earlier PUT overwrites the later pick
- Viewport 1440×900, new-visitor step (qa1-4@dates.test).
- Steps (A): change `#day` 12 times back-to-back (+1…+12 days) with no waits. Steps (B): with `page.route` delaying only the request carrying 2026-09-30 by 2.5 s, pick 2026-09-30 then 200 ms later 2026-10-01.
- Expected: final order date == final pick (2026-10-01), or the UI tells the visitor which date won.
- Actual (A): 12 PUTs, all 200, responses in order, final 2026-09-22 == pick — OK. Actual (B): server received 10-01 first, then 09-30; server order = **2026-09-30**, UI `#day` = **2026-09-30**, last toast said "Day pass for Thu, Oct 1". The visitor's last choice is lost with no indication. Server and UI are consistent with each other (checked with a no-op `PUT {saveCard:true}` read-back) — the problem is loss of the user's intent, not divergence.
- Evidence: `out-t4-race.txt` ("B: responses in arrival order: 2026-10-01->2026-10-01, 2026-09-30->2026-09-30", "server order.visitDate = 2026-09-30 | UI shows 2026-09-30"); shot `t4-race-B.png`.
- Cause: `shortTermPassSlice.ts` `updateOrder.fulfilled` applies whatever response arrives (`isCurrent` only checks checkout id); the BFF has no version/if-match on `PUT /order`. Mitigation: abort in-flight PUT on a new pick, or send a client sequence and ignore stale responses.

### A1-06 (P3) Fine print during "Processing…" on the new-visitor step uses the recognized copy
- Viewport 1440×900, qa1-33@dates.test, `POST /purchases` delayed 6 s via `page.route`.
- Steps: fill name, pick visa-4242, accept terms, click Pay; sample DOM every 400 ms.
- Expected: addendum fine-print row: "identify/new visitor 'Defaults to today — pick another day…'; recognized 'Valid {day}. Your card stays on file at {Club}…'".
- Actual: while the button reads "Processing…" the sidebar fine print is **"Valid Today · Thu, Sep 10. Your card stays on file at Riverside — not on this website."** The "card stays on file" claim is made before the purchase succeeds and regardless of the save-card toggle.
- Good news from the same run: `#day`, `#mockCard`, `#termsCb`, `#pay` are all `disabled` for the whole processing window (13/13 samples); `page.fill('#day')` during processing was blocked.
- Evidence: `out-t3.txt` "DURING samples"; shot `t3-processing.png`.
- Cause: `OrderSummary.tsx` `if (step === 'recognized' || step === 'submitting') fine = finePrintRecognized(...)` — does not consult `previousStep`.

### A1-07 (Q) No maximum visit date
- UI: 2027-09-10, 2036-09-10 and 9999-12-31 all accepted with toast and `PUT → 200`; `#day` has no `max` attribute. API-level: `PUT {"visitDate":"9999-12-31"} → 200`. Fixture offers set no `maxDaysAhead`, so `maxVisitDate` is undefined (`fixtures/catalog.ts`, `order.ts createOrderShell`). If the product intends a booking window (e.g. 30/90 days), the catalog needs `maxDaysAhead`; the plumbing (`maxVisitDate`, `max` attr, `isVisitDateAllowed`) already exists and I could not exercise it because no fixture sets it.

### A1-08 (P3) Date labels never include the year
- `dayLabel`/`shortDate` in `format.ts` format `{weekday, month, day}` only. 2027-09-10 toasts "Day pass for Fri, Sep 10" — indistinguishable from this year's Sep 10 (a Thursday, but nobody checks the weekday). Receipt "Valid" line and pass block would read the same way for a far-future purchase. Shots `t1-values-+365.png`, `t1-values-9999.png`.

### A1-09 (Q) Identify-step fine print vs addendum
- Actual on identify (all clubs): "No membership. No recurring billing. Change plan any time before you pay." (`FINE_PRINT_INITIAL`). The addendum's "Fine print" row lists three variants and says "identify/new visitor" both get "Defaults to today — pick another day…", while also mentioning the "Initial static text". The prototype (`prospect-wallet-demo-1-first-visit.html:467-469`) re-renders `#fine` to the "Defaults to today" copy on every render including identify. Decide which is intended; the day picker is already live on identify so the planning hint arguably belongs there. Shot `t0-identify-default.png`.

### A1-10 (P3) Stale date error
- After A1-03/A1-04 the red "Pick a day from today onwards." stays in `#formErr` until another *successful* PUT. Setting the field empty (`page.fill('#day','')`) or to unparseable text ("tomorrow", "2026-13-45" via evaluate → Chrome sanitises to "") triggers no PUT (`if (!value) return`), so the error remains and the field visually keeps the last good date. `out-t1.txt` "== eval-garbage", "== eval-bad-month". Only cosmetic since Pay is not blocked by a date error... note that `order.ready` is server-computed and the last good date is what the server holds, so Pay is safe.

## 4. What passed

- Default value and `min` on identify and new-visitor steps equal club-local today (2026-09-10) for clubs 90030, 90032 (America/New_York) and 90033 when the browser is in the same calendar day; identify response `order.minVisitDate` matches. `max` absent (no `maxVisitDate`).
- Valid future picks via `page.fill`: tomorrow, +7, +30, +365, +10 y, 9999-12-31, leap day 2028-02-29 → PUT 200, `order.visitDate` echoes the pick, input shows it, toast "Day pass for Fri, Sep 11" / "Tue, Feb 29" etc.; back to today → toast "Day pass for Today".
- `page.evaluate` + input/change events behave identically to fill (2026-09-13 → 200).
- Past dates (yesterday, 1900-01-01, 2020-01-01) are rejected by the BFF (400 VALIDATION_FAILED, `details.field=visitDate`) and the input reverts to the last accepted date; server never stored a past date.
- Pending date picked BEFORE identify (2026-09-16) survives identify: exactly one `PUT {"visitDate":"2026-09-16"} → 200` right after `/identify`; changing again after the card was selected (2026-09-19) kept the card ("Visa •••• 4242 ready.") and terms checked; purchase → `/signup/pass?club=90030`, heading "Receipt", pass block **"1-day pass · Sat, Sep 19"**, sidebar **"Valid Sat, Sep 19"**, `purchase.pass.visitDate = 2026-09-19`, receipt R-000045 (qa1-23). Toast label "Day pass for Sat, Sep 19" matched.
- Today purchase (qa1-33): pass block "1-day pass · Today · Thu, Sep 10", sidebar "Valid Today · Thu, Sep 10", `pass.visitDate 2026-09-10`, R-000047. `#day` is not rendered on the done page (Valid row instead), as designed.
- Date input, card select, terms and Pay are disabled during "Processing…".
- Rapid sequential changes (12 in a row) — every PUT 200, responses in order, final state consistent.
- Empty value: no PUT, no toast, state unchanged.
- API-level (page.evaluate fetch with the session CSRF token): `"2026-13-45"`, `"2026-02-30"`, `"tomorrow"`, `""`, `"2026-9-1"`, `"20260915"`, `"2026-09-15T00:00:00Z"` → 400 `Invalid request: visitDate must match format "date"`; `12345` → 400 `must be string`; yesterday/1900 → 400 "Pick a day from today onwards."; unknown property → 400 additionalProperties; missing CSRF header → 403 CSRF_REJECTED; `null` → 200 no-op (schema allows nullable). The UI stayed on the new-visitor step with its own date after all probes.
- Club 90032: same date behaviour, "1-day pass $18.00", Pay $18.00. Club 90033: "Gym Floor $25.00", "Pay $25.00 and get my pass", min/default 2026-09-10, +2 → "Day pass for Sat, Sep 12". Core South purchase: see appendix line below (filled when t6 completed).
- No console errors other than the expected `Failed to load resource: 400` for deliberately invalid dates; two Chrome warnings `The specified value "tomorrow" does not conform to the required format` from my own evaluate probes. Redux `SerializableStateInvariantMiddleware took Nms` dev warnings appeared under load (dev-only noise, not reported).

## 5. Not tested / blocked

- Browser *behind* club (browser yesterday vs club today, the real "near midnight in the US" case) — cannot be produced at 11:00 PDT; the club clock is server time and off-limits. Analysed from source in A1-02.
- `maxVisitDate` / `max` attribute enforcement — no fixture offer sets `maxDaysAhead` (A1-07).
- Real native date-picker popup interaction (mouse in the calendar widget) is not scriptable in headless Chrome; used fill/keyboard/evaluate instead.
- Reload/rehydration of a pending (pre-identify) date — out of slice; noted that `pendingVisitDate` lives only in Redux, so a reload on identify loses the pick (by design per the source comment).

## Appendix — late results
- Core South (club 90033, qa1-6c@dates.test, picked +2 = 2026-09-12, visa-4242, terms accepted): done page `/signup/pass?club=90033`, heading "Receipt", pass block **"Gym Floor · Sat, Sep 12"**, sidebar "Gym Floor $25.00 / Valid Sat, Sep 12 / Paid with Visa •• 4242 / Paid $25.00 / Receipt emailed to q•••••@dates.test. Your card stays on file at CORE — not on this website." No non-2xx, no console errors. Shots `t6-90033-newvisitor.png`, `t6-90033-done.png`. (Side observation for the copy owners: the club short name renders as all-caps "CORE" from `brand.word`.)
- Recognized step (t9, my own persona qa1-23@dates.test re-identified after its purchase → verify step, code 123456 → recognized with saved Visa •• 4242; one OTP send consumed): verify-step fine print is the initial copy ("No membership. No recurring billing. Change plan any time before you pay."), `#day` 2026-09-10. Recognized: `#day` 2026-09-10, min 2026-09-10, fine print **"Valid Today · Thu, Sep 10. Your card stays on file at Riverside — not on this website."**, sidebar "Paying with Visa •• 4242" — matches addendum. Pick +4 → toast "Day pass for Mon, Sep 14", fine print "Valid Mon, Sep 14. Your card stays…" — tracks the date (PASS). Shots `t9-recognized.png`, `t9-recognized-changed.png`.

### A1-11 (P2) Recognized step swallows the date rejection
- Viewport 1440×900, recognized step as above.
- Steps: 1. On recognized with `#day` = 2026-09-14, `page.fill('#day', '2026-09-09')` (yesterday).
- Expected: an error near the picker (or at least the same "Pick a day from today onwards." the new-visitor step shows), no success toast.
- Actual: `PUT /order → 400 VALIDATION_FAILED "Pick a day from today onwards."`; toast **"Day pass for Wed, Sep 9"**; input reverts to 09/14/2026; `#formErr` absent, `[role=alert]` count 0, fine print still "Valid Mon, Sep 14…". The visitor sees a success toast for Sep 9 and a field that quietly shows Sep 14. Console: `Failed to load resource: 400`.
- Evidence: `out-t9.txt` "after yesterday" line + NON-2xx list; shot `t9-recognized-past.png`.
- Cause: `RecognizedStep.tsx` does not render `state.error` for `VALIDATION_FAILED` the way `NewVisitorStep.tsx:72` does; `OrderSummary.tsx` toasts before the PUT resolves (same root as A1-03).
