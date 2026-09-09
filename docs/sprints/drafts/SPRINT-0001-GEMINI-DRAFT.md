# Sprint 0001 Draft: Day Pass single-flow checkout in Online Join (UI + BFF)

**Status:** draft (Gemini)
**Inputs:** `docs/sprints/drafts/SPRINT-0001-INTENT.md`, `docs/prd/day-pass.html`, `docs/SEMANTIC-INDEX.md`
**Chapter:** none

## Pyramid Index

- **L0:** Ship the prototype's Day Pass single-flow checkout in `online-join-ui` and `online-join-bff`. Identity and wallet resolution must use the Ignite member ID (`type=MEMBER`), avoiding any reliance on `PROSP` or placeholder agreement numbers. The legacy `mico` stack is not modified.
- **L1:**
  - **A — UI Flow & Design System:** Implement identify, recognized, new visitor, and done screens. Form factors include summary sidebar, terms gate, and inline one-time-code (OTP). Replicate the prototype's `dt-*` visual design as a productized mini-system.
  - **B — Server-side Adapters & BFF:** Scaffold endpoints in Koa (`lookup`, `otp`, `checkout`) supporting mock-responses until backend infrastructure arrives. Manage session binding securely without leaking state.
  - **C — Integration & Security:** Process payments solely via the `@abc/pay-page-sdk` (PCI isolation), and sequence new user flow as: auth payment -> persist prospect -> create wallet owner/entry.
- **L2:** Seed (prototype) · Context (code areas) · Constraints · Success Criteria · Open Questions. Detailed in subsequent sections.

## Overview

We are building a robust Day Pass checkout experience targeting a split stack (`online-join-ui` React app, `online-join-bff` Koa service). Based on a working prototype (`day-pass.html`), the system will collect email/phone, issue and verify a one-time code inline, fetch linked saved-cards (for recognized prospects), or gather profile data, payment info, and consent (for new prospects). 

All traffic flows through the BFF which isolates the frontend from downstream complexity as mockable, verifiable endpoints. We strictly adhere to the updated identity boundaries outlined in the Universal Wallet plan: prospects use Ignite member IDs (`MEMBER` type) and never carry a `PROSP` agreement number for identity or dedup logic.

## Use Cases

| ID | Title | Summary |
|----|-------|---------|
| UC1 | Known prospect checkout | Uses email/phone -> matches -> receives OTP -> verifies OTP via single-view -> displays mask of existing card -> accepts T&C -> completes payment securely. |
| UC2 | New prospect checkout | Uses email/phone -> no match -> inputs full name, optional second contact -> inputs card via Pay SDK iframe -> accepts T&C -> authorizes -> persisted as prospect -> wallet created. |
| UC3 | Change contact inline | Visitor can swap between phone or email for OTP delivery without losing session context prior to verification. |
| UC4 | T&C Gate | Terms checkout is a distinct checkbox required before `Pay` button becomes active. |

## Architecture

- **UI (`repos/online-join-ui`):** 
  - Standard React flow using Redux Toolkit slices (e.g. `dayPassSlice`)
  - The payment section strictly relies on `@abc/pay-page-sdk` logic via a hook integration `usePayPageSession`.
  - Design variables (`dt-*`/`--ig-*`) shipped as standalone SCSS tokens (or isolated MUI v4 overrides) protecting `GuestReviewPage` legacy code.
- **BFF (`repos/online-join-bff`):** 
  - `src/routes/dayPass` (analogous to `payPage` standard template) managing state routing securely.
  - New service abstractions for `Datatrak` (Prospects/POS) and `UniversalWallet` integrations since the upstream is non-existent/out of scope. An adapter strategy will toggle mock dependencies local to the BFF.
  - Identifiers mapped post-OTP flow stored in a `SESSION-ID` context, partitioned from general traffic.
  - Telemetry: LD flags toggle `/day-pass` accessibility locally, default false.

## Implementation Plan

### Phase 1: Foundational Scaffolding
- **UI:** Integrate SCSS vars (`--ig-*`) as CSS custom properties or mini-module. Setup Route `/signup/day-pass` and basic components (`Sidebar`, `FormFields`).
- **BFF:** Create robust route boilerplates at `/api/day-pass/*`, guarded by LD feature flags configured server-side.

