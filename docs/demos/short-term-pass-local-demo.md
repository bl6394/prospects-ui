# Short-term pass (Guest Pass) — local demo script

**Sprint 0004 B13 (contract v4).** The demo drives the real BFF router and purchase orchestrator over HTTP (cookies, CSRF, Origin) with the mock adapter set, asserts API results and inspects mock state directly (directory, wallet owners / entries, gateway calls, sales, outbox, pending compensations). Copy is never used as evidence. Every line it prints is **mock proof**: the fault switch, the fixture catalog and the labelled stand-in prospect email are the harness — nothing here is a live DataTrak read, a real charge or a pilot verdict.

## Run it

```
cd repos/online-join-bff
npm run demo:short-term-pass              # Demo 0–6, exit 0 only when every check passes
npm run demo:short-term-pass -- --hosted  # + one real Pay Page hosted-capture run (needs PAY_PAGE_* / ABC_CORE_API_URL in .env)
```

The script is `scripts/short-term-pass-demo.ts`, compiled by `npm run build` into `dist/scripts/`. It sets `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=mock`, `STP_TEST_HOOKS=true`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_CATALOG_SOURCE=fixture` and `STP_ALLOWED_ORIGINS` when they are absent, boots an in-process Koa app on an ephemeral port with the same body middlewares as `server.ts`, mounts the pass router and the payPage router, and reads every one-time code from the outbox (v4 codes are random; `STP_MOCK_OTP_CODE` exists only for unit fixtures and dev). It resets the identify and purchase limiters, the per-address send counters and the challenge limits before every demo, flips the in-process `faultSwitch` for the fault runs (never a browser API) and prints the four verdicts at the end.

## Runs

| Demo | What it proves | Use cases |
|---|---|---|
| 0 · One-time code for everyone | known and unknown addresses answer the same shape; `expiresAt` = issue + 5 min (D58); a phone number and a disposable domain are 400; the 3rd send inside the hour is 429 (D59); no cookie → 401 | CR-05, D58, D59 |
| 1 · Riverside new visitor | `POST /checkouts` v4 (one item "Day Pass" $18.00, no v3 vocabulary); identify → challenge; verify → newVisitor; order shell with `useBy` = club-local today and no date field; Pass Terms 2026-09.3 sentence; waiver + marketing; create **before** pay; COMPLETE with `beginDate = expirationDate = today`, `visits 1`; stand-in email (text + HTML, no image, no link) | U4, U5, U8, U16 |
| 2 · Kelly returning at Core South | three flagged items (3-visit and unflagged hidden), Flex Day Pass 7 days, repaint before pay, opt-in pre-filled from the directory, saved Visa 4242, COMPLETE with `expirationDate = today + 6` | U1, U3, U6, U12, U13 |
| 3 · New visitor decline | Visa 0002 → FAILED at authorize, prospect created then **deactivated**, no sale, no wallet write; retry with Visa 4242 on the same checkout completes under a new purchase id; no duplicate person | U9, U15 |
| 4 · Kelly decline | fault `decline` → FAILED, the repainted record **reverted**, never deactivated | U12, R5 |
| 5 · Priya | expired saved card listed with `expired:true`, refused at Pay (400), the hosted slot completes | U14 |
| 6 · Deactivate failure | fault `deactivate-failure` → RECONCILING (`failure.step deactivate`, `person.deactivated:false`); a second Pay → 409 `PURCHASE_IN_PROGRESS`; `POST …/compensate` while the fault persists → still RECONCILING with attempts counted; after `faultSwitch.clear()` compensate retries **only** the deactivate → FAILED at `PERSON_DEACTIVATED`; nothing pending → 409; U24 the 11th purchase from one IP → 429 | U10, U24 |

## Recorded run (2026-09-18, `online-join-bff` `0589049`, mock adapters) — 58 / 58

Log lines (`info` / `warn` from the BFF logger) are stripped; every `✓` is a script assertion.

```
Guest Pass demo (contract v4) · adapter mode mock · capture mode mock · 2026-09-18T03:53:54.416Z

Capability report:
  mock     ClubCatalogPort                        MockClubCatalog                DataTrak service layer: getClubDefaultExternal.spr (name, prospects, prospectTerms, waiver text, timezone) + saleItems.spr with the guest-pass fields (CF-13/CF-14)
  mock     CheckoutStorePort                      InMemoryCheckoutStore          shared atomic checkout store + §5A.1 address lock (live gate L4)
  mock     PurchaseStorePort                      InMemoryPurchaseStore          durable operation store with idempotency keys (live gate L4)
  mock     IdentityDirectoryPort + ProspectPort   MockIdentityDirectory          club-scoped lookup by contact; DataTrak /member/addProspect.spr with begin / expiration / visits / opt-in / item, plus update, deactivate (CF-15)
  mock     VerificationPort + DeliveryPort        SmtpMailer                     email-publisher-service (OQ-2); the DataTrak prospect email (stand-in); SMS still outbox-only
  mock     WalletPort                             MockWallet                     universal-wallet /wallet-entry-owner and /wallet-entry/credit-card
  mock     PayPageSessionReader                   MockPayPageSessionReader       Order Service GET /ors/payment-token/session/{id}
  mock     PaymentPort                            MockPaymentGateway             Ignite Payment Gateway authorize/capture/void/refund (OQ-3)
  mock     PassSalePort                           MockPassSale                   datatrak /pos/onlineSale.spr — product sale against the prospect (OQ-3)

