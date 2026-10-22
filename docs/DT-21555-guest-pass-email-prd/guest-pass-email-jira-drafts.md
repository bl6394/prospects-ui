# Guest pass email — Jira drafts

Use these in a **fresh Cursor chat** in this project so the Atlassian
connection (`plugin-atlassian-atlassian`) is attached. Project **DT**.
Assignee **Chancey Toombs**. No Figma mockups. After tickets exist, comment
the keys on the GitHub PR and rename the branch if desired.

Create in this order, then link Stories/Task as children of the Epic.

---

## Epic

**Issue type:** Epic  
**Summary:** Guest pass item and Add Guest email

Staff can mark a catalog item as a guest pass, clubs can maintain guest
liability language, and members who buy a guest pass (or are added as a
guest) receive an Add Guest thank-you email with a barcode QR code.

**Acceptance criteria:**

1. Clubs can configure guest-pass products, guest liability language, and
   the Add Guest email envelope independently.
2. A member who is added as a guest or who buys a guest-pass item at POS
   can receive the Add Guest email when the type is active and an email
   address is on file.
3. Database changes required for this work are tracked in a child task
   that the database team can execute.

---

## Story 1

**Issue type:** Story  
**Summary:** Mark catalog items as guest pass products

Club staff need a way to identify which products are guest passes so later
sale and email behavior can treat those items differently from ordinary
retail. On the catalog item secondary page, staff can flag an item as a
guest pass and enter allowed visits and contract days (1–100) when the
flag is on.

**Acceptance criteria:**

1. Staff can mark a catalog item as a guest pass and save visits and
   contract days between 1 and 100.
2. When the guest-pass flag is off, visits and contract days are not
   required.
3. After the item is deployed to a club, the guest-pass flag and related
   values are available on the club sale item used at POS.

---

## Story 2

**Issue type:** Story  
**Summary:** Configure guest liability language for clubs

Clubs already maintain prospect terms. They also need club-specific
liability language that can appear in the Add Guest email so guests see
the club’s current wording rather than a one-size-fits-all paragraph.

**Acceptance criteria:**

1. Staff can view and save guest liability language in Edit Club for both
   Fast Add and Online prospect configuration.
2. Saved liability language is the text that appears in the Add Guest
   email for that club.
3. Clubs with no liability language still send the rest of the email
   without that section.

---

## Story 3

**Issue type:** Story  
**Summary:** Send Add Guest email with barcode QR code

When a guest is added, the club should be able to send a thank-you email
that includes guest details, club terms, liability language, and a QR
code of the guest barcode for door or kiosk use. Subject, header, footer,
and active flag stay editable in the existing email-type screens.

**Acceptance criteria:**

1. An Add Guest email type exists and can be turned on or off per club
   like other email types.
2. The email body includes guest contact details, terms, liability
   language when present, and a QR image generated from the guest barcode.
3. If the email type is inactive for the club, the email is not sent.
4. The Add Guest path from Fast Add / add-guest continues to use this
   email type.

---

## Story 4

**Issue type:** Story  
**Summary:** Email guest when a guest pass is sold at POS

Buying a guest-pass item at the register should notify the purchaser the
same way adding a guest does. After a successful sale that includes a
guest-pass item, Datatrak sends one Add Guest email to the member on the
sale.

**Acceptance criteria:**

1. Completing a POS sale that includes at least one guest-pass item sends
   one Add Guest email to the member on the sale when they have an email
   address and the type is active.
2. Sales with no guest-pass items do not send this email.
3. Returned or voided guest-pass lines do not trigger the email.
4. If the email cannot be sent, the completed sale still succeeds.

---

## Task

**Issue type:** Task  
**Summary:** Apply guest pass email database changes

The application work depends on new columns on existing tables and on
Add Guest rows in the existing email-template tables. No new tables.

Handoff for the database team:

- Markdown: `docs/database/guest-pass-email-database-handoff.md`
- Word: `docs/database/guest-pass-email-database-handoff.docx`
- PDF: `docs/database/guest-pass-email-database-handoff.pdf`

Script order:

1. `sql/project-prospect-liability-language.sql`
2. `sql/project-guest-pass-catalog-item.sql`
3. `sql/project-add-guest-email-type.sql`

**Acceptance criteria:**

1. The seven new columns exist on `SPL_EXTENSIONS`,
   `CATALOGITEMS`, and `SALEITEMS` as documented in the handoff.
2. The `ADD_GUEST` contact template exists globally and location rows are
   cloned from `ADD_PROSPECT` for each club that already has that type.
3. Billing code uniqueness (`CTEM_UNIQUE_BILLING`) is confirmed before
   the email-type script is applied; `030` is the intended code.

---

## After tickets exist

1. Replace `NOJIRA` on the PR title/body with the Epic key (or primary
   Story key, per team preference).
2. Comment each ticket URL on the PR.
3. Optionally rename `feat/NOJIRA-guest-pass-email` to
   `feat/<EPIC-KEY>-guest-pass-email`.
