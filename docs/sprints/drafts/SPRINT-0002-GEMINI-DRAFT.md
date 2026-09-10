# Sprint 0002: Day Pass sprint-review change requests

**Status:** draft
**Inputs:** `docs/sprints/drafts/SPRINT-0002-INTENT.md`, `docs/prd/Change_Requests_2026-09-10.md`, `docs/prd/Consolidated_PRD_v3.4.md` (specifically §4.5, §5, §5A), `docs/prd/day-pass-v1.2.html`.

## Overview
This sprint implements the Day Pass checkout change requests generated from the Sprint 0001 review against the Director of Design's HTML v1.2. It focuses on achieving visual and structural parity with v1.2, integrating Commerce Pay Page card capture, enforcing §4.5 consent documentation, saving cards to the prospect wallet, and building an automated test harness (simulated user agents and a visual parity loop).

Sprint 0001 will be closed, absorbing its pending G2 and G4 gates into this sprint. Changes will stack as additional commits on the existing `prospect-wallet/sprint-0001` branches, seamlessly updating the unmerged PRs (#96 and #524) to reflect final design-aligned logic.

## Use Cases
- **U1:** First-time buyer enters email, receives OTP inline. Address is completely masked and verification doesn't definitively leak existing identity until after the OTP is consumed.
- **U2:** Upon successful verification, buyer is presented with exact consent content (§4.5): waiver, pass terms, privacy notice. Toggling the "save card" switch updates the legal stored-card terms display.
- **U3:** First-time buyer enters payment through the embedded Pay Page (hosted fields, strictly no fallback `MockCardCapture` select list).
- **U4:** Returning buyer verifies via emailed OTP, sees a recognized user screen ("Welcome back"), and can pay with a previously stored card from their universal wallet.
- **U5:** Returning buyer disables "save card" toggle upon providing a new card, saving the pass transaction details but leaving their universal wallet unmutated for the subsequent transactions.
- **U6:** Tooling - Parity loop automatically renders UI states (first-time, returning, document modals) in 1440px and 375px headless Chrome, excluding Pay Page regions, and assertions verify structural copy and layout differences.
- **U7:** Tooling - Simulated agents drive complete E2E loops via a local OTP mail sink test route without triggering live datatrak/payment systems.

## Architecture

### Visual Parity and UI Adjustments
- **Design Baseline:** `docs/prd/day-pass-v1.2.html` is the strict source of truth for spacing, layout, fonts, and colors (reverting the priority of Riverside Demos from Sprint 0001).
- **Consent Location & Layout:** Move "I agree..." and the dynamic T&C blocks strictly into the right-hand `OrderSummary` panel alongside the Pay button. Main UI retains contact/payment details. 
- **Marketing Opt-In:** An independent, explicitly unchecked marketing opt-in variable is stored separately alongside the mandatory transactional SMS notice.
- **Inline Code Entry:** OTP verification is now an inline UI state that dynamically transforms the email collection screen. "Change" triggers `DELETE /identity` to clear pending verifications.

### T&C and Consent Schema (§4.5)
- **Consent Versioning:** `ClubCatalogPort` serves a versioned subset of documents: `waiver`, `passTerms`, `storedCard`, and `privacy`.
- **User Actions:** Acceptance explicitly recorded at `PUT /order`, mapping exact version strings and methods. Self-attestation of age + explicitly decoupled waiver consent.
- **Configuration:** Authored as templates, dynamically injected with club and product naming, always retaining the `PROPOSED` marker logic until legal sign-off.

### Payment Strategy (Hosted Pay Page Embed)
- The legacy dummy dropdown for card collection in mock mode is completely removed from buyer flows.
- Uses `@abc/pay-page-sdk` heavily mirroring standard membership online join (`PaymentPageWithPayPage.tsx`).
- Orchestrator relies on token polling sequence (`GET /api/pay-page/session/:id`) to verify the token before proceeding with `POST /purchases`.

### Identity, Verification (OTP), and Wallet Sync
- **Backend Identify Masking:** The `POST /checkouts/:id/identify` endpoint strictly queues the challenge. It returns a generic structure indicating required OTP without leaking new/returning status. 
- **Wallet Writes:** Writing tokenised cards utilizes `ICreateWalletCreditCard` to the prospect wallet payload. It safely aligns with universal-wallet rules identifying MEMBER strictly by UUID (externalId) without `PROSP` fallback or agreement-number assignment, effectively bypassing existing RCM sync duplication hazards via `#4` `dt_agreementNumber` missing handling (backend dedup fix required). 

## Implementation Plan

### Phase A — Core Form & Capture Alignment (UI + BFF)
- **UI:** Remove dummy `MockCardCapture`. Implement `@abc/pay-page-sdk` for `CardCaptureSlot.tsx`. Adjust `OrderSummary.tsx` to hold the Pay button and consent checkboxes.
- **BFF:** Enforce §4.5 consent variables traversing up to `/checkouts/:id/order`.
- **Files:** `UI/routes/ShortTermPass/components/CardCaptureSlot.tsx`, `UI/routes/ShortTermPass/components/OrderSummary.tsx`, `BFF/services/shortTermPass/order.ts`.

### Phase B — Inline Verification & Masking (UI + BFF)
- **BFF:** Update `POST /checkouts/:id/identify` to hide `newVisitor` or `recognized` outcome until the corresponding `POST /checkouts/:id/verify` action succeeds.
- **UI:** Refactor `VerifyStep` into an inline transition in `IdentifyStep`. Add "Change" functionality connected to `DELETE /checkouts/:id/identity`. Integrate the separate unchecked marketing opt-in.
- **Files:** `BFF/routes/shortTermPass/identify.ts`, `UI/routes/ShortTermPass/steps/IdentifyStep.tsx`.

### Phase C — Visual Parity Tooling (Test Harness)
- **Parity Loop:** Build the pixel & CSS/DOM difference tool wrapping puppeteer, generating reports at 1440/375px over local host and v1.2 HTML, ignoring explicitly marked layout exclusions (e.g., Pay Page iframe).
- **Files:** `tools/parityLoop.js` (NEW) inside the docs or planning repo.

### Phase D — Prospect Wallet Saves & Agent Testing (BFF)
- **BFF:** Validate Prospect owner creation via member `uuid` payload. Record versioned consent (stored card). 
- **Harness:** Expose `/api/test/otp-sink` outbox route strictly under mock modes for E2E simulations. Configure `claude -p` based workflow invoking end-to-end sandbox operations.
- **Files:** `BFF/services/shortTermPass/wallet.ts`, `BFF/testing/harness.ts`, `tools/agentSimulator.sh`.

## Files Summary
- **UI Modifications:** `IdentifyStep.tsx`, `OrderSummary.tsx`, `PayBar.tsx`, `CardCaptureSlot.tsx`, `TermsDialog.tsx`, `short-term-pass.scss`.
- **BFF Modifications:** `identify.ts`, `verify.ts`, `order.ts`, `purchaseOrchestrator.ts`, `catalog.ts`.
- **Tooling Additions:** `tools/parityLoop.js`, `tools/simulatedAgents/*`.

## Definition of Done
- **Code:** All change requests (CR-01 through CR-09) and process requests (PR-01 through PR-04) implemented.
- **Testing:** Visual parity loop shows zero unauthorized differences. E2E simulated user agents successfully drive complete mock-payments.
- **Documentation:** README/Indices, Readiness logs updated. CFs mapped to respective owners.
- **Closure:** Sprint 0001 status actively closed.

## Risks & Mitigations
- **B1 Missing Credentials:** Host card proof remains blocked if B1 (`PAY_PAGE_API_URL` env inputs) is not provided locally. **Mitigation:** Drive isolated tests targeting API structures until secrets are shared securely.
- **Semantic Wallet Deduplication:** Universal wallet backend lacks complete `PROSP` stability handling. **Mitigation:** Writes will be isolated behind `STP_WALLET_WRITES` to avoid production bleed prior to backend dedup resolution.
- **§4.5 Legal Content Approval:** Content remains unapproved (CF-02). **Mitigation:** Hardcode the fallback marker "PROPOSED" alongside all template text instances rendered per schema.

## Dependencies
- `@abc/pay-page-sdk` compatibility.
- Backend sprint fixing the `DEDUPL_ACCOUNT_<agreementNumber>` thrown error for missing agreement numbers in prospects.

## Open Questions
1. **Offer Card Handling:** Design v1.2 layout explicitly shows a designated "Gym Floor" $25 offer card component layout despite limiting combinations to one active offer. *Recommendation: implement the selector but permanently render it as solely selected to match layout.*
2. **Inline Code State Machine:** Should the state machine officially merge `identify` and `verify` states? *Recommendation: Maintain separate states internally within Redux for robust validation and tracking, but physically render both on the shared `IdentifyStep.tsx` screen based on `challenge` presence.*
3. **Consent Version Strings:** What constitutes a consent "version"? *Recommendation: Prioritize tracking version string values dictated by the catalog as it matches corporate policy. Fall back to SHA256 of the payload body for unversioned inputs.*
4. **Pay Page Embed Readiness:** How to handle initial rendering states before token acquisition? *Recommendation: Spin generic loaders over form slots until polling `GET /session/:id` provides token success.*
5. **OTP Leakage & Rate Limitations:** Where should the backend perform member lookups? *Recommendation: Execute member lookups post-verification internally; prior to OTP, validation acts solely on rate-limits independent of prospect status.*
6. **Agent & Parity Architectures:** *Recommendation: Reside tooling completely in a dedicated `tools/` directory, execute visual diff scripts ignoring explicit CSS blocks outlining the `iframe`, and utilize `claude -p` for simulation CLI iterations.*
7. **Branching Strategy:** *Recommendation: Absorb review changes dynamically to PR #96 and #524 under `prospect-wallet/sprint-0001` keeping the review loop unified vs stacked.*
8. **Transferring G2/G4:** *Recommendation: Explicitly mark Sprint 0001 "complete" and track G2/G4 solely within this sprint track to avoid disconnected status tracking.*
