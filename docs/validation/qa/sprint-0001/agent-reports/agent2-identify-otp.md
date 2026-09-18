# QA report — agent2-identify-otp (IDENTIFY + VERIFY / one-time code)

## 1. Environment + what I ran

- Entry: http://localhost:3000/signup/day-pass?club=90030 (BFF mock mode, shared in-memory state). Note: http://127.0.0.1:3000 is rejected by the BFF origin check (`POST /checkouts` -> 403 `ORIGIN_REJECTED`, page shows unavailable) — expected hardening, noted for other testers.
- Tooling: playwright-core + installed Chrome, headless. Scripts: `$S/qa/agent2-identify-otp/{a-identify-validation,b-jordan-otp-input,c-jordan-nav,d-sam-lockout,e-alex-resend-switch,f-mobile,g-rerun}.mjs` (logs `*.log` beside them). Screenshots: `$S/qa/shots/agent2-identify-otp/`.
- Viewports: desktop 1440x900 (A–E, G); iPhone 12 emulation 390x844 / DPR 3 / touch (F).
- Personas used: Jordan's phone 5550192231 in formats `+1 (555) 019-2231`, `1-555-019-2231`, `555.019.2231`, `15550192231` (4 code sends total); ambiguous phone 5550197788 (x2, no sends); `  Sam@Example.COM  ` (1 send + 1 resend); alex@example.com (2 identifies, 1 resend, 3 channel switches); unknowns `qa2-…@otp.test`, `<script>alert(1)</script>@x.com`.
- API-level probes (fetch from inside the page with the real cookie + CSRF header) were used only to prove server behaviour behind UI-blocked states; each is marked **[API]** below.
- Console noise excluded per brief: HMR, AppDynamics. Remaining console errors were exclusively axios "Failed to load resource" lines mirroring the expected 4xx below. No `pageerror`, no 5xx, no unexpected 4xx in any run.

## 2. Findings table

| ID | Sev | Title | Viewport |
|---|---|---|---|
| A2-01 | P2 | "Text me instead" / "Email me instead" stays enabled during the 30 s cooldown and fails with a raw throttle error | desktop (repro 2/2) |
| A2-02 | P2 | After a channel switch the verify sub-line says "your mobile"/"your email" (no masked contact), but a reload then reveals the masked alternate contact — inconsistent and defeats the BFF's stated privacy rule | desktop (2/2) |
| A2-03 | P2 | Contact longer than 120 chars shows developer text: `Invalid request: contact must match pattern "^[^\r\n]{3,120}$"` | desktop (2/2) |
| A2-04 | P2 | After a wrong code, the six boxes clear but focus is lost (BODY) or left on Digit 6; on mobile the keyboard closes and the user must re-tap box 1 | desktop + mobile (7/7) |
| A2-05 | P3 | Ambiguous-contact warning persists on screen alongside the inline format error when the user then submits invalid text | desktop + mobile |
| A2-06 | P3 | Pasting a code into box 3 fills from box 1 (ignores paste position); pasting `12` into box 3 overwrites boxes 1–2 | desktop |
| A2-07 | P3 | Verify-step link row wraps on 390 px: "Start over" drops to a second line leaving a dangling "·" separator; link tap targets are 17 px tall | mobile |
| A2-08 | P3 | Continue has no busy affordance beyond `disabled` (no label change/spinner) during 0.6–3.5 s identify round-trips | desktop + mobile |
| A2-09 | Q | Reload on verify keeps the challenge and countdown but drops the "Test mode — your code is 123456." hint (snapshot has no `debug`) — mock-only; confirm hint is truly mock-only | desktop |
| A2-10 | Q | Browser Back from verify leaves the checkout (about:blank / referrer); Forward rehydrates to verify. No in-app history entries per step — acceptable? | desktop |
| A2-11 | Q | No client-side max length on #ident; server caps at 120 (see A2-03) | desktop |
| A2-12 | Q | identify latency 0.6–3.5 s and verify-success 2.5–3.4 s under 4 concurrent agents (floor is 300 ms) — dev-mode Redux invariant middleware warnings suggest client-side cost | all |

