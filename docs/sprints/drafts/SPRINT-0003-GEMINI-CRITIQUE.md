# Sprint 0003 Draft Critique

## Claude Draft Evaluation
- **Architectural soundness:** High. Accurately proposes a dedicated `PUT /offer` API and models `validUntil` using calendar days on the order shell. The pass-view token uses a hashed storage approach, and pass email correctly diverges by transport (CID for SMTP, hosted image for Publisher).
- **Completeness:** Excellent. Fully covers CR-10 through CR-17, addressing UI component details (`.offers` radiogroup), copy changes, and updating the parity loop inputs without running it. It explicitly mentions the components and slice changes required.
- **Phasing/Ordering:** Strong. Organizes into sequential lanes (API/contract -> BFF -> UI) and specifically calls out a vertical slice goal early on (selection to mock purchase with updated receipt) before starting email/credential work.
- **Risk coverage:** Good. Correctly handles client/email constraints for QR codes (avoiding data URIs) and addresses some token security aspects (scoping, rate limiting).
- **Feasibility:** High. Directly references and understands the current codebase structures (React 17, `STP_NON_PRODUCTION`, Mailpit).
- **Definition of done:** Clear mapping of Use Cases to validation steps and an explicit vocabulary for what is considered local vs live vs deferred.

### Strongest Ideas
- Identifying that the publisher transport (`EmailEngineRequest`) has no attachment capability and cleanly planning a strategy split (CID vs hosted).
- Using a vertical slice delivery (contract -> offer choice/purchase -> email) so behavior can be seen early.
- Direct mapping of Use Cases to the test suite proofs.

### Weaknesses / Gaps
- Misses the deep concurrency/race condition implications of early offer selection (e.g., UI races between offer changes and order verify) and locking the purchase state.
- Token storage uses a generic hashed field on the purchase store rather than a distinct credential boundary. 

## Codex Draft Evaluation
- **Architectural soundness:** Very High. Highlights critical concurrency gaps in the current checkout (stale writes, atomic generation requirements) and properly isolates token capabilities by introducing a distinct `PassCredentialStorePort`.
- **Completeness:** Strong on backend and security boundaries. Handles the CRs, emphasizes keeping the Riverside single-product logic intact, and correctly maps out the public route chain (avoiding the cookie-bound `checkoutChain`). 
- **Phasing/Ordering:** Good. Also drives towards an early demonstrable slice (B1-B3 + D1-D3) to achieve end-to-end selection before the credential features.
- **Risk coverage:** Excellent. Outstanding attention paid to security, tracking abstraction, link lifecycle, bounds checking, and explicitly un-checking deferred gates.
- **Feasibility:** High. Highly rigorous in defining what gets run (e.g., removing `qrcode.react` from done, but not building data URI). 
- **Definition of done:** Very rigorous and formal. Sets separate T-gates so this sprint’s completion doesn't improperly overwrite prior pending gates.

### Strongest Ideas
- Identifying the need for atomic generation checks on all mutations so concurrent UI edits do not commit stale state prior to verification.
- Proposing a dedicated `PassCredentialStorePort` with an HMAC capability token, establishing a clear security boundary independent of the 30-min checkout session.
- Detailed public route pipeline security (no-store, tracking prevention, strict token limits).

### Weaknesses / Gaps
- Less detail given on the exact UI component and stylesheet breakdown compared to Claude. 
- Tone is quite cautious; could benefit from some of Claude's direct actionable checklists for the UI lane.

## Conclusion
Both drafts accurately observe codebase realities (e.g., `offerId` absence, publisher attachment limits). The final plan should adopt **Claude's UI mapping and email transport implementation details**, heavily reinforced by **Codex's concurrency architecture (generation checks) and token security abstraction (HMS capability token & isolated store)**.
