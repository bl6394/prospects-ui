# Short-term pass (Guest Pass) — BFF contract, adapter register and readiness

**Status:** contract **v4.1** (Sprint 0005 A3, 2026-10-07): v4 plus the DataTrak service-layer field table and the two feature-flag keys in §8a(e), the `guestPassItems.spr` row in §8, and the CF-19…CF-25 / RQ-10…RQ-16 register rows in §10; the browser contract (§4–§6) is unchanged. Contract **v4** was frozen at Sprint 0004 task A3 (2026-09-18) — supersedes v3 (Sprint 0003 A2, 2026-09-16), v2 (Sprint 0002 A2) and v1 (Sprint 0001 A1). v3 → v4 changes are listed in §4a, v4 example payloads in §4b, the Sprint 0004 A2 feasibility findings in §8a, the hosting model in §9 and the readiness / CF / RQ registers in §10. Sprint 0004 E5 completes the registers.
**Source of truth for shapes:** `online-join-bff/src/routes/shortTermPass/schemas.ts` (ajv schemas + TypeScript types), mirrored by `online-join-ui/src/interfaces/api/shortTermPass.ts`. At the A3 freeze both files carry the v4 types; the v3 fields they still export are marked `@deprecated — removed in B0/C0` and leave with the Phase B/C removal tasks so that `tsc` stays green at the Phase A exit.
**Source SHAs at the v4 freeze:** `online-join-bff` `f5c92ca` (origin/main incl. PR #106) and `online-join-ui` `b6dae7d` (origin/main), branches `prospect-wallet/sprint-0004`. v3 freeze SHAs: BFF `5915c96`, UI `d97afbe`; v2: UI `a3c61b6`, BFF `db81011`; v1: UI `f3242b1`, BFF `bc8a4bd`; `mico` `5dad4d66` (read-only).
**Sources (precedence):** `docs/prd/Consolidated_PRD_v3.6.md` (D48–D74), `docs/prd/Change_Requests_2026-09-10_v3.md` (CR v3 ids), `docs/prd/Next_Steps_2026-09-10_v2.md`, `docs/prd/day-passv6.html` (Design v6). CR ids in this document are CR v3 unless qualified "(2026-09-15)".
**Internal naming:** `ShortTermPass` / `shortTermPass` / `STP_*`. "Guest Pass" / "Day Pass" are UI copy only.

**v4 in one paragraph (Rounds 5–7, D48–D74; CR-06, 09, 12, 13, 14, 15, 20, 25–32, 35).** The catalog is the list of products a club flagged **"Guest pass online"** in DataTrak, each carrying `contractDays` and `visits`; v1 sells only single-visit items (`visits === 1`), listed with a validity line ("One time use only, valid today" / "… valid for 7 days"). There is no start date: `beginDate` is the club-local purchase day and `expirationDate = beginDate + contractDays − 1` (inclusive); the order quotes `useBy` and the purchase recomputes it. The prospect is created (or an existing club-scoped prospect repainted) **before** payment with `{beginDate, expirationDate, visits, marketingOptIn, saleItemId, paymentTokenReference}`; a confirmed decline deactivates the new record or reverts the repainted one; an unknown authorization is looked up by reference and otherwise lands in `RECONCILING`, never treated as a decline; the card is saved to the wallet only after `AUTHORIZED`. The 18+ checkbox, the start-date picker, the on-page QR, the BFF QR renderer, the pass page (`/passes/:token`), the pass-link routes and their three env keys are **removed**; DataTrak renders the QR and sends the prospect email (`delivery.status:'delegated'`, `renderer:'dt'`); mock mode sends a labelled stand-in email without an image. The marketing opt-in is a versioned consent **document** (`marketing`) with a hash-bound checked state that travels on the create/repaint call. The one-time code is 6 digits, **5 minutes**, **2 sends per address per hour**, with `expiresAt` for a countdown. The same BFF serves a standalone Guest Pass host (`STP_STANDALONE_HOSTS`): `/` and `/guest-pass` render the checkout there, membership paths and non-guest-pass APIs answer 404. The gate is LaunchDarkly `guest-pass-online` (club context) **and** at least one eligible flagged item; `onlineProspects` no longer gates.

## 1. Scope recorded at A3

**Ships in Sprint 0004 (mock adapters, both repos):** the v4 contract below; catalog port v4 with the v1 single-visit filter; order without dates; purchase order `VALIDATED → PERSON_PERSISTED → AUTHORIZED → WALLET_RESULT → SALE_FINALIZED → COMPLETE` with `deactivate` / `revert` compensation, `RECONCILING`, an owner-only `compensate` route and a process-local compensation sweep; `marketing` consent document; expired saved cards exposed and refused; OTP constants and template slot; purchase rate limit and attempt log; production guard v4; `DatatrakServiceCatalog` adapter behind `STP_CATALOG_SOURCE=datatrak` unit-pinned against **labelled synthetic** fixtures (CF-13/14 block the live read — §8a); host-scoped routing; UI per Design v6 (offer cards with the validity line, no date field, "use by" row, waiver + optional marketing checkbox with the legal text in a dialog, no 18+, five-minute expiry countdown, expired-card chip, returning lane re-accepting Pass Terms and waiver, v6 done copy with truthful delivery variants, `/guest-pass` route, host-aware router base); demo 0–6; helm PR for the standalone dev host.

**Does not ship (and is not claimed):** live DataTrak reads (CF-13/CF-14), live prospect create / repaint / deactivate (platform `ProspectPort` stays `notEnabled`, CF-15), hosted Pay Page capture proof (B1 credentials), the production Guest Pass host and Cloudflare rules (V-P3), the DT prospect email with the QR (DataTrak's — RQ-0, RQ-3), durable stores (V-P1), the harness lane (deferred by the user), any change to MICO, universal-wallet, wallet-account-sync, datatrak or `@abc/bff-toolkit`.

**Removed by Sprint 0004 (D63, D66, D71, §9 non-goals) — retired paths answer the router's generic 404:** `GET /passes/:token`, `GET /passes/:token/qr.png`, `GET`/`POST …/purchases/:pid/pass-link`, `POST /testing/passes/revoke`; `pv1` tokens, `PassCredentialStorePort`, the QR renderer (`qrcode`, `jsqr`, `pngjs`), the pass email with a QR image, the history-fallback pass rewrite, log redaction of tokens, the AppDynamics skip; `visitDate`, `minVisitDate`, `maxVisitDate`, `durationDays`, `validUntil`, `label` (duration), `maxDaysAhead`, `adult`; env `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS`. Git preserves the work (`main` history; tag `prospect-wallet/sprint-0003-history-20260917`).

## 2. Environment matrix (v4)

| Variable | mock (local / CI) | mock (dev cluster) | platform (dev, later) | production | Notes |
|---|---|---|---|---|---|
| `STP_ADAPTER_MODE` | `mock` | `mock` | `platform` | `platform` or unset | Unset = feature disabled (every pass route 404). Production refuses `mock`. |
| `STP_NON_PRODUCTION` | — | `true` | unset | refused (ignored when `NODE_ENV=production`) | Declares a cluster whose `NODE_ENV` is not `development` non-production for this feature only. |
| **`STP_CATALOG_SOURCE`** (v4) | `fixture` (default in mock) | `fixture` | `datatrak` | `datatrak` only | `fixture` = `MockClubCatalog`; `datatrak` = `DatatrakServiceCatalog` (§8). **Production refuses `fixture` and every source that can return a fixture offer** (the v3 `PlatformClubCatalog` hybrid that answered `FIXTURE_OFFER` is removed). |
| **`STP_DATATRAK_SERVICE_URL`** (v4) | — | — | `https://datatrak-service.dev.abcfitness.net/external` | required | Base of the DataTrak service layer MICO's `OrasvcClient` uses (`orasvc-client.url` + `path`). Required when `STP_CATALOG_SOURCE=datatrak`. |
| **`STP_DATATRAK_SERVICE_AUTH`** (v4) | — | — | secret (`platform-online-join-bff`) | required | Full `Authorization` header value (MICO uses a static Basic credential — `MicoProperties.dtServicesBasicAuth*`). Never printed. The guard refuses `datatrak` without it. |
| **`STP_DATATRAK_CACHE_SECONDS`** (v4) | `60` | `60` | `60` | `60` | Per-club cache for club defaults and offers; commercial fields are re-read before side effects (§5). |
| **`STP_STANDALONE_HOSTS`** (v4) | `guestpass.localhost` (optional) | `guestpass.dev.abcfitness.net` | same | prod host (RQ-5) | Comma list of hostnames on which `/` and `/guest-pass` serve the Guest Pass entry document and membership paths / non-guest-pass APIs answer 404 (§9). Empty = today's behaviour. Matched against `ctx.hostname` (Koa `app.proxy` is on outside `development`, so `X-Forwarded-Host` wins behind the ingress — §8a(b)). |
| `STP_ALLOWED_ORIGINS` | `http://localhost:3000` (default) | **both** dev origins | both | both prod origins | Fail-closed Origin allowlist on every mutation; the standalone host is a second origin. |
| **`STP_OTP_TEMPLATE_PATH`** (v4) | unset (built-in PROPOSED template) | unset | Chancy's HTML | Chancy's HTML | HTML file with **exactly** the placeholders `{{code}}` and `{{clubName}}`; validated at boot (missing or unknown placeholder → refuse). Both transports (SMTP, publisher) render from it. |
| `STP_LOCAL_FLAG_OVERRIDE` | `true` | `true` (temporary, CF-17) | unset | refused | Treats `guest-pass-online` as on for every club; non-production only. |
| `STP_MOCK_OTP_CODE` | unit fixtures / local | pinned in dev (mock mode; testers cannot read the outbox through the ingress) | unset | **refused (v4)** | The guard now refuses a pinned code in production (R7). |
| `STP_SESSION_SECRET`, `STP_CODE_SECRET` | dev defaults | set | required | required | HMAC keys for session ids and one-time codes. |
| `STP_CAPTURE_MODE` | `paypage` or `mock` (hooks only) | `paypage` | `paypage` | `paypage` | Unchanged (v2). |
| `STP_TEST_HOOKS`, `STP_TEST_HOOKS_KEY`, `STP_TEST_CLOCK` | hooks on for smoke | hooks on (loopback-only routes; read through `kubectl port-forward`) | unset | refused | Unchanged. The testing routes stay loopback-only **by design** (no policy change in this sprint). |
| `STP_MOCK_FAULTS` | optional | unset | unset | refused | v4 fault list in §7. |
| `STP_EMAIL_TRANSPORT`, `STP_SMTP_URL`, `STP_EMAIL_FROM`, `STP_EMAIL_PUBLISHER_*`, `STP_EMAIL_SENDER`, `STP_EMAIL_REPLY_TO`, `STP_EMAIL_DISPLAY_NAME`, `STP_EMAIL_BILLING_CODE_SUFFIX` | `smtp` + Mailpit | `mock` | `publisher` | `publisher` | Unchanged. In **platform mode the BFF sends no pass email** (DT does — `delivery.renderer:'dt'`); the transport carries the one-time code only. |
| `STP_WALLET_READS`, `STP_WALLET_WRITES`, `UNIVERSAL_WALLET_API_URL` | ignored | `false` | `false` until L3 | `false` | Unchanged (R16). |
| `PAY_PAGE_*`, `ABC_CORE_API_URL` | — | set in dev | required | required | Unchanged; hosted capture stays unverified locally (B1). |
| ~~`STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS`~~ | **removed (v4)** | removed from helm (D1) | — | — | The boot guard no longer knows them; a leftover value is ignored, not an error. |

**Boot guard v4 (`assertShortTermPassBootConfig`, `server.ts`):** unknown `STP_ADAPTER_MODE` / `STP_CAPTURE_MODE` / `STP_EMAIL_TRANSPORT` / `STP_CATALOG_SOURCE` → refuse; production + `mock` adapters, `smtp`, flag override, faults, hooks, test clock, mock capture → refuse; **production + `STP_CATALOG_SOURCE=fixture` (or unset, which defaults to fixture) → refuse; production or platform mode + `STP_MOCK_OTP_CODE` → refuse; `STP_CATALOG_SOURCE=datatrak` without `STP_DATATRAK_SERVICE_URL` (https in production) and `STP_DATATRAK_SERVICE_AUTH` → refuse; `STP_OTP_TEMPLATE_PATH` set but unreadable or with placeholders other than `{{code}}` / `{{clubName}}` → refuse;** platform mode without the two secrets → refuse; production without origins → refuse; hooks without key → refuse; feature-off production always boots. The three pass-link keys are forgotten.

## 3. Gating (v4)

Every `/api/short-term-pass/*` route and the pass-scoped Pay Page session route run `requireShortTermPass`: resolve club (body `clubNumber` for `POST /checkouts`, the checkout record for everything else) → `ClubCatalogPort.resolveClub` → LaunchDarkly **`guest-pass-online`** evaluated with `{kind:'club', key:<5-digit padded>}` → **at least one eligible flagged item** (`requireOffers` after the v1 filter, §4 "Catalog") → the resolved club and offers on `ctx.state.shortTermPass`. Any failure, missing data or thrown error → `404 {code:'NOT_FOUND'}`. **`club.onlineProspects` no longer gates** (D61: a flagged paid item sells even when online free trials are off); it stays on `CatalogClub` as data. The HTML entry point serializes `window.featureFlags.guest_pass_online` from the same LD evaluation with the validated `?club=` query (UI hint only) and, on a standalone host, `window.guestPass = {standalone:true, basename:'/'}` (§9). The old key `oj-short-term-pass-checkout` never existed in LD (CF-17); the rename ships and `STP_LOCAL_FLAG_OVERRIDE` stands in until PLATFORM creates the flag (D3).

## 4. Browser contract (`/api/short-term-pass`) — v4

Common rules (unchanged): JSON bodies validated with ajv, `additionalProperties:false`; bodies never accept `memberId`, owner/user/entry ids, org/location ids, agreement metadata, price, dates, terminal id, PG token, `pan`, `cvc`, `expiry`, `tokenId`. Every response is `Cache-Control: no-store` and carries `X-Correlation-Id`. Mutations on a checkout require the `OJ-PASS-SESSION` cookie, the `X-STP-CSRF` header and an allowlisted `Origin`. Cookie `Secure` follows `NODE_ENV==='production'` through the toolkit's `secureCookieMiddleware` (PR #106 fix kept).

Error envelope: `{code, message, retryable, correlationId, retryAfterSeconds?, details?}`. Codes: `VALIDATION_FAILED` 400 · `NOT_FOUND` 404 · `CHECKOUT_EXPIRED` 401 · `NOT_VERIFIED` 401 · `CSRF_REJECTED` / `ORIGIN_REJECTED` / `FORBIDDEN` 403 · `STATE_CONFLICT` / `IDEMPOTENCY_CONFLICT` / `PURCHASE_IN_PROGRESS` 409 · `CODE_INVALID` / `CODE_EXPIRED` / `CHALLENGE_MISSING` 401 · `CHALLENGE_LOCKED` / `THROTTLED` 429 · `ORDER_NOT_READY` / `CAPTURE_NOT_READY` 409 · `UPSTREAM_UNAVAILABLE` 502/503 · `NOT_ENABLED` 501. `STATE_CONFLICT` `details.reason` ∈ `STALE_GENERATION` · `CONSENT_REVISION` (documents, button text **or the commercial line incl. `useBy`** changed — a midnight rollover between render and Pay lands here with the refreshed `order` and `consent` in `details`) · `WAIVER_HASH` · `OFFER_UNAVAILABLE` (refreshed `offers` + new `selectedOfferId`). **v4: `details.contractVersion: 4` rides every 409 and every checkout response** so a stale bundle can restart with a clear message (C1).

**Generation, offer selection lifecycle:** unchanged from v3 (`PUT /offer` requires `generation`; committed offer and order edits bump it; selection only before an order exists).

**Catalog (v4, CR-28, D61, D70, D72).** `CatalogOffer {offerId (= DataTrak saleItemId), catalogItemId, type:'product', guestPassOnline, name, amountMinor, currency, taxed, contractDays, visits, sourceRevision}`. `requireOffers` applies the **v1 filter** — `guestPassOnline && type==='product' && visits === 1 && amountMinor > 0 && Number.isInteger(contractDays) && contractDays >= 1` — and lists skipped items (`{offerId, reason}`) in the capability report; a club with no eligible item is a gate refusal (404), not a 502. Purchase **refuses** an offer that fails the filter (409 `STATE_CONFLICT` / `OFFER_UNAVAILABLE`) rather than coercing visits. `OfferSummary` (browser) = `{offerId, name, amountMinor, currency, contractDays, visits, validityLine}` — no `perks` (DataTrak has no such field; "what's included" is v2 — D57), no `durationDays`, no duration `label`. `validityLine` is computed server-side: `contractDays === 1 ? 'One time use only, valid today' : \`One time use only, valid for ${contractDays} days\`` (RQ-1 draft copy, pinned).

**Validity (v4, D48, D62, D71, D72).** `beginDate` = club-local calendar date of the purchase; `expirationDate = beginDate + contractDays − 1` (inclusive calendar days in the club's IANA zone; a 1-day pass expires on its begin date); `visits` from the item (1 in v1). Before purchase the order carries `useBy` = club-local today + contractDays − 1 as a **quote**; `validatePurchase` recomputes it and refuses a stale `consentRevision` (the commercial line binds `useBy`) with 409 `CONSENT_REVISION` and the refreshed order — never a silent move. One helper file, `services/shortTermPass/validity.ts` (`expirationDateOf`, `useByOf`, `validityLineOf`, `useByLabel`, `zonedDateOf`, `addCalendarDays`), owns the arithmetic; the UI's `format.ts` mirrors `useByLabel` / `validityLine` and is pinned against the same fixtures. Browser timezone and DST cannot move the dates (tests: month/year/leap day, DST, browser zone ≠ club zone). No numeric literal for days, visits or prices in customer copy (static scan, V1).

| Method / path | Request | Response |
|---|---|---|
| `POST /checkouts` | `{clubNumber}` | `CreateCheckoutResponse` — `contractVersion: 4`, `checkoutId`, `csrfToken`, `generation`, `captureMode`, `adapterMode`, `testHooks`, `resumed`, `club` (`name`, `number`, `timezone`, `legalName?`, `brand{word,tag}`, `locationLabel`, `links`), **`offers: OfferSummary[]`** (eligible flagged items in catalog order; the 3-visit and unflagged Core fixtures are absent), `selectedOfferId`, `consent: ConsentDocumentSet` (§6, **five** documents incl. `marketing`), `snapshot` (`step`, `generation`, `contact?`, `contactHint?`, `challenge?` incl. `expiresAt`, `emailVerified`, `offerId?`, `person?`, `order?`, `purchaseId?`). **The compatibility `offer` field is removed.** |
| `PUT /checkouts/:id/offer` | `{offerId, generation}` | `OfferResponse {selectedOfferId, offer: OfferSummary, consent, generation}` — unchanged semantics (v3). |
| `POST /checkouts/:id/identify` | `{email, generation?}` | `{outcome:'challenge', generation, contact, challenge:{expiresAt, resendAfter, attemptsRemaining, locked}}` — **`expiresAt` = issue + 5 min (D58)**; 429 `THROTTLED` + `retryAfterSeconds` at **2 sends per address per 60 min** across checkouts and clubs, or 20 identifies per IP per hour; "Change" (`DELETE /identity`) never consumes a send. Everything else as v2/v3 (no directory call, identical key set and 300 ms floor). |
| `POST /checkouts/:id/challenge` | `{action:'resend'}` | `{generation, contact, challenge}` — 30 s cooldown (429 `THROTTLED`), the 2/hour limit and address lock as identify. |
| `POST /checkouts/:id/verify` | `{code, generation?}` \| `{retryLookup:true, generation?}` | As v3: recognized → `{outcome:'recognized', generation, person, contact, order, consent}` (order shell **without dates**, §6); newVisitor → `{outcome:'newVisitor', generation, contact, order, consent}`; unresolved → `{outcome:'unresolved', generation, contact}`. `CODE_EXPIRED` after 5 minutes. |
| `DELETE /checkouts/:id/identity` | — | `{ok:true, generation, contactHint?}` — unchanged; **the offer selection is kept** (Change re-verifies the same pass). |
| `GET /checkouts/:id/wallet` | — | `{status:'ok', cards:[{selectionRef, brand, last4, source, expired}]}` \| `{status:'unavailable'}` — **v4: expired ACTIVE cards are listed with `expired:true`** (end of `expMonth/expYear`, club-local) instead of filtered out; INACTIVE entries stay hidden. A `newVisitor` checkout answers 401 `NOT_VERIFIED`. |
| `PUT /checkouts/:id/order` | `{waiver?:{accepted, method?, renderedHash?}, saveCard?, marketingOptIn?, smsNoticeShown?, generation?}` | `{order: OrderSummary, consent, generation}` — **`OrderSummary = {offerId, offerName, amountMinor, currency, contractDays, visits, useBy, consents, saveCard, ready}`**; `visitDate` / `adult` in the body → 400 `VALIDATION_FAILED` (`additionalProperties:false`); `ready = (!waiver.required \|\| waiver.accepted)` — no date, no adult term. `marketingOptIn` records `{optedIn, templateVersion, renderedHash, at}` against the current `marketing` document (explicit `false` is recorded too); it never gates Pay. Waiver rules unchanged (`method` + `renderedHash`; 409 `WAIVER_HASH` on a text change). |
| `POST /checkouts/:id/consent-events` | `{type, documentId ∈ waiver\|passTerms\|storedCard\|privacy\|marketing, renderedHash}` | `{ok:true, count}` — unchanged; **`marketing` accepted** (opening the dialog is evidence, never opt-in). |
| `GET /checkouts/:id/capture?sessionId=`, `POST /checkouts/:id/capture/mock` | unchanged | unchanged |
| `POST /checkouts/:id/purchases` | header `Idempotency-Key`; `{payment:{kind:'saved', selectionRef}\|{kind:'hosted', payPageSessionId}, attestation:{consentRevision, payButtonText}, profile?:{firstName, lastName, mobile}, generation?}` | `PurchaseResult` (§5): 201 new attempt, 200 replay. **v4 validation:** state `recognized`/`newVisitor`, waiver accepted when required, attestation against the set **recomputed for club-local today** (`useBy` moved → 409 `CONSENT_REVISION` with `details.order` + `details.consent`), offer still eligible (else 409 `OFFER_UNAVAILABLE`), profile for new visitors, payment source owned by the checkout; **a saved `selectionRef` whose entry is expired → 400 `VALIDATION_FAILED` "That card has expired. Add a different card."** (field `payment.selectionRef`). Per-IP limiter **10 per hour → 429 `THROTTLED`** (before validation, after the checkout chain). Then the §5 order runs synchronously. Attempt log line `purchase.attempt {clubNumber, purchaseId, outcome}` — never PAN, token, email, name. |
| `GET /checkouts/:id/purchases/:pid` | — | `PurchaseResult` — refresh recovery, owned checkout only. |
| `POST /checkouts/:id/purchases/:pid/wallet-retry` | — | `PurchaseResult` — unchanged (same `walletProvidedId`). |
| **`POST /checkouts/:id/purchases/:pid/compensate`** (v4) | — (empty body) | Owner-only (same ownership rule as `wallet-retry`): re-runs **only** the pending prospect compensation of a `RECONCILING` purchase whose `failure.step` is `deactivate` or `revert`; answers the updated `PurchaseResult` (`FAILED` with `person.deactivated:true` / `person.reverted:true` once the compensation is confirmed; still `RECONCILING` when the adapter fails again). 409 `STATE_CONFLICT` when nothing is pending. Never replays create, authorize, sale or capture. A process-local sweep retries the same compensations while the process lives (§5). |
| `DELETE /checkouts/:id` | — | `{ok:true, generation, contactHint?}` — unchanged. |
| `POST /api/pay-page/session/short-term-pass` | `{checkoutId}` | unchanged (`purpose:'short-term-pass'`); **allowed on standalone hosts** (§9). |
| `GET /api/short-term-pass/testing/outbox?checkoutId=`, `GET /testing/state?checkoutId=`, `POST /testing/reset` | header `X-STP-TEST-KEY`, loopback peer only | **Hooks only.** `outbox` messages: `{kind:'code'\|'prospect-stand-in', channel, destination, code?, receiptNumber?, barcode?, beginDate?, expirationDate?, sentAt, checkoutId?}` — no `viewPath`, no `qr`. `state` purchases carry `pass.{beginDate, expirationDate, visits}`, `person.{created, deactivated?, reverted?}`, `delivery.{status, renderer}`, `access?` (mock directory access snapshot for the bound member), `compensation?` (pending / done). `reset` also clears the purchase limiter and the attempt log. The leak scan asserts no `viewPath`, `qrPayload`, `pv1`, PAN, token, session key or CSRF token in any hooks response. |
| ~~`GET /passes/:token`~~, ~~`GET /passes/:token/qr.png`~~, ~~`GET`/`POST …/pass-link`~~, ~~`POST /testing/passes/revoke`~~ | — | **Removed (v4).** The router has no such routes; they answer the generic 404 like any unknown path (test: `GET /api/short-term-pass/passes/anything` → 404 with no `X-Robots-Tag`). |

### 4a. Version changes

**v3 → v4 (Sprint 0004 A3, 2026-09-18).** Added: `contractVersion` on `CreateCheckoutResponse` and on 409 `details`; `OfferSummary.{contractDays, visits, validityLine}`; `OrderSummary.{contractDays, visits, useBy}`; `OrderConsents.marketingOptIn.{templateVersion, renderedHash}`; consent document `marketing` (five documents); `consentEvent.documentId: 'marketing'`; `WalletCard.expired`; `PurchaseResult.person.{deactivated?, reverted?}`, `pass.{beginDate, expirationDate, visits}`, `delivery.status` values `unknown` and `delegated`, `delivery.renderer: 'dt' \| 'bff-stand-in'`, `receipt.{beginDate, expirationDate}`; checkpoints `PERSON_DEACTIVATED`, `PERSON_REVERTED`; `POST …/purchases/:pid/compensate`; `ChallengeSummary.expiresAt` semantics (5 min); env `STP_CATALOG_SOURCE`, `STP_DATATRAK_SERVICE_URL`, `STP_DATATRAK_SERVICE_AUTH`, `STP_DATATRAK_CACHE_SECONDS`, `STP_STANDALONE_HOSTS`, `STP_OTP_TEMPLATE_PATH`; LD flag key `guest-pass-online` / window flag `guest_pass_online`; `window.guestPass.basename`. Changed: `PurchaseResult.receipt.item` is the catalog name; purchase order (person before payment); gate no longer requires `onlineProspects`; `GET /wallet` exposes expired cards; OTP TTL 10 → 5 min, sends 5 → 2 per hour; Pass Terms template `2026-09.2` → `2026-09.3`; `consentRevision` commercial line `offerId|amount|currency|visitDate|validUntil` → `offerId|amount|currency|contractDays|visits|useBy`; `PURCHASE_CHECKPOINTS` order. Removed: `CreateCheckoutResponse.offer`; `OfferSummary.{perks, durationDays, label}`; `OrderRequest.{visitDate, adult}`; `OrderSummary.{durationDays, label, visitDate, validUntil, minVisitDate, maxVisitDate}`; `OrderConsents.adult`; `OrderConsents.marketingOptIn.version`; notice `marketingOptIn`; `PurchaseResult.pass.{passId, visitDate, validUntil, qrPayload, viewPath}`; `receipt.{label, visitDate, validUntil}`; checkpoint `ISSUED`; `PassLinkResponse`, `PassLinkRotateResponse`, `PassView`, `PASS_TOKEN_PATTERN`, `isPassTokenShape`; the four retired routes; the three pass-link env keys; `PurchaseConsentSnapshot.adult`; `StoredOrder.{durationDays, visitDate, validUntil, maxVisitDate}`; `CatalogOffer.{perks, durationDays, maxDaysAhead, provisional}`; `PassSalePort.issue`, `IssuedPass`; `DeliveryInput.{qrPayload, viewPath, links}`.

**v2 → v3 (Sprint 0003 A2).** Added offers/selection, inclusive multi-day range, receipt snapshot, pass credential, public pass routes, pass-link routes, hooks revoke (all but offers/selection and the receipt snapshot removed again in v4). **v1 → v2 (Sprint 0002 A2).** Consent set, attestation, generation, test hooks, email-only identity.

### 4b. v4 example payloads

**4b-1 — `POST /checkouts` at Core South (three eligible items; the 3-visit and unflagged products are absent):**

```json
{ "contractVersion": 4, "checkoutId": "chk_…", "csrfToken": "…", "generation": 0, "captureMode": "paypage", "adapterMode": "mock", "testHooks": true, "resumed": false,
  "club": { "name": "Core Health and Fitness Club — South", "legalName": "Core Health and Fitness Club", "number": "90033", "timezone": "America/Chicago",
            "brand": { "word": "CORE", "tag": "Health and fitness club" }, "locationLabel": "South", "links": { "app": "https://example.com/core-app" } },
  "offers": [
    { "offerId": "core-day-pass",     "name": "Day Pass",         "amountMinor": 2500, "currency": "USD", "contractDays": 1,  "visits": 1, "validityLine": "One time use only, valid today" },
    { "offerId": "core-flex-pass",    "name": "Flex Day Pass",    "amountMinor": 3000, "currency": "USD", "contractDays": 7,  "visits": 1, "validityLine": "One time use only, valid for 7 days" },
    { "offerId": "core-anytime-pass", "name": "Anytime Day Pass", "amountMinor": 3500, "currency": "USD", "contractDays": 30, "visits": 1, "validityLine": "One time use only, valid for 30 days" } ],
  "selectedOfferId": "core-day-pass",
  "consent": { "documents": [ {"id":"waiver","…":"…"}, {"id":"passTerms","templateVersion":"2026-09.3","…":"…"}, {"id":"storedCard","…":"…"}, {"id":"privacy","…":"…"},
                              {"id":"marketing","title":"Marketing communications","templateVersion":"2026-09.1","approval":"PROPOSED","requiresAffirmativeAct":false,"…":"…"} ],
               "notices": [ {"id":"emailTransactional","…":"…"}, {"id":"smsTransactional","…":"…"} ], "waiverRequired": true,
               "payButtonText": "Pay $25.00 and get my pass", "consentRevision": "…", "approval": "PROPOSED" },
  "snapshot": { "step": "identify", "generation": 0, "emailVerified": false, "offerId": "core-day-pass" } }
```

**4b-2 — order shell after verify (Kelly, Flex Day Pass selected, club-local 2026-09-17):**

```json
{ "offerId": "core-flex-pass", "offerName": "Flex Day Pass", "amountMinor": 3000, "currency": "USD", "contractDays": 7, "visits": 1, "useBy": "2026-09-23",
  "consents": { "waiver": { "required": true, "accepted": false, "templateVersion": "2026-09.1", "renderedHash": "…" },
                "storedCard": { "shownVersion": "cof-v1" },
                "marketingOptIn": { "optedIn": false, "templateVersion": "2026-09.1", "renderedHash": "…" },
                "notices": { "emailTransactional": { "version": "2026-09.1", "shownAt": "…" } } },
  "saveCard": false, "ready": false }
```

The Pass Terms body for that order reads: *"Flex Day Pass to Core Health and Fitness Club. One time use only, valid for 7 days · use by Wed, Sep 23. Price $30.00 including tax. One-time purchase — no membership, no renewal, no recurring billing."* followed by `PASS_TERMS_REFUND_SENTENCE` (PRD D15/D22; the v6 "before the pass is first used" sentence is **not** adopted — CF-16).

**4b-3 — stale clients (`PUT /order {visitDate:"2026-09-20"}` or `{adult:true}`):**

```json
// 400
{ "code": "VALIDATION_FAILED", "message": "Invalid request: (body) must NOT have additional properties", "retryable": false, "correlationId": "…", "details": { "field": "(body)" } }
```

**4b-4 — midnight rollover between render and Pay (`POST /purchases` with yesterday's `consentRevision`):**

```json
// 409
{ "code": "STATE_CONFLICT", "message": "The terms shown have been updated. Please review them and tap Pay again.", "retryable": true, "correlationId": "…",
  "details": { "reason": "CONSENT_REVISION", "contractVersion": 4, "order": { "…": "…", "useBy": "2026-09-24" }, "consent": { "…": "…" } } }
```

**4b-5 — new visitor, confirmed decline (mock fixture card `visa-0002`) — 201:**

```json
{ "purchaseId": "pur_…", "state": "FAILED", "checkpoint": "FAILED",
  "failure": { "step": "authorize", "code": "PAYMENT_DECLINED", "message": "Your card was declined.", "retryable": true },
  "payment": { "status": "declined", "brand": "Visa", "last4": "0002" },
  "person": { "created": true, "deactivated": true, "firstName": "Taylor" },
  "wallet": { "status": "not-requested" }, "sale": { "status": "not-attempted" },
  "pass": { "status": "not-issued" }, "delivery": { "status": "not-attempted", "renderer": "bff-stand-in" },
  "consent": { "passTermsVersion": "2026-09.3", "waiverVersion": "2026-09.1", "marketingOptIn": false } }
```

**4b-6 — Kelly, success (mock mode) — 201:**

```json
{ "purchaseId": "pur_…", "state": "COMPLETE", "checkpoint": "COMPLETE",
  "payment": { "status": "captured", "brand": "Visa", "last4": "4242" },
  "person": { "created": false, "firstName": "Kelly" },
  "wallet": { "status": "saved", "brand": "Visa", "last4": "4242" },
  "sale": { "status": "finalized", "receiptNumber": "R-000002" },
  "pass": { "status": "issued", "label": "Flex Day Pass", "beginDate": "2026-09-17", "expirationDate": "2026-09-23", "visits": 1 },
  "delivery": { "status": "sent", "renderer": "bff-stand-in", "channel": "email", "masked": "m•••@m.com" },
  "consent": { "passTermsVersion": "2026-09.3", "waiverVersion": "2026-09.1", "marketingOptIn": true },
  "receipt": { "receiptNumber": "R-000002", "item": "Flex Day Pass", "amountMinor": 3000, "currency": "USD", "beginDate": "2026-09-17", "expirationDate": "2026-09-23", "purchasedAt": "2026-09-17T20:05:12.000Z" } }
```

In platform mode the same result carries `"delivery": { "status": "delegated", "renderer": "dt", "channel": "email", "masked": "m•••@m.com" }` — the BFF sent nothing for the pass.

**4b-7 — deactivate failure (`deactivate-failure` fault) — 201, then `POST …/compensate`:**

```json
// 201
{ "state": "RECONCILING", "checkpoint": "RECONCILING",
  "failure": { "step": "deactivate", "code": "UPSTREAM_UNAVAILABLE", "message": "Your card was declined. We are tidying up your record; please do not pay again yet.", "retryable": false },
  "payment": { "status": "declined", "…": "…" }, "person": { "created": true, "deactivated": false }, "…": "…" }
// POST …/compensate after the fault clears → 200
{ "state": "FAILED", "checkpoint": "PERSON_DEACTIVATED", "failure": { "step": "authorize", "code": "PAYMENT_DECLINED", "…": "…" }, "person": { "created": true, "deactivated": true }, "…": "…" }
```

**4b-8 — expired saved card (Priya) — `GET /wallet` then `POST /purchases {payment:{kind:'saved', selectionRef}}`:**

```json
// 200
{ "status": "ok", "cards": [ { "selectionRef": "sel_…", "brand": "Mastercard", "last4": "5454", "source": "Saved online", "expired": true } ] }
// 400
{ "code": "VALIDATION_FAILED", "message": "That card has expired. Add a different card.", "retryable": false, "correlationId": "…", "details": { "field": "payment.selectionRef" } }
```

## 5. Purchase result, order and recovery (v4)

```
PurchaseResult {
  purchaseId, state: 'COMPLETE'|'FAILED'|'RECONCILING'|'PROCESSING', checkpoint,
  failure?: {step: 'validate'|'create'|'repaint'|'authorize'|'deactivate'|'revert'|'wallet'|'finalize-sale'|'capture', code, message, retryable},
  payment:  {status: authorized|captured|declined|voided|unknown|not-attempted|refunded, brand?, last4?},
  person:   {created, firstName?, deactivated?, reverted?},
  wallet:   {status: saved|not-requested|failed-retryable|unavailable, brand?, last4?},
  sale:     {status: finalized|failed|not-attempted|refunded, receiptNumber?},
  pass:     {status: issued|not-issued|not-attempted, label?, beginDate?, expirationDate?, visits?},
  delivery: {status: sent|pending|failed|unknown|delegated|not-attempted, renderer: 'dt'|'bff-stand-in', channel?, masked?},
  consent?: {passTermsVersion, waiverVersion?, storedCardVersion?, marketingOptIn},
  receipt?: {receiptNumber, item, amountMinor, currency, beginDate, expirationDate, purchasedAt}
}
```

Checkpoints: `VALIDATED → PERSON_PERSISTED → AUTHORIZED → WALLET_RESULT → SALE_FINALIZED → COMPLETE`, plus `PERSON_DEACTIVATED`, `PERSON_REVERTED`, `FAILED`, `RECONCILING`. `ISSUED` is gone: the pass **is** the prospect's access (`pass` is derived from the record's `{beginDate, expirationDate, visits}` and the offer name at `SALE_FINALIZED`).

```
validate (identity, eligibility, owned payment source, catalog re-read, consent revision incl. useBy)
→ reserve idempotent purchase + one consent snapshot                               VALIDATED
→ create new / repaint existing club-scoped prospect                               PERSON_PERSISTED
   {beginDate, expirationDate, visits, marketingOptIn, saleItemId, paymentTokenReference}
→ authorize against that prospect (unknown → status lookup → RECONCILING)           AUTHORIZED
→ save card only if auth succeeded AND save-card on                                 WALLET_RESULT
→ record product sale + confirm capture                                             SALE_FINALIZED
→ COMPLETE (delivery: mock stand-in 'sent'|'failed'|'pending'; platform 'delegated')
```

| Outcome | Recovery and visible result |
|---|---|
| Validation / contact conflict before create | No record, no payment; typed 4xx; conflict resets identity (as v3). |
| Create definite failure (`create-failure`) | `FAILED {failure.step:'create', payment:'not-attempted'}`; retry allowed (no mutation occurred). |
| Create response lost | `ProspectPort.lookupByOperation(operationKey)`; found → reuse; unresolved → `RECONCILING {step:'create'}`, no fresh create, no authorization. |
| Authorization **confirmed declined** | new record → `deactivate(memberId, {purchaseId})` (key `${purchaseId}:deactivate`); repainted record → `revert(memberId, previousAccess, {purchaseId})`; then `FAILED {step:'authorize', code:'PAYMENT_DECLINED', person.deactivated\|reverted:true}`; no wallet write, no sale. `FAILED` is written **only after** the compensation is confirmed. |
| Deactivate / revert failure or timeout (`deactivate-failure`, `revert-failure`) | one immediate retry → `RECONCILING {step:'deactivate'\|'revert'}`; log `prospect.deactivate-failed {purchaseId}`; owner-only `compensate` and the process-local sweep retry **only** that step; `already-inactive` / `already-reverted` count as done. |
| Authorization **unknown** (`auth-unknown`: timeout or thrown transport) | `PaymentPort.status(reference)`; `authorized` → continue; anything else → `RECONCILING {step:'authorize', payment:'unknown'}`; **never** a decline, **never** a blind deactivate. |
| Wallet failure after confirmed auth | `wallet.status:'failed-retryable'\|'unavailable'`, sale continues; `wallet-retry` with the same `providedId`. |
| Sale failure before capture (`sale-failure`) | void the authorization, compensate the prospect (deactivate / revert), `FAILED {step:'finalize-sale'}`; unknown void or compensation → `RECONCILING`. |
| Capture unknown after sale | resolve provider status; unresolved → `RECONCILING {step:'capture'}`; no second sale / capture; no success claim. |
| Confirmed payment, stand-in / DT delivery failure | `COMPLETE` with truthful `delivery.status`; desk fallback copy; no BFF credential. |
| Replay / concurrent | same key + fingerprint → stored result; different body → 409 `IDEMPOTENCY_CONFLICT`; a running or `RECONCILING` purchase blocks a new one for the checkout (409 `PURCHASE_IN_PROGRESS`); a `FAILED` purchase frees the checkout and the retry ("Try another card") reuses the known (now inactive) record identity through the directory — no duplicate. |

"Attempts logged, not persisted" (D65) forbids a failed-attempt reporting surface; it does not permit dropping idempotency or compensation state. Stores are in-memory in both modes today (V-P1). Compensation for a repainted record is scoped to `previousAccess` captured at repaint; the overlapping-active-pass case is excluded from the pilot until CF-15 / RQ-4 settle. No `STP_CREATE_BEFORE_PAY` switch (register row).

## 6. Order and consent rules (v4)

**Order shell** (created at verify / retryLookup, priced for the effective offer): `{offerId, offerName, amountMinor, currency, contractDays, visits, useBy, consents, saveCard:false}`; `useBy = clubLocalToday + contractDays − 1`, refreshed on every read (`toOrderSummary`) so a shell that crossed midnight shows the new quote; the revision binds it, so Pay on the old render is a 409 `CONSENT_REVISION`.

**Consent document set** (`ClubCatalogPort.getConsentDocuments(club, offer, {todayIso})`):

```
ConsentDocument    { id:'waiver'|'passTerms'|'storedCard'|'privacy'|'marketing', title, templateVersion, renderedHash, html, meta, requiresAffirmativeAct, approval }
ConsentNotice      { id:'emailTransactional'|'smsTransactional', copy, version }
ConsentDocumentSet { documents[5], notices[2], waiverRequired, payButtonText, consentRevision, approval }
```

Templates: waiver `2026-09.1` (club `waiverText` / `consentOverrides.waiver` wins when present — CF-18 fallback is the US template; the fallback still says "18 or older" → **CF-08 for Kelly, never rewritten silently**), **Pass Terms `2026-09.3`** ("{offerName} to {legalName}. {validityLine} · use by {useByLabel}. Price {amount} including tax. One-time purchase — no membership, no renewal, no recurring billing." + `PASS_TERMS_REFUND_SENTENCE`), stored card `cof-v1`, privacy `2026-09.1`, **marketing `2026-09.1`** (Design v6 `DOCS.marketing` with `{legalName}` interpolated where v6 hard-codes "Core South"; title "Marketing communications"; meta "Optional. Not a condition of purchase. Checked state, timestamp and the exact text shown are retained as the TCPA prior-express-written-consent record."; `requiresAffirmativeAct:false`; `approval:'PROPOSED'` until CF-09). `renderedHash = sha256(title + meta + whitespace-normalised html)`. `consentRevision = sha256(every id:renderedHash, every notice id:version, pay:${payButtonText}, commercial:${offerId}|${amountMinor}|${currency}|${contractDays}|${visits}|${useBy})`.

**Order consents:**

```
waiver         { required, accepted, templateVersion, renderedHash, method?, at? }   — reset every purchase (D53)
storedCard     { shownVersion, shownAt? }
marketingOptIn { optedIn, templateVersion, renderedHash, at? }                       — the `marketing` document the box sat next to; explicit false recorded
notices        { emailTransactional:{version, shownAt}, smsTransactional?:{version, shownAt} }
```

**Pay-time attestation** unchanged (`{consentRevision, payButtonText}`; 409 `CONSENT_REVISION` before any side effect). **Consent snapshot** (`PurchaseRecord.consents`, one per purchase at `VALIDATED`): `{surface, checkoutId, capturedAt, memberId?, consentRevision, waiver, storedCard?, marketingOptIn:{optedIn, templateVersion, renderedHash, at?}, notices, passTerms, privacy, ipHash, userAgentHash}` — **no `adult`**. The `marketingOptIn.optedIn` value (true **or** false) travels on the create / repaint call. Both lanes show the marketing checkbox (recognized: stored value pre-filled when the directory knows it).

## 7. Fixture identities, catalog and fault switch (mock adapters, v4)

| Club | Number | Zone | Products (`offerId` · name · price · contractDays · visits · flag) |
|---|---|---|---|
| Riverside Athletic Club (pilot shape) | 90030 | America/Chicago | `day-pass` · Day Pass · $18.00 · 1 · 1 · on |
| Riverside — Eastside | 90031 | America/Chicago | `day-pass` on; `onlineProspects:false` (proves the gate no longer needs it) |
| Riverside — Northside | 90032 | America/New_York | `day-pass` on; club-authored `prospectTerms` and waiver override |
| Core Health and Fitness Club — South (layout club) | 90033 | America/Chicago | `core-day-pass` · Day Pass · $25.00 · 1 · 1 · on; `core-flex-pass` · Flex Day Pass · $30.00 · 7 · 1 · on; `core-anytime-pass` · Anytime Day Pass · $35.00 · 30 · 1 · on; **`core-3-visit-pass` · 3-Visit Pass · $60.00 · 7 · 3 · on → hidden in v1**; **`core-towel-service` · Towel Service · $5.00 · 1 · 1 · flag off → hidden** |

Windows other than 1 day prove arithmetic and layout; they are not permission to configure a multi-day pilot (D72).

| Person | Kind / club | Email | Card | Purpose |
|---|---|---|---|---|
| Jordan Reyes | prospect / 90030 | `jordan.reyes@email.com` | Visa 4242 | Riverside returning buyer; `access` from a past pass (expired range) |
| Kelly Reyes | prospect / 90033 | `m@m.com` | Visa 4242 | Core returning buyer; `marketingOptIn:true` known → pre-filled |
| **Priya Patel** (v4) | prospect / 90033 | `priya@example.com` | **Mastercard 5454, expired 2026-08** | expired chip → hosted slot; saved purchase → 400 |
| Casey Morgan | member / 90030 | `casey@example.com` | Mastercard 4444 | member block (D12) unchanged |
| Riley Chen, Dana Whitfield, Morgan Blake, Sam / Alex Patel | as v3 | — | — | no card / inactive card / decline / ambiguous |

Mock capture fixture cards: `visa-4242`, `mastercard-4444`, `visa-0002` (declined), `visa-0003` (authorization unknown → status resolves authorized), `visa-1111-expired`. Mock prospect records carry `access {beginDate, expirationDate, visits, active}` and a 12-character `barcode` (DT assigns one; the stand-in email prints it as text). Receipts `R-000001…`.

Fault switch (`STP_MOCK_FAULTS` at boot or the in-process `faultSwitch`): `decline`, **`auth-unknown`** (renamed from `auth-timeout`; also covers a thrown transport), **`create-failure`** (renamed from `prospect-failure`), **`create-response-lost`**, **`deactivate-failure`**, **`revert-failure`**, `wallet-failure`, `wallet-unavailable`, `wallet-response-lost`, `sale-failure`, `delivery-failure`, `void-unknown`. `issue-failure` is removed with the issue step.

## 8. Adapter register (v4)

Selection: `services/shortTermPass/adapters/index.ts` builds the set from `STP_ADAPTER_MODE` and `STP_CATALOG_SOURCE`; `adapters.capabilities()` prints the capability table (demo, E5). Every live capability without an adapter fails closed with `NOT_ENABLED` (501), never a fixture success.

| Port | Mock that ships | Platform adapter (Sprint 0004) | Real upstream | Gate / owner |
|---|---|---|---|---|
| `ClubCatalogPort` — `resolveClub`, `getOffers`, `getConsentDocuments`, `capability` | `MockClubCatalog` (§7; skipped items listed) | **`DatatrakServiceCatalog`** (`STP_CATALOG_SOURCE=datatrak`), **v4.1 (Sprint 0005 D1):** `resolveClub` ← `GET {url}/club/getClubDefaultExternal.spr?clubNumber=` (name, `prospects`, base64 `prospectTerms`, address; **on the DT service flag:** base64 `prospectLiability` → waiver override, `timezone` → validated zone id — §8a(e)); `getOffers` ← **`GET {url}/club/guestPassItems.spr?clubNumber=`** (club-scoped, member-less; the single-item re-read adds `&saleItemId=`) — the POS `saleItems.spr` is no longer called (CF-14 not required); the flag-off / unknown-club envelope (`messages.status = error`, `saleItems = null`) is "no offers" (gate 404), never a fixture; `itemType` must be `PRODUCT` / `SERVICE` / `BILLING` (unknown or missing → skipped `unknown-type`); 60 s cache; fail-closed per club when a field is missing or the timezone is not a Node-supported id (`missing: ['timezone:invalid']`); capability report split into club / offers / consent texts / timezone and `dtFields: present | absent (off, old code or columns missing — unknown which)` — an observation, never a claim about the remote flag; fixtures under `fixtures/datatrak/*` are **labelled `recorded` (what dev answered on 2026-09-18 — the absent / off case) or `synthetic` (the v4.1 on shape until a dev recording replaces it)** | DataTrak service layer (`.spr` web services MICO's `OrasvcClient` / `oraSvcRestTemplate` call); fields and the new endpoint from the datatrak-service PR of Sprint 0005 (verdict 3 pending until it is merged, the scripts run and the flag is on) | CF-13 (code prepared — pending DT review, merge, scripts, flag), CF-14 (not required), CF-20 (names), DT credential secret (PLATFORM); timezone values (RQ-11, Chancy / Terry) |
| `IdentityDirectoryPort` | `MockIdentityDirectory` (+ `access`, `barcode`, `marketingOptIn`) | none → `NOT_ENABLED` | club-scoped lookup by email | OQ-1 |
| **`ProspectPort` v4** — `create(input, operationKey)`, `repaint(memberId, access, operationKey)`, `deactivate(memberId, {purchaseId})`, `revert(memberId, previousAccess, {purchaseId})`, `lookupByOperation(operationKey)` | `MockIdentityDirectory` (serialized per person/club; faults §7) | none → `NOT_ENABLED` | DT `/member/addProspect.spr` (+ update / deactivate — CF-15) | CF-15 (field names for begin / expiration / visits / item / opt-in; one value vs four `comm*` flags — MICO sets `commDirectMail`, `commEmail`, `commPushNotif`, `commSms` from one consent; idempotency; deactivate / conditional update), RQ-4, RQ-7 |
| `PaymentPort` — `authorize`, `status`, `capture`, `void`, `refund` | `MockPaymentGateway` (idempotent by reference; `auth-unknown`) | none → `NOT_ENABLED` | Ignite Payment Gateway | OQ-3 |
| **`PassSalePort` v4** — `finalizeSale({purchaseId, memberId, clubNumber, saleItemId, offerId, amountMinor, currency, beginDate, expirationDate, visits, authorizationRef})` only | `MockPassSale` (receipts; no `issue`, no QR) | none → `NOT_ENABLED` | DT `/pos/onlineSale.spr` | OQ-3 |
| `WalletPort` (+ `expired` on `listEntries` consumers) | `MockWallet` (+ Priya) | `PlatformWallet` (dark, `STP_WALLET_*`) | universal-wallet | L3 / R16 |
| `VerificationPort` (OTP) | `MockOutbox` / `SmtpMailer` — **template slot** `STP_OTP_TEMPLATE_PATH` or the built-in PROPOSED template; `{{code}}`, `{{clubName}}` only | `EmailPublisherMailer` (same template) | email-publisher-service | CR-29 / CR-34 (Chancy's HTML) |
| **`DeliveryPort` v4** — mock mode only | `MockOutbox.deliver` / `SmtpMailer` → **`prospectMailStandIn`**: subject "Your Day Pass at {club}", banner "Stand-in for the DataTrak prospect email — DataTrak sends the real one with the QR", barcode as text, begin / expiration dates, acknowledged Pass Terms / waiver / opt-in texts, receipt block, **no image part, no link** | **none — the BFF sends no pass email in platform mode** (`delivery.status:'delegated'`, `renderer:'dt'`) | DataTrak prospect email (D52, D63) | RQ-0, RQ-2, RQ-3 |
| `CheckoutStorePort`, `PurchaseStorePort` | in-memory | in-memory | durable stores | V-P1 |
| `PayPageSessionReader` | mock | `PlatformPayPageSessionReader` | Order Service session API | B1 (credentials) |
| ~~`PassCredentialStorePort`, QR renderer~~ | removed | removed | — | cancelled (D63) |

### 8a. Sprint 0004 A2 feasibility findings (2026-09-18, time-boxed)

**(a) DataTrak service layer, dev, MICO's credential, no member id — probed; CF-13 blocked, CF-14 refused.** Base `https://datatrak-service.dev.abcfitness.net/external` (MICO `orasvc-client.url` + `path`), static Basic `Authorization` (MICO `MicoProperties.dtServicesBasicAuth*` — value read from the local MICO config into a shell variable, never printed, never committed). Club `09003` (a real dev club).
- `GET /club/getClubDefaultExternal.spr?clubNumber=09003` → **200** `application/json;charset=ISO-8859-1` (14.5 KB) and, with `Accept: application/xml`, **200** `application/xml` (`<clubDefaultExternalResponse><club>…`). Shape: `club.{number, name, phone, website, facebook, twitter, billingCountry, classes, prospects (bool — the online free-trial switch), prospectTerms (base64 HTML: "PHA+dGVzdDwvcD4=" → "<p>test</p>"), address{address1, address2, city, state, stateName, zip, country}, branding{primaryColor, secondaryColor, backgroundColor, image (data URI), imageBytes, theme, brandColor}, hideEnrollPage}`. **No timezone, no waiver text, no guest-pass fields** → the adapter maps name / prospects / prospectTerms / address and fails closed on timezone until a source exists (CF-13 residual: timezone). Recorded, scrubbed (address, phone, image) as `fixtures/datatrak/getClubDefaultExternal.recorded.json`.
- `GET /pos/saleItems.spr?club=09003` (no `memberId`) → **400** `application/problem+json` `{"title":"Bad Request","detail":"Required parameter 'memberId' is not present."}`; with `memberId=` (empty) → **200** `{"club":null,"saleItems":null,"messages":{"status":"error","message":[{"text":"Invalid request."}]}}`. **CF-14 refused:** the sale-items query is member-scoped; a pre-identity catalog read needs a club-scoped query (or a members-free variant) in Chancy's DT PR. Both responses recorded. The v3 MICO DTO (`SaleItem`: `saleItemId, catalogItemName, catalogPrice, catalogDefaultQuantity, saleItemDiscountId, eventName, eventTypeId, eventDescription, scheduleEventType, bookOnline, catalogMinQuantity, catalogMaxQuantity, expiration, unlimited, taxed, eventDeployedToClub` + discount `percentage, fixedAmount, name, description`) carries **no `guestPassOnline`, `contractDays` or `visits`** → the synthetic fixture `saleItems.synthetic.json` adds exactly those three fields and is labelled as the shape the DT PR must expose (CF-13).
- Without a credential the gateway answers **404** `{"error_code":"N404"}` — fail closed; the adapter treats every non-200 as "club unavailable".
- MICO's `AddProspectRequest` (`abc-common-5.9.0.jar`, `com.abcfinancial.ws.prospect`) is set from `ProspectController` with `club, firstName, lastName, street, address2, city, state, zip, email, issueDate, signatureImage, campaign, country, primaryPhone, cellPhone, referredById, agreementEntrySource` and the four consent flags `commDirectMail, commEmail, commPushNotif, commSms` from **one** `messagingConsent` value; begin / expiration / visits / item fields are not set by MICO's path → **CF-15 open** (Chancy / Mark). Platform `ProspectPort` stays `notEnabled`.

**(b) `ctx.hostname` behind the ingress — verified in code, runtime proof in E3.** `services/application.ts` sets `app.proxy = isProduction` (`NODE_ENV !== 'development'`, so true in dev); Koa then resolves `ctx.hostname` from `X-Forwarded-Host` first, falling back to `Host`. ingress-nginx sets `X-Forwarded-Host` to the request host by default. The standalone-host middleware therefore compares `ctx.hostname` (lower-cased, port stripped) with `STP_STANDALONE_HOSTS`; the E3 dev smoke on `guestpass.dev.abcfitness.net` is the runtime proof.

**(c) Dev hooks through the pod — passes.** `POST https://onlinejoin.dev.abcfitness.net/api/short-term-pass/checkouts` → 201 (BFF `v1.2.3`, mock mode); `GET …/testing/state` through the ingress → **403** (loopback rule intact); `kubectl --context k8s-lower-wlr -n dev port-forward deploy/online-join-bff 18080:8080` then `GET http://127.0.0.1:18080/api/short-term-pass/testing/state?checkoutId=…` with the dev key → **200** `{checkout:{id, state:'identify', generation:0, …}, purchases:[], wallet:{…}, outbox:[]}`. No policy change needed (R14).

**(d) `addProspect` field names / deactivate — asked, unanswered.** Handoff text recorded under CF-15 (§10); until answered the platform `ProspectPort` is `notEnabled` and the mock proves the order.

### 8a(e). Sprint 0005 A2/A3 — the DataTrak service-layer field table (v4.1, frozen 2026-10-07; names proposed until CF-20)

**A2 decision — local DTO pair, no jar bump.** The club-defaults response types (`ClubDefaultExternalResponse`, `ClubDefaultExternal`) come from `com.abcfinancial.rest.api:internal-interface:4.2.0`. datatrak-service answers the on path with a local pair — `GuestPassClubDefaultExternalResponse extends ClubDefaultExternalResponse` (same `@XmlRootElement(name="clubDefaultExternalResponse")`, `@XmlSeeAlso`) and `GuestPassClubDefaultExternal extends ClubDefaultExternal` (`@XmlType(name="guestPassClubDefaultExternal")`, both new fields `@XmlElement(required=false)` + `@JsonInclude(NON_NULL)`) — and the jar types on the off path. Spike run 2026-10-07 (standalone `javac` + TestNG, `GuestPassClubDefaultSerializationSpikeTest`, 7 / 7; version proxies recorded in `SPRINT-0005-BLOCKERS.md` §A2): off bodies carry neither field; on JSON = off JSON + the two fields; on XML keeps the root and carries the two elements inside `<club xmlns:xsi=… xsi:type="guestPassClubDefaultExternal">`; no-`Accept` = XML; null fields are omitted in both media types; **the on-path XML unmarshals into the jar envelope with the unknown `xsi:type` ignored** (the club arrives as the jar `ClubDefaultExternal`, every shared field intact) — this is what MICO's `oraSvcRestTemplate` does (a `RestTemplateBuilder` default: `Accept` lists XML before JSON, the Jaxb2 converter reads the body); on-path JSON deserialises into the jar envelope with `FAIL_ON_UNKNOWN_PROPERTIES=false` (MICO's `WsShop` setting). RQ-10 / RQ-12 (jar follow-up) stay open; the pair ships. JSON tolerance is not XML tolerance — the XML unmarshal is the proof MICO needs.

**Flags (two keys, club context, default off everywhere; one decision per operation shared by query, binds and mapper):**

| Repo | Constant | Key | Evaluator |
|---|---|---|---|
| datatrak-service | `LDFeatureFlagConstants.GUEST_PASS_FIELDS` | `datatrak-service-DT-21555-guest-pass-fields` | `com.abcfs.launchdarkly.helper.GuestPassFeature.isOn(clubNumber)` — canonical five-digit club number required, else `false` locally; `computeBooleanFeature(key, vpd, club, false)`; any exception → `false` + warn |
| datatrak (M&O, PR #6643) | `LDFeatureFlagConstants.MO_GUEST_DAY_PASS` | **`MO_guest_day_pass_DT-21555`** (Paul Knuth, 2026-10-07 `0d0f2d06` — supersedes the planned `datatrak-DT-21555-guest-pass`) | `com.abcfinancial.datatrak.common.launchdarkly.GuestDayPassFeatureFlag.isOn(clubNumber)` — blank club → `false` locally; `FeatureService` missing or throwing → `false` + warn |

**`GET /external/club/getClubDefaultExternal.spr?clubNumber=` — unchanged when off (byte-identical SQL, binds, classes, bodies); on the service flag the `club` object gains:**

| Field | Type | Source | Encoding / null rule | Flag |
|---|---|---|---|---|
| `club.prospectLiability` | string | `SPL_EXTENSIONS.SPLEX_PROSPECT_LIABILITY` (left join on `spl_id` + `vpd_id`; `VARCHAR2(4000)` bytes — CF-21) | base64 of the stored HTML, **exactly like `prospectTerms`**: a null column (or no `spl_extensions` row) is encoded as `""` → `""` | on only; absent when off |
| `club.timezone` | string | `TIMEZONELOOKUP.TZL_ABC_CODE` via `SERVICEPROVIDERLOCATIONS.TZL_ID` (left join) | emitted as the lookup value normalised by the service (`ZoneId.of` accepted as is; `ZoneId.SHORT_IDS` alias mapped; otherwise raw + warn); **absent** (omitted) when the club has no lookup row; the BFF validates strictly (`Intl.supportedValuesOf('timeZone')` + alias map) and closes the club on an unknown id — never GMT (RQ-11) | on only; absent when off |

Every existing field, `branding` and `hideEnrollPage` are unchanged in both states. On a `BadSqlGrammarException` whose cause is `ORA-00904` (columns not yet added) the service warns once per club (`guest-pass.columns-absent`) and answers the **off** shape — a compatibility proof, not the rollout order.

**NEW `GET /external/club/guestPassItems.spr?clubNumber=[&saleItemId=]`** (in `ClubExternalController`, same `produces` / header match / `setVpdFromClubNumber` prelude as `getClubDefaultExternal`; the POS `saleItems.spr`, `OnlinePosValidator` and `repository/pos/**` are **untouched**). Envelope (local JAXB DTOs `GuestPassItemResponse { club, saleItems { saleItem[] }, messages }`, the `SaleItemResponse` style):

| Field | Type | Source | Rule |
|---|---|---|---|
| `club` | string | request `clubNumber` | echoed |
| `saleItems.saleItem[]` | list | `SALEITEMS sai JOIN CATALOGITEMS cgi` where `sai.spl_id = :splId AND sai.sai_active='1' AND cgi.cgi_active='1' AND sai.sai_guest_pass='1' AND cgi.cgi_service='0' AND cgi.cgi_online='1'` (RQ-15 position) `[AND sai.sai_id = :saleItemId]`, `ORDER BY cgi.cgi_name` | **on** only; products only by the `WHERE`; services never rows |
| `saleItem.saleItemId` | string | `SAI_ID` | — |
| `saleItem.catalogItemId` | string | `CGI_ID` | — |
| `saleItem.catalogItemName` | string | `CGI_NAME` | — |
| `saleItem.catalogPrice` | string | `CGI_SALE_PRICE` | as `SaleItem.catalogPrice` (string) |
| `saleItem.salePrice` | string | `SAI_SALE_PRICE` | the club's deployed price; the BFF prices from `salePrice` when present, else `catalogPrice` |
| `saleItem.taxed` | boolean | the `taxed` CASE copied from `GET_ONLINE_SALE_ITEMS` | — |
| `saleItem.guestPassOnline` | boolean | `SAI_GUEST_PASS = '1'` | always `true` by the `WHERE`; kept on the wire for the BFF's filter |
| `saleItem.guestPassContractDays` | int | `SAI_GUEST_PASS_CONTRACT_DAYS` (from `SALEITEMS`, not the catalog default) | `0` / null → BFF skips `invalid-contract-days` |
| `saleItem.guestPassVisits` | int | `SAI_GUEST_PASS_VISITS` | v1 sells `1` only (`multi-visit` skipped) |
| `saleItem.itemType` | `PRODUCT` \| `SERVICE` \| `BILLING` | `CGI_SERVICE` `0` / `1` / `2` | always `PRODUCT` here; the BFF rejects anything else (`unknown-type`) |
| `messages` | `{status, message[{text}]}` | — | `success` with rows (an empty list is still `success`); **`error` + `"Not available"` + `saleItems = null` when the flag is off, the club is unknown or the columns are absent (ORA-00904 → warn once per club)**; flag off executes **no SQL** |

Byte-identical means the full deterministic body through the real converters under fixed inputs, for `application/json`, `application/xml` and no `Accept` (XML). MICO XML finding: `WsClubDefaults.getDtClubDefaultExternal` receives XML into the jar envelope (above); MICO's sale items go through Feign + Jackson into `WsShop`'s tolerant mapper and do not call the new endpoint.

**Shared-catalog editing (CF-23):** PK's gating evaluates the flag per **destination club** on the sale-item sync (`CatalogItemsDB.addSaleItem` / `updateSaleItemRecord` via `ClubDB.getClubNumber(connection, clubId)`; `CatalogItemDaoImpl` by the sale item's club), so a shared catalog edited from a flagged club writes guest values only to flagged destinations.

## 9. Hosting — standalone Guest Pass host on the existing BFF (D60, CR-27, CF-11)

`STP_STANDALONE_HOSTS` (comma list; empty = today). Middleware `standaloneHost` (before the routers and the history fallback) tags a request whose `ctx.hostname` matches; on such a host: `GET /` and `GET /guest-pass` (with or without `?club=`) serve the Guest Pass entry document with `window.guestPass = {standalone:true, basename:'/'}`; the history fallback maps `/`, `/guest-pass`, `/pass` (and their sub-paths) to the SPA; membership SPA paths (`/signup/*`) and every API outside `/api/short-term-pass/*` and the guest-pass `/api/pay-page/*` routes (`POST /api/pay-page/session/short-term-pass` and the session poll/close used by the embed, with their existing ownership controls) answer the generic 404; `/probe/*` stay. On the existing host nothing changes (`/signup/day-pass`, `/signup/guest-pass` alias, `/signup/pass`; entry document `basename:'/signup'`). UI: `PAGES.guestPass='/guest-pass'`; `index.tsx` reads `globalThis.guestPass?.basename ?? '/signup'`; `App.tsx` treats `/guest-pass` like `/day-pass`; completion still moves to `/pass`. Helm (D1): second host + TLS on `ingress[0]`, `STP_STANDALONE_HOSTS`, both origins in `STP_ALLOWED_ORIGINS`, `STP_CATALOG_SOURCE=fixture`, the three pass-link keys removed. Prod host, Cloudflare rules (PK) are V-P3.

## 10. Readiness, CF and RQ registers (v4)

**Verdict vocabulary (four separate verdicts, never merged):** (1) implementation and mock acceptance; (2) standalone dev host; (3) live integration — DataTrak catalog read {done | blocked CF-13/14}, prospect create/repaint/deactivate {mock only — platform port `notEnabled`}, hosted capture {verified | unverified B1}, QR / prospect email / access enforcement = DataTrak's and unverified from this build; (4) pilot — not eligible until V-P0…V-P6 pass. A failed gate is named, never absorbed.

| Capability | Status at A3 (E5 updates) | Evidence | Gate / owner |
|---|---|---|---|
| Contract v4 frozen; v3 fields deprecated in both type files; `tsc` green | done 2026-09-18 | this §4; BFF `schemas.ts`, UI `interfaces/api/shortTermPass.ts` | V0 · UI+BFF |
| Fixtures v4 (§7), `validity.ts` v4 helpers with boundary tests, UI factories | done (A4) | `catalog.test.ts`, `identityDirectory.test.ts`, `consentTemplates.test.ts`, `validity.test.ts`, UI `shortTermPassTestData.test.ts` | V0 |
| Removal inventory executed with `rg` proof | done — BFF B0 `61b32cf`, UI C0 `5b6e541`; `rg` proof in `SPRINT-0004-BLOCKERS.md` §Removal inventory | `SPRINT-0004-BLOCKERS.md` §Removal inventory | V0 / V4 · SECURITY+BFF+UI |
| Catalog-driven single-visit checkout (U1–U6) | done — **mock** (BFF router suites; UI C1–C3 tables; E2 smoke 71 / 71 Riverside + Core) | router tests, jest tables, smoke | V1 · PRODUCT+QA |
| Design v6 parity, approved deltas (VALID_DAYS, adultCb, refund sentence CF-16, "Core South" → `{legalName}`, perks not rendered — D57) | done — copy / layout tables (C9), screenshots 1440 / 375 / 320–440; DESIGN observer not consulted this sprint | copy / layout tables, screenshots 1440 / 375 | V2 · UI+DESIGN |
| Purchase order and recovery (U8–U12, U15, U24) | done — **mock** (orchestrator + `compensation.test.ts`; demo 3 / 4 / 6; E2 flows decline → deactivated, decline → reverted, RECONCILING → compensate) | orchestrator + `compensation.test.ts`, demo 3 / 4 / 6 | V3 · BFF+QA+PK |
| No QR, no pass page, no age gate (U25 part) | done — leak / static scans in both repos, lockfiles, `GET /passes/*` 404, E2 state / DOM scans | leak tests, lockfiles, guard tests | V4 · SECURITY+BFF+UI |
| Consent and opt-in evidence (U7, U13) | done — snapshot tests both lanes; E2 Kelly snapshot `marketingOptIn {optedIn, templateVersion, renderedHash}`; LEGAL observer not consulted | snapshot tests, both lanes | V5 · LEGAL(observer)+BFF |
| Quality floors, Sonar, demo 0–6 | done — UI 111 / 112 suites (transformers baseline), 95.75 % lines / statements; BFF 68 / 68, 97.42 / 85.98 / 97.13 / 98.26; demo 58 / 58; lint clean both; Sonar gates green on #532 / #107 after the first-scan findings were fixed | validation docs | V6 |
| Host-scoped routing, helm PR, dev smoke on both hosts, DataTrak adapter unit-pinned, live read | routing: done locally (E2 standalone-host flow on `guestpass.localhost`); helm #3090 open, unmerged; E3: pass for the deployed v3 build, v4 assertions pending the deploy; adapter unit-pinned; live read blocked (E4) | `standaloneHost.test.ts`, smoke §dev, this §8a | V7 · PLATFORM+QA — each item its own verdict |
| DataTrak catalog **live read** | **blocked** (CF-13: fields absent; CF-14: member-less query refused); E4 boot 2026-09-18 with `STP_CATALOG_SOURCE=datatrak` failed closed (404 on `POST /checkouts` for 09003 / 90030) — the dev service host did not resolve from the executor's network in that session, so no live shape was observed | §8a(a); smoke §live | E4 records blocked · Chancy → PK |
| Prospect create / repaint / deactivate **live** | mock only; platform `notEnabled` | §8 | CF-15 · Chancy / Mark |
| Hosted capture (Pay Page) | unverified locally (B1); dev has credentials — E3 records the result truthfully | smoke §dev | PAYMENTS+QA |
| LD flag `guest-pass-online` (club kind, default off) in dev / prod | pending PLATFORM ticket (D3) — **no ticket id issued**: the executor has no ticketing tool; handoff text in `SPRINT-0004-EXECUTION-SUMMARY.md` §Handoffs; override stands in | — | CF-17 · PLATFORM |
| DT credential in `platform-online-join-bff` | pending PLATFORM ticket once CF-13 holds — no ticket id (same handoff) | — | PLATFORM |
| **LaunchDarkly keys for the two DataTrak flags (Sprint 0005 A5):** `datatrak-service-DT-21555-guest-pass-fields` (datatrak-service, constant `GUEST_PASS_FIELDS`) and `MO_guest_day_pass_DT-21555` (datatrak, constant `MO_GUEST_DAY_PASS`, PK 2026-10-07) — boolean, club context, **default off** in dev and prod, no club targeted until runbook R3/R4 | pending — keys named identically in both constants classes, both local yml files, §8a(e) and the runbook; creation is CF-24 (PLATFORM / Chancy / PK), no ticket id | §8a(e); `docs/deploy/guest-pass-db-and-flags.md` R0 | CF-24 · PLATFORM / Chancy / PK |
| Cloudflare rules + prod host | pending PK — D3 handoff, no ticket id | — | V-P3 · PK, RQ-5 |
| Durable stores, service-owned reconciliation | not built (in-memory by declaration) | — | V-P1 |
| Harness lane / simulated agents | deferred by the user | — | V-P5 · Mark |

**Confirmations (CF) and requests (RQ) — owner slots, effect if unanswered:** CF-08 waiver enforceability with no age gate; fallback waiver copy says "18 or older" (Kelly + Legal; ships PROPOSED, no DOB) · CF-09 opt-in text in a modal acceptable to legal and Twilio (Kelly; modal ships, inline variant is a copy switch) · CF-10 any rule requiring the pre-payment record (PK; D65 order ships) · CF-11 repo home — **answered 2026-09-17: existing repos + standalone host** · CF-13 DT service layer exposes `guestPassOnline`, `contractDays`, `visits`, waiver text, timezone (Chancy → PK; **blocked 2026-09-18** — fields absent from `getClubDefaultExternal.spr`, `SaleItem` DTO) · CF-14 `saleItems.spr` for a club with no member (Chancy; **refused 2026-09-18** — 400 "Required parameter 'memberId'") · CF-15 `addProspect` field names for begin / expiration / visits / item / opt-in (one value vs four `comm*` flags), idempotency, deactivate / conditional update (Chancy / Mark; platform port `notEnabled`, overlapping-active-pass case excluded from pilot) · CF-16 v6 refund sentence vs PRD D15/D22 (PM + Legal; PRD sentence stays) · CF-17 flag key `guest-pass-online` (PLATFORM / Bjorn; rename ships, override in dev) · CF-18 club with no waiver text (Kelly + Chancy; US template fallback ships) · RQ-0 does DT send the prospect email on create, before payment? (Chancy + Mark; **no pilot** — V-P0) · RQ-1 exact copy for 1-day validity and the pending / failed delivery variants (DESIGN; draft pinned) · RQ-2 DT re-send on request (Chancy; no resend on the page) · RQ-3 how DT reproduces the acknowledged texts (Chancy; stand-in documents the expected content) · RQ-4 returning prospect with unconsumed paid access whose repaint fails (Kelly + Chancy + Mark; excluded from pilot, mock proves revert) · RQ-5 prod host and Cloudflare rules (PK) · RQ-6 parity inputs re-baseline (Bjorn; left at v4) · RQ-7 payment token on the create call (Mark; server-resolved `paymentTokenReference`, nothing saved before `AUTHORIZED`) · RQ-8 Jira epics (Bjorn → Chancy) · RQ-9 recognized members blocked (PRODUCT; existing behaviour).

**Carried from Sprints 0001–0003:** S5 hosted Pay Page (B1) and S2/S7 harness (deferred) carry unchanged; Sprint 0003 rows closed by cancellation — rotating QR + desk verifier, CF-06 link lifetime, CF-07 static vs link-only, durable credential store, publisher image fetch, PA-1 / PA-2 (routes removed); rows that stay — durable stores and async purchase status (V-P1), live re-pricing after verify (Change / Start again re-selects), staff revoke / discovery (DT), sprint-wide `generation` matrix, metrics, Turnstile, accessibility audit, semantic-index expansion; CF-04 pricing per item from the catalog (closes with V-P1); CF-05 window semantics closed by D48 / D71.

**Deferred to v2 (recorded so nobody rebuilds cancelled items):** multi-day / multi-visit passes and any future start date; pass extension on repeat purchase; guest definition revisit (D73); no prospect record unless payment succeeds; the dynamic-link credential; the BFF QR renderer and the "View your pass" page (cancelled — D63); link-use counter; 18+ checkbox (reversed — D66); minimum age via M&O, DOB, minor queue; waiver versioning and once-per-club state; "what's included" / perks copy per item (D57); reporting and insights; service modelling (D70); club-settings item picker (D61); new `guest-pass-*` repos; harness lane; durable stores and service-owned reconciliation (V-P1).
