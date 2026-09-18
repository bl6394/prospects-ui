# Change Request List v3 — Guest Pass Online (2026-09-10, after the afternoon session)

Source: v2 of this list plus the afternoon working session on 2026-09-10 (Kelly Card, Bjorn, Mark; Chancy Toombs; Kyle Childers; Anil Joseph and Jag Wander; Mike West; PK). Decisions D59–D69 in Consolidated PRD v3.6 (Round 6, §4.6 rewritten), plus the evening follow-up D70–D74 (Round 7: product not service, no date picker, single-visit first). Board copy of the sprint review: https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683338149349

Owners: **Bjorn** — Guest Pass page and OTP; **Mark** — BFF, API package, page design; **Chancy** — DataTrak (catalog item, club settings, prospect email, OTP email template); **PK** — DT PR review, Cloudflare, future dynamic-link app; **Terry Smith** — DBA; **Kelly** — decisions, legal, escalation. Numbers carry over from v2; cancelled and reversed items are kept and marked so nobody rebuilds them.

Goal: Prospect Wallet API package to production today behind a flag. Guest Pass live as soon as the catalog-item columns and the DT PR land — "tonight at the latest."

## A. Guest Pass page (Bjorn; design Mark)

| # | Change request | Decision | Status | Notes |
|---|---|---|---|---|
| CR-01 | Consent control and Pay in the right-hand Order Summary panel | D42 | In progress | |
| CR-02 | §4.5 terms in the T\&C modal | D43 | In progress | Content still PROPOSED. |
| CR-04 | No saved-card dropdown for a first-time buyer | D44 | In progress | |
| CR-07 | Remove generator explanatory text | D46 | Confirm in build | |
| CR-08 | Visual parity with HTML v1.2 | D46 | In progress | Mark has a new revision with pass options. |
| CR-09 **revised** | Marketing/SMS opt-in: the **legal-written single checkbox** used on the trial guest-pass page; long text in a **mobile-friendly modal**; value passed on the create call checked or not | D67 | To do | Chancy posted the language in chat. Kelly takes the mockup to legal. |
| CR-13 | Numeric keyboard on the OTP field | D54 | To do | |
| CR-14 **revised** | Returning lane: Pass Terms and waiver every purchase | D53 | To do | "Not re-asked 18+" dropped — there is no 18+ (CR-26). |
| CR-15 | Returning lane: expired card on file → different card via the Pay Page | D53 | To do | |
| CR-16 | ~~Thank-you page shows the QR~~ | D63 | **Cancelled** | Replaced by CR-25. |
| CR-22 | ~~Keep the 18+ checkbox~~ | D66 | **Reversed** | Replaced by CR-26. |
| CR-25 **new** | Success page says "We've emailed your QR code for club access" — no QR rendered; remove the code/QR from the prototype's last page | D63 | To do | |
| CR-26 **new** | **Remove the 18+ checkbox** | D66 | To do | Minimum age later via the M\&O setting. |
| CR-27 **new** | **Standalone Guest Pass URL** forked off Myko, not Online Join; confirm which repo the code lives in (Myko vs OJ) | D60 | To do — repo home to confirm | Club site gets a "Buy a day pass" button. |
| CR-28 **revised** | Page lists every catalog item flagged "Guest pass online" with real prices; v1 configured and tested with **one single-visit day pass** | D61 / D68 / D72 | Design done (Mark); build to do | Multi-day tabled. |
| CR-35 **new** | **Remove the start-date picker.** Show "You have X days to use this pass" with X read from the item's contract days in M\&O — not hard-coded | D71 | To do — Chancy tracking down Mark for the UI change | Pass starts on purchase. |
| CR-29 **new** | OTP email: send from Chancy's HTML template with the code injected; club name only | D59 | To do (template from Chancy) | Bjorn asked for the template; Chancy sending HTML. |
| CR-30 **new** | 5-minute timer on the OTP page | D59 | Done | |
| CR-31 **new** | Read flagged items, days/visits, prospect terms and waiver language directly from the DT database (like Myko); no enterprise-API change | D64 | To do | Chancy's guidance. |

## B. BFF / API package (Mark)

