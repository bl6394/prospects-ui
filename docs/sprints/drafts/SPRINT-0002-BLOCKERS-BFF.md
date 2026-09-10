# Sprint 0002 — BFF lane: blockers, deviations and notes

Executor: Claude Fable 5.1, BFF lane (parallel with the UI lane), 2026-09-10. Repo `repos/online-join-bff`, branch `prospect-wallet/sprint-0001`, entered at `289220e` (Phase A), left at `fc77007`. Scope: Implementation Plan Phase B (B1–B6), Addendum P1-3 and P1-4, the 429 `retryAfterSeconds` P2 item, E4 for the BFF only. Not pushed; no PR touched; dev servers on :3000/:3001 not started, stopped or restarted.

## Blockers

### B1 — Pay Page dev credentials still absent (unchanged, not a Phase B dependency)

Checked by key name only: `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN`, `ABC_CORE_API_URL` are not in `repos/online-join-bff/.env`. No values were printed. `npm run demo:short-term-pass -- --hosted` reports BLOCKED; gate S5's hosted evidence stays *pending*; the register reads "hosted capture unverified (B1)". Nothing in Phase B depended on them; the BFF side of S5 (capture defaults `paypage`, mock capture unreachable without hooks, boot guard) is implemented and pinned.

### No other blockers. Every Phase B task, both P1 fixes and E4 completed.

## Deviations (none from contract v2; behavioural clarifications recorded for the UI lane and the orchestrator)

### D-1 — `schemas.ts` v2 landed in stages, not in one B1 commit

The brief asked for the previous executor's in-progress v2 `schemas.ts` to be finished and landed with B1. Its full v2 shape (order `consents`, `PurchaseRequest.attestation`, `PurchaseProfile.mobile`, `consent` on responses, `testHooks`) type-failed 27 sites that only B3, B4 and B5 replace, so landing it whole with B1 would have meant implementing B3+B4+B5 in the same commit or committing a red build — both forbidden by the same brief ("every commit must build and its suite must be green"). Resolution: the file was reconciled against contract v2 §4 and split by task. `34b5493` carries the identify / verify / challenge / generation / snapshot half with the v1 remainder marked `@deprecated v1`; `7ecdf58` (B3), `9ad75d8` (B4) and `531f4f4` (B5) each replace their section. At `531f4f4` `schemas.ts` equals the reconciled v2 file and matches contract §4 route by route. Nothing from the previous executor's diff was discarded; the only changes to it were: `TermsMethod` alias dropped once `terms` left, `MOBILE_PATTERN` relaxed to `{0,32}` so a blank mobile reaches the service's "Please add your mobile number." message instead of a generic schema error, and `documentId` enum spelled out.

### D-2 — An unknown cookie is refused with 401 `CHECKOUT_EXPIRED` but is **not** cleared

Contract §4 (P1-3) says a missing or unknown cookie answers 401 `CHECKOUT_EXPIRED`; it does not say whether the cookie is cleared. Clearing it turned out to be harmful: when two requests race the verify rotation, the loser still carries the previous cookie value, is "unknown", and a `Set-Cookie` clear on that response wipes the *new* session the winning tab just received (the HTTP harness reproduced this). The BFF therefore clears the cookie only on genuine expiry; on an unknown cookie the UI's restart (`POST /checkouts`) simply resumes whichever live checkout the cookie now points at. Pinned in `checkouts.test.ts` ("P1-3 …") and `verify.test.ts` (unslowed race). **UI lane: after a 401 `CHECKOUT_EXPIRED`, call `POST /checkouts` before assuming the session is gone — it may resume with `resumed:true`.**

### D-3 — New visitors may `wallet-retry` on their own checkout

Sprint 0001 refused `wallet-retry` on a new visitor's checkout (401 `NOT_VERIFIED`) because new visitors never verified. Under v2 every buyer proves the email by code, and the purchase binds the persisted member id to the checkout, so `requireVerified` now passes for a new visitor after purchase and the retry is allowed (unverified fresh cookie → 401; the buyer's own checkout → 200; re-verified fresh checkout → reaches the purchase; stranger → 404). This is what U17's "wallet-retry alert for a failed save" needs for first-time buyers.

### D-4 — Code replay after a 503 lookup failure answers 401 `CHALLENGE_MISSING`

A replay of the consumed code while the checkout is `verified` answers 401 `CHALLENGE_MISSING` ("This code is no longer valid. Request a new one."), the code the UI already handles for a consumed challenge; `{retryLookup:true}` is the only way forward (bounded to 3 attempts, then 409 `STATE_CONFLICT` "We could not look you up. Please start again.").

