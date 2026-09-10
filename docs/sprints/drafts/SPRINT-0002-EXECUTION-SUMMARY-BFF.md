# Sprint 0002 — BFF lane execution summary

**Sprint:** Day Pass review changes (`docs/sprints/SPRINT-0002.md`). **Lane:** BFF — Phase B (B1–B6), Addendum P1-3 / P1-4, the 429 `retryAfterSeconds` P2 item, E4 for `repos/online-join-bff`.
**Executor:** Claude Fable 5.1, 2026-09-10, in parallel with the UI lane. Entered at BFF `289220e` on `prospect-wallet/sprint-0001`; left at `fc77007`. Not pushed; PR #96 not touched; dev servers untouched.
**Lane verdict:** **Phase B complete; P1-3 and P1-4 fixed; E4 (BFF) green; hosted capture unverified (B1).** No contract v2 deviation; four behavioural clarifications recorded in `SPRINT-0002-BLOCKERS-BFF.md` (D-1…D-5).

## 1. Tasks

Legend: ✅ done · ◐ done with a recorded limit · ⛔ blocked.

| Task | Status | Commit | Evidence (tests are in `src/routes/shortTermPass/__tests__` unless noted) |
|---|---|---|---|
| B1 OTP for every email; lookup after consumption; `retryLookup`; `resetIdentity`; `switch-channel`/`altContact`/`debug` removed | ✅ | `34b5493` | `identify.test.ts` (U3 known, U3 unknown identical key set, S4 no directory call before verify, S4 latency floor, U4 Change), `verify.test.ts` (U5 recognized, U6 newVisitor, U7 unresolved, U9 503 + retryLookup bounded to 3), `services/.../challenge.test.ts` |
| B2 §5A.1 limits: hourly windows, 15-minute address lock, disposable check, timing floor, concurrency | ✅ | `34b5493` | `identify.test.ts` (U8 21st identify/IP/hour incl. other club + fresh cookie, U8 6th send/address/hour across identify + resend + clubs + cookies, disposable 400), `verify.test.ts` (U8 lock on 5th wrong code refuses verify **and** resend with one message, lock spans checkouts and clubs, atomic double wrong-code count, one-of-two concurrent verifies consumes) |
| B3 consent set on every response, `order.consents`, waiver hash, consent-events, save default off, per-club override | ✅ | `7ecdf58` | `order.test.ts` (U10 date re-renders Pass Terms hash, U11/U13 adult + waiver with version/hash/method/time, U13 WAIVER_HASH 409 + template change, U13/U14 save default off + storedCard version, U6/U13 marketing opt-in + SMS notice once, S3 club 90032 overrides served/accepted/recorded, U12 consent-events bounded at 50), `checkouts.test.ts` (consent on POST /checkouts, Northside override), `services/.../order.service.test.ts`, `catalog.test.ts`, `platformCatalog.test.ts` |
| B4(a) demo reads codes from the outbox before the `debug` echo is removed | ✅ | `34b5493` (same commit; the demo never broke between commits) | `npm run demo:short-term-pass` 57/57 at `34b5493` → 66/66 at `fc77007` |
| B4(b) attestation before authorization; one consent snapshot; `PurchaseResult.consent`; `mobile` required | ✅ | `9ad75d8` | `purchase.test.ts` "consent attestation and the purchase snapshot": stale revision / wrong button text / date moved → 409 CONSENT_REVISION with refreshed set and zero authorizations; one snapshot at VALIDATED with memberId linked, none on replay; summary shape; FAILED keeps snapshot; profile table (blank mobile, garbage, email-as-mobile, too long) |
| B5 capture defaults `paypage`; hooks; boot guard; `testHooks`; mock capture 404 without hooks; testing routes; test clock | ✅ | `531f4f4` | `testingRoutes.test.ts` (U16 testHooks + mock capture, U20 outbox per checkout, U22 sanitized state with leak scan, 403 without key / wrong key / non-loopback, reset, router-stack 404 with hooks off, mount-on-env, STP_TEST_CLOCK), `services/.../config.test.ts` (production refusals R7, mock-without-hooks, hooks-without-key, bad clock, unknown capture mode), `adapters.test.ts`, `checkouts.test.ts` |
| B6 UUID `walletProvidedId`; `oj_*` metadata allowlist; mock + platform adapters; read-back; retry reuses id | ✅ | `fc77007` | `services/.../walletWrites.test.ts` (allowlist, UUID id, duplicate → read-back, non-UUID/dt_ refused, response lost → read-back accepts only own owner + token), `platformWallet.test.ts` (create body carries UUID `providedId` + exactly the three `oj_` keys, `findEntryByProvidedId` GET by id), `purchase.test.ts` (U13 entry id = record UUID + metadata + upstream payload scan, U18 wallet-retry reuses id and metadata, U18 lost response saved via read-back), `idempotency.test.ts` |
| P1-3 missing/unknown cookie → 401 `CHECKOUT_EXPIRED` | ✅ | `34b5493` | `checkouts.test.ts` "P1-3 …" (no cookie, unknown cookie not cleared, forged id under a live cookie still 404), `session.test.ts` (pass-session route), `verify.test.ts` (stale cookie after rotation) |
| P1-4 `generation` on identify/verify/order/purchase; stale → 409 `STATE_CONFLICT` `STALE_GENERATION` | ✅ | `34b5493` | `identify.test.ts`, `verify.test.ts` "P1-4 …", `order.test.ts` "P1-4 …" (order edits do not bump), `purchase.test.ts` "P1-4 …" (refused before validation and authorization) |
| P2 429 `retryAfterSeconds` on every throttle response (+ `Retry-After` header) | ✅ | `34b5493` | identify per-IP, per-address send cap, resend cooldown, address lock — all asserted |
| E4 (BFF) lint / build / coverage | ✅ | — (working tree at `fc77007`) | §3 below |

