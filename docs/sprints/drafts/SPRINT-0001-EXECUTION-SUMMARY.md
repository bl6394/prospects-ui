# Sprint 0001 — execution summary

**Sprint:** Day Pass single-flow checkout in Online Join (UI + BFF), `docs/sprints/SPRINT-0001.md` (revised 2026-09-09 with the Riverside addendum).
**Executor:** Claude Fable 5.1 — session 1 (2026-09-09: phases A and B) and session 2 (2026-09-09/10: phases C, D, E, resumed after the requirements addendum).
**Branches:** `prospect-wallet/sprint-0001` in `repos/online-join-ui` and `repos/online-join-bff`. Not pushed; no PRs opened. Planning-repo deliverables are left uncommitted at the repo root for the orchestrator.
**Completion vocabulary:** *sprint implementation complete; local checkout complete; live integration blocked.* G4: *mock demo complete; hosted capture unverified.*

## 1. Tasks completed per phase

Legend: ✅ done · ◐ done with a recorded limit · ⛔ blocked. "(s1)" = previous executor session; "(s2)" = this session.

### A — Foundations (s1) ✅
A1 contract freeze (`docs/contracts/short-term-pass-bff.md`, BFF `schemas.ts`, UI `interfaces/api/shortTermPass.ts`) · A2 flag + club gating with explicit club context at HTML render and `requireShortTermPass` · A3 env, `.env.example`, boot guard · A4 housekeeping (dangling `jose` jest mapping removed, `webpack.dev.config.js` proxies for `/api/short-term-pass` and `/api/pay-page`) · A5 UI route shell, `SignupShell` extraction, iframe/unavailable states · A6 spikes recorded in the contract doc (A6(a) Pay Page blocked → B1; A6(b) owner-scoped wallet query decision; A6(c) LD flag missing → B2) · A7 scoped SCSS + five `Dt*` primitives with isolation test.
**Addendum impact absorbed in phase C:** catalog fixture became Riverside (see C1).

### B — BFF trust boundary (s1) ✅
B1–B7 all present in commit `b76de82` (found committed at the start of s2; nothing uncommitted): router mounted before the MICO proxy; opaque `OJ-PASS-SESSION` cookie + in-memory `CheckoutStore`; contact normalization/masking; identify / challenge (resend, switch) / verify with hashed codes, expiry, attempt cap, cooldown, per-contact and per-IP limits, 300 ms floor; member-UUID binding; `GET /wallet` with opaque selection refs and `ok`/`unavailable`; pass-scoped Pay Page session route with purpose tagging and generic poll/close refusal; platform adapters for catalog, wallet reads (dark) and the Pay Page session reader; redacted logging; HTTP harness and suites.

### C — BFF purchase orchestration (s2) ✅ — commit `4e5e5b2`
C1 Riverside fixture (90030, $18.00 "1-day pass", Jordan `jordan.reyes@email.com`; Core South kept at 90033, $25.00), per-club offers, order shell with `visitDate` defaulting to club-local today, `PUT /order` (date, terms as an affirmative act with method/version/server time, save consent, terms-version change handling) · C2 `PurchaseStorePort` + in-memory adapter, `Idempotency-Key` + fingerprint, replay / conflict / in-progress, atomic single active attempt · C3 orchestrator authorize → persist prospect → consented wallet write → sale + capture → issue (bounded retry, refund) → deliver with the full failure table (void, `RECONCILING` on unknown outcomes, contact race back to identify) · C4 wallet writes (existing-owner reuse, allowlisted metadata, `providedId`), `wallet-retry` route with ownership rules · C5 `MockPaymentGateway`, `MockPassSale` (receipt, pass, demo QR), delivery via the outbox · C6 tests: order + purchase route suites (Demo 1 / Demo 2 paths, member match, hostile bodies, ownership, idempotency, concurrency, every failure boundary, wallet-retry, recursive upstream payload scan) and unit suites for order rules, idempotency, wallet writes, mocks · C7 adapter register (contract §8) and adapter index with capability report. Phase B tests updated for the new fixture.

### D — UI flow (s2) ✅ — commit `9753a70`
D1 service module (credentials, CSRF interceptor, `StpClientError`, idempotency keys), slice with generation-guarded thunks, selectors (`paymentReady`, `canPay`), store registration · D2 bootstrap + `CheckoutShell` (club logo + name, "Classes · Memberships · Day pass · Visit", "🔒 Secure checkout") · D3 `IdentifyStep` · D4 `VerifyStep` (own screen, six inputs, resend cooldown, switch only when on file, Start over) · D5 `RecognizedStep` + `SavedCardChip` + `PayBar` · D6 `NewVisitorStep` + `SaveCardToggle` (switch) · D7 `CardCaptureSlot` (`PayPageEmbed` / `MockCardCapture`) + `useShortTermPassCapture` (submit → bounded poll) · D8 `OrderSummary` (no skeleton, no buttons, "Pick a day" defaulting to today with toast, Paying with / Paid with, three fine-print variants, Receipt) · D9 `TermsDialog` on MUI `Dialog` (opening is not acceptance; checkbox and "Agree and close" each recorded) · D10 pay action with idempotency key, `DoneStep` + `PassBlock` (QR via `qrcode.react`), URL `/signup/pass` on completion · D11 rehydration from the snapshot, purchase reload, Start again, `Toast`, session-expired restart · D12 tests for every step, component, slice, selectors, service, format, page and a static PCI scan; App test covers `/pass`. Also: `dist/.tsbuildinfo` untracked and `/dist` ignored (it had been committed in phase A).

