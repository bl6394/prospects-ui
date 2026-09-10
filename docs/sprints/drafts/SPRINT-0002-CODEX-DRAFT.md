# Sprint 0002: Day Pass v1.2 review changes and repeatable browser verification

**Status:** Codex draft for review, 2026-09-10. Tasks and gates below are proposed, not executed.
**Inputs:** [intent](SPRINT-0002-INTENT.md); [review change requests](../../prd/Change_Requests_2026-09-10.md); [PRD v3.4](../../prd/Consolidated_PRD_v3.4.md), D35–D47, §4.5, §5, §5A, §7, §12.15; [Design HTML v1.2](../../prd/day-pass-v1.2.html); [Sprint 0001](../SPRINT-0001.md), its [execution summary](SPRINT-0001-EXECUTION-SUMMARY.md) and [blockers](SPRINT-0001-BLOCKERS.md); [BFF contract](../../contracts/short-term-pass-bff.md).
**Project conventions:** no `CLAUDE.md` is present, as the intent confirms. Follow Sprint 0001's task tables, evidence gates, readiness register, and the product repositories' lint/Prettier/Jest conventions. No chapter selected; `docs/chapters/` is absent. Sprint status belongs to the sprint/ledger, not a chapter or this draft.
**Path conventions:** `UI/` = `repos/online-join-ui/src/`; `UI-T/` = its `__tests__/`; `BFF/` = `repos/online-join-bff/src/`; other paths are relative to this planning repository. NEW paths below are proposals; MODIFY paths exist.
**Baseline:** both product working trees are clean on `prospect-wallet/sprint-0001`. Intent/execution records identify UI `a3c61b6`, BFF `db81011`, and open PRs #524/#96. Re-record exact heads at kickoff. No branch, status, deployment, or product-code changes are made by drafting this document.

## Pyramid Index

- **L0:** Implement CR-01–CR-09 and runnable PR-01–PR-04 on Sprint 0001: v1.2 layout, separate versioned consent, email OTP for every buyer, hosted card capture, prospect-wallet saving, and repeatable visual and independent-agent browser proof.
- **L1:** A — contracts and fixtures; B — identity and mail sink; C — consent and purchase/wallet integrity; D — UI and hosted capture; E — parity and simulated-user tooling; F — validation and handoff.
- **L2:** Use cases → implementation task IDs → delivery gates → per-request commit/evidence manifest. Hosted and wallet integration results remain separate from mock results.

## Overview

Sprint 0001 implemented most underlying infrastructure, but its Riverside flow differs materially from the newly authoritative v1.2 design. This sprint changes that implementation rather than rebuilding checkout. Every submitted email receives a code before any recognition outcome. The code inputs remain on the identify screen. After verification, the right-hand Order Summary contains date, adult attestation, any required waiver, the matched purchase disclosure, and the sole Pay button. New-card capture uses the membership flow's Commerce Pay Page embed; save-card starts off and writes only after consent and prospect persistence. Marketing permission is an independent, unchecked choice.

Deliver the four-document catalog, server-side consent evidence, updated UI/BFF contracts and tests, a protected local OTP inbox, sandbox-card configuration, visual comparison tooling, and at least three independent simulated-user browser runs. CF-01–CF-03 stay open with owners in the readiness register; they are confirmations, not implementation tasks or claims of approval.

**Authority and scope decisions:**

| Area | Draft decision |
|---|---|
| Design lineage | v1.2 replaces the Riverside demos for layout, typography, colours and presentation. Explicit CR/PRD behaviour overrides contradictory prototype behaviour. Keep Riverside 90030 / $18 as the ordinary default. |
| Offer card | Render the single catalog offer as the selected radio card. No multi-offer selection API or catalog expansion. This follows v1.2 without adding a new product decision. |
| Date and sidebar | Two skeletons before verification; server-created order defaults to club-local today after verify. Retire the browser-local pending-date initialization. Record the intentional difference from v1.2's blank starting date. |
| Header | Use catalog brand word/tag and location label; retain a static location treatment without a false dropdown interaction until destinations exist. Use v1.2 tabs and responsive layout. |
| Legal copy conflict | v1.2 `DOCS.terms` promises a full refund before the first valid day; PRD §4.5/D15/D22 specify no online refunds. Use PRD policy in the configurable proposed template, record the exact copy delta, and leave counsel approval open. Do not copy prototype legal assertions as approved policy. |
| Waiver | Implement current-version reuse per person and club, with version re-sign per D24. The v1.2 unchecked checkbox is the unsigned fixture, not the rule for an already signed waiver. |
| Broader PRD | Trusted devices, stored-card last-four step-up, rotating QR/magic links, member lifecycle eligibility changes, VPD-wide directory expansion, durable stores, production delivery/payment adapters, Turnstile and metrics are separate readiness/backlog items. Do not claim full PRD §5A or production readiness. The intent preserves Sprint 0001 decisions, including its existing-member flow; conflicts remain explicit below. |
| Earlier carryovers | Sprint 0001's “carried to Sprint 002” list is not automatically added to this concentrated sprint. Register each remaining item with an owner; keep scope focused on the CR/PR list. |

Preserve the top-level route `/signup/day-pass?club=NNNNN`, completion `/signup/pass`, opaque `OJ-PASS-SESSION`, `/api/short-term-pass`, CSRF/Origin checks, server-side LD plus `onlineProspects` gating, internal `ShortTermPass` naming, synchronous idempotent purchase order, adapter separation, and no PAN/CVC/expiry input or state in the pass React tree. MICO and wallet repositories remain reference/dependency surfaces.

## Use Cases

