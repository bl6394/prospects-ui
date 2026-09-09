# Sprint 0001 Critique: CODEX draft vs GEMINI draft

**Status:** critique (Claude), 2026-09-09. Read-only review; no repo files other than this one were changed.
**Inputs:** `SPRINT-0001-INTENT.md`, `SPRINT-0001-CODEX-DRAFT.md` (366 lines), `SPRINT-0001-GEMINI-DRAFT.md` (104 lines).
**Verification scope:** claims about code were checked against `repos/online-join-ui` @ `f3242b1`, `repos/online-join-bff` @ `bc8a4bd` (with the uncommitted `src/server.ts` patch), and `repos/mico` @ `5dad4d66` (read-only). Claims about `wallet-repos/` or the sibling `prospects1` repo were **not** verified here and are marked as such.

## Verdict in one paragraph

The Codex draft is the stronger plan by a wide margin and should be the merge base. It reads the code correctly, corrects two errors in the intent, proposes a complete browser-facing contract and adapter model, and separates "local checkout complete" from "live service enabled" in a way that will keep the sprint honest. Its weaknesses are size and density: roughly 20–27 engineering days, twelve endpoints, seven adapters, a retrofit of existing Pay Page session handling, and a purchase state machine designed ahead of the contract decisions it depends on. The Gemini draft has the right skeleton (route under `/signup`, payPage-template router, adapter toggle, scoped tokens, RTK slice) and is easy to read, but it is too thin to execute: no exit criteria, no contract, no failure handling beyond one sentence, a single `checkout` endpoint that collapses quote, terms, and purchase, and an ordering in Phase 4 that omits authorization and owner creation. The merged plan should keep Codex's architecture, contracts, identity rules, failure table, and DoD gates, trim Codex's scope in the places named below, and borrow Gemini's readable use-case table and phase summary as the top layer.

## Claim verification

