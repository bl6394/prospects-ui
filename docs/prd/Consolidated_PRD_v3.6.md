# Short-Term Passes \& Prospect Identity — Consolidated PRD (v3.6 — Guest Pass URL and catalog-item model, round 6)

**Status:** Draft v3.6 (D1–D74); Round 3 full text in companion §1b; Round 4 (2026-09-10 sprint review) notes in the Sprint Review doc; Round 5 (2026-09-10 PM working session with Jennifer and Chancy) added the DataTrak enablement decisions D48–D58 and §4.6; **Round 6 (2026-09-10 afternoon, with Chancy, Kyle Childers, Anil Joseph, Jag Wander, Mike West and PK) adds D59–D69: standalone Guest Pass URL, per-catalog-item pass configuration, static QR by email only, the create-then-deactivate payment pattern, 18\+ checkbox removed, legal opt-in checkbox.** §4.6 rewritten. **Round 7 (2026-09-10 evening) adds D70–D74: guest pass is a product, start-date picker removed, single-visit day pass ships first.** "(D#)" tags mark changes; §4.5 PROPOSED. Companion files for this version: `Change_Requests_2026-09-10_v3.md` (what changes, by owner) and `Next_Steps_2026-09-10_v2.md` (who does what next).

**Sources**

- PRD #1 — "Prospect Wallet — PRD Summary" (Kendall), Miro doc `3458764683094415355`
- PRD #2 — "Prospect Wallet Product Requirements Document" (Jennifer), Miro doc `3458764683094558923`
- Board notes: ABC customers with online day passes (`3458764683095278523`), Slack chatter on short-term passes (`3458764683095452743`), Passwordless Login Solve (`3458764683097847385`), Iron 24 benchmark (`3458764683096115511`, `3458764683096115720`)
- Board reference only (not inspected): Figma "OJ Design" (`3458764683096460981`) (D4b)
- v2–v3.1 inputs: `codex_review.md`, `claude_review.md`, `scenario_solutions.md`, `consent_legal_research.md`, prototype `prospect-wallet-demo-1b-consent.html`; Kelly Card decisions (2026-09-09)
- v3.4 input: sprint review of build v1.1 against the Director of Design HTML v1.2 (2026-09-10) — "Sprint Review Notes — Guest Day Pass Purchase" https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683338149349
- v3.5 input: PM working session 2026-09-10 (Kelly Card, Bjorn, Mark; with Jennifer and Chancy, PMs) on enabling the online day pass in DataTrak — recorded transcript; Change Requests 2026-09-10 (v1) as the baseline for v2
- v3.6 input: afternoon working session 2026-09-10 (Kelly Card, Bjorn, Mark; Chancy Toombs; Kyle Childers; Anil Kanjooparambil Joseph and Jagjit Singh Wander from the engagement/Trainerize side; Mike West; Paul Knuth "PK") — recorded transcript

**Terminology.** Per the Slack thread, this PRD uses **short-term pass** to mean any non-recurring access product from a single day pass up to roughly one month (day pass, multi-day pass, week pass, trial pass). **Product framing (D5):** the Prospect Wallet is the feature; it serves several use cases; the short-term (day) pass is the dominant use case and the primary journey in this document. The wallet remains the spine of the PRD. **Buyer framing (D29):** pass buyers are largely **fitness explorers** — people who want to visit clubs when and where it is convenient for them; in v1 pricing does the conversion work, product nudges toward membership come later. **System naming (v3.5):** DataTrak (DT) is ABC's operator system for the club — the system this PRD has called M\&O; club settings, catalog items, email types, prospect records, barcodes and check-in live there. The two names are used interchangeably below.

## Decision log

### Round 1 — 2026-09-09 (Kelly Card)

Each entry: decision — rationale — what it closes.

- **D1.** The pass is a **POS item** with a start date and an end date derived from the pass product's configured timeframe. It is not a new "entitlement object". Validity window, check-in validation, and expiry requirements are stated on the POS item. — *Rationale:* reuse the existing product/POS model instead of inventing a parallel entitlement domain. — *Closes:* review finding "pass object missing"; scenario decision 5 (partially). *(Access enforcement revised by D48: the sold catalog item carries the money; the prospect record's begin/expiration dates carry access.)*
- **D2.** Likely repeat pass buyers are **returning out-of-area visitors**, not ex-members. Ex-members must still be able to buy a pass. Existing active members will not buy day passes in this scope (e.g. for friends/family) — no "member buys pass" path in v1. — *Rationale:* matches the observed buyer population; keeps v1 to one buyer type. — *Closes:* "do members get offered passes"; state-model row "Member buys a pass".
- **D3.** Identity resolution key is the **phone number or the email address** (either works as lookup key and OTP channel), consistent with the online-join flow already built. Possession only identifies; it does not authorize (D10). *(Superseded by D35.)* — *Rationale:* aligns with what online join already does; either contact field the club already collects. — *Closes:* Q20 (partially), "SMS fallback (email code?)".
- **D4.** Three over-promoted items corrected: (a) passwordless OTP is a **recommended approach, owner TBD**, not a recorded decision *(accepted and owned in D19/D26)*; (b) the Figma "OJ Design" file is a board reference only, not passwordless design evidence; (c) "recurring billing is structurally impossible" is replaced with: membership dues require an RCM agreement, and recurring services are out of scope for v1 as a **priority call**. — *Rationale:* v1 stated more certainty than the sources support. — *Closes:* C4.
- **D5.** **Prospect Wallet is the feature**; it serves multiple use cases; the day pass is the dominant use case. Do not restructure the PRD around the pass. — *Rationale:* the wallet is the shared dependency; the pass is the first journey that exercises it. — *Closes:* C7 (framing), Claude review Q1.
- **D6.** **C1 — both diagnoses are right.** Both are recorded as required work. The wallet API contract is keyed by **person UUID**; AccountInfoID/Commerce is satisfied underneath. — *Rationale:* two layers of the same gap (M\&O/Universal Wallet vs Commerce/eAPI); one contract on top, both fixed below. — *Closes:* C1.
- **D7.** "Card on file (COF) is in scope." (verbatim) Full add/replace/remove parity in the app is **not** asserted as decided; remaining in-app wallet-management capabilities stay open. *(Closed by D17.)* — *Rationale:* unblocks the dominant use case without pre-deciding app management scope. — *Closes:* C2 (COF part), C6 (cards).
- **D8.** **Reverse conversion: suspend, never delete.** Tokens retained, agreement roles stripped, reactivation is a consent tap. Reverse conversion is pulled **into** scope; the "Critical \+ out of scope" contradiction is retired. — *Rationale:* ex-members must be able to buy a pass (D2) on the same identity and wallet. — *Closes:* Q4; Critical watchlist item; non-goal "reverse conversion is a separate decision".
- **D9.** **Prospect creation for web/app buyers:** persist the person after OTP **or** payment (verified contact). Sequence: verify → persist person → init wallet → collect payment → fulfil. Keep the person if later steps fail. Delete the contrary "prospect exists before payment data is collected" assumption. — *Rationale:* verified contact is the right threshold: no junk records at phone entry, no lost leads at payment. — *Closes:* C5, Q14.
- **D10.** **Authentication:** phone/email possession only identifies; **step-up** before exposing stored credentials from a new device; **one OTP issuer** shared by web and app. — *Rationale:* possession of a contact channel is not account authority. — *Closes:* Q21; scenario decision 3; review "does phone possession authorize".
- **D11.** "VPD of ABC is the proper tenancy." (verbatim) Recorded as: identity and wallet tenancy boundary = the ABC VPD. Glossary line added (D36). — *Rationale:* sets the boundary the phone/email match query runs inside. — *Closes:* Q11 (boundary only; details remain open — see D28).
- **D12.** **Lifecycle restrictions: BLOCK.** Active, frozen, past-due, and banned members do not buy short-term passes in this version. **Unused pass time at conversion to membership is lost** — no credit, no refund, no delayed start. — *Rationale:* simplest correct rule for v1; conversion is the economic goal (D16). — *Closes:* review Q5/Q7 (lifecycle, unused value); state-model member row.
- **D13.** **Payer vs pass-holder** (gifting, guardians, households): **not in MVP.** Self-purchase only. — *Rationale:* keeps identity = payer = pass-holder in v1. — *Closes:* review Q8/Q5 (payer vs participant).
- **D14.** **Waivers:** in scope for the day-pass use case; **not part of the Prospect Wallet.** The wallet does not store waivers; waiver status is a pass-checkout requirement. — *Rationale:* wallet stays a billing capability; waivers belong to the pass sale. — *Closes:* C3, Q23, FR-E5.
- **D15.** **No refunds on short-term passes.** Stated as policy in Pass Terms. Chargeback handling still to be defined (open). *(Chargebacks and in-club refunds resolved by D22.)* — *Rationale:* cheap, instantly fulfilled product; refunds invite abuse. — *Closes:* review Q10 (refund part).
- **D16.** **Business optimisation:** club passes are cost-prohibitive on their own — pass pricing is intentionally set so the economic path is membership conversion. Optimise for conversion, not casual revenue. — *Rationale:* defines what the metrics and roadmap optimise for. — *Closes:* review Q12.

### Round 2 — 2026-09-09 (Kelly Card)

- **D17.** **In-app wallet management.** The prospect can **manage** the wallet in the mobile app (view, add, replace/update, remove); can **add** a payment method to the wallet on the web; and the front desk sees the updated information — at minimum. Full web management beyond add is not asserted. — *Rationale:* the app is the explorer's home surface; web needs only enough to complete a purchase; desk parity is what makes it one wallet. — *Closes:* remaining part of C2; "in-app management scope" open item; H10 scope; FR-E2 residual.
- **D18.** **Pass credential.** After purchase the buyer is shown a **QR code**. The QR is **persistent in the mobile app**. Desk check-in **scans the QR against the pass's start/end dates on the POS item**. Clubs **may** tell day-pass buyers to download the club's mobile app for the best experience (club messaging option — not a requirement to buy or to enter). — *Rationale:* a scannable credential makes "buy right before walking in" real without new door hardware; the app is the durable home for it. — *Closes:* "pass credential / check-in mechanics" open item; FR-P7 credential residual; Claude review Q7. *(v1 delivery: static QR of the barcode by email — D51; app persistence follows with the app scope.)*
- **D19.** **OTP channel — "Okay" to the recommendation.** *(Channel superseded by D35; step-up stands via D10.)* Phone and email both lookup keys; club configures the code channel; web defaults to email; step-up before exposing a stored card from a new device. — *Rationale:* keeps the desk-friendly phone key while defaulting the public web to the cheaper, safer channel. — *Closes:* D3 email-only option; D4a "recommended approach" — now accepted; §5 channel question; Q20 (channel part).
- **D20.** **Session lifetime — no PM preference** (verbatim: "I don't care about this"); engineering/security chooses. **Working assumption:** 30-day web session refreshed on purchase; app session indefinite with biometric/OS re-auth. Owner = engineering. — *Rationale:* not a product differentiator; engineering owns the number, the PRD carries a default so design can proceed. — *Closes:* "session lifetime and trusted-device criteria" open item (owner assigned; final numbers remain with engineering).
- **D21.** **Start date.** The "pick a day" selection **is** the pass's effective start date; the end date derives from the pass product's configured duration (D1). **Default = today.** — *Rationale:* makes FR-P4 a decided, trivial POS-item field rather than a nice-to-have; ties directly to D1. — *Closes:* FR-P4; Q18. *(Picker removed by D71: the pass starts on purchase.)*
- **D22.** **Refunds.** No online refund flow to build. Pass refunds, where a club chooses to make one, are handled **in-club through existing POS tools**. **Chargeback handling is not a v1 build item** — operational, existing process. — *Rationale:* nothing new to build; club discretion stays at the desk where it already lives. — *Closes:* D15 chargeback residual; FR-P13 residual; "chargeback handling for a no-refund product" open item.
- **D23.** **Minimum age.** Online pass purchase is **18\+** (self-attestation at checkout; minors are routed to the club). Also makes the waiver enforceable. — *Rationale:* adults can bind themselves to a waiver; minors cannot (consent memo §2.8) — routing them in-club is the only clean v1 answer. — *Closes:* "DOB and minors" open item; Claude review COPPA/minors note; counsel question (6) partly.
- **D24.** **Waivers.** Signed **once per person per club**; **re-signed on waiver version change**. **Desk and app show waiver status.** (Wallet does not store waivers — D14 stands.) — *Rationale:* one signature per club is what the club needs; version tracking keeps it enforceable; status visibility removes the desk question. — *Closes:* FR-P9 detail; Claude review "operational" waiver-status gap. *(v1 re-presentation rule set by D53: terms and waiver on every purchase; version tracking deferred.)*
- **D25.** **Migration: create wallet owners for ALL existing prospects (backfill)**, not lazy creation. (verbatim: "Create new for all existing prospects".) Implication: a backfill job with reconciliation, and remote-system record creation for dormant prospects — **volume/cost is an engineering estimate item**, but the decision is backfill. — *Rationale:* every known prospect becomes wallet-ready on day one; no split behaviour between old and new records. — *Closes:* Q6; "Migration" open item; risk-watchlist "backfill" (decided; estimate remains).
- **D26.** **Fraud \& security stays with this team** — the PM does not want it handed to another team ("assigning it somewhere else is going to slow us down"). The PRD carries a **strong recommendation** that is "super secure but ultimately protects a world class user experience" — new **§5A Security \& fraud posture (recommended)**. Owner = product, engineering to validate. — *Rationale:* delegation slows delivery; an opinionated posture in the PRD lets engineering validate rather than design from scratch. — *Closes:* "fraud controls" open item; Q7 (direction); §5 open items on rate limiting, SMS pumping, brute force, step-up mechanism, passkeys.
- **D27.** **Pilot: yes — clubs 31239 and 31590** (already selling online passes). Capture **baselines before build** (repeat-buyer share, time-to-purchase, prospect-creation rate); **success thresholds are set from those baselines**. — *Rationale:* the two clubs already have the traffic; baselines first is the only way thresholds mean anything. — *Closes:* Q22; "pilot clubs and metrics baselines" open item.
- **D28.** **Tenancy inside the VPD: yes** — the same person at two clubs within one ABC VPD is **one person record and one wallet**. — *Rationale:* one explorer visiting two clubs in one VPD is one customer, not two strangers; consistent with D11. — *Closes:* Q11 residual (behaviour inside the boundary); FR-W10 model; Claude review 2.10 (identity part).
- **D29.** **Persona and conversion framing.** Pass buyers are largely **"fitness explorers"** — they want to visit clubs when and where it is convenient for them. Prospect persona renamed accordingly. **In-app nudging toward membership is a FUTURE consideration, not v1.** Reconciled with D16: pricing does the conversion work in v1; product nudges come later. — *Rationale:* names the real buyer and stops v1 from growing a conversion-marketing feature set. — *Closes:* FR-P14 "conversion prompts — scope open"; Claude review Q1 persona residual.
- **D30.** **Guest persona — "both can be true"** *(revised in v3.2 — D31 governs).* Every day-pass buyer is a **Guest** while buying; one who gives a phone or email becomes a **Prospect** (record at OTP or payment, D9; wallet, persistent QR, recognition, conversion path); one who gives none stays anonymous — no record, wallet, persistent QR, or recognition — **in scope as a buyer** with no wallet benefits. Guest → Prospect = "gave us a contact", at sale or any later visit; prior guest sales not linked in v1. The "other surfaces per club config" clause is superseded by D31. — *Rationale:* the Slack ask describes identified buyers, not a ban on anonymous sales. — *Closes:* Personas row 6; §9 guest non-goal; FR-P2; J1/J3; §6.
- **D31.** **Guest — revises D30.** "Guest" is the pass **buyer** persona on **every channel** — web, mobile, and desk. It describes what the person is doing (buying a pass), not whether we hold a record. An **anonymous guest** (no phone or email captured) can occur **only at the front desk**; web and mobile always capture a contact, so a web/mobile guest always becomes a prospect at OTP or payment (D9). The desk can always sell to an anonymous guest: no person record, no wallet, no persistent QR, no recognition on return. A guest becomes a prospect the moment they share a contact. — *Rationale:* "guest" is a role in the sale, not a record type. — *Closes:* D30 channel clause; web/app guest-checkout open item; FR-P17; J1; §6; Personas row 6.
- **D32.** **Prospect — definition.** A prospect is a person who **could join the club, could take a trial membership, or should be followed up with by text, email, or phone about joining**. It is a **record status describing the club's relationship to the person (a sales lead)**, not merely "an identified guest". Requires a contact. Consequences: (a) an identified guest is a prospect because they are now a lead for follow-up; (b) **marketing follow-up (texts/emails/calls about joining) requires its own opt-in**, separate from the transactional OTP/receipt notice — §4.5 Tier 0 and §5A consent logging; (c) **the wallet follows the person record** — prospects and members have wallets, anonymous guests do not. — *Rationale:* a contact makes a lead the club may work; marketing consent must be separate from the transactional notice. — *Closes:* Personas row 1; §2; FR-P2; §4.5; §5A; §7.
- **D33.** **Member — definition.** Members do **not** hold a "permanent agreement". A member holds a **membership agreement for a defined term** (month-to-month, 12-month, paid-in-full, etc.). When the term ends or the agreement is cancelled they are no longer a member and, per D8, return to **Prospect** with the wallet **suspended, not deleted**. "Permanent agreement" is removed from persona, journey, state-model, and goals prose; the data distinction survives only in §5/§7 as "a membership agreement number (vs. the `PROSP` placeholder)". — *Rationale:* a membership has a term; "permanent" hid the Member → Prospect return path D8 depends on. — *Closes:* Personas row 4; §1; J3/J6; FR-W6; §5; §6; §9; §12.
- **D34.** **API pass sales are identity-first.** API-originated pass sales always require an identified buyer (prospect, or a person eligible to become one). Anonymous guest sales are a desk-only capability of the club's member management software and are not exposed through the API. — *Closes:* partner guest/prospect branching. See companion doc: https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683228918534