| ID | Scenario and observable result | Tasks |
|---|---|---|
| U1 | Known, unknown, and ambiguous emails all receive the same challenge-shaped response and inline six-digit UI. No name, alternate contact, wallet, or lookup outcome appears before verify. Phone-only identification and SMS switching are rejected. | B1–B3, D2 |
| U2 | Unknown email → valid OTP → details with required first/last/mobile; no prospect is created merely by sending a code. Save off + adult/waiver + Pay → prospect, sale and pass; no wallet write. | B1, C1–C4, D3–D4 |
| U3 | Same first-time flow, explicitly save on → one entry owned by the persisted member UUID, stored-card consent metadata and truthful saved result. Later email verification recognizes that person. | C3–C5, E3 |
| U4 | Returning buyer → email OTP → name/info and usable saved-card chip; Pay does not create an owner or save the existing card again. Current waiver can be reused. | B1, C2, D3 |
| U5 | Returning buyer chooses a different card, then switches back; only one hosted session/controller is active. New-card save on adds to the existing owner; off adds nothing. | C5, D1, D4 |
| U6 | Wrong, expired, replayed or superseded code is rejected. Five failures lock the address for 15 minutes; Change, resend, fresh checkout and another club cannot reset address/IP limits. No ambiguity disclosure until possession is proven. | B2–B3 |
| U7 | Change/Edit calls `DELETE /identity`, removes binding, code, order, card selections, capture and checkout consents; old asynchronous responses cannot restore them. Reload preserves the legitimate inline-code or verified state. | B1–B3, D1–D2 |
| U8 | Adult unchecked, missing required waiver, invalid date, incomplete mobile/name, loading/failed capture, or an order update in flight keeps Pay unavailable. Server independently refuses forged purchases. | C1–C4, D3–D4 |
| U9 | Each of four documents opens with its own title/body/meta and Close. Only waiver has an affirmative Agree action. Opening/scrolling is never required; Close never accepts. Escape, focus return and keyboard navigation work. | C1–C3, D3, E2 |
| U10 | Changing date/price/template updates the purchase disclosure revision. A stale Pay or stale waiver version gets 409 and refreshed content before authorization. Replayed accepted purchase does not record new consent or charge again. | C2–C4 |
| U11 | Marketing remains off unless explicitly checked; notices are recorded independently. Saving a card, buying a pass and accepting a waiver never imply marketing permission. | C3, D3 |
| U12 | New buyer sees only hosted card entry in an ordinary demo. Sandbox valid card proceeds; expired card fails before purchase; embed errors/timeouts are recoverable. No browser profile exposes personal saved cards. | D4, E1–E3 |
| U13 | Decline, response loss, wallet failure/retry, sale/issuance/delivery failures and reload retain Sprint 0001's compensation and independent statuses. Wallet-only retry uses original consent and never re-authorizes. | C4–C5, F1 |
| U14 | Identify, code entry, recognized, recognized-new-card, new visitor, done save on/off, and all four document dialogs pass the defined parity comparison at 1440 and 375 px. | D2–D5, E2 |
| U15 | Three isolated agents complete first-time save on, first-time save off, and returning saved-card journeys through a real browser and readable OTP sink. Machine assertions corroborate transcripts. | B4, E1, E3 |
| U16 | Flag off remains unavailable; test inbox/mock capture are absent from ordinary runtime routes. Production boot rejects test configuration. Existing signup/guest/Pay Page behaviour stays covered. | B4, D4, F1 |

## Architecture

### Retrieved prior art and concrete implications

Read the available semantic-index entrypoint at `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/README.md`, routed through `themes/identity-by-member-id.md`, `themes/agreement-number-and-prosp.md`, and `themes/feature-flags.md`, then the Universal Wallet owner, credit-card, and deduplication leaves. Followed citations into the local wallet source. Online-join remains unindexed; direct `rg` and source reads establish these change points:

| Existing implementation / citation | Implication for this sprint |
|---|---|
| `BFF/services/shortTermPass/identify.ts`: `identify`, `resendChallenge`, `switchChallengeChannel`, `resetIdentity`; `routes/shortTermPass/verify.ts`: `verifyRoute` | `identify` currently looks up first and bypasses OTP for no match; `verifyRoute` assumes `candidateMemberId`. Move lookup after consumption and make verify a recognized/new-visitor/ambiguous union. |
| `ChallengeService.issue/evaluate`, `WindowLimiter`, middleware `rateLimit.ts` | Current send window is 15 minutes and lock is challenge-local. Implement the PRD hourly limits and address lock across challenges. |
| `createOrderShell`, `applyOrderUpdate`, `isOrderReady`, `validatePurchase` | Current single `terms` acceptance and `saveCard:true` must change on both sides. New visitors currently lack a verified-email purchase check and mobile is optional. |
| `UI/routes/PaymentPage/PaymentPageWithPayPage.tsx`, `components/PayPageEmbed.tsx`; `BFF/services/payPage/client.ts`: `createPassAddTokenSession` | Reuse SDK embed, single due-today CARD add-token session; do not copy membership's recurring session or token-in-Redux handling. Wrapper already receives SDK `onLoad` internally; expose an optional readiness callback. |
| `CardCaptureSlot`, `useShortTermPassCapture`, `usePayAction`, `NewVisitorStep`, `RecognizedStep` | Remove render-time timeout readiness. Lift the shared embed ref and profile state above main/sidebar; mount capture lifecycle once. |
| `saveCardToWallet`, `PlatformWallet.createCreditCard`, `beginPurchase` in `idempotency.ts` | Save plumbing exists, but lacks consent metadata. `providedId` currently receives `pur_…`; wallet Java `CreditCardRequestVO.providedId` is UUID. Persist a separate UUID per purchase for wallet entry creation and retries. |
| Wallet `owner/validator/WalletEntryOwnerValidator.java`, unique identity index described by `identity/owner.md` | Resolve owner by member UUID + MEMBER + org; require location for a new MEMBER owner; reuse existing owner without re-homing it. |
| Wallet `walletentry/creditcard/vo/CreditCardBaseVO.java` and `CreditCardRequestVO.java` | Token must be compatible with wallet UUID `pgToken`; validate required card metadata, omit unavailable optional first-six rather than sending `''`, and confirm metadata wire shape against the deployed contract. Never invent token compatibility. |
| Wallet `scheduler/job/data/walletentry/deduplication/util/DeduplicationJobKeyByWalletEntryOwnerCalculator.java` | Local source already contains agreement-less owner fallback, unlike older theme warnings. Local code is not deployment evidence. Keep dev enablement dependent on the deployed fix and prospect-safe sync. |
| Deduplication leaf, `MEMBER_ONLY` handler dependency | Owner/entry creation alone does not prove dedup or app/desk charging; confirm MEMBER authorized-user readiness without inventing agreement assignments. No last-four deduplication. |

### Email challenge and session state

Keep server state `identify → challenge → recognized | newVisitor`, with a post-verification unresolved path for ambiguity. Retain the UI's internal `verify` discriminator if useful for thunk/rehydration compatibility, but render it through `IdentifyStep` with an extracted `InlineCodeEntry` component. Delete the separate visual step and SMS affordances.

`identify` validates/normalizes email, checks abuse limits, sends a challenge and returns only submitted-email mask plus expiry/resend metadata. Lookup runs after an atomic successful consumption. For no match, store verified email and `verifiedAt`, rotate the session cookie and create an order; do not fabricate a member UUID. For a unique match, bind the returned member UUID/home club, then create the order. Ambiguity returns an unresolved result without wallet access or automatic selection. Directory failure must not undo consumed-code semantics: provide a bounded resolution retry tied to verified possession, or an explicit restart with a new challenge; freeze that response in A2.

Concurrent verify/resend/Change must compare challenge ID and checkout generation inside the store mutation. Wrong-attempt accounting must also occur atomically, not evaluate a stale record and overwrite a newer count. New-visitor capture/order/purchase require verified email; wallet reads additionally require a bound member identity. Keep existing opaque selection refs and ownership re-checks.

Six digits, ten-minute expiry, single use, 30-second resend cooldown, five wrong attempts followed by a 15-minute address lock. Five sends per normalized address per hour and twenty per IP per hour cover identify and resend, with address limits spanning checkouts/clubs to prevent bypass. Maintain generic responses and the existing response-latency floor. Add configurable disposable-domain checks with a deterministic fixture list; the production policy/provider and shared atomic storage remain L1/L4 dependencies. Use random codes in browser tests; a fixed code may remain only in isolated unit fixtures. Remove `debug.code` from customer API responses, even in harness mode.

