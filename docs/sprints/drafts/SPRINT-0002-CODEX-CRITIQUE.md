# Sprint 0002 — Codex critique of Claude and Gemini drafts

Reviewed 2026-09-10 against [Sprint intent](SPRINT-0002-INTENT.md), including its carried constraints and success criteria. Supporting checks included the change-request list, PRD consent requirements, and the existing capture hook and wallet service. This is a plan review, not a validation of either draft's claimed execution evidence.

**Recommendation:** Use Claude's draft as the implementation baseline, after correcting its evidence gaps and reducing optional tooling scope. Gemini offers useful simplicity and a promising post-verification lookup design, but needs substantial expansion before it can guide implementation or acceptance.

| Criterion | Claude | Gemini |
|---|---|---|
| Architectural soundness | Strong reuse and concrete contracts; consent lifecycle needs reconciliation | Directionally aligned; payment readiness proposal conflicts with a carried constraint |
| Completeness | Covers all CRs/PRs explicitly; visual and negative-path proof still incomplete | Names the major themes but omits important behaviors and contracts |
| Phasing/ordering | Contract first and parallel lanes are sensible; prerequisites and early proof need adjustment | UI/capture first and harness last create avoidable integration risk |
| Risk coverage | Broad and actionable, with several unresolved internal contradictions | Covers three external blockers; little coverage of implementation or harness failure |
| Feasibility | Executable detail, but ambitious tooling scope and unclear staffing arithmetic | Compact scope presentation without estimates, owners, or enough tasks to assess delivery |
| Definition of done | Mostly measurable; incomplete state matrix and ambiguous pending-gate wording | Too broad to distinguish implementation from demonstrated completion |

## Claude draft

### Architectural soundness

The strongest architectural choice is to extend Sprint 0001 rather than rebuild it. The draft identifies the existing hosted session path, replaces artificial readiness with an additive embed callback, preserves submit → bounded poll → purchase, and carries forward session, authorization, wallet ownership, and idempotency constraints. Moving profile state into a shared source and defining one Pay action directly addresses the sidebar/main-form coordination problem.

The consent contract is substantially better specified than Gemini's: template version plus rendered hash, document-specific affirmative acts, server validation of the exact Pay text, and separation of order updates from purchase acceptance. However, it has unresolved lifecycle problems:

- **Identity binding:** events can be recorded before a new prospect has a UUID, and the proposed event makes `memberId` optional. PRD §5A.10 calls for person UUID and channel. Specify how pre-purchase events become durably associated with the persisted person, including when a later purchase stage fails; include channel explicitly.
- **Persistence and failure behavior:** the ledger has only an in-memory implementation and a platform `NOT_ENABLED` adapter. Define whether that adapter blocks checkout, whether the purchase snapshot is sufficient evidence for this sprint, and what platform enablement requires. Do not imply durable consent evidence has been delivered by an inspectable mock.
- **Retries and ordering:** B3 records opt-in/stored-card events on order updates, while B4 appends them again at `VALIDATED`. Distinguish preference changes from a purchase snapshot and specify deduplication under an identical `Idempotency-Key`, ledger failure, and wallet retry. Otherwise repeated payment attempts can generate misleading acceptance histories.
- **Stale content:** `renderedHash` is described in prose but absent from the displayed `ConsentDocument` interface. Define how changed date, offer, or template content reaches the UI, which acceptances are invalidated, and how a 409 refreshes the documents before another Pay attempt.

These are contract-level issues to resolve in A, before the BFF and UI lanes implement separate interpretations.

### Completeness

The U1–U22 matrix and task references provide strong CR/PR traceability. Required mobile, save default off, transactional notices, marketing consent, recognized-card replacement, receipt copy, and CF ownership all receive explicit treatment.

The main gaps are in proof and edge behavior:

- **All four document modals need visual checks at both widths.** U18/D1 substitute text-only checks for stored-card and privacy dialogs. The intent explicitly requires each document modal; shared framing does not prove wrapping, scrolling, footer visibility, or mobile overflow for different content lengths.
- **Hosted proof should include a first-time buyer.** E3 specifies a returning buyer's replacement-card variant. That helps verify reuse, but CR-03/04 specifically require a first-time buyer to see the hosted form without a picker. Exercise that lane when B1 clears, including an invalid/expired card followed by recovery.
- **Existing-card receipt semantics need correction.** U16 places a recognized saved-card purchase into a “saved to your wallet” versus “you chose not to save” split. Distinguish an existing saved card, a newly saved card, a new unsaved card, and a failed wallet save. Paying with an existing card must not claim it was newly saved or will need re-entry next time.
- **Recognized marketing preference and waiver reuse remain unresolved.** NQ-2/NQ-3 expose these honestly, but their defaults should be explicit scope decisions. An untouched unchecked control must not overwrite a returning person's existing preference, and “always ask” should be recorded as a deviation from D24's version-based waiver reuse.

