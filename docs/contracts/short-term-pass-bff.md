# Short-term pass (Day Pass) — BFF contract, adapter register and readiness

**Status:** contract **v2** frozen at Sprint 0002 task A2 (2026-09-10) — supersedes the v1 freeze of Sprint 0001 A1 (2026-09-09). Adapter register (Sprint 0001 C7) and readiness register (Sprint 0001 E5) updated by Sprint 0002 E5. v1 → v2 changes are listed in §4a.
**Source of truth for shapes:** `online-join-bff/src/routes/shortTermPass/schemas.ts` (ajv schemas + TypeScript types), mirrored by `online-join-ui/src/interfaces/api/shortTermPass.ts`.
**Source SHAs at the v2 freeze:** `online-join-ui` `a3c61b6`, `online-join-bff` `db81011` (both `prospect-wallet/sprint-0001`; the v2 code lands on the same branches), `mico` `5dad4d66` (read-only). v1 freeze SHAs: UI `f3242b1`, BFF `bc8a4bd`.
**Internal naming:** `ShortTermPass` / `shortTermPass` / `STP_*`. "Day pass" is UI copy only.

## 1. Scope recorded at A1

Ships: club-scoped flag + `onlineProspects` gate on both sides; `/signup/day-pass` shell; `/api/short-term-pass` router with an opaque server-side checkout session; identify → challenge → verify → bind to Ignite member UUID; pass-scoped Pay Page session; server-owned order; synchronous idempotent purchase orchestration; typed ports with deterministic stateful mocks; platform adapters for Pay Page session reads and (dark) wallet reads; tests to threshold; demo script; this document.

Does not ship: any change to MICO, universal-wallet, wallet-account-sync, datatrak, spring-cloud-config or `@abc/bff-toolkit`; real code delivery, prospect creation, pass sale or wallet write in any environment; multi-day passes; embedded (iframe) checkout; diagnostics panel; metrics.

## 2. Environment matrix

| Variable | mock (local / CI) | platform (dev) | production | Notes |
|---|---|---|---|---|
| `STP_ADAPTER_MODE` | `mock` | `platform` | `platform` or unset | Unset = feature disabled (every pass route 404, no secrets required). Production refuses `mock`. |
| `STP_LOCAL_FLAG_OVERRIDE` | `true` | unset | refused | Honoured only when `NODE_ENV === 'development'`. |
| `STP_SESSION_SECRET`, `STP_CODE_SECRET` | dev defaults | required | required | HMAC keys for session ids and one-time codes. |
| `STP_ALLOWED_ORIGINS` | `http://localhost:3000` | dev origin | required | Fail-closed Origin allowlist on every mutation. |
| `STP_CAPTURE_MODE` | `paypage` (default) or `mock` **only with `STP_TEST_HOOKS=true`** | `paypage` | `paypage` | v2: defaults to `paypage` in every mode; the boot guard refuses `mock` without hooks and refuses it outright in production (CR-03, CR-04). |
| `STP_TEST_HOOKS` | `true` for parity / agent runs | unset | refused | v2: enables mock capture, `GET /testing/outbox`, `GET /testing/state`, `POST /testing/reset` and `STP_TEST_CLOCK`. The testing router is mounted only when hooks are on; every testing route requires a loopback peer address **and** `X-STP-TEST-KEY`. |
| `STP_TEST_HOOKS_KEY` | random string | — | — | Required with hooks; compared in constant time. |
| `STP_TEST_CLOCK` | optional ISO instant | — | refused | v2: `deps.now()` starts at this instant and advances with wall time (frozen date, moving clock) so cooldowns and windows still elapse. |
| `STP_MOCK_OTP_CODE` | unit fixtures only | ignored | ignored | v2: the mock adapter issues a **random** six-digit code; this pin is honoured only when set explicitly (unit tests). Browser runs read the code from the outbox route. |
| `STP_MOCK_FAULTS` | optional | unset | refused | Test-harness fault switch (see §7). |
| `STP_WALLET_READS` | ignored | `false` until L3 | `false` | Platform wallet read adapter. |
| `STP_WALLET_WRITES` | ignored | `false` | `false` | Never true before the sibling backend sprint ships and L3 is signed. |
| `UNIVERSAL_WALLET_API_URL` | — | dev URL | prod URL | Platform wallet adapter. |
| `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN`, `ABC_CORE_API_URL` | — | required | required | Already read by the payPage route; reused by the pass-scoped session reader. **Not present in the local `.env` at execution time (see blockers).** |

Boot guard (`assertShortTermPassBootConfig`, called from `server.ts`): unknown mode → refuse; production + mock → refuse; production + override/faults → refuse; production or platform mode without secrets → refuse; production without origins → refuse; **v2:** production + `STP_TEST_HOOKS` / `STP_TEST_CLOCK` / `STP_CAPTURE_MODE=mock` → refuse; any mode with `STP_CAPTURE_MODE=mock` and hooks off → refuse; hooks on without `STP_TEST_HOOKS_KEY` → refuse; feature-off production always boots.

## 3. Gating

