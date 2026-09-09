# Sprint 0001 Merge Notes

Orchestrator synthesis, 2026-09-09. Inputs: `SPRINT-0001-INTENT.md`, the three drafts, the three critiques, and the interview answers recorded below.

## Claude Draft Strengths

- Code-verified corrections to the intent that all reviewers accepted: runtime config is `window.process.env` (not `window.env`); the Pay Page SDK delivers no token in a callback, the UI polls `GET /api/pay-page/session/:id` and reads `result.NEW_PAYMENT_METHOD.TOKEN[0]`; `SESSION-ID` helpers are called by nothing in production code; `jose` and `ajv` are declared but unused; `jest.config.js` maps `jose` to a mock file that does not exist; MICO `/trial/submit` needs address, signature, campaign and a session CSRF token so it cannot be a lean prospect adapter; MICO `/shop/*` is `@Secured("ROLE_USER")`; the toolkit has no SMS surface.
- The most concrete file-by-file implementation plan: route branch, slice shape, selectors, service module, step components, scoped SCSS, primitives, test files, demo script.
- Recursive payload scan test that fails the suite if `PROSP`, `agreementNumber`, `dt_agreementNumber`, `dt_memberNumber`, or `dt_memberOrdinal` appear in any payload the BFF sends.
- Prototype-faithful copy and masking rules turned into test assertions; `canPay` selector table.
- Estimates by task and a two-lane schedule.

## Codex Draft Strengths

- Trust boundary: the browser never sends `memberId`, owner or entry IDs, org/location, price, terminal ID, or PG token; the server resolves and binds club/org/location at checkout creation and later requests cannot replace them.
- Separation of five identifiers the prototype blurs: Ignite member UUID, wallet owner ID, wallet entry ID, Pay Page session ID, PG token.
- Confirmed that the due-today Pay Page session **defers authorization** (`deferAuthorizationToPayment: true`), so a token is not a charge; explicit `PaymentAdapter` with authorize / finalize / void / status.
- Opaque server-side checkout session in a dedicated cookie instead of overloading `SESSION-ID` or carrying `memberId` in a JWT.
- Confirmed the generic Pay Page poll/close routes check only UUID shape and club, never browser ownership.
- Seven identity and wallet write rules (no agreement roles or assignment tags to make a call work; no last4 dedup; existing-owner reuse; metadata allowlist).
- Failure-boundary table directly implementable as tests; ambiguous-match state; honest treatment of enumeration.
- Sprint delivery gates G0–G8 separate from live-enablement gates L1–L5, with the completion vocabulary "local checkout complete; live integration blocked".
- Proposed defaults for every open question with owner and effect-if-unanswered.
- Stateful mocks that persist across Start again so the secondary-contact repeat-purchase path is real behaviour.

## Gemini Draft Strengths

- One-screen readability: the A/B/C workstream split and five phase headlines are the right top layer.
- Compact use-case table format.
- R3: scope every `dt-*`/`--ig-*` style under the page root to protect the existing signup flow.
- Reminder to reuse existing UI components where they fit rather than duplicating `GuestReviewPage` work.

## Consensus Critiques (multiple agents agreed)

1. **Codex is the architectural base; Claude supplies the implementation layer; Gemini supplies the top layer.** (Claude critique, Gemini critique, Codex critique in substance.)
2. **Claude's new-card Pay gate deadlocks** as written (`capture.status === 'TOKENIZED'` required before Pay, while Pay triggers tokenization). Fix: enable Pay on day + terms + form readiness; sequence submit → bounded poll → purchase. (Codex critique; consistent with Claude critique's reading of the existing flow.)
3. **Sale, authorization, and issuance must be distinct states**; a token is not a charge; "Paid" must never be shown from authorization alone. (Codex draft, Codex critique, Claude critique.)
4. **Pay Page sessions must be bound to the checkout that created them**; the generic poll/close routes are a bypass. (Codex draft, Gemini critique, Codex critique.)
5. **Both the LaunchDarkly flag and the club's `onlineProspects` setting are enforced server-side on every pass route**, fail closed. (Codex draft, Codex critique.)
6. **Multiple matches are an explicit unresolved state**, never "first match" and never "no match" that would mint a duplicate prospect. (Codex draft, Codex critique, Claude critique.)
7. **Stateless JWT carrying `memberId` is the weaker session model** for this flow; use an opaque cookie with a server-side store behind a port. (Gemini critique, Claude critique, Codex draft.)
8. **Codex over-reaches** on the generic Pay Page ownership retrofit, the async purchase state machine, endpoint count, and metrics; trim these. (Claude critique, Gemini critique.)
9. **Internal naming is short-term pass**; "day pass" is UI copy only. (Intent constraint; Codex draft; Claude critique against Gemini.)
10. **Mock messaging must not log codes** in a way that contradicts the redaction gate; use a mock-mode-only debug channel. (Codex critique.)

