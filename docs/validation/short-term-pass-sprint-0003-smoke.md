# Sprint 0003 — orchestrator browser smoke (E2) and PR-06 email proof

**Build:** online-join-ui `6243e8b`, online-join-bff `6dfa0cd` (branch `prospect-wallet/sprint-0003` in both, stacked on `prospect-wallet/sprint-0001`). **Date:** 2026-09-16. **Environment:** one BFF process on :3000 (`node --env-file=.env dist/src/server`, built from `6dfa0cd`) with `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_TEST_HOOKS=true`, `STP_TEST_HOOKS_KEY=<local>`, `STP_EMAIL_TRANSPORT=smtp` → Mailpit (`stp-mailpit`, SMTP :2525, API :8025), `STP_PUBLIC_BASE_URL=http://localhost:3000`, `STP_PASS_LINK_SECRET=<local, never printed>`, `STP_PASS_LINK_GRACE_HOURS=24`; UI dev server on :3001 proxied by the BFF; entry `http://localhost:3000/signup/day-pass?club=90033` (Core South, the v4 club) and `?club=90030` (Riverside). **Driver:** headless Google Chrome via `puppeteer-core` 23.11, one fresh browser context per flow (fresh cookie jar), background-tab throttling disabled, `POST /testing/reset` before every flow (limiters, address locks, pass-view and resend limiters). One-time codes read from `GET /api/short-term-pass/testing/outbox?checkoutId=` with `X-STP-TEST-KEY`. Fixture cards only; no real card; mock gateway; no live charge. Script: `smoke3.mjs` in the orchestrator session scratchpad (seed for the deferred harness's browser driver). Raw pass tokens never appear in this report or in the screenshots.

**Result: 240 / 240 checks passed** (first run 216 / 234 — the 18 failures were script assumptions: the smoke never pressed "Verify and continue"; a receipt-row selector picked the date field; the "QR" hit was the shell's header icon; the third-party list was the pre-existing CDN + AppDynamics on checkout pages; the bullet check matched the masked email; and a background tab was throttled by headless Chrome. No product defect was found.)

## Flows

| Flow | Width | Path | Result |
|---|---|---|---|
| core-kelly-1day | 1440 | Core, three cards, default 1-day, `m@m.com` (Kelly, saved Visa 4242), pay | COMPLETE; `pass.validUntil=2026-09-16`, `receipt.amountMinor=2500`, label "1-day pass"; done page no QR, "View your pass" in block **and** Receipt; email + page + API + tamper + **resend** (old link 404, new link 200, reload shows the link without a resend) + **hooks revoke** (404) |
| core-kelly-3day-future | 375 | select 3-day (toast "3-day pass · $60.00"), Kelly, start date +7 days | help "Wed, Sep 23 – Fri, Sep 25"; Pay "Pay $60.00 and get my pass"; COMPLETE `validUntil=2026-09-25`; page status **Upcoming** with QR; email subject "Your 3-day pass at Core Health and Fitness Club · Wed, Sep 23 – Fri, Sep 25" |
| core-new-5day-save-off | 1440 | select 5-day (toast "5-day pass · $90.00"), new visitor (`smoke-<ts>@stp.test`, unique mobile), Visa 4242 test card, save off | `newVisitor`; help "Today – Sun, Sep 20"; COMPLETE `validUntil=2026-09-20`, amount 9000; page **Valid today**; email decoded |
| core-kelly-3day-375 | 375 | 3-day, Kelly, today | help "Today – Fri, Sep 18"; COMPLETE `validUntil=2026-09-18` |
| riverside-jordan-1day | 1440 | Riverside single card (`.offers.single`), Jordan, saved card | line item exactly "1-day pass"; Pay "$18.00"; COMPLETE `validUntil=2026-09-16` — regression clean |
| overflow | 320 / 360 / 375 / 393 / 440 | identify with three cards | `scrollWidth == innerWidth` at every width |
| stale-tab | 1440 | two tabs on one cookie; tab 2 selects 5-day, tab 1 then selects 3-day with the stale generation | tab 1 is refused (409 `STALE_GENERATION`), rolls back and re-syncs to **5-day** |

## What every purchase flow asserted

Identify: three `.offer` cards in `role="radiogroup"` "Choose a pass", exactly one `.selected` with the "Selected" chip, `.days` "1-day pass | 3-day pass | 5-day pass", prices "$25 | $60 | $90", cards still rendered on code entry; selecting a card persists (`PUT /offer`) and toasts. Sidebar: `label[for=day]` "Day pass applies on" (1-day) / "Pass starts on" (multi-day); help "Today · Wed, Sep 16" / "Today – Fri, Sep 18" / "{start} – {end}" (en dash); line item "{label} · Gym Floor" (Riverside "1-day pass"); Pay text from `consent.payButtonText`. Done: pass block "{label} · {validity}" + the v4 sentence "We emailed your pass and door QR code to {masked}. Show it at the door, or just say your name at the front desk."; no `.qr` / svg / canvas in the pass block; "View your pass" href identical under the block and in the Receipt row; Receipt "Valid" row. Server state (`/testing/state`): `purchase.state=COMPLETE`, `pass.{label,validUntil,qrPayload STP2…}`, `receipt.{amountMinor,…}`, **no raw token anywhere in the state dump**. No third-party **font** request (Inter self-hosted); the pre-existing CDN and AppDynamics hosts still load on checkout pages and **not** on the pass page.

## PR-06 — pass email proof (Mailpit API, three flows)

`GET /api/v1/search?query=to:"<email>" subject:"pass"` → `GET /api/v1/message/{ID}`: subject "Your {label} at Core Health and Fitness Club · {validity}"; `Inline[0]` = `image/png` with `Content-ID: pass-qr` (listed under `Inline`, not `Attachments`); `GET /api/v1/message/{ID}/part/{PartID}` decoded with `pngjs` + `jsqr` **equals `pass.qrPayload` byte-for-byte** (59 chars, `STP2|passId|90033|visitDate|validUntil|sig`) in all three flows; HTML references `cid:pass-qr` and contains Receipt, an amount and the PRD refund sentence "Refunds: none online…"; the plain-text part carries the "View your pass" URL. Screenshot: `email-pass-3day-delivered.png` (rendered from the delivered HTML with the CID image inlined and the token redacted). Two emails exist for the resend flow (original + accepted resend) with different links.

## CR-13 — public credential (per flow, JSON + image + page)

`GET /api/short-term-pass/passes/<token>` → 200, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex, nofollow`, no `Set-Cookie`; `PassView` key set exactly `club, contact, holder, linkExpiresAt, pass, qr, receipt, status, today`; `qr.payload` equals the issued payload; `holder` = `{firstName}` only. `…/qr.png` → 200 `image/png`, `nosniff`, `no-store`, decodes to the issued payload. Tampered signature and a well-formed unknown token → 404 with an identical body (correlation id aside), `no-store`, no cookie. Fresh browser context (no cookie, no `?club=`, `window.featureFlags` absent): `/signup/pass/<token>` renders `[data-testid=pass-credential]` at 1440 and 375 with the QR SVG, "{label} · {validity}", first name, status pill (Valid today / Upcoming), the desk sentence, "Get the CORE app", and the Receipt sidebar (item, amount, Valid, receipt number) — no card brand/last4, no ids, **no AppDynamics request**. Tampered link → "This link isn't valid.". Resend (`POST …/pass-link`) rotates the link; the old one answers 404 only after the accepted send; reload of the done page shows the current link via `GET …/pass-link`; hooks revoke → 404.

## Screenshots (`docs/validation/screenshots/sprint-0003/`)

`identify-three-cards-375.png`; per flow `*-code-entry-{w}.png` (three cards + inline code entry), `*-sidebar-{w}.png` (order summary with the range), `*-done-{w}.png` (no QR, View your pass, Receipt), `*-pass-page-{1440,375}.png` (public page); `email-pass-3day-delivered.png`.

## Not covered here (by design or blocked)

- Parity loop and agent runs (deferred by the user; inputs re-baselined on v4 — see `short-term-pass-ui.md`).
- Hosted Pay Page capture (B1 credentials absent) — `TestCardPanel` fixture cards used for the new-card flow.
- Live email through the publisher (dev email-publisher 503) — publisher request shape unit-pinned; hosted `qr.png` verified only against the local BFF.
- Link expiry at `linkExpiresAt` and the `expired` page state — covered by BFF jest with the test clock (`passes.test.ts`), not in this real-time smoke.
- Desk scanning of the QR — no verifier exists (static demo payload, OQ-5).

## Reproduce

```text
docker start stp-mailpit
cd repos/online-join-bff && npm run build && node --env-file=.env dist/src/server     # .env per the header above
cd repos/online-join-ui && npm start                                                  # :3001
node <scratchpad>/smoke/smoke3.mjs                                                    # prints PASS/FAIL per check; results JSON beside it
```