Every `/api/short-term-pass/*` route and the pass-scoped Pay Page session route run `requireShortTermPass`: resolve club (body `clubNumber` for `POST /checkouts`, the checkout record for everything else) → `ClubCatalogPort.resolveClub` → LaunchDarkly `oj-short-term-pass-checkout` evaluated with `{kind:'club', key:<5-digit padded>}` → `club.onlineProspects`. Any failure, missing data or thrown error → `404 {code:'NOT_FOUND'}`. The HTML entry point serializes `window.featureFlags.oj_short_term_pass_checkout` from the same evaluation with the validated `?club=` query; the UI treats it as a hint only.

Pay Page pads club numbers to six digits for its location lookup; LaunchDarkly pads to five. Both mappings are distinct and tested (`getClubFeatureFlagContext` vs `padClubNumber`).

## 4. Browser contract (`/api/short-term-pass`) — v2

Common rules: JSON bodies validated with ajv, `additionalProperties:false`; bodies never accept `memberId`, owner/user/entry ids, org/location ids, agreement metadata, price, terminal id, PG token, `pan`, `cvc`, `expiry`, `tokenId`. Every response is `Cache-Control: no-store` and carries `X-Correlation-Id`. Mutations require the `OJ-PASS-SESSION` cookie, the `X-STP-CSRF` header equal to the checkout's `csrfToken`, and an allowlisted `Origin`.

Error envelope: `{code, message, retryable, correlationId, retryAfterSeconds?, details?}`. Codes: `VALIDATION_FAILED` 400 · `NOT_FOUND` 404 · `CHECKOUT_EXPIRED` 401 (**v2: also for a missing or unknown cookie on a checkout route — P1-3**) · `NOT_VERIFIED` 401 · `CSRF_REJECTED` / `ORIGIN_REJECTED` / `FORBIDDEN` 403 · `STATE_CONFLICT` / `IDEMPOTENCY_CONFLICT` / `PURCHASE_IN_PROGRESS` 409 · `CODE_INVALID` / `CODE_EXPIRED` / `CHALLENGE_MISSING` 401 · `CHALLENGE_LOCKED` / `THROTTLED` 429 · `ORDER_NOT_READY` / `CAPTURE_NOT_READY` 409 · `UPSTREAM_UNAVAILABLE` 502/503 · `NOT_ENABLED` 501. **v2:** a 409 `STATE_CONFLICT` carries `details.reason` — `STALE_GENERATION` (another tab changed this checkout; P1-4), `CONSENT_REVISION` (documents or button text changed since the browser rendered them), `WAIVER_HASH` (waiver text changed) — and, for the consent reasons, `details.consent` (the refreshed `ConsentDocumentSet`).

**Generation (P1-4).** Every response that reflects checkout state carries `generation` (`POST /checkouts`, identify, verify, `PUT /order`, `DELETE /identity`). Requests to identify, verify, `PUT /order` and `POST /purchases` may carry `generation`; when present and different from the server's, the request is refused with 409 `STATE_CONFLICT` / `STALE_GENERATION` before anything changes. Identify, verify, `DELETE /identity` and revoke bump it.

