# Day Pass browser QA — shared brief (read fully before doing anything)

## What is under test
The new "Day Pass" single-flow checkout built in Sprint 0001 across two repos:
- UI: /Users/bjornloftis/claudeprojects/prospects-ui/repos/online-join-ui (branch prospect-wallet/sprint-0001), code under src/routes/ShortTermPass/
- BFF: /Users/bjornloftis/claudeprojects/prospects-ui/repos/online-join-bff (branch prospect-wallet/sprint-0001), code under src/routes/shortTermPass/ and src/services/shortTermPass/
- Requirements (authoritative, in this order): docs/prd/prospect-wallet-demo-1-first-visit.html, docs/prd/prospect-wallet-demo-2-returning-visit.html, docs/prd/day-pass-requirements-addendum.md, then docs/prd/day-pass.html — all under /Users/bjornloftis/claudeprojects/prospects-ui/docs/prd/. Sprint plan: docs/sprints/SPRINT-0001.md.
Read the UI source for the step you test so you know intended behavior; when actual != intended, or intended != requirements, that is a finding.

## Running servers (already up — DO NOT restart, rebuild, kill, or touch them)
- Entry URL: http://localhost:3000/signup/day-pass?club=90030   (BFF :3000 serves HTML and /api; webpack dev server :3001 serves the bundle)
- Done page URL: /signup/pass?club=90030 (the app redirects there itself after purchase)
- The BFF runs in mock mode: STP_ADAPTER_MODE=mock, STP_CAPTURE_MODE=mock, flag locally overridden on.
- The BFF state is IN MEMORY and SHARED by all QA agents running concurrently. Stay inside your assigned contacts (see your task). Do not use another agent's personas.

## Browser tooling
- playwright-core is installed at $S/node_modules (S = /private/tmp/claude-502/-Users-bjornloftis-claudeprojects-prospects-ui/069fdd27-8017-422c-ba01-40725c36dc93/scratchpad). Put your scripts anywhere under $S/qa/<your-agent-dir>/ so `import { chromium, devices } from 'playwright-core'` resolves (node walks up to $S/node_modules). Use .mjs files.
- Launch: `chromium.launch({ channel: 'chrome', headless: true })` (uses the installed Google Chrome; no browser download). Node is v26.
- Working example: $S/qa/probe.mjs (loads the page on an iPhone 14 emulation, identifies Jordan, reaches the OTP screen, screenshots).
- Playwright `devices[...]` descriptors work for mobile emulation (viewport, DPR, touch, UA). `page.emulateMedia`, `context.setOffline`, `page.route` (to inject failures / inspect requests), `page.evaluate` (to tamper with inputs the picker UI wouldn't allow) are all available.
- ALWAYS collect: console errors/warnings (page.on('console'), page.on('pageerror')), failed/4xx/5xx responses (page.on('response')), and a full-page screenshot at each meaningful state. Save screenshots to $S/qa/shots/<your-agent-dir>/ with descriptive names.
- Do not use bypass of the app: drive the real UI. API-level probing (fetch from page.evaluate or curl) is allowed ONLY to prove the server side of a corner case (e.g. does the BFF reject a past date the browser picker blocked?). Say clearly which findings were API-level.

## Flow and stable selectors (from the source)
1. identify: input #ident (label "Mobile number or email"), button #continue. Client accepts an email (regex ^[^\s@]+@[^\s@]+\.[^\s@]+$) or a phone with 10 digits or 11 digits starting with 1 (any formatting). Otherwise inline error "Enter a mobile number or an email address."
   - Known contact -> verify step. Unknown contact -> newVisitor step (no code). Shared phone -> stays on identify with the "We need a hand with that one" warning.
2. verify: six inputs aria-label "Digit 1".."Digit 6" (class .dt-input inside .otp), button #verifyBtn, links #resend, #switchCh (only when the other contact is on file), #startover. Mock OTP code is 123456 (shown on screen as "Test mode — your code is 123456."). Wrong code: "attempts left" message; after 5 wrong attempts the challenge locks. Resend cooldown 30 s; at most 5 code sends per contact per club per 15 min; code TTL 10 min.
3. newVisitor: #first, #last, #second (optional other-channel contact), test-card select #mockCard (options: visa-4242 approved, mastercard-4444 approved, visa-0002 declined, visa-0003 authorization timeout, visa-1111-expired invalid), save-card toggle, terms checkbox #termsCb plus a "Terms & conditions" link opening a modal with an Agree button, pay button #pay ("Pay $18.00 and get my pass"). Form error region #formErr. "Edit" link #editContact goes back to identify.
4. recognized (returning): "Welcome back, <first>" banner, Your info section, Payment: saved card chip with #diffCard, or #useSaved when a saved card exists but a new card is being entered, or the #mockCard slot; #termsCb; #pay.
5. complete/done: "You're in, <first>", pass block [data-testid=pass-block] with QR, "1-day pass · <day>", delivery sentence, wallet saved pill / not-saved copy, buttons #again (Start again) and #getApp.
Order summary sidebar [data-testid=order-summary]: date input #day (type=date, min = club-local today from the BFF, max = maxVisitDate or none), line item, "Paying with", Total, fine print #fine. Toasts appear on date change ("Day pass for Today"/"Day pass for Wed, Sep 16").
The URL stays at /signup/day-pass until complete, then /signup/pass. Reload mid-flow should rehydrate from the OJ-PASS-SESSION cookie. Session-expired -> toast "Your session expired. Let's start again." and restart.

## Fixture data (mock mode)
Clubs: 90030 Riverside Athletic Club (America/Chicago, $18.00 "1-day pass", app link) — the main club. 90031 Eastside (onlineProspects false -> should be unavailable). 90032 Northside (America/New_York, club-authored terms HTML). 90033 Core South (Gym Floor $25.00 with perks, America/Chicago). Any other club number, a missing club param, or the page inside an iframe -> "This page is not available. Please contact the club." / "Open secure checkout".
Personas (club 90030):
- Jordan Reyes, prospect, jordan.reyes@email.com / 5550192231 — has a saved card (the returning-visit demo)
- Casey Morgan, member, casey@example.com / 5550193344
- Riley Chen, prospect, riley@example.com / 5550195566 — NO card on file
- Dana Whitfield, prospect, dana@example.com, no phone — expired card
- Morgan Blake, prospect, morgan@example.com / 5550190002 — card declines
- Sam Patel sam@example.com and Alex Patel alex@example.com BOTH have phone 5550197788 -> ambiguous
Anything else is a new visitor.

## Reporting — write $S/qa/findings/<your-agent-dir>.md
Sections: (1) Environment + what you ran (viewports, personas), (2) Findings table, (3) Detailed findings, (4) What passed (short list), (5) Not tested / blocked and why.
Each finding: ID (e.g. A1-03), Severity (P0 blocker / P1 major / P2 minor / P3 cosmetic / Q design question), Title, Viewport/device, Steps (numbered, exact input values), Expected (cite the source or requirement), Actual (exact on-screen text), Evidence (screenshot path, console/network lines), Repro count (e.g. 3/3), Suspected cause with file:line if you looked. Be skeptical of your own findings: re-run each once before reporting; note flakiness. Report console errors and non-2xx API responses even if the UI looked fine. Do not report the webpack-dev-server HMR chatter or the AppDynamics key warning; those are dev noise.
Hard rules: never edit files in the two repos; never commit; never kill or restart servers or other node processes; stay within your persona allocation; finish within ~35 minutes of wall clock and write the report even if incomplete.