No P0/P1 found in this slice.

## 3. Detailed findings

### A2-01 — P2 — Switch-channel link enabled during cooldown -> raw THROTTLED error
- Viewport: 1440x900.
- Steps: 1) Enter `alex@example.com`, Continue. 2) On "Check your email", within 30 s click **Text me instead**.
- Expected: either the link is disabled while "Resend code (Ns)" is counting down, or the switch is exempt from the resend cooldown (the addendum lists the link with no cooldown semantics; the resend link already models cooldown with a disabled label).
- Actual: link is enabled; `POST /challenge {"action":"switch-channel"}` -> **429** `THROTTLED`; red alert reads exactly: `Please wait before requesting another code. Try again in 25s.` (the `Ns` value is the retryAfterSeconds and does not tick). Nothing else changes; the alert clears when the user types a digit.
- Evidence: shots `41-alex-switch-during-cooldown.png`; e-alex log lines "SWITCH during cooldown"; g-rerun "RERUN switch during cooldown". Repro 2/2.
- Suspected cause: UI `VerifyStep.tsx:161-167` disables `#switchCh` only on `busy`; BFF `challenge.ts:63-69` (`ChallengeService.issue`) applies `previous.resendAfter` to every issue, including switch (`identify.ts:158`). Same applies to `Start over -> re-identify`? No — Start over clears the challenge so re-identify is immediate (verified in C).

### A2-02 — P2 — Masked contact hidden after switch, but shown after reload
- Viewport: 1440x900.
- Steps: 1) `alex@example.com` -> Continue. 2) Wait 30 s, click **Text me instead** (toast "Code texted"). 3) Observe sub-line. 4) Reload.
- Expected (addendum "Code entry"): sub "We sent a 6-digit code to **{masked}**." consistently. BFF comment (`identify.ts:149`) says "The response never carries a mask of the unsubmitted address", i.e. the alternate contact should NOT be revealed.
- Actual: after switch the sub reads `We sent a 6-digit code to your mobile.`; after reload the snapshot (`checkouts.ts:28-32`) returns `contact.masked` for the current (switched) contact and the sub reads `We sent a 6-digit code to (555) •••-7788.` Symmetric on switching back ("your email" then reload shows `a•••@example.com`). So the privacy rule is only enforced on the switch response, not on rehydrate; and the copy differs before/after reload.
- Evidence: shots `43-alex-switched-to-phone.png`, `46-alex-switched-reload-mask.png`; e-alex log "SWITCH -> phone" and "RELOAD on switched channel"; g-rerun. Repro 2/2.
- Decision needed: either always show the masked alt contact (drop the rule) or strip `masked` from the snapshot when `record.contact` is the switched-to contact.

### A2-03 — P2 — Raw schema message shown for very long contact
- Viewport: 1440x900.
- Steps: type `qa2-` + 480×`a` + `@otp.test` (493 chars; passes the client email regex), Continue.
- Expected: friendly inline error, e.g. "Enter a mobile number or an email address." (INVALID_CONTACT_MESSAGE) — the field error slot is meant for user copy.
- Actual: 400 `VALIDATION_FAILED`; the help line becomes `Invalid request: contact must match pattern "^[^\r\n]{3,120}$"`. Repro 2/2.
- Evidence: shot `02-server-500char.png`; a-identify log "SERVER CASE 500char".
- Suspected cause: `schemas.ts:388` builds the message from the ajv error and `IdentifyStep.tsx:48` shows any `VALIDATION_FAILED` message verbatim. Also no `maxLength` on `#ident` (A2-11).