Mobile remains a required profile/delivery field, never an auth channel. Replace browser `secondaryContact` with explicit `mobile` while preserving the verified email server-side. For a recognized fixture missing mobile, collect it with the same transactional notice before Pay; do not silently bypass D37 or use it to merge identities.

### Versioned documents and consent evidence

Replace `ClubCatalogPort.getTerms` with a consent-set resolver taking club, product tier, locale and authoritative order context. Proposed NEW `services/shortTermPass/consent.ts` renders trusted, escaped/configured templates; NEW `fixtures/consentDocuments.ts` holds the four defaults. Keep `PROPOSED — pending counsel` visible in catalog/config metadata, not an unsolicited customer banner. Legacy `prospectTerms` cannot stand in for all four documents; require explicit document-specific mapping or the proposed fixture defaults.

Each document has `{id, title, templateVersion, version, html, meta, requiresAffirmativeAct, approvalStatus}`. `templateVersion` identifies the authored revision; `version` is a SHA-256 of canonical rendered content including title/meta and relevant substitution values. Archive the exact rendered content associated with evidence. Waiver versions depend on waiver content/club/locale, not visit date; dynamic Pass Terms versions include club/product/date/price. A `consentRevision` binds the document-set versions and exact button/disclosure copy shown for the current order. No client-supplied HTML, amount or arbitrary version becomes authoritative.

| Evidence | Collection and persistence rule |
|---|---|
| Adult attestation | Explicit checkbox; record boolean, copy version, server time and surface through `PUT /order`. Required per checkout. No DOB/ID expansion. |
| Waiver | Required only when configured and no current acceptance exists for `(memberId, club, waiverVersion)`. Checkbox or modal Agree records method/version/time; Close only records availability evidence. A new visitor's checkout acceptance is linked to the persisted UUID after prospect creation. |
| Pass Terms / Privacy | Their availability and displayed disclosure are tracked separately from document-open events. `POST /purchases` with the current `consentRevision` records acceptance-by-Pay and privacy acknowledgment with exact button/disclosure text from the server snapshot. No extra purchase checkbox. |
| Stored card | Default false. Explicit toggle event records disclosure version and choice; purchase freezes final consent against the selected new card. Version change clears stale consent; changing the new-card source resets save off. Resolve “this card” to server-confirmed brand/last4 after capture while preserving the copy actually shown at the act. |
| Email/SMS notices | Distinct presentation events, with channel, copy version, timestamp and `surface`; they are notices, not marketing authorization. Pre-person events are checkout-scoped and later linked to UUID without falsifying original timestamps. |
| Marketing | Separate unchecked control near contact details in both lanes, with configured channel scope (email/SMS/calls about joining). Record explicit opt-in/out choices independently; lack of a new choice cannot revoke prior consent or grant new consent. No marketing sender integration is added. |
| Document open/close | NEW `POST /checkouts/:id/consent-events` accepts a bounded event ID/type, known document/copy key and current revision. Validate against server catalog, bind server time/surface/checkout and deduplicate retries. Opening is optional and never a payment gate. |

Propose a `ConsentStorePort` with append/deduplicate and current-waiver lookup; implement an in-memory adapter for local proof and document the durable store/export contract as L4. Save consent snapshots on the purchase record, distinct from ordinary redacted application logs. Store audit IP/user-agent only in the controlled evidence record where required by the supplied stored-card template; never in public snapshots or agent transcripts. Define retention/export with PM/Legal/Platform in readiness, without claiming the process-local store meets it.

`PUT /order` handles date, adult/waiver acts, save choice and marketing choice against an expected revision; returns current documents/revision and readiness. `POST /purchases` includes payment, required profile where applicable, and the shown `consentRevision`; the server revalidates current documents before any authorization and freezes evidence under the purchase attempt. Update idempotency fingerprinting to include the submitted revision and freeze effective order/profile/consent; reject conflicting order edits while an attempt is active. A same-key replay returns original results even if the catalog later changes. A stale revision returns 409 plus refreshed safe content, with no charge; only affected acceptances are invalidated.

### UI composition and payment capture

Add `CheckoutController`/provider beneath `CheckoutFlow`, owning one `PayPageEmbedHandle` ref, profile draft/errors and the single `usePayAction`/capture lifecycle. `NewVisitorStep` and `RecognizedStep` render fields and capture using that controller; `OrderSummary` invokes its validated Pay action. Keep refs/functions out of Redux. Redux holds serializable checkout/order/capture/consent state; clear profile/controller state on identity generation changes. Avoid duplicate session creation when the sidebar renders.

Retire `PayBar`; move consent and Pay into `OrderSummary`. Update `canPay` to require an active verified lane, valid server order/date, adult, current required waiver, profile/mobile completeness, no pending updates/submission, and payment readiness. Save and marketing never gate payment. Introduce `ConsentDocumentDialog` with MUI Dialog, v1.2 title/body/meta/footer and scoped portal styles. Use a safe HTML rendering policy for trusted templates.

Default capture to `paypage` in every ordinary non-test configuration, including mock business adapters. Missing credentials yield an actionable unavailable/loading error, never a fixture selector. `PayPageEmbed` gets an optional readiness callback using its existing SDK `onLoad`; reset readiness on session change/error/unmount. Pass UI uses it instead of `setTimeout` during render. Preserve the membership wrapper defaults and regression-test its two embeds.

Pay calls the actual embed's `submit`, then bounded pass-scoped capture polling, then purchase. A missing ref is an error; do not silently optional-chain past it. Keep tokens in the BFF: the UI sees session ID/readiness/brand/last4 only. Country, ZIP, holder, PAN, expiry and security code are rendered by Pay Page. Use server-owned CARD-only, deferred-authorization add-token configuration and existing OAuth/location helpers. Preserve purpose-based denial on generic Pay Page poll/close routes.

### Wallet completion and integration lanes

Extend `SaveCardInput`, wallet port and both adapters with a small explicit entry metadata allowlist, proposed keys `stp_stored_card_consent_version`, `stp_stored_card_consented_at`, `stp_consent_evidence_id`, subject to deployed metadata contract verification. Do not put these on the identity owner or add arbitrary browser metadata. Preserve owner metadata allowlist and forbid agreement/member-number/ordinal placeholders.

Allocate and store a separate `crypto.randomUUID()` wallet-entry `providedId` in `PurchaseRecord` before the first save; reuse it in `retryWalletStep`. Current opaque purchase IDs stay unchanged. Add response-loss recovery by querying the same provided entry ID and verifying owner/token association before treating a duplicate as success. Keep no-save → zero wallet-write calls, and resolve/create/write after person persistence. Wallet failure remains independently retryable, with original consent and no authorization/sale replay.

