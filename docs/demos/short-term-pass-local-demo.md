# Short-term pass (Day Pass) — local demo script

**Sprint 0001 task E1.** The demo drives the real BFF router and purchase orchestrator over HTTP (cookies, CSRF, Origin) with the mock adapter set, asserts API results and inspects mock state directly (directory, wallet owners/entries, gateway calls, sales, passes, outbox). Copy is never used as evidence.

## Run it

```
cd repos/online-join-bff
npm run demo:short-term-pass              # Demo 1 · First visit, Demo 2 · Returning visit, reload and fault runs
npm run demo:short-term-pass -- --hosted  # + one real Pay Page hosted-capture run (needs PAY_PAGE_* / ABC_CORE_API_URL in .env)
```

The script is `scripts/short-term-pass-demo.ts`, compiled by `npm run build` into `dist/scripts/` (no extra runner dependency: the repo's `erasableSyntaxOnly` TypeScript compiles with `tsc`). It sets `STP_ADAPTER_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true` and `STP_ALLOWED_ORIGINS` when they are absent, boots an in-process Koa app on an ephemeral port with the same body middlewares as `server.ts`, mounts the pass router and the payPage router, and exits 0 only when every check passes. The one-time code in mock mode is the fixed `STP_MOCK_OTP_CODE` (`123456`), echoed by the BFF in the mock-only `debug` field; the script never reads the outbox for it.

## Runs

| Group | Run | What it proves | Use cases |
|---|---|---|---|
| Demo 1 · First visit | 1 — new visitor, save on (Taylor Kim by email + mobile) | authorize → prospect persisted with both contacts → owner created by member UUID with exactly `{dt_clubNumber, dt_memberId, dt_memberType:'PROSPECT'}` → one entry → sale → pass → emailed; reload resumes the completed checkout and `GET /purchases/:pid` recovers the result | U8, U10, U13, U17 |
| | 2 — new visitor, save off (Sam Lee by mobile + email) | prospect and second contact persisted; no owner, no entry, **no wallet call**; receipt texted | U13 |
| | 3 — Start again, then Taylor returns by the **secondary** contact (mobile) | `DELETE /checkouts` revokes access; lookup by the second contact finds the same person (no duplicate); wallet lists the card saved in run 1; saved-card purchase completes | U5, U11, U13, U17 |
| Demo 2 · Returning visit | 4 — Jordan Reyes, saved Visa 4242 | typed channel in full / other masked; reload rehydrates `recognized`; purchase on the stored entry with no wallet write; idempotent replay (same key → same result, one authorization) | U6, U11, U16, U17 |
| | 5 — Jordan, Mastercard 4444, save on | entry added to the **existing** owner; `createOwner` never called; 4242 untouched | U12 |
| | 6 — Jordan, Mastercard 4444, save off | no wallet write; existing entries untouched | U12 |
| | 7 — Morgan Blake, saved Visa 0002 (decline) then a new card | `FAILED` with `PAYMENT_DECLINED`, nothing sold or issued; retry on the same checkout completes | U16 |
| | 8 — fault switch `wallet-failure` then `wallet-retry` | sale and pass complete with `wallet.status:'failed-retryable'`; the retry saves the card and makes **no** payment call | U16 |
| Hosted | `--hosted` | pass-scoped Pay Page session, generic poll refused (404), readiness poll, purchase from the BFF-side token | G4 |

The fault switch (`STP_MOCK_FAULTS` or the in-process `faultSwitch`) is never a browser API; runs 7–8 flip it from inside the script. The remaining faults (`auth-timeout`, `prospect-failure`, `void-unknown`, `wallet-unavailable`, `sale-failure`, `issue-failure`, `delivery-failure`) are exercised by `src/routes/shortTermPass/__tests__/purchase.test.ts` (see `docs/validation/short-term-pass-bff.md`).

## Recorded run (2026-09-10, `online-join-bff` @ Phase E, mock adapters)

```
Short-term pass demo · adapter mode mock · capture mode mock · 2026-09-10T06:15:44.861Z

Capability report:
  mock     ClubCatalogPort                        MockClubCatalog                MICO club/getClub (name, onlineProspects, prospectTerms) + POS sale items (offer, price)
  mock     CheckoutStorePort                      InMemoryCheckoutStore          shared atomic checkout store (live gate L4)
  mock     PurchaseStorePort                      InMemoryPurchaseStore          durable operation store with idempotency keys (live gate L4)
  mock     IdentityDirectoryPort + ProspectPort   MockIdentityDirectory          club-scoped lookup by contact and lean prospect creation (OQ-1; no MICO endpoint exists)
  mock     VerificationPort + DeliveryPort        MockOutbox                     email-publisher-service + SMS provider (OQ-2)
  mock     WalletPort                             MockWallet                     universal-wallet /wallet-entry-owner and /wallet-entry/credit-card
  mock     PayPageSessionReader                   MockPayPageSessionReader       Order Service GET /ors/payment-token/session/{id}
  mock     PaymentPort                            MockPaymentGateway             Ignite Payment Gateway authorize/capture/void/refund (OQ-3)
  mock     PassSalePort                           MockPassSale                   datatrak /pos/onlineSale.spr or gateway charge + POS record; pass issuance service (OQ-3, OQ-5)

== Demo 1 · First visit ==

  Run 1 — new visitor, save card ON (Taylor Kim, taylor.kim@example.com + mobile)
    ✓ identify → newVisitor (nothing on file)
    ✓ mock capture visa-4242 → ready (no PAN ever sent)
    ✓ terms accepted via checkbox; visit date defaults to club-local today 2026-09-10
    → COMPLETE · payment captured Visa 4242 · person.created true · wallet saved · sale finalized R-000001 · pass issued pass_b8aa77b7 · delivery sent t•••••@example.com
    ✓ purchase COMPLETE
    ✓ prospect persisted and card saved
    ✓ directory: 1 new prospect with both contacts (memberId 929bb362…)
    ✓ wallet: 1 new owner keyed by the member UUID (type MEMBER, club org)
    ✓ wallet: owner metadata exactly {"dt_clubNumber":"90030","dt_memberId":"929bb362-1d42-4e2b-9564-e5b9e2de6ece","dt_memberType":"PROSPECT"}
    ✓ wallet: 1 entry (Visa 4242) on that owner
    ✓ outbox: pass + receipt emailed to taylor.kim@example.com
    ✓ reload: POST /checkouts resumes the completed checkout with the purchase id
    ✓ reload: GET /purchases/:pid returns the sanitized result

  Run 2 — new visitor, save card OFF (Sam Lee, mobile + email)
    ✓ identify by phone → newVisitor
    → COMPLETE · payment captured Visa 4242 · person.created true · wallet not-requested · sale finalized R-000002 · pass issued pass_0a85aff0 · delivery sent (555) •••-3030
    ✓ purchase COMPLETE with wallet not-requested
    ✓ directory: prospect persisted with the second contact
    ✓ wallet: no owner, no entry, no wallet call at all
    ✓ delivery texted to the masked mobile

  Run 3 — Start again, then Taylor returns by the SECONDARY contact (mobile) and pays with the saved card
    ✓ DELETE /checkouts → revoked; only the safe contact hint returned
    ✓ revoked checkout id answers 404 (no cookie any more)
    ✓ identify 555-010-2020 → challenge (masked (555) •••-2020)
    ✓ verify with the mock code → recognized Taylor
    ✓ wallet by member id → the card saved in Run 1
    → COMPLETE · payment captured Visa 4242 · person.created false · wallet saved · sale finalized R-000003 · pass issued pass_549bdae7 · delivery sent (555) •••-2020
    ✓ purchase COMPLETE as the existing prospect (no duplicate record)
    ✓ receipt texted to the channel used this time

== Demo 2 · Returning visit ==

  Run 4 — Jordan Reyes, saved Visa 4242, card never re-entered
    ✓ identify jordan.reyes@email.com → challenge (masked j•••••@email.com)
    ✓ verify with the mock code → recognized Jordan
    ✓ person: typed channel in full, other channel masked
    ✓ wallet: Visa 4242 "Saved in the app last week"
    ✓ reload after verify rehydrates the recognized step
    → COMPLETE · payment captured Visa 4242 · person.created false · wallet saved · sale finalized R-000004 · pass issued pass_5b4bf88f · delivery sent j•••••@email.com
    ✓ purchase COMPLETE on the stored entry
    ✓ wallet: no write for a card already on file
    ✓ idempotent replay: same key → same result, one authorization

  Run 5 — Jordan, different card (Mastercard 4444), save ON → added to the EXISTING owner
    ✓ identify (555) 019-2231 → challenge (masked (555) •••-2231)
    ✓ verify with the mock code → recognized Jordan
    → COMPLETE · payment captured Mastercard 4444 · person.created false · wallet saved · sale finalized R-000005 · pass issued pass_69b3f873 · delivery sent (555) •••-2231
    ✓ purchase COMPLETE, Mastercard 4444 saved
    ✓ wallet: createOwner never called; entry added to the existing owner; 4242 untouched

  Run 6 — Jordan, different card, save OFF
    ✓ identify jordan.reyes@email.com → challenge (masked j•••••@email.com)
    ✓ verify with the mock code → recognized Jordan
    → COMPLETE · payment captured Mastercard 4444 · person.created false · wallet not-requested · sale finalized R-000006 · pass issued pass_e93abfee · delivery sent j•••••@email.com
    ✓ purchase COMPLETE, no wallet write, existing entries untouched

  Run 7 — decline (Morgan Blake, saved Visa 0002) then recovery with a new card
    ✓ identify morgan@example.com → challenge (masked m•••••@example.com)
    ✓ verify with the mock code → recognized Morgan
    → FAILED · payment declined Visa 0002 · person.created false · wallet not-requested · sale not-attempted  · pass not-attempted  · delivery not-attempted 
    ✓ decline reported truthfully; nothing sold or issued
    ✓ retry with a new card on the same checkout completes

  Run 8 — fault switch: wallet write fails after payment; wallet-only retry saves the card without a second charge
    ✓ identify jordan.reyes@email.com → challenge (masked j•••••@email.com)
    ✓ verify with the mock code → recognized Jordan
    → COMPLETE · payment captured Mastercard 4444 · person.created false · wallet failed-retryable · sale finalized R-000008 · pass issued pass_1af2e10a · delivery sent j•••••@email.com
    ✓ sale and pass complete; wallet failed-retryable; never "saved"
    ✓ wallet-retry → saved; no payment call made

== Summary ==
  checks: 47/47 passed
  mock directory: 9 people · wallet owners 5 · entries 8 · outbox 14 messages · sales 8 · passes 8
  hosted capture: skipped
```

## Hosted-capture run (`--hosted`)

Blocked at execution time (BLOCKERS B1): `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN` and `ABC_CORE_API_URL` are absent from the local BFF `.env`. The script reports:

```
== Hosted capture run (real Pay Page dev session; mock sale/wallet) ==
  BLOCKED (B1): missing PAY_PAGE_API_URL, PAY_PAGE_CLIENT_ID, PAY_PAGE_CLIENT_SECRET, PAY_PAGE_CONSUMER_ID, PAY_PAGE_ORIGIN, ABC_CORE_API_URL — hosted capture unverified
  hosted capture: blocked — "mock demo complete; hosted capture unverified"
```

With the variables present the run creates the pass-scoped session, prints its URL for a human to complete the hosted form in a browser, verifies that the generic `GET /api/pay-page/session/:id` refuses it, polls `GET /checkouts/:id/capture` for up to five minutes and then purchases from the BFF-side token. Gate G4 stays **pending** until that run is recorded.

## Browser demo (UI on :3001, BFF on :3000)

1. `repos/online-join-bff/.env` (gitignored) carries `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001`, `OJ_UI_URL=http://localhost:3001/`.
2. `npm start` in both repos; open `http://localhost:3000/signup/day-pass?club=90030` (through the BFF so the cookie, CSRF and `window.featureFlags` are exercised). `?club=90031` renders the unavailable block (the catalog says `onlineProspects=false`), `?club=90033` is Core Health and Fitness Club — South at $25.00.
3. Demo 2: type `jordan.reyes@email.com` or `(555) 019-2231`, code `123456` (also shown as a test-mode hint), pay with the saved Visa 4242 or choose "Use a different card" and a test card from the mock capture slot. Demo 1: type any unknown contact, fill the name and optional second contact, pick a test card, accept the terms, pay; then Start again and type the second contact.
4. The URL moves to `/signup/pass?club=90030` on completion; reloading it recovers the receipt; Start again returns to `/signup/day-pass`.

Verified 2026-09-10 with `curl` against the restarted dev BFF (`npm start`, Phase C+E build) and the restarted UI dev server (the Phase A proxy entries need a dev-server restart):

| Check | Result |
|---|---|
| `GET /signup/day-pass?club=90030` with `Accept: text/html` (the history fallback only rewrites HTML requests) | 200; the page serializes `window.featureFlags.oj_short_term_pass_checkout` (`{ value: true, … }`, the same object form the existing flags use) |
| `GET /signup/plan?club=90030` (existing signup entry) | 200 |
| `POST /api/short-term-pass/checkouts {clubNumber:'90030'}` with `Origin: http://localhost:3000` | 201; `Set-Cookie: OJ-PASS-SESSION=…; path=/; samesite=lax; httponly`; `Cache-Control: no-store`; Riverside club and $18.00 offer in the body |
| same for `90031` (`onlineProspects=false`) | 404 `NOT_FOUND` (gate refused server-side even though the flag override is on) |
| `POST /api/short-term-pass/checkouts` through the UI dev server `:3001` | 201 (proxied to the BFF) |

A visual pass at 1440/375 px in a real browser was **not** performed by the executor (no browser tooling in this session) and is left for the design gate.

## Receiving the one-time code and the pass as real emails (fake email service, 2026-09-10)

Codes are random in v2, so a human tester needs an inbox. The BFF can deliver every email to a local SMTP sink in addition to the in-memory outbox (`STP_EMAIL_TRANSPORT=smtp`; mock adapter mode only; refused in production; the platform email-publisher adapter is still L1).

1. Start Mailpit (Docker). Host port 2525 is used because macOS already listens on 1025:
   ```
   docker run -d --name stp-mailpit -p 2525:1025 -p 8025:8025 axllent/mailpit
   ```
2. In `repos/online-join-bff/.env`:
   ```
   STP_EMAIL_TRANSPORT=smtp
   STP_SMTP_URL=smtp://localhost:2525
   STP_EMAIL_FROM="Day Pass <no-reply@daypass.local>"
   ```
   then restart the BFF (`npm start`).
3. Open the inbox at **http://localhost:8025**. Every identify sends "Your {Club} one-time code" with the six digits; every completed purchase sends "Your 1-day pass at {Club} - {date}" with the pass id and receipt number. Any address works (nothing leaves the machine), e.g. `you@stp.test`.
4. The outbox route (`GET /api/short-term-pass/testing/outbox?checkoutId=`) and the demo script keep working unchanged; phone-channel messages stay outbox-only.

Verified 2026-09-10: the orchestrator smoke (`docs/validation/short-term-pass-sprint-0002-smoke.md`) ran with SMTP on — 13 emails in Mailpit (one code per identify, one pass per COMPLETE purchase), capability report shows `SmtpMailer` for `VerificationPort + DeliveryPort`.