### D-5 — `MockWallet` now behaves like the service on `providedId`

Sprint 0001's mock silently returned the existing entry for a repeated `providedId`. universal-wallet's `validateId` refuses an already-used client id (`walletEntry.providedId.exists`, wallet-entry-core.md L199-L206), so the mock now answers 409 and the service layer reads back by id — the code path the live adapter will actually take. The Sprint 0001 `wallet.service.test.ts` expectation was updated accordingly.

## Phase B notes per commit

### `34b5493` — B1, B2, B4(a), P1-3, P1-4, P2 `retryAfterSeconds`

- **Address lock lives in `CheckoutStorePort`** (`addressState`, `recordWrongCode`, `clearWrongCodes`, `resetAddressLimits`) keyed by normalized email so it spans checkouts and clubs; `StoredChallenge.locked` is gone; `attemptsRemaining = 5 − wrongCodes(address)`; a correct code clears the count; the lock lifts only by time (15 min). Wrong-code window 15 min.
- **Send limiter key** `club:channel:address` → `channel:address` (spans clubs), window 15 → 60 min; identify per-IP window 15 → 60 min; the IP-limiter middleware takes the injected clock so tests can advance the hour.
- **Codes are random in every mode**; `STP_MOCK_OTP_CODE` pins them only when set. The local `.env` does not set it: once the dev BFF is restarted it issues random codes and the UI lane must read them from the B5 outbox route (see "Left for the orchestrator").
- **Verify concurrency**: challenge id and generation are re-checked inside the store mutation; the deterministic test slows `store.update`; the natural race accepts `CHALLENGE_MISSING` or `CHECKOUT_EXPIRED` for the loser (D-2).
- **`resetIdentity`** also clears `contact`, `emailVerifiedAt`, `lookupAttempts`; `DELETE /identity` and the `unresolved` outcome keep only `contactHint`.
- **Demo** reads codes from `MockOutbox.lastCodeFor`; Demo 0 asserts identical key sets for known/unknown, phone/disposable refusal, STALE_GENERATION and the P1-3 401. The `debug.code` echo was removed in the same commit, so `npm run demo:short-term-pass` never broke.

### `7ecdf58` — B3

- `ClubCatalogPort.getTerms`, `CatalogTerms`, `termsVersionOf` and `buildPrototypeTermsHtml` are gone; `consentSetFor(catalog, club, visitDate, now)` renders the set for the order's date.
- `StoredOrder.consents` replaces `terms`; `saveCard` defaults `false` (the A3 carry-over the previous executor deferred).
- `applyOrderUpdate` refuses the whole update on a waiver hash mismatch (409 `WAIVER_HASH`, refreshed set in `details.consent`); a template change clears the stored acceptance and refuses the old hash.
- `POST /consent-events` is allowed in any live state (documents are linked from the identify screen too), bounded at 50.
- `validatePurchase` messages: "Please confirm you're 18 or older" / "Please agree to the Liability Waiver" (409 `ORDER_NOT_READY`).

### `9ad75d8` — B4(b)

- Attestation check runs right after the order rules and **before** profile validation and payment-source resolution, so a stale revision never reaches authorization or even the saved-card token lookup.
- The snapshot is written at `VALIDATED` on `PurchaseRecord.consents` and `PurchaseResult.consent` is set in the same mutation; `memberId` is linked at `PERSON_PERSISTED`; FAILED purchases keep their snapshot (evidence of what was agreed); a replay returns before validation and writes nothing (pinned by comparing `updatedAt` and the snapshot).
- `ipHash` / `userAgentHash` are sha256 of `ctx.ip` and `User-Agent`; the raw values are never stored.
- `mobile` is parsed by `parseMobile` (ten digits or eleven with a leading 1; an email is refused); the prospect is created with `email = verified address`, `phone = mobile`.

### `531f4f4` — B5