### Round 3 — 2026-09-09 (Kelly Card, with Mark)

One-liners; full text in companion §1b.

- **D35.** OTP **by email only**, SMS out; email = sole identifier/lookup key; one step, login = signup. *Supersedes D3, D19.*
- **D36.** Identity **scoped to the club's VPD**; never another operator's record. Confirms D11/D28.
- **D37.** **Mobile required**; SMS notice separate from marketing opt-in; OTP never by SMS. *Supersedes "second contact optional".*
- **D38.** **Commerce Pay Page required** for card capture; no redesign. Closes companion 3e.
- **D39.** API: email-OTP OPTIONAL, Pay Page REQUIRED. *Supersedes companion 3a.* OPEN: own-auth possession proof.
- **D40.** **18\+ age validation OPEN** (D23 self-attestation today; options: attestation, DOB, ID, club-configurable).
- **D41.** **Email receipt \+ credential:** receipt (memo §7), **static QR** (pass window only; club may set link-only), **"View your pass"** magic link → web page with rotating QR, no app/login. Full text: companion §1b. *(v1 narrowed by D51: static QR of the barcode by email; the "View your pass" page and rotating QR are deferred.)*

### Round 4 — 2026-09-10 (sprint review: Kelly Card, Director of Design, engineering)

One-liners; full notes and the needs list in "Sprint Review Notes — Guest Day Pass Purchase (2026-09-10)": https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683338149349

- **D42.** **Consent \+ Pay live in the right-hand Order Summary panel**; "Save this card for next time" stays in the payment section. Confirms Design v2; counsel to confirm placement stays conspicuous. — *Closes:* Design v2 alignment row "18\+ and waiver" (placement).
- **D43.** **Day-pass T\&Cs come from this PRD (§4.5, General Counsel agreement), not from the Pay Page.** The Pay Page supplies card capture only. The build's current T\&C modal is the old text — replace. Content itself remains PROPOSED.
- **D44.** **Pay Page embedded the same way as membership online join**; backend-provided (design can only mock it). Cardholder name, card, expiry, security code, country and postal code come from the Pay Page. A first-time buyer sees **no saved-card dropdown**; new-card entry is the Pay Page. Reaffirms D38. — *Closes:* Design v2 alignment rows "Payment capture" and "Country list".
- **D45.** **Save card at pass checkout stores the token to the prospect wallet** — new capability (membership saves to the member wallet today). Reaffirms D7/D17.
- **D46.** **Latest Design HTML in the repo (v1.2) is the build's source of truth**; the build (v1.1) must match fonts, sizes, layout and colours, verified by an iterative diff loop until no differences are reported; unnecessary explanatory text removed.
- **D47.** **Verification by multiple independent simulated-user agents** running the flow end to end; the test harness supplies OTP mail capture and sandbox test cards (4242 valid, expired card = invalid case); never real cards; browser autofill / Google Pay off in test; no live charges.
- Confirmed, no change: phone removed as an auth method (D35), already in the latest HTML; **email OTP is required for first-time and returning buyers** and is missing from build v1.1 — must be added; date selector and "Welcome back" lane correct; save-card control position correct.

### Round 5 — 2026-09-10 (PM working session: Kelly Card, Bjorn, Mark; with Jennifer and Chancy, PMs)

Goal set in the session: **publish the Prospect Wallet API package to production today** and complete the one day-pass use case on top of it. Bjorn is updating the web page; Chancy owns everything in DataTrak — club settings, the prospect email with the static QR, and the database columns — working in Cursor; the OTP email is not yet owned (see *Still open*). Guiding rule from the room: simplicity first — pick one mechanism and iterate. Working detail: `Change_Requests_2026-09-10_v2.md` and `Next_Steps_2026-09-10.md`.