| Lane | Configuration and evidence |
|---|---|
| Deterministic local | Mock identity, email, wallet, payment and sale; explicit test-only capture fixture hook. Browser and HTTP proof, no hosted-capture claim. |
| Hosted sandbox | Mock business adapters + `STP_CAPTURE_MODE=paypage`, real sandbox Pay Page session/tokenization; mock authorization/sale. Proves hosted capture without live charges. |
| Dev wallet | Explicit integration runner injecting `PlatformWallet`, sandbox token and a valid dev person identity, with both wallet read/write gates enabled only after readiness checks. Default mock adapter selection currently always picks `MockWallet`; toggling `STP_WALLET_WRITES` alone is insufficient. |

Dev-wallet checklist: deployed agreement-less dedup fix and prospect-safe sync; actual org/location and valid persisted member UUID; read/create/token scopes; supported owner-scoped query; Pay Page token → `pgToken` mapping; UUID providedId and required card metadata; consent metadata persistence; read-back and retry without duplicate owner/entry; authorized-user/dedup status and cross-channel limitations; switches restored off. If unavailable, CR-06 may close for implementation/mock proof plus this recorded checklist as the intent permits; live wallet readiness stays pending.

### Reproducible browser tooling

Put product-specific browser tools under NEW `repos/online-join-ui/scripts/short-term-pass/`, with pinned dev dependencies and the UI lockfile. Reference the design through a CLI `--reference` path (default planning-repo v1.2 path); record its checksum. This avoids a separate undocumented scratchpad package. Add BFF test support under NEW `scripts/short-term-pass-test-server.ts` and `scripts/short-term-pass-test-support/`, reusing the real router/dependencies without mounting support routes from the production `src/server.ts` entrypoint.

The test server binds loopback and requires explicit `STP_TEST_HOOKS=true`, a per-run bearer secret and a run-scoped lease for inbox/assertion/reset APIs. Check the actual peer address, not merely Host/forwarded headers; no CORS access for arbitrary websites. Never serialize this secret into React/runtime config or launch-agent command arguments. Ordinary and production server routes return 404, and production configuration rejects hooks and mock capture. Per-agent outbox records include run/checkout/challenge correlation and expiry so resends cannot race into another buyer's inbox. Private reset affects only that run. Responses are no-store, bounded and purged at teardown.

Expose a readable local inbox via the support client, not a customer API `debug` field. `MockOutbox` supplies the mandatory baseline. Also provide a local SMTP verification adapter and pinned Mailpit compose configuration for provider-shaped delivery tests; bind SMTP and inbox API to loopback, disable relay, and consume it through the same scoped broker. This is not a production email-publisher adapter.

**PR-01 parity contract:**

- Launch pinned `puppeteer-core` against a recorded Chrome executable/version; support `CHROME_PATH`, including `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`. Lock pixel-diff/PNG dependencies. Fix viewport to 1440×1000 and 375×900, DPR 1, locale, timezone and clock; wait for `document.fonts.ready`, assert Inter loaded, disable animation/caret, then capture full-page and named regions. Use the same pinned font assets for both pages, with a declared loader-only override.
- Drive prototype through its visible controls (its state is inside an IIFE), and build through browser interactions/OTP sink. A reference adapter applies only declared fixture/copy normalization before interaction; never synthesize the build's successful state in Redux. Normalize Core/Riverside brand, product, price, email, date and card masks identically in both captures without rewriting the source HTML. Include a separate ordinary Riverside regression.
- Named states: identify, inline code empty/full/error, recognized saved, recognized new-card, new visitor, complete save on/off, and waiver/Pass Terms/stored-card/privacy dialogs. Include disabled/enabled Pay, save/marketing on/off, current/changed waiver and representative errors as assertions/additional states. Missing states are failures, not skipped successes.
- Exclusions: remove prototype `.proto` and `#syslog` with layout accounted for; mask only hosted-field internals and QR modules. Compare hosted wrapper bounds and neighbouring spacing separately. Use a fixed, documented hosted-region placeholder in both parity renders; also retain unmodified hosted screenshots and functional checks so masks cannot hide clipping or a missing embed. QR container/copy remain compared.
- An explicit expected-delta manifest covers PRD-required notices/marketing, refund wording, today default, static location, waiver reuse and truthful failure copy. Apply narrow expected text/layout changes to the reference in memory, and report them alongside results; never mask the entire form/consent/sidebar or auto-accept changed baselines. Preserve raw-reference screenshots for review.
- Proposed fixed threshold: pixelmatch colour threshold 0.1; changed pixels ≤0.1% per named region and full unmasked page; zero normalized-copy mismatches; zero computed-style mismatches for font family/size/weight/line-height, colour/background, border/radius, padding/gap, control dimensions, and key element bounds (round geometry to 0.5 CSS px). Missing/extra controls or horizontal overflow fail regardless of pixel percentage. Freeze/calibrate on two reference self-renders before evaluating the build; a font/render environment failure is not a product pass.
- Emit PNG pairs/heatmaps, element/copy deltas and JSON/HTML report per iteration. Agent fixes are constrained to product files; the loop cannot edit reference, thresholds or exclusions. Re-run until all states pass twice consecutively. Cap at five repair iterations or a configured time budget; exhaustion exits nonzero with remaining deltas. “No differences reported” means this contract passed, not pixel-perfect or silently waived errors.

**PR-02/03/04 independent agents:** launch at least three separate `claude -p` processes (installed/authenticated per intent; verify CLI interface at implementation kickoff), each with a fresh browser profile, checkout, synthetic email/run ID and private support lease. Each agent receives a goal and test-card policy, then independently decides browser actions through a small Puppeteer broker (`snapshot`, click, type, frame, wait, screenshot, inbox); a prerecorded checkout script run three times does not satisfy independence. The parent assigns fixtures and verifies evidence but does not hand agents another run's observations or execute checkout on their behalf. Limit concurrency to three by default, bound steps/time, and report timeout/failure/incomplete separately.

For the returning lane, create a distinct returning fixture via run-scoped setup before the agent begins; all three still retrieve OTP from the sink. Required scenarios are first-time save on, first-time save off, returning saved card. Add an expired-card attempt followed by correction and resend/Change exploration. In mock mode agents select a named sandbox fixture through the private broker, with no customer-visible card picker; label capture as simulated. In hosted mode agents type only the approved sandbox values into Pay Page frames through the broker. A mock fixture completion never closes hosted G4.

Maintain a versioned card policy listing provider/environment, valid 4242 fixture, expired fixture, expected outcome and owner slot. Do not assume a generic internet test number works in every processor sandbox: PAYMENTS verifies the list in the configured dev environment. Chrome launches with new temporary profiles, autofill/payment features disabled and no signed-in/default profile; record effective flags/preferences and verify no wallet picker appears. Allow only local services and explicit sandbox hosts; forbid live payment endpoints in preflight. Redact typing arguments/card fields, OTPs, cookies, tokens, session URLs and support secrets from shared traces. Store goal, actions, sanitized screenshots, outcome and parent assertions; screenshot masking must cover card fields during entry.