| Claim | Draft | Result |
|---|---|---|
| `/signup` basename lives in `src/index.tsx`, routes in `App.tsx` | Codex | **Confirmed.** `index.tsx:18` sets `basename="/signup"`; `App.tsx` owns routes, header/footer, club fetches, trackers, and the `SessionProvider`. |
| Runtime config is injected as `window.process.env`, not `window.env` | Codex | **Confirmed.** `routes/static/index.html.ts:83-89` defines `window.process.env`; flags are under `window.featureFlags`. The intent's `window.env` wording is wrong; Codex's correction stands. |
| Due-today Pay Page session is add-token with `deferAuthorizationToPayment: true`; UI reads `result.NEW_PAYMENT_METHOD.TOKEN` | Codex | **Confirmed.** `payPage/index.ts:368-369`; `usePayPageSession.ts:119`. Token collection is not authorization. This is the single most important correction to the intent. |
| Pay Page poll/close validate only session UUID format and club, no browser ownership | Codex | **Confirmed.** `validateAndResolveOrg` (`payPage/index.ts:373+`) checks UUID shape and `clubNumber` query, then calls upstream with the tenant header. No cookie or ownership check. |
| Pay Page location lookup pads club to 6 digits; LD context pads to 5 | Codex | **Confirmed.** `padClubNumber` uses `padStart(6,'0')`; `getFeatureFlagContext.ts` uses `padStart(5,'0')`. |
| React `SessionContext` is a network-block UI, not an auth session | Codex | **Confirmed.** `contexts/SessionContext.tsx` renders `SecurityBlockedModal`. |
| `historyFallback` rewrites `text/html` requests to index | Codex | **Confirmed.** `utils/middlewares/historyFallback.ts` with `htmlAcceptHeaders: ['text/html']` and a whitelist. Low risk for axios calls but worth one regression test. |
| `healthCheck.ts`, `prom-client`, AJV exist in BFF | Codex | **Confirmed.** `services/healthCheck.ts`, `utils/prometheusMetrics.ts`, `ajv` 8.x, `prom-client` 15.x. |
| BFF thresholds 84 lines/statements, 67 branches/functions; UI 80 lines/statements | Codex | **Confirmed.** `jest.config.js` in both repos. UI `npm test` already runs `jest --coverage`. |
| `npm run test:cov`, `lint`, `build` exist in both repos | Codex | **Confirmed.** |
| Snapshot SHAs and uncommitted `server.ts` patch | Codex | **Confirmed.** |
| MICO `addProspect` returns `memberId`; no phone/email lookup or OTP in MICO | Both | **Confirmed.** `ProspectController.java:219-246`; `OrasvcClient.java:139`. No matches for lookup-by-contact or verification code anywhere in `mico/src/main/java`. |
| `/api/online-join` wildcard proxy; new prefix must avoid it | Codex | **Confirmed.** `routes/proxy/index.ts:15`. Both drafts' prefixes (`/api/short-term-pass`, `/api/day-pass`) avoid it. |
| Wallet dedup calculator "already changed" at UW `b380cd0` (index drift) | Codex | **Not verified here.** Lives in `wallet-repos/`, outside this review's scope. Codex correctly refuses to draw a rollout conclusion from it, but the merged plan should phrase it as "to confirm with wallet owners", not as fact. |
| `@abc/bff-toolkit/universalWallet` exists and can be used | Gemini | **Confirmed with a caveat.** The installed toolkit exports `universalWallet` with `getWalletEntries(externalId)`, `createWalletOwner`, `createWalletUser`, `createCreditCard`, and assignment methods. The toolkit uses `got`, not axios, so "mocked Axios responses" is wrong for the BFF side. Codex's caution that the Jest mock is not a verified production contract is the right posture. |
| `src/assets/styles/day-pass-tokens.scss` | Gemini | **Path does not exist.** UI has `src/index.scss`, `src/App.scss`, and per-component scss; there is no `src/assets/styles/` or `src/styles/`. Either draft's new stylesheet location is a new convention; Codex's `src/styles/short-term-pass.scss` is also new. Minor. |
| Bound identity can live in the existing `SESSION-ID` cookie | Gemini | **Weak.** `cookies.ts` writes `SESSION-ID` from `ctx.state.session`, and nothing in this BFF's `src/` assigns `ctx.state.session`. The cookie is `sameSite: none, partitioned` for iframe embedding. Overloading it for OTP-bound identity conflates two lifecycles. Codex's separate opaque cookie is the sounder choice. |

One finding neither draft states plainly: `getFeatureFlagContext` returns `{kind:'user', key:'ANONYMOUS'}` when `ctx.state.session` is absent, and no code in the BFF populates that state. Club-scoped LD evaluation at HTML render time therefore needs an explicit club context derived from the query string, which Codex's B2 ("correct trusted LD context and HTML serialization") gestures at without spelling out. The merged plan should make this a named task.

## Codex draft

### Architectural soundness — strong

- Trust boundary is right: the browser never sends `memberId`, owner IDs, org/location, price, terminal, or PG token; the server resolves and binds club/org/location at checkout creation and refuses to let later requests replace them.
- Correctly separates five identifiers that the intent and prototype blur: Ignite member UUID, wallet owner ID, wallet entry ID, Pay Page session ID, PG token. This alone prevents a class of bugs.
- Catches that the existing Pay Page session **defers authorization**. A plan that treated the returned token as "paid" would ship a flow that never charges. The `PaymentAdapter` with explicit authorize/finalize/void is the correct consequence.
- Dedicated opaque checkout cookie plus server-side store, rather than overloading `SESSION-ID`. Correct given what `SESSION-ID` actually is today.
- Identity and wallet write rules (section "Identity and wallet write rules", items 1–7) are the best statement of the member-ID-only model in either draft: no agreement roles, no `PRIMARY`/`CLUB_ACCOUNT` assignments to make a library call work, no last4 dedup, existing owner reuse, metadata allowlist with `dt_memberType=PROSPECT` and no `dt_agreementNumber`.
- Separate route shell (`SignupShell.tsx`) so the day-pass route does not inherit the signup club-fetch, trackers, stepper, and `isPageUnavailable` logic in `App.tsx`. Verified as necessary: `App.tsx:106-150` dispatches four club fetches and `setTrackers` unconditionally.