### Phase 2: Mock Contracts & BFF API
- **BFF:** Setup `POST /api/day-pass/lookup`, `POST /api/day-pass/otp`, and `POST /api/day-pass/checkout`. 
- **Mock Interfaces:** Use `@abc/bff-toolkit/universalWallet` with mocked Axios responses mirroring standard `(externalId=memberUUID, type=MEMBER)` returns to facilitate UI unblocking. 

### Phase 3: Identity & OTP UI
- **UI:** Wire React components for Ident / Code Verification logic pointing to BFF. Handle state transition gracefully when OTP returns valid.

### Phase 4: Payment & Backend Orchestration
- **UI:** Integrate `@abc/pay-page-sdk` iframe securely for card intake.
- **BFF Orchestration:** Map new-visitor checkout: (1) Evaluate SDK payment tokens (2) Persist Prospect (`addProspect`) (3) Read member GUID (4) `POST /wallet-entry/credit-card`.

### Phase 5: CI & Security Parity
- **Both:** Ramp RTL/Jest tests ensuring `online-join-ui` (>=80%) and `online-join-bff` (>=84%) meet lines-of-code coverage. Prove Identity is enforced over UUID not PROSP `dt_agreementNumber`.

## Files Summary

| Repo | File | Action |
|---|---|---|
| online-join-ui | `src/common/constants.ts`, `src/App.tsx` | MODIFY: Top-level `/signup/day-pass` route |
| online-join-ui | `src/routes/DayPassPage/**` | NEW: Components for Identify, Checkout, Done |
| online-join-ui | `src/reducers/dayPassSlice.ts`, `src/services/dayPass.ts` | NEW: State mechanics |
| online-join-ui | `src/assets/styles/day-pass-tokens.scss` | NEW: UI token translations |
| online-join-bff | `src/routes/dayPass/index.ts` | NEW: Adapter API endpoints |
| online-join-bff | `src/services/dayPassProxy.ts`, `src/__mocks__/dayPass.ts` | NEW: Client / Mock adapters |

## Definition of Done

- **Mock Playability:** `GET /signup/day-pass?club=NNNNN` correctly exercises all workflows using static mock responses.
- **Security:** Pay Page SDK iframe handles all raw PAN data. No unmasked PAN enters `online-join-ui` state or the Koa BFF.
- **Dark Deploy:** Behind `onlineProspects` club settings + a LaunchDarkly toggled-flag context.
- **Contracts Asserted:** The API requests passed to `@abc/bff-toolkit/universalWallet` log member ID assertions ensuring no `PROSP` payload leaks.
- **Test Coverage:** Exceeds baseline limits (>80% UI / 84% BFF).

## Risks & Mitigations

- **R1 - OTP Abuse:** Email/Phone can be probed for registered status. *Mitigation:* BFF implements basic rate limits per IP and restricts attempt retries early within memory stores until scalable architecture is decided.
- **R2 - Sequential failures:** Wallet save fails after prospect is written. *Mitigation:* Explicitly handle retryable responses internally; user experience does not crash, rather card just avoids storing. 
- **R3 - Global styling conflicts:** Legacy interfaces break. *Mitigation:* Restrict `dt-*` css scopes tightly to `DayPassPage` roots.

## Dependencies

- **Platform:** Base `MICO` services referenced purely as API contract spec checks.
- **Internal Integration:** `@abc/pay-page-sdk` token resolution pathways functioning.
- **Review:** Approvals from UI architectures ensuring we don't duplicate existing `GuestReviewPage` functionality redundantly.

## Open Questions

1. **Backend Contract / Routing:** 
   * Does BFF proxy MICO (`/trial/submit`) or natively call Datatrak `/member/addProspect.spr` using `client-credentials` like `payPage`?
   * Does SMS infrastructure formally exist beyond `email-publisher-service`?
2. **Catalog / Products:** Are perks and daily prices statically mapped as configurations, extracted from online-join club models, or fetched via generic POS APIs (`/pos/saleItems.spr`)?
3. **Location mapping:** Do we map new top-level `/signup/day-pass`, or `/day-pass` strictly enforcing header divergence?
4. **Scoping Design Tokens:** Standardizing CSS encapsulation versus merging into robust `@abc/ui-configs` bundles.
5. **Session Model:** Persist `SESSION-ID` via JWT short-lived stores for repeat purchasers or fallback on `mico` behavior? 
6. **Multi-match Rules:** Resolving shared phone/emails if duplicated by older prospects on file. 
7. **Date pickers:** Will Mobile responsive require calendar changes over default web inputs?