| Method / path | Request | Response |
|---|---|---|
| `POST /checkouts` | `{clubNumber}` | `CreateCheckoutResponse` — `checkoutId`, `csrfToken`, `generation`, `captureMode: 'paypage'\|'mock'`, `adapterMode`, `testHooks: boolean`, `resumed`, `club` (`name`, `number`, `timezone`, `brand{word,tag}`, `locationLabel`, `links`), `offer` (`offerId`, `name`, `amountMinor`, `currency`, `perks`, `durationDays`), **`consent: ConsentDocumentSet`** (§6), `snapshot` (step + safe state for reload recovery, incl. `emailVerified` and the inline `challenge` when on code entry). Sets the cookie. With a live cookie for the same club the existing checkout is returned (`resumed:true`). `terms` is gone. |
| `POST /checkouts/:id/identify` | `{email, generation?}` | Always `{outcome:'challenge', generation, contact:{channel:'email', masked}, challenge:{expiresAt, resendAfter, attemptsRemaining, locked}}` for any syntactically valid, non-disposable email — **no directory call, identical key set, status (200) and 300 ms floor for known and unknown addresses** (CR-05, §5A.1). 400 `VALIDATION_FAILED` "Enter a valid email address." (phones are never identity) or "Use a permanent email address." (disposable domain). 429 `THROTTLED` with `retryAfterSeconds` at 5 sends per address per 60 min or 20 identifies per IP per 60 min, spanning checkouts and clubs; 429 `CHALLENGE_LOCKED` while the address is locked. `debug`, `altChannelAvailable` and `switch-channel` are removed. |
| `POST /checkouts/:id/challenge` | `{action:'resend'}` | `{generation, contact, challenge}` — 30 s cooldown (429 `THROTTLED`), same send limit and address lock as identify. |
| `POST /checkouts/:id/verify` | `{code, generation?}` \| `{retryLookup:true, generation?}` | Consumes the code atomically (challenge id and generation compared inside the store mutation; attempt counts written atomically), rotates the session cookie, sets `emailVerifiedAt`, **then** runs the directory lookup: unique → `{outcome:'recognized', generation, person, contact, order, consent}` (checkout bound to the member UUID + home club, order shell created); none → `{outcome:'newVisitor', generation, contact:{channel, display, masked}, order, consent}` (state `newVisitor`, order shell created, no member bound); more than one → `{outcome:'unresolved', generation, contact}` (state back to `identify`). Wrong code → 401 `CODE_INVALID` with `details.attemptsRemaining`; 5th wrong code → the **address** is locked 15 min (429 `CHALLENGE_LOCKED`, one generic message for verify and resend, `retryAfterSeconds`); expired → 401 `CODE_EXPIRED` "That code expired. Request a new one."; directory failure after consumption → 503 `UPSTREAM_UNAVAILABLE` (retryable) with the code already consumed; `{retryLookup:true}` re-runs only the lookup (state `verified`, at most 3 attempts) and answers one of the three outcomes. |
| `DELETE /checkouts/:id/identity` | — | `{ok:true, generation, contactHint?}` — challenge, verified email, binding, hosted sessions, order and consents revoked; the typed address is kept as the hint (Change / Edit). |
| `GET /checkouts/:id/wallet` | — | `{status:'ok', cards:[{selectionRef, brand, last4, source}]}` \| `{status:'unavailable'}` — recognized checkouts only; a `newVisitor` checkout (verified email, no member) answers 401 `NOT_VERIFIED`. |
| `PUT /checkouts/:id/order` | `{visitDate?, adult?, waiver?:{accepted, method?, renderedHash?}, saveCard?, marketingOptIn?, smsNoticeShown?, generation?}` | `{order, consent, generation}` — `order.consents` (§6) replaces `order.terms`; `consent` is the set re-rendered for the current date and amount (Pass Terms hash changes with the date). Waiver acceptance requires `method` (`checkbox`\|`modal`) and the `renderedHash` the browser displayed; a mismatch answers 409 `STATE_CONFLICT` / `WAIVER_HASH` "The Liability Waiver has been updated. Please read and accept it again." with the refreshed set and no acceptance recorded. `saveCard:true` records `storedCard.shownVersion`; `marketingOptIn` defaults `false` and changes only through this field; `smsNoticeShown:true` records the SMS notice version once. Preference changes update state only (no event per toggle). `order.ready = date valid && adult && (!waiver.required \|\| waiver.accepted)`. |
| `POST /checkouts/:id/consent-events` | `{type:'document-opened'\|'document-closed', documentId, renderedHash}` | `{ok:true, count}` — bounded availability evidence (max 50 events per checkout; older ones dropped, never an error). Opening is never acceptance or a gate. |
| `GET /checkouts/:id/capture?sessionId=` | — | `{payPageSessionId, status:'pending'\|'ready'\|'invalid'\|'closed', brand?, last4?}` — readiness only; the token never leaves the BFF. |
| `POST /checkouts/:id/capture/mock` | `{card}` | **404 unless `STP_TEST_HOOKS=true` and `STP_CAPTURE_MODE=mock`**; creates a checkout-owned mock session for a fixture card key; `{payPageSessionId, status, brand, last4}`. |
| `POST /checkouts/:id/purchases` | header `Idempotency-Key`; `{payment:{kind:'saved', selectionRef}\|{kind:'hosted', payPageSessionId}, attestation:{consentRevision, payButtonText}, profile?:{firstName, lastName, mobile}, generation?}` | `PurchaseResult` (§5): 201 for a new attempt, 200 for a replay. `validatePurchase` recomputes the consent set and refuses a stale `consentRevision` or a `payButtonText` different from the canonical one with 409 `STATE_CONFLICT` / `CONSENT_REVISION` (refreshed `consent` in `details`) **before any authorization**; the attestation is part of the request fingerprint. New visitors must send `profile` with a valid **mobile** ("Please add your mobile number." / "That mobile number doesn't look right."); it is stored as the prospect's phone. Other pre-checks as v1 (400/401/403/404/409 typed errors, no operation record). At `VALIDATED` the orchestrator writes one consent snapshot on the purchase record (§6); a replay writes nothing. |
| `GET /checkouts/:id/purchases/:pid` | — | `PurchaseResult` for refresh recovery. |
| `POST /checkouts/:id/purchases/:pid/wallet-retry` | — | `PurchaseResult`; retries only the wallet step with the **same** `walletProvidedId` and consent metadata; never authorizes, sells or issues again. |
| `DELETE /checkouts/:id` | — | `{ok:true, contactHint?}`; cookie cleared; durable operation records kept. |
| `POST /api/pay-page/session/short-term-pass` | `{checkoutId}` | `{url, sessionId, mode, status}` — due-today add-token session, `paymentMethods:['CARD']`, `deferAuthorizationToPayment:true`, `purpose:'short-term-pass'`, owned by the checkout; 501 `NOT_ENABLED` when `captureMode` is `mock`. Generic Pay Page routes refuse pass-purpose sessions. |
| `GET /api/short-term-pass/testing/outbox?checkoutId=` | header `X-STP-TEST-KEY`, loopback peer only | **Hooks only** (router mounted only when `STP_TEST_HOOKS=true`): `{messages:[{kind:'code'\|'pass', channel, destination, code?, passId?, receiptNumber?, sentAt}]}` for that checkout. 403 without loopback + key. Never in production (boot guard). |
| `GET /api/short-term-pass/testing/state?checkoutId=` | same | **Hooks only:** sanitized server state for the judge — `{checkout:{id, state, generation, emailVerified, contact?:{masked}, boundMember:boolean, order?}, purchases:[{purchaseId, state, checkpoint, payment, person, wallet, sale, pass, delivery, consents?, walletProvidedId?}], wallet:{owners:[{ownerId, externalId, organizationId, metadata}], entries:[{entryId, brand, last4, providedId?, metadata?}]}, outbox:[…]}`. No session keys, CSRF tokens, PG tokens or hosted session ids. |
| `POST /api/short-term-pass/testing/reset` | same | **Hooks only:** clears the in-memory send/identify limiters and address locks so a parity or agent run can reuse a fixture address; `{ok:true}`. Scope change recorded in the blockers file. |