### Completeness — strong, with three over-reaches

- Covers every prototype state (U1–U13), every failure boundary in PRD §4.4 and several the PRD omits (authorization timeout, contact race at create, issuance after settlement, delivery failure, refresh).
- Proposes defaults for all ten of the intent's open questions and names the owner and consequence for each unanswered live question.
- Over-reach 1: **B6 retrofits browser-ownership tracking onto all existing Pay Page sessions**, including live signup. The bypass it closes is real (verified above), but modifying production signup session handling inside a dark-flagged feature sprint raises regression risk and the "compatibility for preexisting sessions at rollout" is unaddressed. Recommend narrowing: tag pass-purpose sessions at creation and make the generic poll/close routes refuse sessions carrying a pass purpose. That closes the bypass without touching signup session semantics.
- Over-reach 2: **the purchase checkpoint machine** (`VALIDATED → … → COMPLETE`, plus `RECONCILING`/`COMPENSATING`) and the `202 processing` + status-poll path are designed before A2 settles whether the POS sale captures or a payment API does. Codex acknowledges this. For a sprint whose live mode will almost certainly stay off, a simpler synchronous purchase with a durable operation record and idempotency key would deliver the same local proof at lower cost. Keep the state names in the contract doc; implement the minimum that mocks need.
- Over-reach 3: **twelve browser endpoints**. `resend` and `channel` could be one `POST /challenges/:id/actions` with a discriminated body; `DELETE /identity` and `DELETE /checkouts/:id` could collapse. Not wrong, but each endpoint is a schema, a test file, and a UI thunk.

### Phasing and ordering — good

- A (contracts) → B/C/D in parallel against frozen fixtures → E is correct and front-loads the only decisions that block live work.
- Exit criteria per phase are concrete and testable ("neither a forged cookie/body nor a generic Pay Page route retrieves another checkout's data").
- Weakness: A is 2–3 days but depends on external owners answering contract questions. If they do not answer in that window, A4's instruction to "record chosen scope as local complete target" is the right fallback, and it should be stated as the expected outcome rather than the exception.

### Risk coverage — strongest section in either draft

- The failure-boundary table is directly implementable as test cases.
- Names enumeration honestly: the prototype's distinct "no match" and "challenge" states make full anti-enumeration impossible; records the residual disclosure for security review instead of pretending.
- Multiple matches become an explicit ambiguous state with desk-help copy. Correct for household-shared contacts.
- Gap: the proposed cookie is `SameSite=Lax`, host-only, top-level only, with embedded checkout deferred. The existing online join is deployed in iframes on club sites (hence `sameSite: none, partitioned` today and `appIsUsedInIframe` / `ancestorOrigins` in the UI). If day pass must be embeddable in v1, this is a product decision with real architectural consequence. Codex flags it in one sentence; the merged plan should promote it to a kickoff decision.

### Feasibility — the main concern

- 20–27 engineering days across UI, BFF, and QA is at or beyond a normal sprint for the likely team size. Codex says so and refuses to cut OTP, hosted fields, identity rules, failure behaviour, or tests. That is the right refusal, but the plan should also name what **can** be cut: B6's generic retrofit, the async purchase path, metrics (E5), and the mock outbox inspection tooling.
- The prose density will slow implementers. Several paragraphs are policy statements without a task ID. The merged plan should move the policy into the contract doc and leave task tables with one-line rationale.
- G4 (PCI boundary) requires a real Pay Page SDK sandbox run. This depends on sandbox access the team may not have. Codex handles it with "mock demo complete; sandbox hosted collection unverified", which is honest, but it should be raised as a day-one dependency, not discovered at E1.

