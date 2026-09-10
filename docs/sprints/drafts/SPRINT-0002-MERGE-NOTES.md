# Sprint 0002 Merge Notes

Orchestrator: Claude Fable 5.1, 2026-09-10. Inputs: `SPRINT-0002-INTENT.md`, the three drafts (`CLAUDE`, `CODEX`, `GEMINI`), the three critiques, and the user's interview answers.

## Claude Draft Strengths
- Most executable UI breakdown: every step, component, hook and SCSS class named with what changes, what is deleted (`VerifyStep`, `PayBar`, `TermsDialog`, `SaveCardToggle`, `MockCardCapture`) and which v1.2 copy is pinned in tests.
- Consent model with `templateVersion` plus rendered-content hash; pass terms recorded at Pay against the server's canonical button text; adult / waiver / stored-card / marketing / notices as distinct records.
- `STP_TEST_HOOKS` policy: capture defaults to `paypage` everywhere, mock capture and the outbox reader exist only behind hooks, production refuses hooks at boot.
- Parity loop design with a frozen clock (`STP_TEST_CLOCK`), `document.fonts.ready`, named element list with computed-style and text comparison, approved-delta file with citations, and a finite iteration cap.
- Agent runner judged by server state through a testing route, not by the agent's own claim.
- Facts verified in code (mock capture `<select>` is what the review saw; identify skips OTP on no match; readiness faked by `setTimeout`).

## Codex Draft Strengths
- Three defects the CR list did not know about: wallet `providedId` must be a UUID (today it receives `pur_…`; a live write would be rejected); v1.2 Pass Terms promise a full refund while PRD D15/D22 forbid online refunds; `PayPageEmbed` swallows the SDK `onLoad` so readiness is faked.
- Lookup **after** code consumption (no directory call before possession is proven), and a `recognized | newVisitor | unresolved` verify union.
- `consentRevision` bound to the order and folded into the idempotency fingerprint; stale revision → 409 before any authorization.
- `CheckoutController` lifting the embed ref and the Pay action above main panel and sidebar so moving Pay to the sidebar cannot create two hosted sessions.
- Three evidence lanes (deterministic local, hosted sandbox, dev wallet) with a completion vocabulary that never lets mock evidence close a hosted gate.
- Traceability CR/PR → task → gate; noticed the SPRINT-0001 header/ledger status mismatch; refused to auto-add Sprint 0001's "carried to 002" list.

## Gemini Draft Strengths
- Absorb the review changes into the open PRs on the existing branches (adopted by the user).
- Mark Sprint 0001 complete with G2/G4 explicitly transferred (adopted).
- Render the single offer as a permanently selected offer card (all three agree).
- Keep tooling in one dedicated directory; keep the plan short where it can be.

## Consensus Critiques (multiple agents agreed)
- Claude's draft is the UI/consent baseline; Codex's wallet `providedId`, refund ruling and readiness fix must be kept verbatim.
- Test hooks must be unreachable in ordinary and production runtime with a test that iterates the router stack.
- Every one of the four document dialogs needs a visual check at both widths, not text-only.
- Hosted proof, when B1 arrives, must include a first-time buyer and an expired-card rejection followed by recovery.
- Agent verdicts must be correlated by run and checkout id, never "last purchase for this email".
- Codex's harness scope (separate leased test server, SMTP lane, browser broker with three CLI runners) is too large for the sprint; start with one CLI and the mock outbox.
- Gate letters must not collide with Sprint 0001's G2/G4.