| # | Change request | Decision | Status | Notes |
|---|---|---|---|---|
| CR-03 | Pay Page embed as membership online join does | D44 | In progress | |
| CR-05 | Email OTP for both lanes | D35 / D59 | **Done — working; CISO (Azim) approved** | |
| CR-06 **revised** | Save-card writes the token to the prospect wallet **only on a successful auth** | D45 / D65 | In progress | |
| CR-10 | Build email OTP in the BFF (6 digits, 5 min, 2 sends/hour) | D58 / D59 | **Done** | Resend timer / change-email UI still to confirm. |
| CR-11 | ~~Barcode → QR renderer in the BFF~~ | D63 | **Cancelled** | DT is the sole renderer. |
| CR-12 **revised** | Prospect create/update call sends **begin date = today, expiration = today + contract days − 1, number of visits** (from the item; 1 in v1), the **opt-in value**, the item, and the wallet token; no future begin date; club default prospect settings untouched; returning buyer's record repainted | D62 / D67 / D71 / D72 | To do | |
| CR-23 | API package (OTP, email service, wallet) behind a flag to production today | D55 | In progress | |
| CR-32 **new** | Payment failure, v1: create prospect → attempt payment → **deactivate on failure**; make sure the deactivate goes through the same webhooks as the create; log attempts (no records); Cloudflare rate limiting as on OJ | D65 | To do | "Do stupid now, fix later" — PK. v2 removes the pre-payment record. |

## C. DataTrak (Chancy)