### Definition of done — excellent

- G0–G8 sprint gates versus L1–L5 live-enablement gates is the clearest "done" vocabulary either draft offers, and it prevents the common failure of a mock demo being reported as a working product.
- Owner slots with "no unnamed role signs off" is good practice.
- Coverage thresholds stated exactly and correctly.
- Minor: G2 (design parity) depends on a DESIGN owner who may not exist in this team; allow the UI lead to sign it with a documented deviation list.

### Strongest ideas to keep

1. The evidence table that corrects the intent (`window.process.env`, deferred authorization, no browser ownership on Pay Page poll/close).
2. Five-identifier separation and the seven identity/wallet write rules.
3. Failure-boundary table with per-boundary required behaviour.
4. Sprint gates G0–G8 separate from live gates L1–L5, and the completion vocabulary.
5. Adapter table with "existing evidence / selected approach" per adapter and `SHORT_TERM_PASS_ADAPTER_MODE` with production refusal of mock mode.
6. Proposed defaults for every open question, with owner and effect-if-unanswered.
7. Stateful mocks that persist across Start again so the secondary-contact repeat-purchase path is real behaviour.
8. Internal naming `ShortTermPass` / `durationDays` per intent constraint.

### Weaknesses and gaps

- Scope and density as above.
- B6 modifies live signup Pay Page handling.
- `SameSite=Lax` cookie versus iframe deployment reality needs a product decision.
- Unverified wallet "index drift" claim stated as fact.
- Does not name the LD anonymous-context problem explicitly.
- Does not mention `webpack.dev.config.js` proxying: the local demo is routed through the BFF on :3000, which is correct, but developers running the UI directly on :3001 will need a dev-proxy entry for the new API prefix or requests will hit MICO's `/iclub` proxy and fail.
- No mention of the club theme dependency: `App.tsx` blocks render on `colorSchemaReady`; the new shell must decide whether to wait for club theme or use the `--ig-*` tokens regardless.

## Gemini draft

### Architectural soundness — right skeleton, wrong details