## 2. Commits (BFF, `prospect-wallet/sprint-0001`, on top of Phase A `289220e`)

| Hash | Message (first line) |
|---|---|
| `34b5493` | Sprint 0002 Phase B (BFF lane): B1+B2 email OTP for every address, lookup after consumption, §5A.1 limits and address lock; P1-3 401 on missing cookie; P1-4 checkout generation; demo reads codes from the outbox (B4a) |
| `7ecdf58` | Sprint 0002 Phase B (BFF lane): B3 §4.5 consent set on every response, order consents, waiver hash check, consent-events route, save-card default off |
| `9ad75d8` | Sprint 0002 Phase B (BFF lane): B4(b) Pay-tap attestation checked before authorization, one consent snapshot per purchase, mobile required for new visitors |
| `531f4f4` | Sprint 0002 Phase B (BFF lane): B5 capture defaults to paypage, mock capture and testing routes only behind STP_TEST_HOOKS, boot guard, test clock |
| `fc77007` | Sprint 0002 Phase B (BFF lane): B6 prospect-wallet save with a UUID providedId, oj_ consent metadata and read-back on response loss |

62 files changed, +4134 / −1024 across the five commits. Every commit built, passed lint-staged (prettier + eslint) and its full jest suite; `dist/`, coverage output and `.env` were never staged (`.gitignore` covers them; verified with `git diff --name-only`).

## 3. E4 — lint / build / coverage (working tree = `fc77007`)

| Check | Result |
|---|---|
| `npm run lint` (`eslint src/ --quiet`) | clean, exit 0 |
| `npm run build` (`tsc --project tsconfig.json`) | clean, exit 0 |
| `npx jest --coverage` | 60 suites passed; 549 tests passed, 2 skipped (both pre-existing at the Sprint 0001 baseline), 0 failed; 2 snapshots passed |
| Coverage (all files) — statements / branches / functions / lines | **97.39 / 85.11 / 95.74 / 98.08** |
| Floors (`jest.config.js`, unchanged) | 84 / 67 / 67 / 84 — no threshold lowered, no exclusion added |
| Baseline at `289220e` | 59 suites, 488 tests |

## 4. Demo

`npm run demo:short-term-pass` (mock adapters; sets `STP_TEST_HOOKS=true`, `STP_TEST_HOOKS_KEY`, `STP_CAPTURE_MODE=mock` for itself when unset):

| Commit | Checks |
|---|---|
| `34b5493` | 57/57 |
| `7ecdf58` | 62/62 |
| `9ad75d8` | 65/65 |
| `531f4f4` | 65/65 |
| `fc77007` | 66/66 |

Runs: Demo 0 (CR-05 indistinguishability, phone/disposable refusal, STALE_GENERATION, P1-3), Demo 1 (new visitor save ON with consent block, snapshot and UUID entry; new visitor save OFF with marketing opt-in + SMS notice; Start again then return by email with the saved card), Demo 2 (Jordan saved card + stale-attestation refusal + idempotent replay; new card save ON to the existing owner; new card save OFF; decline then recovery; wallet-failure then wallet-retry with the same providedId). Hosted run: `--hosted` → BLOCKED (B1), "mock demo complete; hosted capture unverified".

## 5. Gates this lane contributes evidence to

