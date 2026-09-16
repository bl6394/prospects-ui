# Short-term pass (Day Pass) — BFF contract, adapter register and readiness

**Status:** contract **v3** frozen at Sprint 0003 task A2 (2026-09-16) — supersedes the v2 freeze of Sprint 0002 A2 (2026-09-10) and the v1 freeze of Sprint 0001 A1 (2026-09-09). Adapter register (§8) and readiness register (§10) carry Sprint 0002 E5 plus the Sprint 0003 A2/A4 rows; Sprint 0003 E5 completes them. v1 → v2 and v2 → v3 changes are listed in §4a; v3 example payloads in §4b; A4 feasibility findings in §8a.
**Source of truth for shapes:** `online-join-bff/src/routes/shortTermPass/schemas.ts` (ajv schemas + TypeScript types), mirrored by `online-join-ui/src/interfaces/api/shortTermPass.ts`.
**Source SHAs at the v3 freeze:** `online-join-bff` `5915c96` and `online-join-ui` `d97afbe` on `prospect-wallet/sprint-0003` (branched off `53e549e` / `151846d`, the `prospect-wallet/sprint-0001` heads; fixtures follow in BFF `0121512` / UI `b6ae307`, feasibility in BFF `a3cdbfc`). v2 freeze SHAs: UI `a3c61b6`, BFF `db81011`; v1: UI `f3242b1`, BFF `bc8a4bd`; `mico` `5dad4d66` (read-only).
**v3 in one paragraph (Design v4, CR-10…CR-17):** the catalog's offers reach the browser (`offers[]`, `selectedOfferId`, compatibility `offer`) and a buyer picks one before any order exists (`PUT /checkouts/:id/offer`, `generation` required); validity is an inclusive club-local range (`durationDays`, `label`, `validUntil` on the order, the issued pass, the receipt and the `STP2` QR payload); Pass Terms `2026-09.2` names the label and the range and `consentRevision` binds the commercial fields; an immutable receipt snapshot is written at ISSUED; the pass credential leaves the done page and arrives by email as a server-rendered QR image plus a signed "View your pass" link (`pass.viewPath` on the creating 201 only, owner-only `GET`/`POST …/pass-link`) that opens a public, cookie-free `PassView` (`GET /passes/:token`, `GET /passes/:token/qr.png`). Types and ajv schemas landed at the freeze; route behaviour lands in Phase B (BFF) and Phase C (UI) against this document.
**Internal naming:** `ShortTermPass` / `shortTermPass` / `STP_*`. "Day pass" is UI copy only.

## 1. Scope recorded at A1

Ships: club-scoped flag + `onlineProspects` gate on both sides; `/signup/day-pass` shell; `/api/short-term-pass` router with an opaque server-side checkout session; identify → challenge → verify → bind to Ignite member UUID; pass-scoped Pay Page session; server-owned order; synchronous idempotent purchase orchestration; typed ports with deterministic stateful mocks; platform adapters for Pay Page session reads and (dark) wallet reads; tests to threshold; demo script; this document.

Does not ship: any change to MICO, universal-wallet, wallet-account-sync, datatrak, spring-cloud-config or `@abc/bff-toolkit`; real code delivery, prospect creation, pass sale or wallet write in any environment; ~~multi-day passes~~ (Sprint 0003 adds 1/3/5-day fixture offers with provisional prices — CF-04); embedded (iframe) checkout; diagnostics panel; metrics.

**Sprint 0003 (v3) adds:** offer selection before an order exists; inclusive multi-day validity; Pass Terms `2026-09.2`; receipt snapshot; a process-local `PassCredentialStorePort` with HMAC capability tokens; public pass routes with their own rate limit and headers; a receipt-grade pass email with a `cid:` PNG on SMTP and a hosted PNG on the publisher; owner-only current-link and rotate-and-resend. It does **not** add a rotating QR or desk verifier (register row), live re-pricing after verify, staff surfaces, durable stores, or a live email proof (publisher 503).

## 2. Environment matrix