- **D48.** **Access is enforced by the prospect record's begin and expiration dates, not by dates on the POS item.** The picked day is written to the prospect's **begin date**; for a one-day pass the **expiration date is the same calendar day**. Both are dates, not times, evaluated club-locally: a pass that expires today is usable all of today; a begin date in the future is refused at the door regardless of visits. Prospects are governed today by date **and** visit count; visits stay at the club default and are not the v1 control. The sold catalog item carries the money (profit centre, reporting); the prospect dates carry access. The maintenance server expires prospects. — *Rationale (Jennifer, Chancy):* check-in already aligns with prospect dates; nothing new is built at the door. — *Revises:* D1 and D21 mechanics; FR-P4–P8; §6 state model. *Multi-day and visit-based passes are v2 (D57).* *(D62 adds number of visits to the create call; D61 puts days and visits on the catalog item; D71 replaces the picked day with the purchase date.)*
- **D49.** **The day pass is a club-configurable catalog item selected in DT club settings**, the same pattern already used for the cancel fee and the donation item. Clubs pick an existing item or create one and name it as they like; nothing is created systematically. **Recommended type: service** (bookable/deductible later, multi-day later); a product is acceptable for a one-day pass. — *Rationale:* the standard DT route; the item's own configuration already handles how the money is reported. — *Closes:* "which item is the day pass"; sets FR-P19. *(Superseded by D61: the pass is identified by a flag on the catalog item, not a club setting; several items may be flagged.)*
- **D50.** **New DT club settings in the prospect configuration: (a) enable online day pass for this club; (b) catalog item to sell; (c) waiver language as inserted text — the same pattern as the existing prospect terms, not an upload.** Default duration is fixed at one day in v1 (a 1/2/3-day default rides along only if trivial). These are new columns on the club-settings extension table in Oracle (service-provider-location extensions) and need a **DBA ticket** (Steve Jackson / Terry Smith's group); lower environments first. Chancy builds the M\&O UI and names the fields so the DBA can derive column names; the feature ships behind a **LaunchDarkly flag** with existing behaviour as default. — *Rationale:* the existing prospect settings page is the right home; a waiver picker that does not exist today is more scope than a text field. — *Closes:* waiver source (D14 residual); no new DT page. *(Revised by D61: the catalog-item setting (b) is dropped and never requested from the DBA; waiver language (c) stands under club settings → Online; the enable switch (a) is replaced by the presence of flagged items.)*
- **D51.** **v1 pass credential = a static QR code that encodes the prospect's barcode**, delivered **by email** and also shown on the thank-you page. DT assigns every new prospect a unique 12-character barcode (systematic, or supplied via the API — must be unique) and returns it with the agreement number from prospect creation; the QR is that barcode in scannable form, not a new identifier. Saving the pass to a phone wallet from the web page is not pursued (the buyer is usually on a laptop). Barcode-to-QR and email orchestration live in the **UI/BFF layer**, not in the wallet repos — a barcode is not a wallet concern. The mobile app's dynamic QR, the "View your pass" page and the rotating payload (D41, §5A-6) are **deferred** past the first release. — *Rationale:* email is what the buyer can open on the phone at the door; static is enough for a one-day pass. — *Revises:* D18 (app persistence follows app scope), D41 (magic link deferred). *(Revised by D63: the QR is in the email only — the success page shows no QR; DT is the sole renderer.)*
- **D52.** **The pass email is the existing DT prospect email type, modified — no new email type.** Additions: the QR (header or footer), the pass date, and — per legal — the text of everything the buyer acknowledged (18\+, Pass Terms, waiver). The prospect email already carries the club's prospect terms and is sent when the prospect is created through this path. The buyer also receives the existing **POS purchase receipt** email; that is acceptable. — *Rationale:* Chancy confirmed the type exists and the terms already flow; adding to it is a same-day change. Jennifer's alternative — a new "day pass" email type fired by a "when this item is sold, send this email" rule — is recorded as the general mechanism for later. — *Sets:* FR-P20.
- **D53.** **Returning buyers re-accept Pass Terms and the waiver on every purchase in v1**; version tracking (D24) is deferred. **18\+ attestation is asked once**; a returning buyer is not re-asked. The returning lane must handle a **card on file that has expired** (offer a different card through the Pay Page). Recognition repaints the existing prospect's begin and expiration dates with the new pick. — *Rationale:* terms or waiver may have changed since the last visit; a per-purchase acknowledgement is simpler than version state. — *Revises:* D24 for v1; J2.
- **D54.** **The OTP code field defaults to the numeric keyboard on mobile** (`inputmode="numeric"`, telephone keypad). Requested by Mark; a solved problem, half a line.
- **D55.** **Release plan.** The API package — email OTP, an optional transactional email service, and the Prospect Wallet — goes to production today behind a flag; partners can adopt all three or the wallet alone (D39). The day-pass use case follows as soon as the DT pieces (D50–D52) land, flagged in LaunchDarkly so it can be switched off; stateless DT removes the one-release-a-day constraint. Marketing point to carry: a prospect created this way has a wallet with a card on file, so **card-on-file works for them at in-club POS** (juice bar and the like) from day one.
- **D56.** **18\+ stays a checkbox and no date of birth is collected** — do not add a field. DT's member "minor queue" (club-defined minor age, hold queue for a second waiver) is the future model once DOB is captured. — *Confirms:* D23; leaves D40 open. *(Reversed by D66: the 18\+ checkbox is removed.)*
- **D57.** **Deferred to v2 (recorded, not built):** multi-day and visit-based passes, including extending the expiration date on a repeat purchase; "what's included" copy (gym floor, classes, pool) configured per club; minor-queue handling; reporting and insights requirements (raised by Mark, parked until the DT requirements were settled); the "View your pass" page and rotating QR; a generic "send this email when this item is sold" rule. Chancy's OneNote of day-pass use cases is the v2 input.
- **D58** *(added later on 2026-09-10 after Kelly checked with SISO).* **Build our own email OTP in the BFF as part of the API package** — SISO's guidance: quick and simple; no dependency on another team's service. **Parameters: 6-digit code, 5-minute expiry, 2 sends per address per hour.** Lockout after wrong attempts, generic responses and disposable-domain checks stay as in §5A-1. The code email is sent by the BFF through the transactional mail provider Online Join already uses. — *Supersedes:* §5A-1's 10-minute expiry and 5-sends-per-hour figures. — *Closes:* CR-10 / CF-07; the "OTP email delivery" open item. *(Approved by the CISO team and built — D59.)* *Watch:* two sends an hour is tight — a mistyped address or a slow inbox uses both; the UI must show when a resend becomes available and offer "change email address" without consuming a send.

*Still open from Round 5:* QR generator source (what Trainerize uses; otherwise a library in the BFF); DBA ticket turnaround for production; legal check of the email content (D52); product-marketing hand-off (D55).

### Round 6 — 2026-09-10 afternoon (Kelly Card, Bjorn, Mark; Chancy Toombs; Kyle Childers; Anil Joseph and Jag Wander; Mike West; PK)

Hard stop at the end of the AI Diffusion boot-camp day. Chancy's DT work was rerouted mid-session (club-setting item picker dropped in favour of a catalog-item flag) before any DBA request went out. The dynamic-QR link was designed on the call and then scratched once Anil confirmed every scanner reads a plain barcode QR.

- **D59.** **Email OTP approved by the CISO team (Azim) and built.** Bjorn has it working end to end; the 5-minute page timer is in. The **OTP email** is sent by the BFF from an **HTML template Chancy supplies** (her DT test-email format) with the code injected; it is not club-configurable beyond the club name, which is there mainly so it does not read as spam. — *Closes:* D58 residual, CR-10, CR-29.
- **D60.** **The day pass lives at a new standalone URL — a "Guest Pass" fork off Myko — not inside Online Join.** OJ's existing "day pass" is a membership plan that expires in a day and creates a member; that is not this product. The club's website gets a third call to action next to *Get a guest pass* (free trial) and *Join now*: **Buy a day pass**, pointing at the ABC-hosted page. Mid-market and below need ABC to host an embeddable page; enterprise uses the API package and builds its own look (D39, D55). Working mindset agreed with Chancy: **this page could become the new OJ.** The web code's repo home (Myko repo vs OJ repo) is Bjorn's to confirm; DT settings stay in M\&O. — *Rationale:* a retail flow, not a sign-up-for-a-gym flow; a branch off OJ would inherit the membership model. — *Closes:* "where does this live" (open since D31); Personas — the three offers are trial prospect, member, and paying guest, and a club may choose not to offer any one of them.
- **D61.** **Pass configuration moves onto the catalog item — supersedes D49 and D50(b).** A new flag on the catalog item (working name **"Guest pass online"**, like the existing "available online") opens two fields on the item: **contract days** and **number of visits**. A club may flag as many items as it sells — one-day, three-day, week, month — each with its own price, and reporting stays per item. The Guest Pass page lists the flagged items as its offerings. The club-settings "club item for prospect day pass" field Chancy had built is removed; **waiver (liability) language stays in club settings → Online** next to the existing prospect terms. ~~The item should be a service~~ **Product, per D70** — the toggle is added to products. — *Rationale (Kelly):* seed the future — one-day today, but never a one-item corner; per-item reporting matters to Chancy. — *Revises:* D49, D50, FR-P19; the DBA request moves from the club-settings table to the catalog-item table.
- **D62.** **The prospect create call passes begin date, expiration date and number of visits** taken from the flagged item's contract days and visits; the club's default prospect settings (days/visits for the free trial) are **not** used and not touched — they serve other workflows. Kyle: a literal day pass is expiration = today plus one visit; whichever hits first expires the record, and the door/M\&O already refuse an expired prospect. Consequence: **sharing the QR is self-limiting** — the friend who scans first uses the visit; no link-use counter or dynamic logic is needed. — *Revises:* D48 (adds visits); closes the "limit the link to N uses" idea raised on the call. *(D71: begin = creation date; D72: visits = 1 for v1.)*
- **D63.** **Credential: a static QR of the barcode, no timestamp, in the DT prospect email — and nowhere else.** Anil confirmed all ABC scanners read both the timestamped engagement-app QR and a plain barcode QR, so the earlier "scanners will reject a static QR" objection was a misunderstanding. **The web success page shows no QR**; it says the QR has been emailed. DT is the **sole renderer**, using the QR library the engagement team already uses (PK shared it; Cursor's ZXing pick is replaced). — *Recorded for later:* the dynamic-link design Anil and Jag sketched — a public web app, URL carrying barcode and club number, rendering a timestamped QR valid for one minute, hosted on existing ABC infrastructure — is the v2 credential Kelly wants ("a link seeds the future"); its risks (open page, shareable link, hosting) are noted in §10. — *Revises:* D51, FR-P15, FR-P21; cancels the BFF QR renderer (CR-11/CR-16).
- **D64.** **The Guest Pass page reads DT configuration directly from the database**, the way Myko does — flagged items, days/visits, prospect terms, waiver language. No enterprise-API changes are needed for this. — *Owner:* Bjorn, per Chancy's guidance.
- **D65.** **Payment failure — v1 follows the existing M\&O pattern: create the prospect, take the payment, deactivate (soft-delete) the prospect if payment fails.** Everyone on the call dislikes it. PK: the transaction must be linked to the user and re-linking after the fact is unproven — changing it now risks today's delivery; ship, then fix. Kyle's warning stands: prospect creation fires webhooks and CRM automation, so the deactivate must also propagate or clubs will chase people who never bought. Mike West: the target state is "like a failed subscription" — no record unless the auth succeeds; the UI offers another payment method on decline. **The card is saved to the wallet only on a successful auth** (Mark). Operators do not want failed-attempt reporting; **attempts are logged**, not persisted as records, for compliance; **Cloudflare rate limiting as on OJ** protects the endpoint from card testing. — *Revises:* D9 for v1 in DT terms (the DT prospect is created at payment and deactivated on failure; the OTP-verified person in the BFF is unaffected). — *Follow-up:* PK to confirm there is no legal or payment-operations rule behind the pattern; v2 removes it.
- **D66.** **The 18\+ checkbox is removed from the page.** It came from a recommendation, not a requirement; legal liked it but did not ask for it. Minimum age will later be enforced with the existing M\&O minimum-age setting clubs already configure for memberships. — *Reverses:* D23 self-attestation and D56 for v1; **D40 stays open** and gains the counsel question of waiver enforceability without an age gate.
- **D67.** **Marketing / SMS opt-in: the legal-written single checkbox already used on the guest-pass (trial) page is included**, and the opt-in or opt-out value is passed on the prospect create call (the flag already exists in the API). The long legal paragraph goes in a **modal** behind a short mobile-friendly line; Kelly takes a mockup to legal rather than accepting the current OJ layout. Known risk: Twilio has previously told Chancy it will not approve SMS sends if the language is behind a modal — "let them tell us no." Phase-one fields: first name, last name, email, mobile. — *Confirms and specifies:* D32b, CR-09.
- **D68.** **The page is designed for several pass offerings from day one** (day / 3-day / 5-day, each with a real price such as $25) even though today's build ships with one flagged item. Mark has the options in the latest revision. — *Closes:* Q19 direction (the club decides the ladder); FR-P1 naming. *(D72: v1 ships one single-visit item; the multi-offer layout stays.)*
- **D69.** **Process:** Bjorn sends the Jira epics/tickets (they are referenced from the Miro board and this PRD) to Chancy so DT stories land in the right place; Chancy's DT PR goes to PK for review; Terry Smith decides whether the catalog-item table is common-use (night deployment) — "tonight at the latest"; the QR library link PK posted is the standard.

*Still open from Round 6:* PK's answer on the create-then-deactivate rule (D65); webhook handling for the deactivate (Kyle); legal on the opt-in modal and on removing 18\+; repo home for the page; hosting for the future dynamic-link app.

### Round 7 — 2026-09-10 evening (Kelly Card, Chancy Toombs, Mark; DT modeling follow-up)

Alignment on how the guest pass is modeled in DT and what ships first. Net effect: **a single-visit day pass, as a product, starting the moment it is bought.**

- **D70.** **The guest pass is a catalog PRODUCT, not a service.** Reason: unused service passes would sit as liabilities in reporting; a product is recognised at sale. The catalog-item toggle stands as designed in D61 — **guest pass yes/no**, with **number of visits** and **contract days** on the item. — *Supersedes:* the "service recommended / service type" language in D49, D61, FR-P5, FR-P19, §4.6. — *Closes:* CF-12.
- **D71.** **The start-date picker is removed. Contract days start immediately on creation.** A future begin date via the API is unsupported and risky — it is unclear how DT handles a check-in before the begin date. The page instead shows copy like **"You have X days to use this pass"**, with X read from the item's contract-days value in M\&O — never hard-coded. — *Revises:* D21 and FR-P4 (pick a day), D48 (begin date = purchase date, not a picked day), D62 (begin = now; expiration = now + contract days − 1). The date selector listed as "confirmed correct" in the change list is withdrawn.
- **D72.** **Ship a single-visit day pass first.** Contract days give the window; the **first check-in expires the prospect** (visits = 1). Multi-day and multi-visit passes, and any future start date, are **tabled for a later release**. The page still lists whatever items are flagged (D68), but v1 is configured and tested with one single-visit item. — *Revises:* D57 (multi-day now explicitly tabled with a reason), D68 scope.
- **D73.** **Path to production: ship the current scope, then revisit the guest definition and pass extension** (repeat purchase extending an active pass, multi-visit, future start).
- **D74.** **Verification Chancy owns before the model is final:** (a) test whether M\&O accepts a prospect created with a future begin/end range; (b) check whether DT alerts or refuses when a prospect checks in before the begin date; (c) reconvene with Terry Smith at 7 pm to finalise the catalog-item fields and tables; (d) get the UI change (drop the picker, add days-to-use copy) to Mark.

## 1. Problem and goals

### Problem

- Prospects are people the club already knows (person record, Ignite member ID, barcode, often an email) who buy short-term passes, take classes, and visit without a membership. Today they must re-enter billing details on every purchase because wallet support is reserved for members holding a membership agreement (D33). \[PRD #2\]
- Prospects cannot transact at all in the IGNITE Engagement (IE) mobile app: no day-pass purchase, no class-package purchase, no stored payment method. This blocks unified mobile on IE. \[PRD #1\]
- Point of Sale recognises prospects but deliberately creates a transient user (`id = 'doesNotExist'`) with no wallet owner, so every prospect sale is a guest-like checkout; conversion cannot reuse what was already collected. \[PRD #2\]
- Clients want consumers who buy passes up to a month long to become prospects in the system, not just single-day buyers. \[Slack\]
- Online, a returning pass buyer has no frictionless way to be recognised and re-purchase; the benchmark (Iron 24) is "buy once, stay logged in, buy again and again." \[Iron 24 caption\]
- The likely repeat buyer is a **returning out-of-area visitor** (someone who comes back to the area), not an ex-member; ex-members must still be able to buy. (D2) These buyers are largely **fitness explorers** who want to visit clubs when and where it suits them. (D29)

### Goals

1. Let a known prospect store billing information once and reuse it for later purchases without becoming a member, and carry that same wallet forward if they convert. \[PRD #2\]
2. Make prospects able to transact in the engagement app: buy short-term passes and class packages end to end, hold a stored payment method (card on file — D7), and **manage it in the app** (view, add, replace/update, remove) (D17). \[PRD #1\]
3. Do this without allocating a membership agreement number early (D33), duplicating payment methods, or exposing one prospect's payment methods to another. \[PRD #2\]
4. Give repeat buyers a frictionless re-purchase path on web and in app so re-purchase is near one-tap: passwordless one-time code emailed to the address used as the lookup key (D35), with a **returning buyer on a known device seeing nothing but Pay** (D26). \[Passwordless note, Iron 24\]
5. Treat any short-term pass buyer (1 day to \~1 month) as a prospect so clubs can market to and convert them. \[Slack\]
6. Optimise the pass journey for **membership conversion**, not casual pass revenue: pass pricing is intentionally set so the economic path is conversion (D16). In v1 **pricing does the conversion work; in-app nudges toward membership are a future consideration** (D29).
7. Give every pass buyer a **scannable QR credential** at purchase, persistent in the app, so "buy right before walking in" works at the desk (D18). **v1: a static QR of the prospect's barcode, delivered by email only (D51, D63).**

### Why this matters

- A known, verified prospect record for every pass buyer, which is the raw material for conversion. (D16)
- Faster front-desk and self-service checkout because the card is already on file and the pass is a scannable credential. (D18)
- Class and event purchase by non-members in club systems and in the engagement app.
- A cleaner path to membership because the billing method already belongs to the same person. \[PRD #2\]
- Repeat day-pass and drop-in revenue from returning visitors is a by-product, not the objective. (D16)

## 2. Personas

**Glossary (D31–D33).** **Guest** — anyone buying a pass, on any channel (web, mobile, desk); anonymous (no phone/email) only at the desk (D31). **Prospect** — a person with a contact who could join the club, could take a trial membership, or should be followed up with about joining; a sales-lead record status, not merely an identified guest (D32). **Member** — holds a membership agreement for a defined term; when it ends or is cancelled, returns to Prospect with the wallet suspended (D8, D33). **VPD** — virtual private domain; the tenancy boundary of a club operator within ABC (D36). **DataTrak (DT)** — ABC's operator system for the club, called M\&O elsewhere in this PRD; club settings, catalog items, email types, prospect records, barcodes and check-in live here (v3.5). **Barcode** — the unique 12-character access identifier DT assigns to every prospect and member; the day-pass QR encodes it (D51, D63). **Myko / MICO** — the ABC-hosted consumer web property the Guest Pass page forks from as a new standalone URL (D60); Online Join (OJ) is the existing hosted membership sign-up and is *not* where the day pass lives.

*[Table lives on the Miro board](https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683208013421)*


**Changes to the personas table above since v1** (rows 1, 4, 6 also edited in place):

- *Prospect → **Fitness explorer, first-time short-term pass buyer** (D29):* row 1 now leads with the D32 sales-lead definition; persisted once email is verified or payment completes (D9, D35); mobile required (D37); self-purchase only (D13); 18\+ online (D23); receives a QR (D18).
- *Returning buyer → **Fitness explorer, returning (out-of-area visitor)** (D2, D29):* nothing but Pay on a known device (D26); email plus an emailed code from a new device (D35, D10); QR in the app (D18); one record and one wallet across clubs in a VPD (D28).
- *New — Ex-member (reverse-converted):* buys a pass on the same record; wallet suspended, not deleted; consent tap reactivates it (D8).
- *Prospect in the engagement app:* manages the wallet — view/add/replace/remove (D17) — and holds the QR (D18).
- *Member:* row 4 rewritten in place — membership agreement for a defined term, never "permanent"; back to Prospect at term end or cancellation (D33). **Does not buy short-term passes in this version — blocked** (D2, D12).
- *Front-desk staff:* scan the QR against POS-item dates (D1, D18); see waiver status (D24) and the app-updated wallet (D17); dedicated role with audit trail (D26).
- *Guest — **pass buyer on any channel** (D30, D31):* row 6 updated in place; anonymous only at the desk; becomes a Prospect once a contact is shared.
- *New — Payer for someone else (out of scope)* (D13); *Minor (out of scope online)* (D23).

## 3. User journeys

### J1 — First online short-term pass purchase (web / online join or app) — primary journey (D5)

1. Consumer chooses a short-term pass (1 day up to \~1 month) on the club's online join page or in the app. The page is the standalone ABC-hosted Guest Pass URL (D60); it lists every catalog item the club has flagged "Guest pass online" with its price (D61, D68) — today one item. **No date picker (D71): the pass starts when it is bought; the page says "You have X days to use this pass" with X from the item's contract days.** In v1 the prospect's begin date = purchase date, expiration = begin + contract days − 1, visits = 1 (D48, D62, D71, D72); access is enforced by those prospect fields, the catalog item carries the money. \[Slack\]
2. Enters **email** — sole identifier and lookup key (D35) — plus name and **mobile (required, D37)**. No age checkbox in v1 (D66; minimum age later via the M\&O setting — D40). Lookup runs **inside the club's VPD only** (D36); no match = new visitor; a match only decorates ("Welcome back, Jordan", prefilled) — login and signup are one step (D35). An active, frozen, past-due, or banned member is blocked with a club-configurable message (D12). Web/app always capture a contact, so every web/app guest becomes a prospect at OTP or payment; anonymous guest sale is desk-only (D31, FR-P17). Email field: "We'll email you a one-time code and your receipt" (D35); mobile field: transactional-SMS notice (D37); the legal-written single marketing/SMS opt-in checkbox, long text in a modal, value passed on the create call (D32, D67).
3. Verifies possession with a 6-digit code **sent by email** (D35). On verification the person is persisted as a prospect (member UUID, `PROSP` agreement, PROSPECT type) and the Universal Wallet owner/authorized user is initialised by member UUID. (D9) A first-time buyer sees **one code** here and **one 3DS challenge** at payment — nothing more (D26).
4. Accepts the club waiver (single checkbox) if the club requires one for passes — a pass-checkout requirement, not a wallet item (D14). The waiver text comes from the club's DT prospect configuration (D50). **In v1 the waiver and Pass Terms are presented on every purchase** (D53); once-per-club with version re-sign (D24) is deferred. Sees Pass Terms, including the no-refund policy (D15, D22), and the proposed Tier 0/1 consent copy (§4.5, pending counsel).
5. Pays on the **Commerce Pay Page** (D38). Optionally opts in to save the card (default off) — card on file is in scope (D7). Sequence is verify → persist person → init wallet → collect payment → fulfil; the person record is kept if a later step fails (D9). \[PRD #2 lifecycle; PRD #1 UC "trial pass"\]
6. **Sees "we've emailed your QR code for club access"** — no QR on the page (D63). The BFF creates the prospect in DT with begin date = today and expiration/visits from the item (D48, D62, D71), takes the payment, and deactivates the prospect if payment fails (D65). On success DT sends the **prospect email** — a **static QR of the barcode**, the pass date, and the text of every acknowledgement the buyer made (D52, D63) — plus the existing POS receipt email. At the club, **scanning the QR is a barcode scan**; check-in admits when today is within the prospect's begin/expiration dates and refuses otherwise (D48). Email lookup / barcode search is the staff fallback. The app's persistent QR and the "View your pass" page follow later (D51, D57). \[PRD #2 UC5\]

### J2 — Returning buyer re-purchases (the Iron 24 benchmark)

1. **On a known device:** the buyer is recognised by the trusted-device binding and goes straight to Pay — no code (D26; D20 working assumption: 30-day web session refreshed on purchase; app indefinite with biometric/OS re-auth).
2. **On a new device:** enters email (D35); a one-time code arrives by email and is entered inline — the same step as a new user (D35).
3. Session binds to the member ID; the wallet resolves exactly as it does at the desk and in the app. \[Passwordless note\]
4. On a **new device**, a step-up check (last-4 of the stored card; no SMS codes — D35/D37) runs before the stored card is exposed or charged (D10, D26). On a recognised device the stored card is presented directly.
5. The buyer re-accepts Pass Terms and the waiver (every purchase in v1 — D53); if the card on file has expired the Pay Page offers a different card (D53). One confirmation completes the purchase; the existing prospect's begin/expiration dates and visits are repainted from the purchase date and item (D48, D62, D71); the pass email with the QR is sent (D52, D63). Front desk and app show the same saved card, not two wallets. \[PRD #2 UC1, UC3\]

### J3 — Front desk sells a pass or class to a known prospect — or to a guest (D30)

Staff scan barcode or search the prospect, sell the pass/class in POS, confirm the stored method (plus any required signature, waiver, or consent) in seconds. The desk sees the wallet **as the prospect last updated it in the app** (D17) and the current **waiver status** — signed for this club and current version, or needs signature (D24). The pass POS item carries its start/end dates for check-in (D1); the QR is issued and scanned against those dates (D18). Staff act under a dedicated prospect-wallet role with audit trail (D26). The prospect never receives a membership agreement number and is not billed on a membership schedule (D33). If the person is an active, frozen, past-due, or banned member, POS blocks the pass sale (D12). \[PRD #2 UC1, UC5\] **Guest path (D30, D31):** every walk-in buyer is a guest; for one with no record, staff ask for an email (and mobile — D35, D37). **Provided** → prospect path (record, wallet, QR). **Declined** → sell as an **anonymous guest** (desk only — D31): no record, wallet, or persistent QR; printed receipt only, stating the benefits of sharing a contact. A guest who gives a contact on a later visit becomes a prospect from then; earlier guest sales are not linked.

### J4 — Prospect books a class or event they don't have access to

In the app, the prospect opens the schedule, book-and-pays for an eligible non-member product (single class, class package, event) with the stored wallet. Confirmation, cancellation, rebook all use the same person and method. If club policy requires an in-person first visit, the first payment may occur at the desk and the app reuses the wallet afterwards. \[PRD #1 class package UC; PRD #2 UC2, UC7\]

### J5 — Prospect manages stored payment method in the app (D17)

Signed-in prospect opens payment methods and sees the card on file owned by their member ID (D7). In the app they can **view, add, replace/update, and remove** payment methods (D17). Viewing, using, or managing a stored card from a new device requires step-up (D10, D26). On the **web** the prospect can **add** a payment method during checkout (at minimum; wider web management not asserted — D17). The **front desk sees the updated information** on the next lookup (D17). \[PRD #2 UC6, H10\] (C2 closed.)

### J6 — Prospect converts to member

Staff (or online join) convert the prospect. The existing wallet owner, authorized user, tokens, and entries remain; metadata is updated with the membership agreement number (D33); billing-account/payor relationships are added only after RCM owns the agreement. The app continues to show the same saved method. Conversion is an identity and billing-role upgrade, not a new payment identity. **Any unused time on an active pass is lost at conversion — no credit, no refund, no delayed start** (D12). In v1 the path here is the club's pricing and the desk, not in-app nudges (D29). \[PRD #2 UC4\]

### J7 — Prospect with an abandoned or incomplete join still buys

A person who started a join path, or was entered after a tour, can still buy eligible items (day pass, class pack, single class, limited event) on the prospect wallet; lack of an agreement does not force guest checkout. A web/app visitor who verified contact but abandoned before payment is already persisted as a prospect (D9). Existing prospects already have a wallet owner from the backfill (D25). \[PRD #2 UC7\]

### J8 — Member is reverse-converted, later returns as a pass buyer (D8, D2)

A member's agreement ends and they are converted back to prospect. The wallet is **suspended**: owner and authorized user stay live, entries go inactive with tokens retained, agreement roles are stripped, billing pointers cleared. Months later the ex-member buys a pass (web, app, or desk) on the same person record; on first stored-credential use they see a consent tap that reactivates the card. No second identity, no re-enrolment of the card.

### J9 — Member attempts to buy a pass (blocked) (D12)

An active, frozen, past-due, or banned member who reaches a pass checkout (web, app, or POS) is blocked. The message is club-configurable (e.g. "You already have access — see the front desk"). No pass POS item is created. Members buying passes for friends or family is not a v1 path (D2, D13).

### J10 — Same explorer visits a second club in the same VPD (D28)

A prospect who bought a pass at club A buys one at club B inside the same ABC VPD. Email resolves inside the VPD (D36) to the **same person record and the same wallet** (D28); no second prospect, no second card entry. The waiver is per club, so club B's waiver is presented if B requires one (D24). How club B's channels and staff are authorised to see and charge that wallet (token/merchant-account scoping) is an engineering design item (see *Still open*).

### J11 — Pass refund or chargeback (D22)

There is no online refund flow. If a club chooses to refund a pass, staff do it **in-club through existing POS tools**. Chargebacks follow the existing operational process; nothing is built for them in v1.

## 4. Functional requirements

### 4.1 Wallet and identity (from PRD \#2, FR1–FR12, kept verbatim in substance)

- **FR-W1** M\&O must create or resolve prospect wallet identity by member UUID only for wallet-enabled home clubs, within the ABC VPD tenancy boundary (D11). One person across clubs in the VPD resolves to one member UUID and one wallet (D28).
- **FR-W2** M\&O must support adding and viewing the prospect's permitted wallet entries from the agreed prospect user experience, including POS for day-pass and class/event sales, and must **display wallet changes made by the prospect in the app** (D17).
- **FR-W3** M\&O must not create billing-account or payor ownership for a prospect.
- **FR-W4** M\&O must not assign PRIMARY, ALTERNATE, CLUB\_ACCOUNT, or CARD\_ON\_FILE agreement roles until product defines which roles are valid before conversion. Repeat retail charges may use the person-owned wallet without those roles.
- **FR-W5** Prospect-to-member conversion must reuse the existing member owner, authorized user, tokens, and wallet entries.
- **FR-W6** Conversion must update wallet metadata to the membership agreement number (D33) without changing the member external ID.
- **FR-W7** Wallet-disabled clubs must retain existing prospect and conversion behaviour.
- **FR-W8** Existing member wallet and unidentified guest checkout behaviour must remain unchanged.
- **FR-W9** Prospect deletion, expiration, and merge must invoke an explicit wallet lifecycle policy (still open). **Reverse conversion policy is decided (D8):** suspend the wallet — owner/user stay live, entries inactive, tokens retained, agreement roles stripped; reactivation is a consent tap on first stored-credential use. abc-core `convertToProspect` must stop deactivating/unmapping the wallet for wallet-enabled clubs.
- **FR-W10** (D28) Within one ABC VPD, a person known at two clubs is **one person record and one wallet**; the wallet is not duplicated per club. Remote-club *access* mechanics (how a non-home club's staff and channels are authorised to view/charge the wallet; token and merchant-account scoping) remain an engineering design item and stay disabled until designed. Cross-VPD access is out of scope (D11).
- **FR-W11** Engagement-app commerce for a signed-in prospect must resolve the same Universal Wallet owner by Ignite member ID that M\&O uses.
- **FR-W12** A payment method saved in M\&O must be selectable in the engagement app, and vice versa, for the same prospect; a method added, replaced, or removed in the app is reflected at the desk (D17).
- **FR-W13** (D6) The wallet API contract exposed to every channel is keyed by **person UUID**. The AccountInfoID/Commerce dependency (PRD #1) is satisfied underneath that contract; both the M\&O/POS work (PRD #2) and the Commerce/eAPI work (PRD #1) are required.
- **FR-W14** (D25) **Backfill:** wallet owners/authorized users are **created for all existing prospects** at wallet-enabled clubs by a backfill job with reconciliation (idempotent by member UUID, no orphan records on failure — E3/E4). Includes remote-system record creation for dormant prospects. Volume and cost are an engineering estimate item; lazy creation is not the strategy.
- **FR-W15** (D26) Staff view and charge of prospect wallets requires a **dedicated security role** and writes an **audit trail** (who, which wallet, what action, when). Recommendation in §5A; role definition to be validated by engineering (Q7).

### 4.2 Engagement-app commerce (from PRD \#1)

- **FR-E1** Prospect can sign up for a trial pass, paid via POS down payment.
- **FR-E2** (D7, D17) Prospect holds a **card on file** in their wallet and can **manage** it in the app: **view, add, replace/update, remove**. Management from a new device requires step-up (D10, D26).
- **FR-E3** Prospect can use the stored payment method to purchase a class package when booking a class they don't have access to.
- **FR-E4** Wallet supports short-term pass purchase end to end, in app.
- **FR-E5** *(Replaced — D14, closes C3)* The wallet does **not** store documents. Waiver acceptance is a pass-checkout requirement (see FR-P9); waiver status is read by checkout, not stored on the wallet. The app **shows waiver status** for the club (D24).
- **FR-E6** (D18) The app holds the buyer's **persistent QR credential** for each active pass, with the validity dates shown; the payload rotates per §5A so a screenshot cannot be reused past its window (D26).
- **FR-E7** (D17) **Web (online join):** the prospect can **add** a payment method to the wallet during pass checkout, at minimum. Wider web management is not asserted (see *Still open*).

### 4.3 Short-term pass product (from Slack, online-join note, Iron 24, plus D1/D2/D12/D13/D15 and round 2)

- **FR-P1** "Short-term pass" covers passes from a single day up to approximately one month (day, multi-day, week, trial). Product copy and internal naming should use "short-term pass" rather than "day pass."
- **FR-P2** Any consumer who buys a short-term pass online (online join at onlinejoin.abcfitness.com, e.g. clubs 31239 and 31590 already sell them — pilot clubs, D27), in app, or at the desk **and provides an email** (D35) becomes a prospect (or is matched to an existing prospect) in the club's system — a sales lead the club may follow up with about joining (D32); a desk buyer who declines is an **anonymous guest** (FR-P17, D31). Persistence for web/app happens at OTP verification or payment, whichever comes first (D9).
- **FR-P3** A returning buyer must be able to re-purchase with no re-entry of profile or card details ("stay logged in and buy another one and another one"); on a known device this means no code either (D26).
- **FR-P4** (D21, D48, D71) **Start date — revised.** **No start-date picker in v1.** The prospect's **begin date = purchase date**; **expiration date = begin + the item's contract days − 1**; **number of visits from the item** (1 in v1 — D72). The page shows "You have X days to use this pass", X read from M\&O, never hard-coded (D71). A future begin date via the API is unsupported until Chancy's tests (D74) say otherwise. Applies to web and app.
- **FR-P5** (D1, D48, D61, D62, D70) The pass is a **POS sale of a catalog PRODUCT flagged "Guest pass online"** (D61, D70 — a product so unused passes are not carried as liabilities). The item carries the money — price, profit centre, per-item reporting — and its **contract days and number of visits**. Those are copied onto the prospect record at sale (begin, expiration, visits — D62), which is what check-in enforces. No separate entitlement object is created.
- **FR-P6** (D1, D48) **Validity window — decided for v1:** calendar day, not elapsed hours. The pass is valid on its begin date through its expiration date inclusive (the same day for a one-day pass), evaluated as club-local **dates**; DT has no time-based expiry, so a pass expiring today is usable all of today. Elapsed-hour windows are not built.
- **FR-P7** (D18, D48, D62, D72) **Check-in validation (v1: visits = 1, so the first check-in expires the prospect):** scanning the pass QR is a **barcode scan** of the prospect's barcode; existing DT check-in admits only when today is within the prospect's **begin/expiration dates and visits remain**, and refuses otherwise — whichever limit is hit first expires the record. Sharing the QR is therefore self-limiting (D62). No new check-in logic is built for v1. Barcode search / email lookup remains the staff fallback.
- **FR-P8** (D48) **Expiry:** after the prospect's expiration date the barcode no longer admits; the **maintenance server** expires the prospect (operational dependency — see risk watchlist). No lifecycle change beyond that (stays prospect) and the wallet is untouched. A repeat purchase repaints begin/expiration with the new pick (D53). No automatic renewal: the day-pass item must never carry a renewal flag.
- **FR-P9** (D14, D24, D50, D53) **Waiver:** if the club requires a waiver for passes, acceptance is a checkout requirement for the pass sale (single distinct checkbox online; signature or equivalent at the desk). The text is the **waiver language configured in DT club settings** (D50). **v1: presented and accepted on every online purchase** (D53); once-per-person-per-club with version re-sign (D24) and desk/app waiver status are deferred. Waiver status is not stored on the wallet; the acknowledgement text is printed in the pass email (D52).
- **FR-P10** (D12) **Lifecycle block:** pass purchase is refused for active, frozen, past-due, and banned members in every channel (web, app, POS) with a club-configurable message. No override in v1.
- **FR-P11** (D12) **Conversion:** when a prospect with an active pass converts to membership, unused pass time is forfeited — no credit, refund, or delayed membership start. Pass Terms must say so.
- **FR-P12** (D13) **Self-purchase only:** the verified person is the payer and the pass-holder. No gifting, guardian, or household purchase in v1.
- **FR-P13** (D15, D22) **No refunds** on short-term passes as policy; stated in Pass Terms and in the confirmation. **No online refund flow is built.** Where a club chooses to refund, it does so in-club through existing POS tools. **Chargebacks follow the existing operational process; not a v1 build item.**
- **FR-P14** (D16, D29) Pass **pricing** is a club configuration; the product guidance is that passes are priced so that membership is the economic path. **In-app nudges toward membership ("apply toward a membership" prompts) are a future consideration, not v1.**
- **FR-P15** (D18, D51, D63) **QR credential:** every successful online pass purchase produces a **static QR code encoding the prospect's barcode, no timestamp**, sent in the pass email (D52) — the success page shows no QR and points to the email (D63). It is validated at the club as a barcode against the prospect's begin/expiration dates (FR-P7). The app's persistent QR and the rotating payload are deferred (D51, D57). Clubs **may** message buyers to download the club's app for the best experience; the app is **not** required to buy or to enter.
- **FR-P16** (D23, D40, D66) **Minimum age:** **no age checkbox on the page in v1** (D66). Enforcement later uses the existing M\&O minimum-age setting clubs configure for memberships; no DOB capture (D56). *Counsel question OPEN (D40):* waiver enforceability with no age gate.
- **FR-P17** (D30, D31) **Anonymous guest pass sale — desk only:** at the front desk a pass MAY be sold with **no contact captured**; it creates **no person record, no wallet**, no persistent QR (one-time printed credential acceptable); the receipt states the benefits of sharing a contact. Web and app **always capture a contact** — there is no anonymous web/app sale (D31).
- **FR-P18** (D35, D37, D38) Email = sole identifier and lookup key, verified by an emailed 6-digit code, no SMS OTP; mobile required (SMS notice separate from marketing opt-in; never an OTP channel); card capture only on the Commerce Pay Page (its fields/labels; no redesign).
- **FR-P19** (D50, D61) **DT configuration — guest pass online:** (a) on the **catalog item**, a **"Guest pass online" flag** that opens **contract days** and **number of visits**; any number of items may be flagged; **product** type (D70); (b) in **club settings → Online**, **waiver (liability) language** as inserted text beside the existing prospect terms. New columns on the catalog-item table (DBA); behind a LaunchDarkly flag; flag off = existing behaviour. No club-level item picker and no enable switch — an unflagged catalog is an unenabled club.
- **FR-P20** (D52) **Pass email:** the existing DT **prospect email type** carries the QR of the barcode, the pass date, and the text of each acknowledgement the buyer made (18\+, Pass Terms, waiver). The existing POS purchase receipt email continues to be sent. No new email type in v1.
- **FR-P21** (D51, D63) **Barcode → QR:** the QR encodes the prospect's 12-character barcode as a plain string, no timestamp. **DT is the sole renderer**, in the prospect email, using the engagement team's QR library (D69). Nothing else renders a pass QR in v1. The QR is not a new identifier and is not a wallet concern.
- **FR-P22** (D53, D66) **Re-acknowledgement:** Pass Terms and waiver on every purchase; the returning lane offers a different card when the card on file has expired.
- **FR-P23** (D54) **OTP entry:** the code field opens the numeric keyboard on mobile (`inputmode="numeric"`).
- **FR-P24** (D60) **Hosting:** the Guest Pass flow is a standalone ABC-hosted URL forked off Myko, embeddable by the club as a "Buy a day pass" call to action; it is not part of Online Join. Enterprise clubs use the API package instead.
- **FR-P25** (D62) **Create call:** the prospect create/update call carries begin date, expiration date, number of visits (from the item), the marketing/SMS opt-in value (D67), the flagged catalog item, and the wallet token; the club's default prospect (free-trial) settings are not used.
- **FR-P26** (D64) **Configuration read:** the page reads flagged items, days/visits, prospect terms and waiver language directly from the DT database as Myko does; no enterprise-API change.
- **FR-P27** (D65) **Payment failure, v1:** prospect created, payment attempted, prospect deactivated on failure (existing M\&O pattern); the deactivate must propagate through the same webhooks as the create; card saved to the wallet only on a successful auth; attempts logged, not persisted as records; Cloudflare rate limiting on the endpoint. Target state (v2): no record unless payment succeeds.
- **FR-P28** (D67) **Marketing/SMS opt-in:** the legal-written single checkbox with the long text in a mobile-friendly modal; value passed on the create call whether checked or not.

### 4.4 Failure handling (PRD \#2, updated for D9)

- Sequence for web/app: verify contact → persist person → initialise wallet → collect payment → fulfil (D9).
- Verification failure (no code entered / expired / locked out per §5A): nothing is persisted.
- Prospect persistence failure after verification: do not create a wallet identity; show a retryable error.
- Wallet identity creation failure after prospect persistence: **keep the valid prospect**, show a retryable wallet error, do not claim the method was saved (D9).
- Payment failure after wallet initialisation: **keep the person and the wallet owner** in the BFF (D9); **in DT the prospect record created for the attempt is deactivated** (D65) and the deactivate propagates to CRMs through the same webhooks as the create; no pass sale is recorded; no card is stored.
- Payment method save failure with a successful purchase: fulfil the pass; keep the prospect and any pre-existing wallet entries unchanged; tell the buyer the card was not saved.
- QR issuance failure after a successful purchase: the sale stands; the buyer is told the pass is valid and can be found by name/phone at the desk; the QR is re-issued when the app or confirmation link is next opened (D18).
- Conversion failure before agreement commit: keep the prospect wallet and prospect metadata.
- Conversion failure after a remote wallet update: compensate or queue reconciliation.
- Backfill failure for a given prospect (D25): no partial owner; the record is retried by the reconciliation pass; the prospect remains sellable via existing behaviour until then.
- Duplicate requests: resolve by member external ID and return the existing owner/user/token/entry when the idempotency key matches.

### 4.5 Checkout consent — day pass (PROPOSED — not a PM decision)

PROPOSED — layout reviewed with counsel 2026-09-09 (no objection to layout; content not yet approved) — see Counsel Review Record https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683230797378. **REQ-CONSENT-TEMPLATES:** consent/terms templates must be versioned and configurable per product tier and per club (root cause of today's single highest-watermark text is an engineering constraint, not legal).

Summarises `consent_legal_research.md` §6. Prototypes: `prospect-wallet-demo-1b-consent.html` (counsel-reviewed layout) and the Director of Design HTML v1.2 (build source of truth — D46). The consent block and Pay sit in the Order Summary panel (D42); T\&C text comes from this section, not from the Pay Page (D43). Copy must reflect: **no 18\+ checkbox in v1** (D66; D40 open), waiver and Pass Terms **on every purchase in v1** (D53; once-per-club and version re-sign per D24 deferred), the legal-written marketing/SMS opt-in checkbox with its text in a modal (D67), waiver text from DT club settings (D50), no online refunds (D22), email code (D35), mobile (D37), Pay Page (D38), receipt per memo §7 (D41). **Legal requirement recorded 2026-09-10 (Chancy):** everything the buyer ticked — Pass Terms, waiver, opt-in — must also be printed in the email the buyer receives (D52). Kelly is taking the modal layout to legal with a mockup; Twilio's earlier objection to modal placement is a known risk (D67).

- **Tier 0 — one-time pass, card not saved.** No checkbox for the purchase. A matched disclosure sentence sits immediately above the primary button in body-size type: "By tapping **Pay $20**, you agree to \[Club\]'s \[Pass Terms\] and acknowledge the \[Privacy Notice\]. Your pass is valid \[dates\]. Refunds: none (D15)." Button text echoes the sentence. Pass Terms and Privacy Notice open in dismissible sheets; nothing is gated on opening or scrolling. At the email field: the **transactional notice** "We'll email you a one-time code and your receipt" (D35); at the mobile field a **transactional-SMS notice** (D37); and a **separate, unchecked opt-in** — "Keep me posted about joining Riverside" — for texts, emails, or calls about joining; marketing follow-up requires this opt-in, not the transactional notice (D32). **18\+ self-attestation** as a short line or checkbox (D23). If the club requires a waiver, it is its own **single checkbox** ("I've read and agree to the \[Facility Waiver\]") — D14 — shown only if the person has not signed this club's current waiver version (D24). *Open for counsel:* waiver inside the "By tapping Pay" sentence (memo §6: separate checkbox).
- **Tier 1 — pass plus save card.** Everything in Tier 0 plus a **save-card toggle, default off**, carrying the four Visa/Mastercard stored-credential elements: truncated card (last 4), how the credential will be used (only when the buyer chooses to buy and confirms), how the buyer is told of changes, how to remove it (in the app — D17). No automatic or recurring charges. (Aligns with D7.)
- **Not applicable to card-paid passes:** the Authorization Terms document (EFT/PAD authorization, pre-notification waivers, varying-amount notice) and the E-SIGN consumer-consent paragraph.
- **Tier 2 — membership / recurring billing:** the current full document stack stays (written agreement and copy, statutory cancellation notices, auto-renewal consent, Reg E / Payments Canada H1 if bank debit, E-SIGN consent, French-first in Quebec). A pass SKU must never escalate silently into Tier 2 (FR-P8).
- **Questions for ABC legal counsel before this is adopted:** (1) whether a short pass is a covered "health studio"/"health club" contract in California and New York (and IL, OH, MA) requiring the statutory cancellation sentence and an emailed copy; (2) Ontario over-$50 distance-contract and personal-development-services regimes (price switch, not product switch) and Quebec CPA ss. 197–205 applicability plus 15-day copy; (3) Quebec French-first delivery of all adhesion terms (Charter s. 55); (4) whether ABC is merchant of record or a payment facilitator/agent for the club, which determines whose name appears in the stored-credential consent, receipt, and privacy notice; (5) current Visa/Mastercard stored-credential text from ABC's acquirer; (6) waiver enforceability by state when presented as a separate checkbox, given the 18\+ self-attestation gate (D23) and version re-sign (D24); (7) whether self-attestation alone is sufficient age verification for the states/provinces in scope.

### 4.6 DataTrak (M\&O) enablement — guest pass online (D48–D53, D59–D69) — rewritten in v3.6

**Purpose.** What already exists in DT, what is built for v1, how the pieces run, and how a club switches it on. *(Round 7: product not service; no date picker; single-visit first — D70–D72.)* Owners: Chancy (DT), Bjorn (Guest Pass page and OTP), Mark (BFF, API package, design), PK (DT PR review), Terry Smith (DBA).

**Already in DT — reuse, do not rebuild**

- Prospect configuration in club settings: default contract days, default visits, campaigns — these serve the **free trial** ("Get a guest pass") and are **not** used by the paid pass (D62).
- Prospect terms text, configurable per club under club settings → Online, already in the prospect email; readable directly from the database (D64).
- Prospect creation assigns a unique 12-character barcode and returns it with the agreement number; the create call already accepts begin date, expiration date, visits and the marketing opt-in flag (D62, D67).
- Email types (setup → Email types): the **prospect** email and the **POS purchase receipt** email; links are allowed in the body.
- Check-in and the door file enforce the prospect's begin date, expiration date and visit count; whichever is exhausted first expires the record (D62).
- The maintenance server expires prospects.
- M\&O minimum-age setting for memberships (future model for age — D66).
- Existing M\&O behaviour on failed payment: create the profile, attempt payment, deactivate on failure (D65).

**Built for v1**

1. **Catalog item (Chancy):** on **products** (D70), new flag **"Guest pass online"** (working name); when on, the item shows **contract days** and **number of visits**. Columns on the catalog-item table — DBA ticket to Terry Smith; if the table is common-use the change runs at night; "tonight at the latest" (D61, D69).
2. **Club settings → Online (Chancy):** **waiver (liability) language** text field beside the existing prospect terms (D50). The earlier club-level "day pass item" field is removed and was never requested from the DBA (D61).
3. **Prospect email type (Chancy):** static QR of the barcode (engagement team's QR library — D69), the pass date, and every non-null acknowledgement/terms field; no 18\+ line (D52, D63, D66).
4. **OTP email template (Chancy → Bjorn):** HTML template with the code injected by the BFF; club name only (D59).
5. **Guest Pass page (Bjorn, design Mark):** standalone URL forked off Myko (D60); lists flagged items with prices (D68); OTP with numeric keypad and a 5-minute timer (D54, D59); name, email, mobile; **no date picker — "You have X days to use this pass" from the item's contract days (D71)**; Pass Terms, waiver, and the legal opt-in checkbox with a modal (D53, D67); Pay Page (D38, D44); success page says the QR was emailed (D63). Reads configuration straight from the DT database (D64).
6. **BFF (Mark):** create call with begin = today, expiration = today + contract days − 1, visits from the item (1 in v1), opt-in, item, wallet token (D62, D71, D72); create → pay → deactivate-on-failure (D65); save card only on successful auth; attempt logging; Cloudflare rate limiting.
7. **LaunchDarkly flag** for the whole path; off = existing behaviour (D50, D55).

**Runtime sequence (page → BFF → DT)**

1. Buyer lands on the club's "Buy a day pass" link → Guest Pass page shows the flagged items and prices.
2. Enters email → BFF issues a 6-digit code (5-minute expiry, 2 sends/hour — D58) → OTP email from Chancy's template → code entered on a numeric keypad.
3. New buyer: name, mobile; returning buyer: recognised, details prefilled. Picks the pass; sees "You have X days to use this pass" (D71). Ticks Pass Terms, waiver, and the opt-in (or not). Card on the Pay Page; optional save-card.
4. BFF creates the prospect in DT (begin = today; expiration and visits from the item; opt-in value; item), then takes payment. Failure → deactivate the prospect, offer another payment method (D65). Success → save the card to the wallet if requested (D45).
5. DT sends the prospect email with the QR, pass date and acknowledgement text, plus the POS receipt (D52, D63).
6. Success page: "We've emailed your QR code for club access." No QR on the page (D63).
7. At the club: scan the QR → check-in admits within begin/expiration with visits remaining, refuses otherwise (D62); with visits = 1 the first check-in expires the prospect (D72). Barcode search / email lookup is the staff fallback.

**Club configuration steps (for the enablement guide and product marketing)**

1. Create the catalog **product** you want to sell (D70): v1 = a single-visit day pass, e.g. Day Pass $25 — contract days 1, visits 1. Turn on **Guest pass online** and set days and visits. (Multi-day / multi-visit items are tabled — D72.)
2. Club settings → Online: paste the waiver language; review the prospect terms.
3. Setup → Email types: review the prospect email greeting and footer.
4. Add a **Buy a day pass** button on the club website pointing at the ABC-hosted Guest Pass URL (enterprise: use the API package instead).
5. Confirm the maintenance server is running.

## 5. Identity and authentication

**Approach accepted (D19, D35; was "recommended, owner TBD" — D4a):** passwordless one-time code **by email only**, inline on the same page; no SMS OTP (D35). Security posture and its owner are in §5A (D26); session lifetime is owned by engineering (D20).

- **Lookup key is the email address** — sole identifier and unique lookup key (D35; supersedes D3/D19). New and returning users take one step: email → emailed code → code; login and signup are one action, recognition only decorates ("Welcome back, Jordan"). Every user verifies the email. Mobile is required but never an OTP channel (D37).
- **Possession only identifies; it does not authorize** (D10, D26, D35). The code proves control of the channel; the session then binds to the **member ID**; the wallet resolves exactly as it does at the desk and in the app (Universal Wallet owner by Ignite member UUID — consistent with PRD #2's identity model and its rule that email/phone/barcode/PROSP are never identity).
- **Step-up before exposing stored credentials from a new device** (D10). Mechanism decided by recommendation (D26): **last-4 of a stored card** (no second-channel SMS code — D35/D37), before any stored card is displayed or charged.
- **Trusted device** (D26): a signed device cookie (web) or app-instance binding lets a returning buyer skip the code for N days. **Session lifetime — working assumption (D20, owner engineering):** 30-day web session refreshed on each purchase; app session indefinite with biometric/OS re-auth. Final numbers are engineering's call.
- **One OTP issuer shared by web and app** (D10). Web (online join) and the engagement app use the same issuance, verification, rate-limiting, and audit service. Closes Q21.
- **Tenancy (D11, D28, D36):** "VPD of ABC is the proper tenancy." The email lookup runs inside the club's VPD and **never surfaces another operator's record** (D36); **the same person at two clubs in one VPD is one person record and one wallet** (D28). Remote-club access mechanics remain an engineering design item (FR-W10).
- Fails gracefully: no match simply means "new visitor" (D35).
- **Email-only — decided (D35):** the only lookup key and code channel; D19's club-configurable channel is withdrawn.
- **Passkeys** in the app are the fast-follow that removes OTP entirely for returning users (D26).
- Figma "OJ Design" is a board reference only, not design evidence (D4b).

**Identity model (PRD #2, adopted):** Organization and Location = home club's Universal Wallet org/location within the ABC VPD (D11); Owner type MEMBER; Authorized user type MEMBER; External ID = Ignite member ID. Never use as identity: `PROSP`, home-club number \+ `PROSP`, a temporary/preallocated agreement number, prospect email, phone number, or barcode.

**Prospect wallet metadata (PRD #2):** store Ignite member ID, M\&O VPD ID, home club number, lifecycle status PROSPECT, membership type code PROSPECT (if supported). Do not set a membership agreement number (vs. the `PROSP` placeholder) or member-number metadata until conversion (D33); if a downstream schema requires them it must accept null or a non-identifying value, and no search/dedup/authorization may use that value.

**Open (identity):** multiple candidate records for one email (household sharing, duplicates inside the VPD — chooser and second factor per §5A, but the duplicate-resolution rule is open); remote-club access mechanics inside the VPD (FR-W10); recovery when the email changes; final session-lifetime numbers (engineering — D20); consent/stored-credential language differences app vs desk vs web (PRD #2 Q15 — proposal in §4.5 pending counsel).

## 5A. Security \& fraud posture (recommended) (D26)

**Owner: product (Kelly Card), engineering to validate. Status: recommendation for PM approval — not delegated to another team.** The bar is Shop Pay / Stripe Link: recognise a returning buyer from an email (D35), authenticate once, prefill everything, and on a known device show nothing but Pay. Every control below is chosen so that a **first-time buyer sees exactly one code and one 3DS challenge**, and a **returning buyer on a known device sees nothing but Pay**. Security that the honest buyer never notices is the point.

1. **Email OTP design (D35, D58).** Built in the BFF (D58). 6 digits, **5-minute expiry** (D58), single use. 5 wrong attempts locks that address for 15 minutes and invalidates the code. Rate limits: **2 sends per address per hour** (D58; the UI shows when a resend is available and lets the buyer correct the address without consuming a send), 20 per IP per hour, with a per-device cap in the app; **disposable-domain checks** on the address. Responses are generic ("if that address is on file, a code is on its way") so the lookup never confirms whether a record exists. There is no SMS channel and therefore no SMS fallback path.
2. **Possession is not authorization.** An email match only *identifies* a candidate (D35). Binding to the person record happens **after** the OTP. On a **new device** the buyer must pass one **step-up — last-4 of a stored card (no SMS codes — D35/D37) — before any stored card is displayed or charged**. If more than one record matches, show first-name choices and run the step-up against the chosen record; never list private details.
3. **Trusted device.** After a successful purchase, bind the device: a signed, HttpOnly cookie on web; app-instance binding in the app. A returning buyer on a bound device **skips OTP for N days** (working assumption 30 on web, indefinite in-app behind biometric/OS re-auth — D20). Binding is revoked on contact-detail change, failed step-up, or staff request.
4. **Card testing.** Enforce **processor-side velocity limits per card fingerprint, per IP, and per device**; require **AVS and CVV** on every new card; run **3DS/SCA on the FIRST purchase from a new device only — never on trusted-device repeat purchases**. Alert on decline-rate spikes per club; auto-raise 3DS scope for that club while the spike lasts.
5. **SMS pumping — retired for OTP (D35).** No code goes by SMS, so 10DLC, destination allowlists and OTP SMS-spend controls are out of scope; operational texts (D37) keep a per-number daily cap and spend-anomaly alert.
6. **QR credential.** **v1 (D51, D63): a static QR of the prospect's barcode, no timestamp, delivered only in the email**; its exposure is bounded by the prospect's dates and visit count — a shared QR spends the buyer's own visit (D62). Target state (deferred — D57): a **signed, rotating payload** (refreshes on a short window, e.g. every 60 seconds, in the app and on the View-your-pass web page — D41) so a screenshot cannot be reused past its window; the desk scanner validates the signature and flags a second scan of a single-visit pass.
7. **Card data.** **Masked PAN everywhere** — app, web, desk, receipts. Tokenised via the Commerce Pay Page (D38); **no PAN or CVV in logs, events, or analytics**. Online Join stays out of PAN scope.
8. **Staff access.** A **dedicated role** for viewing and charging prospect wallets, separate from general POS; every view and charge writes an **audit record** (staff ID, member UUID, action, time). Closes the direction on Q7.
9. **Fast-follow: passkeys in the app.** Once a buyer has purchased once, offer a passkey; from then on the app needs **no OTP at all** for returning users, and the trusted-device cookie becomes the web fallback rather than the primary path.
10. **Consent logging (D32).** Log the email and SMS notices (D35, D37) and the **separate marketing opt-in** as distinct events (person UUID, channel, copy version, timestamp, surface). Follow-up about joining reads only the marketing opt-in. Anonymous desk guests have no record, so no consent record (D31).

What the user feels: first visit — enter email and mobile, one emailed code, pay with one 3DS tap, see a QR. Every visit after that on the same phone — open the app, tap Pay, show the QR. That is the Shop Pay / Stripe Link experience, and it is what these controls buy.

## 6. Prospect / member state model

*[Table lives on the Miro board](https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683208013428)*


**Changes to the state model above since v1 (D1, D2, D8, D9, D12, D17, D18, D24–D26, D28, D30–D33, D35, D36):**

- *New pre-state — **Anonymous guest (desk only, no record)** (D30, D31):* desk pass sold with no contact → no person record or wallet, POS item only, one-time credential; becomes **Prospect** on contact capture (at sale or a later visit; prior guest sales not linked in v1). Web/app always capture a contact, so no anonymous pre-state there.
- *New record:* web/app visitor persisted as **Prospect** at email-code verification or payment (D9, D35), lookup VPD-scoped (D36); wallet owner initialised after persistence; card stored only on opt-in (D7); a verified visitor who abandons is still a prospect (lead). OTP skipped on a trusted device (D26); step-up on a new device (D10).
- *New rows:* existing prospect before launch — wallet owner created by the backfill (D25); same person at a second club in the VPD — same record, one wallet, club waiver if required (D28, D24); prospect changes payment method in the app — reflected at the desk (D17).
- *Pass expiry (v3.6 — D48, D62):* the prospect's **expiration date passes or visits are used up**, whichever first; person stays Prospect, wallet retained, check-in refuses the barcode/QR (FR-P7). A repeat purchase repaints begin/expiration/visits (D53, D62). A QR is emailed on every purchase (D18, D63).
- *Failed payment (v3.6 — D65):* DT prospect created for the attempt is **deactivated**; the deactivate follows the create through the webhooks. Target state: no record without a successful auth.
- *Conversion to member:* **Member** holds a membership agreement number for a defined term (D33); same wallet reused; **unused pass time forfeited** (D12).
- *Member attempts to buy a pass* (active, frozen, past-due, banned, or matched during online purchase): **blocked** with a club-configurable message; wallet untouched, no POS item (D2, D12).
- *Reverse conversion:* trigger is **agreement term ends or cancelled** (D33); wallet **suspended, never deleted** — owner/user live, entries inactive, tokens retained, roles stripped, billing pointers cleared; abc-core deactivate/unmap replaced (D8). *Ex-member buys a pass:* stays Prospect; consent tap reactivates the card (D2, D8).
- Unchanged: repeat purchases stay Prospect indefinitely; deletion/merge/expiry wallet policy open (Q5); failed creation creates no wallet identity.

## 7. Payments and wallet

- **Architecture (PRD #2, confirmed by D6):** person-owned Universal Wallet keyed by Ignite member UUID; `PROSP` is lifecycle state, not identity; POS must resolve a real owner/authorized user for prospects instead of `doesNotExist`; agreement-level roles/assignments deferred to conversion — a membership agreement number (vs. the `PROSP` placeholder) is set only then (D33); **the wallet follows the person record** — prospects and members have wallets, anonymous guests do not (D32); club-level enablement (`use_wallet_as_primary`, `read_from_wallet`) plus a club-scoped feature flag with existing behaviour as default.
- **Blocker — both diagnoses are right (D6, closes C1):** (a) PRD #1: the wallet is built on AccountInfoID, which assumes the person exists on Commerce; prospects don't exist on Commerce today — how Club Managed members get wallets without existing on Commerce first (Aaron's team) and ENGIN-4241 / EAPI-791 remain required work. (b) PRD #2: `PROSP` is shared metadata and POS deliberately returns `doesNotExist`; downstream contracts (Universal Wallet, Order Service, RCM, UPCT) need a spike. **Contract decision:** the wallet API contract is keyed by person UUID (FR-W13); AccountInfoID/Commerce is satisfied underneath it. One joint plan, two workstreams.
- **Channel parity (PRD #2 UC3, FR-W12):** one wallet across desk, POS, app, and web; **changes made in the app are what the desk sees** (D17).
- **In-club card on file (D55):** a prospect created through the online day pass has a wallet with a saved card, so card-on-file works for them at in-club POS from day one — an added benefit to state, not a separate build.
- **DT sale mechanics (D48, D61, D62):** the sale is a catalog item flagged "Guest pass online"; the item governs price, profit centre, per-item reporting, contract days and visits; those are copied to the prospect record at sale. Configuration per §4.6.
- **Failed payment (D65):** v1 create-then-deactivate; card saved only on successful auth; attempts logged; Cloudflare rate limiting against card testing. PK to confirm there is no payment-operations rule behind the pattern before v2 removes it.
- **Payment methods in scope:** **card on file is in scope** (D7, verbatim). **In-app management — view, add, replace/update, remove — is in scope (D17); web = add at minimum (D17).** Apple Pay / Google Pay and bank accounts remain open (PRD #2 Q2). **Pass-checkout save-card writes the Pay Page token to the prospect wallet — new capability (D45); the Pay Page embed reuses the membership online-join integration (D44); no saved-card dropdown for a first-time buyer (D44).**
- **Migration (D25):** **backfill** — create wallet owners for all existing prospects at wallet-enabled clubs with a reconciliation pass (FR-W14). Volume/cost estimate is an engineering item; the strategy is decided.
- **Tenancy (D28):** one person, one wallet across clubs within an ABC VPD; token/merchant-account scoping for remote-club charging is an engineering design item.
- **Trial pass down payment:** PRD #1 includes a trial pass paid via POS down payment.
- **Recurring billing (D4c):** membership dues require an RCM agreement, so prospects get no RCM billing account or payor until conversion (PRD #2). Recurring services purchase by a prospect is out of scope for v1 **as a priority call** (PRD #1), not because it is structurally impossible.
- **Reverse conversion (D8):** suspend, never delete — see FR-W9 and J8.
- **Refunds and chargebacks (D15, D22):** no refunds as policy; **no online refund flow**; club-discretion refunds happen in-club through existing POS tools; **chargebacks follow the existing operational process — not a v1 build item**.
- **Fraud posture (D26):** card-testing velocity limits, AVS/CVV, 3DS on first purchase from a new device only, masked PAN via the Pay Page (D38), no PAN/CVV in logs — see §5A.
- **Pricing and economics (D16, D29):** passes are cost-prohibitive on their own; pricing is set so that membership conversion is the economic path. In v1 pricing does that work; in-app membership nudges are a future consideration. The wallet's job in this use case is to make the *conversion* frictionless, not to maximise pass volume.
- **Current-state findings and code evidence** from PRD #2 (ProspectServiceTransactionsImpl, JdbcAgreementDao.insertProspectAgreement, JdbcMemberDao.insertProspectMember, FastAddDB, PosPayPageInitServiceBase, WalletEntryOwnerUserResolver, AgreementWalletRestfulFacadeBase, UpdateMemberDB CONVERT\_PROSPECT hook, abc-core MemberServiceImpl.convertToProspect, PS-2165, PS-2910, UPCT member-ID support) are preserved in full in the source doc and in the scrape appendix; they are the engineering baseline for this PRD.

## 8. Reporting, metrics, and acceptance criteria

### Success measures (PRD \#2)

- A payment method saved for a prospect is available on the next day-pass, class, or POS sale for that person.
- The same method is available in the engagement app without a second enrolment; a change made in the app is visible at the desk (D17).
- The method survives successful conversion.
- Conversion creates no duplicate owner, authorized user, token, or wallet entry.
- No wallet lookup uses `PROSP` as a unique identifier.
- Existing member wallet, guest checkout, and wallet-disabled club behaviour unchanged.
- Failed or abandoned prospect creation leaves no usable orphan wallet records; the backfill leaves no partial owners (D25).
- Every pass purchase yields a QR that validates at the desk against the POS item's dates (D18).

### Pilot and baselines (D27)

- **Pilot clubs: 31239 and 31590** (already selling online passes).
- **Baselines captured before build:** repeat-buyer share, time-to-purchase (first-time and returning), prospect-creation rate from online pass sales. Add for context: email-code deliverability and chargeback rate, since D35/D26 change them.
- **Success thresholds are set from those baselines**, not chosen in advance. Rollout beyond the two clubs is gated on hitting them.

### Additional product metrics (derived from board notes, re-weighted for D16)

- **Primary (D16):** prospect-to-member conversion rate and days-to-convert for short-term pass buyers vs the club's non-pass prospects; whether the wallet was reused at conversion.
- Share of short-term pass purchases by returning buyers completed with no re-entry of card details — split by **no code (trusted device)** vs **code** (D26).
- Time-to-purchase for returning buyers (web and app) vs first-time buyers (D27 baseline).
- Number of online short-term pass buyers persisted as prospects (per club), by pass length (1 day, 2–7 days, 8–30 days), and share that verified but abandoned before payment (D9).
- Passes purchased vs QR-redeemed; QR scan failures by reason (expired, not started, signature, reuse) (D18, D26).
- Email-OTP success rate and time-to-verify (D35); code-delivery failures and disposable-domain rejections.
- Card-testing signals: decline rate per club, 3DS challenge rate on first purchases, velocity-limit trips (D26).
- Ex-member pass purchases that reused a suspended wallet via consent tap (D8).
- Blocked member pass attempts per club (D12) — signal for messaging and for whether the block is too blunt.
- Under-18 attestation declines per club (D23).
- Desk checkout time for known prospects (PRD #2 UC5 target: closer to member card-on-file than guest checkout).
- Chargeback rate on passes (no refunds — D15; existing process — D22).
- App-download rate after purchase where the club uses the "download the app" message (D18).
- Backfill: prospects processed, reconciled, failed/retried (D25).

### Acceptance criteria (PRD \#2, IDs preserved; additions tagged)

High: H1 save method for new prospect; H6 stored method for repeat day pass; H7 stored method for class entry; H2 wallet preserved through conversion; E1 no cross-prospect access despite shared `PROSP`; E2 prospect state preserved on failed conversion; E3 no orphan wallet data. Medium: H3 add method for existing prospect; H4 convert prospect without wallet; E4 idempotent wallet creation; E5 wallet service failure handled; O1 wallet outcomes logged/metricked without exposing credentials; D1 flag-off behaviour preserved. Low: H5 member/guest behaviour unchanged; H8 desk-saved method reused in app; H9 app-saved method reused at desk; H10 self-service update in app reflected in POS (**scope decided — view/add/replace/remove, D17**).

Added in v2: **P1** pass POS item carries start/end dates from the product timeframe and check-in honours the window (D1); **P2** member (active/frozen/past-due/banned) pass purchase is blocked in web, app, and POS (D12); **P3** reverse conversion suspends, never deletes, the wallet and a consent tap reactivates it (D8); **P4** web/app person persisted at OTP verification or payment and kept when later steps fail (D9); **P5** stored card not exposed on a new device without step-up (D10); **P6** waiver acceptance required at pass checkout and not written to the wallet (D14).

Added in v3: **P7** app supports view/add/replace/remove of payment methods and the desk shows the result (D17); **P8** every pass purchase shows a QR, the QR persists in the app, and desk scan validates it against the POS item's start/end dates (D18); **P9** *(superseded by D35: emailed code for every user)*; **P10** picked day = start date, default today, end date from product duration (D21); **P11** no online refund flow exists; in-club POS refund still works (D22); **P12** under-18 self-attestation blocks online purchase and routes to the club (D23); **P13** waiver required once per person per club, re-required on version change, status visible at desk and in app (D24); **P14** all existing prospects at wallet-enabled clubs have a wallet owner after backfill, with reconciliation and no partial records (D25); **P15** §5A controls verified — OTP limits/lockout, new-device step-up, trusted-device skip, 3DS on first new-device purchase only, rotating QR rejects a stale screenshot, masked PAN, staff-role audit trail (D26); **P16** same person at two clubs in one VPD resolves to one member UUID and one wallet (D28).

Added in v3.5, revised in v3.6: **P17** the picked day writes the prospect's begin date, and expiration and visits come from the flagged item; check-in admits within the window while visits remain and refuses otherwise (D48, D62); **P18** the catalog-item flag opens contract days and visits, waiver text exists under club settings → Online, and flag-off leaves existing behaviour intact (D61); **P19** the prospect email contains the QR of the barcode, the pass date and the acknowledgement text, no 18\+ line, and the POS receipt email is still sent (D52, D66); **P20** the emailed QR scans at the desk as a barcode and the success page shows no QR (D63); **P21** a returning buyer sees Pass Terms and waiver again, and an expired card on file leads to a new-card capture (D53); **P22** the OTP field opens the numeric keyboard on iOS and Android (D54).

Added in v3.6 (Round 7): **P28** the pass is a product; no date picker is shown; the page shows days-to-use read from the item's contract days; the prospect's begin date is the purchase date and visits = 1, and the first check-in expires the prospect (D70–D72). **P23** the Guest Pass page is reachable at its own URL, lists every flagged item with price, and is not part of Online Join (D60, D68); **P24** a failed payment leaves the DT prospect deactivated, the deactivate reaches the CRM webhooks, and no card is saved (D65); **P25** the opt-in value, checked or not, arrives on the create call (D67); **P26** the page renders configuration read directly from the DT database with no enterprise-API change (D64); **P27** the OTP email is sent from the supplied template with the code injected (D59).

### Observability (PRD \#2 O1)

Logs and metrics identify operation, outcome, home club, and correlation identifiers for wallet create/load/save/conversion/suspension/reactivation/compensation/backfill, without exposing payment credentials (no PAN/CVV — D26). Add funnel events for the consumer flow: email and mobile entered, age attested, code sent, code verified, trusted-device skip, step-up passed/failed, person persisted, 3DS challenged, payment succeeded, card saved, QR issued, QR scanned (result), waiver signed, member blocked. Security events per §5A: OTP lockout, velocity trip, disposable-domain rejection, spend-anomaly alert, staff wallet view/charge (audit).

## 9. Non-goals

- Recurring membership dues or Recurring Services purchase on a prospect — out of scope for v1 as a priority call; dues require an RCM agreement (D4c).
- Existing active, frozen, past-due, or banned members buying short-term passes, including for friends or family (D2, D12).
- Buying a pass for someone else — gifting, guardians, households; payer must be the pass-holder (D13).
- Refunds on short-term passes as policy (D15); **any online refund flow** and **any new chargeback tooling** (D22).
- ~~Online pass purchase by anyone under 18 (D23)~~ — v1 has no age gate (D66); minimum age via the M\&O setting later (D40).
- Storing waivers or other documents on the wallet (D14).
- A new entitlement object for passes; the pass is a POS item (D1).
- Credit, refund, or delayed start for unused pass time at conversion (D12).
- **In-app nudging toward membership** — future consideration, not v1 (D29).
- **Full web wallet management** beyond adding a payment method at checkout (D17).
- Requiring the club's mobile app to buy or to enter — the app is recommended by club messaging, not mandatory (D18).
- Door/turnstile integration of the QR for 24/7 clubs (desk scan only in v1) (D18).
- **(v3.5)** Multi-day and visit-based passes, expiration extension on repeat purchase, "what's included" copy per club (D57).
- **(v3.5)** The "View your pass" page, rotating QR payload and persistent app QR in the first release (D51, D57).
- **(v3.5)** A new DT email type or a generic "send this email when this item is sold" rule (D52, D57).
- **(v3.5)** Date-of-birth capture or minor-queue handling (D56).
- **(v3.6)** Placing the day pass inside Online Join (D60).
- **(v3.6)** A QR on the web success page, or any pass-QR renderer other than DT (D63).
- **(v3.6)** A link-use counter or dynamic QR logic for v1 — M\&O visits and dates bound access (D62).
- **(v3.6)** Using the club's default prospect (free-trial) days/visits for the paid pass (D62).
- **(v3.6, Round 7)** A start-date picker or any future begin date (D71); multi-day / multi-visit passes in the first release (D72); modeling the pass as a service (D70).
- **(v3.5)** Waiver version tracking and once-per-club signature state (D53).
- Handing fraud/security design to another team (D26).
- Lazy, on-first-save wallet creation for existing prospects (D25 — backfill instead).
- Changing existing guest checkout mechanics or extending wallet benefits to guests — guest sales themselves are **in scope** (D30). \[PRD #2\]
- Sharing one stored card across multiple prospects. \[PRD #2\]
- Cross-VPD identity or wallet access (D11); remote-club engagement-app charging until access mechanics inside the VPD are designed (D28 settles the model, not the mechanics). \[PRD #2\]
- Allocating a membership agreement number at prospect creation (D33); changing agreement-number sequencing. \[PRD #2\]
- Creating an RCM billing account or payor before an RCM agreement exists. \[PRD #2\]
- Building a separate engagement-app wallet that is not the Universal Wallet owner for the member ID. \[PRD #2\]
- Redesigning payment authorization, consent, or wallet management screens except as required to expose the same owner to prospects — with the exception of the proposed day-pass consent ladder in §4.5, pending counsel. \[PRD #2\]
- Defining the full engagement-app catalog of non-member items; the wallet must work for items clubs already sell to prospects. \[PRD #2\]
- Making the email or mobile number the identity (D3, D35). \[Passwordless note\]

*Removed from non-goals in v2:* reverse-conversion wallet policy — decided, in scope (D8).

## 10. Open questions

From PRD #2 (numbering preserved; closed items marked):

1. Which UX is in scope: prospect Membership tab, Agreement tab, POS, conversion flow, engagement app, or all? *(open; app wallet management and desk visibility are now in — D17)*
2. Which payment methods: cards, bank accounts, Apple Pay, Google Pay, or only cards? *(partially closed — card on file is in scope, D7; wallets/bank open)*
3. Which wallet assignment tags, if any, may be selected while still a prospect? *(open)*
4. Should an existing member's wallet remain active when converted back to a prospect? **Closed (D8).**
5. What happens to wallet entries when a prospect expires, is deleted, is merged, or never converts? *(open)*
6. Lazy migration of existing prospects vs backfill? **Closed (D25): backfill.**
7. Which security role controls prospect wallet view/edit? **Direction set (D26):** dedicated role with audit trail (FR-W15); engineering to validate.
8. Is new wallet authorization consent required when a prospect method becomes an agreement billing method? *(open)*
9. Do Universal Wallet and Order Service accept missing agreement-number metadata for a durable owner/authorized user? *(open — spike)*
10. Does RCM need special behaviour when conversion creates billing account/payor after wallet entries already exist? *(open — spike)*
11. Must prospect wallets work across clubs/organizations? **Closed for the model (D11, D28)**; access mechanics open (FR-W10).
12. Should a wallet failure block prospect creation? **Closed (D9): no.**
13. Which engagement-app products may a prospect buy, and which stay member-only? *(open)*
14. Must the prospect exist in M\&O before first app purchase, or may the app create prospect and wallet in one flow? **Closed (D9):** one flow — persist at OTP or payment, then wallet, then payment.
15. What consent/stored-credential language applies app vs desk? *(see §4.5)*

From PRD #1:

- **Q16.** How do Club Managed members get wallets without existing on Commerce first, and is that pattern replicable for prospects? *(open — required work under D6)*
- **Q17.** Can the wallet support a non-Commerce entity at all? **Reframed (D6)**; implementation approach open.

From board notes:

- **Q18.** Should buyers be able to pick a pass start date/timeframe? **Closed (D21): yes.** \[Slack\]
- **Q19.** What is the maximum pass length that still creates a prospect ("up to a month")? Does a 30-day pass need different treatment from a 1-day pass? *(open)* \[Slack\]
- **Q20.** Passwordless edge cases. *(partly closed — channel D35; rate limiting, lockout, recycled-number step-up, fallback D26/§5A; member match blocked D12; multiple-match rule and contact-change recovery still open)* \[Passwordless note\]
- **Q21.** Does the same OTP login extend to the engagement app? **Closed (D10)**; MICO still open. \[Passwordless note, Slack\]
- **Q22.** Which clubs already selling online day passes should pilot? **Closed (D27).** \[Online-join note\]
- **Q23.** Are waivers stored on the wallet or handled elsewhere? **Closed (D14, D24).**

### Still open — to be decided next session

What genuinely remains after D1–D47.

- **Web wallet management scope beyond "add" (D17):** whether view/replace/remove ship on the web, or the web points to the app for management.
- **Partner possession proof (D39):** minimum proof the API demands from own-auth partners before exposing a stored card (D10); certification tests it.
- **Age validation (D40, D23):** attestation; DOB; ID check; club-configurable.
- **Waiver in the "By tapping Pay" sentence (note b):** legal review (memo §6: separate checkbox).
- **Remote-club access mechanics inside the VPD (D28 residual, FR-W10):** how a non-home club's staff and channels are authorised to see/charge the one wallet; token and merchant-account scoping when clubs in one VPD have different acquirers; how staff see a cross-club match.
- **Legal counsel outcomes** on the §4.5 consent ladder and the counsel questions listed there (now including 18\+ self-attestation sufficiency and waiver version re-sign).
- **Marketing / segment hand-off PRD:** the "fitness explorer" segment, membership-nudge roadmap (future — D29), and the marketing-consent line at the contact field (TCPA/CASL) — separate document.
- **Session-lifetime final numbers (engineering — D20):** confirm or replace the 30-day web / indefinite-app working assumption; trusted-device N.
- **Backfill volume and cost estimate (engineering — D25):** prospect counts per wallet-enabled club, remote-system record creation for dormant prospects, run window.
- **Engineering validation of §5A (D26):** confirm limits and thresholds, processor capabilities (velocity, AVS/CVV, 3DS scoping), QR rotation window; passkey fast-follow timing.
- **Multiple candidate records for one email (Q20 residual):** chooser rule and duplicate-resolution/merge review; recovery when contact details change.
- **Payer vs pass-holder, later:** when (if ever) gifting, guardian, and household purchase enter scope, and which model.
- **Q19 maximum pass length** and the multi-day / visit-based model (D57). *(Pass window type is closed for v1: calendar day — D48.)*
- **Apple Pay / Google Pay / bank accounts (Q2 residual).**
- **Prospect expiry/deletion/merge wallet policy (Q5), assignment tags (Q3), re-consent at conversion (Q8).**
- **Channel list and naming (C7 residual):** MICO in or out; align IE / Market/Ops / M\&O naming.
- **Downstream contract spikes** (Q9, Q10) with dates and owners.
- **From the 2026-09-10 sprint review:** counsel confirmation that right-panel consent placement is conspicuous (D42); T\&C content sign-off (D43 fixes the source, not approval); owner for the test-environment OTP mail sink and test-card list (D47); marketing opt-in at the contact field still absent from the build (D32b).
- **From the 2026-09-10 PM working session (Round 5), as revised by Round 6:**
  - ~~OTP email delivery~~ **Closed (D58, D59):** own email OTP in the BFF, CISO-approved, built; template from Chancy. Residual: resend timer and change-email path in the UI.
  - ~~QR generator source~~ **Closed (D63, D69):** DT is the only renderer, using the engagement team's library.
  - **DBA ticket (D61, D69):** now the catalog-item table; Terry Smith to say whether it is common-use (night deployment). Tonight at the latest.
  - **Legal check of the email content (D52):** acknowledgement text printed in the prospect email; counsel to confirm.
  - **Confirm deferrals (D53, D57):** waiver once-per-club with version re-sign; multi-day passes are now *configurable* (D61) but today's build ships one item. *(Rotating QR / "View your pass": deferral confirmed by Kelly; see the dynamic-link design under Round 6.)*
  - **Product-marketing hand-off (D55):** flow, screens, §4.6 guide, in-club card-on-file benefit.
  - **Reporting and insights requirements (D57):** parked; needs an owner.
- **From the 2026-09-10 afternoon session (Round 6):**
  - **Create-then-deactivate (D65):** PK to confirm there is no legal or payment-operations rule requiring a record before payment; Kyle's webhook concern — the deactivate must reach every CRM the create reached; owner for that propagation. v2 target: no record without a successful auth.
  - **18\+ removal (D66):** counsel to confirm waiver enforceability with no age gate; when to adopt the M\&O minimum-age setting (D40).
  - **Opt-in modal (D67):** Kelly to take the mockup to legal; Twilio's position on modal placement to be tested — "let them tell us no."
  - **Repo home for the Guest Pass page (D60):** Myko repo vs Online Join repo — Bjorn to confirm from the commits.
  - **Dynamic-link credential, v2 (D63):** Anil/Jag design — public web app, URL with barcode and club number, timestamped QR valid one minute, engagement's generator; needs hosting on existing ABC infrastructure, an owner (PK offered his team), and a decision on the open-page risk (shareable link, service abuse) — M\&O visit limits already bound the access risk.
  - **Card-testing protection (D65):** confirm the Cloudflare rules used on OJ apply to the new URL; attempt logging in place for compliance.
  - **Jira (D69):** Bjorn to send epics to Chancy; DT stories filed under them.
  - ~~Item type~~ **Closed (D70):** product.
- **From the 2026-09-10 evening follow-up (Round 7):**
  - **Future begin date (D74a/b):** does M\&O accept a prospect with a future begin/end range, and does DT alert or refuse a pre-begin check-in? Outcome decides whether a start-date picker can ever return.
  - **Terry Smith 7 pm (D74c):** final catalog-item fields and tables.
  - **UI change to Mark (D74d):** remove the picker; days-to-use copy bound to M\&O contract days.
  - **Guest definition and pass extension (D73):** revisit after ship — repeat purchase on an active pass, multi-visit, future start.

*Closed since v2 (removed from this list):* items closed by D17–D47. — see each decision's "Closes" field.

## 11. Conflicts

*[Table lives on the Miro board](https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683208013435)*


All eight resolved 2026-09-09.

### Resolved conflicts (2026-09-09)

- **C1** both diagnoses right; contract keyed by person UUID (D6). **C2** COF in scope; app manage, web add, desk sees (D7, D17). **C3** waivers a pass requirement, not a wallet item (D14, D24). **C4** recurring billing out of v1 as a priority call (D4c). **C5** prospect created at OTP or payment (D9). **C6** card on file in; wallets/bank open (D7, Q2). **C7** wallet is the feature, day pass the dominant use case (D5). **C8** decision log closes items; the rest stays open in §10 (D1–D40).

### Conflicts to resolve

None outstanding between the two source PRDs. Review recommendations the PM overruled: credit/delayed start at conversion (D12); payer/holder link in v1 (D13); club-configurable online refunds (D15/D22); Apple/Google Wallet pass with door integration (D18: QR in app, desk scan); an outside security owner (D26). Full app wallet parity in v1 — adopted (D17).

## 12. Delivery approach (PRD \#2, with additions)

1. Confirm downstream contracts (owner, authorized user, wallet entry, checkout session) keyed by person UUID without a membership agreement number (D33); run the ENGIN-4241 AccountInfoID audit and EAPI-791 as the Commerce workstream under the same contract (D6).
2. Implement the reverse-conversion policy: suspend, never delete; roles stripped; consent-tap reactivation (D8). Prospect expiration/deletion/merge policy still to be decided.
3. Club-scoped feature flag, existing behaviour default.
4. Prospect wallet initialization service that runs only after person persistence; for web/app, persistence at OTP verification or payment (D9).
5. **Backfill job (D25):** create wallet owners/authorized users for all existing prospects at wallet-enabled clubs, with reconciliation and retry; engineering to estimate volume/cost and run window before enabling any club.
6. Sell the pass as the club's configured day-pass catalog item (D49); picked day = start date, default today (D21), written to the prospect's begin/expiration dates (D48); issue a static QR of the barcode on the thank-you page and in the prospect email (D51, D52); check-in uses existing prospect-date enforcement (FR-P7); item-carried dates, persistent app QR and rotating payload follow in v2 (D57); add the lifecycle block for active/frozen/past-due/banned members in web, app, and POS (D12).
7. Update prospect UX and POS session init to resolve a real owner/authorized user by member ID, including short-term pass and class checkout; show waiver status (D24) and app-made wallet changes (D17) at the desk; dedicated staff role with audit trail (D26).
8. Align engagement-app signed-in prospect checkout and payment-method screens to the same owner; **view/add/replace/remove in the app (D17)**; web add at checkout (D17); card capture on the Pay Page (D38).
9. Passwordless identification (D19, D35) on online join / web pass purchase and the app: email-only lookup and code (D35), VPD-scoped (D36), mobile required (D37), one shared OTP issuer, session bound to member ID, new-device step-up before exposing a stored card (D10, D26), trusted-device binding with engineering-owned lifetimes (D20).
10. Implement §5A security controls (D26) with engineering validation: email-OTP limits/lockout/disposable-domain checks, velocity and AVS/CVV, 3DS on first new-device purchase only, rotating QR payload, masked PAN, audit trail. Passkeys as fast-follow.
11. Implement the day-pass checkout consent ladder (§4.5) once ABC legal counsel signs off; waiver as its own checkbox, once per person per club with version re-sign (D14, D24); 18\+ self-attestation (D23; method open — D40); no-refund policy in Pass Terms (D15, D22).
12. Update conversion reconciliation to replace prospect metadata, preserve entries, establish post-agreement assignments, and forfeit unused pass time (D12).
13. Add compensation and reconciliation for partial failures (including backfill and QR issuance).
14. **Pilot (D27):** capture baselines at clubs 31239 and 31590 **before build** (repeat-buyer share, time-to-purchase, prospect-creation rate); internal test clubs; then enable 31239 and 31590; set success thresholds from the baselines; broader enablement gated on them.
15. **Build verification (D46, D47):** iterative visual-parity loop of the build against the Design HTML v1.2 until no differences are reported; independent simulated-user agent runs end to end with an OTP mail sink and sandbox test cards; no real cards or live charges in test; Pay Page embed (D44) and email OTP (D35) are prerequisites for the agents to complete a purchase.
16. **DataTrak enablement (D48–D53, D61–D63, §4.6):** catalog-item flag with contract days and visits (DBA columns via Terry Smith); waiver text under club settings → Online; prospect email type with the static QR, pass date and acknowledgement text; LaunchDarkly flag; BFF create call with begin/expiration/visits/opt-in; no page QR. Owner: Chancy (DT), Mark (BFF), Bjorn (web), PK (review).
18. **Standalone Guest Pass URL (D60, D64, D68, D71):** fork off Myko; list flagged items with prices; no date picker — days-to-use from M\&O; read DT config from the database; club-site "Buy a day pass" call to action; repo home confirmed.
21. **Model (D70–D72):** product with guest-pass toggle, contract days and visits; v1 single-visit; Chancy's future-begin tests (D74) before any picker returns.
19. **Payment-failure pattern (D65):** ship create-then-deactivate with webhook propagation, attempt logging and Cloudflare limits; PK confirms the rule; v2 removes the pre-payment record.
20. **Consent surface (D66, D67):** remove the 18\+ checkbox; add the legal opt-in checkbox with modal; mockup to legal.
17. **Email OTP (D58, D59):** built and CISO-approved — 6 digits, 5-minute expiry, 2 sends per address per hour, lockout per §5A-1; OTP email from Chancy's template; resend timer and change-email path in the UI. Numeric keypad on the code field (D54).

### Risk watchlist (PRD \#2, updated)

- **Critical — Reverse conversion lifecycle: RETIRED (D8).** Now in scope with a decided policy; acceptance criterion P3.
- **High** — Downstream identity contract (Universal Wallet, Order Service, RCM, UPCT) and the Commerce/AccountInfoID dependency (D6). Architecture spike before implementation.
- **High → Medium** — Remote-club authorization inside the ABC VPD. Model decided (one person, one wallet — D28); access mechanics and token/merchant scoping remain an engineering design item (FR-W10). Excluded from first release.
- **High** — Engagement-app identity contract (consumer session, BFF, Universal Wallet, shared OTP issuer — D10). Architecture spike before app implementation.
- **High → Medium** — Consumer web session on Online Join: owner and working assumption set (engineering — D20); trusted-device binding per §5A (D26). Final numbers pending.
- **Medium** — Existing prospect backfill: **strategy decided (D25 — backfill)**; risk is now volume/cost and remote-system record creation for dormant prospects — engineering estimate before enablement.
- **Medium** — Security posture validation (D26): engineering confirms processor capabilities (velocity, AVS/CVV, 3DS scoping) and email-OTP guardrails (D35); email deliverability at pilot clubs.
- **Medium** — Legal review of the day-pass consent ladder (§4.5), no-refund policy (D15/D22), 18\+ self-attestation (D23), and waiver version re-sign (D24) by state/province.
- **Low** — QR adoption at the desk: scanner availability and staff training at pilot clubs (D18).
- **Medium (new, v3.5)** — **Maintenance server dependency (D48):** prospects expire only when the maintenance server runs; if it stalls, day-pass prospects keep access past their day. Add a monitor before enabling a club.
- **Medium (v3.5, revised v3.6)** — **DBA turnaround (D61, D69):** the new columns are now on the catalog-item table; if Terry Smith classes it common-use the change runs at night. "Tonight at the latest."
- ~~Two QR renderers~~ **Retired (D63):** DT is the only renderer.
- **High (new, v3.6)** — **Create-then-deactivate webhooks (D65):** a failed payment creates and then deactivates a prospect; if the deactivate does not reach every CRM, clubs will market to people who never bought. Verify propagation before enabling a club.
- **Medium (new, v3.6)** — **Twilio and the opt-in modal (D67):** Twilio has said it will not approve SMS sends with the consent text behind a modal. Test with the mockup; fallback is inline text.
- **Medium (new, v3.6)** — **No age gate (D66):** waiver enforceability for a minor buyer; counsel to confirm; M\&O minimum-age setting is the fix.
- **Low (new, v3.6 Round 7)** — **Pre-begin check-in behaviour unknown (D71, D74):** until Chancy's test, no future begin dates are sent; if a future date slips through, DT behaviour is unverified.
- **Low (new, v3.6)** — **Shared QR (D62):** a forwarded QR spends the buyer's own visit; acceptable by design, but the email should say so.
- **Low (new, v3.5)** — **Two emails per purchase (D52):** prospect email with the QR plus the POS receipt; buyers may open the wrong one. Subject lines should make the pass email obvious.

### Assumptions carried from PRD \#2 (updated)

Wallet behaviour is enabled for records with AgreementTypeLookup PROSPECT / agreement number PROSP; day pass and class items are already sellable to prospects as POS items (D1); the app identifies a signed-in prospect by the same Ignite member ID; *"the prospect exists before payment data is collected" is deleted and replaced (D9):* the person is persisted at OTP verification or payment, before the wallet is initialised and payment collected; **all existing prospects at wallet-enabled clubs receive a wallet owner via backfill before launch (D25)**; member ID is unchanged through conversion; existing authorization/consent experience is reusable for membership (Tier 2) while the day-pass flow uses the proposed lighter ladder pending counsel; tenancy boundary is the ABC VPD and one person is one wallet across clubs inside it (D11, D28); wallet entries belong to the person, billing assignments to the eventual agreement; club-level rollout control; desk check-in has a QR-capable scanner (D18); the Commerce Pay Page keeps Online Join out of PAN scope (D26, D38); **(v3.5)** DT prospect creation returns the barcode synchronously and check-in already enforces prospect begin/expiration dates without change (D48, D51); the prospect email type can carry an image, links and additional text (D52); the day-pass path is fully gated by a LaunchDarkly flag (D50); **(v3.6)** the catalog-item table accepts three new columns (D61); the prospect create call already carries begin/expiration/visits and the opt-in flag (D62, D67); all ABC scanners read a plain barcode QR (D63); the Guest Pass page can read the DT database directly as Myko does (D64).

## 13. Benchmark: Iron 24

Iron 24 (iron24.com): 24/7 digital gym — buy online, personal QR in app or web, scan at the door; sells day/week passes. Its "buy once, buy again" flow is the target for FR-P3 (D35); its QR in app or web is the credential model (D18, D41), except v1 scans at the desk and the v1 credential is a static QR of the barcode delivered by email (D51). Friction benchmark: Shop Pay / Stripe Link (§5A).

## 14. Source appendix

*[Table lives on the Miro board](https://miro.com/app/board/uXjVHpGS2D4=/?moveToWidget=3458764683208013473)*

