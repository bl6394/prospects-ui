# Sprint 0004: Guest Pass v1 — Catalog Integration, Standalone URL, and Direct DataTrak Connectivity

**Status:** Draft; prepared centrally.
**Inputs:** `docs/prd/Consolidated_PRD_v3.6.md`, `docs/prd/Change_Requests_2026-09-10_v3.md`, `docs/prd/Next_Steps_2026-09-10_v2.md`, `docs/prd/day-passv6.html`, `docs/sprints/drafts/SPRINT-0004-INTENT.md`.

## Pyramid Index

- **L0:** Re-aim the Day Pass build at the Round 5–7 product — a standalone Guest Pass URL selling catalog-flagged single-visit passes read from DataTrak, with begin-on-purchase validity, DT-rendered QR by email, legal opt-in, and create→pay→deactivate — while deciding what of Sprint 0003 is kept, hidden or removed.
- **L1:**
  - **Home and repo decision:** We will serve the existing `online-join-ui` / `online-join-bff` React+Koa stack at a new standalone host/path with its own flag, rather than porting to `mico`.
  - **Catalog and DT configuration:** Flagged products (Guest pass online) carry contract days and visits, retrieved via a small MICO endpoint (to avoid direct Oracle connection from BFF).
  - **Prospect create and purchase order:** Begin = today, expiration = today + days - 1. Purchase order: create → pay → deactivate. Save card only on success.
  - **Page changes (Design v6):** Remove date picker, add "You have X days from purchase", add opt-in modal, remove 18+ checkbox, update success copy. Turn off the View your pass page.
  - **Proof and pilot readiness:** Update demo, scanner gates, webhook verifications.
- **L2:** §Overview · §Use Cases · §Architecture · §Implementation Plan (A–E, phases) · §Files Summary · §Definition of Done · §Risks & Mitigations · §Dependencies · §Open Questions.

## Overview

Sprint 0003 built multi-day support, a date picker, and an independent pass view page. Rounds 5–7 heavily pivot this product into a simpler v1: **Guest Pass as a standalone flow selling a single-visit pass configured directly on the DataTrak catalog item.** The pass begins on the date of purchase (date picker removed). The buyer gets a static QR code rendered by DataTrak via email (BFF QR generation and the View page are shelved). The flow is now structured as create-prospect → attempt-payment → deactivate-on-failure.

**What is kept, hidden, or removed:**
- **Kept (but adjusted):** The multi-offer grid layout (Design v6 keeps it, but v1 ships one single-visit item), email OTP (already CISO-approved), Pay Page embed.
- **Hidden / configured off:** Multi-day validity logic (tabled for v2), `PASS-VIEW-PAGE` and BFF credential generation + rotation. The routes will be hidden behind a `STP_QR_V2_ENABLED` configuration.
- **Removed:** The start-date picker, the 18+ checkbox, and the "View your pass" links from the thank-you page. 

## Use Cases

| ID | Description |
|---|---|
| U1 | **Identify and Selection:** Buyer sees available Guest Passes (v1: 1 pass) via DT catalog. Multi-offer layout stays intact but populated with 1 item. |
| U2 | **Summary & Validity:** Buyer sees "Valid: One time use only, valid for 30 days — use by {expiration}" based on contract days from DT, instead of picking a day. |
| U3 | **Opt-in & Consents:** Buyer sees the legal marketing SMS opt-in checkbox and modal (optional). 18+ checkbox is gone. |
| U4 | **Purchase Order:** Buyer attempts purchase. BFF checks out, calls DT to create prospect. Payment is authorized. If successful, card saved to wallet and pass issued. If failed, BFF calls DT to deactivate prospect. |
| U5 | **Done Page:** Success page shows "Check your email — we've sent your QR access code" without exposing the QR code logic. |

## Architecture

### 1. Home and Repo
Although the intent considered forking off Myko, **we will serve the existing React+Koa stack at a new standalone host/path (e.g., `guestpass.abcfitness.com`)**. 
*Cost of alternative:* Forking an entirely new UI/BFF inside the Myko monolith would abandon weeks of Sprint 1-3 progress (OTP, Identity, Wallets, Pay Page embed) and delay pilot by a month. Using our current stack and adjusting DNS/Cloudflare gives us a standalone page immediately while moving toward the "new OJ" vision.

### 2. Catalog and DT configuration
**Direct Oracle vs. Enterprise Endpoint:** We will use **an endpoint on MICO** to read DT configuration (flagged products). 
*Cost of alternative:* Adding Oracle drivers (`node-oracledb`), maintaining production DT credentials in the BFF, and negotiating new VPC peerings for the BFF would block this sprint. MICO already has safe read access to DT. 