### A2-04 — P2 — Focus lost after a wrong code
- Viewports: 1440x900 and iPhone 12.
- Steps: on verify enter `000000`, submit with **Enter** (desktop) or the **Verify** button (desktop/mobile).
- Expected: boxes clear and focus returns to Digit 1 so the user can retype immediately (the source resets `digits` but only focuses box 1 on `challenge.expiresAt` change, `VerifyStep.tsx:44-46`).
- Actual: alert `That code isn't right. Check it and try again. 4 attempts left.`; boxes empty; `document.activeElement` = BODY when the Verify button was used (button becomes disabled and drops focus) or Digit 6 when Enter was used. Typing then does nothing (BODY) or fills box 6 first. On mobile the soft keyboard would close. Repro 7/7 (B x1, D x5, F x1).
- Evidence: shots `12-verify-wrong-code-enter.png`, `30-sam-wrong-1.png`, `54-mobile-wrong-code.png`; logs "focus=BODY"/"focus Digit 6".

### A2-05 — P3 — Ambiguous warning does not clear on further edits
- Steps: enter `5550197788` -> warning "We need a hand with that one / More than one person at this club uses that contact. Try your other mobile number or email, or ask the front desk to help." (correct). Then type `abc`, Continue.
- Actual: the inline format error appears **and** the ambiguous warning remains. It only clears on the next successful identify (`state.ambiguous=false` set in `identifyContact.fulfilled` only).
- Evidence: shot `03-ambiguous-then-invalid.png`; a-identify log last two lines.

### A2-06 — P3 — Paste ignores the target box
- Steps: focus Digit 3, paste `987654` -> all six boxes filled from box 1 (`987654`), focus Digit 6. Paste `12` into box 3 -> `12____` (boxes 1–2 overwritten), focus Digit 3.
- Expected: debatable; most OTP widgets either fill from the focused box or (as here) treat any paste as the whole code. Flag as design question / minor. `VerifyStep.tsx:77-84`.

### A2-07 — P3 — Mobile link row wraps with dangling separator; small tap targets
- iPhone 12: "Resend code (30s) · Email me instead ·" on line 1, "Start over" alone on line 2 (shot `53-mobile-verify.png`). Link buttons measure 127x17, 113x17, 66x17 px (below 44 px touch target guidance). OTP boxes 45x48 px, `inputmode=numeric`, no horizontal overflow (scrollWidth 390).

### A2-08 — P3 — No busy affordance on Continue
- Sampled every 30–40 ms after submit: `#continue` is `disabled` for the whole round-trip (so double-submit is prevented, see passes) but label stays "Continue", no `aria-busy`, no spinner. With 0.6–3.5 s round-trips the screen looks frozen. `IdentifyStep.tsx:85`.

### A2-09 — Q — Mock code hint disappears on reload
- After reload on verify: h1/sub/countdown/switch link all rehydrate correctly, `.dt-help` hint absent (snapshot carries no `debug`). Mock-only; harmless, but the demo driver must remember 123456. Also confirm `echoCode` (`routes/shortTermPass/identify.ts:13`, `adapters.mode === 'mock'`) can never be true in platform mode.

### A2-10 — Q — Browser Back/Forward
- From verify, `history.back()` -> about:blank (the app never pushes per-step history); Forward -> full reload, rehydrates to verify with countdown intact (`21-verify-after-reload.png`). Requirements do not specify in-app back; flag for product.

### A2-12 — Q — Latency
- identify: 390 ms (ambiguous), 588–1307 ms typical, one 3537 ms; verify success 2540–3351 ms; POST /checkouts 2.8–3.8 s. Console shows Redux `SerializableStateInvariantMiddleware`/`ImmutableStateInvariantMiddleware took 33–75ms` warnings (dev only). Likely load from 4 concurrent agents + dev build; not a defect, but the 300 ms floor is never the bottleneck.

## 4. What passed

