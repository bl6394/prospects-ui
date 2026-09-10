# Sprint 0002: Day Pass review changes — Design v1.2 parity, §4.5 consent, Pay Page embed, email OTP for every buyer, prospect-wallet save, and the agent test harness

**Status:** planned, 2026-09-10 (interview and merge complete). Owners named at kickoff.
**Inputs:** `docs/sprints/drafts/SPRINT-0002-INTENT.md` (build-vs-v1.2 reconciliation table); `docs/prd/Change_Requests_2026-09-10.md` (CR-01…CR-09, PR-01…PR-04, CF-01…CF-03, §D, §E); `docs/prd/Consolidated_PRD_v3.4.md` (D35–D47, §4.5, §5, §5A items 1 and 10, §7, §12.15); `docs/prd/day-pass-v1.2.html` (**source of truth for fonts, sizes, layout, colours and copy — D46**; `day-pass.html` is the superseded v1.1; the Riverside demos remain the source only for fixture data); `docs/sprints/SPRINT-0001.md` with its execution summary and blockers; `docs/contracts/short-term-pass-bff.md` (contract v1, readiness register §10); drafts, critiques and `SPRINT-0002-MERGE-NOTES.md` under `docs/sprints/drafts/`.
**Verified locally (token cache `repos/`):** `online-join-ui` @ `a3c61b6`, `online-join-bff` @ `db81011`, both on `prospect-wallet/sprint-0001`, clean; PRs online-join-ui #524 and online-join-bff #96 open against `main`. BFF `.env` has `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_ALLOWED_ORIGINS`; the six `PAY_PAGE_*`/`ABC_CORE_API_URL` keys are **absent** (B1 open). `short-term-pass.scss` line 5 `@import`s Inter from Google Fonts; BFF CSP allows `fonts.googleapis.com`/`fonts.gstatic.com`; webpack already bundles `woff2`. Machine: Node 26, Chrome at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, `claude`/`codex`/`agy` authenticated.
**Facts from the code that shape this plan:** the reviewed "saved-card dropdown" is `MockCardCapture.tsx` (a `<select>` of fixture cards) rendered whenever `captureMode !== 'paypage'`, and the BFF defaults capture to `mock` in mock adapter mode; `identify()` looks up the directory first and skips the code on no match; `PayPageEmbed` receives the SDK `onLoad` but exposes only `submit()`, so `CardCaptureSlot` fakes readiness with `setTimeout`; `saveCardToWallet` sends the purchase id as `providedId` while universal-wallet's `CreditCardRequestVO.providedId` is a `UUID`; `debug.code` is echoed in mock mode and `scripts/short-term-pass-demo.ts` depends on it; challenge limits are 15-minute windows with a per-challenge lock (§5A.1 wants hourly windows and a 15-minute address lock); v1.2 `DOCS.terms` promises "Full refund any time before the first valid day" while PRD D15/D22 forbid online refunds.
**Not verified locally:** Pay Page dev behaviour (B1); deployed universal-wallet acceptance of entry metadata and of a `MEMBER` owner without an agreement number (L3); any email provider (L1).
**Path conventions:** `UI/` = `repos/online-join-ui/src/`, `UI-T/` = `repos/online-join-ui/__tests__/`, `BFF/` = `repos/online-join-bff/src/`, `TOOLS/` = `tools/day-pass-harness/` in this planning repo.
**Chapter:** none (`docs/chapters/` does not exist).
**Branching (interview):** all product commits land on `prospect-wallet/sprint-0001` in both repos so PRs #96 and #524 absorb the review changes; commit messages start "Sprint 0002". No stacked branches.
**Sprint 0001 (interview):** ledger status `done`; header note "G2 (design parity) and G4 (hosted Pay Page) transferred to SPRINT-0002 gates S2 and S5 — transferred, not passed".

## Pyramid Index

- **L0:** Bring the Sprint 0001 Day Pass build to parity with Design HTML v1.2 and PRD v3.4 Round 4 — consent and Pay in the Order Summary sidebar, the §4.5 four-document consent set recorded server-side with template versions, rendered hashes and the exact Pay button text, a real Pay Page embed as the only new-card entry, an emailed code for every buyer before any lookup outcome is revealed, save-card default off writing a UUID-keyed entry with consent metadata to the prospect wallet behind the existing gate, marketing opt-in as its own record — and stand up a reproducible harness (parity loop with a terminating criterion, OTP outbox reader, autofill-off browser policy, three independent `claude -p` simulated users judged by server state) that proves it with no real card and no live charge.
- **L1:**
  - **A — Contract v2 and freeze (both lanes, 1.5–2 days).** Identify/verify union with lookup after code consumption; `ConsentDocumentSet` + `consentRevision`; `PurchaseRequest.attestation`; `mobile` required; `STP_TEST_HOOKS` policy; fixtures (Core `m@m.com` parity twin, consent templates with PRD refund copy, disposable-domain list); Inter woff2 assets; approved-delta manifest; husky in the BFF clone; Sprint 0001 status resolved.
  - **B — BFF (CR-02, 03, 04, 05, 06, 09, PR-03).** Every email gets a code; verify reveals `recognized | newVisitor | unresolved`; §5A.1 limits and address lock; consent documents, order consents, consent-events route, purchase snapshot; capture defaults `paypage`, mock capture and testing routes only behind hooks; UUID `providedId` and `oj_*` entry metadata; demo script reads codes from the outbox before `debug.code` is removed.
  - **C — UI (CR-01, 03, 04, 05, 07, 08, 09).** v1.2 shell and tabs; identify with selected offer card and inline code entry; sidebar skeleton → date/rows/consent block/Pay → receipt; generic document dialog; recognized "We found you." with `.paysel`; new visitor with required mobile, notices and marketing opt-in; `.savecard` switch default off; `PayPageEmbed` with real readiness and Retry; `TestCardPanel` behind hooks only; done per v1.2; self-hosted Inter; every demo help line removed.
  - **D — Harness in `TOOLS/` (PR-01…PR-04).** `parity` (nine states plus four dialogs × two widths, frozen clock, masks, 0.5 % pixel ratio + zero semantic deltas minus approved deltas, twice-consecutive pass, 8-iteration cap), `otp-sink` (hooks-only outbox route keyed by checkout), `browser` (fresh profile, autofill and payments off, self-test), `agents` (scripted smoke, then three independent `claude -p` personas judged by `GET /testing/state` correlated by run and checkout id).
  - **E — Loops and proof.** Parity loop to termination; agent runs recorded; hosted proof as a B1-gated step covering a first-time buyer and expired-card recovery; lint/build/coverage in both repos; contract v2, validation docs, readiness register (CF-01…CF-03 rows), `docs/SEMANTIC-INDEX.md`, ledger, PRs updated.
- **L2:** §Overview · §Use Cases (U1–U22) · §Architecture (state machine; consent model; capture policy and test hooks; wallet write; parity loop; agents; UI structure) · §Implementation Plan (A–E with files) · §Files Summary · §Definition of Done (S0–S9; carried L1–L5; CF rows) · §Risks · §Dependencies · §Open Questions.

## Overview

Sprint 0001 shipped a working Day Pass checkout whose screens follow the Riverside demos. The 2026-09-10 review compared it with the Director of Design HTML v1.2 and PRD Round 4 and produced nine build changes, four harness requests and three confirmations. This sprint changes the existing implementation; it does not rebuild it.

**What changes.** (1) Identify is email-only with the single catalog offer rendered as a selected offer card; code entry is inline ("Check your email!", read-only email + Change, six inputs, Resend code, "Verify and continue"). (2) Every submitted email receives a code; the directory lookup runs only after the code is consumed, so nothing about the address is revealed before possession is proven (CR-05, D35, §5A.1). (3) The single terms gate is replaced by the §4.5 consent block in the Order Summary sidebar — "I'm 18 or older" checkbox, Liability Waiver checkbox, the "By tapping **Pay $X and get my pass**…" sentence linking Pass Terms and Privacy Notice — and the Pay button moves there too; four versioned documents open in one dialog; pass terms and privacy are recorded at Pay against the server's canonical button text (CR-01, CR-02, D42, D43). (4) Card capture is the Pay Page embed in every non-test mode, wired like membership's `PaymentPageWithPayPage`, with real readiness from the SDK; the fixture picker the review saw exists only as a test-hook panel (CR-03, CR-04, D44). (5) Save card is a switch, default **off**, with the stored-credential description and "Stored card terms"; a consented save writes a UUID-keyed entry with `oj_*` consent metadata to the **prospect** wallet through the existing gated path (CR-06, D45). (6) New visitors must give a mobile number (D37); the email field carries the transactional notice, the mobile field the SMS notice, and an unchecked "Keep me posted about joining {Brand}" opt-in is its own record (CR-09, D32b). (7) Every generator help line is removed (CR-07). (8) A parity loop, an OTP outbox reader, a browser policy and a simulated-user runner exist as documented, runnable tooling (PR-01…PR-04, D47).