Sprint 0004 notes (the honest lines the register reads):
  catalog source       MockClubCatalog — STP_CATALOG_SOURCE=fixture; v1 filter skipped: 90033:core-3-visit-pass (multi-visit), 90033:core-towel-service (not-flagged)
  prospect writes      MockIdentityDirectory (mock) — club-scoped lookup by contact; DataTrak /member/addProspect.spr with begin / expiration / visits / opt-in / item, plus update, deactivate (CF-15)
  code + stand-in mail SmtpMailer — OTP template: built-in; prospect email: labelled stand-in, text + HTML, no image part, no link
  live DataTrak read   blocked (CF-13 fields absent, CF-14 member-scoped query) — this run is mock proof only

== Demo 0 · One-time code for everyone (CR-05, D58, D59) ==
    ✓ known and unknown addresses answer the same status, outcome and key set
    ✓ challenge.expiresAt is issue + 5 minutes (D58) — the UI counts it down beside the 30 s resend cooldown
    ✓ the unknown address received a code too (nothing about it is revealed before the code is proven)
    ✓ a phone number is never identity (400)
    ✓ a disposable domain is refused as address validation (400)
    ✓ the 3rd send to one address inside the hour is 429 THROTTLED (retry after 3599s) — D59
    ✓ a request without the cookie answers 401 CHECKOUT_EXPIRED (P1-3)

== Demo 1 · Riverside new visitor: create BEFORE pay, one-day window, stand-in email (U4, U5, U8, U16) ==
    ✓ POST /checkouts (contract v4): one flagged item "Day Pass" $18.00 · "One time use only, valid today"
    ✓ POST /checkouts: no v3 vocabulary (QR, link, date, 18+) in the response
    ✓ identify taylor.kim@example.com → challenge (masked t•••••@example.com); no code in the response
    ✓ verify with the emailed code → newVisitor
    ✓ order shell has no date field: contractDays 1, visits 1, useBy 2026-09-17 (club-local today), waiver not yet accepted, marketing unchecked
    ✓ Pass Terms 2026-09.3: "Day Pass to Riverside Athletic Club. One time use only, valid today · use by Thu, Sep 17. …"
    ✓ a stale client sending a start date or the 18+ flag is refused (400) — the fields no longer exist
    ✓ mock capture visa-4242 → ready (no PAN ever sent)
    ✓ Pay before the waiver → 409 ORDER_NOT_READY (the waiver is the only gate — no 18+ step, D66)
    ✓ waiver accepted (version 2026-09.1, modal) → order ready; marketing stays an explicit false
    → COMPLETE (COMPLETE) · payment captured Visa 4242 · person created=true · wallet saved · sale finalized R-000001 · pass issued 2026-09-17→2026-09-17 ×1 · delivery sent/bff-stand-in t•••••@example.com
    ✓ purchase COMPLETE: pass = {label "Day Pass", beginDate 2026-09-17, expirationDate 2026-09-17, visits 1} — a one-day pass begins and expires today
    ✓ POST /purchases: no v3 vocabulary (QR, link, date, 18+) in the response
    ✓ directory: 1 new prospect with access {2026-09-17 → 2026-09-17, visits 1, active}, a DataTrak-style barcode and marketingOptIn=false (D62, D67)
    ✓ the record was created BEFORE the authorization (D65 order: PERSON_PERSISTED → AUTHORIZED → WALLET → SALE → COMPLETE)
    ✓ wallet: one owner keyed by the member UUID with exactly the allowlisted metadata and one entry (saved only after AUTHORIZED)
    ✓ outbox: the labelled stand-in for the DataTrak prospect email — barcode as text, dates, receipt; no QR, no link (D63)
    ✓ idempotent replay: same key → identical stored result, no second create, authorization or email
    ✓ reload: POST /checkouts resumes the completed checkout; GET /purchases/:pid recovers the identical result