## Implementation Plan

Dependency order: A → B/C → D → E → F. Tool scaffolding and B1 credential diagnostics start in A; E final runs need B–D. Estimates below are planning ranges for one UI engineer, one BFF engineer and QA/tooling support, not calendar commitments: A 0.5–1 day; B 2–3; C 3–4; D 3–4; E 2–3; F 1–2. B/C may overlap across owners after the contract freezes; name owners and schedule at kickoff.

### Phase A — Freeze scope, contracts and reference inputs

| ID | Task | Files |
|---|---|---|
| A1 | Record both source heads; propose `prospect-wallet/sprint-0002` branches from Sprint 0001 with stacked PR bases. Record gate transfer proposal and CF owners without changing status by inference. Run BFF `npm run prepare` before implementation commits. | Planning `docs/sprints/ledger.yaml`, NEW `docs/sprints/drafts/SPRINT-0002-BLOCKERS.md` during execution |
| A2 | Freeze identify/verify union, explicit mobile, consent documents/revision/events, evidence store, order-update and purchase replay rules. Provide representative requests, 409 refresh response and upgrade/reset handling for old active checkouts. | `docs/contracts/short-term-pass-bff.md`; MODIFY `BFF/routes/shortTermPass/schemas.ts`, `UI/interfaces/api/shortTermPass.ts` |
| A3 | Record v1.2 checksum, state/copy/style inventory, expected-delta manifest, static offer/location decisions and refund discrepancy. Preserve original HTML. | NEW `UI repo/scripts/short-term-pass/{reference,states,expected-deltas}.mjs`; validation docs |
| A4 | Preflight Node/npm/Chrome/fonts/CLI/install access; report presence of B1 variables by name only. Establish hosted sandbox and wallet capability checklist with owners; start dependency resolution immediately. | NEW `UI repo/scripts/short-term-pass/preflight.mjs`; MODIFY BFF `.env.example`; blockers |

### Phase B — Email OTP in both lanes and protected mail sink

| ID | Task | Files |
|---|---|---|
| B1 | Rewrite `identify` to issue for every email; lookup only after verified possession; extend `verifyRoute`, snapshot mapping and new-visitor capture/order/purchase guards. Preserve `resetIdentity` invalidation and session rotation. | MODIFY `BFF/services/shortTermPass/{identify,person}.ts`, `ports/checkoutStore.ts`, `routes/shortTermPass/{identify,verify,challenge,checkouts,session}.ts` |
| B2 | Remove switch-channel route action; add hourly send/IP limits, cross-checkout address lock, atomic attempt/consume handling and disposable-domain policy. Keep phone normalization for mobile only. | MODIFY `BFF/services/shortTermPass/{challenge,contact,rateLimit}.ts`, `BFF/utils/middlewares/rateLimit.ts`, `routes/shortTermPass/{context,schemas}.ts`; NEW `services/shortTermPass/emailPolicy.ts` |
| B3 | Tests for known/none/ambiguous response equivalence, no lookup pre-verify, two simultaneous verifications, failed-attempt concurrency, expiry/resend/Change, fresh-checkout lock bypass, tenant isolation, no SMS and no debug OTP. Replace ambiguous-phone fixture with ambiguous-email fixture. | MODIFY BFF route/service tests, `fixtures/directory.ts`, `testing/harness.ts`, `adapters/mock/identityDirectory.ts` |
| B4 | Correlate `MockOutbox` messages; build private loopback test server, inbox client and isolated run lease/reset/assertions; optional SMTP-backed local mode and Mailpit launcher. Guard all hooks independently of product feature flag. | MODIFY `ports/verification.ts`, `adapters/mock/verification.ts`, config/boot tests; NEW BFF `scripts/short-term-pass-test-server.ts`, `scripts/short-term-pass-test-support/{router,leases,smtpVerification}.ts`, `scripts/short-term-pass-test-support/compose.yaml`; package/lockfile |

### Phase C — Consent, order integrity and prospect wallet

| ID | Task | Files |
|---|---|---|
| C1 | Implement four configurable tier/club documents and copy templates; version/render/archive semantics; Tier 0/1 defaults, save off; no automatic recurring-document inclusion. Correct prototype refund copy per PRD. | MODIFY `BFF/services/shortTermPass/ports/clubCatalog.ts`, `adapters/{mock,platform}/catalog.ts`, `fixtures/catalog.ts`; NEW `fixtures/consentDocuments.ts`, `consent.ts` |
| C2 | Replace single terms gate with adult/current-waiver/revision validation; implement person-club waiver reuse and changed-version re-sign. Date changes refresh dynamic Pass Terms; old checkouts reset safely. | MODIFY `BFF/services/shortTermPass/order.ts`, `ports/checkoutStore.ts`, `routes/shortTermPass/{order,verify,checkouts}.ts`; NEW `ports/consentStore.ts`, `adapters/mock/consentStore.ts`; MODIFY `adapters/index.ts` |
| C3 | Add bounded consent event endpoint, evidence linking after person persistence and separate marketing/transactional events. Archive exact copy and freeze consent snapshot at Pay. | NEW `BFF/routes/shortTermPass/consent.ts`; MODIFY router/context/schemas, `services/shortTermPass/{consent,log,purchaseOrchestrator}.ts`, `ports/purchaseStore.ts` |
| C4 | Make mobile and verified email mandatory; update `validatePurchase`, fingerprint/revision conflict handling, active-attempt lock and evidence replay. Preserve authorize → persist → consented save → sale → issue → deliver and all compensation paths. | MODIFY `BFF/services/shortTermPass/{purchaseOrchestrator,idempotency,person}.ts`, `routes/shortTermPass/purchase.ts`, order/purchase/consent tests |
| C5 | Add allowlisted stored-card evidence metadata; persist wallet providedId UUID; validate platform payload and retry/read-back semantics. Test save off, existing-owner reuse, mismatch rejection, write failure and response loss. Implement explicit dev-wallet integration runner/checklist. | MODIFY `BFF/services/shortTermPass/wallet.ts`, `ports/{wallet,purchaseStore}.ts`, `adapters/{mock,platform}/wallet.ts`, `purchaseOrchestrator.ts`; NEW BFF `scripts/short-term-pass-wallet-proof.ts`; existing wallet and purchase suites |

### Phase D — v1.2 UI and real hosted capture

