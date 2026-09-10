# Day Pass — Sprint 0002 orchestrator browser smoke (2026-09-10)

**Build:** online-join-ui `41d7444`, online-join-bff `fc77007` (branch `prospect-wallet/sprint-0001`). **Environment:** BFF on :3000 with `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_TEST_HOOKS=true`, `STP_TEST_HOOKS_KEY=<local>`; UI dev server on :3001 proxied through the BFF; entry `http://localhost:3000/signup/day-pass?club=90030` (Riverside fixture). **Driver:** headless Google Chrome via `puppeteer-core` 23, one fresh browser context per flow (fresh cookie jar), flags `--disable-features=AutofillServerCommunication,PaymentRequest`, temp profile deleted afterwards. One-time codes read from `GET /api/short-term-pass/testing/outbox?checkoutId=` with `X-STP-TEST-KEY`. Fixture cards only; no real card; mock payment gateway; no live charge.

This is the orchestrator's manual-equivalent check, not the deferred parity loop (PR-01) or the simulated-user agents (PR-02).

## Results

| # | Flow | Width | Steps | Server state after Pay | Verdict |
|---|---|---|---|---|---|
| 1 | Returning — `jordan.reyes@email.com`, saved Visa 4242 | 1440 | identify → code (outbox) → verify → "We found you." → adult + waiver → Pay | purchase `COMPLETE`, payment `captured`, wallet `saved` (existing entry), URL `/signup/pass?club=90030` | pass |
| 2 | Same as 1 | 375 | same | same | pass |
| 3 | First-time, save off — new email, first/last, unique mobile, fixture Visa 4242 via `TestCardPanel` | 1440 | identify → code → verify → details → card → adult + waiver → Pay | `COMPLETE`, person `created`, wallet `not-requested`, 0 entries | pass |
| 4 | First-time, save on — as 3 with the save switch turned on after the card was ready | 375 | same + switch | `COMPLETE`, person `created`, wallet `saved`, 1 entry with UUID `providedId` | pass |
| 5 | Script defect kept as evidence: first-time with a mobile already on another person | 375 | as 3 | `FAILED` at `persist-person` — "Someone with this contact already exists…", payment `voided`, no person, no sale; UI stayed on the failure view, no receipt, URL unchanged | correct behaviour (P1-1 fix observed) |
| 6 | P1-6 overflow — identify, code entry, new visitor | 320, 360, 375, 393, 440 | `document.documentElement.scrollWidth` vs `innerWidth` | equal at every width and step | pass |
| 7 | Fonts | all | request log | no request to `fonts.googleapis.com` / `fonts.gstatic.com` | pass (Inter self-hosted) |
| 8 | Page errors | all | `pageerror` listener | none | pass |

## Screenshots (`docs/validation/screenshots/sprint-0002/`)

`returning-{01-identify,02-code-entry,03-recognized,05-consented,06-done}-{1440,375}.png`, `first-save-off-{01…06}-1440.png`, `first-save-on-{01…06}-375.png`, `overflow-new-visitor-{320,360}.png`. Reviewed by eye against `docs/prd/day-pass-v1.2.html`: offer card selected beside the email field with the skeleton sidebar; inline six-digit code entry with Change / Resend / "Verify and continue"; "Welcome back, Jordan" with the "We found you." alert, Your info rows and the `.paysel` chip; Order Summary with "Day pass applies on", line item, Paying with, Total, the 18+ and waiver checkboxes, the "By tapping Pay…" sentence and the Pay button; new visitor with required Mobile, both notices and the unchecked "Keep me posted about joining Riverside"; TEST MODE fixture panel in place of the hosted form; save switch default off with the stored-card description; done page with QR, saved-card alert, "Get the Riverside app" / "Start again", and the Receipt sidebar.

Visible deviations, all on the approved-delta list: email transactional notice under the email field; SMS notice and marketing row; TEST MODE panel where v1.2 mocks card fields; static location label; PRD refund sentence in Pass Terms.

## Not covered here

Hosted Pay Page capture (B1 credentials absent — gate S5 pending); the four document dialogs were not screenshotted by this script (pinned in UI tests, to be covered by the parity loop); declined / timeout / wallet-failure paths (covered by the BFF demo script 66/66 and route suites); accessibility beyond labels.

## Reproduce

1. Restart the BFF and UI dev servers on the branch heads (BFF `.env` needs `STP_TEST_HOOKS=true` and `STP_TEST_HOOKS_KEY=<random>`; keep `STP_CAPTURE_MODE=mock` so the fixture panel is available without Pay Page credentials).
2. Manual: open `http://localhost:3000/signup/day-pass?club=90030`, enter an email, then read the code with `curl -H "X-STP-TEST-KEY: $KEY" "http://localhost:3000/api/short-term-pass/testing/outbox?checkoutId=<id>"` (the id is in the `POST /checkouts` response in the network tab), or pin `STP_MOCK_OTP_CODE=123456` in `.env` for a manual session. Jordan Reyes `jordan.reyes@email.com` is the returning buyer; any other email is a first-time buyer.
3. Scripted: the smoke script used here lives in the orchestrator session scratchpad (`smoke/smoke.mjs`); it is the seed for `tools/day-pass-harness/browser` when the harness lane starts.