### E — Proof (s2) ◐ — commit `690dd3e` (BFF) + planning docs
E1 ✅ `npm run demo:short-term-pass` (eight mock runs + reload checks, 47/47 checks) · E1 hosted ⛔ `--hosted` reports BLOCKED (B1) · E2 ✅ security/fault matrix executed by the B7/C6 suites, indexed in `docs/validation/short-term-pass-bff.md` · E3 ◐ existing UI suites green, HTTP smoke through the restarted dev BFF and dev-server proxy recorded; **manual browser check at 1440/375 px not performed** (no browser tooling) · E4 ✅ lint/build/coverage recorded below and in the validation docs; ledger updated · E5 ✅ readiness register (contract §10), `docs/SEMANTIC-INDEX.md` note.

## 2. Commits

| Repo | Hash | Message |
|---|---|---|
| online-join-bff | `e98d5c9` | Sprint 0001 Phase A: short-term pass foundations (contract, gating, env, housekeeping) (s1) |
| online-join-bff | `b76de82` | Sprint 0001 Phase B: short-term pass trust boundary (router, session, OTP, wallet reads, Pay Page scoping) (s1) |
| online-join-bff | `4e5e5b2` | Sprint 0001 Phase C: short-term pass purchase orchestration (order, idempotency, payment, wallet writes, sale, issuance, delivery) (s2) |
| online-join-bff | `690dd3e` | Sprint 0001 Phase E: scripted local demo of the Day Pass checkout (s2) |
| online-join-ui | `fcf9b9d` | Sprint 0001 Phase A: short-term pass route shell, scoped design tokens, dt primitives (s1) |
| online-join-ui | `9753a70` | Sprint 0001 Phase D: Day Pass UI flow per the Riverside demos (identify, verify, recognized, new visitor, done) (s2) |

Base SHAs: BFF `bc8a4bd`, UI `f3242b1`. Both working trees are clean after the commits. `repos/mico` untouched; `wallet-repos` untouched.

## 3. Final lint / build / coverage

| Repo | Lint | Build | Tests | Coverage (stmts / branches / funcs / lines) | Floors |
|---|---|---|---|---|---|
| online-join-bff | `npm run lint` → 0 errors | `npm run build` → ok | 58 suites, 481 passed, 2 pre-existing skipped | **97.52 / 85.81 / 95.13 / 98.04** | 84 / 67 / 67 / 84 |
| online-join-ui | `npm run lint` → 0 errors (warnings only) | `npm run build` → compiled, 3 pre-existing bundle-size warnings | 100 suites: 99 passed, 1 failed (pre-existing timezone-dependent `transformers.test.ts`, unrelated); 578 tests: 577 passed | **92.97 / 82.18 / 87.55 / 92.97** | 80 / 80 (lines / statements) |

No threshold was lowered and no exclusion added. `tsc --noEmit` in the UI still reports only the 25 pre-existing errors in PaymentPage/PayPageEmbed tests; none in new code.

## 4. Demo runs

**Demo 1 · First visit** (mock adapters, through the real router): Run 1 new visitor save on — COMPLETE, prospect persisted with both contacts, owner keyed by the new member UUID with metadata exactly `{dt_clubNumber, dt_memberId, dt_memberType:'PROSPECT'}`, one entry, sale R-000001, pass issued, emailed; reload resumes the completed checkout and `GET /purchases/:pid` recovers it. Run 2 new visitor save off — COMPLETE, prospect + second contact persisted, no wallet call, texted. Run 3 Start again then return by the secondary contact (mobile) — recognized as the same person, wallet lists the run-1 card, saved-card purchase COMPLETE.
**Demo 2 · Returning visit:** Run 4 Jordan saved Visa 4242 — COMPLETE with no wallet write; reload rehydrates `recognized`; replay with the same key returns the same purchase with one authorization. Run 5 new Mastercard save on — entry added to the existing owner, `createOwner` never called. Run 6 new card save off — no wallet write. Run 7 Morgan's Visa 0002 — FAILED `PAYMENT_DECLINED`, nothing sold or issued; retry with a new card completes. Run 8 `wallet-failure` fault — COMPLETE with `wallet.failed-retryable`, pass issued; `wallet-retry` saves the card with no payment call.
**Outcome:** 47/47 checks, exit 0. Transcript in `docs/demos/short-term-pass-local-demo.md`.
**Hosted run (`--hosted`):** BLOCKED — the six `PAY_PAGE_*`/`ABC_CORE_API_URL` variables are absent locally (B1).
**Browser smoke (curl against the restarted dev servers):** HTML entry 200 with the flag serialized (`Accept: text/html` required by the history fallback), `POST /checkouts` 201 with cookie and `no-store`, closed club 404, `:3001` proxy 201, existing signup entry 200.

