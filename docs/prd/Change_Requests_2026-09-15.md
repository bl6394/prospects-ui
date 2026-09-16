# Change Request List — Guest Day Pass Purchase (Design v4 and board review, 2026-09-15)

**Decision (user, 2026-09-15): `docs/prd/day-passv4.html` (Director of Design, 2026-09-10 16:36) supersedes `day-pass-v1.2.html` as the build's source of truth under D46.** Everything below is derived from the v1.2 → v4 diff, from the Design v2 alignment table on the Prospect Wallet Miro board (rows the 2026-09-10 review did not carry into the build), and from the Counsel Review Record actions. The Miro board itself carries no item newer than the 2026-09-10 Sprint Review Notes; the board's Consolidated PRD is still titled v3.3 (the repo's v3.4 is newer).

Numbering continues from `Change_Requests_2026-09-10.md` (CR-01…CR-09, PR-01…PR-04, CF-01…CF-03).

## A. Change requests (must change in the build)

| # | Change request | Area | Source | Notes |
|---|---|---|---|---|
| CR-10 | **Multiple pass products per club, selectable on the identify screen.** v4 shows three offer cards in a `radiogroup` "Choose a pass": 1-day pass $25, 3-day pass $60, 5-day pass $90 (Gym Floor, same perks). Selecting one updates the sidebar line item, total, Pass Terms and the Pay button amount, and toasts "{label} · ${price}". | Front end + backend | v4 diff (`PRODUCTS`, `offerCards`, `setProduct`) | Prices are marked "demo pricing — confirm" in the design. Catalog (`ClubCatalogPort.getOffers`) already returns a list with `durationDays`; the order shell must take the selected `offerId` (`PUT /order {offerId}` — the contract field exists, the UI never sent it). Riverside fixture gains 3-day and 5-day offers; Core South keeps Gym Floor 1/3/5. Consent revision changes when the offer changes (price and validity are in Pass Terms). |
| CR-11 | **Multi-day validity.** Date field label is "Day pass applies on" for a 1-day pass and **"Pass starts on"** otherwise; the help line, the sidebar "Valid" row, the pass block and the Pass Terms show a range "Today – Fri, Sep 12" (start = chosen day, end = start + days − 1). | Front end + backend | v4 `validityLabel()` | BFF: `order.visitDate` stays the start; add `validUntil` (club-local) derived from `offer.durationDays`; pass issuance and the receipt carry both dates. Sprint 0001 typed `durationDays` for this reason. |
| CR-12 | **Done page: QR moves out of the page into the email.** v4 removes the on-page `.qr` block. Pass block copy becomes "{label} · {validity}" and **"We emailed your pass and door QR code to {masked}. Show it at the door, or just say your name at the front desk."** | Front end + backend | v4 diff (`.qr` and `qr()` removed; done copy) + D41 | The pass email must carry the QR image (static, valid only in the pass window, bound to person + sale — D41) plus the receipt content. Today the pass email is plain text with pass id and receipt number and the QR only renders in the browser. Needs an image-capable email template (inline PNG/CID or hosted image) and the `qrPayload` rendered server-side. |
| CR-13 | **"View your pass" magic link on the done page, in the pass email and on the receipt** (D41, PRD FR-P22/P23; Design v2 alignment rows 8–9, never carried into the 2026-09-10 list). A signed link opens a web pass page that renders the rotating QR without app or login. | Front end + backend | Miro Design v2 alignment table rows 8, 9; Session Index §6 | New surface: `/signup/pass/:token` (or similar) rendering the pass with a rotating QR; link lifetime, resend path and admit interval are open engineering decisions (Session Index §6). Scope for Sprint 0003 can be the link + page with a static QR first, rotation behind a flag. |
| CR-14 | **Remove the "We'll text your pass here on the day" helper** under the mobile field; keep the transactional-SMS notice and the marketing opt-in (D37, D32b). Mobile input gets `inputmode="tel"` and `autocomplete="tel"`. | Front end | v4 diff (`second.help` removed; input attributes) + D41 | Pass delivery is by email; SMS is operational only. |
| CR-15 | **Offer-card and identify layout per v4:** `.offers` three-column grid (`repeat(3, minmax(0,1fr))`, gap s4, flex basis 560 px), card price 32 px, name at base size, new `.days` line ("1-day pass"), perks at small size with 22 px line height, 32 px icon; `.lead` flex basis 300 px; breakpoints: column layout under 1250 px with offers max-width 640 px, single-column offers under 640 px. | Front end | v4 CSS diff | Replaces the single 260 px card of v1.2. Parity element list and approved deltas must be regenerated from v4. |
| CR-16 | **Fixture:** returning-visitor first name is **Kelly** Reyes in v4 (`m@m.com`). | Fixtures | v4 diff | Update the Core `m@m.com` twin used by the parity loop; Riverside Jordan unchanged. |
| CR-17 | **Pass Terms template** reads "{label} to {Club}, valid {validity}" (label "1-day pass" / "3-day pass" / "5-day pass"; validity per CR-11). | Backend | v4 `DOCS.terms` | `consentTemplates.ts`; template version bump; PRD refund sentence stays (D15/D22). |

## B. Process and test-harness requests

| # | Request | Notes |
|---|---|---|
| PR-05 | Re-baseline the (deferred) parity loop on v4: element list, approved deltas, the eleven states plus one per additional offer selected. | The harness lane is still deferred by the user; when it starts, v4 is the reference, not v1.2. |
| PR-06 | Pass email rendering check: the QR image renders in the Mailpit inbox and the "View your pass" link resolves locally. | Extends the SMTP lane smoke. |

## C. Confirmations needed

| # | Item | Owner |
|---|---|---|
| CF-04 | Multi-day pricing (3-day $60, 5-day $90 are "demo pricing — confirm") and which clubs sell which durations; catalog source per club. | PM / PRODUCT |
| CF-05 | Pass window semantics for multi-day: consecutive calendar days from the start date (v4 assumes this); FR-P6 calendar-day vs elapsed-hours; maximum length (Q19). | PM |
| CF-06 | View-your-pass link lifetime, resend path, static-QR admit interval and anomaly thresholds (Session Index §6). | Engineering + PM |
| CF-07 | QR in email: static QR bound to person + sale, or link-only per club setting (D41 "club may set link-only"). | PM |

## D. Already satisfied or closable from the board review

- Counsel action **(e)** "confirm feasibility and effort of per-tier / per-club versioned consent templates (REQ-CONSENT-TEMPLATES)": satisfied by Sprint 0002's `ConsentDocumentSet` (per-tier documents, per-club overrides, template versions, rendered hashes, consent revision) — report to PM/Legal as done.
- Design v2 alignment rows 1–7, 10–13 (email-only OTP, mobile required, 18+ and waiver checkboxes in the sidebar, matched Pay sentence, Pay Page capture, country list from the Pay Page, PRD refund copy, save default off, waiver "Agree and close", marketing opt-in, masked mobile on the recognised lane) are all in the Sprint 0002 build.
- CF-01…CF-03 from 2026-09-10 remain open with PM / Legal.

## E. Inputs

1. `docs/prd/day-passv4.html` — source of truth (have; committed 2026-09-15).
2. Confirmed multi-day pricing and catalog per club — missing (CF-04).
3. QR-capable pass email template (design) — missing; no design file yet for the pass/receipt email.
4. View-your-pass page design — missing (D41 describes behaviour, no mock-up on the board).
5. Pay Page dev credentials — still missing (B1; unchanged since 2026-09-10).