### Phasing and ordering

Contract freeze followed by BFF, UI, and harness lanes is the right structure. Keep the source-of-truth inventory and parity exceptions early. Start a minimal failing parity capture and OTP-sink/browser smoke immediately so tooling assumptions are tested before the UI is finished.

The claim that D is state-agnostic is too optimistic: it depends on new fixtures, inline OTP, consent controls, and testing routes. Define staged harness exits: prototype capture, old-build diagnostic report, then v2 end-to-end run. An “expected to fail” completion against Sprint 0001 is not a clear acceptance gate.

Move B1 configuration preflight to kickoff and make hosted proof a standing task triggered by credential availability, rather than letting its placement in E imply it waits until the end. Resolve branch/status choices before A1 mutates branches; the draft currently places those decisions in A5. Correct the inconsistent OQ numbering around the static location label.

### Risk coverage

The risk register is the stronger of the two by a wide margin: credentials, consent approval, pixel nondeterminism, enumeration, test hooks, membership regression, and agent self-reporting all have proposed mitigations.

Additional risks or corrections:

- A 300 ms floor and matching response keys do not establish timing indistinguishability if lookup latency exceeds the floor. Test observable failures and latency behavior as well as response shape; consider Gemini's lookup-after-verification alternative.
- `debug.code` remains allowed in mock responses while mock adapters can now power a hosted demo. Tie any debug code exposure to explicit test hooks or remove it in favor of the sink.
- Masking `.toast` removes visual coverage of required save-card feedback. Test toasts separately. Assert mask geometry so an oversized card-slot exclusion cannot conceal surrounding layout errors; require review for new approved deltas.
- The browser-policy self-test equates absent/disabled `navigator.credentials` with payment autofill control. That is not an adequate proxy. Verify clean profiles, configured preferences, and actual suggestion behavior; smoke-test the proposed CLI permission restrictions rather than assuming they constrain a bypass-permissions run.
- Server-state judging by “last purchase for email” can read a previous run, particularly for the fixed returning fixture. Correlate verdicts with a run ID and exact checkout/purchase, and isolate/reset fixtures.
- Changed shared components need explicit regression coverage. Keeping membership tests unchanged is not itself evidence that new readiness/error callbacks preserve membership behavior.

### Feasibility

The file/function detail makes implementation estimable, but the scope includes a browser daemon, three agent-CLI adapters, two email backends, visual comparison/reporting, and dev orchestration alongside substantial product changes. Roughly 3.5 harness days is aggressive for that surface.

Start with one supported agent CLI, a small browser interface, and the mock outbox sink. Add the SMTP lane and alternate CLI runners only after mandatory proof passes; label them consistently as optional rather than listing them as unconditional tasks. Pin dependencies with a lockfile and record the Chrome/font environment used for evidence. Clarify whether “~16 engineering days” means total person-days or elapsed time with three staffed lanes, and reserve integration time explicitly.

### Definition of done

S0–S9, coverage floors, commands, artifacts, and CR-to-commit mapping are worth keeping. The completion vocabulary is internally inconsistent: S0–S9 cannot all pass while S5 is pending. Report implementation/mock proof and hosted verification separately, with an explicit overall status when B1 remains open. The intent permits work to proceed without credentials; it does not permit hosted verification to be reported as passed.

Expand S2 to all modals, S5 to the first-time hosted lane, and the required validation matrix to expired-card rejection/recovery. An eight-iteration cap should produce an unresolved-differences report, not a parity pass. Keep CFs open with owners; they are confirmations, not new build gates.

**Strongest ideas to retain:** precise contract-first work breakdown; reuse of the existing Pay Page integration; real readiness callback; dual consent version/hash evidence; deterministic pixel-plus-semantic parity; authenticated local test hooks; independent agents judged against server state; explicit separation of mock proof and external enablement.

## Gemini draft

### Architectural soundness

The draft correctly chooses sidebar consent/Pay, inline email OTP, catalog-served documents, and UUID-based prospect-wallet ownership. Its OQ-5 recommendation to defer member lookup until verification is especially useful: it reduces pre-verification directory timing/error exposure and avoids retaining a potentially stale candidate during the challenge. Specify where verification success is retained if the subsequent lookup fails and how retry works without requiring a reused OTP.

**The payment readiness proposal must change before implementation.** OQ-4 recommends loaders until session polling returns a token. The existing capture hook obtains capture readiness after the user presses Pay and the embed submits. Waiting for a token before making the form/Pay usable risks a circular dependency. Preserve form-ready → Pay → submit → bounded poll → purchase, with token resolution on the BFF and only readiness/session references returned to the browser.