## 5. Gates

| Gate | Verdict | Evidence |
|---|---|---|
| G0 Ready | **met** (owners still to be named) | contract frozen with SHAs and the server patch; A6 spikes recorded; LD flag requested (B2); env in `.env.example` |
| G1 Product flow | **met locally** | demo runs 1–8 + purchase/identify/verify suites cover U2–U18 through the BFF with state inspection; both save variants; next visit by secondary contact |
| G2 Prototype parity | **pending design sign-off** | every copy string, masking and disabled state is test-pinned (`docs/validation/short-term-pass-ui.md`); deviations listed there; the 1440/375 px visual pass was not performed |
| G3 Identity boundary | **met** | C6 + B7 suites: payload scan, owner by bound member UUID / MEMBER / org, existing-owner reuse, call order, hostile bodies, entry ownership, cross-checkout/club refusal, no pre-verify disclosure, limits, redaction |
| G4 PCI boundary | **pending: mock demo complete; hosted capture unverified** | static PCI scan and `/purchases` schema rejections pass; `PlatformPayPageSessionReader` unit-tested; no real Pay Page dev run (B1) |
| G5 Transaction integrity | **met** | ordered orchestration, no-save persistence, every failure boundary, idempotent replay, 409 on payload change, concurrent attempt refused, wallet-retry never re-authorizes, truthful statuses (`purchase.test.ts`, `idempotency.test.ts`) |
| G6 Dark and isolated | **met** | 404 on every pass route when the gate fails; production refuses mock/override/faults; existing signup, guest and Pay Page suites green; generic Pay Page routes refuse pass sessions; SCSS isolation test |
| G7 Quality | **met (numbers above), minus the manual browser check** | lint/build clean in both repos; coverage above floors; nothing lowered |
| G8 Operable local delivery | **met** | deterministic demo with capability report; faults reproducible via the switch; redacted correlation logs; readiness register with owner slots |

Live gates L1–L5 remain open by design (contract §10).

## 6. Left for the orchestrator or the user

1. **B1 — Pay Page dev credentials.** Add `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN`, `ABC_CORE_API_URL` to `repos/online-join-bff/.env`, run `npm run demo:short-term-pass -- --hosted`, complete the hosted form in a browser, and record the run to close G4.
2. **B2 — LaunchDarkly flag** `oj-short-term-pass-checkout` (club kind, default off) must be created by someone with write access; local runs use `STP_LOCAL_FLAG_OVERRIDE=true`.
3. **Manual browser check** of `http://localhost:3000/signup/day-pass?club=90030` and the existing signup route at 1440 and 375 px (design gate G2 / quality gate G7); both dev servers are running with the sprint code.
4. **Planning-repo commit.** Uncommitted deliverables: `docs/contracts/short-term-pass-bff.md`, `docs/demos/short-term-pass-local-demo.md`, `docs/validation/short-term-pass-{bff,ui}.md`, `docs/sprints/drafts/SPRINT-0001-BLOCKERS.md`, this summary, `docs/SEMANTIC-INDEX.md`, `docs/sprints/ledger.yaml`, the L1 touch-up in `docs/sprints/SPRINT-0001.md`, plus the addendum and demo HTML files that were already untracked.
5. **Push / PRs** for `prospect-wallet/sprint-0001` in both repos (not done by instruction).
6. **Owners** for gates and OQ-1…OQ-9 at kickoff; the readiness register (contract §10) lists the slot per capability.
7. **Pre-existing defects observed, not fixed:** `rawBodyCapture` breaks JSON bodies for `/api/*` routes other than `/api/pay-page/` and `/api/short-term-pass/`; the UI `transformers.test.ts` month-label test is timezone-dependent; UI `tsc --noEmit` has 25 pre-existing errors in PaymentPage tests.
8. **Scope changes to acknowledge** (blockers file "Scope changes"): two extra BFF routes (`GET /checkouts/:id/capture`, mock-only `POST /checkouts/:id/capture/mock`); `PAYMENT_DECLINED` reported inside the 2xx `PurchaseResult` instead of a 402 envelope; fixture club `90033`; completion URL `/signup/pass`; eight demo runs instead of six.