| ID | Task | Files |
|---|---|---|
| D1 | Lift profile/ref/action into one controller; update slice, services and selectors for verified union, document revisions, mobile and consent; clear on generation change; serialize order edits and Pay. | NEW `UI/routes/ShortTermPass/components/CheckoutController.tsx`; MODIFY page, hooks, `reducers/shortTermPass/shortTermPassSlice.ts`, `selectors/shortTermPass.ts`, `services/shortTermPass.ts` |
| D2 | Email-only identify, selected offer card, inline OTP, readonly email/Change, paste/backspace/focus/resend/error semantics and skeleton sidebar before order. Retire separate VerifyStep presentation and SMS copy. | MODIFY `steps/IdentifyStep.tsx`, page, format; NEW `components/{InlineCodeEntry,OfferCard}.tsx`; DELETE `steps/VerifyStep.tsx` after moving useful code/tests |
| D3 | Sidebar adult/waiver/disclosure/Pay; generic document dialog; required mobile and notices; separate marketing control in contact area; save panel default off and versioned copy. Use controller action and truthful done status. | MODIFY `components/{OrderSummary,SaveCardToggle,SavedCardChip,PassBlock}.tsx`, `steps/{NewVisitor,Recognized,Done}Step.tsx`; NEW `components/{ConsentDocumentDialog,MarketingOptIn}.tsx`; DELETE `PayBar.tsx`, `TermsDialog.tsx` after replacement |
| D4 | Default hosted capture; expose SDK readiness callback, remove render-time timeout, handle null ref/errors/retry/session cancellation, preserve single session submit/poll and server token boundary. Remove customer mock-card selector; restrict fixture capture to explicit test process/broker. | MODIFY `UI/routes/PaymentPage/components/PayPageEmbed.tsx`, pass `CardCaptureSlot.tsx`, hooks; DELETE `MockCardCapture.tsx` customer component; MODIFY BFF `config.ts`, `env.ts`, routes session, adapter selection and config tests |
| D5 | Match v1.2 scoped tokens, Inter, header/tabs, overlapping desktop widgets, responsive stack, offer, controls, saved-card panel, dialogs and receipt; remove generator text. Prevent horizontal overflow and portal style leakage. | MODIFY `UI/styles/short-term-pass.scss`, `UI/components/dt/*` where needed, pass `CheckoutShell.tsx`; corresponding UI tests |

### Phase E — Repeatable parity and independent simulated users

| ID | Task | Files |
|---|---|---|
| E1 | Pin browser/diff dependencies; create browser broker with private profile, sandbox allowlist, sensitive-field redaction, scoped inbox bridge and test-card policy. Prove test hooks cannot be accessed through ordinary product server. | NEW UI `scripts/short-term-pass/{browser,broker,cards}.mjs`; MODIFY UI package/lockfile; BFF test-support tests |
| E2 | Implement reference/build state drivers, capture/style/copy comparison, narrow exclusions, declared deltas, reports and bounded compare/fix/repeat loop. Add intentional mismatch self-tests for font, copy, missing button and mask overreach. | NEW UI `scripts/short-term-pass/{capture,compare,parity-loop,report}.mjs`, tool tests; NEW `docs/validation/short-term-pass-sprint-0002-parity.md` |
| E3 | Implement separate CLI sessions and browser leases; run ≥3 goals, expired-card recovery, and parent-side assertions for prospect/wallet/consent/payment/pass/outbox. Store sanitized transcripts and label mock/hosted lanes. | NEW UI `scripts/short-term-pass/{agents,assertions}.mjs`, goal files; NEW `docs/validation/short-term-pass-sprint-0002-agents.md` |
| E4 | Publish reproducible commands and setup; run hosted browser proof immediately when B1 is resolved; run dev-wallet proof when its prerequisites pass, otherwise record exact blocked steps. | MODIFY `docs/demos/short-term-pass-local-demo.md`, validation docs; NEW harness README; BFF demo script |

Proposed commands (to be implemented, not available yet):

```text
# BFF repo — loopback test entrypoint, reads local .env without printing it
npm run test-server:short-term-pass
npm run test-mail:short-term-pass
npm run demo:short-term-pass
npm run demo:short-term-pass -- --hosted
npm run proof:short-term-pass:wallet

# UI repo — ordinary product development server plus tooling
npm start
npm run stp:preflight
npm run stp:parity -- --reference ../../docs/prd/day-pass-v1.2.html --max-iterations 5
npm run stp:agents -- --count 3 --capture mock
npm run stp:agents -- --count 3 --capture paypage
```

### Phase F — Regression gates, evidence and handoff

| ID | Task | Files |
|---|---|---|
| F1 | Update the eight-run demo and reload/fault checks for email OTP in every lane, required mobile, separate consent and save off. Replace secondary-phone re-entry with email re-entry. Run lint/build/coverage and existing signup/guest/Pay Page suites plus full-page browser checks. | MODIFY BFF `scripts/short-term-pass-demo.ts`; BFF tests; `UI-T/routes/ShortTermPass/**`, reducer/selector/service tests, PaymentPage tests |
| F2 | Run matrix at both widths, review raw and normalized evidence, verify accessibility basics and receipt truthfulness. Record hosted/wallet verdicts separately. | Validation reports and NEW `docs/validation/screenshots/sprint-0002/` |
| F3 | Record CR/PR → task → commit → tests/artifact → verdict; update contract/readiness, code map, demo docs and execution summary. Record CF owners and unresolved broader PRD dependencies. Resolve Sprint 0001 status explicitly with gate-transfer evidence; never infer completion from this draft. | MODIFY contract/validation/demo/`docs/SEMANTIC-INDEX.md`/ledger; NEW `docs/sprints/drafts/SPRINT-0002-EXECUTION-SUMMARY.md`, `docs/validation/short-term-pass-sprint-0002-traceability.md` |

## Files Summary

| Repository | Paths | Action/purpose |
|---|---|---|
| BFF | `src/routes/shortTermPass/{schemas,identify,challenge,verify,checkouts,order,purchase,session,index,context}.ts` | MODIFY contracts, email flow, order/consent and guarded capture |
| BFF | `src/routes/shortTermPass/consent.ts` | NEW consent availability/event endpoint |
| BFF | `src/services/shortTermPass/{identify,challenge,contact,rateLimit,emailPolicy,order,consent,purchaseOrchestrator,idempotency,wallet,person,config,log}.ts` | MODIFY existing; NEW `emailPolicy`, `consent` |
| BFF | `src/services/shortTermPass/ports/{checkoutStore,clubCatalog,verification,wallet,purchaseStore}.ts`, `ports/consentStore.ts` | MODIFY types; NEW consent store port |
| BFF | `src/services/shortTermPass/fixtures/{catalog,directory,consentDocuments}.ts`, `adapters/{index,mock/*,platform/catalog,platform/wallet}.ts` | MODIFY fixtures/adapters; NEW consent documents/store |
| BFF | `src/utils/middlewares/rateLimit.ts`, `src/env.ts`, `.env.example`, config/boot tests | MODIFY hourly limits and explicit test/hosted settings |
| BFF | `scripts/short-term-pass-demo.ts`, NEW `scripts/short-term-pass-{test-server,wallet-proof}.ts`, `scripts/short-term-pass-test-support/*`, package/lockfile | Runnable test support, SMTP sink and proofs |
| BFF | Route/service/middleware tests and `src/routes/shortTermPass/testing/harness.ts` | MODIFY/NEW targeted contract, security, evidence and retry coverage |
| UI | `src/routes/ShortTermPass/{ShortTermPassPage,steps/*,components/*,hooks/*,format}.tsx/ts` | MODIFY flow; NEW controller, inline code, offer, documents and marketing; remove obsolete VerifyStep/PayBar/TermsDialog/MockCardCapture files |
| UI | `src/{interfaces/api/shortTermPass,services/shortTermPass,selectors/shortTermPass}.ts`, `src/reducers/shortTermPass/shortTermPassSlice.ts` | MODIFY contract, state and gating |
| UI | `src/routes/PaymentPage/components/PayPageEmbed.tsx`, `src/styles/short-term-pass.scss`, `src/components/dt/*` | MODIFY optional readiness event and scoped parity styling |
| UI | `__tests__/routes/ShortTermPass/**`, reducer/selector/service tests and PaymentPage suites | MODIFY/NEW behaviour and isolation validation; keep helpers named `*Data.ts` |
| UI | `scripts/short-term-pass/*`, `package.json`, `package-lock.json` | NEW reproducible browser, parity and independent-agent tools; pinned dev dependencies |
| Planning | Contract, demo, validation, screenshots, traceability, blockers/execution summary, semantic code map, ledger | MODIFY/NEW evidence and readiness; no automatic source-design rewrites |