| Variable | mock (local / CI) | platform (dev) | production | Notes |
|---|---|---|---|---|
| `STP_ADAPTER_MODE` | `mock` | `platform` | `platform` or unset | Unset = feature disabled (every pass route 404, no secrets required). Production refuses `mock`. |
| `STP_LOCAL_FLAG_OVERRIDE` | `true` | unset | refused | Honoured only when `NODE_ENV === 'development'`. |
| `STP_PUBLIC_BASE_URL` (v3) | `http://localhost:3000` | dev origin | required when a real email transport is on | Origin a browser reaches the BFF at. Absolute links are built as `${STP_PUBLIC_BASE_URL}/signup/pass/<token>` (the UI's `BrowserRouter basename="/signup"`) and `${STP_PUBLIC_BASE_URL}/api/short-term-pass/passes/<token>/qr.png`; **never** derived from the `Host` header. See §8a(c). |
| `STP_PASS_LINK_SECRET` (v3) | dev default | required | required | Dedicated HMAC-SHA256 key for `pv1` pass-view tokens (≥ 32 random bytes; never `STP_SESSION_SECRET`). Boot guard (B5) refuses a missing or short secret whenever the pass routes are mounted outside mock mode. Never printed. |
| `STP_PASS_LINK_GRACE_HOURS` (v3) | `24` (default) | `24` | `24` | View-only grace after the club-local end of the last valid day (interview decision 2026-09-15; CF-06). Parsed as a non-negative number; default when unset. |
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

**v3 — public pass routes (`GET /passes/:token`, `GET /passes/:token/qr.png`).** No cookie, no CSRF, no `checkoutChain`. The club is resolved **from the credential record** (`clubNumber` stored at mint), then the same `requireShortTermPass` evaluation runs (flag + `onlineProspects`, fail closed). A club whose flag is off therefore also refuses retrieval of an already-issued pass — a rollout decision recorded as R13 / RQ-7, not an accident. The token HTML document (`/signup/pass/<token>`) is served by the SPA entry point without a flag hint; the page relies on the API gate alone.

## 4. Browser contract (`/api/short-term-pass`) — v3

Common rules: JSON bodies validated with ajv, `additionalProperties:false`; bodies never accept `memberId`, owner/user/entry ids, org/location ids, agreement metadata, price, terminal id, PG token, `pan`, `cvc`, `expiry`, `tokenId`. Every response is `Cache-Control: no-store` and carries `X-Correlation-Id`. Mutations on a checkout require the `OJ-PASS-SESSION` cookie, the `X-STP-CSRF` header equal to the checkout's `csrfToken`, and an allowlisted `Origin`. **v3:** the two public pass routes take none of these (see their rows) and add `Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex, nofollow` and, for the image, `X-Content-Type-Options: nosniff` on every response including errors; they never set a cookie.

Error envelope: `{code, message, retryable, correlationId, retryAfterSeconds?, details?}`. Codes: `VALIDATION_FAILED` 400 · `NOT_FOUND` 404 · `CHECKOUT_EXPIRED` 401 (**v2: also for a missing or unknown cookie on a checkout route — P1-3**) · `NOT_VERIFIED` 401 · `CSRF_REJECTED` / `ORIGIN_REJECTED` / `FORBIDDEN` 403 · `STATE_CONFLICT` / `IDEMPOTENCY_CONFLICT` / `PURCHASE_IN_PROGRESS` 409 · `CODE_INVALID` / `CODE_EXPIRED` / `CHALLENGE_MISSING` 401 · `CHALLENGE_LOCKED` / `THROTTLED` 429 · `ORDER_NOT_READY` / `CAPTURE_NOT_READY` 409 · `UPSTREAM_UNAVAILABLE` 502/503 · `NOT_ENABLED` 501. A 409 `STATE_CONFLICT` carries `details.reason` — `STALE_GENERATION` (another tab changed this checkout; P1-4), `CONSENT_REVISION` (documents, button text **or, v3, the commercial fields** changed since the browser rendered them), `WAIVER_HASH` (waiver text changed), **`OFFER_UNAVAILABLE` (v3: the selected offer is no longer in this club's catalog; `details.offers` carries the refreshed `OfferSummary[]` and `details.selectedOfferId` the new default — never a silent fallback to `offers[0]`)** — and, for the consent reasons, `details.consent` (the refreshed `ConsentDocumentSet`). A `STATE_CONFLICT` **without** `details.reason` carries customer copy (e.g. "Start again to choose a different pass.").

**Generation (P1-4, v3 rule).** Every response that reflects checkout state carries `generation` (`POST /checkouts`, identify, verify, `PUT /offer`, `PUT /order`, `DELETE /identity`). Requests to identify, verify, `PUT /order` and `POST /purchases` *may* carry `generation`; **`PUT /checkouts/:id/offer` must** (400 `VALIDATION_FAILED` without it). When present and different from the server's, the request is refused with 409 `STATE_CONFLICT` / `STALE_GENERATION` before anything changes. Identify, verify, `DELETE /identity`, revoke and — v3 — every **committed** offer edit and every committed order edit bump it, so an equal-generation stale write from another tab is refused (plan §1 concurrency; the sprint-wide mandatory-generation matrix is a register row). The offer stored on the checkout is read **inside** the same `CheckoutStore.update` that commits the order shell at verify / retryLookup, so a selection racing verify either lands first or is refused by the state check.

**Offer selection lifecycle (v3, CR-10).** `selectedOfferId` on `POST /checkouts` is the effective offer: the order's `offerId` once an order exists, else the choice stored on the checkout (`CheckoutRecord.selectedOfferId`, B1), else `offers[0]`. `PUT /offer` is accepted only in states `identify`, `challenge` and `verified` with no active purchase; once an order exists (`recognized`, `newVisitor`, `complete`) it answers 409 `STATE_CONFLICT` "Start again to choose a different pass." (v4 has no control to re-price after verify; Change — `DELETE /identity` — keeps the selection, Start again — `DELETE /checkouts/:id` + new checkout — restores the default). Every consent render (`POST /checkouts`, `PUT /offer`, verify, `PUT /order`, `POST /purchases` validation) uses the effective offer, never "the first catalog offer" (Sprint 0003 fact 1). `OfferSummary.label` ("1-day pass") is computed server-side from `durationDays`; `CatalogOffer.provisional` (CF-04) never reaches the browser.

| Method / path | Request | Response |
|---|---|---|
| `POST /checkouts` | `{clubNumber}` | `CreateCheckoutResponse` — `checkoutId`, `csrfToken`, `generation`, `captureMode: 'paypage'\|'mock'`, `adapterMode`, `testHooks: boolean`, `resumed`, `club` (`name`, `number`, `timezone`, `brand{word,tag}`, `locationLabel`, `links`), **v3 `offers: OfferSummary[]`** (this club's catalog in card order; `OfferSummary = {offerId, name, amountMinor, currency, perks, durationDays, label}`), **v3 `selectedOfferId`** (effective selection, see lifecycle above), `offer` (**compatibility**: the entry of `offers` whose id is `selectedOfferId`), `consent: ConsentDocumentSet` (§6, rendered for the effective offer), `snapshot` (step + safe state for reload recovery, incl. `emailVerified`, the inline `challenge` when on code entry and **v3 `offerId`** so a reload restores the checked card). Sets the cookie. With a live cookie for the same club the existing checkout is returned (`resumed:true`). |
| **`PUT /checkouts/:id/offer`** (v3) | `{offerId, generation}` — both required | `OfferResponse {selectedOfferId, offer, consent, generation}`; `generation` bumped on commit. States `identify` \| `challenge` \| `verified` only, no active purchase. 400 `VALIDATION_FAILED` for a malformed body or an `offerId` that is not in **this club's** catalog ("Choose one of the passes offered by this club."); 409 `STATE_CONFLICT` "Start again to choose a different pass." once an order exists or a purchase is in progress; 409 `STATE_CONFLICT` / `STALE_GENERATION` for a stale `generation` — nothing changes on any refusal. Persisted inside `CheckoutStore.update` with the state check; kept by `DELETE /identity`; gone with the checkout. Example §4b-1/2. |
| `POST /checkouts/:id/identify` | `{email, generation?}` | Always `{outcome:'challenge', generation, contact:{channel:'email', masked}, challenge:{expiresAt, resendAfter, attemptsRemaining, locked}}` for any syntactically valid, non-disposable email — **no directory call, identical key set, status (200) and 300 ms floor for known and unknown addresses** (CR-05, §5A.1). 400 `VALIDATION_FAILED` "Enter a valid email address." (phones are never identity) or "Use a permanent email address." (disposable domain). 429 `THROTTLED` with `retryAfterSeconds` at 5 sends per address per 60 min or 20 identifies per IP per 60 min, spanning checkouts and clubs; 429 `CHALLENGE_LOCKED` while the address is locked. `debug`, `altChannelAvailable` and `switch-channel` are removed. |
| `POST /checkouts/:id/challenge` | `{action:'resend'}` | `{generation, contact, challenge}` — 30 s cooldown (429 `THROTTLED`), same send limit and address lock as identify. |
| `POST /checkouts/:id/verify` | `{code, generation?}` \| `{retryLookup:true, generation?}` | Consumes the code atomically (challenge id and generation compared inside the store mutation; attempt counts written atomically), rotates the session cookie, sets `emailVerifiedAt`, **then** runs the directory lookup: unique → `{outcome:'recognized', generation, person, contact, order, consent}` (checkout bound to the member UUID + home club, order shell created); none → `{outcome:'newVisitor', generation, contact:{channel, display, masked}, order, consent}` (state `newVisitor`, order shell created, no member bound); more than one → `{outcome:'unresolved', generation, contact}` (state back to `identify`). Wrong code → 401 `CODE_INVALID` with `details.attemptsRemaining`; 5th wrong code → the **address** is locked 15 min (429 `CHALLENGE_LOCKED`, one generic message for verify and resend, `retryAfterSeconds`); expired → 401 `CODE_EXPIRED` "That code expired. Request a new one."; directory failure after consumption → 503 `UPSTREAM_UNAVAILABLE` (retryable) with the code already consumed; `{retryLookup:true}` re-runs only the lookup (state `verified`, at most 3 attempts) and answers one of the three outcomes. |
| `DELETE /checkouts/:id/identity` | — | `{ok:true, generation, contactHint?}` — challenge, verified email, binding, hosted sessions, order and consents revoked; the typed address is kept as the hint (Change / Edit). |
| `GET /checkouts/:id/wallet` | — | `{status:'ok', cards:[{selectionRef, brand, last4, source}]}` \| `{status:'unavailable'}` — recognized checkouts only; a `newVisitor` checkout (verified email, no member) answers 401 `NOT_VERIFIED`. |
| `PUT /checkouts/:id/order` | `{visitDate?, adult?, waiver?:{accepted, method?, renderedHash?}, saveCard?, marketingOptIn?, smsNoticeShown?, generation?}` | `{order, consent, generation}` — **v3 `OrderSummary` = `{offerId, offerName, amountMinor, currency, durationDays, label, visitDate?, validUntil?, minVisitDate, maxVisitDate?, consents, saveCard, ready}`**; `validUntil = visitDate + durationDays − 1` (inclusive club-local calendar days, §6) is recomputed on every date change; `minVisitDate`/`maxVisitDate` bound the **start** date and an out-of-range date is refused with the existing message, never clamped; committed edits bump `generation` (v3). `order.consents` (§6) replaces `order.terms`; `consent` is the set re-rendered for the current offer, date and amount (Pass Terms hash changes with the range). Waiver acceptance requires `method` (`checkbox`\|`modal`) and the `renderedHash` the browser displayed; a mismatch answers 409 `STATE_CONFLICT` / `WAIVER_HASH` "The Liability Waiver has been updated. Please read and accept it again." with the refreshed set and no acceptance recorded. `saveCard:true` records `storedCard.shownVersion`; `marketingOptIn` defaults `false` and changes only through this field; `smsNoticeShown:true` records the SMS notice version once. Preference changes update state only (no event per toggle). `order.ready = date valid && adult && (!waiver.required \|\| waiver.accepted)`. |
| `POST /checkouts/:id/consent-events` | `{type:'document-opened'\|'document-closed', documentId, renderedHash}` | `{ok:true, count}` — bounded availability evidence (max 50 events per checkout; older ones dropped, never an error). Opening is never acceptance or a gate. |
| `GET /checkouts/:id/capture?sessionId=` | — | `{payPageSessionId, status:'pending'\|'ready'\|'invalid'\|'closed', brand?, last4?}` — readiness only; the token never leaves the BFF. |
| `POST /checkouts/:id/capture/mock` | `{card}` | **404 unless `STP_TEST_HOOKS=true` and `STP_CAPTURE_MODE=mock`**; creates a checkout-owned mock session for a fixture card key; `{payPageSessionId, status, brand, last4}`. |
| `POST /checkouts/:id/purchases` | header `Idempotency-Key`; `{payment:{kind:'saved', selectionRef}\|{kind:'hosted', payPageSessionId}, attestation:{consentRevision, payButtonText}, profile?:{firstName, lastName, mobile}, generation?}` | `PurchaseResult` (§5): 201 for a new attempt, 200 for a replay. **v3:** `pass.{label, validUntil}` and `receipt` (§5) on every result; **`pass.viewPath` (`/signup/pass/<token>`) only on the creating 201** — attached by the route from the orchestrator's transient return, never written to the stored `result`, so a replayed 200, `GET /purchases/:pid` and `/testing/state` never carry it. `validatePurchase` recomputes the consent set and refuses a stale `consentRevision` or a `payButtonText` different from the canonical one with 409 `STATE_CONFLICT` / `CONSENT_REVISION` (refreshed `consent` in `details`) **before any authorization**; the attestation is part of the request fingerprint. New visitors must send `profile` with a valid **mobile** ("Please add your mobile number." / "That mobile number doesn't look right."); it is stored as the prospect's phone. Other pre-checks as v1 (400/401/403/404/409 typed errors, no operation record). At `VALIDATED` the orchestrator writes one consent snapshot on the purchase record (§6); a replay writes nothing. |
| `GET /checkouts/:id/purchases/:pid` | — | `PurchaseResult` for refresh recovery — **without** `pass.viewPath` (v3); the done page fetches the link with `GET …/pass-link`. |
| `POST /checkouts/:id/purchases/:pid/wallet-retry` | — | `PurchaseResult`; retries only the wallet step with the **same** `walletProvidedId` and consent metadata; never authorizes, sells, issues, mints or mails again. |
| **`GET /checkouts/:id/purchases/:pid/pass-link`** (v3) | — | Owner-only (the verified checkout that made the purchase, same ownership check as `wallet-retry`): `PassLinkResponse {viewPath, linkExpiresAt}` — the **current** link, no rotation, no email. 409 `STATE_CONFLICT` unless `pass.status === 'issued'`; 404 `NOT_FOUND` when no credential exists (mint failed — the pass is still issued, `delivery` reads `failed`). |
| **`POST /checkouts/:id/purchases/:pid/pass-link`** (v3) | — (empty body) | Owner-only rotate-and-resend, serialized per purchase: mint a new token → deliver the pass email again → **revoke the old token only when the transport accepts**; `PassLinkRotateResponse {viewPath, linkExpiresAt, delivery}` where `delivery` is the fresh `{status:'sent'\|'pending'\|'failed', channel, masked}`. A failed resend leaves the previous link valid and answers `delivery.status:'failed'` with the **old** `viewPath`. 3 per purchase per hour (429 `THROTTLED` + `retryAfterSeconds`, `WindowLimiter(3, ONE_HOUR_MS)`); 409 unless issued. |
| **`GET /passes/:token`** (v3, public) | no cookie, no CSRF, no `Origin` check; `:token` must match `^pv1\.[A-Za-z0-9_-]{32}\.\d{10}\.[A-Za-z0-9_-]{43}$` | 200 `PassView` (§5) built from the receipt snapshot, the club and club-local `today`; `qr` absent when `status:'expired'`. **One identical 404 `NOT_FOUND`** for malformed shape, bad signature, unknown id, revoked, past `linkExpiresAt`, club flag off or `onlineProspects:false`. Per-IP `WindowLimiter(60, FIFTEEN_MINUTES_MS)` → 429 `THROTTLED` with `retryAfterSeconds` (61st request). Headers on every response incl. errors: `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex, nofollow`; never `Set-Cookie`. Example §4b-4/5. |
| **`GET /passes/:token/qr.png`** (v3, public) | same | `image/png` (+ `X-Content-Type-Options: nosniff`) of the issued pass's static `qrPayload`, rendered server-side (`qrcode`, error correction M, margin 1, scale 6); same limiter, same identical 404; **404 when the pass is `expired`** (grace window shows dates, not the QR). Used by the publisher-path email `<img src>` and the page's `<noscript>`. |
| `DELETE /checkouts/:id` | — | `{ok:true, contactHint?}`; cookie cleared; durable operation records kept. |
| `POST /api/pay-page/session/short-term-pass` | `{checkoutId}` | `{url, sessionId, mode, status}` — due-today add-token session, `paymentMethods:['CARD']`, `deferAuthorizationToPayment:true`, `purpose:'short-term-pass'`, owned by the checkout; 501 `NOT_ENABLED` when `captureMode` is `mock`. Generic Pay Page routes refuse pass-purpose sessions. |
| `GET /api/short-term-pass/testing/outbox?checkoutId=` | header `X-STP-TEST-KEY`, loopback peer only | **Hooks only** (router mounted only when `STP_TEST_HOOKS=true`): `{messages:[{kind:'code'\|'pass', channel, destination, code?, passId?, receiptNumber?, sentAt, checkoutId?, label?, validUntil?, viewPath?}]}` for that checkout — **v3:** `kind:'pass'` messages record `label`, `validUntil` and the raw `viewPath` (the hooks outbox is the acknowledged fourth place a raw link appears, after the email, the creating 201 and the `pass-link` responses). 403 without loopback + key. Never in production (boot guard). |
| `GET /api/short-term-pass/testing/state?checkoutId=` | same | **Hooks only:** sanitized server state for the judge — `{checkout:{id, state, generation, emailVerified, contact?:{masked}, boundMember:boolean, selectedOfferId?, order?}, purchases:[{purchaseId, state, checkpoint, payment, person, wallet, sale, pass, delivery, consents?, receipt?, walletProvidedId?}], wallet:{owners:[…], entries:[…]}, outbox:[…]}`. No session keys, CSRF tokens, PG tokens, hosted session ids **or `pv1.` tokens** (v3: the leak scan in `testingRoutes.test.ts` is extended to the token prefix; `pass.viewPath` is stripped). |
| `POST /api/short-term-pass/testing/reset` | same | **Hooks only:** clears the in-memory send/identify limiters and address locks so a parity or agent run can reuse a fixture address; `{ok:true}`. Scope change recorded in the blockers file. |
| **`POST /api/short-term-pass/testing/passes/revoke?checkoutId=&purchaseId=`** (v3) | same | **Hooks only:** revokes the current credential of that purchase so the smoke can prove the identical 404 (`{ok:true, revoked:boolean}`). No public or staff revoke surface exists this sprint (register row). |

### 4a. Version changes

**v2 → v3 (Sprint 0003 A2, 2026-09-16).** Added: `CreateCheckoutResponse.offers[]` and `selectedOfferId` (compatibility `offer` **kept**, equal to the selected entry); `snapshot.offerId`; `OfferSummary.label`; `PUT /checkouts/:id/offer` (`OfferRequest {offerId, generation}` — the only route where `generation` is required; `OfferResponse`); `OrderSummary.{durationDays, label, validUntil}`; `PurchaseResult.pass.{label, validUntil, viewPath}` (`viewPath` on the creating 201 only); `PurchaseResult.receipt` (`PurchaseReceiptSummary`); `GET`/`POST …/purchases/:pid/pass-link` (`PassLinkResponse`, `PassLinkRotateResponse`); public `GET /passes/:token` (`PassView`) and `GET /passes/:token/qr.png`; hooks `POST /testing/passes/revoke`; outbox `kind:'pass'` fields `label`, `validUntil`, `viewPath`; `details.reason` `OFFER_UNAVAILABLE`; the `pv1` token shape (`PASS_TOKEN_PATTERN`, `isPassTokenShape`). Changed: committed offer and order edits bump `generation`; every consent render uses the effective offer; mock QR payload `STP1|passId|club|visitDate|sig` → `STP2|passId|club|visitDate|validUntil|sig`; Pass Terms template `2026-09.1` → `2026-09.2` and `consentRevision` binds the commercial line (§6); env rows `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS` (§2). Removed: nothing — v2 clients keep working against `offer` until the UI lane migrates (C1).

**v1 → v2 (Sprint 0002 A2).** Removed: `POST /checkouts` `terms`; identify outcomes `newVisitor` / `ambiguous` and the `debug.code` echo; `challenge.altChannelAvailable`, `challenge.channel`; `challenge` action `switch-channel`; `order.terms` and `PUT /order {terms}`; `PurchaseProfile.secondaryContact`. Added: `generation` (response field + optional request field); `testHooks`; `consent: ConsentDocumentSet`; verify union with `retryLookup`; `order.consents`; `POST /consent-events`; `PurchaseRequest.attestation`; `PurchaseProfile.mobile` (required for new visitors); `PurchaseResult.consent`; the three hooks-only testing routes; checkout step `verified`; `snapshot.emailVerified`. Changed: identify request body `{contact}` → `{email}`; `PUT /order` response gains `consent`; missing cookie → 401 `CHECKOUT_EXPIRED`; mock capture 404 without hooks; `saveCard` defaults **false**.

### 4b. v3 example payloads

**4b-1 — selection before any order exists** (`PUT /checkouts/chk_…/offer`, Core South checkout in state `identify`, generation 0):

```json
// request
{ "offerId": "day-pass-gym-floor-3", "generation": 0 }
// 200
{
  "selectedOfferId": "day-pass-gym-floor-3",
  "offer": { "offerId": "day-pass-gym-floor-3", "name": "Gym Floor", "amountMinor": 6000, "currency": "USD",
             "perks": ["Classes", "Steam & Sauna", "Basketball court"], "durationDays": 3, "label": "3-day pass" },
  "consent": { "documents": [ { "id": "passTerms", "templateVersion": "2026-09.2", "renderedHash": "…",
               "html": "…<p>3-day pass to Core Health and Fitness Club, valid Today – Fri, Sep 11. Price $60.00 including tax. …</p>…", "…": "…" }, "…" ],
               "notices": ["…"], "waiverRequired": true, "payButtonText": "Pay $60.00 and get my pass",
               "consentRevision": "…", "approval": "PROPOSED" },
  "generation": 1
}
```

**4b-2 — stale offer selection** (a second tab already changed the checkout; nothing changes):

```json
// request
{ "offerId": "day-pass-gym-floor-5", "generation": 0 }
// 409
{ "code": "STATE_CONFLICT", "message": "This checkout changed in another tab. Reload to continue.",
  "retryable": true, "correlationId": "…", "details": { "reason": "STALE_GENERATION" } }
```

and, when the stored selection has left the catalog by the time a consent set is rendered (e.g. `POST /checkouts` on resume after a fixture edit):

```json
// 409
{ "code": "STATE_CONFLICT", "message": "That pass is no longer offered. Choose another pass.",
  "retryable": false, "correlationId": "…",
  "details": { "reason": "OFFER_UNAVAILABLE", "selectedOfferId": "day-pass-gym-floor",
               "offers": [ { "offerId": "day-pass-gym-floor", "label": "1-day pass", "amountMinor": 2500, "…": "…" } ] } }
```

Selection after an order exists (state `recognized` / `newVisitor` / `complete`) or during an active purchase:

```json
// 409
{ "code": "STATE_CONFLICT", "message": "Start again to choose a different pass.", "retryable": false, "correlationId": "…" }
```

**4b-3 — changed waiver** (`PUT /checkouts/chk_…/order` accepting a waiver whose text changed since the shell was created; unchanged from v2, shown because the v3 `order` shape appears in the refreshed set's sibling response):

```json
// request
{ "waiver": { "accepted": true, "method": "checkbox", "renderedHash": "<hash the browser displayed>" }, "generation": 3 }
// 409
{ "code": "STATE_CONFLICT", "message": "The Liability Waiver has been updated. Please read and accept it again.",
  "retryable": true, "correlationId": "…",
  "details": { "reason": "WAIVER_HASH", "consent": { "documents": ["…"], "notices": ["…"], "waiverRequired": true,
               "payButtonText": "Pay $60.00 and get my pass", "consentRevision": "…", "approval": "PROPOSED" } } }
// a successful PUT /order afterwards answers
{ "order": { "offerId": "day-pass-gym-floor-3", "offerName": "Gym Floor", "amountMinor": 6000, "currency": "USD",
             "durationDays": 3, "label": "3-day pass", "visitDate": "2026-09-16", "validUntil": "2026-09-18",
             "minVisitDate": "2026-09-09", "consents": { "…": "…" }, "saveCard": false, "ready": true },
  "consent": { "…": "…" }, "generation": 5 }
```

**4b-4 — expired, revoked, tampered, unknown or malformed link** (`GET /passes/pv1.…` — one body for all five, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex, nofollow`, no `Set-Cookie`):

```json
// 404
{ "code": "NOT_FOUND", "message": "This link isn't valid.", "retryable": false, "correlationId": "…" }
```

**4b-5 — `PassView`** (`GET /passes/pv1.…` for Kelly's 3-day pass on club-local 2026-09-16; key set pinned by the leak test — no surname, full email, member / purchase / checkout id, card brand or last4):

```json
// 200
{
  "status": "active",
  "today": "2026-09-16",
  "pass": { "label": "3-day pass", "offerName": "Gym Floor", "visitDate": "2026-09-16", "validUntil": "2026-09-18" },
  "holder": { "firstName": "Kelly" },
  "club": { "name": "Core Health and Fitness Club — South", "legalName": "Core Health and Fitness Club",
            "brand": { "word": "CORE", "tag": "Health and fitness club" }, "locationLabel": "South",
            "address": "120 Riverside Ave, San Francisco, CA 94107", "timezone": "America/Chicago",
            "links": { "app": "https://example.com/core-app" } },
  "qr": { "kind": "static", "payload": "STP2|pass_7f3a91c2|90033|2026-09-16|2026-09-18|0f9d3c2b1a4e" },
  "receipt": { "receiptNumber": "R-000002", "item": "3-day pass · Gym Floor", "amountMinor": 6000, "currency": "USD" },
  "contact": { "masked": "m•••@m.com" },
  "linkExpiresAt": "2026-09-20T05:00:00.000Z"
}
```

On 2026-09-15 the same link answers `status:'upcoming'` with the QR; on 2026-09-19 (grace) `status:'expired'` **without** `qr`; from `linkExpiresAt` on, 4b-4. `linkExpiresAt` = club-local start of the day after `validUntil` + 24 h (2026-09-19 00:00 CDT = 05:00Z, + 24 h).

**4b-6 — creating purchase 201 (v3 fields only)**

```json
{ "purchaseId": "pur_…", "state": "COMPLETE", "checkpoint": "COMPLETE", "…": "…",
  "sale": { "status": "finalized", "receiptNumber": "R-000002" },
  "pass": { "status": "issued", "passId": "pass_7f3a91c2", "label": "3-day pass", "visitDate": "2026-09-16", "validUntil": "2026-09-18",
            "qrPayload": "STP2|pass_7f3a91c2|90033|2026-09-16|2026-09-18|0f9d3c2b1a4e", "viewPath": "/signup/pass/pv1.<id>.<exp>.<sig>" },
  "delivery": { "status": "sent", "channel": "email", "masked": "m•••@m.com" },
  "consent": { "passTermsVersion": "2026-09.2", "waiverVersion": "2026-09.1", "marketingOptIn": false },
  "receipt": { "receiptNumber": "R-000002", "item": "3-day pass · Gym Floor", "label": "3-day pass", "amountMinor": 6000,
               "currency": "USD", "visitDate": "2026-09-16", "validUntil": "2026-09-18", "purchasedAt": "2026-09-09T17:05:12.000Z" } }
```

## 5. Purchase result and state machine

```
PurchaseResult {
  purchaseId, state: 'COMPLETE'|'FAILED'|'RECONCILING'|'PROCESSING', checkpoint,
  failure?: {step, code, message, retryable},
  payment:  {status: authorized|captured|declined|voided|unknown|not-attempted|refunded, brand?, last4?},
  person:   {created, firstName?},
  wallet:   {status: saved|not-requested|failed-retryable|unavailable, brand?, last4?},
  sale:     {status: finalized|failed|not-attempted|refunded, receiptNumber?},
  pass:     {status: issued|not-issued|not-attempted, passId?, label?, visitDate?, validUntil?, qrPayload?, viewPath? (creating 201 only)},
  delivery: {status: sent|pending|failed|not-attempted, channel?, masked?},
  consent?: {passTermsVersion, waiverVersion?, storedCardVersion?, marketingOptIn},
  receipt?: {receiptNumber, item, label, amountMinor, currency, visitDate, validUntil, purchasedAt}      // v3
}

PassView {                                                                                                // v3, public
  status: 'upcoming'|'active'|'expired', today,
  pass: {label, offerName, visitDate, validUntil}, holder: {firstName},
  club: {name, legalName?, brand{word,tag}, locationLabel, address?, timezone, links{app?}},
  qr?: {kind:'static', payload},                    // absent when expired
  receipt: {receiptNumber, item, amountMinor, currency}, contact: {masked}, linkExpiresAt
}
```

Checkpoints: `VALIDATED → AUTHORIZED → PERSON_PERSISTED → WALLET_RESULT → SALE_FINALIZED → ISSUED → COMPLETE`, plus `FAILED` and `RECONCILING`. The UI shows "Paid", "saved to your wallet" and "We emailed/texted it" only from the corresponding confirmed field.

**v3 — receipt snapshot and credential (plan §3, §4).** At `ISSUED` the orchestrator writes an immutable `PurchaseRecord.receipt = {receiptNumber, offerId, item, label, amountMinor, currency, visitDate, validUntil, purchasedAt, seller:{legalName, address?}, paidWith?:{brand, last4}, firstName}` from the order, the sale, the payment and the person, then mints the pass credential (`PassCredentialStorePort.getOrCreateForPurchase`; record `{tokenId, purchaseId, clubNumber, linkExpiresAt, issuedAt, revokedAt?, rotations}`; token `pv1.<id>.<exp>.<sig>` = 24 random bytes base64url · `linkExpiresAt` epoch seconds · HMAC-SHA256(`STP_PASS_LINK_SECRET`, `pv1|pass-view|id|exp`) base64url, constant-time compare). The pass email, the public `PassView`, the current-link GET and the resend read the **snapshot**, never the checkout or the live catalog, so the page works after checkout expiry (30 min idle / 2 h) and after a catalog edit. `PurchaseResult.receipt` is the customer-safe subset; `paidWith` appears in the email receipt only. If minting fails the pass is still issued, `delivery` is `failed`, no link is advertised. Replay returns the stored result and the same link without a second charge or email; `wallet-retry` never mints or mails. Both stores are process-local by declaration (L4): a restart loses links and purchases alike.

Checkout steps (`snapshot.step`): `identify → challenge → recognized | newVisitor → complete`, plus `revoked`. Transitions are atomic in the store; `verify` consumes the challenge and rotates the session id; `DELETE /identity` returns to `identify`; `DELETE /checkouts/:id` → `revoked`. A `FAILED` purchase leaves the checkout on its step so the visitor can correct and retry (new key); a contact race at prospect creation resets the checkout to `identify`.

Orchestration order and failure handling (as executed, test-pinned in `routes/shortTermPass/__tests__/purchase.test.ts`): validate → authorize → persist prospect (new visitors; second contact stored as a lookup key) → consented wallet write (saved-card payments record `wallet.status:'saved'` without a write; `saveCard:false` → `not-requested`) → finalize sale + capture → issue (one bounded retry, then refund) → deliver (never blocks completion). Declined → `FAILED` with nothing persisted. Authorization timeout → one `status()` call by reference, never a second authorization; still unknown → `RECONCILING`. Prospect failure or contact race → void; unknown void → `RECONCILING`. Wallet failure → `failed-retryable` (write) or `unavailable` (owner resolution), sale continues, `wallet-retry` resumes only that step. Sale failure → void, prospect and saved card kept. Issuance failure → refund, `pass.status:'not-issued'`, `sale.status:'refunded'`. Delivery failure → `delivery.status:'failed'`, pass stays visible.

## 6. Order and consent rules (v2 CR-01 / CR-02 / CR-09; v3 CR-11 / CR-17; PRD §4.5, §5A.10)

Visit date is a calendar date (`YYYY-MM-DD`) in the club timezone; minimum club-local today (the default when the shell is created); maximum from the catalog when set (`maxDaysAhead` bounds the **start** date); re-validated at purchase, including a midnight rollover. Amounts are integer minor units + currency; the browser never computes price. `saveCard` defaults to **false** (§4.5 Tier 1) and is independent of every consent.

**v3 — validity range (CR-11, CF-05).** `validUntil = visitDate + durationDays − 1`: inclusive club-local calendar days (a 3-day pass from 2026-09-10 ends 2026-09-12; a 1-day pass ends on its start date). One BFF helper, `services/shortTermPass/validity.ts` (`validUntilOf`, `validityLabel`, `dateFieldLabelOf`, `durationLabelOf`, `linkExpiresAtOf`, `zonedMidnightOf`, `passStatusOn`), is the only place the rule lives (RQ-2: hours vs days is a one-file change); the UI formatter (C3) is pinned against the same fixtures. Labels: 1-day "Today · Wed, Sep 9" / "Wed, Sep 16"; multi-day "Today – Fri, Sep 11" / "Wed, Sep 16 – Fri, Sep 18" (en dash U+2013 with spaces; "Today" only when the club-local today is passed — durable surfaces such as the email and the receipt snapshot never say "Today"). Date-field label: `durationDays === 1 ? 'Day pass applies on' : 'Pass starts on'`. Link lifetime (`linkExpiresAt`) = the club-local start of the day **after** `validUntil` + `STP_PASS_LINK_GRACE_HOURS` (24), computed with the club's IANA zone (DST-safe; month, year and leap-day boundaries tested in `validity.test.ts`, plus TZ-independence in child processes) — never `durationDays × 24h`, never the browser's clock. Pass status on the public page is decided from the club-local `today` the server returns.

**Consent document set** (`ClubCatalogPort.getConsentDocuments(club, offer, {visitDate, todayIso})`):

```
ConsentDocument    { id:'waiver'|'passTerms'|'storedCard'|'privacy', title, templateVersion, renderedHash, html, meta, requiresAffirmativeAct, approval:'PROPOSED'|'APPROVED' }
ConsentNotice      { id:'emailTransactional'|'smsTransactional'|'marketingOptIn', copy, version }
ConsentDocumentSet { documents[4], notices[3], waiverRequired, payButtonText, consentRevision, approval }
```

Templates live in `services/shortTermPass/fixtures/consentTemplates.ts` as functions of `TemplateContext = {legalName, brandWord, offerName, offerLabel, amount, dayLabel, validity}` with the Design HTML `DOCS` text as the default — **v4 for Pass Terms, v1.2 elsewhere** — **except** Pass Terms refunds (PRD D15/D22, approved delta AD-09). **v3 / CR-17: Pass Terms template `2026-09.2`** reads `"{offerLabel} to {legalName}, valid {validity}. Price {amount} including tax. One-time purchase — no membership, no renewal, no recurring billing."` (e.g. "3-day pass to Core Health and Fitness Club, valid Today – Fri, Sep 11. Price $60.00 including tax."); the refund paragraph is unchanged (`PASS_TERMS_REFUND_SENTENCE`). Waiver, stored-card and privacy stay `2026-09.1` / `cof-v1`. `renderedHash = sha256(title + meta + whitespace-normalised html)`; Pass Terms re-render when the offer, the visit date (range) or the amount changes. `payButtonText = "Pay $X.XX and get my pass"`. **`consentRevision = sha256(every id:renderedHash, every notice id:version, the button text, and — v3 — the commercial line `commercial:${offerId}|${amountMinor}|${currency}|${visitDate}|${validUntil}`)`**, so a club-overridden **static** Pass Terms text cannot hide a product, price or range change (fact 10; tested with a static Northside-style override). Per-club overrides: `CatalogClub.consentOverrides[id] = {html, templateVersion, approval?}`; MICO `prospectTerms` maps to a `passTerms` override. `approval:'PROPOSED'` is carried in the fixture, the config and the capability report and never rendered to the customer (CF-02). Adult, save and marketing state survive an offer or date change; waiver acceptance survives only if its rendered hash is unchanged.

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
| **Kelly Reyes** (v3, CR-16) | prospect, home club **90033** | `m@m.com` | `5550192231` | Visa 4242 "Saved in the app last week" (Core organisation owner) | Design HTML v4 returning visitor at Core South (`KELLY_CORE`, fixed UUID `7a8b9c0d-…`, the former Jordan twin renamed); "Welcome back, Kelly" / "You're in, Kelly" (U23); never resolves at Riverside |
| Casey Morgan | member | `casey@example.com` | `5550193344` | Mastercard 4444 "Saved at the front desk" | Member match, U15 |
| Riley Chen | prospect | `riley@example.com` | `5550195566` | none | No usable card, U14 |
| Dana Whitfield | prospect | `dana@example.com` | — | Visa 1111 expired | Expired card filtered → empty wallet, U14 |
| Morgan Blake | prospect | `morgan@example.com` | `5550190002` | Visa 0002 | Saved-card decline |
| Sam Patel / Alex Patel | prospects | `sam@example.com` / `alex@example.com` | both `5550197788` | none | Ambiguous phone, U9 |

Mock capture fixture cards: `visa-4242` (approved), `mastercard-4444`, `visa-0002` (declined), `visa-0003` (authorization timeout → status resolves authorized), `visa-1111-expired` (invalid token). Fixture clubs (addendum): `90030` **Riverside Athletic Club** (open; one product `day-pass-1-day` "1-day pass" USD 18.00, no perks; default demo club; all fixture people except Kelly are homed here), `90031` Riverside — Eastside (`onlineProspects=false`), `90032` Riverside — Northside (club-authored terms, `America/New_York`), `90033` **Core Health and Fitness Club — South** (second organization, `America/Chicago`; **v3: "Gym Floor" in three durations, catalog order = card order** — `day-pass-gym-floor` 1-day USD 25.00 (existing id), `day-pass-gym-floor-3` 3-day USD 60.00 and `day-pass-gym-floor-5` 5-day USD 90.00, both **`provisional: true`** (CF-04 "demo pricing — confirm"; listed in the `MockClubCatalog` capability note, never in customer copy); perks "Classes", "Steam & Sauna", "Basketball court"; Design v4 parity club). Fixture UUIDs are fixed and valid. Mock purchase fixtures: receipts `R-000001…`, pass ids `pass_<8 hex>`, QR payload **v3 `STP2|<passId>|<club>|<visitDate>|<validUntil>|<12-hex sig>`** (sig over all fields + receipt; a demo credential, not an admission credential — OQ-5; static everywhere, CF-07).

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
| `PassSalePort` | `MockPassSale` (receipt + pass + demo QR; idempotent by purchase id; v3 `STP2` payload with `validUntil`) | none → `NOT_ENABLED` | datatrak `/pos/onlineSale.spr` or gateway charge + POS record; issuance service | OQ-3, OQ-5 | PAYMENTS+PASS |
| **`PassCredentialStorePort`** (v3, B5) | `InMemoryPassCredentialStore` — `{getOrCreateForPurchase, findByTokenId, rotate, revoke, capability}`; lifetime = pass window + grace, independent of the checkout sweep | same (process-local; a restart loses links) | durable credential store with key rotation and a staff revoke surface | CF-06 lifetime / resend / admit interval; register row | PLATFORM+SECURITY |
| **QR renderer** (v3, B5 `STP/qr.ts`) | `qrcode` 1.5.4 (`toBuffer`, error correction M, margin 1, scale 6) — proven by the A4 encode → `jsqr` decode round-trip (§8a) | same | — (pure library) | none | BFF |
| `WalletPort` | `MockWallet` (owners keyed `(externalId, MEMBER, org)`, seeded cards, `providedId` idempotency) | `PlatformWallet`: reads behind `STP_WALLET_READS` (owner query + `GET /wallet-entry/credit-card?q=`), writes typed against `ICreateWalletOwner` / `ICreateWalletCreditCard` but `NOT_ENABLED` until `STP_WALLET_WRITES` | universal-wallet `/wallet-entry-owner`, `/wallet-entry/credit-card` | OQ-4; L3 (dedup-key deployment, owner-scoped rsql path) | WALLET |
| `PayPageSessionReader` | `MockPayPageSessionReader` (fixture token by session prefix; used with `MockCardCapture`) | `PlatformPayPageSessionReader` (OAuth client credentials via `OAuthTokenService`, `GET /ors/payment-token/session/{id}`); live in dev once the `PAY_PAGE_*` variables exist (BLOCKERS B1) | Order Service session API (already used by the payPage route) | credentials locally (B1) | PAYMENTS |

### 8a. Sprint 0003 A4 feasibility findings (2026-09-16, time-boxed)

**(a) Node QR rendering + independent decode — passes.** `qrcode@1.5.4` (runtime) and dev `@types/qrcode@1.5.6`, `jsqr@1.4.0`, `pngjs@7.0.0` + `@types/pngjs` installed from `registry.npmjs.org` (lockfile committed, BFF `a3cdbfc`). `qrFeasibility.test.ts`: an `STP2|…` payload → `QRCode.toBuffer(type:'png', errorCorrectionLevel:'M', margin:1, scale:6)` → `pngjs` → `jsQR` decodes **byte-for-byte** to the payload; a blank PNG of the same size decodes to nothing; the symbol is version ≤ 6 (≤ 41 modules, ≤ 258 px) for the mock payload class. **Deviation:** `pngjs` was not in the plan's package list; `jsqr` consumes raw RGBA, not PNG, so a PNG decoder is needed on the test side (dev-only). B5 wraps this in `renderQrPng(payload)` with a bounded payload length.

**(b) nodemailer CID inline PNG against Mailpit — passes.** A message with `attachments:[{filename:'pass-qr.png', content, contentType:'image/png', cid:'pass-qr', contentDisposition:'inline'}]` and `<img src="cid:pass-qr" alt="Door QR code">` sent to `smtp://localhost:2525` (Mailpit v1.31.1 running) produced `multipart/alternative` → [`text/plain`, `multipart/related; type="text/html"` → [`text/html` (quoted-printable), `image/png; name=pass-qr.png` / `Content-ID: <pass-qr>` / `Content-Disposition: inline; filename=pass-qr.png` / base64]]. Mailpit lists it under **`Inline`** (`ContentID: pass-qr`, `PartID 2.2`), not `Attachments`; `GET /api/v1/message/{ID}/part/2.2` returns `image/png` whose bytes equal the sent buffer. So the E2 / PR-06 proof is: `GET /api/v1/search?query=subject:"…"` → `GET /api/v1/message/{ID}` → `Inline[0].PartID` → `GET …/part/{PartID}` → `jsqr` decode. Message left in the Mailpit inbox (subject `A4 CID feasibility <ts>`, to `a4-cid-check@stp.test`); no fixture data was changed.

**(c) `STP_PUBLIC_BASE_URL` and the `/signup` basename through the history fallback — a real blocker for the token page, with a fix.** The UI is a single SPA under `BrowserRouter basename="/signup"`; the BFF serves the entry document at `/` and `koa2-connect-history-api-fallback@0.1.3` (`utils/middlewares/historyFallback.ts`: `index:'/'`, `htmlAcceptHeaders:['text/html']`, whitelist `/status|/session-invalid|/not-found|/detectify|/c/`) rewrites SPA paths to `/`. Probe (library called directly with the production options): `/signup/day-pass?club=90033` → `/` ✓, `/signup/pass?club=90033` → `/` ✓, **`/signup/pass/pv1.<id>.<exp>.<sig>` → not rewritten** — the library's **dot rule** (`pathname.indexOf('.') !== -1 && !disableDotRule`) treats the dotted token as a file request, so the request falls through to the routers and 404s: the "View your pass" page would never load. API and image requests are unaffected (`/api/short-term-pass/passes/<token>` with a JSON accept, `/qr.png` with an image accept → not rewritten, as intended). **Fix for B5 (owner of `historyFallback.ts`):** add `rewrites: [{ from: /^\/signup\/pass\/pv1\.[A-Za-z0-9_.-]+$/, to: '/' }]` — rewrites are evaluated **before** the dot rule; probe with the rule: token path (with or without a query) → `/` ✓, `/signup/pass?club=` → `/` ✓, `/signup/main.abc123.js` still not rewritten ✓. Do **not** set `disableDotRule` globally (it would swallow asset 404s). Consequence for the contract: `STP_PUBLIC_BASE_URL` is the **origin only** (`http://localhost:3000`, the dev ingress origin); the BFF appends `/signup/pass/<token>` itself (UI basename) and `/api/short-term-pass/passes/<token>/qr.png`. Whether the dev ingress mounts the BFF at `/` or under a prefix was **not verifiable locally** (no ingress config in the cache) — if a prefix exists, `STP_PUBLIC_BASE_URL` must include it; recorded as a PLATFORM question.

**(d) Where request paths are logged — two places, both outside `services/shortTermPass`.** (1) `@abc/bff-toolkit@11.29.1` `loggerMiddleware()` (first middleware in `services/application.ts`) logs `→ IN {method} {ctx.request.url}` at request start (before the fallback rewrite, so the token path) and `← IN {method} {ctx.request.originalUrl} -> {status}` at finish, both with `endpointUri: ctx.request.url`; the entry object spreads `...ctx.state.inboundRequestsLogMetadata` **after** `message`/`endpointUri`, so a middleware mounted before the logger could override them, but the same override would clobber both lines. (2) `historyFallback.ts` passes `logger: (...args) => loggerService.debug(args.join(' '))` when `LOG_LEVEL=debug`, which logs `Rewriting GET /signup/pass/pv1.… to /` (probe confirmed the raw token appears in these lines). **Recommendation for B5:** redact at the sink — install a winston format on `loggerService` at boot (`loggerService.format = winston.format.combine(redactPassTokens(), loggerService.format)`; winston 3 reads `this.format` per log call) that rewrites `pv1\.[A-Za-z0-9_-]{32}\.\d{10}\.[A-Za-z0-9_-]{43}` to `pv1.[redacted]` in `message` and `endpointUri`, plus the same regex inside the `historyFallback` debug logger; unit-test by capturing a transport. The pass-route handlers themselves must log `passes.view` events with the credential's `tokenId` prefix only, never the token.

**(e) Club-local next-day + 24 h helper — done in A3** (`validity.ts` `linkExpiresAtOf`; 3-day Sep 16–18 in Chicago → `2026-09-20T05:00:00.000Z`; DST, month/year/leap-day and TZ-independence tests green).

**(f) Publisher attachments — not assumed.** `EmailEngineRequest` (`adapters/publisher/emailPublisher.ts`) is base64 HTML + plain text with no attachment slot; the publisher path uses the hosted `qr.png` URL (B6). No live publisher call was attempted (dev ingress 503 on 2026-09-10; unchanged assumption).

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

| **Sprint 0003 — contract v3 (A2)** | frozen 2026-09-16: types + ajv schemas in both repos, both type-check (UI: 8 pre-existing errors outside the Day Pass code, unchanged); route behaviour lands in B/C | `schemas.test.ts` (offer bodies, token shape), UI `shortTermPassTestData.test.ts`; §4, §4a, §4b | T0 | UI+BFF |
| **Sprint 0003 — fixtures (A3)** | Core 1/3/5 offers (`provisional` on 3/5 — CF-04), Kelly Reyes, Pass Terms `2026-09.2` with commercial binding, `validity.ts` | `catalog.test.ts`, `identityDirectory.test.ts`, `consentTemplates.test.ts`, `validity.test.ts` (BFF 64 suites / 640 passed, 97.19 / 85.86 / 96.12 / 97.91) | CF-04 prices (PM), CF-05 window semantics (PM) | PRODUCT / BFF |
| **Sprint 0003 — QR renderer (A4)** | proven locally: `qrcode` PNG decodes byte-for-byte with `jsqr` | `qrFeasibility.test.ts`; §8a(a) | — | BFF |
| **Sprint 0003 — pass email image transport (A4)** | CID inline PNG shape proven against Mailpit (SMTP lane); publisher path = hosted `qr.png` URL, **live send unverified (publisher 503)**; rendering in Gmail / Outlook / Apple Mail documented from client behaviour, not tested | §8a(b), §8a(f) | L1 (OQ-2); publisher image fetch from real clients (PLATFORM+IDENTITY) | PASS-DELIVERY |
| **Sprint 0003 — token page reachability (A4)** | **blocker with fix**: history-fallback dot rule 404s `/signup/pass/pv1.…`; rewrite rule specified for B5; `STP_PUBLIC_BASE_URL` = origin only; ingress prefix unverified | §8a(c), probe 2026-09-16 | B5 rewrite + test; PLATFORM to confirm the dev ingress mount path | BFF+PLATFORM |
| **Sprint 0003 — token confidentiality in logs (A4)** | two log sites identified (toolkit request logger, history-fallback debug logger); redaction design specified for B5 | §8a(d) | B5 redaction test | BFF+SECURITY |
| **Sprint 0003 — credential store, public routes, rotate-and-resend** | contract only (types frozen; B5/B7 build) — in-memory by declaration | §4, §5 | CF-06 (ENG+PM); durable store + staff revoke (PLATFORM); rotating QR + desk verifier (PRODUCT+SECURITY) | BFF |
| **Sprint 0003 — parity inputs v2 (A5)** | `tools/day-pass-harness/parity/{elements,approved-deltas}.json` re-keyed to `day-passv4.html` (sha256 `c0a5fd8d…`), 13 states, v4 selector stubs, AD-01…AD-10 re-cited, AD-11…AD-13 placeholders; **loop not run (user decision)** | JSON valid; D1 completes | S2/S7 deferred | DESIGN / UI |

Completion vocabulary for Sprint 0002: **sprint implementation complete; local checkout complete; live integration blocked** — and, for G4, **"mock demo complete; hosted capture unverified"**. Sprint 0003 uses the T0–T8 vocabulary of `docs/sprints/SPRINT-0003.md`; at the A-phase exit only T0 is claimable ("contract v3 frozen and type-checked; fixtures, validity helper and feasibility checks done; branches created, not pushed; ledger owned by the orchestrator").
