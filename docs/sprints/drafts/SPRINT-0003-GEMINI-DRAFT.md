# Sprint 0003: Design v4 — multi-day passes, pass credential by email, and "View your pass"

**Status:** Drafted 
**Inputs:** `docs/sprints/drafts/SPRINT-0003-INTENT.md`, `docs/prd/Change_Requests_2026-09-15.md` (CR-10 to CR-17), `docs/prd/day-passv4.html` (D46 source of truth).
**Path conventions:** `UI/` = `repos/online-join-ui/src/`, `BFF/` = `repos/online-join-bff/src/`.

## Pyramid Index

- **L0:** Move the Day Pass build from Design v1.2 to v4 — selectable 1/3/5-day products with range validity, the QR and receipt delivered by email instead of on the done page, and a login-free "View your pass" link and page — with the contract, consent templates, fixtures and copy updated and the deferred harness re-baselined on v4.
- **L1:**
  - **A — Catalog and selection (CR-10):** Multi-day products in catalog; `PUT /checkouts/:id/offer` to select offer before order creation; dynamic `durationDays`.
  - **B — Order and validity (CR-11, CR-17):** `validUntil` computation based on `durationDays`; Pass Terms templates updated; sidebar date ranges.
  - **C — Credential delivery (CR-12):** Server-side QR rendering; inline email images; receipt moving to email; v4 Done page copy without inline QR.
  - **D — View your pass (CR-13):** Stateless tokenized access; signed token generation; a new unauthenticated BFF endpoint and UI route to view the digital pass.
  - **E — Parity and Proof (CR-14, CR-15, CR-16):** Parity loop re-baselined on v4 (deferred execution); Core fixture updated to Kelly; UI grid modifications; removal of text helper.

## Overview

Sprint 0003 upgrades the single-flow Day Pass checkout to follow Design v4. The key architectural shifts are introducing multi-day pass selections on the initial screen, decoupling the pass credential (QR code) from the checkout completion page to improve security and utility, delivering it via a designed email alongside the receipt, and adding a token-based, login-free digital "View your pass" surface to retrieve the credential later.

## Use Cases

| ID | Behaviour and required result |
|---|---|
| U1 | **Offer Selection:** Identify screen displays a grid of available passes (e.g., 1-day, 3-day, 5-day). Changing selection updates the selected state and sets the chosen offer for the checkout session. |
| U2 | **Validity Ranges:** When a multi-day pass is selected, the sidebar and Pass Terms show the full validity range (e.g., "Today – Fri, Sep 12"). |
| U3 | **Done Page Update:** On successful payment, the Done page shows v4 copy. The QR code and on-page receipt are absent. It conveys that the pass and receipt were emailed. |
| U4 | **Enhanced Email Delivery:** The email delivered post-purchase contains the receipt details and embeds a scannable QR code directly in the email body, along with a "View your pass" link. |
| U5 | **View Your Pass Magic Link:** Clicking the "View your pass" link opens a web page showing the pass details and QR code without requiring a user login or checkout session. |
| U6 | **Token Expiry/Revocation:** If the pass validity window plus grace period has expired, the "View your pass" link displays an expired state and refuses to render the QR code. |
| U7 | **UI Adjustments:** The mobile input text helper "We'll text your pass here on the day." is removed. The layout updates to the 3-column `.offers` grid. |

## Architecture

### Offer Selection API
In v4, offer selection occurs on the `identify` screen before an `order` exists.
- `POST /checkouts` will return an array of `offers` and a `defaultOfferId` from the catalog.
- A new endpoint `PUT /checkouts/:id/offer {offerId}` will store the chosen offer in `CheckoutStore` before verify occurs.
- On `verify` or `newVisitor`, the created order shell incorporates the chosen offer details (price, duration).
- If the user changes an offer mid-flow (after order creation), `PUT /order` will accept an `offerId` to replace the selection, re-triggering consent invalidation.

### Validity Model
`validUntil` is computed as `visitDate + durationDays - 1` (inclusive club-local calendar days).
- It lives in `OrderSummary` for UI rendering and in `IssuedPass` upon generation.
- Pass Terms template logic will evaluate `validUntil` to produce ranges when `durationDays > 1` (e.g., "valid Today – Fri, Sep 12").

### View Your Pass Token and Page
- **Token Format:** A JWT-like signed token using `STP_SESSION_SECRET` (or a dedicated pass secret). Payload: `{passId, visitDate, durationDays, clubNumber, maskedEmail, iat, exp}`.
- **Lifetime:** `visitDate + durationDays + 1 day` grace period to ensure validity across timezone boundaries without revealing PII if leaked late.
- **BFF Route:** `GET /api/short-term-pass/passes/:token` validates the signature and expiry, returning sanitized pass details and the static QR payload.
- **UI Route:** mounted at `/signup/pass/:token` outside `isShortTermPassRoute` checkout constraints, fetching the standalone data. No session required.

### Credential Delivery in Email
- **Server-Side QR:** The BFF will generate a PNG data URI for the QR payload using a Node library (`qrcode`).
- **Transport Handling:**
  - *Nodemailer/SMTP:* Employs `cid` attachments mapped to inline `<img>` tags.
  - *Publisher:* the data URI will be passed directly in the base64 HTML if the provider accepts it, or we rely on a securely signed public BFF route that returns the image buffer (decision bound in Open Questions).

## Implementation Plan

