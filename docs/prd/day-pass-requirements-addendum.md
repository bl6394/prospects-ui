# Day Pass requirements addendum — Riverside demos (2026-09-09)

**Applies to:** `docs/sprints/SPRINT-0001.md`. **Sources:** `prospect-wallet-demo-1-first-visit.html` and `prospect-wallet-demo-2-returning-visit.html` (added to this repo 2026-09-09; identical to the copies in `prospects1/docs/prd/`). The two files share one script and differ only in `MODE` (`first` | `returning`) and one line of done-page copy.

**Decision (user, 2026-09-09):** where the Riverside demos conflict with `day-pass.html`, **the demos are authoritative**, with one exception: **the Terms & conditions gate is kept** (separate affirmative acceptance before payment), even though the demos omit it. `day-pass.html` remains the source for everything the demos do not cover: the `--ig-*` tokens and `dt-*` component styling, masking rules, validation messages, and the inline error behaviour.

## What changes

| Topic | Was (day-pass.html) | Now (Riverside demos) |
|---|---|---|
| Identify screen | Offer card ("Gym Floor", $25, perks, radio) beside the contact field; header "Get your day pass!" / "Choose your pass, then tell us the best way to reach you" | **No offer card.** Header "Get your day pass", sub "Start with how we can reach you. Either works."; one field "Mobile number or email" with placeholder `you@email.com or (555) 555-0123`; help line "Bought with us before? We'll send a code so you can use your saved card. New here? You'll set up in the next step."; Continue button in the main panel. Invalid input turns the help line into the error "Enter a mobile number or an email address." |
| Code entry | Inline beneath the contact field on the same screen; Change / Resend / switch | **Separate step.** Header "Check your email" or "Check your texts"; sub "We sent a 6-digit code to **{masked}**."; six single-digit inputs; links "Resend code" · "Text me instead" / "Email me instead" (only when the other contact is on file) · "Start over"; Verify button disabled until six digits. Start over returns to a fresh identify screen and revokes the challenge and any binding. |
| Pay button | In the Order Summary sidebar, enabled only when date and terms are set | **In the main panel** at the bottom of the recognized and new-visitor steps: "Pay $18.00 and get my pass". Enabled when terms are accepted and the payment method is ready (the date always has a value now). |
| Terms & conditions | Checkbox + modal in the sidebar | **Kept**, moved to the main panel directly above the Pay button on the recognized and new-visitor steps: checkbox "I agree to the Terms & conditions" with the link opening the modal; modal has Close and "Agree and close". Still a separate affirmative act recorded server-side before purchase. |
| Visit date | Blank, must be chosen, min today | **Defaults to club-local today**, label "Pick a day", min today; changing shows toast "Day pass for {Today|Wed, Sep 9}". |
| Sidebar before an order | Two skeleton blocks | **Always shows** the line item "1-day pass  $18.00", the "Pick a day" date field, and Total. "Paying with" row appears once a payment method is selected. Title "Order summary" (lower-case s); "Receipt" on done. |
| Fine print | Two variants | Three: identify/new visitor "Defaults to today — pick another day if you're planning ahead. No membership. No recurring billing."; recognized "Valid {day}. Your card stays on file at {Club} — not on this website."; done "Receipt emailed/texted to {masked}. Your card stays on file at {Club} — not on this website." Initial static text "No membership. No recurring billing. Change plan any time before you pay." |
| Offer | Selectable product | **One fixed product** per club from the catalog ("1-day pass"); `offerId` stays in the contract but the UI never asks. |
| Save-card control | Checkbox | **Toggle switch** styled control, same copy: "Save this card for next time" / "Here, in the app, or at the front desk. No membership, no recurring billing." Default on. |
| Recognized header | Widget header "Welcome back, {first}" / "Confirm your details and pay" | Banner "✓ Welcome back, {first}" then "Your info" and "Payment" sections |
| Done | "You're in, {first}" / "Your pass is ready" | Banner "✓ You're in, {first}"; pass block "1-day pass · {day}" with "Show this at the front desk, or just say your name. We emailed/texted it to {masked} too."; pill "✓ {Brand} •••• {last4} saved to your wallet" plus "Next time — here, in the app, or at the desk — you'll just verify your {email|number} and pay."; or "You chose not to save a card. Next time you'll enter it again."; buttons "Get the {Club} app" (ghost) and "Start again". The browser URL changes from `…/day-pass` to `…/pass` on completion. |
| Site nav | "Class · Membership · Day Pass · Visit", club brand + location switcher | "Classes · Memberships · Day pass · Visit", club logo + name ("Riverside Athletic Club"), "🔒 Secure checkout". Location switcher dropped. |
| Fixture | Core Health and Fitness Club — South; $25.00 Gym Floor; Jordan Reyes `m@m.com` / `(555) 019-2231` / Visa 4242 | **Riverside Athletic Club; $18.00 "1-day pass"; Jordan Reyes `jordan.reyes@email.com` / `(555) 019-2231` / Visa 4242 "Saved in the app last week"**. Core remains available as a second mock club for multi-club tests. |
| Demo scenarios | Three paths | Named **Demo 1 · First visit** (new visitor, save on and off) and **Demo 2 · Returning visit** (saved card; different card save on/off). The demo script and validation docs use these names. |

## What does not change

Identity model and ordering (contact finds, code proves, session binds to the member ID, wallet by `(memberId, MEMBER, org)`; authorize → persist prospect → consented wallet write → sale → issue → deliver); PCI path (Pay Page hosted fields, no card inputs in React); flag and club gating; second contact as an additional lookup key; masking rules; validation messages ("Please add your first and last name.", "Please complete the card details.", "That mobile number doesn't look right.", "That email doesn't look right."); the "Behind the scenes" panel remains a demo affordance and is not shipped.

**Demo-only affordances not to implement:** Demo 2's rule that *any* typed contact is treated as Jordan's; the browser-chrome frame; "Restart demo".

## Contract impact (BFF)

- `POST /checkouts/:id/verify` and the new-visitor path create the order shell with `visitDate = club-local today`; `PUT /checkouts/:id/order` still changes it.
- `DELETE /checkouts/:id/identity` is the "Start over" action from the verify step.
- Catalog fixture default becomes Riverside ($18.00, single offer "1-day pass"); a second fixture club (Core, $25.00) is kept for tests.
- No other route or schema change.