### 4a. v1 → v2 changes (Sprint 0002 A2)

Removed: `POST /checkouts` `terms`; identify outcomes `newVisitor` / `ambiguous` and the `debug.code` echo; `challenge.altChannelAvailable`, `challenge.channel`; `challenge` action `switch-channel`; `order.terms` and `PUT /order {terms}`; `PurchaseProfile.secondaryContact`. Added: `generation` (response field + optional request field); `testHooks`; `consent: ConsentDocumentSet`; verify union with `retryLookup`; `order.consents`; `POST /consent-events`; `PurchaseRequest.attestation`; `PurchaseProfile.mobile` (required for new visitors); `PurchaseResult.consent`; the three hooks-only testing routes; checkout step `verified`; `snapshot.emailVerified`. Changed: identify request body `{contact}` → `{email}`; `PUT /order` response gains `consent`; missing cookie → 401 `CHECKOUT_EXPIRED`; mock capture 404 without hooks; `saveCard` defaults **false**.

## 5. Purchase result and state machine

```
PurchaseResult {
  purchaseId, state: 'COMPLETE'|'FAILED'|'RECONCILING'|'PROCESSING', checkpoint,
  failure?: {step, code, message, retryable},
  payment:  {status: authorized|captured|declined|voided|unknown|not-attempted|refunded, brand?, last4?},
  person:   {created, firstName?},
  wallet:   {status: saved|not-requested|failed-retryable|unavailable, brand?, last4?},
  sale:     {status: finalized|failed|not-attempted|refunded, receiptNumber?},
  pass:     {status: issued|not-issued|not-attempted, passId?, visitDate?, qrPayload?},
  delivery: {status: sent|pending|failed|not-attempted, channel?, masked?}
}
```

Checkpoints: `VALIDATED → AUTHORIZED → PERSON_PERSISTED → WALLET_RESULT → SALE_FINALIZED → ISSUED → COMPLETE`, plus `FAILED` and `RECONCILING`. The UI shows "Paid", "saved to your wallet" and "We emailed/texted it" only from the corresponding confirmed field.

Checkout steps (`snapshot.step`): `identify → challenge → recognized | newVisitor → complete`, plus `revoked`. Transitions are atomic in the store; `verify` consumes the challenge and rotates the session id; `DELETE /identity` returns to `identify`; `DELETE /checkouts/:id` → `revoked`. A `FAILED` purchase leaves the checkout on its step so the visitor can correct and retry (new key); a contact race at prospect creation resets the checkout to `identify`.

Orchestration order and failure handling (as executed, test-pinned in `routes/shortTermPass/__tests__/purchase.test.ts`): validate → authorize → persist prospect (new visitors; second contact stored as a lookup key) → consented wallet write (saved-card payments record `wallet.status:'saved'` without a write; `saveCard:false` → `not-requested`) → finalize sale + capture → issue (one bounded retry, then refund) → deliver (never blocks completion). Declined → `FAILED` with nothing persisted. Authorization timeout → one `status()` call by reference, never a second authorization; still unknown → `RECONCILING`. Prospect failure or contact race → void; unknown void → `RECONCILING`. Wallet failure → `failed-retryable` (write) or `unavailable` (owner resolution), sale continues, `wallet-retry` resumes only that step. Sale failure → void, prospect and saved card kept. Issuance failure → refund, `pass.status:'not-issued'`, `sale.status:'refunded'`. Delivery failure → `delivery.status:'failed'`, pass stays visible.

## 6. Order and consent rules (v2, CR-01 / CR-02 / CR-09, PRD §4.5, §5A.10)

Visit date is a calendar date (`YYYY-MM-DD`) in the club timezone; minimum club-local today (the default when the shell is created); maximum from the catalog when set; re-validated at purchase. Amounts are integer minor units + currency; the browser never computes price. `saveCard` defaults to **false** (§4.5 Tier 1) and is independent of every consent.

**Consent document set** (`ClubCatalogPort.getConsentDocuments(club, offer, {visitDate, todayIso})`):

```
ConsentDocument    { id:'waiver'|'passTerms'|'storedCard'|'privacy', title, templateVersion, renderedHash, html, meta, requiresAffirmativeAct, approval:'PROPOSED'|'APPROVED' }
ConsentNotice      { id:'emailTransactional'|'smsTransactional'|'marketingOptIn', copy, version }
ConsentDocumentSet { documents[4], notices[3], waiverRequired, payButtonText, consentRevision, approval }
```