“Implement the SDK” in Phase A also overlooks that the pass embed/session path already exists. Name the precise changes to configuration, callbacks, and errors. The wallet discussion conflates correct MEMBER ownership with avoiding the backend dedup defect: UUID ownership and omitting agreement metadata do not themselves fix the backend. Preserve the gated write path and prove the exact owner/entry payload.

### Completeness

Listing all CRs as done is not enough when tasks omit required behaviors. Missing or materially underspecified work includes:

- Save-card default off; required new-visitor mobile; exact email/SMS notices; sidebar skeleton/date/receipt states; recognized replacement-card and wallet failure states.
- Separate adult/waiver enforcement, document open/close evidence, stored-card disclosure evidence, and pass-terms-by-Pay with exact button text. Recording all acceptance at `PUT /order` does not capture the Pay act required by the intent.
- Rendered hashes alongside template versions for dynamic Pass Terms; stale-document rejection; server timestamps, person/channel linkage, and idempotent purchase evidence.
- Explicit mock-capture test policy, production guards, unchanged authorization/session constraints, and regression protection for purchase ordering and wallet retries.
- Deterministic prototype/build state drivers, every modal, pixel tolerance, computed-style selector mapping, font/clock control, and a terminating diff criterion.
- At least three independent browser-driving agents, isolated sessions/fixtures, transcripts, server-side judging, browser autofill policy, and expired-card proof.

The PROPOSED recommendation also needs restraint: the intent requires the marker in catalog fixture/config. Hardcoding it alongside every rendered text instance adds an unapproved design change. Keep approval state in versioned configuration and explicitly decide any customer-visible treatment.

### Phasing and ordering

Phase A changes payment and consent before defining the shared contract, then Phase B changes identity, and the OTP sink arrives only in D. This leaves the UI dependent on moving APIs and postpones the infrastructure needed to test the new flow.

Add kickoff decisions and contract/error shapes first. Implement OTP plus its sink early, run parity capture alongside UI changes, and begin hosted preflight immediately. Integrate wallet consent metadata with the consent/purchase work rather than treating it as a late isolated task. Include phase exit criteria and a final integration/evidence phase.

The overview treats existing-branch updates and Sprint 0001 closure as settled while Open Questions calls them recommendations. Both are interview items in the intent. Keep them provisional until resolved, with explicit G2/G4 transfer records.

### Risk coverage

Credentials, counsel approval, and wallet dedup are relevant risks, but structural API tests cannot substitute for hosted proof. Missing credentials should leave a named pending verification item.

Add enumeration/rate-limit boundaries, OTP replay and Change invalidation, stale consent and retry behavior, capture timeout/recovery, shared membership regressions, parity nondeterminism, and agent false positives. A route exposed “strictly under mock modes” is not sufficient isolation: demos also use mock adapters. Define an explicit test switch, authentication, local-only access, and production refusal, plus sanitized evidence artifacts.

### Feasibility

The concise plan is easy to scan and avoids committing to multiple optional integrations. That restraint is useful. However, it has no estimates, lane ownership, critical path, installation/bootstrap commands, or concrete external enablement checklist. Its apparent small size reflects omitted work. Estimate only after adding the missing contract, harness, and validation tasks; reuse existing capture and wallet services to keep the resulting scope manageable.

### Definition of done

The current four bullets are not auditable. “Zero unauthorized differences” needs an actual comparison specification and exception ownership. “Agents successfully drive complete mock-payments” needs a count, personas, isolation requirements, observable assertions, and saved artifacts.

Add the intent's lint/build/coverage floors, existing-suite and demo regressions, all-state/two-width visual matrix, expired-card scenario, CR-to-commit/test traceability, documented PR commands, explicit CF owner rows, and separate hosted/wallet enablement evidence. Sprint 0001 closure is status bookkeeping, not evidence that this sprint meets those gates.

**Strongest ideas to retain:** post-verification identity lookup; the option to retain distinct internal identity states while sharing one screen; a selected single-offer card; keeping tooling in one dedicated directory; a compact plan presentation with fewer optional infrastructure commitments.

## Recommended synthesis

1. Adopt Claude's task and gate structure; reconcile consent identity binding, evidence persistence, retries, and stale-content handling before implementation.
2. Evaluate Gemini's post-verification lookup against the existing challenge/session model, while retaining Claude's precise response and rate-limit contract.
3. Keep readiness-gated payment and reuse the existing hosted capture and wallet paths. Require first-time hosted proof when B1 becomes available.
4. Deliver the smallest harness that satisfies all four PRs: one agent CLI, mock OTP sink, isolated browsers, three required personas, complete visual state coverage, and server-correlated evidence. Include expired-card rejection/recovery in required tests.
5. Freeze parity exceptions and distinguish implementation complete, mock verified, hosted verified, and platform enablement pending. Resolve branch strategy and gate transfer once, and record the result consistently.