**What does not change (carried from Sprint 0001).** Route `/signup/day-pass?club=NNNNN` (→ `/signup/pass` on completion); top-level only; `OJ-PASS-SESSION` opaque cookie with the server-side `CheckoutStore`; `/api/short-term-pass`; flag `oj-short-term-pass-checkout` + `onlineProspects` enforced server-side; `STP_ADAPTER_MODE=mock|platform` with production refusing mock; internal naming `ShortTermPass`; purchase order authorize → persist prospect → consented wallet write → finalize sale → issue → deliver, synchronous with `Idempotency-Key`; Pay readiness-gated, never token-gated; no PAN in the React tree; pass sessions polled through `/checkouts/:id/capture` while generic Pay Page routes refuse them; BFF `erasableSyntaxOnly`; wallet identity `(memberId, MEMBER, org)` with the owner-metadata allowlist; `STP_WALLET_WRITES` false until the backend dedup fix ships (L3). Existing-member match still proceeds as member; last-four step-up, trusted devices and D12 member blocking are **not** added (readiness items).

**Out of scope by decision (merge notes).** Per-person waiver reuse store (D24 → readiness item; the waiver checkbox is always presented); separate test-server entrypoint; SMTP/Mailpit lane (design note only); disposable-domain provider (fixture list only); codex/agy agent runners.

## Use Cases

Fixtures (mock adapters): default club **90030 Riverside Athletic Club**, "1-day pass" USD 18.00, Jordan Reyes `jordan.reyes@email.com` / `(555) 019-2231` / Visa 4242 "Saved in the app last week". Parity club **90033 Core Health and Fitness Club — South**, "Gym Floor" USD 25.00 with perks "Classes", "Steam & Sauna", "Basketball court", gains a Jordan twin `m@m.com` (same name, phone and card) so the loop compares exact v1.2 text. Mock OTP is random in browser runs and read from the outbox; `STP_MOCK_OTP_CODE` may pin it for unit fixtures only. Widths 1440 and 375.

| ID | Behaviour and required result | CR / PRD | Tasks |
|---|---|---|---|
| U1 | Identify: header "Get your day pass!" / "Choose your pass, then enter your email"; selected offer card (checked radio, "Selected" chip, icon, price without cents, name, perks) beside an "Email" field (`type=email`, placeholder "Add your email here") with secondary "Continue"; help under the field "We'll email you a one-time code and your receipt" (approved delta, §4.5); sidebar shows two skeleton blocks and no fine print; no other help text | CR-07, CR-08 | C2, C3 |
| U2 | Non-email → field `aria-invalid`, help becomes "Enter a valid email address."; phones never accepted as identity | D35, §D | C2 |
| U3 | Any syntactically valid, non-disposable email → code sent; response identical in shape, status and timing floor for known and unknown addresses; header "Check your email!" / "Enter the 6-digit code we sent to **{masked}**"; email read-only + secondary "Change"; label "6-digit code", six inputs, help "Check your email!", link "Resend code", primary "Verify and continue" disabled until six digits | CR-05, §5A.1 | B1, B2, C2 |
| U4 | Change → `DELETE /checkouts/:id/identity`; challenge discarded; email editable with the typed value kept; stale responses ignored | CR-08 | B1, C2 |
| U5 | Correct code, unique match → `recognized`: header "Welcome back, {first}" / "Confirm your details and pay"; success alert "**We found you.** Your saved card is ready — nothing to re-enter."; Your info rows Name / Email (full) / Mobile (masked); Payment `.paysel` chip with source and check; "Use a different card" ↔ "Enter a new card. [Use Visa •••• 4242 instead]" + card form + save switch; if the person has no mobile on file a required Mobile field appears under Your info (approved delta, D37) | CR-05, CR-08 | B1, C4 |
| U6 | Correct code, no match → `newVisitor`: header "Welcome — a few details" / "Email **{email}** Edit"; First name, Last name, **Mobile number** (required) help "We'll text your pass here on the day." plus the SMS notice; unchecked "Keep me posted about joining {Brand}"; Payment with the hosted form and `.savecard` switch; danger alert for form errors; **no Pay button in the panel** | CR-05, CR-09, D37 | B1, C5 |
| U7 | Correct code, more than one record → `unresolved`: state back to identify with the desk-help copy; no prospect, no card shown; shown only after verification | §5A.2 | B1, C2 |
| U8 | Wrong code ×5 → address locked 15 min (verify and resend refused with one generic message); expired → "That code expired. Request a new one."; 6th send per address per 60 min or 21st identify per IP per 60 min → 429 with `retryAfterSeconds`; limits span checkouts and clubs | §5A.1 | B2 |
| U9 | Directory failure after a consumed code → 503 retryable; `emailVerifiedAt` kept; Retry re-runs the lookup without a new code | — | B1 |
| U10 | Sidebar from recognized / newVisitor: "Order Summary" / "A breakdown of your order with us"; "Day pass applies on" date (defaults to club-local today, `min` today, help = day label); "1-day pass · {Product}"; "Paying with" when known; Total; consent block; Pay full width; fine print "No membership. No recurring billing. Your card stays on file at the club — not on this website." | CR-01, CR-08, §D | B3, C3 |
| U11 | Consent block: checkbox "**I'm 18 or older.** Under 18? Visit the front desk with a parent or guardian."; checkbox "I've read and agree to the [Liability Waiver]"; sentence "By tapping **Pay $X and get my pass**, you agree to {Brand}'s [Pass Terms] and acknowledge the [Privacy Notice]."; Pay enabled only when day && adult && waiver && payment ready && (newVisitor → profile complete) && no request in flight; pressing Pay while incomplete toasts "Please confirm you're 18 or older" / "Please agree to the Liability Waiver" / "Complete the card information to continue" | CR-01, CR-02, D42 | B3, C3 |
| U12 | Each of the four document links opens one dialog titled per document with body, meta footer and Close; the waiver dialog also has "Agree and close" which checks the waiver (`method:'modal'`); opening is never acceptance or a gate; open/close post consent-events; Escape and focus return work | CR-02, §4.5 | B3, C3 |
| U13 | Server record: adult (server time); waiver (`templateVersion`, `renderedHash`, method, time); stored-card disclosure version shown whenever save is on; marketing opt-in (default false, copy version); notices shown with versions; pass terms and privacy accepted at Pay with the exact button text and `consentRevision`; stale revision or hash → 409 `STATE_CONFLICT` with refreshed `consent` and no authorization; one snapshot per purchase, none on idempotent replay | CR-02, CR-09, §5A.10 | B3, B4 |
| U14 | Save switch default **off**; description "Save {**{Brand} ····{last4}** \| this card} to your {Brand} wallet. It's charged only when you choose and confirm a purchase — here, in the app, or at the desk. We'll email you if anything about it changes. Remove it anytime in the app or at the desk. [Stored card terms]"; toggling toasts "Card will be saved — charged only when you confirm a purchase" / "Card won't be saved" | §4.5 Tier 1, CR-08 | C6 |
| U15 | New card: the Pay Page hosted form is the only card entry; loading state; load-failure or `closed` → alert "Unable to load the payment form." with Retry (new session); `formReady` from the SDK `onLoad`; Pay → `submit()` → bounded poll → purchase; a missing embed ref is an error | CR-03, CR-04, D44 | B5, C6 |
| U16 | Mock capture route answers 404 unless `STP_TEST_HOOKS=true`; with hooks and `STP_CAPTURE_MODE=mock` the slot renders `TestCardPanel` (buttons per fixture card, badge "TEST MODE — fixture cards, no card details are entered on this site", never a `<select>`); production boot refuses hooks, test clock and mock capture; testing routes 404 when hooks are off (router-stack test) and 403 without loopback + key | CR-04, PR-03 | B5, C6 |
| U17 | Done: header "You're in, {first}" / "Your pass is ready"; pass block (QR, "1-day pass · {day}", "Show this at the front desk, or just say your name. We emailed it to {masked} too."); success alert "**{Brand} •••• {last4} saved to your wallet**" + "Next time — here, in the app, or at the desk — you'll just verify your email and pay." for an existing saved card **or** a newly saved card; help "You chose not to save a card. Next time you'll enter it again." for a new unsaved card; the Sprint 0001 wallet-retry alert for a failed save (approved delta); buttons "Get the {Brand} app" (secondary) then "Start again"; sidebar "Receipt" / "Paid — this is your record", "Valid {day}", "Paid with", "Paid"; fine print "Receipt emailed to {masked}. Your card stays on file at the club — not on this website." | CR-08 | C7 |
| U18 | New visitor, save on → authorize → prospect persisted (email + mobile) → owner `(memberId, MEMBER, org)` → entry with a per-purchase UUID `providedId` and `oj_storedCardConsentVersion`/`oj_storedCardConsentAt`/`oj_purchaseId` metadata → sale → issue → deliver; wallet-retry reuses the same `providedId` and reads back before treating a duplicate as success; save off → no wallet call | CR-06, D45 | B6 |
| U19 | Parity: `npm run parity` renders identify, code-entry, recognized, recognized-new-card, new-visitor, done-saved, done-not-saved plus the four dialogs, at 1440 and 375, for the prototype and the build with the same frozen clock; masks hosted-field internals, QR modules, `.proto`, `#syslog`, `.toast`; passes when the differing-pixel ratio outside masks is ≤ 0.5 % per state × width and there are zero text/computed-style deltas on the named element list except approved deltas; toast text asserted separately; twice-consecutive pass required; 8-iteration cap exits nonzero with the unresolved list | CR-08, PR-01 | D1, E1 |
| U20 | OTP sink: `otp-sink latest --checkout <id>` returns the last code for that checkout from `GET /testing/outbox?checkoutId=` (hooks, loopback, key); never in production | PR-03 | B5, D2 |
| U21 | Browser policy: every harness Chrome has a fresh temp profile, autofill and payment handlers disabled, no signed-in account; self-test types into a card-number-shaped input and asserts no suggestion popup; fixture cards only (4242 approved, 1111 expired = invalid); no real PAN in tools or docs | PR-04 | D3 |
| U22 | Agents: after one scripted smoke run, `agents run --n 3` starts three independent `claude -p` sessions (own Chrome profile, checkout, email, transcript) for first-time save-on, first-time save-off, returning saved-card; each completes through the real browser using the sink and fixture cards; the runner judges by `GET /testing/state?checkoutId=` (purchase COMPLETE, wallet status, consent snapshot, outbox pass message) correlated by run id; transcripts, sanitized screenshots and verdicts recorded | PR-02, D47 | D4, E2 |