Templates live in `services/shortTermPass/fixtures/consentTemplates.ts` as functions of `{legalName, brandWord, offerName, amount, dayLabel}` with the v1.2 `DOCS` text as the default **except** Pass Terms refunds (PRD D15/D22, approved delta AD-09). `renderedHash = sha256(title + meta + whitespace-normalised html)`; Pass Terms re-render when the visit date or amount changes. `payButtonText = "Pay $X.XX and get my pass"`. `consentRevision = sha256(every id:renderedHash, every notice id:version, the button text)`. Per-club overrides: `CatalogClub.consentOverrides[id] = {html, templateVersion, approval?}`; MICO `prospectTerms` maps to a `passTerms` override. `approval:'PROPOSED'` is carried in the fixture, the config and the capability report and never rendered to the customer (CF-02).

**Order consents** (`order.consents`, replaces `terms`):

```
adult          { attested, at? }                                   — server time on the affirmative act
waiver         { required, accepted, templateVersion, renderedHash, method?:'checkbox'|'modal', at? }
storedCard     { shownVersion, shownAt? }                          — set whenever save is switched on
marketingOptIn { optedIn:false|true, version, at? }                — its own record; never implied by notices
notices        { emailTransactional:{version, shownAt}, smsTransactional?:{version, shownAt} }
```

**Pay-time attestation.** Pass Terms and the Privacy Notice are accepted by the Pay tap against the canonical button text: the browser sends `attestation:{consentRevision, payButtonText}`; the server recomputes both and refuses a mismatch with 409 `STATE_CONFLICT` / `CONSENT_REVISION` before authorization. At `VALIDATED` one **consent snapshot** is written on `PurchaseRecord.consents`: `{surface:'web-online-join', checkoutId, capturedAt, memberId? (linked after person persistence), consentRevision, adult, waiver, storedCard? (when saving), marketingOptIn, notices, passTerms:{templateVersion, renderedHash, acceptedAt, payButtonText}, privacy:{templateVersion, renderedHash, acknowledgedAt, payButtonText}, ipHash, userAgentHash}`. A replay under the same key returns the stored result and writes nothing. `PurchaseResult.consent = {passTermsVersion, waiverVersion?, storedCardVersion?, marketingOptIn}`. The purchase record (in-memory by declaration) is the evidence store this sprint; a durable, exportable consent ledger is a readiness row (§10).

**Wallet entry metadata (CR-06).** A consented save writes the entry with a per-purchase UUID `providedId` (`PurchaseRecord.walletProvidedId`, allocated before the first attempt and reused by `wallet-retry`) and metadata exactly `{oj_storedCardConsentVersion, oj_storedCardConsentAt, oj_purchaseId}` (allowlist; prefix `oj_`, never `dt_*`). On a lost response the adapter reads back by `providedId` and verifies owner and token before treating a duplicate as success.

## 7. Fixture identities and fault switch (mock adapters)

| Person | Kind | Email | Phone | Card | Purpose |
|---|---|---|---|---|---|
| Jordan Reyes | prospect | `jordan.reyes@email.com` | `5550192231` | Visa 4242 "Saved in the app last week" | Riverside demo fixture, U6/U11 (changed from `m@m.com` by the 2026-09-09 addendum) |
| Casey Morgan | member | `casey@example.com` | `5550193344` | Mastercard 4444 "Saved at the front desk" | Member match, U15 |
| Riley Chen | prospect | `riley@example.com` | `5550195566` | none | No usable card, U14 |
| Dana Whitfield | prospect | `dana@example.com` | — | Visa 1111 expired | Expired card filtered → empty wallet, U14 |
| Morgan Blake | prospect | `morgan@example.com` | `5550190002` | Visa 0002 | Saved-card decline |
| Sam Patel / Alex Patel | prospects | `sam@example.com` / `alex@example.com` | both `5550197788` | none | Ambiguous phone, U9 |

Mock capture fixture cards: `visa-4242` (approved), `mastercard-4444`, `visa-0002` (declined), `visa-0003` (authorization timeout → status resolves authorized), `visa-1111-expired` (invalid token). Fixture clubs (addendum): `90030` **Riverside Athletic Club** (open; one product "1-day pass" USD 18.00, no perks; default demo club; all fixture people are homed here), `90031` Riverside — Eastside (`onlineProspects=false`), `90032` Riverside — Northside (club-authored terms, `America/New_York`), `90033` **Core Health and Fitness Club — South** (second organization; "Gym Floor" USD 25.00 with the day-pass.html perks; multi-club tests). Fixture UUIDs are fixed and valid. Mock purchase fixtures: receipts `R-000001…`, pass ids `pass_<8 hex>`, QR payload `STP1|<passId>|<club>|<visitDate>|<12-hex sig>`.

Fault switch (`STP_MOCK_FAULTS` at boot or the in-process `faultSwitch` used by tests and the demo): `decline`, `auth-timeout`, `prospect-failure`, `wallet-failure`, `wallet-unavailable`, `sale-failure`, `issue-failure`, `delivery-failure`, `void-unknown`. Never a browser API.