No product work in `repos/mico`, wallet services, legacy signup shell, global styles or membership recurring-payment rules. The existing BFF manifest-skip and API body-handling accommodations must be preserved.

## Definition of Done

Owner slots are UI, BFF, QA/TOOLING, DESIGN, PRODUCT (Kelly Card/PM), SECURITY, PAYMENTS, IDENTITY, WALLET and PLATFORM. Assign names at kickoff; an unassigned slot cannot sign a gate.

| Gate | Owner | Required evidence |
|---|---|---|
| G0 — Review baseline | UI+BFF+PRODUCT | Frozen contract/examples, source heads, approved scope/delta manifest, branch plan and explicit Sprint 0001 gate disposition. Every CR/PR has implementation and evidence owner. |
| G1 — Identity | BFF+SECURITY | U1/U6/U7 pass; email OTP for known/none/ambiguous; generic pre-verify response; hourly limits/address lock and atomic consume; no SMS/debug-code path; new-visitor purchase cannot bypass possession. |
| G2 — Consent | BFF+UI+QA | Four versioned tier/club-configurable proposed documents; adult and waiver acts; waiver reuse/re-sign; exact Pay disclosure/revision evidence; marketing separated; mobile required; stale revision refuses before money movement; replay has no duplicate evidence. |
| G3 — UI/parity | DESIGN+QA | Every named state at both widths passes frozen threshold/style/copy contract twice; raw screenshots, expected-delta list and diff artifacts reviewed; no customer card picker/demo log/generator help; keyboard/focus, modal and overflow checks pass. Replaces Sprint 0001 G2 obligation. |
| G4 — Hosted/PCI | PAYMENTS+QA | Actual sandbox session create → SDK render/ready → valid/expired form actions → submit → pass-scoped poll → BFF token re-read, recorded through browser. Null/loading/error paths tested; no PAN/CVC/expiry in pass UI state; hostile purchase fields rejected; signup embed regressions green. Carries Sprint 0001 G4. |
| G5 — Wallet/transactions | BFF+WALLET+QA | Ordered purchase/compensation/idempotency preserved; UUID providedId and consent metadata tests; save-off zero writes; save-on owner identity/read-back/retry assertions; dev proof or explicit allowed CR-06 mock evidence plus enablement checklist. |
| G6 — Tooling | QA/TOOLING+SECURITY | Clean install reproduces tooling; inbox works; ≥3 independent browser-agent completions with parent state assertions and sanitized transcripts; expired fixture test; sandbox-only/profile checks; test support absent from ordinary/production runtime. |
| G7 — Quality/isolation | UI+BFF+QA | Both lint/build pass. UI lines/statements ≥80%; BFF statements/branches/functions/lines ≥84/67/67/84. No reduced floors or exclusions. Existing signup/guest/Pay Page suites and manual existing-signup browser smoke recorded. |
| G8 — Handoff | PRODUCT+UI+BFF | CR-01…09 and PR-01…04 traceable to commits/commands/evidence; contract/readiness/demo/validation/index/ledger current; CF-01…03 open with owners; Sprint 0001 status explicitly resolved and pending gates not erased. |

Sprint 0001's published execution evidence contains a timezone-sensitive UI test failure and pre-existing PaymentPage type-test errors. Establish their reproducible baseline; do not copy historical “all green” claims, lower thresholds, or classify new failures as pre-existing without evidence. Set a documented common test timezone and fix any changed-flow regression. A known unrelated baseline failure must be listed explicitly in the G7 verdict.

**Completion vocabulary:** all G0–G8 passed = sprint implementation and local/browser verification complete; production enablement remains blocked by relevant L1–L5. If B1 is missing, G4 remains pending: **“implementation/mock browser proof complete; hosted capture unverified; sprint verification incomplete.”** No successful mock agent run substitutes for hosted evidence. CR-06's explicit mock-plus-checklist allowance does not close live wallet readiness. Passing engineering consent gates does not close counsel confirmations.

**CR/PR traceability:** CR-01 → D1/D3; CR-02 → C1–C3/D3; CR-03 → D4/E4; CR-04 → D4/E1; CR-05 → B1–B3/D2; CR-06 → C5/E4; CR-07 → D2/D5; CR-08 → D5/E2; CR-09 → C3/D3; PR-01 → E2; PR-02 → E3; PR-03 → B4; PR-04 → E1/E3. F3 records actual commit hashes and artifacts before any item is called shipped.

## Risks & Mitigations

| ID | Risk | Mitigation |
|---|---|---|
| R1 | Pay Page credentials unavailable or token environment mistaken for live | Start B1 preflight in A4; sandbox host allowlist and mock authorization; proceed with implementation, retain pending G4 until actual hosted browser evidence. |
| R2 | “Versioned terms” records wrong copy after a date/template change | Canonical rendered hashes + template version + server-issued revision; archive exact copy; 409 before authorization and idempotent evidence freezing. |
| R3 | Prototype refund/policy and §4.5 disagree | PRD policy wins for content; narrow explicit expected delta; proposed catalog marker and CF-02 remains open. |
| R4 | Moving Pay loses local profile data, creates duplicate embeds or sends stale consent | One controller/ref/capture lifecycle; serializable slice state; block pending order edits; full-page integration tests, including the prior new-visitor order-shell defect. |
| R5 | Email enumeration, brute force or lock reset via new checkout | Post-verify lookup, uniform metadata, address/IP limits independent of checkout, atomic attempts and shared-store live gate. |
| R6 | Mail sink/debug capture accidentally exposed | Separate loopback test entrypoint; bearer lease + peer checks; no secret in frontend; ordinary/production 404 and boot rejection tests; private purge and artifact redaction. |
| R7 | Pixel loop “passes” by masking real defects or endlessly tuning thresholds | Freeze thresholds/masks, report every declared delta, assert wrapper geometry/copy/styles, detector self-tests and finite nonzero failure exit. |
| R8 | Wallet mock accepts a payload live Java rejects | Actual-source UUID providedId correction, required-field validation, consent metadata contract check and explicit dev read-back. |
| R9 | Local wallet fix assumed deployed; duplicate or lost entries | Verify deployed prospect-safe lane; immutable UUID per wallet write, response-loss read-back, no last4 dedup/re-home, gates remain dark. |
| R10 | In-memory consent/waiver/payment state portrayed as durable legal evidence | Mock implementation plus persistence contract; L4 retention/shared storage remains open; no production enablement claim. |
| R11 | Required notices or failure copy prevent literal v1.2 parity | Expected-delta manifest tied to CR/PRD; independently verify those controls rather than exclude them. |
| R12 | Independent agent runs interfere or pass by self-report | Separate profiles/run leases/fixtures, bounded concurrency and steps, parent state assertions, artifacts tied to exact source/config. |
| R13 | Wider PRD security/eligibility expectations silently missed | Explicit open decisions/readiness owners for step-up/trusted device/member eligibility and VPD identity; concentrated sprint is not full PRD compliance. |
| R14 | Native fonts, dates or prototype QR cause noisy visual failures | Pinned fonts/browser/DPR/clock, reference self-test, local-today server tests, QR-module-only mask and unmasked geometry. |