- `captureMode` defaults `paypage` in every mode; `mock` only with hooks. Boot guard: production refuses `STP_TEST_HOOKS` (even `false` — the variable's presence is refused, R7), `STP_TEST_CLOCK` and `STP_CAPTURE_MODE=mock`; any mode refuses mock capture without hooks, hooks without `STP_TEST_HOOKS_KEY`, a non-ISO clock, a clock without hooks, an unknown capture mode.
- Testing routes are added to the same router only when `deps.testHooks` is true (router-stack test); each requires loopback (`127.0.0.1`, `::1`, `::ffff:127.0.0.1`) and a constant-time `X-STP-TEST-KEY` match; `app.proxy` is only true in production, so `X-Forwarded-For` cannot spoof loopback locally (the harness enables proxy trust in one test to prove the refusal).
- `GET /testing/state` adds `checkout.consentEvents` (count) and `entries[].source` on top of the contract shape; nothing else is added and no secret field is present (leak test).
- **Local `.env` edited (gitignored, not committed):** appended `STP_TEST_HOOKS=true` and `STP_TEST_HOOKS_KEY=<random hex>` because the existing `STP_CAPTURE_MODE=mock` would otherwise refuse to boot after this commit (plan Dependencies: "BFF `.env` gains `STP_TEST_HOOKS=true`, `STP_TEST_HOOKS_KEY=<random>`"). The running dev BFF was not restarted.

### `fc77007` — B6

- `walletProvidedId = crypto.randomUUID()` is allocated in `beginPurchase` (with the record, before any save) and reused by `retryWalletStep`; records without one (none exist in memory after a restart anyway) get a lazy UUID.
- Entry metadata is exactly `{oj_storedCardConsentVersion, oj_storedCardConsentAt, oj_purchaseId}` from the order's `consents.storedCard` and the purchase id; `ENTRY_METADATA_ALLOWLIST` in `wallet.ts`; the mock refuses any `dt_` entry key.
- Read-back on a failed create: `WalletPort.findEntryByProvidedId(owner, providedId)`; accepted only when `ownerIds` contains the owner and `pgToken` matches; otherwise the original write failure surfaces (`failed-retryable`). New mock fault `wallet-response-lost` stores the entry and drops the response.
- `PlatformWallet.createCreditCard` sends `providedId` + `metadata` (typed through `ICreateWalletCreditCard.metadata?: Record<string, unknown>` from `@abc/shared-types`); `findEntryByProvidedId` = `GET /wallet-entry/credit-card/{providedId}` under the owner tenancy, behind `STP_WALLET_READS`. `STP_WALLET_WRITES` stays false.

## Citations relied on (re-queried before B6 as instructed)

- `themes/identity-by-member-id.md` — owners keyed `(externalId, type, org_id)`, `MEMBER` externalId = Ignite member UUID; creating an owner requires no agreement number or RCM linkage; email is never identity. Applied: verify binds the member only after the code is consumed; `saveCardToWallet` resolves the owner by member UUID; `PersonSummary` carries no id or kind.
- `themes/agreement-number-and-prosp.md` hazards #1 (`PROSP` fails `validateAgreementNumber`), #4 (dedup key `DEDUPL_ACCOUNT_<agreementNumber>_<ordinal>`), #5 (sync excludes `PROSP`), #10 (`DeduplicationJobKeyByWalletEntryOwnerCalculator.calculate()` throws `deduplication-job.member` for a MEMBER owner without `dt_agreementNumber` — the reason `STP_WALLET_WRITES` stays false), #11 (membership-created hook re-migrates destructively). Applied: `OWNER_METADATA_FORBIDDEN` unchanged; no `dt_*` on entries at all; writes stay `NOT_ENABLED`.
- `repos/universal-wallet/walletentry/credit-card.md` — `POST /wallet-entry/credit-card` honours `providedId` via `walletEntryService.validateId` (controller L65-L86); `CreditCardRequestVO.providedId` L38; `GET /wallet-entry/credit-card/{id}` L93-L109 (the read-back path); `GET /wallet-entry/credit-card?q=` L119-L135.
- `repos/universal-wallet/walletentry/wallet-entry-core.md` L16 — `validateId(providedId)` rejects an already-used client-provided UUID (`walletEntry.providedId.exists`, `WalletEntryService` L199-L206); L71 — the controller assigns the validated `providedId` as the entity id. Applied: D-5 mock semantics; read-back by id.
- Token cache: `wallet-repos/universal-wallet/.../walletentry/creditcard/vo/CreditCardRequestVO.java:L38` `private UUID providedId;` and `.../walletentry/vo/WalletEntryBaseVO.java:L62` `protected Map<@NotNull String, String> metadata = new HashMap<>();` — a UUID id and a free string map (R11).

## Scope changes

None. `POST /testing/reset` was already in contract v2 §4 (the previous executor recorded its addition); it is implemented as specified. The Pyramid Index in `SPRINT-0002.md` was not edited.

## Housekeeping observed, not fixed (outside scope)

- husky 9 prints a deprecation warning on every commit (`.husky/pre-commit` and `.husky/post-commit` still source `husky.sh`); commits succeed. Removing the two lines is a one-line follow-up for whoever owns the hook files.
- Two pre-existing skipped tests elsewhere in the BFF suite (`2 skipped` at the Sprint 0001 baseline and unchanged).
