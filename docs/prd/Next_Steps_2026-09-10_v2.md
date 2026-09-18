# Next Steps v2 — Guest Pass Online on the Prospect Wallet (evening of 2026-09-10)

Companion to Consolidated PRD v3.6 (Rounds 6 and 7, D59–D74) and Change Requests v3. Supersedes Next Steps v1 from earlier today.

## Where we are

- Email OTP is built, working, and approved by the CISO team. Bjorn owns it; Chancy is sending the email template.
- The product now has a home: a standalone Guest Pass URL forked off Myko, not Online Join. Clubs add a "Buy a day pass" button next to the trial and join buttons.
- Configuration moved onto the catalog item mid-session: a "Guest pass online" flag opens contract days and visits. The club-settings item picker is gone and was never sent to the DBA. This is what lets a club sell a day, a week, and a month pass from day one.
- The credential is settled: a static QR of the barcode in the DT prospect email, nothing on the web page. Anil confirmed every scanner reads it. DT is the only renderer.
- Failed payments follow the existing create-then-deactivate pattern for now. Nobody likes it. PK confirms the rule; v2 removes it.
- The 18+ checkbox is gone. The legal-written opt-in checkbox is in, with the long text in a modal.
- Evening alignment: the pass is a **product** (so unused passes are not liabilities), the **start-date picker is removed** (the pass starts on purchase; the page shows days-to-use from M&O contract days), and v1 is a **single-visit day pass** whose first check-in expires the prospect. Multi-day and future start are tabled.

## Tonight

1. **Chancy** reconvenes with **Terry Smith at 7 pm** to finalise the catalog-item fields and tables (product flag, contract days, visits); then finishes the DT PR — flag on products, waiver language under Online, prospect email with QR and acknowledgement text — to **PK** for review, and the OTP email HTML to **Bjorn**.
1a. **Chancy** tests whether M&O accepts a future begin/end range and whether DT alerts on a pre-begin check-in. Result decides if a date picker can ever come back.
1b. **Chancy → Mark**: UI change — remove the date picker; add "You have X days to use this pass" bound to the item's contract days.
2. **Chancy → Terry Smith**: DBA ticket for the three catalog-item columns. Terry says whether the table is common-use; if so, it runs tonight. **Kelly** escalates if it stalls.
3. **Mark** ships the API package behind its flag.

## Tomorrow morning

4. **Bjorn**: fork the Guest Pass URL off Myko and confirm the repo home; remove the 18+ checkbox; add the opt-in checkbox with modal; success page says the QR was emailed; OTP email from the template; numeric keypad; read DT config from the database.
5. **Mark**: create call with begin = today, expiration = today + contract days − 1, visits = 1, opt-in, item, wallet token; no future dates; create → pay → deactivate on failure; save card only on success; attempt logging; confirm the Cloudflare rules from OJ cover the new URL.
6. **Bjorn → Chancy**: Jira epics so DT stories land in the right place.
7. **Chancy**: LaunchDarkly flag; POS receipt and pass email subjects.

## Before enabling a pilot club

8. Desk-scanner test: emailed QR admits on the pass day, refused after expiration or once visits are used (Chancy, Mark).
9. Webhook check: a failed payment's deactivate reaches every CRM the create reached (Chancy, Kyle).
10. Simulated-user agents end to end with the mail sink and sandbox cards (Mark).
11. Maintenance server running at the pilot clubs (Chancy).
12. Baselines at clubs 31239 and 31590 captured (D27).

## Decisions and confirmations still on Kelly

- Take the opt-in modal mockup to legal; test Twilio's objection. Fallback is inline text.
- Ask counsel about waiver enforceability with no age gate, and confirm the email acknowledgement text.
- Name an owner for reporting and insights requirements.
- Decide when the dynamic-link credential (Anil and Jag's design) gets scheduled and who hosts it. PK's team offered.
- Post v3.6, Change Requests v3 and this doc to the Miro board.

## Waiting on others

- **PK**: is there any legal or payment-operations rule behind creating the record before payment? If not, v2 drops it.
- **Terry Smith**: catalog-item table classification and deployment window.
- **Bjorn**: repo home for the page; Jira epics to Chancy.
- **Chancy**: results of the future-begin and pre-begin check-in tests; final field list from Terry.

## Deferred to v2 (recorded in the PRD, not built now)

- Multi-day / multi-visit passes and any future start date; pass extension on repeat purchase; the guest definition revisit (D73).
- No prospect record unless payment succeeds; decline offers another payment method.
- Dynamic-link credential: public web app rendering a one-minute timestamped QR from barcode and club number.
- Minimum age via the M&O setting; DOB capture; minor queue.
- Waiver version tracking and once-per-club state.
- "What's included" copy per item.
- Reporting and insights.
- Chancy's OneNote of day-pass use cases.

## Risks this week

- **Create-then-deactivate webhooks** — if the deactivate does not propagate, clubs market to people who never bought. Highest risk of a bad first impression with a pilot club.
- **DBA window** — night deployment if the catalog table is common-use; production timing is the gating item.
- **Twilio and the modal** — could block SMS sends; have the inline fallback ready.
- **No age gate** — counsel question open on waiver enforceability.
- **Card testing on an open endpoint** — Cloudflare limits and attempt logging must be live before the URL is public.