## 8. Adapter register (C7)

Selection: `services/shortTermPass/adapters/index.ts` builds the set once from `STP_ADAPTER_MODE`; `adapters.capabilities()` prints the honest capability table (used by the demo script and E5). Every live capability without an adapter fails closed with `NOT_ENABLED` (501), never a fixture success.

| Port | Mock that ships | Platform adapter this sprint | Real upstream it stands in for | Decision needed | Owner slot |
|---|---|---|---|---|---|
| `ClubCatalogPort` | `MockClubCatalog` (clubs 90030–90033, fixture offers, prototype terms template, `version = sha256(html)`) | `PlatformClubCatalog`: MICO `getClub` (name, `onlineProspects`, `prospectTerms`) + shared `LocationResolver` (org/location, TTL cache); offer still the fixture | MICO club settings; POS sale items for the offer and price | OQ-6 catalog, tax, timezone, terms review | PRODUCT |
| `CheckoutStorePort` | `InMemoryCheckoutStore` | same (process-local; production refuses mock mode) | shared atomic checkout store | OQ-7 | PLATFORM+BFF |
| `PurchaseStorePort` | `InMemoryPurchaseStore` (idempotency key + fingerprint, one active attempt per checkout) | same (process-local) | durable operation store with reconciliation owner | OQ-7 | PLATFORM+BFF |
| `IdentityDirectoryPort` | `MockIdentityDirectory` (seeded §7; created prospects persist for the process) | none → `NOT_ENABLED` | club-scoped lookup by phone/email (no MICO endpoint exists) | OQ-1 | IDENTITY |
| `ProspectPort` | `MockIdentityDirectory.create` (idempotent by purchase id; contact-race → `conflict`) | none → `NOT_ENABLED` | lean prospect creation from name + contacts | OQ-1 | IDENTITY |
| `VerificationPort` | `MockOutbox.send` (inspectable; codes never logged) | none → `NOT_ENABLED` | email-publisher-service + SMS provider | OQ-2 | IDENTITY+SECURITY |
| `DeliveryPort` | `MockOutbox.deliver` | none → `NOT_ENABLED` | email-publisher-service + SMS provider | OQ-2, OQ-5 | PASS/DELIVERY |
| `PaymentPort` | `MockPaymentGateway` (authorize/status/capture/void/refund; idempotent by purchase id; last4 0002 declines, 0003 times out) | none → `NOT_ENABLED` | Ignite Payment Gateway (token → PG token mapping, stored-card authorization without an agreement) | OQ-3 | PAYMENTS |
| `PassSalePort` | `MockPassSale` (receipt + pass + demo QR; idempotent by purchase id) | none → `NOT_ENABLED` | datatrak `/pos/onlineSale.spr` or gateway charge + POS record; issuance service | OQ-3, OQ-5 | PAYMENTS+PASS |
| `WalletPort` | `MockWallet` (owners keyed `(externalId, MEMBER, org)`, seeded cards, `providedId` idempotency) | `PlatformWallet`: reads behind `STP_WALLET_READS` (owner query + `GET /wallet-entry/credit-card?q=`), writes typed against `ICreateWalletOwner` / `ICreateWalletCreditCard` but `NOT_ENABLED` until `STP_WALLET_WRITES` | universal-wallet `/wallet-entry-owner`, `/wallet-entry/credit-card` | OQ-4; L3 (dedup-key deployment, owner-scoped rsql path) | WALLET |
| `PayPageSessionReader` | `MockPayPageSessionReader` (fixture token by session prefix; used with `MockCardCapture`) | `PlatformPayPageSessionReader` (OAuth client credentials via `OAuthTokenService`, `GET /ors/payment-token/session/{id}`); live in dev once the `PAY_PAGE_*` variables exist (BLOCKERS B1) | Order Service session API (already used by the payPage route) | credentials locally (B1) | PAYMENTS |

## 9. Spike outcomes (A6)

**A6(a) Pay Page hosted capture with dev credentials.** Blocked at execution time: `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN` and `ABC_CORE_API_URL` are absent from the BFF `.env` and from the environment of the running dev BFF (verified by key-name inspection only; no values printed). The existing payPage route therefore cannot create sessions locally either. The platform `PayPageSessionReader` is implemented against the same OAuth client-credentials flow and session API the payPage route already uses (`GET {PAY_PAGE_API_URL}/ors/payment-token/session/{id}` with `ABCFS-TENANT-ID`), reads `result.NEW_PAYMENT_METHOD.TOKEN[0]` (`id`, `creditCardBrand`, `accountNumberLastFour`/`creditCardNumberLastFour`, `expirationMonth/Year`, `accountHolderName`, `tokenStatus`) as the existing UI hook does, and is unit-tested with mocked fetch. Gate G4 stays pending: "mock demo complete; hosted capture unverified".