### 3. Purchase Order (Create → Pay → Deactivate)
The workflow changes to:
1. `validate` purchase details
2. `prospect` creation in DT (returns barcode and member id)
3. `authorize` card
4. If `authorize` fails: `deactivate` prospect in DT, return 400.
5. If `authorize` succeeds: `save_card` to wallet, `sale`, `issue`, `deliver`.

### 4. Page changes
Design v6:
- Drop `.dayfield` date picker.
- Add "valid for X days" and "use by {Date}".
- Pass marketing opt-in flag to DT create prospect.

## Implementation Plan

### Phase A: Architecture & Contract Refuse (~2 days)
1. **Contract v4**: Update API shapes to remove `visitDate`/`validUntil` and replace with `contractDays`/`visits`. Add `marketingOptIn` boolean.
2. **Fixture Updates**: Update mock adapters (`catalog`, `directory`) to source the new DT product payload shape (contract days, visits).

### Phase B: BFF Lane (~4 days)
1. **Purchase Orchestrator**: Implement `create-pay-deactivate` logic. Guarantee idempotent recovery of deactivations. Rate limit endpoints heavily.
2. **DT Read MICO Adapter**: Setup the API client to fetch the flagged catalog items from MICO.
3. **Pass Credential & QR Retirement**: Shelf the `PassView` and token minting endpoints behind a Feature Flag (`STP_V2_CREDENTIALS`).
4. **Email Adjustments**: Ensure OTP template injects the correct club context and variables. (Wait on Chancy's template).

### Phase C: UI Lane (~3 days)
1. **Date Picker Removal**: Drop the `<input type="date">` for the pass start date. Start date is automatically `today`. Use `format.ts` to show "valid for N days". 
2. **Opt-in Modal & 18+**: Remove the 18+ checkbox. Add the marketing checkbox triggering a modal for the legal disclosures.
3. **Success Page**: Revise the `PassBlock` to strip QR code rendering and the "View your pass" links, replacing it with the new v6 text.
4. **OTP Keypad**: Add `inputmode="numeric"` to the OTP verification input.

### Phase D: Orchestrator Proof & Pilot Readiness (~2 days)
1. **Traceability**: Update Cypress/Selenium smoke flows.
2. **Webhooks Check**: Ensure that deactivating a prospect cleanly zeroes out downstream CRM states. 
3. **Scanner Test**: Verify emailed mock barcode scans on the desk test devices.

## Files Summary

- **MODIFY** `docs/contracts/short-term-pass-bff.md` (v4 additions)
- **MODIFY** `online-join-ui/src/routes/ShortTermPass/components/OrderSummary.tsx`
- **MODIFY** `online-join-ui/src/routes/ShortTermPass/components/PassBlock.tsx`
- **MODIFY** `online-join-bff/src/services/shortTermPass/purchaseOrchestrator.ts`
- **MODIFY** `online-join-bff/src/services/shortTermPass/ports/prospect.ts`

## Definition of Done

- Contract v4 implemented.
- UI passes v6 design checks (no Date picker, no 18+, numeric OTP, correct messaging).
- Purchase flow executes Create → Pay (success) or Deactivate (fail).
- Deferred features correctly hidden via feature toggles, keeping `main` clean.
- Gated checks for scanner, Webhooks, and Cloudflare rules finalized.

## Risks & Mitigations

- **Risk:** Create-then-deactivate leaves "ghost" prospects if the process crashes during deactivate.
- **Mitigation:** Background idempotency sweep in the BFF to retry deactivations for stalled purchases.
- **Risk:** Legal issues with opt-in content in a modal vs inline.
- **Mitigation:** Build the modal, but make it easily convertible to inline text via CSS/Flag if Twilio pushes back.

## Dependencies

- **Chancy (DT):** DT PR, catalog item flags, HTML OTP template.
- **PK (Ops):** Deactivation webhook confirmation. 
- **Kelly (Legal):** Approval for the opt-in modal and 18+ removal.

## Open Questions
1. **Reconciliation:** We are keeping the Sprint 0003 multi-day rendering components but forcing them to read `1 visit` and fixing the date to the purchase date for v1. The `View your pass` and BFF QR logic will be feature-flagged off but NOT deleted, preserving them for v2.
2. **Home and repo:** React/Koa stack re-hosted behind a new Cloudflare URL is significantly faster and less risky than porting logic to Myko/Java. Highly recommend staying in `online-join-ui/bff`.
3. **DT read path:** Instead of opening Node-to-Oracle connections which introduces security/network delays, we should rely on a MICO (`/iclub`) endpoint mapping to supply the DT configuration as MICO already has the Oracle link established.