| Gate | BFF-lane evidence | Verdict from this lane |
|---|---|---|
| S3 — Consent recorded | Purchase record shows adult, waiver (version, hash, method), stored-card version when saved, pass terms + privacy with the exact button text, marketing opt-in default false, notices with versions; one snapshot per purchase, none on replay; stale revision refused before authorization; PROPOSED only in fixture/config/capability report (never in a customer-visible field — `approval` is on the set the UI receives but the UI lane renders no marker); club 90032 override tested end to end | **BFF side met** (`purchase.test.ts`, `order.test.ts`, `consentTemplates.test.ts`) |
| S4 — OTP for everyone | Identical key set, status and floor for known/unknown; no directory call before verify (spy); §5A.1 limits and 15-minute lock pinned incl. cross-checkout, cross-club and fresh-cookie cases; phones never identity; no code in any response, snapshot or log (redacted logger; leak assertions) | **BFF side met** (`identify.test.ts`, `verify.test.ts`, `challenge.test.ts`, `log.test.ts`) |
| S5 — Pay Page only | `captureMode` defaults `paypage`; mock capture unreachable without hooks (404) and refused by the boot guard in production; testing routes absent from the router stack without hooks | **BFF side met; hosted run pending (B1)** |
| S6 — Prospect-wallet save | Mock-proven owner `(memberId, MEMBER, org)` + entry with UUID `providedId` and exactly the `oj_*` metadata; read-back on response loss; retry reuses id and metadata; platform adapter typed and `NOT_ENABLED` (writes) with the body shape unit-tested; enablement checklist below | **BFF side met; L3 unchanged** |
| S8 — Quality (BFF half) | lint clean, build clean, coverage above floors, thresholds untouched, demo green | **met for the BFF** |
| S1 — Traceability inputs | Task → commit → test table above (CR-02, 03, 04, 05, 06, 09, PR-03 on the BFF side) | inputs ready for the orchestrator's E5 table |
| S0, S2, S7, S9 | not this lane (S2/S7 deferred by the user; S9 is E5) | — |

## 6. Response shapes the UI lane must consume (as built; matches contract v2 §4)

- `POST /checkouts` → `{checkoutId, csrfToken, generation, captureMode:'paypage'|'mock', adapterMode, testHooks, resumed, club, offer, consent: ConsentDocumentSet, snapshot}`. `snapshot` = `{step, generation, emailVerified, contactHint?, contact?, challenge?:{expiresAt, resendAfter, attemptsRemaining, locked}, person?, order?, purchaseId?}`; `step` may now be `'verified'` (lookup failed after the code was consumed → show Retry, send `{retryLookup:true}`). `terms` is gone.
- `POST /checkouts/:id/identify {email, generation?}` → 200 `{outcome:'challenge', generation, contact:{channel:'email', masked}, challenge}` for every valid, non-disposable address. 400 `VALIDATION_FAILED` `details.field:'email'` with message `Enter a valid email address.` or `Use a permanent email address.`; 429 `THROTTLED` (`retryAfterSeconds`, `Retry-After`) or 429 `CHALLENGE_LOCKED` (`Too many incorrect codes. Try again in 15 minutes.`); 409 `STATE_CONFLICT` `details.reason:'STALE_GENERATION'` (`details.generation` = current).
- `POST /checkouts/:id/challenge {action:'resend'}` → `{generation, contact, challenge}`; same 429s. `switch-channel` → 400.
- `POST /checkouts/:id/verify {code, generation?}` → `{outcome:'recognized', generation, person, contact, order, consent}` | `{outcome:'newVisitor', generation, contact:{channel, display, masked}, order, consent}` | `{outcome:'unresolved', generation, contact}`; 401 `CODE_INVALID` `details.attemptsRemaining`; 401 `CODE_EXPIRED` `That code expired. Request a new one.`; 401 `CHALLENGE_MISSING` (no challenge / consumed / superseded); 429 `CHALLENGE_LOCKED`; 503 `UPSTREAM_UNAVAILABLE` `retryable:true` → `{retryLookup:true}` (≤3, then 409). The verify response **rotates the cookie**.
- `DELETE /checkouts/:id/identity` → `{ok:true, generation, contactHint?}`; `DELETE /checkouts/:id` → `{ok:true, generation, contactHint?}`.
- `PUT /checkouts/:id/order {visitDate?, adult?, waiver?:{accepted, method?, renderedHash?}, saveCard?, marketingOptIn?, smsNoticeShown?, generation?}` → `{order, consent, generation}`; `order.consents` per contract §6; `order.saveCard` defaults **false**; waiver acceptance needs `method` and the `renderedHash` displayed (400 `waiver.method` / `waiver.renderedHash` when missing; 409 `STATE_CONFLICT` `details.reason:'WAIVER_HASH'` + `details.consent` when stale). Order edits do **not** bump `generation`.
- `POST /checkouts/:id/consent-events {type:'document-opened'|'document-closed', documentId, renderedHash}` → `{ok:true, count}`; allowed in any live state.
- `POST /checkouts/:id/capture/mock {card}` → 201 only when `testHooks && captureMode==='mock'`, else 404.
- `POST /checkouts/:id/purchases` (header `Idempotency-Key`) `{payment, attestation:{consentRevision, payButtonText}, profile?:{firstName, lastName, mobile}, generation?}` → 201/200 `PurchaseResult` with `consent:{passTermsVersion, waiverVersion?, storedCardVersion?, marketingOptIn}`; 409 `ORDER_NOT_READY` messages `Please confirm you're 18 or older` / `Please agree to the Liability Waiver`; 409 `STATE_CONFLICT` `details.reason:'CONSENT_REVISION'` + `details.consent` (re-render and re-attest); 400 `profile.mobile` `Please add your mobile number.` / `That mobile number doesn't look right.`; 409 `STALE_GENERATION`.
- Any checkout route without a cookie or with an unknown cookie → 401 `CHECKOUT_EXPIRED` (`Your checkout session has expired. Please start again.`); the cookie is **not** cleared for an unknown value (D-2) — restart with `POST /checkouts`, which may resume.
- Hooks-only (loopback + `X-STP-TEST-KEY`): `GET /api/short-term-pass/testing/outbox?checkoutId=`, `GET …/testing/state?checkoutId=`, `POST …/testing/reset`.