| # | Change request | Decision | Status | Notes |
|---|---|---|---|---|
| CR-17 **revised** | Club settings → Online: **waiver (liability) language** text field beside the existing prospect terms. ~~Club item for prospect day pass~~ removed. | D50 / D61 | Waiver field done; item field removed | Never requested from the DBA. |
| CR-18 **revised** | Oracle columns now on the **catalog-item table**: guest-pass-online flag, contract days, number of visits | D61 / D69 | **DBA ticket to raise with Terry Smith** | Night deployment if common-use. Tonight at the latest. |
| CR-19 **revised** | Prospect email type: static QR of the barcode (engagement team's library, replacing ZXing), pass date, every non-null terms/waiver/opt-in field; **no 18+ line**; links allowed | D52 / D63 / D66 / D69 | In progress | |
| CR-20 | LaunchDarkly flag; off = existing behaviour | D50 / D55 | To do | |
| CR-21 **revised** | Enablement guidance: flag a product, set contract days and visits (v1: 1 and 1) (PRD §4.6) | D61 / D70 / D72 | Documentation | |
| CR-24 | POS receipt email continues; pass email subject unmistakable | D52 | To do | |
| CR-33 **revised** | **Catalog item flag "Guest pass online"** (working name) on **products** that opens **contract days** and **number of visits** | D61 / D70 | PR in progress (Cursor) → PK review; fields finalised with Terry at 7 pm | Product so unused passes are not liabilities. |
| CR-34 **new** | Send Bjorn the OTP email HTML template | D59 | To do (today) | |

## D. Process and test-harness requests

| # | Request | Decision | Owner | Status / notes |
|---|---|---|---|---|
| PR-01 | Visual-parity loop against HTML v1.2 | D46 | Bjorn | Running. |
| PR-02 | Simulated-user agents end to end | D47 | Mark | Needs PR-03, CR-03. |
| PR-03 | OTP mail sink | D47 | Mark | |
| PR-04 | Sandbox cards; no real cards or live charges | D47 | Mark | |
| PR-05 **revised** | DBA ticket for the catalog-item columns, escalated under Kelly's name | D69 | Chancy → Terry Smith | Terry to classify the table. |
| PR-06 **revised** | Desk-scanner test: the emailed QR admits on the pass day and is refused after expiration or once visits are used | D62 / D63 | Chancy + Mark | Before pilot. |
| PR-07 | Maintenance-server check | D48 | Chancy | |
| PR-08 | Product-marketing hand-off | D55 | Chancy | Add the three-button club-site story (trial / join / day pass). |
| PR-09 | Reporting and insights requirements | D57 | TBD | Parked. |
| PR-10 **new** | Bjorn sends Jira epics/tickets to Chancy; DT stories filed under them | D69 | Bjorn → Chancy | Tickets referenced from the Miro board and PRD. |
| PR-11 **new** | Chancy's DT PR to PK for code review | D69 | Chancy → PK | |
| PR-12 **new** | Mockup of the opt-in modal to legal; test Twilio's position | D67 | Kelly | "Let them tell us no." |
| PR-13 **new** | PK confirms whether any legal or payment-ops rule requires the pre-payment record | D65 | PK | Input to v2. |
| PR-14 **new** | Webhook propagation check: deactivate reaches every CRM the create reached | D65 | Chancy + Kyle | Before enabling a club. |
| PR-15 **new** | Test whether M\&O accepts a prospect with a future begin/end range | D74 | Chancy | Decides whether a picker can ever return. |
| PR-16 **new** | Check whether DT alerts or refuses a check-in before the begin date | D74 | Chancy | |
| PR-17 **new** | Reconvene with Terry Smith at 7 pm to finalise fields and tables | D74 | Chancy | |

## E. Confirmations needed (no build change yet)

| # | Item | Decision | Owner |
|---|---|---|---|
| CF-01 | Counsel: right-panel consent placement conspicuous | D42 | Kelly |
| CF-02 | Counsel approves T\&C content | D43 / §4.5 | Kelly + Legal |
| CF-03 | Owner for the OTP mail sink and test cards | D47 | Kelly (→ Mark) |
| CF-04 | Counsel: acknowledgement text in the prospect email sufficient | D52 | Kelly + Legal |
| CF-05 | Deferrals: waiver once-per-club with version re-sign; multi-day passes now configurable but one item shipped | D53 / D61 | Kelly — rotating QR deferral confirmed |
| CF-06 | ~~QR generator source~~ Closed: engagement team's library, DT only | D63 / D69 | — |
| CF-07 | ~~OTP sender~~ Closed by D58/D59 | — | — |
| CF-08 **new** | Counsel: waiver enforceability with no 18+ gate | D66 / D40 | Kelly + Legal |
| CF-09 **new** | Legal and Twilio: opt-in text in a modal | D67 | Kelly |
| CF-10 **new** | PK: no rule behind create-then-deactivate | D65 | PK |
| CF-11 **new** | Repo home for the Guest Pass page | D60 | Bjorn |
| CF-12 | ~~Service or product~~ Closed by D70: product | D70 | — |

## F. Confirmed correct — no change

- Phone removed as an authentication method (D35).
- ~~Date selector~~ **withdrawn (D71)** — no picker; the pass starts on purchase.
- "Welcome back" lane; record repainted with new dates and visits (D53, D62).
- Position of "Save this card for next time".
- Check-in already enforces prospect dates and visits (D62) — nothing at the door.
- All ABC scanners read a plain barcode QR (D63, Anil) — no dynamic QR needed for v1.
- Prospect create call already accepts begin/expiration/visits and the opt-in flag (D62, D67).
- Phase-one fields: first name, last name, email, mobile (D67).

## G. Cancelled or reversed in this version

- CR-11 BFF QR renderer and CR-16 QR on the success page — cancelled (D63).
- CR-22 keep the 18+ checkbox — reversed; CR-26 removes it (D66).
- Club-settings "club item for prospect day pass" field — removed before any DBA request (D61).
- Dynamic-link QR web app — not v1; recorded as the v2 credential design (D63).
- Link-use counter ("works three times") — not needed; M\&O visits and dates bound access (D62).
- Start-date picker — removed (D71); future begin dates unsupported pending Chancy's tests (D74).
- Multi-day / multi-visit passes — tabled (D72).
- Service modeling — replaced by product (D70).

## H. Things you need to have (inputs)

1. Design HTML (latest revision with pass options) as the build's source of truth — have.
2. §4.5 terms — partial (content not approved).
3. Commerce Pay Page embed — in progress.
4. Email OTP — **done, CISO-approved**; OTP email HTML template from Chancy — pending today.
5. Prospect-wallet save-card — in progress.
6. Sandbox cards and OTP mail sink — partial.
7. Legal opt-in language — have (Chancy posted it).
8. Catalog-item columns in a lower environment — pending Terry Smith.
9. Engagement team's QR library — have (PK posted it).
10. Jira epics for the DT stories — pending Bjorn.
11. Repo decision for the page — pending Bjorn.