Regression (always): existing signup, guest and Pay Page suites green; membership `PayPageEmbed` behaviour unchanged; Sprint 0001 demo script green; lint/build clean; coverage ≥ floors.

## Architecture

### Identify → verify (CR-05, §5A.1)

```
BFF state:  identify ──POST /identify {email}──▶ challenge ──POST /verify {code}──▶ recognized | newVisitor | identify (unresolved)
                ▲                                    │ DELETE /identity (Change)
                └────────────────────────────────────┘
UI step:    identify (codeEntry=false) ─▶ identify (codeEntry=true) ─▶ recognized | newVisitor ─▶ submitting ─▶ complete
```

- `POST /checkouts/:id/identify {email}`: validate (`parseContact` rejects phones; `fixtures/disposableDomains.ts` → 400 "Use a permanent email address."); **no directory call**; issue a code for every valid address; response always `{outcome:'challenge', contact:{channel:'email', masked}, challenge:{expiresAt, resendAfter, attemptsRemaining}}`. `altChannelAvailable`, `switch-channel` and `debug` are removed. The 300 ms floor stays.
- `POST /checkouts/:id/verify {code}`: consume atomically (challenge id and checkout generation compared inside the store mutation; wrong-attempt counts updated atomically), rotate the session, set `emailVerifiedAt`, **then** `directory.findByContact`: unique → bind member + home club, create the order shell, `{outcome:'recognized', person, contact, order, consent}`; none → `state:'newVisitor'`, create the order shell, `{outcome:'newVisitor', contact, order, consent}`; ambiguous → `state:'identify'`, `{outcome:'unresolved', contact}`. Directory error → 503 `UPSTREAM_UNAVAILABLE` retryable; `POST /verify` with `{retryLookup:true}` re-runs the lookup while `emailVerifiedAt` is set and the code is consumed (bounded to 3).
- Limits: 5 sends per `email` per 60 min and 20 identifies per IP per 60 min (`WindowLimiter`, window changed), spanning checkouts and clubs; 5 wrong codes → `lockedAddresses[email] = now + 15 min` in the `CheckoutStore` adapter, refusing verify and resend with one generic message; code 6 digits, 10-minute TTL, single use, 30-second resend cooldown. In-memory by declaration; shared store is L1/L4.
- `POST /checkouts/:id/challenge {action}` enum shrinks to `['resend']`. Snapshot rehydrates the inline code entry from `challenge`.
- A `newVisitor` checkout has a verified email but no bound member; `GET /wallet` answers `NOT_VERIFIED`; capture, order and purchase require `emailVerifiedAt`.

### Consent model (CR-01, CR-02, CR-09, §4.5, §5A.10)

`ClubCatalogPort.getConsentDocuments(club, offer, order) → ConsentDocumentSet` replaces `getTerms`.

```ts
interface ConsentDocument { id:'waiver'|'passTerms'|'storedCard'|'privacy'; title; templateVersion; renderedHash; html; meta; requiresAffirmativeAct; approval:'PROPOSED'|'APPROVED' }
interface ConsentNotice   { id:'emailTransactional'|'smsTransactional'|'marketingOptIn'; copy; version }
interface ConsentDocumentSet { documents; notices; waiverRequired; payButtonText; consentRevision; approval }
```

Templates: `BFF/services/shortTermPass/fixtures/consentTemplates.ts`, functions of `{clubName, brandWord, offerName, amount, currency, visitDate}` with the v1.2 `DOCS` text as default **except** Pass Terms refunds, which follow PRD D15/D22 ("Refunds: none online. Any refund is at the club's discretion, in club.") with the delta recorded. `approval:'PROPOSED'` lives in the fixture, the config and the capability report — never in the customer UI. Per-club override `CatalogClub.consentOverrides?: Partial<Record<id,{html, templateVersion}>>` (existing `prospectTerms` maps to `passTerms`); tier is `tier1` when save is on. `renderedHash = sha256(canonical title + meta + html)`; Pass Terms re-render when `visitDate` or amount changes. `payButtonText = \`Pay ${money(amount)} and get my pass\``. `consentRevision = sha256(all renderedHashes + notice versions + payButtonText)`; returned on `POST /checkouts`, every `PUT /order` response and every `verify` outcome that creates an order.

Order state replaces `terms`:

```ts
consents: { adult:{attested, at?}; waiver:{required, accepted, templateVersion, renderedHash, method?:'checkbox'|'modal', at?};
            storedCard:{shownVersion, shownAt?}; marketingOptIn:{optedIn:false|true, version, at?};
            notices:{emailTransactional:{version, shownAt}; smsTransactional?:{version, shownAt}} }
saveCard: false
```

`PUT /checkouts/:id/order {visitDate?, adult?, waiver?:{accepted, method, renderedHash}, saveCard?, marketingOptIn?, smsNoticeShown?}`; `order.ready = date valid && adult && (!waiver.required || waiver.accepted)`; waiver `renderedHash` mismatch → 409 "The Liability Waiver has been updated…" with the refreshed set. Preference changes update state only (no event per toggle). `POST /checkouts/:id/consent-events {type:'document-opened'|'document-closed', documentId, renderedHash}` appends bounded availability evidence (max 50 per checkout).

`PurchaseRequest.attestation = {consentRevision, payButtonText}`; `validatePurchase` recomputes both and refuses with 409 `STATE_CONFLICT` (`details.reason`, refreshed `consent`) before any authorization; the revision is part of the idempotency fingerprint. At `VALIDATED` the orchestrator writes **one** consent snapshot on `PurchaseRecord.consents` (adult, waiver, stored-card when saved, marketing, notices, pass terms + privacy with `payButtonText`, all hashes, checkout id, surface `web-online-join`, hashed IP and UA); after person persistence the snapshot gains `memberId`. Replay under the same key returns the original result and writes nothing. `PurchaseResult.consent = {passTermsVersion, waiverVersion?, storedCardVersion?, marketingOptIn}`. `ConsentLedgerPort` is **not** built this sprint; the purchase record is the evidence store and a durable/exportable ledger is a readiness row (PRODUCT+LEGAL+PLATFORM).