## 7. Left for the orchestrator or the UI lane

1. **Restart the dev BFF on :3000 to pick up v2** (not done by this lane per the brief). The local `.env` now has `STP_TEST_HOOKS=true` and `STP_TEST_HOOKS_KEY=<random>` (appended, gitignored) so it will boot with its existing `STP_CAPTURE_MODE=mock`; without those two keys the B5 boot guard refuses mock capture. The key's value is in `.env` only.
2. **Codes are random in dev now.** The UI lane / browser QA must read them from `GET /api/short-term-pass/testing/outbox?checkoutId=<id>` with header `X-STP-TEST-KEY: <value from .env>` from localhost (this is what `tools/otp-sink` will wrap), or pin `STP_MOCK_OTP_CODE=123456` in `.env` for a manual session.
3. **E5 contract §10 register rows (text ready):** wallet-write enablement checklist = `STP_WALLET_WRITES=true`, `UNIVERSAL_WALLET_API_URL`, OAuth authorities, deployed dedup fix (hazard #10), owner-scoped rsql path verified, `pgToken` mapping, acceptance of `oj_*` entry metadata and of a UUID `providedId` on `POST /wallet-entry/credit-card` for a MEMBER owner without agreement metadata (R11 / OQ-3), read-back `GET /wallet-entry/credit-card/{providedId}` under the owner tenancy, smoke against dev with fixture Jordan under `STP_ADAPTER_MODE=platform` + mock payment/sale. Consent ledger platform adapter row (PRODUCT+LEGAL+PLATFORM): the purchase-record snapshot (`PurchaseRecord.consents`) is in-memory by declaration. CF-02: the refund sentence delta and `approval:'PROPOSED'` unchanged.
4. **Contract v2 doc:** no deviation to record; §4a could gain one sentence for D-2 (unknown cookie not cleared) and D-3 (new-visitor wallet-retry allowed) if the orchestrator wants them in the contract rather than only in the blockers file. `GET /testing/state` additionally returns `checkout.consentEvents` (count) and `entries[].source`.
5. **UI lane cross-checks:** `order.saveCard` default false; `consent` present on `POST /checkouts`, `PUT /order` and both order-creating verify outcomes; `snapshot.step === 'verified'` needs a Retry affordance; `testHooks` gates `TestCardPanel`; `generation` should be sent on identify/verify/order/purchase and stored from every response that carries it.
6. **Husky deprecation** (pre-existing): `.husky/pre-commit` / `.husky/post-commit` still source `husky.sh`; harmless today, fails on husky 10.
7. **Not done by design (out of scope):** Phase D, E1, E2, E3 (B1), E5, pushes, PR #96 description, `docs/contracts` edits, `SPRINT-0002.md` edits (Pyramid Index still truthful — no scope change), anything under `repos/online-join-ui`, `tools/`, `docs/validation/**`.
