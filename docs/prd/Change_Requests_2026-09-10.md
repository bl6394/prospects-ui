# Change Request List — Guest Day Pass Purchase (sprint review 2026-09-10)

Source: sprint review of build v1.1 against the Director of Design HTML v1.2. Decisions logged in the Consolidated PRD v3.4 as Round 4 (D42–D47). Board copy: https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683338149349

Speakers identified by role as inferred from context: Design (owner of the latest HTML), PM (Kelly Card), Engineering. Owners below are suggestions, not assignments made in the room.

## A. Change requests (must change in the build)

| # | Change request | Area | Decision | Owner (suggested) | Notes |
|---|---|---|---|---|---|
| CR-01 | Move the T&C agreement control and the Pay button into the right-hand Order Summary panel | Front end | D42 | Engineering | Already in HTML v1.2. "Save this card for next time" stays where it is. |
| CR-02 | Replace the T&C modal content with the new General Counsel-agreed terms from PRD §4.5 | Content / front end | D43 | PM + Engineering | Build shows the old terms. Terms do not come from the Pay Page. Content itself still PROPOSED pending counsel. |
| CR-03 | Embed the Commerce Pay Page for card capture, the same way membership online join does | Backend + front end | D44 / D38 | Engineering | Cardholder name, card, expiry, security code, country, postal code all come from the Pay Page. Backend must supply it; design can only mock it. Membership online join is the only existing embed to copy. |
| CR-04 | Remove the saved-card dropdown for a first-time buyer; add-new-payment-method comes from the Pay Page | Front end | D44 | Engineering | The dropdown seen in the demo was browser Google Pay autofill exposing real cards. |
| CR-05 | Add email OTP for both lanes (first-time and returning): enter email, receive code, enter code | Backend + front end | D35 | Engineering | Missing from build v1.1. Login and signup are one action; recognition only changes the decoration. |
| CR-06 | Save-card writes the tokenised card to the prospect wallet | Backend | D45 | Engineering | New capability. Membership path stores to the member wallet today. |
| CR-07 | Remove unnecessary explanatory text the generator adds | Front end | D46 | Engineering | Removed in HTML v1.2; confirm in build. |
| CR-08 | Bring the build to visual parity with HTML v1.2: fonts, sizes, layout, colours | Front end | D46 | Engineering | Build is on v1.1. Run the diff loop until no differences are reported. |
| CR-09 | Add the unchecked marketing opt-in at the contact field | Front end | D32b | Engineering | Carried from the Design v2 alignment table; still absent. |

## B. Process and test-harness requests

| # | Request | Decision | Owner (suggested) | Notes |
|---|---|---|---|---|
| PR-01 | Visual-parity agent loop: point the agent at the HTML in the repo as source of truth; compare, fix, repeat until no differences are found | D46 | Engineering | Never reaches pixel-perfect; stop when no differences are reported. |
| PR-02 | Multiple independent simulated-user agents run the whole flow end to end | D47 | Engineering | Agents cannot receive email or hold a card; the harness must fake both. |
| PR-03 | OTP mail sink so agents and testers can read one-time codes | D47 | Engineering | Prerequisite for PR-02. |
| PR-04 | Sandbox test cards: 4242… valid, expired card = invalid case; browser autofill / Google Pay off in test; never real cards; no live charges | D47 | Engineering | New-card entry is not possible until the Pay Page lands (CR-03). Test pass observed at $18. |

## C. Confirmations needed (no build change yet)

| # | Item | Decision | Owner |
|---|---|---|---|
| CF-01 | Counsel confirms right-panel consent placement stays conspicuous | D42 | PM |
| CF-02 | Counsel approves T&C content (Pass Terms, waiver, stored-card disclosure, privacy notice) | D43 / §4.5 | PM + Legal |
| CF-03 | Owner named for the OTP mail sink and test-card list | D47 | PM |

## D. Confirmed correct — no change

- Phone number removed as an authentication method (D35); already in HTML v1.2.
- Date selector.
- "Welcome back" returning-buyer lane: your info, then payment.
- Position of "Save this card for next time".

## E. Things you need to have (inputs)

1. Latest Design HTML v1.2 in the repo, flagged as the build's source of truth — have.
2. New T&C content from PRD §4.5 — partial (source fixed, content not approved).
3. Commerce Pay Page embed for the pass flow — missing.
4. Email OTP send/verify service — missing.
5. Prospect-wallet save-card capability — missing.
6. Sandbox test cards and an OTP mail sink — partial (cards exist, no sink).
7. Parity-loop and simulated-user agent tooling — missing.