## Dependencies

- **Source baseline:** Sprint 0001 product branches, its contract and validation artifacts; final stack strategy before implementation commits. Planning drafts do not merge or close existing PRs.
- **Toolchain:** Node ≥22/npm ≥10 in BFF; React 17/router v5/RTK/MUI v4 in UI; BFF `erasableSyntaxOnly` (no enums); Prettier/husky prepared; UI installs use `--legacy-peer-deps` as documented. Pin browser/diff/mail dev dependencies and lockfiles; Artifactory access needed for product installs.
- **Hosted B1:** `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN`, `ABC_CORE_API_URL` in private BFF `.env`, plus correct sandbox club/location and origin configuration. Never put values in plans/reports.
- **Flags/runtime:** existing `oj-short-term-pass-checkout` and `onlineProspects`; LD creation remains an owned readiness item. Local overrides remain non-production only; explicit mock capture/test hooks require the isolated test server. Wallet read/write flags off outside the dedicated approved dev proof.
- **Wallet:** deployed dedup fix/prospect-safe sync, scopes and org/location, valid persisted dev identity, owner-scoped query and token compatibility; backend sibling sprint is a dependency, not a source of this sprint's completion status.
- **Email/agents:** local mock sink required; Docker only for the additional Mailpit lane. At least one supported authenticated agent CLI and Chrome; broker installed through reproducible tooling. Production shared OTP issuer and delivery provider are still L1 dependencies.
- **People/content:** DESIGN for expected deltas/parity; PM/Legal for proposed wording and CF-01/02; PM for CF-03; PAYMENTS for sandbox card/environment attestation; QA/TOOLING for harness ownership and reports.
- **Live readiness remains:** L1 identity/delivery/abuse controls, L2 real payments/sale/issuance, L3 wallet deployment/read/charge path, L4 shared durable stores/reconciliation/audit retention, L5 counsel/catalog/channel claims. Update the existing readiness register rather than introducing a competing status system.

## Open Questions

The draft supplies defaults for reversible implementation choices. Resolve conflicts at plan review/kickoff; unanswered live-capability questions keep only that capability blocked, not unrelated implementation.

| ID | Question / proposed disposition | Owner | Effect if unresolved |
|---|---|---|---|
| OQ-1 | Accept the selected single offer card and static location label? Default yes, reflecting v1.2 layout and existing catalog. | PRODUCT+DESIGN | Use declared default and retain parity delta for static label. |
| OQ-2 | New stacked `prospect-wallet/sprint-0002` branches or extend #96/#524? Default stacked branches/PRs based on Sprint 0001; retarget after base merges. | Engineering lead | Record strategy before execution; no branch mutation in this draft. |
| OQ-3 | Close Sprint 0001 administratively with G2/G4 transferred, or keep in progress? Recommend keep `in-progress` until explicit disposition; later administrative closure must say transferred, never passed. Header currently says planned while ledger says in-progress; reconcile both. | Sprint owner/PRODUCT | G8 awaits explicit recorded resolution, without rewriting historical test evidence. |
| OQ-4 | Confirm expected-delta manifest: no-refund copy, transactional notices/marketing, waiver reuse, today default, static location and hosted wrapper geometry. | DESIGN+PRODUCT | Draft defaults guide implementation; G3 sign-off awaits review. |
| OQ-5 | Exact transactional-SMS text, marketing channel scope, missing-mobile returning state, privacy URL and approved seller/brand interpolation? | PRODUCT+Legal | Versioned proposed fixture text; no production consent-content approval claim. |
| OQ-6 | Which production store/API supplies waiver history, consent audit export/retention and marketing permission consumption? | PLATFORM+BFF+PRODUCT | In-memory local proof; L4 and downstream marketing integration remain open. |
| OQ-7 | Are stored-card last-four step-up, trusted-device bypass and D12 member blocking intended in this CR sprint despite the intent preserving Sprint 0001? Recommend a separate scoped decision; do not silently add or claim them. | PRODUCT+SECURITY | Mock returning flow remains as intended; affected live wallet/identity enablement pending. |
| OQ-8 | Which deployed Pay Page environment/card list and `pgToken` mapping are valid, and who supplies B1 access? | PAYMENTS | Hosted G4 pending; no fabricated successful hosted run. |
| OQ-9 | Can dev wallet prove owner query, consent metadata, providedId response-loss recovery and MEMBER authorized-user/dedup readiness without agreement roles? | WALLET+PAYMENTS | CR-06 implementation/mock proof plus checklist; L3 pending. |
| OQ-10 | Which shared identity service enforces VPD-wide lookup/duplicates and which disposable-domain policy is adopted? | IDENTITY+SECURITY | Fixture/local email policy only; no invented remote-club authority or automatic person merge. |
| CF-01 | Counsel confirms right-panel consent remains conspicuous. **Open confirmation; no build change assigned.** | PM | Readiness confirmation stays open. |
| CF-02 | Counsel approves waiver, Pass Terms, stored-card disclosure and privacy content. **Open confirmation; templates remain PROPOSED.** | PM+Legal | Production content adoption remains pending. |
| CF-03 | Name the OTP-sink and test-card-list maintenance owner. **Open confirmation; engineering still builds the tooling.** | PM | Record QA/TOOLING and PAYMENTS as provisional implementation slots, not appointed permanent owners. |

Deferred items from Sprint 0001 receive explicit backlog/readiness entries at F3: durable stores and async status, metrics, Turnstile, OAuth/location helper convergence, multi-day products, iframe decision, broader accessibility audit and semantic-index expansion over online-join. This sprint updates the existing code map only. None becomes complete merely because Sprint 0002 is closed.