## Valid Critiques Accepted
- Move the demo-script rewrite (read the code from the outbox) **before** `debug.code` is removed, otherwise the demo is red for most of the sprint.
- Decide how Inter is loaded (user: self-host woff2; the SCSS currently `@import`s Google Fonts).
- Split the v1.2 styling task into shell / main panel / sidebar so parity failures land on a named task.
- Phase A (contract freeze) is 1.5–2 days, not half a day.
- Toasts are masked in the pixel diff, so assert their text separately.
- Browser-policy self-test must check for an actual autofill suggestion on a card-number-shaped input, not the presence of `navigator.credentials`.
- Receipt copy must distinguish existing saved card, newly saved card, new unsaved card and failed save (resolved: v1.2's "saved to your wallet" alert is truthful for an existing card too; failed save keeps the Sprint 0001 retry alert as an approved delta).
- Run one scripted smoke agent before the three autonomous agents so a broker bug and an agent-judgement failure are distinguishable.
- State the CR-04 root cause once in the traceability record (the review saw `MockCardCapture`; autofill is disabled anyway by the browser policy).
- Consent events recorded on order updates must not be appended again at purchase: preference state lives on the order; one snapshot per purchase, idempotent under the same key.

## Critiques Rejected (with reasoning)
- **Separate loopback test-server entrypoint with bearer leases (Codex; endorsed by Gemini).** Sprint 0001's `isMockMode` gating plus `STP_TEST_HOOKS`, loopback peer check, a key header and a production boot refusal give the isolation at a fraction of the build; each agent owns its checkout so leases are unnecessary. User chose the trimmed scope.
- **Per-person waiver reuse store (Codex, D24).** No CR asks for it and it cannot be demonstrated with one fixture person; waiver acceptance is recorded on the purchase record, the checkbox is always presented (v1.2 renders it), and D24 reuse becomes a readiness item.
- **SMTP/Mailpit lane (Claude and Codex drafts).** No platform email adapter exists to point at it (L1); a design note suffices. User chose trimmed scope.
- **Disposable-domain provider policy.** A small fixture list only; provider choice is L1.
- **Codex 0.1 % pixel threshold.** Too tight between a hand-written prototype and React+MUI; 0.5 % outside masks with zero semantic deltas is the criterion, calibrated on two reference self-renders, loosened only by a human with a recorded reason.
- **Gemini's "hardcode PROPOSED alongside every rendered text".** The marker stays in catalog fixture/config and the capability report, never in the customer UI.
- **Gemini's use of the generic `GET /api/pay-page/session/:id` poll.** Sprint 0001 deliberately routes pass sessions through `/checkouts/:id/capture` and the generic routes refuse pass sessions.

## Interview Refinements Applied
1. **Branches:** review changes land on `prospect-wallet/sprint-0001` in both repos; PRs #96 and #524 absorb them. No stacked branches.
2. **Sprint 0001:** ledger status `done` with a header note "G2 and G4 transferred to SPRINT-0002 (S2, S5), not passed"; the `planned` header line is corrected.
3. **Scope:** trimmed — no consent store / waiver reuse, no separate test server, no SMTP lane. Kept: consent revision, UUID `providedId`, refund ruling, `onLoad` readiness.
4. **Inter:** self-hosted woff2 (four weights) replaces the Google Fonts `@import` in `short-term-pass.scss`.

## Final Decisions
- Tooling lives in this planning repo under `tools/day-pass-harness/` with its own `package.json` and lockfile; product repos gain no harness dependencies.
- Lookup runs after code consumption; identify never touches the directory. Directory failure after a consumed code keeps `emailVerifiedAt` on the checkout and returns a retryable 503; retry re-runs the lookup without a new code.
- Header location switcher rendered as a static label styled like `.dt-switcher` with no popup semantics (approved delta).
- Visit date defaults to club-local today after verify (CR §D); v1.2's blank-state help string never renders (approved delta). Skeleton sidebar before an order; `pendingVisitDate` retired.
- Marketing opt-in shown to new visitors only this sprint; recognized preference is a later read (readiness item).
- Transactional email notice is a help line under the email field (approved delta, §4.5).
- `debug.code` removed from every API response; codes are read from the outbox via the hooks-only testing route.
- Agents: `claude -p` only this sprint; codex/agy runners deferred.
- Gates numbered S0–S9 to avoid collision with Sprint 0001's G-gates.
