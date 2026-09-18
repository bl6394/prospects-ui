# Day Pass checkout — browser QA, 2026-09-10

Consolidated results of six parallel QA agents driving headless Chrome (Playwright, installed Google Chrome) against the Sprint 0001 build:

- UI `online-join-ui` branch `prospect-wallet/sprint-0001` at `a3c61b6` (PR #524)
- BFF `online-join-bff` branch `prospect-wallet/sprint-0001` at `db81011` (PR #96)
- Entry `http://localhost:3000/signup/day-pass?club=90030`, mock adapters and mock capture, flag override on, Riverside fixture data.

Per-agent reports (full steps, evidence, passed lists) are in `agent-reports/`; screenshots in `screenshots/<agent>/`; the shared brief the agents worked from is `agent-reports/00-BRIEF.md`. A designer-facing screenshot gallery of every screen at 13 phone viewports is at `../../screenshots/sprint-0001/mobile/day-pass-mobile-gallery.html`.

Agents and slices: A1 dates · A2 identify and one-time code abuse · A3 new visitor, payment, terms, done · A4 returning visitor and wallet · A5 mobile viewports · A6 gating, clubs, session, resilience, accessibility.

## Verdict

No P0. Seven distinct P1 defects, all reproduced at least 2/2, two of them found independently by two agents. None blocks a demo on the happy path, but three (decline receipt, reload dead end, lost-cookie dead end) will be hit by real visitors and should be fixed before the PRs merge. Everything in the happy path passed on all 13 viewports, and no request produced a 5xx.

## P1 — fix before merge

| # | Title | Found by | Cause (verified in source) |
|---|---|---|---|
| P1-1 | **Declined purchase shows a paid receipt.** Main panel says "We couldn't complete your purchase / Your card was declined", but the sidebar flips to "Receipt · Paid with Visa •• 0002 · Paid $18.00 · Receipt emailed to …" and the URL moves to `/signup/pass`. | A3-02, A4-01 (3/3, 2/2) | `OrderSummary.tsx` keys "done" off `step === 'complete'` instead of `purchase.state === 'COMPLETE'`; same for the `/pass` redirect in `ShortTermPassPage.tsx`. |
| P1-2 | **Reload on the new-visitor step leaves Pay permanently disabled.** After any reload that rehydrates into new visitor, choosing a card returns `ready` but "Paying with" never appears and Pay stays disabled with terms ticked. Only "Edit → Continue" recovers. | A3-01, A6-03 (4/4, 2/2) | `applySnapshot` in `shortTermPassSlice.ts` never sets `paymentChoice = { useSaved: false }` for the `newVisitor` snapshot, so `paymentReadySelector` waits for a saved card that a new visitor cannot have. |
| P1-3 | **Lost or deleted session cookie is a dead end.** Pay, Continue or a date change show a raw red "Not found" alert; no session-expired toast, no restart; only a manual reload recovers. | A6-01 (3/3) | BFF `context.ts` answers 404 `NOT_FOUND` for a missing cookie (401 `CHECKOUT_EXPIRED` only for a known-but-expired record); the UI restarts only on `CHECKOUT_EXPIRED` and renders every other message verbatim. |
| P1-4 | **Two tabs, one cookie: pass delivered to the wrong contact.** Tab B identifies contact X, tab A identifies contact Y (same checkout, BFF overwrites contact and order), tab B still shows X and pays; the pass and receipt go to Y. All calls 200/201. | A6-02 (2/2) | `identify.ts` re-binds the checkout's contact with no staleness check; the UI has no checkout revision/etag on purchase. |
| P1-5 | **Browser time zone ahead of the club mislabels "Today".** With the browser a day ahead (emulated Pacific/Auckland vs America/Chicago), the pre-identify picker uses the browser's today, toasts "Day pass for Today" for club-tomorrow, and that date is applied to the order after identify. | A1-01 (2/2) | `OrderSummary.tsx` falls back to `browserToday()` until the order exists; club-local today is only known after `/identify`. Expose `minVisitDate` on the checkout bootstrap, or hide the picker until the order exists. |
| P1-6 | **New-visitor step overflows horizontally on every phone narrower than 393 px** (33 px on 360, the most common Android; 74 px on 320). | A5-01 (13/13 viewports) | `.page { grid-template-columns: 1fr }` is `minmax(auto,1fr)` so the column cannot shrink below the `#mockCard` select's intrinsic width. `minmax(0,1fr)` or `select { width:100%; min-width:0 }` fixes it. The select is mock-only, but the same grid weakness reproduces with a long email in production (A5-04). |

## P2 — should fix

Grouped by theme; IDs point into the agent reports.

**Server messages leak to the visitor**
- A2-03, A3-03: a contact over 120 chars or a name with `<`/`>` or over 60 chars passes the client and the visitor sees `Invalid request: contact must match pattern "^[^\r\n]{3,120}$"`. Add client `maxLength` and friendly copy.
- A6-11: a real 429 on identify shows "Too many attempts…" without the retry seconds, and Continue re-enables immediately. (Confirmed with the real limiter: the 21st identify from one IP in 15 minutes is throttled.)

**Optimistic UI missing**
- A4-02, A6-12: the terms checkbox, save toggle and date only change after the `PUT /order` round trip (480–835 ms locally); on slow networks the box looks broken.
- A1-03, A1-11: a success toast fires for a date the server then rejects; on the recognized step the rejection shows no error at all and the input silently reverts.
- A1-04: keyboard year entry sends one `PUT` per keystroke with partial years, producing 3–8 spurious 400s and error flashes.
- A1-05: out-of-order `PUT /order` responses can lose the visitor's last pick with no notice (deterministic with injected delay).
- A1-02: before identify the picker's default and `min` follow browser today, then silently jump to club today.

**Recovery paths**
- A6-04: the "Your session expired" toast can never render because `resetForNewCheckout` clears the toast in the same tick.
- A6-05: a 200 with a non-JSON body on bootstrap crashes the reducer and spins "Loading your checkout…" forever.
- A6-06: a purchase request with no response hangs in "Processing…" indefinitely (no client timeout).
- A6-07: a transient network failure on bootstrap shows the permanent "This page is not available" copy.
- A6-08: after another tab completed the purchase, the first tab's actions fail with "Identify yourself before…" and offer no way out.
- A3-04: "Try again" after a decline wipes the typed names. A3-05: the inline form error is stale and the invalid field gets no `aria-invalid` or focus.
- A2-04: after a wrong code the six boxes clear but focus is lost; on a phone the keyboard closes.
- A2-01: "Text me instead" stays enabled during the 30 s cooldown and fails with a raw throttle message. A2-02: after a channel switch the masked alternate contact is withheld, but a reload reveals it.

**Mobile and accessibility**
- A5-02: header overflows by 84 px in landscape and at tablet-portrait widths (641 to about 930 px).
- A5-03: all inputs are 14 px, which triggers iOS zoom-on-focus.
- A5-05: tap targets under 44 px: text links 17 px tall, terms checkbox 16 px, date input 36 px, OTP boxes 33 to 40 px wide.
- A6-09: no `<html lang>`, two `<main>` landmarks, unavailable and done pages have no h1.
- A6-10: primary button text contrast about 3.0:1 (white on #239CD3) fails WCAG AA.

## P3 and design questions (summary)

- Copy and consistency: card label "Visa •• 4242" in the sidebar vs "Visa •••• 4242" in the chip (A4-04); labels omit the year for far-future dates (A1-08); stale "Pick a day from today onwards" error (A1-10); orphan "·" when verify links wrap (A2-07, A5-09); "saved to your wallet" shown when paying with an already-saved card (A4-03); Dana's expired card silently hidden behind "No card on file yet" (A4-05); after a decline "Try again" leaves the declining card preselected (A4-06).
- Layout: header renders as three rows at 402 px and under (A5-06); nav "Visit" clipped at 360 px and under with no affordance while the demo hides the nav on phones (A5-07); about 56 px dead space above "Order summary" on mobile (A5-08, A4-09); order summary and date picker sit below Pay and are not sticky, so a visitor can pay without seeing "Pick a day" (A5-12); 320 px only: done page overflows 5 px and "Pick a day" wraps (A5-10, A5-11).
- Navigation: every step uses `history.replace`, so browser Back leaves the site (A2-10, A4-08). Edit resets a chosen date to today (A3-07). Reload on new visitor keeps terms and date but loses names and card (A6-17).
- Product questions: no upper bound on the visit date, 9999-12-31 accepted (A1-07); header nav "Classes · Memberships · Visit" are dead spans (A6-14); Core South perks never displayed (A6-16); production CSP is `frame-ancestors *` so framing is blocked only client-side (A6-15); the visa-0003 "timeout" mock completes normally so the RECONCILING screen is unreachable from the browser (A3-09); `findDOMNode` StrictMode console error from the MUI Terms dialog on every load (A5-13, A6-13).

## What passed

- Happy paths: new visitor and returning visitor purchases completed on desktop and on all 13 phone viewports; exactly one `POST /purchases` on double-click; network-abort retry reuses the same Idempotency-Key; reload on the done page re-renders the pass; QR payload non-empty; delivery sentence and masking correct per channel; Casey the member behaves like a prospect.
- Identify and code: all junk, script, SQL, unicode and oversized inputs inert; every phone format accepted; ambiguous shared phone handled; exact "attempts left" copy including the singular; lockout after 5 wrong codes with Resend and Start over still working; Start over revokes the code server-side (API-proven 401); double-click Continue sends one identify; reload on verify rehydrates with the countdown intact.
- Dates: default and min equal club-local today for all three time-zone fixtures; every valid future date including leap day round-trips; past and malformed dates rejected server-side with 400 `VALIDATION_FAILED` (also confirmed with CSRF at the API); pre-identify pick survives to the receipt; date input disabled during Processing; 12 rapid changes stay consistent.
- Payment and terms: all five test cards behave as documented; Pay disabled until terms; Escape, backdrop, Close and × do not accept; modal focus trap and restore; save-card copy on and off; no raw card number anywhere in DOM or network.
- Gating: all club variants and malformed `club` values show the unavailable copy with no script execution and no cookie; Northside club-authored terms appear; Core South $25 Gym Floor and "Get the CORE app"; iframe fallback with `target=_top`; direct `/signup/pass` without a session returns to identify; cookie is HttpOnly, SameSite=Lax, Path=/; offline then online retry preserves state; injected 500/502 on purchase is readable and recoverable; whole flow completable by keyboard.
- Mobile: no viewport except the new-visitor step overflowed; modal fits and Agree is reachable everywhere; `inputmode` and `autocomplete` correct on every field; no font under 12 px; club name never clipped.

## Not covered

- Browser time zone behind the club (analysed from source only; cannot be produced at the run time of day).
- `maxVisitDate` enforcement: no fixture offer sets `maxDaysAhead`.
- Hosted Pay Page capture (gate G4): mock capture only, as in the sprint.
- Real SMS or email delivery; mock delivery only.
- Real devices and Safari: Chrome emulation with an iOS user agent, so iOS-specific rendering (native date picker, zoom-on-focus) is inferred from font sizes rather than observed.

## Harness notes

- The BFF throttles identify at 20 per IP per 15 minutes and dev runs with `app.proxy` off, so six agents on localhost would have been throttled within a minute. The compiled `dist` was temporarily patched to 100000 for the run and restored afterwards; the real limit was then confirmed with 22 sequential identifies (the 21st is rejected with "Too many attempts"). The repo source was never changed.
- Personas were partitioned per agent because mock state is in memory and the per-contact send limit (5 per 15 minutes) is real.
- Five simultaneous cold loads from the webpack dev server stalled the bundle (A4-10); this is the dev server, not the product, but it inflated some latencies quoted in the reports.

## Addendum 2026-09-10 13:45 PDT — P1 fix verification against the Sprint 0002 head

The Sprint 0002 execution (UI `41d7444`, BFF `fc77007`, same branch `prospect-wallet/sprint-0001`, pushed 13:09 PDT) consumed this report and landed fixes for P1-1 through P1-6 between 12:01 and 12:53 PDT. Rather than re-implement, the four the user asked for were re-verified in the browser against that head (headless Chrome, fresh context per case, one-time codes read from the hooks-only testing outbox). Script: session scratchpad `qa/verify/verify-p1.mjs`; screenshots in `screenshots/p1-verify/`.

| Defect | Result | Evidence |
|---|---|---|
| P1-1 declined card showed a paid receipt | **Fixed.** Sidebar stays "Order Summary" with "Paying with Visa •• 0002" and Total; no "Receipt", no "Paid"; URL stays `/signup/day-pass`. | `p1-1-decline.png` |
| P1-2 reload on new visitor left Pay disabled | **Fixed.** After reload, choosing a card enables Pay, "Paying with" appears, and the purchase completes to the pass block. | `p1-2-after-reload.png`, `p1-2-done.png` |
| P1-3 lost cookie dead-ended on "Not found" | **Fixed.** BFF answers 401 `CHECKOUT_EXPIRED`; the UI shows "Your session expired. Let's start again." (toast appears in about 1.4 s, lasts 1.8 s) and restarts at identify with no "Not found". | `p1-3-lost-cookie-toast.png` |
| P1-6 new-visitor step overflowed under 393 px | **Fixed.** `scrollWidth - innerWidth` is 0 at 320, 360 and 375 px on identify, code entry and new visitor with the test-card panel. | `p1-6-newvisitor-{320,360,375}.png` |

Also observed on the new head: a 429 on identify now shows "Try again in Ns" and disables Continue with a countdown (closes P2 A6-11). Verification traffic tripped the new §5A.1 per-IP limit (retry 3001 s); it was cleared with the hooks-only `POST /testing/reset`, which the harness lane can rely on.

The v1.2 redesign changed the flow (offer card, inline code entry, every email gets a code, adult and waiver consents in the sidebar, sidebar Pay button), so the remaining P2/P3 findings above need re-triage against the new screens before anyone acts on them.