### Capture policy and test hooks (CR-03, CR-04, PR-03)

| Setting | Before | After |
|---|---|---|
| `STP_CAPTURE_MODE` default | `paypage` in platform mode, `mock` in mock mode | **`paypage` always** |
| `STP_CAPTURE_MODE=mock` | any non-production | only with `STP_TEST_HOOKS=true`; boot guard refuses otherwise |
| `STP_TEST_HOOKS` (new) | — | enables mock capture, `GET /api/short-term-pass/testing/outbox?checkoutId=`, `GET /testing/state?checkoutId=`, `STP_TEST_CLOCK`; refused in production; testing routes require loopback peer address **and** `X-STP-TEST-KEY: $STP_TEST_HOOKS_KEY`; mounted only when hooks are on |
| `STP_TEST_CLOCK` (new) | — | ISO instant for `deps.now()` when hooks are on |

`POST /checkouts` returns `captureMode` and `testHooks:boolean`. `CardCaptureSlot` renders `PayPageEmbed` unless `captureMode==='mock' && testHooks`, then `TestCardPanel`. `MockCardCapture.tsx` is deleted; the PCI static scan adds "no `<select>` under `components/CardCapture*`". Hosted flow as in membership: `createHostedSession` on entering a new-card state → `PayPageEmbed sessionUrl payPageOrigin onReady onError` → `formReady` from the additive `onReady` prop (fires on the SDK `onLoad`'s rendered state; membership callers unaffected) → Pay → `submit()` → `pollCapture` (15 × 1 s) → `POST /purchases {kind:'hosted', payPageSessionId, attestation, profile}`. `closed`, embed error or session-creation failure → "Unable to load the payment form." + Retry (revoke reference, new session). Customization variables `{colorBackground:'#ffffff', colorBrand:'#239cd3'}`. Without B1 the hosted slot shows the load-failure alert; the demo doc says so.

### Wallet write (CR-06)

`PurchaseRecord.walletProvidedId = crypto.randomUUID()` allocated before the first save and reused by `retryWalletStep`; `CreateCreditCardInput.providedId` becomes that UUID; `CreateCreditCardInput.metadata` allowlist `['oj_storedCardConsentVersion','oj_storedCardConsentAt','oj_purchaseId']` (prefix `oj_`, never `dt_*`); `MockWallet` stores and exposes it; `PlatformWallet.createCreditCard` sends it; on response loss, query by `providedId` and verify owner/token before treating a duplicate as success; owner metadata allowlist and forbidden list unchanged; recursive payload scan allows `oj_*`. Enablement checklist (register row): `STP_WALLET_WRITES=true`, `UNIVERSAL_WALLET_API_URL`, OAuth authorities, deployed dedup fix (hazard #10), owner-scoped query verified, `pgToken` mapping, metadata acceptance, smoke against dev with fixture Jordan. `STP_WALLET_WRITES` alone does not select `PlatformWallet` in mock adapter mode; a dev smoke needs `STP_ADAPTER_MODE=platform` with mock payment/sale, documented as a separate lane and run only if credentials appear.

### Parity loop (PR-01, CR-08)

`TOOLS/parity/` — `puppeteer-core` (channel chrome, `CHROME_PATH` supported), `pixelmatch`, `pngjs`, pinned with a lockfile in `TOOLS/package.json`.

- **States (11):** identify, code-entry, recognized, recognized-new-card, new-visitor, done-saved, done-not-saved, dialog-waiver, dialog-pass-terms, dialog-stored-card, dialog-privacy. Widths 1440×1000 and 375×900, DPR 1, fixed locale/timezone/clock, animations and caret disabled, `document.fonts.ready` awaited, Inter asserted loaded on both sides.
- **Prototype driver:** `file://…/day-pass-v1.2.html`; inject CSS hiding `.proto` and `#syslog` (layout accounted for); freeze `Date` via `evaluateOnNewDocument`; drive its DOM (email → Continue → six digits → "Verify and continue" → `#day` → adult → waiver → mocked card fields → save toggle → Pay). `m@m.com` = recognized; any other email = new visitor.
- **Build driver:** BFF `:3000` with `STP_ADAPTER_MODE=mock STP_CAPTURE_MODE=mock STP_TEST_HOOKS=true STP_TEST_HOOKS_KEY=… STP_TEST_CLOCK=…`; club `90033`; same interactions; code via the outbox route; card via `TestCardPanel`.
- **Masks (by selector bbox):** prototype `.payfields` ↔ build `.card-slot` internals (wrapper bounds and neighbouring spacing are compared, not masked), `.qr` modules, `.proto`, `#syslog`, `.toast`. Mask geometry is asserted so an oversized mask fails the run.
- **Criterion:** pixelmatch threshold 0.1; differing-pixel ratio outside masks ≤ 0.5 % per state × width; zero deltas on `elements.json` (~45 selector pairs) for text (whitespace-normalised) and computed `font-family, font-size, font-weight, line-height, letter-spacing, color, background-color, border-color, border-radius, padding, height, width` (geometry rounded to 0.5 px) except entries in `approved-deltas.json`, each citing a PRD/CR line. Missing or extra controls and horizontal overflow fail regardless. Calibrate by rendering the prototype against itself twice before evaluating the build. Toast text asserted separately.
- **Termination:** all states × widths pass twice consecutively → exit 0 with `docs/validation/parity/sprint-0002/report.{html,json}` and PNG pairs/heatmaps; else exit 1 with the delta list. Loop = run → fix product files → run; cap 8 iterations, then report unresolved differences — never a pass. Thresholds, masks and approved deltas change only by a human with a recorded reason.

Initial approved deltas: email transactional notice under the email field; SMS notice and marketing opt-in rows; required Mobile under Your info when missing; Pay Page frame replacing the mocked card fields; static location label without popup semantics; Retry/error affordances; wallet-retry alert on done; blank-date help string never rendered; refund sentence in Pass Terms.

### Simulated users (PR-02, PR-03, PR-04)

- `TOOLS/browser/`: daemon + CLI over puppeteer-core; per session `--user-data-dir=<tmp>`, `--no-first-run`, `--disable-sync`, `--password-store=basic`, `--disable-features=AutofillServerCommunication,PaymentRequest`, preferences `{"autofill":{"credit_card_enabled":false,"profile_enabled":false},"payments":{"can_make_payment_enabled":false}}`; commands `open`, `click <selector|text>`, `type`, `read` (accessibility text), `wait`, `screenshot`, `url`, `close`; sensitive typing redacted from transcripts; self-test per U21.
- `TOOLS/otp-sink/`: `latest --checkout <id>` and `wait --checkout <id> --timeout 30s` over the hooks-only outbox route.
- `TOOLS/agents/`: `smoke` (one scripted run through the broker, must pass before autonomous runs) and `run --n 3 --personas first-save-on,first-save-off,returning-saved`; each persona spawns `claude -p --output-format json --dangerously-skip-permissions` with a brief allowing only the `browser` and `otp-sink` CLIs, fixture card names only, distinct email `agent-<persona>-<runId>@stp.test` (returning uses `jordan.reyes@email.com` at 90030 with a fresh checkout), bounded steps and time; the judge reads `GET /testing/state?checkoutId=` and asserts persona expectations (COMPLETE; `wallet.status` saved / not-requested / existing; snapshot present; `marketingOptIn` false unless opted in). Independent = process + profile + cookie + email + transcript, no shared scratch. Output under `docs/validation/agents/sprint-0002/<runId>/`. No live charges: mock adapters or, with B1, hosted Pay Page dev with mock payment/sale.

### UI structure after this sprint

```
routes/ShortTermPass/
  ShortTermPassPage.tsx           steps identify | recognized | newVisitor | submitting | complete; CheckoutController provider
  components/CheckoutController.tsx  owns the PayPageEmbed ref, the single capture lifecycle and the Pay action for both panels
  components/CheckoutShell.tsx    v1.2 .dt-header (brand word + tag, static .dt-switcher label, "Secure checkout") + nav.dt-tabs
  steps/IdentifyStep.tsx          OfferCard + email + InlineCodeEntry (VerifyStep.tsx deleted)
  steps/RecognizedStep.tsx        header, "We found you." alert, kv rows, .paysel, new-card branch, required Mobile when missing
  steps/NewVisitorStep.tsx        header, names, Mobile (required) + notices + MarketingOptIn, Payment
  steps/DoneStep.tsx              header, PassBlock, success alert / help / retry alert, actions
  components/OrderSummary.tsx     skeleton | date + rows + ConsentBlock + Pay | receipt
  components/{ConsentBlock,DocumentDialog,OfferCard,InlineCodeEntry,MarketingOptIn,SaveCardSwitch,TestCardPanel}.tsx  NEW
  components/{PayBar,TermsDialog,SaveCardToggle,MockCardCapture}.tsx  DELETED
  hooks/usePayAction.ts           builds attestation {consentRevision, payButtonText}; validates draftProfile with v1.2 messages
selectors  canPay = day && adult && waiver && paymentReady && profileComplete && !busy
slice      checkout.consent; order.consents; draftProfile {firstName,lastName,mobile}; capture.formReady only from onReady; no switchChannel
assets/fonts/inter-{400,500,600,700}.woff2 + @font-face in short-term-pass.scss (Google Fonts @import removed)
```

## Implementation Plan

**Sizing:** ~14 engineering days — A shared (1.5–2), then B (BFF, ~4) ∥ C (UI, ~5) ∥ D (harness, ~3, from day 2), then E (~2). Tests per task. Every task has a "done when".

### A — Contract v2 and freeze · 1.5–2 days · all lanes

| # | Task | Files | Done when |
|---|---|---|---|
| A1 | Record heads; `npm run prepare` in the BFF clone (husky/prettier); Sprint 0001 → ledger `done`, header note on G2/G4 transfer; ledger entry for this sprint | `docs/sprints/{ledger.yaml,SPRINT-0001.md}`; BFF clone | prettier runs on a BFF commit; ledger shows 0001 done, 0002 in-progress |
| A2 | Contract v2: identify/verify union (`retryLookup`), `challenge` enum `['resend']`, `ConsentDocumentSet`/`consentRevision` on `POST /checkouts`, `PUT /order` request/response, `POST /consent-events`, `PurchaseRequest.attestation`, `PurchaseProfile.mobile` required (replaces `secondaryContact`), `PurchaseResult.consent`, `testHooks`, testing routes, env matrix rows, error `details.reason`; representative requests and the 409 refresh example | MODIFY `docs/contracts/short-term-pass-bff.md` (§2, §4 v2, §6), `BFF/routes/shortTermPass/schemas.ts`, `UI/interfaces/api/shortTermPass.ts` | both repos type-check against v2; contract doc §4 lists every route with v2 shapes |
| A3 | Fixtures: Core 90033 gains Jordan `m@m.com` and the three perks; `disposableDomains.ts`; consent templates from v1.2 `DOCS` with PRD refund copy and PROPOSED marker; `createOrderShell` `saveCard:false`; `STP_MOCK_OTP_CODE` used only by unit fixtures | MODIFY `BFF/services/shortTermPass/fixtures/{catalog,directory}.ts`; NEW `fixtures/{consentTemplates,disposableDomains}.ts` | fixture tests green; `getConsentDocuments` returns four documents with hashes for both clubs |
| A4 | Parity inventory: `elements.json` (prototype→build selector pairs per state), `approved-deltas.json` with citations, v1.2 checksum; record the intent's reconciliation decisions in the UI validation doc | NEW `TOOLS/parity/{elements.json,approved-deltas.json}`; MODIFY `docs/validation/short-term-pass-ui.md` | every U1–U17 state has selector coverage; each approved delta cites a line |
| A5 | Inter assets: four woff2 files (OFL) under `UI/assets/fonts/`, `@font-face` rules, Google Fonts `@import` removed; `.dt-*` font stack unchanged | NEW `UI/assets/fonts/inter-*.woff2`; MODIFY `UI/styles/short-term-pass.scss` | build emits the woff2 files; no request to `fonts.googleapis.com` from the pass page |

**Exit:** v2 schemas compile in both repos; fixtures and templates tested; `TOOLS/parity/elements.json` complete; husky active; ledger updated.

### B — BFF · ~4 days · BFF lane

| # | Task | Files | Done when |
|---|---|---|---|
| B1 | **OTP for every email; lookup after consumption.** `identify()` email-only, no directory call, always issues; `verify()` consumes atomically, rotates, sets `emailVerifiedAt`, then resolves → `recognized` / `newVisitor` (order shell) / `unresolved`; `retryLookup`; `resetIdentity` clears everything; remove `switch-channel`, `altContact`, `debug` | MODIFY `BFF/services/shortTermPass/{identify,contact,person}.ts`, `routes/shortTermPass/{identify,verify,challenge,checkouts}.ts`, `ports/checkoutStore.ts` (`emailVerifiedAt`, `lookupAttempts`, `lockedUntil`) | U3–U7, U9 route tests green; identify responses for known/unknown addresses have identical key sets, status and floor; no directory mock call before verify |
| B2 | **§5A.1 limits.** Hourly windows (5/address, 20/IP) spanning checkouts; 15-minute address lock after 5 wrong codes refusing verify and resend; disposable check; timing floor; concurrency tests for two simultaneous verifies and stale-count overwrite | MODIFY `BFF/services/shortTermPass/{challenge,rateLimit}.ts`, `routes/shortTermPass/index.ts`; tests `identify/verify/challenge.test.ts` | U8 boundaries pinned; fresh cookie or another club cannot reset the lock |
| B3 | **Consent set, order consents, events.** `getConsentDocuments` on port + mock + platform (`prospectTerms` → `passTerms`); `consentRevision`; `StoredOrder.consents`; `applyOrderUpdate` for adult / waiver / saveCard (records `storedCard.shownVersion`) / marketingOptIn / smsNoticeShown; `isOrderReady`; waiver hash mismatch 409; `POST /consent-events` bounded; capability report rows | MODIFY `ports/clubCatalog.ts`, `adapters/{mock,platform}/catalog.ts`, `services/shortTermPass/order.ts`, `routes/shortTermPass/{order,checkouts,index}.ts`; NEW `routes/shortTermPass/consentEvents.ts`; tests | U10–U13 order-side rules pinned; club `90032` override test proves per-club templates |
| B4 | **Demo script first, then pass-terms-by-Pay.** (a) Rewrite `short-term-pass-demo.ts` to read codes from `MockOutbox` / the testing route and to drive email-only OTP for every run, save off by default, consent assertions; **land before `debug` removal in B1 is merged** (same commit series). (b) `validatePurchase` checks `attestation`; one consent snapshot at `VALIDATED`, `memberId` linked after persistence, none on replay; `PurchaseResult.consent`; `mobile` required for new visitors ("Please add your mobile number."), stored as prospect phone | MODIFY `BFF/scripts/short-term-pass-demo.ts`, `services/shortTermPass/{purchaseOrchestrator,idempotency}.ts`, `routes/shortTermPass/purchase.ts`, `ports/purchaseStore.ts`; tests `purchase.test.ts` | demo exits 0 on every run; 409 on stale revision/button text with no authorization; replay writes no second snapshot |
| B5 | **Capture policy and test hooks.** `captureMode` default `paypage`; `testHooks`, `testHooksKey`, `testClock`; boot guard; `POST /checkouts` returns `testHooks`; `mockCaptureRoute` requires hooks; `routes/shortTermPass/testing/routes.ts` (`/testing/outbox`, `/testing/state`, loopback + key, sanitized, no tokens) mounted only with hooks; `deps.now` honours the clock | MODIFY `config.ts`, `env.ts`, `.env.example`, `routes/shortTermPass/{index,checkouts,session}.ts`; NEW `routes/shortTermPass/testing/routes.ts`; tests `config.test.ts`, NEW `testingRoutes.test.ts` | U16 pinned incl. the router-stack 404 test and production refusal |
| B6 | **Prospect-wallet save.** UUID `walletProvidedId` on the purchase record; `oj_*` metadata allowlist; `MockWallet`/`PlatformWallet` updated; read-back on response loss; wallet-retry reuses id and metadata; payload scan allows `oj_*`; enablement checklist in register §10 | MODIFY `ports/{wallet,purchaseStore}.ts`, `services/shortTermPass/wallet.ts`, `adapters/{mock,platform}/wallet.ts`, `purchaseOrchestrator.ts`; tests `walletWrites.test.ts`, `platformWallet.test.ts`; contract §10 | U18 pinned; platform adapter unit test asserts a UUID `providedId` and the metadata shape |

**Exit:** U3–U13, U16, U18 pass at the router level; demo green; production boot refuses every hook; coverage ≥ floors.

### C — UI · ~5 days · UI lane

| # | Task | Files | Done when |
|---|---|---|---|
| C1 | **Slice, selectors, service (v2).** `checkout.consent`; `order.consents`; `identifyContact` → code entry always; `verifyCode` three outcomes + `retryLookup`; `changeContact` (was `startOver`); remove `switchChannel`; `draftProfile`; `capture.formReady` only via `onReady`; `canPay`; service adds `postConsentEvent`, `attestation` on `purchase` | MODIFY `UI/reducers/shortTermPass/shortTermPassSlice.ts`, `UI/selectors/shortTermPass.ts`, `UI/services/shortTermPass.ts`; tests | slice/selector tables and service tests green against v2 fixtures |
| C2 | **Identify with inline code (CR-05, 07, 08).** `OfferCard`; `.identify-row`; email field + §4.5 help + error; `InlineCodeEntry` (read-only email + Change, label, six inputs with auto-advance/backspace/paste, help, Resend with cooldown, "Verify and continue", locked/expired/throttled copy, unresolved copy, 503 Retry); delete `VerifyStep` | MODIFY `steps/IdentifyStep.tsx`; NEW `components/{OfferCard,InlineCodeEntry}.tsx`; DELETE `steps/VerifyStep.tsx` + test | U1–U4, U7, U9 pinned; no SMS copy remains |
| C3 | **Sidebar with consent and Pay (CR-01, 02, 08).** `OrderSummary` modes (skeleton / order / receipt) per U10, U17; `ConsentBlock` (adult, waiver, sentence, Pay with `canPay` and incomplete toasts); `DocumentDialog` (title, body, `.dt-modal-meta`, Close, waiver "Agree and close" → `method:'modal'`; open/close events); delete `PayBar`, `TermsDialog`; retire `pendingVisitDate` | MODIFY `components/OrderSummary.tsx`; NEW `components/{ConsentBlock,DocumentDialog}.tsx`; DELETE `components/{PayBar,TermsDialog}.tsx` + tests | U10–U12 pinned; date change re-fetches Pass Terms hash |
| C4 | **Recognized (CR-08).** Header/sub; "We found you." alert; kv rows; `.paysel` chip; new-card branch with `CardCaptureSlot` + `SaveCardSwitch`; required Mobile when missing; wallet loading/unavailable/empty kept | MODIFY `steps/RecognizedStep.tsx`, `components/SavedCardChip.tsx` | U5 pinned |
| C5 | **New visitor (CR-05, 07, 09, D37).** Header with Edit → `changeContact`; names; Mobile required + help + SMS notice (`smsNoticeShown` once); `MarketingOptIn` → `PUT /order {marketingOptIn}`; Payment; `.dt-alert.danger` with v1.2 messages; no Pay in panel | MODIFY `steps/NewVisitorStep.tsx`; NEW `components/MarketingOptIn.tsx` | U6 pinned; opt-in defaults false and never toggles from other actions |
| C6 | **Card capture (CR-03, 04).** `PayPageEmbed` additive `onReady`; `CheckoutController` owns the ref and lifecycle; `CardCaptureSlot` renders embed unless `mock && testHooks`; loading / failure Retry / `closed`; `TestCardPanel`; `SaveCardSwitch` default off with dynamic description and toasts; PCI scan rules | MODIFY `UI/routes/PaymentPage/components/PayPageEmbed.tsx`, `components/CardCaptureSlot.tsx`, `hooks/useShortTermPassCapture.ts`; NEW `components/{CheckoutController,TestCardPanel,SaveCardSwitch}.tsx`; DELETE `components/{MockCardCapture,SaveCardToggle}.tsx`; tests incl. `pci.test.ts` and a `PayPageEmbed` regression test for `onReady` absent/present | U14–U16 pinned; membership PaymentPage tests unchanged and green |
| C7 | **Done (CR-08).** Header; `PassBlock` copy; success alert for existing or newly saved card; not-saved help; retry alert; actions order; FAILED/RECONCILING kept | MODIFY `steps/DoneStep.tsx`, `components/PassBlock.tsx` | U17 pinned for all four card outcomes |
| C8a | **Shell, tabs, tokens (CR-07, 08).** `.dt-header` brand word/tag from catalog, static `.dt-switcher` label (no `aria-haspopup`), "Secure checkout"; `nav.dt-tabs` "Class · Membership · Day Pass · Visit"; v1.2 tab-row media rule replaces the Sprint 0001 375 px header wrap; `--ig-*` values re-verified | MODIFY `components/CheckoutShell.tsx`, `UI/styles/short-term-pass.scss`; NEW `CheckoutShell.test.tsx` | parity states identify/code-entry pass at both widths |
| C8b | **Main-panel styles.** `.identify-row`, `.offer`, `.inline`, `.otp`, `.kv`, `.paysel`, `.savecard`/`.switch`, `.payfields` wrapper, `.dt-alert.success/.danger`, `.dt-check` sub-label, `.links`, `.req`, `.dt-modal-meta` and dialog body rules; remove `.paybar`, `.termsrow`, `.toggle`, `.welcome`, `.pill-ok`, `.mock-capture`, `.row-links` | MODIFY `short-term-pass.scss`, `UI/components/dt/{DtCheckbox,DtAlert}.tsx` | parity states recognized/new-visitor/dialogs pass |
| C8c | **Sidebar and receipt styles.** `.skeleton`, `.dayfield`, `.srow`, `.total`, `.agree`, `.side-actions`, `.fine`, receipt rows; isolation test unchanged | MODIFY `short-term-pass.scss`; `isolation.test.ts` | parity states done-saved/done-not-saved and sidebar regions pass |
| C9 | **Page and pay action.** `CheckoutController` provider in the page; `usePayAction` builds `attestation` from `checkout.consent`; step switch without `verify`; every v1.2 copy string pinned; `shortTermPassTestData.ts` consent fixtures | MODIFY `ShortTermPassPage.tsx`, `hooks/usePayAction.ts`; tests | U11 gating table green; App test green |

**Exit:** U1–U7, U10–U17 in jest; `MockCardCapture`, `PayBar`, `TermsDialog`, `VerifyStep`, `SaveCardToggle` gone; lint/build clean; coverage ≥ 80/80.

### D — Harness · ~3 days · harness lane (from day 2)

| # | Task | Files | Done when |
|---|---|---|---|
| D1 | **Parity loop.** `TOOLS/package.json` + lockfile; `parity/run.mjs` (`--states --widths --club 90033 --bff --clock --out --max-iterations 8`); `drivers/{prototype,build}.mjs`; `compare/{pixel,semantic}.mjs`; `report/html.mjs`; mask-geometry assertion; self-tests for font, copy, missing-button and mask over-reach detection; README with the criterion and the human-only loosening rule | NEW `TOOLS/parity/**` | prototype self-render passes twice; Sprint 0001 build produces a failing diagnostic report |
| D2 | **OTP sink.** `otp-sink/cli.mjs` (`latest`, `wait`, `--checkout`) over the hooks-only route; README with the never-in-production rule | NEW `TOOLS/otp-sink/**` | returns the code for a fresh identify |
| D3 | **Browser policy.** daemon + CLI; flags and preferences; temp profile deleted on close; redaction; self-test per U21; `policy.md` | NEW `TOOLS/browser/**` | self-test passes; no suggestion popup on a card-number input |
| D4 | **Agent runner.** `agents/smoke.mjs` (scripted broker run); `agents/run.mjs`; `personas/*.md`; `runners/claude.mjs`; `judge.mjs` (state by checkout id, run id correlation); transcript/screenshot capture; summary | NEW `TOOLS/agents/**` | smoke completes against the Sprint 0001 build; judge reports the expected failures |
| D5 | **Dev orchestration.** `TOOLS/dev/{up,down}.sh` start the BFF with hooks env and the UI through the BFF, wait for 200, export the key; documented | NEW `TOOLS/dev/**`; MODIFY `docs/demos/short-term-pass-local-demo.md` | one command brings up the parity/agent environment |

### E — Loops and proof · ~2 days · all lanes

| # | Task | Evidence |
|---|---|---|
| E1 | **Parity to termination (CR-08).** Eleven states × two widths; fix; repeat; record iterations, ratios, approved deltas | `docs/validation/parity/sprint-0002/report.{html,json}` + PNGs; table in the UI validation doc |
| E2 | **Agent runs (PR-02).** Smoke, then `agents run --n 3`; optional fourth persona expired-card-then-recover; verdicts, transcripts, screens, state snapshots | `docs/validation/agents/sprint-0002/**`; summary in the UI validation doc |
| E3 | **Hosted proof (CR-03, B1-gated, standing task from A).** When the six variables exist: `STP_CAPTURE_MODE=paypage` through `:3000`; `demo --hosted`; agent personas first-time save-on **and** returning new-card typed into the hosted fields via the broker with the sandbox 4242; expired-card rejection then recovery; parity state recognized-new-card re-run with the real frame masked. Until then the register says "hosted capture unverified (B1)" | validation docs; contract §10 |
| E4 | **Quality.** `npm run lint`, `npm run build`, coverage in both repos; membership suites; Sprint 0001 demo; common test timezone documented for the pre-existing `transformers.test.ts` baseline | validation docs; ledger |
| E5 | **Docs, status, PRs.** Contract v2 final; register rows (consent ledger platform, wallet-write enablement, D24 waiver reuse, recognized marketing preference, email transport, CF-01 PM, CF-02 PM+LEGAL, CF-03 PM); traceability table CR/PR → task → commit → test → verdict incl. the CR-04 root-cause sentence; `docs/SEMANTIC-INDEX.md` gains `TOOLS/` and the file moves; ledger; PRs #96/#524 descriptions updated | `docs/contracts/short-term-pass-bff.md`, `docs/validation/short-term-pass-sprint-0002-traceability.md`, `docs/SEMANTIC-INDEX.md`, `docs/sprints/ledger.yaml`, `docs/sprints/drafts/SPRINT-0002-EXECUTION-SUMMARY.md` |

Proposed commands (implemented by this sprint):

```text
# planning repo
cd tools/day-pass-harness && npm ci
npm run dev:up                       # BFF :3000 with hooks + UI through the BFF
npm run parity -- --club 90033 --max-iterations 8
npm run otp-sink -- latest --checkout <id>
npm run browser -- self-test
npm run agents -- smoke
npm run agents -- run --n 3 --personas first-save-on,first-save-off,returning-saved
# BFF repo
npm run demo:short-term-pass
npm run demo:short-term-pass -- --hosted     # B1
```

## Files Summary

| Repo | Paths | Action |
|---|---|---|
| online-join-bff | `src/routes/shortTermPass/{schemas,identify,verify,challenge,checkouts,order,purchase,session,index}.ts` | MODIFY |
| online-join-bff | `src/routes/shortTermPass/consentEvents.ts`, `src/routes/shortTermPass/testing/routes.ts` (+ tests) | NEW |
| online-join-bff | `src/services/shortTermPass/{identify,contact,person,challenge,rateLimit,order,wallet,purchaseOrchestrator,idempotency,config}.ts`; `ports/{checkoutStore,clubCatalog,wallet,purchaseStore}.ts`; `adapters/{index,mock/catalog,mock/wallet,platform/catalog,platform/wallet}.ts`; `fixtures/{catalog,directory}.ts` | MODIFY |
| online-join-bff | `src/services/shortTermPass/fixtures/{consentTemplates,disposableDomains}.ts` | NEW |
| online-join-bff | `src/env.ts`, `.env.example`, `scripts/short-term-pass-demo.ts`, route/service tests | MODIFY |
| online-join-ui | `src/interfaces/api/shortTermPass.ts`, `src/services/shortTermPass.ts`, `src/reducers/shortTermPass/shortTermPassSlice.ts`, `src/selectors/shortTermPass.ts` | MODIFY |
| online-join-ui | `src/routes/ShortTermPass/ShortTermPassPage.tsx`, `steps/{Identify,Recognized,NewVisitor,Done}Step.tsx`, `components/{CheckoutShell,OrderSummary,CardCaptureSlot,SavedCardChip,PassBlock}.tsx`, `hooks/{usePayAction,useShortTermPassCapture}.ts`, `format.ts` | MODIFY |
| online-join-ui | `src/routes/ShortTermPass/components/{CheckoutController,OfferCard,InlineCodeEntry,ConsentBlock,DocumentDialog,MarketingOptIn,SaveCardSwitch,TestCardPanel}.tsx` | NEW |
| online-join-ui | `steps/VerifyStep.tsx`, `components/{PayBar,TermsDialog,SaveCardToggle,MockCardCapture}.tsx` (+ tests) | DELETE |
| online-join-ui | `src/routes/PaymentPage/components/PayPageEmbed.tsx` (additive `onReady`), `src/styles/short-term-pass.scss`, `src/components/dt/{DtCheckbox,DtAlert}.tsx`, `src/assets/fonts/inter-*.woff2` | MODIFY / NEW |
| online-join-ui | `__tests__/routes/ShortTermPass/**`, reducer/selector/service tests, `__tests__/App/App.test.tsx` | MODIFY / NEW / DELETE |
| this repo | `tools/day-pass-harness/{package.json,package-lock.json,parity/**,otp-sink/**,browser/**,agents/**,dev/**}` | NEW |
| this repo | `docs/contracts/short-term-pass-bff.md`, `docs/validation/short-term-pass-{ui,bff}.md`, `docs/demos/short-term-pass-local-demo.md`, `docs/SEMANTIC-INDEX.md`, `docs/sprints/ledger.yaml`, `docs/sprints/SPRINT-0001.md` (header) | MODIFY |
| this repo | `docs/validation/parity/sprint-0002/**`, `docs/validation/agents/sprint-0002/**`, `docs/validation/short-term-pass-sprint-0002-traceability.md`, `docs/sprints/drafts/SPRINT-0002-{BLOCKERS,EXECUTION-SUMMARY}.md` | NEW |
| Handoffs | B1 credentials in the BFF `.env`; LD flag (B2); CF-01…CF-03 owners; L3 wallet enablement | outside the cache |

Not modified: `mico/**`; wallet repos; `BFF/routes/payPage/index.ts` beyond Sprint 0001; `BFF/utils/proxyFactory.ts`; existing UI routes, `Header`, `Footer`; membership Pay Page behaviour.

## Definition of Done

Role slots: UI, BFF, QA, SECURITY, PRODUCT, DESIGN, PAYMENTS, IDENTITY, WALLET, PLATFORM, LEGAL. A gate with no named owner does not sign. Gates are numbered S0–S9 so they cannot be confused with Sprint 0001's G-gates.

| Gate | Owner | Passes when |
|---|---|---|
| S0 — Ready | UI+BFF | Contract v2 frozen (A2); husky active; `TOOLS/` installs with `npm ci`; Sprint 0001 status resolved; approved-delta manifest reviewed by DESIGN (or the UI lead with the list recorded) |
| S1 — Traceability | PRODUCT+QA | Table mapping each CR-01…CR-09 to commits and tests, each PR-01…PR-04 to a runnable command and README, each CF-01…CF-03 to a register row with an owner slot; CR-04 root cause stated |
| S2 — Parity terminated (carries Sprint 0001 G2) | DESIGN | `npm run parity` exits 0 twice consecutively for all eleven states at 1440 and 375 under the frozen criterion; report committed; every approved delta cites a line; iteration count recorded; an 8-iteration exhaustion is reported as unresolved, never as a pass |
| S3 — Consent recorded | PRODUCT+LEGAL(observer)+BFF | Purchase record shows adult, waiver (version, hash, method), stored-card version when saved, pass terms and privacy with the exact button text, marketing opt-in defaulting false, notices with versions; one snapshot per purchase; stale revision refused before authorization; PROPOSED marker in fixture, config and capability report only; per-club template override tested |
| S4 — OTP for everyone | SECURITY+BFF | Identify responses indistinguishable for known/unknown addresses (keys, status, floor); no directory call before verify; §5A.1 limits and 15-minute address lock pinned; no phone as identity; no code in any response or log |
| S5 — Pay Page only (carries Sprint 0001 G4) | PAYMENTS+QA | `captureMode` defaults `paypage`; mock capture unreachable without hooks; no `<select>` in capture components; readiness from `onReady`; error/Retry tested; membership embed regression test green. **Hosted run recorded** for a first-time buyer and an expired-card recovery when B1 exists; otherwise this gate is *pending* and the register reads "hosted capture unverified (B1)" |
| S6 — Prospect-wallet save | WALLET+BFF | Mock-proven owner `(memberId, MEMBER, org)` + entry with UUID `providedId` and `oj_*` metadata; read-back on response loss; retry reuses the id; platform adapter typed and `NOT_ENABLED`; enablement checklist recorded; dev smoke recorded only if reachable |
| S7 — Simulated users | QA | Smoke run then ≥ 3 independent `claude -p` personas complete end to end through the real browser via the sink and fixture cards; judge passes on server state correlated by run and checkout id; transcripts, sanitized screens and verdicts committed; browser self-test green; no real card, no live charge |
| S8 — Quality | UI+BFF+QA | Lint and build clean; UI ≥ 80/80; BFF ≥ 84/67/67/84; existing signup, guest and Pay Page suites green; Sprint 0001 demo green; no thresholds lowered; pre-existing baseline failures listed explicitly |
| S9 — Docs and status | BFF+UI | Contract v2, validation docs, demo doc, register, `docs/SEMANTIC-INDEX.md`, ledger and traceability updated; PRs #96/#524 descriptions updated; execution summary written |

**Completion vocabulary:** S0–S9 pass = *review changes complete; parity terminated; agents green; hosted capture verified*. While B1 is open: *review changes complete; parity terminated; agents green; hosted capture unverified (B1); S5 pending*. Passing S0–S9 does not authorise production enablement (L1–L5 unchanged, contract §10). Mock agent runs never close S5's hosted evidence; CR-06's mock proof plus checklist never closes L3.

### Carried live gates and confirmations

L1–L5 from Sprint 0001 stay open by design. New register rows: consent ledger platform adapter (PRODUCT+LEGAL+PLATFORM); D24 waiver reuse per person and club (PRODUCT+IDENTITY); recognized-buyer marketing preference (PRODUCT); email transport / SMTP lane (IDENTITY); wallet-write enablement checklist (WALLET); last-four step-up, trusted device and D12 member blocking (PRODUCT+SECURITY, not this sprint); CF-01 placement conspicuous (PM); CF-02 §4.5 content approval incl. the refund sentence (PM+LEGAL); CF-03 owner for the OTP sink and the test-card list (PM).

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | B1 credentials never arrive; CR-03 unprovable live | All implementation and mock proof proceed; E3 is a standing task with an exact command list; S5 reports *pending*, never *passed*; preflight for the six variables (by name) runs at A |
| R2 | §4.5 content or refund wording changes after counsel | Templates are versioned data with `approval:'PROPOSED'`; change = fixture edit + version bump; hashes keep old acceptances provable |
| R3 | Parity loop cannot terminate (fonts, antialiasing, dates, MUI portal) | Same Chrome binary; self-hosted Inter on the build and `document.fonts.ready` on both; frozen clock; Core `m@m.com` twin for exact text; 0.5 % ratio + masks; approved-delta file; two self-render calibration; 8-iteration cap reports unresolved; thresholds loosened only by a human with a recorded reason |
| R4 | Moving Pay to the sidebar duplicates hosted sessions or submits stale profile/consent | Single `CheckoutController` owning the ref and lifecycle; `draftProfile` in the slice; one `usePayAction`; order edits blocked while a purchase is in flight; full-page integration tests incl. the Sprint 0001 new-visitor order-shell defect |
| R5 | CR-05 breaks many Sprint 0001 tests and the demo | B1/C1 first in their lanes against the frozen v2; demo rewritten in B4(a) before `debug` removal lands |
| R6 | Enumeration via timing or error differences | No directory call before verify; identical key sets, status and floor; disposable refusal is address validation; lock and throttle messages identical |
| R7 | Test hooks leak into a deployed environment | Boot guard refuses hooks, clock and mock capture in production; testing router mounted only with hooks; loopback + key; router-stack test with hooks off |
| R8 | Autofill or Google Pay still surfaces in demos or agent browsers | Fresh profile, preferences file, flags, self-test asserting no suggestion popup; policy documented for humans running demos |
| R9 | `PayPageEmbed` change regresses membership | Optional prop, no behaviour change when absent; explicit regression test for both branches; membership suites unchanged |
| R10 | Agents pass by self-report or read another run's state | Judge reads `GET /testing/state?checkoutId=` correlated by run id; distinct emails and checkouts; smoke run first |
| R11 | Wallet mock accepts what live Java rejects | UUID `providedId`; required metadata shape asserted in the platform adapter test; acceptance of `oj_*` is L3 evidence; read-back on response loss |
| R12 | Consent evidence portrayed as durable legal record | Purchase-record snapshot only, in-memory store by declaration; durable ledger and retention are register rows; completion vocabulary says so |
| R13 | Coverage floors with deletions and many new files | Tests per task; coverage at each phase exit |
| R14 | Harness scope grows (extra CLIs, SMTP, leases) | Trimmed by decision; extras are register rows; `claude -p` only |
| R15 | Riverside vs Core fixtures confuse the audience | Riverside stays the demo default; Core `90033` used only by the parity loop and labelled as such |

## Dependencies

- **Code/infra:** both clones on `prospect-wallet/sprint-0001`; Node ≥ 22; Chrome; `TOOLS/` needs network once for `npm ci`; BFF `.env` gains `STP_TEST_HOOKS=true`, `STP_TEST_HOOKS_KEY=<random>`, optionally `STP_TEST_CLOCK`; Inter woff2 files (OFL) added to the UI.
- **Access:** B1 Pay Page dev credentials (six variables) for S5 hosted proof; LD flag (B2) unchanged; universal-wallet dev URL and authorities only for the optional CR-06 smoke; `claude` CLI authenticated for D4.
- **Decisions made (interview 2026-09-10):** same branches / PRs absorb; Sprint 0001 done with G2/G4 transferred; trimmed scope; self-hosted Inter.
- **People:** owners for the S-gates and the register rows at kickoff; CF-01…CF-03 owners (do not block build work).
- **Backend alignment:** `STP_WALLET_WRITES` false until the sibling backend sprint ships the dedup fix (hazard #10) and L3 is signed.
- **Index leaves consulted:** `themes/identity-by-member-id.md`; `themes/agreement-number-and-prosp.md`; `repos/universal-wallet/walletentry/credit-card.md`; `commerce-universal-wallet-sdk` `CreditCardRequestVO.java` (`UUID providedId`).

## Open Questions

**Decided in this sprint (drafts, critiques, interview):** v1.2 is the design source of truth, fixture data stays Riverside; offer card rendered as the selected single offer; email-only identify with inline code entry; every email gets a code and the lookup runs after consumption; consent and Pay in the sidebar with the §4.5 four-document set; `templateVersion` + `renderedHash` + `consentRevision`; pass terms recorded at Pay against the canonical button text; save default off; mobile required; marketing opt-in for new visitors only; Pay Page the only card entry, mock capture behind `STP_TEST_HOOKS`; UUID `providedId` and `oj_*` metadata; refund copy follows the PRD; date defaults to club-local today with skeleton sidebar before an order; static location label; self-hosted Inter; tooling in `tools/day-pass-harness/`; `claude -p` agents only; same branches; Sprint 0001 done with G2/G4 transferred; no waiver-reuse store, no separate test server, no SMTP lane this sprint.

**Requested (owner and date at kickoff; unanswered questions block only the named capability):**

| # | Question | Owner slot | Effect if unanswered |
|---|---|---|---|
| OQ-1 | Exact transactional-SMS notice text, marketing channel scope (email/SMS/calls), privacy URL and seller/brand interpolation for the templates | PRODUCT+LEGAL | Versioned proposed fixture text ships; CF-02 stays open |
| OQ-2 | Which deployed Pay Page environment and card list are valid for the hosted proof; who supplies B1 | PAYMENTS | S5 pending |
| OQ-3 | Does the deployed universal-wallet accept `oj_*` entry metadata and a `MEMBER` owner without an agreement number; is the dedup fix deployed | WALLET | CR-06 closes on mock proof + checklist; L3 pending |
| OQ-4 | Where do waiver history (D24), marketing preference and consent evidence live durably, with what retention and export | PLATFORM+PRODUCT+LEGAL | Purchase-record snapshot only; register rows |
| OQ-5 | Should recognized buyers see the marketing opt-in, and how is an existing preference read back | PRODUCT | New visitors only |
| OQ-6 | Are last-four step-up, trusted device and D12 member blocking wanted in a later sprint | PRODUCT+SECURITY | Not added; existing-member match proceeds as member |
| OQ-7 | Who on the design side owns the approved-delta manifest and signs S2 | DESIGN | UI lead signs with the list recorded |

**Carried to Sprint 0003 regardless:** durable stores and async purchase status; metrics; Turnstile; OAuth/location helper convergence; multi-day products; iframe decision; accessibility audit beyond E4 basics; semantic index over the three online-join repos; codex/agy agent runners; SMTP/Mailpit lane.