## Valid Critiques Accepted

- Pay gate deadlock fix (above).
- Order of operations fixed as **authorize → persist prospect (new visitors) → consented wallet write → finalize sale → issue → deliver**, with void on prospect failure after authorization. Claude's "sell → prospect" and its OQ-R7 "confirm or invert" are replaced; the PRD §4.4 failure rules are satisfied without leaving a paid sale with no person record.
- Pay Page session ownership: implement the **trimmed** form. A pass-specific `POST /api/pay-page/session/short-term-pass` tags the session with `purpose=short-term-pass` and the owning checkout; the generic poll/close routes refuse any session carrying a pass purpose. Existing signup sessions are not modified.
- Purchase is **synchronous** with a durable operation record (idempotency key + request fingerprint + one active attempt per checkout + stored outcome). Checkpoint names are kept in the contract document; the `202 processing` / status-poll path is deferred.
- Merge `resend` and `switch-channel` into one challenge-action endpoint.
- Named tasks added for: explicit club context for LD evaluation at HTML render time (today the context is `ANONYMOUS` when no session exists); `webpack.dev.config.js` proxy entries for `/api/short-term-pass` and `/api/pay-page` so developers running the UI directly on :3001 are not routed to MICO; the club theme (`colorSchemaReady`) decision for the new shell; the dangling `jose` jest mock mapping.
- Recognized visitor with **no usable card** and wallet **unavailable vs empty** are distinct states with distinct copy.
- Change contact invalidates challenges server-side; resend and switch share attempt and send limits; stale responses are discarded by checkout generation.
- Origin allowlist is fail-closed when the flag can be on, not "only when set".
- Wallet "index drift" (dedup calculator already changed at the wallet-repos snapshot) is recorded as a question for the wallet owners, not as a fact.
- Wallet reads must not rely on the deprecated, QA-only `getWalletEntries(externalId)`; resolve the owner by `(externalId, MEMBER, org)` and use an owner-scoped entry query, or a small authenticated HTTP client to the verified universal-wallet endpoints, chosen during the adapter spike.
- A class-name snapshot cannot prove style isolation while SCSS is mocked in jest; add a manual browser check of the existing signup route to the design gate.
- Coverage thresholds stated exactly; "reject vs ignore" hostile fields made consistent (reject via `additionalProperties:false`).
- New-visitor checkout session grants access to that order's result only; wallet retrieval later requires OTP.

## Critiques Rejected (with reasoning)

- **Codex's retrofit of ownership tracking onto all existing Pay Page sessions (B6).** Real bypass, but modifying live signup session semantics inside a dark-flag sprint raises regression risk; the purpose-tag-and-refuse form closes the bypass for pass sessions without touching signup. Interview confirmed the trimmed scope.
- **Codex's async purchase path with `202` and status polling.** Correct for the eventual live system, premature before A2 settles whether POS captures or the gateway does. Kept as contract vocabulary and as a Sprint 002 trigger.
- **Codex's E5 metrics task.** Deferred; redacted correlation logs and the test outbox are enough for local proof.
- **Claude's optional diagnostics panel (F).** Dropped; the prototype's "Behind the scenes" log is a demo affordance. Redacted server traces and the mock outbox provide the same insight for the demo script.
- **Claude's eight React primitives.** Reduced: `DtButton`, `DtField`, `DtCheckbox`, `DtAlert`, `DtWidget`; the modal uses MUI v4 `Dialog` (focus trap, Escape, restore) with the scoped class; links are plain elements.
- **Gemini's single `checkout` endpoint** collapsing quote, terms, consent, profile, payment and purchase. No idempotency or retry surface; rejected.
- **Gemini's reuse of `SESSION-ID`.** Unpopulated by this BFF and `sameSite:'none', partitioned` for iframe embedding; different lifecycle; rejected.
- **Codex's `SameSite=None` deliberation / embedded checkout.** Resolved by interview: top-level only in v1.
- **Claude's `[today-1, today+30]` date window.** The `-1` admits a past date and the `+30` invents a maximum; the server enforces club-local today as minimum and takes any maximum from the catalog.