**A6(b) Owner-scoped wallet entry query.** `@abc/bff-toolkit` 11.29.1 `UniversalWallet` exposes `getAllWalletEntries({q, sort, page, size})` (rsql, `GET /wallet-entry?q=`) and `getWalletOwners({q})` (`GET /wallet-entry-owner?q=`) in addition to the deprecated QA-only `getWalletEntries(externalId)`. universal-wallet also exposes `GET /wallet-entry/credit-card?q=<rsql>` (paged, auto-filtered to `CREDIT_CARD`) — index leaf `repos/universal-wallet/walletentry/credit-card.md` L43. Decision: the platform adapter resolves the owner with `GET /wallet-entry-owner?q=externalId==<memberId>;ownerType==MEMBER` under the club organization tenancy (`ABCFS-TENANT-ID`), then lists entries with `GET /wallet-entry/credit-card?q=<owner-scoped rsql>`; no deprecated call, no assignment roles. Transport is `fetch` with the shared OAuth client-credentials service (same pattern as the payPage route) because this BFF does not bootstrap the toolkit's platform auth; the toolkit client would need `authorization.initialize` plus the ALS wiring that `server.ts` never runs. The exact owner-association rsql attribute path and whether the deployed dev universal-wallet accepts these queries for a `MEMBER` owner without agreement metadata are L3 evidence; the adapter stays behind `STP_WALLET_READS`.

**A6(c) LaunchDarkly access.** The dev SDK key in the BFF `.env` reaches the dev project. `oj-short-term-pass-checkout` does not exist yet: evaluation returned `{"value":false,"reason":{"kind":"ERROR","errorKind":"FLAG_NOT_FOUND"}}` for `{kind:'club', key:'90030'}`, i.e. the default `false` (fail closed). Handoff: create the flag (club kind, default off) — owner to be named at kickoff. Local runs use `STP_LOCAL_FLAG_OVERRIDE=true`.

## 10. Readiness register (E5)

Classification as of 2026-09-10 (executor). **Proven locally** = exercised end-to-end through the real router/orchestrator with mock adapters and pinned by tests; **contract only** = typed port, mock and (where noted) platform adapter exist, no live traffic; **blocked** = needs something outside this checkout. Owners are slots to be named at kickoff.