### Phase A: Contract and Store Updates
- **Tasks:** Freeze contract v3 (multi-day schemas, `passes/:token` route). Update `CheckoutStore` to hold `selectedOfferId`. Implement `PUT /checkouts/:id/offer` and modify `PUT /order`.
- **Files:** `BFF/routes/shortTermPass/schemas.ts`, `BFF/services/shortTermPass/ports/checkoutStore.ts`, `BFF/services/shortTermPass/order.ts`, `docs/contracts/short-term-pass-bff.md`.

### Phase B: Multi-Day Logistics and UI Parity
- **Tasks:** Update fixture catalogs for Core (1, 3, 5-day). Calculate `validUntil` in BFF and expose to templates. Update UI IdentifyStep to render `.offers` grid. Remove text helper from Mobile input. Set Kelly fixture.
- **Files:** `BFF/services/shortTermPass/fixtures/catalog.ts`, `BFF/services/shortTermPass/fixtures/consentTemplates.ts`, `UI/routes/ShortTermPass/steps/IdentifyStep.tsx`, `UI/routes/ShortTermPass/components/OrderSummary.tsx`.

### Phase C: Done Page and Credential Tokenization
- **Tasks:** Update `DoneStep` to remove QR and use v4 copy. Generate signed tokens on `issue`. Create `GET /api/short-term-pass/passes/:token`. Implement `/signup/pass/:token` UI.
- **Files:** `BFF/services/shortTermPass/ports/passSale.ts`, `BFF/routes/shortTermPass/passes.ts`, `UI/routes/ShortTermPass/steps/DoneStep.tsx`, `UI/routes/SignupShell.tsx`, `UI/routes/ShortTermPass/PassViewerPage.tsx`.

### Phase D: Email Template with Inline QR
- **Tasks:** Implement server-side QR generation. Incorporate receipt layout and "View your pass" link into the email template. Update adapters to mount the inline QR payload.
- **Files:** `BFF/services/shortTermPass/ports/delivery.ts`, `BFF/services/shortTermPass/adapters/smtp/mailer.ts`, `BFF/services/shortTermPass/adapters/smtp/templates/passEmail.ts`.

### Phase E: Harness Re-baselining
- **Tasks:** Produce generated UI deltas based on v4. Output Core/Kelly state snapshots without running the full test agents. Update `approved-deltas.json` and element selectors.
- **Files:** `TOOLS/parity/elements.json`, `TOOLS/parity/approved-deltas.json`.

## Files Summary
- Consolidates updates across `BFF/routes`, `BFF/services/shortTermPass`, `BFF/adapters`, and `UI/routes/ShortTermPass/*`.
- Modifies fixtures and test scaffolding mappings without kicking off the parity loop runners.

## Definition of Done
- Multi-day pass selection functionally populates `PUT /order`.
- Validity logic correctly impacts the order summary and consent verbiage.
- The v4 done page copy matches the prototype accurately.
- Pass email receives a successful local Mailpit render with inline QR and valid "View your pass" link.
- Independent `/signup/pass/:token` route displays the credential outside checkout loops.
- All testing paths, type checking, and unit thresholds pass.
- B1/S5 states remain accurately documented (transferred/not verified).

## Risks & Mitigations
- **Email inline image stripping:** Mitigated by relying on robust CID inclusion in standard SMTP and confirming capability for the Publisher path; providing the magic link acts as a reliable fallback.
- **Stateless token security:** We will restrict the data within the JWT payload to just the masked identity and pass data to prevent PII leakage. The token must be explicitly signed with short expiration.
- **Multi-day API shifts:** Overwriting offer ID requires flushing out invalid consent caches. BFF will be strict on requiring explicit user consent re-approval upon offer swaps.

## Dependencies
- SMTP/Mailpit for local testing of email rendering.
- `STP_NON_PRODUCTION` flags to ensure test payloads simulate safe paths.
- Standby action on the deferred parity/agent loop.

## Open Questions

1. **Offer selection API:** Extends `PUT /order` for in-flight changes, but utilizes `PUT /checkouts/:id/offer` for early pre-verify identification. `POST /checkouts` to return `offers[]`.
2. **Validity model:** Computations strictly reside in the BFF and persist inside `IssuedPass`. `validUntil` ranges are embedded in both consent document templates and response objects.
3. **Pass email content and QR:** Base64 URI is preferred if email clients / publisher allow it, otherwise standard CID attachments. The initial rollout will stay with static QR payload (`CF-07`) until the desk rotation scanner operates. 
4. **"View your pass" token and page:** Simple HMAC signed token stored temporarily or generated purely statelessly with standard JSON web token design. The route will be `/signup/pass/:token`.
5. **Done page and receipt:** Match v4 exactly. Place the "View your pass" trigger visually prominent in the email rather than standardizing it on the temporary Done pane.
6. **Multi-day pricing and catalog:** Core fixtures hardcoded per requirements, tagged `provisional: true`.
7. **Mobile field:** Retain SMS transactional notice but drop the original predictive pass helper text.
8. **Parity re-baseline (PR-05):** We will freeze the v4 states into JSON mapping resources. Run iteration disabled.
9. **Sequencing and lanes:** Parallel UI and BFF as Sprint 2. Prioritize Offer Selection -> Mail Delivery -> Token Page.
10. **Branching:** Recommend branching a new `prospect-wallet/sprint-0003` to cleanly separate these v4 changes from the already dense sprint-0001 branch lineage.