## Interview Refinements Applied

| Question | Answer | Effect |
|---|---|---|
| Merge base and scope | **Codex base, trimmed** | Architecture, contract, identity rules, failure table and gate structure from Codex; file plan and tests from Claude; B6 retrofit → purpose tagging; synchronous purchase; metrics and diagnostics deferred. Target 12–15 engineering days. |
| Embedded in iframe in v1? | **Top-level only** | `OJ-PASS-SESSION` cookie is HttpOnly, Secure, `SameSite=Lax`, host-only. If the page is loaded in a frame it renders a link to open checkout top-level. Embedding is a Sprint 002+ decision. |
| Pay Page dev credentials available? | **Yes, same as the payPage route** | Real hosted card capture is in scope this sprint: the `PayPageSessionReader` platform adapter is live in dev and gate G4 requires a real sandbox run. `MockCardCapture` remains for offline jest and CI. |
| Contact matches an existing member | **Proceed as member** | Verify by code, bind to their member ID, list their existing wallet entries, sell the pass. Member lifecycle and metadata untouched; no `dt_memberType` rewrite; the demo fixture includes an eligible member. |

## Final Decisions

1. Route `/signup/day-pass?club=NNNNN` under the existing basename (`PAGES.shortTermPass = '/day-pass'`), rendered by a dedicated `ShortTermPassPage` branch before the existing signup initialization; the existing routes move under a `SignupShell` with unchanged behaviour.
2. LaunchDarkly flag `oj-short-term-pass-checkout` (club kind, default false), serialized as `window.featureFlags.oj_short_term_pass_checkout`; the BFF builds the LD context from the validated query club at render time and enforces flag + `onlineProspects` + valid club on every pass route.
3. API prefix `/api/short-term-pass`, opaque `OJ-PASS-SESSION` cookie with server-side `CheckoutStore` behind a port, session-bound CSRF token, fail-closed Origin allowlist.
4. Eleven browser routes (see final doc) plus one pass-scoped Pay Page session route; the generic Pay Page poll/close refuse pass-purpose sessions.
5. OTP: HMAC-hashed six-digit code, 10-minute expiry, 5 attempts then locked, 30-second resend cooldown, 5 sends per contact per 15 minutes, 20 identify calls per IP per 15 minutes, 300 ms minimum response latency on identify, fixed code only in mock mode.
6. `STP_ADAPTER_MODE=mock|platform`; production refuses mock. Platform adapters this sprint: `PayPageSessionReader` (live in dev) and `WalletAdapter.listEntries` behind `STP_WALLET_READS` after the spike proves an owner-scoped query; wallet writes typed but throw `NOT_ENABLED` until the sibling backend sprint ships and `STP_WALLET_WRITES=true`.
7. Purchase orchestration order: validate → authorize → persist prospect (new) → consented wallet owner/entry → finalize sale → issue pass → deliver. Synchronous, idempotent, with the failure table from Codex.
8. Design tokens in `src/styles/short-term-pass.scss` scoped under `.short-term-pass`; five primitives; MUI `Dialog` for terms; `PayPageEmbed` reused.
9. Internal naming `ShortTermPass` / `shortTermPass` / `durationDays`; UI copy says "day pass".
10. Sprint acceptance = G0–G8; live enablement L1–L5 registered separately with owners; completion vocabulary "local checkout complete; live integration blocked" when L-gates are open.