| Capability | Status | Evidence | Live gate | Owner slot |
|---|---|---|---|---|
| Club + flag gating on every pass route and the HTML entry | proven locally (flag via `STP_LOCAL_FLAG_OVERRIDE`; LD flag itself missing) | `requireShortTermPass.test.ts`, `static/__tests__/index.test.ts`; LD dev returns `FLAG_NOT_FOUND` (B2) | flag creation | PRODUCT / PLATFORM |
| Opaque checkout session, CSRF, Origin, expiry | proven locally (in-memory store) | `session.test.ts`, `checkouts.test.ts` | L4 shared store | PLATFORM+BFF |
| Contact lookup, one-time code, verify, member-id binding | proven locally against the mock directory; **no live identity service exists** | `identify.test.ts`, `verify.test.ts`, `challenge.test.ts` | L1 (OQ-1, OQ-2) | IDENTITY+SECURITY |
| Wallet reads by `(memberId, MEMBER, org)` | proven locally (mock); platform adapter typed, dark behind `STP_WALLET_READS`, owner-scoped rsql path unverified | `wallet.test.ts`, `platformWallet.test.ts` | L3 | WALLET |
| Wallet writes (owner + entry, allowlisted metadata, `providedId`) | proven locally (mock); platform adapter `NOT_ENABLED` until `STP_WALLET_WRITES` and the backend prospect lane ship | `walletWrites.test.ts`, `purchase.test.ts` U12/U13 | L3 | WALLET |
| Hosted card capture (Pay Page) | **blocked** — `PlatformPayPageSessionReader` and the pass-scoped session route are implemented and unit-tested; no credentials locally (B1); mock capture proven | `payPageSession.test.ts`, `payPage/__tests__/index.test.ts`, `session.test.ts`; demo `--hosted` → BLOCKED | G4 real run | PAYMENTS+QA |
| Authorization / capture / void / refund | contract only (mock gateway) | `purchaseMocks.test.ts`, `purchase.test.ts` failure table | L2 (OQ-3) | PAYMENTS |
| Prospect creation with second contact | contract only (mock directory) | `purchase.test.ts` U13 | L1 (OQ-1) | IDENTITY |
| Sale finalization, pass issuance, QR | contract only (mock) | `purchase.test.ts`, `purchaseMocks.test.ts` | L2 (OQ-3, OQ-5) | PAYMENTS+PASS |
| Code and pass delivery (email / SMS) | contract only (mock outbox) | `identify.test.ts`, `purchase.test.ts` | L1 (OQ-2) | IDENTITY / PASS-DELIVERY |
| Idempotent purchase, one active attempt, checkpoints, wallet-only retry | proven locally (in-memory operation store) | `idempotency.test.ts`, `purchase.test.ts` | L4 durable store + reconciliation owner (OQ-7) | PLATFORM+BFF |
| Redacted logging with correlation ids | proven locally | `log.test.ts`, demo output | — | BFF |
| Catalog (club, offer, price, timezone, terms) | fixture only; platform adapter reads club name/settings from MICO, offer stays fixture | `catalog.test.ts`, `platformCatalog.test.ts` | L5 (OQ-6) | PRODUCT |
| **Sprint 0002 — consent evidence** (adult, waiver version+hash+method, stored-card version, marketing opt-in, notices, pass terms + privacy by Pay with the exact button text; one snapshot per purchase) | proven locally: snapshot on `PurchaseRecord.consents`, in-memory by declaration; no durable ledger, no export | `order.test.ts`, `purchase.test.ts`, `consentEvents.test.ts`; smoke state 2026-09-10 | L4 durable consent ledger + retention/export | PRODUCT+LEGAL+PLATFORM |
| **Sprint 0002 — consent content (§4.5 templates)** | fixture templates with `approval:'PROPOSED'`; refund sentence follows PRD D15/D22 (v1.2 delta recorded); per-club override tested (90032) | `consentTemplates.test.ts` | L5 — CF-02 counsel approval of waiver, Pass Terms, stored-card disclosure, privacy notice | PM+LEGAL |
| **Sprint 0002 — CF-01 right-panel consent placement stays conspicuous** | build follows v1.2 (D42); counsel confirmation open | screenshots `docs/validation/screenshots/sprint-0002/*-05-consented-*` | L5 | PM |
| **Sprint 0002 — CF-03 owner for the OTP sink and the sandbox test-card list** | outbox route and fixture cards exist; no named owner | `testingRoutes.test.ts`, `TestCardPanel` | — | PM (QA/TOOLING and PAYMENTS provisional) |
| **Sprint 0002 — wallet-write enablement checklist** | not run (dev wallet not configured locally) | steps: `STP_ADAPTER_MODE=platform` with mock payment/sale, `STP_WALLET_WRITES=true`, `UNIVERSAL_WALLET_API_URL`, OAuth authorities, deployed dedup fix (hazard #10), owner-scoped rsql path verified, `pgToken` mapping, acceptance of `oj_*` entry metadata and a UUID `providedId` on `POST /wallet-entry/credit-card` for a MEMBER owner without agreement metadata, read-back `GET /wallet-entry/credit-card/{providedId}` under the owner tenancy, smoke with fixture Jordan | L3 | WALLET |
| **Sprint 0002 — D24 waiver reuse per person and club** | not built (always presented); acceptance recorded per purchase | `order.test.ts` | L4/L5 | PRODUCT+IDENTITY |
| **Sprint 0002 — recognized-buyer marketing preference; recognized person without a mobile** | opt-in shown to new visitors only; BFF ignores `profile` on a recognized checkout (fixture persons all have a mobile) | `NewVisitorStep.test.tsx`, `purchaseOrchestrator.ts` | L1/L5 | PRODUCT+IDENTITY |
| **Sprint 0002 — test hooks** (`STP_TEST_HOOKS`: mock capture, `/testing/outbox`, `/testing/state`, `/testing/reset`, `STP_TEST_CLOCK`) | proven locally; production boot refuses; router-stack 404 with hooks off; loopback + key | `testingRoutes.test.ts`, `config.test.ts` | — | BFF+QA |
| **Sprint 0002 — email transport: publisher (route AMZ → aws-email-engine)** | built 2026-09-10 (user request): `EmailPublisherMailer` posts `EmailEngineRequest` to email-publisher-service `POST /email/send` with `route:"AMZ"`; "Sent" = queued; whitelist and validation applied by aws-email-engine; platform-mode verification/delivery no longer `NOT_ENABLED` when configured | `emailPublisher.test.ts`, `adapters.test.ts`, `config.test.ts`; live attempt 2026-09-10 refused — dev publisher ingress 503 `N503` for every request (service down or not exposed externally) | L1 (OQ-2): dev publisher availability; billing code and sender confirmation; receiver-domain whitelist for test addresses | IDENTITY + PLATFORM |
| **Sprint 0002 — email transport (SMTP/Mailpit lane)** | built 2026-09-10 (user request): `SmtpMailer` behind `STP_EMAIL_TRANSPORT=smtp` delivers code and pass emails to a local sink (Mailpit :2525 / inbox :8025) while the mock outbox keeps recording; mock adapter mode only, refused in production; not the platform email-publisher adapter | `smtpMailer.test.ts`, `adapters.test.ts`, `config.test.ts`; 13 emails observed in the 2026-09-10 smoke | L1 (OQ-2) | IDENTITY |
| UI flow per the Design HTML v1.2 (Sprint 0002; supersedes the Riverside-demo row) | proven locally: jest against contract v2 with the service mocked + orchestrator browser smoke through the BFF (4 purchases, 5 phone widths); parity loop and agent runs deferred | `online-join-ui/__tests__/routes/ShortTermPass/**`, `docs/validation/short-term-pass-sprint-0002-smoke.md` | S2 parity loop (deferred), S5 hosted run (B1) | DESIGN / UI |
| UI flow per the Riverside demos with the kept terms gate (Sprint 0001, superseded) | proven locally against the contract (mocked service) + HTTP smoke through the dev BFF; browser visual pass not done | `online-join-ui/__tests__/routes/ShortTermPass/**`, `docs/validation/short-term-pass-ui.md` | G2 design sign-off | DESIGN / UI |

Completion vocabulary for this sprint: **sprint implementation complete; local checkout complete; live integration blocked** — and, for G4, **"mock demo complete; hosted capture unverified"**.
