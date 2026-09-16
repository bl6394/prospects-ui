# Sprint 0003 — PROPOSED designs for DESIGN review (D2, 2026-09-16)

Design v4 (`docs/prd/day-passv4.html`) covers the checkout and the done page. Two surfaces it does not cover were built this sprint from the v4 done-page block and the code-email design language (`docs/prd/email-1-verification-code.html`). Both ship **PROPOSED** (blocker PC-1); the copy is pinned in tests so a DESIGN change is a string edit plus a test update.

## 1. Pass / receipt email (`renderPassMail`, BFF `adapters/smtp/templates/passEmail.ts`)

Screenshot: `screenshots/sprint-0003/email-pass-3day-delivered.png` (delivered through Mailpit, CID image inlined for the render, token redacted).

- Subject: `Your {label} at {legalName} · {validity}` (absolute dates, never "Today").
- Header: legal name + location label (as `email-1`); preheader.
- "You're in, {first}" / "Your pass is ready"; pass block "{label} · {validity}"; QR image `alt="Door QR code"` (CID on SMTP, hosted `qr.png` on the publisher); a plain "View your pass: {url}" line near the top so the mail is useful with images blocked; "View your pass" button.
- Receipt table: receipt number, item "{label} · {name}", amount, Valid, Paid with `{brand} •••• {last4}`, seller legal name + address; "No membership. No recurring billing."; the PRD refund sentence (D15/D22).
- Footer as `email-1`: "Sent on behalf of {legalName} by ABC Fitness…", Pass Terms / Privacy links.
- Plain-text alternative with the same facts and the link.

Open for DESIGN: visual treatment of the QR block and button; whether the receipt belongs in the same email or a second one; localisation of dates.

## 2. Login-free pass page (`/signup/pass/:token`, UI `PassViewPage` + `PassCredential` + `PassReceipt`)

Screenshots: `core-kelly-3day-future-pass-page-{1440,375}.png` (Upcoming), `core-kelly-1day-pass-page-{1440,375}.png` (Valid today), `core-new-5day-save-off-pass-page-{1440,375}.png`.

- Shell header (brand word/tag, static location label) reused; tabs shown as static labels; "Secure checkout" label kept (no v4 alternative).
- Main widget "Your pass" / "{club name}": QR (client-rendered SVG, `<noscript>` hosted PNG), "{label} · {validity}", first name, status pill **Upcoming / Valid today / Expired**, "Show this at the door, or just say your name at the front desk.", "Get the {Brand} app" when the club has an app link.
- Sidebar "Receipt / Paid — this is your record": item, amount, Valid, receipt number, Paid; fine print "Receipt emailed to {masked}. No membership. No recurring billing." — no card brand/last4, no ids.
- States: loading "Loading your pass…"; not found (tampered / revoked / expired link / malformed) → "This link isn't valid."; expired pass (grace window) → credential without QR + alert "This pass link has expired. Your receipt is in your email; the front desk can look you up by name."; generic error + Retry.

Open for DESIGN: page title and subtitle; pill colours; whether the expired state should keep the dates visible (current: yes, per U18); mobile layout of the QR block.

## 3. Done-page copy without a v4 source (UI `PassBlock`, `DoneStep`)

- `pending`: "We're sending your pass and door QR code to {masked}. You can view your pass here."
- `failed`: "We couldn't email your pass and door QR code to {masked}. You can view your pass here, or say your name at the front desk." + "Resend pass email".
- `not-attempted`: "Just say your name at the front desk."
- Resend toasts: "Pass email sent to {masked}" / "Sending your pass email to {masked}" / "We couldn't send the pass email to {masked}".
- Receipt row "Your pass — View your pass".

These are approved deltas AD-12 / AD-13 in `tools/day-pass-harness/parity/approved-deltas.json` pending DESIGN sign-off.