- Client validation (no network call, exact copy `Enter a mobile number or an email address.`, `aria-invalid`, `role=alert`, focus stays in field, error clears on first keystroke): empty, whitespace, `abc`, 9 digits, 12 digits, 11 digits not starting with 1, `' OR 1=1 --`, emoji, `Sam@Example`, `sam @example.com`. Enter and Continue behave identically.
- Phone normalisation: `+1 (555) 019-2231`, `1-555-019-2231`, `555.019.2231`, `15550192231` all reach "Check your texts" with masked `(555) •••-2231`; "Email me instead" offered (both contacts on file). Correct code -> "Welcome back, Jordan".
- `  Sam@Example.COM  ` -> trimmed, matched case-insensitively, masked `s•••@example.com` (mask rule `min(5,max(3,len-1))` dots); "Text me instead" offered (Sam has the shared phone).
- `<script>alert(1)</script>@x.com` and `qa2-ünï+tag'or'1'='1@otp.test` -> new-visitor step, rendered as inert text ("Email <script>alert(1)</script>@x.com Edit"), masked `<•••••@x.com`; Edit returns to identify with the raw value prefilled. No page errors.
- Ambiguous `5550197788` -> stays on identify, warning title/body exactly as specified, no challenge issued, Continue re-enabled (desktop and mobile).
- Double-click Continue (Jordan phone): exactly 1 identify request, 1 challenge; `busy` disables the button synchronously.
- OTP entry: letters ignored; typing `1234567` fills 6 and ignores the 7th; auto-advance; Backspace clears then moves left (never past box 1); paste `12 34 56` -> `123456` focus box 6; `12ab34` -> `1234__` focus box 5, Verify disabled; paste with no digits leaves state untouched; Enter with 5 digits sends nothing; Verify disabled until 6 digits and while busy.
- Wrong-code copy, exact: `That code isn't right. Check it and try again. 4 attempts left.` / `3 attempts left.` / `2 attempts left.` / `1 attempt left.` (singular correct) / 5th: `Too many incorrect codes. Request a new code to continue.` (HTTP 429 CHALLENGE_LOCKED). Locked: all six inputs and Verify disabled, typing has no effect, Resend (countdown) and Start over remain available. **[API]** a 6th attempt with the correct code on the locked challenge -> 429 CHALLENGE_LOCKED.
- Resend: label `Resend code (30s)` ticking 1 s, disabled; enabled at ~29–30 s; click -> toast `Code resent`, new 30 s countdown, boxes cleared, focus Digit 1, alert cleared; on a locked challenge resend produces an unlocked challenge (inputs re-enabled) and the correct code then succeeds ("Welcome back, Sam"). **[API]** resend inside the cooldown -> 429 THROTTLED retryAfterSeconds.
- Switch channel (after cooldown): toasts `Code texted` / `Code emailed`, h1 flips "Check your texts"/"Check your email", link flips "Email me instead"/"Text me instead", new countdown.
- Start over: `DELETE /identity` 200, identify screen with the hint prefilled (`(555) 019-2231` / `alex@example.com`), no stale alerts, focus in field. **[API]** old checkout `POST /verify 123456` -> 401 CHALLENGE_MISSING and `POST /challenge resend` -> 401 CHALLENGE_MISSING (challenge revoked). Re-identify immediately after Start over is allowed (no cooldown) and completes to "Welcome back, Jordan".
- Reload on verify rehydrates to verify (`resumed:true`), countdown continues from server `resendAfter`, URL stays `/signup/day-pass?club=90030`; cookie is not readable from JS.
- Mobile 390x844: no horizontal overflow on identify/verify/recognized; numeric inputmode on OTP boxes; full flow to "Welcome back, Jordan" works.
- Origin check: page served from 127.0.0.1 cannot create a checkout (403 ORIGIN_REJECTED).

## 5. Not tested / blocked and why

- Code expiry (10 min TTL) and the 5-sends-per-contact/15-min ceiling: not exercised to keep within the shared per-contact and per-IP (20 identify / 15 min, keyed by `ctx.ip`, shared by every agent on localhost) budgets.
- Real clipboard/`autocomplete=one-time-code` autofill: pastes were dispatched as synthetic ClipboardEvents (React handler path verified; browser default paste path not).
- "Old code after Start over" could only be proven at API level (mock code is always 123456, so UI cannot distinguish old from new code).
- Jordan's email, Casey/Riley/Dana/Morgan: owned by other agents.
- Switch-channel while the challenge is locked (after cooldown) — not run to preserve Sam's send budget; by code it would issue a fresh unlocked challenge on the other channel.