- Correct big picture: route under `/signup/day-pass`, BFF router modelled on `payPage`, adapter toggle for missing upstreams, RTK slice, scoped tokens under a `DayPassPage` root, payments only via `@abc/pay-page-sdk`.
- Wrong or under-specified:
  - Binds post-OTP identity into "a `SESSION-ID` context". See verification above: that cookie is unpopulated by this BFF, `sameSite: none, partitioned`, and semantically a different thing. Needs its own cookie and store.
  - Single `POST /api/day-pass/checkout` collapses quote, date, terms, consent, profile, payment, and purchase. There is no idempotency key, no purchase status, no wallet-only retry, so R2's "retryable responses" has no endpoint to land on.
  - Phase 4 ordering "(1) evaluate SDK payment tokens (2) persist prospect (3) read member GUID (4) POST wallet-entry" **omits authorization**. The existing session defers authorization, so this sequence would persist a prospect and save a card without ever charging. It also omits owner/user creation before entry creation, the consent gate, and the recognized-visitor-with-new-card path.
  - Says use the toolkit `universalWallet` and then names the raw `/wallet-entry/credit-card` path; pick one and verify it (Codex's A2).
  - Internal naming is `dayPass` everywhere, contrary to the intent's short-term-pass naming constraint.

### Completeness — insufficient

- Four use cases where the prototype has at least eight distinct paths. Missing: recognized visitor with new card, new visitor who declines save, returning visitor with zero cards, existing member match, multiple matches, wallet lookup failure, Start again and re-verify by secondary contact, flag-off/club-invalid states.
- No contract table, no request/response shapes, no error envelope.
- No handling for: date and club timezone, terms versioning, price authority, pass issuance and delivery, refresh recovery, club change, CSRF/origin, production refusal of mock mode, rate-limit dimensions beyond "per IP".
- Files table names six paths with no test files.
- Open questions restate the intent's questions without proposing answers.

### Phasing and ordering — reasonable shape, no gates

- Five phases in a sensible order, but no exit criteria, no sizing, no owners, no parallelism notes. Phase 5 ("ramp tests to coverage") schedules testing last, which usually means coverage is chased rather than designed.

### Risk coverage — thin

- Three risks. R3 (global styling conflicts, scope `dt-*` under `DayPassPage` roots) is a genuinely good catch and should be kept. R1 (OTP abuse) is correct but shallow. R2's mitigation "card just avoids storing" does not say what the user is told, which is exactly the "never claim saved" rule the intent requires.
- No risk for: token-is-not-authorization, generic Pay Page bypass, in-memory state across restarts, multiple-match, timezone, existing member, iframe embedding.

### Feasibility — appears feasible only because it under-specifies

- The plan would fit a sprint, but the missing work (authorization, purchase orchestration, session store, contract, tests) would surface during implementation and either blow the sprint or ship a flow that does not charge.

### Definition of done — weak

- "Mock Playability" and "Dark Deploy" are fine as headlines. "Contracts Asserted: log member ID assertions ensuring no PROSP payload leaks" substitutes logging for tests. No distinction between local-complete and live-enabled, so a mock demo could be reported as done.

### Strongest ideas to keep

1. The one-screen readability. The L1 A/B/C split and the five-phase summary are what a sprint doc's top layer should look like; Codex's version needs this layer.
2. R3: scope all `dt-*`/`--ig-*` styles under the page root to protect `GuestReviewPage` and the rest of signup.
3. The dependency note about not duplicating `GuestReviewPage` functionality: reuse `FormInput`, `Modal`, `TermsAndConditions`, `HeadingBox` where they fit.
4. Use-case table format (ID, title, one-line summary), expanded to Codex's coverage.

### Weaknesses and gaps

- Everything under Completeness and Risk above.
- Phase 4 ordering is unsafe as written.
- `SESSION-ID` reuse is the wrong session model.
- `dayPass` naming violates the intent constraint.
- "Mocked Axios responses" for a `got`-based toolkit.
- Non-existent `src/assets/styles/` path.

## Recommendations for the merge

1. **Base on Codex.** Keep architecture, contract table, adapter table, identity/wallet rules, failure table, G0–G8 and L1–L5 gates, proposed defaults.
2. **Add Gemini's top layer.** A one-screen overview with the A/B/C split, a compact use-case table, and five phase headlines, so an implementer can orient in two minutes before reading the Codex detail.
3. **Trim Codex scope** in this order if capacity is short: (a) replace B6's generic Pay Page session-ownership retrofit with pass-purpose tagging plus refusal on the generic routes; (b) make purchase synchronous with a durable operation record and idempotency key, keeping the checkpoint names only in the contract doc; (c) defer E5 metrics; (d) merge `resend`/`channel` into one challenge-action endpoint.
4. **Promote three items to kickoff decisions:** iframe embedding in v1 (drives cookie `SameSite`), Pay Page sandbox access (drives G4), and which owner answers A2's payment questions (token-to-PG, authorize-before-person, sale-captures-or-not).
5. **Add two named tasks Codex implies but does not list:** explicit club context for LD evaluation at HTML render (today it is `ANONYMOUS` without a session), and a `webpack.dev.config.js` proxy entry for the new API prefix for developers running the UI on :3001.
6. **Adopt Gemini's R3 wording** for style scoping and Codex's rule to port no `:root`, `body`, or universal-selector overrides.
7. **Rephrase the wallet "index drift" finding** as a question for wallet owners rather than a stated fact, since it was not verified from the repos in this workspace.
8. **Use short-term-pass internal naming** throughout, per the intent; "day pass" remains UI copy only.
