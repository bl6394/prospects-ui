# Sprint 0002 Draft Critique (Gemini)

This document provides a detailed critique of the two competing sprint plan drafts (`SPRINT-0002-CLAUDE-DRAFT.md` and `SPRINT-0002-CODEX-DRAFT.md`) based on the intent defined in `SPRINT-0002-INTENT.md`.

## Architectural Soundness

*   **Claude:** Excellent. The identity `->` challenge `->` verify state machine is well-defined and accurately addresses the CR-05 requirement to mask identity existence before OTP verification. Its consent model is particularly rigorous: relying on SHA-256 hashes of the *rendered* HTML ensures non-repudiation between what the user saw and what the server recorded. 
*   **Codex:** Very strong, particularly regarding external integrations and safety. Codex identifies that a wallet entry needs a distinct UUID (`providedId`) rather than reusing the purchase ID to avoid idempotency collisions. Furthermore, Codex correctly identifies that test endpoints (like the outbox sink) shouldn't just be hidden behind a flag in the main app, but should ideally run on a completely isolated `test-server` entrypoint bound to loopback.

## Completeness

*   **Claude:** Exhaustive. Claude breaks down every single component, hook, and SCSS class that needs modifying to reach v1.2 parity. It perfectly translates the Intent's demands into concrete file changes.
*   **Codex:** Also covers all CRs and PRs accurately. While lighter on exact React component changes, Codex is highly explicit about what is *not* in scope (e.g., broader PRD compliance, member step-ups), which is critical for preventing scope creep.

## Phasing/Ordering

*   **Claude:** Senses correct parallelization. Phasing A (Contract freeze) followed by parallel B (BFF), C (UI), and D (Harness), concluding in E (Validation) is a highly efficient plan.
*   **Codex:** Similar A–F phasing, but places a strong emphasis on establishing dev orchestration and the independent test server earlier in the lifecycle, which is practically sound.

## Risk Coverage

*   **Claude:** Identifies the risk of test hooks leaking into production and mitigates it with early boot guards restricting `STP_TEST_HOOKS`. Claude also handles visual testing flakiness (fonts, dates) well by calling out `document.fonts.ready` and clock-freezing.
*   **Codex:** Superb risk management around external integrations. It insists on not faking the hosted payment proof if credentials (B1) are missing, keeping gates explicitly pending rather than falsely passing them. Its mitigation for test hook leakage (a completely separate application entrypoint) is fundamentally more secure than Claude's flag-based approach.

## Feasibility

*   Both drafts are highly feasible. 
*   **Claude's** detailed mapping of the UI changes makes its plan easier for an agent to blindly pick up and execute. 
*   **Codex's** test-server approach might require a bit more boilerplate (duplicating some Koa setup), but its systemic safety makes it worth the minor overhead.

## Definition of Done

*   **Claude:** Very concrete S0-S9 gates with specified owners. Maps well to the requested artifacts.
*   **Codex:** Explicit about administrative constraints. It makes it clear that closing Sprint 0001 status requires explicit gate transfers and that passing mock tests does not clear hosted/wallet gates. 

## Strongest Ideas Worth Keeping

From **Claude**:
1.  **Consent Hashes:** Hashing the exact rendered HTML for consent documents alongside the template version guarantees provable agreement.
2.  **UI Detail:** The exhaustive list of UI components to delete/modify (e.g., extracting `InlineCodeEntry`, deleting `VerifyStep`, moving everything into `IdentifyStep`) is spot on.
3.  **Boot Guards:** Refusing to boot the production server if test flags are present.

From **Codex**:
1.  **Isolated Test Environment:** Using a separate `scripts/short-term-pass-test-server.ts` bound to loopback for the OTP sink and harness routes, completely decoupling it from production routing logic.
2.  **Wallet Idempotency:** Generating a separate `crypto.randomUUID()` for the wallet `providedId` to safely retry wallet operations independently of the purchase ID.
3.  **Strict Mock vs. Live Evidence:** Refusing to substitute agent runs over mock adapters as evidence for hosted capture (G4).

## Weaknesses or Gaps

*   **Claude:** Integrating the test routes (like the mock outbox) directly into the main BFF router, even if guarded by a flag and loopback checks, is an anti-pattern for secure node applications. 
*   **Codex:** Less descriptive about the exact React component re-architecture, making phase C slightly harder for an agent to execute compared to Claude's granular task breakdown.

## Conclusion

Both drafts are exemplary. The perfect sprint plan would merge **Claude's** rigorous React and Consent implementation details with **Codex's** isolated test-server architecture and strict wallet/hosted validation policies.