== Demo 2 · Kelly returning at Core South: three flagged items, 7-day pass, repaint before pay (U1, U3, U6, U12, U13) ==
    ✓ three eligible items in catalog order (Day Pass $25.00 / 1d, Flex Day Pass $30.00 / 7d, Anytime Day Pass $35.00 / 30d); the 3-visit and unflagged items are absent (D72)
    ✓ PUT /offer core-flex-pass → Pay $30.00; Pass Terms "Flex Day Pass to Core Health and Fitness Club. One time use only, valid for 7 days · use by Wed, Sep 23. …"
    ✓ identify m@m.com → challenge (masked m•••@m.com); no code in the response
    ✓ verify with the emailed code → recognized Kelly
    ✓ order shell for the 7-day item: useBy 2026-09-23 (today + 6); Kelly's known marketing opt-in pre-filled without a fresh act (U13)
    ✓ wallet: Visa 4242, expired:false
    ✓ waiver re-accepted on the returning lane (D53); Pass Terms attested on the Pay tap
    → COMPLETE (COMPLETE) · payment captured Visa 4242 · person created=false · wallet saved · sale finalized R-000002 · pass issued 2026-09-17→2026-09-23 ×1 · delivery sent/bff-stand-in m•••@m.com
    ✓ purchase COMPLETE: pass "Flex Day Pass" 2026-09-17 → 2026-09-23, receipt item "Flex Day Pass", opt-in true on the snapshot
    ✓ directory: Kelly's record was repainted BEFORE payment from {2026-09-02, inactive} to {2026-09-17 → 2026-09-23, active} (D53, D62)
    ✓ Kelly purchase: no v3 vocabulary (QR, link, date, 18+) in the response

== Demo 3 · New visitor decline → deactivate → retry with another card, no duplicate (U9, U15) ==
    ✓ identify dee.cline@example.com → challenge (masked d•••••@example.com); no code in the response
    ✓ verify with the emailed code → newVisitor
    → FAILED (FAILED) · payment declined Visa 0002 · person created=true deactivated=true · wallet not-requested · sale not-attempted  · pass not-attempted · delivery not-attempted/bff-stand-in
    ✓ confirmed decline → the record created before payment is deactivated → FAILED {person.created, person.deactivated}; nothing sold, nothing issued
    ✓ directory: the new record exists once and is inactive (2026-09-17, active=false)
    ✓ save-card was on, yet nothing was written to the wallet (CR-06: only after AUTHORIZED)
    → COMPLETE (COMPLETE) · payment captured Visa 4242 · person created=false · wallet saved · sale finalized R-000003 · pass issued 2026-09-17→2026-09-17 ×1 · delivery sent/bff-stand-in d•••••@example.com
    ✓ "Try another card": the same checkout resolves the known (inactive) record, repaints it and completes — no duplicate person

== Demo 4 · Kelly decline → revert (U12, R5) ==
    ✓ identify m@m.com → challenge (masked m•••@m.com); no code in the response
    ✓ verify with the emailed code → recognized Kelly
    → FAILED (FAILED) · payment declined Visa 0002 · person created=false reverted=true · wallet not-requested · sale not-attempted  · pass not-attempted · delivery not-attempted/bff-stand-in
    ✓ confirmed decline on a repainted record → revert → FAILED {person.reverted:true}
    ✓ directory: Kelly's window is back to what it was before this attempt (2026-09-17 → 2026-09-23, active=true)

== Demo 5 · Priya: expired saved card listed, refused at Pay, hosted slot completes (U14) ==
    ✓ identify priya@example.com → challenge (masked p••••@example.com); no code in the response
    ✓ verify with the emailed code → recognized Priya
    ✓ GET /wallet: Mastercard 5454 listed with expired:true (chip disabled in the UI)
    ✓ POST /purchases with the expired card → 400 "That card has expired. Add a different card." — nothing authorized, no record
    → COMPLETE (COMPLETE) · payment captured Visa 4242 · person created=false · wallet not-requested · sale finalized R-000004 · pass issued 2026-09-17→2026-09-17 ×1 · delivery sent/bff-stand-in p••••@example.com
    ✓ the hosted slot is the way through → COMPLETE
    ✓ U24: the 11th POST /purchases from one IP inside the hour is 429 THROTTLED (retry after 3600s); Cloudflare is the outer limit (V-P3)

== Demo 6 · Deactivate failure → RECONCILING → second Pay blocked → compensate (U10) ==
    ✓ identify re.concile@example.com → challenge (masked r•••••@example.com); no code in the response
    ✓ verify with the emailed code → newVisitor
    → RECONCILING (RECONCILING) · payment declined Visa 0002 · person created=true deactivated=false · wallet not-requested · sale not-attempted  · pass not-attempted · delivery not-attempted/bff-stand-in
    ✓ the deactivate fails twice (one immediate retry) → RECONCILING {failure.step:"deactivate"}, person.deactivated:false
    ✓ a second Pay on the checkout is refused while the purchase is unresolved (409 PURCHASE_IN_PROGRESS)
    ✓ POST …/compensate while the fault persists → still RECONCILING, attempts counted
    → FAILED (PERSON_DEACTIVATED) · payment declined Visa 0002 · person created=true deactivated=true · wallet not-requested · sale not-attempted  · pass not-attempted · delivery not-attempted/bff-stand-in
    ✓ once the adapter recovers, compensate retries ONLY the deactivate → FAILED at PERSON_DEACTIVATED with the decline restored; no create / authorize / sale replay
    ✓ nothing pending any more → 409

== Summary ==
  checks: 58/58 passed
  mock directory: 12 people · wallet owners 8 · entries 8 · outbox 13 messages · sales 4 · pending compensations 0
  hosted capture: skipped
  verdicts: (1) mock acceptance as printed above · (2) standalone host: not exercised here · (3) live DataTrak read blocked, prospect writes mock only · (4) pilot: not eligible
```
