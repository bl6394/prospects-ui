# Sprint 0003 Critique: Codex draft vs Gemini draft

**Status:** critique, 2026-09-15. Input to the sprint interview and merge; changes no other file.
**Inputs:** `SPRINT-0003-INTENT.md`, `SPRINT-0003-CODEX-DRAFT.md`, `SPRINT-0003-GEMINI-DRAFT.md`, `docs/prd/Change_Requests_2026-09-15.md`, `docs/prd/day-passv4.html`, and targeted `rg` reads under `repos/online-join-ui/src`, `repos/online-join-ui/__tests__`, `repos/online-join-bff/src` and `tools/day-pass-harness/`. `repos/mico` was not scanned.
**Path conventions:** `UI/` = `repos/online-join-ui/src/`, `BFF/` = `repos/online-join-bff/src/`, `STP/` = `BFF/services/shortTermPass/`.

## Verdict in one paragraph

The Codex draft is the stronger base for the merge. Its code findings check out almost everywhere, it answers all ten intent questions with reviewable defaults, it phases a first demonstrable slice before credential work, and its T0–T8 gates and completion vocabulary are usable as written. Its weaknesses are density, a sizing (15–19 engineering days) that likely exceeds one sprint, two scope-widening moves that need trimming (sprint-wide mandatory `generation`, an audit of instrumentation and logging across the BFF entrypoint), one stale source-reconciliation row, and a parity-input location that would leave the harness pointed at v1.2. The Gemini draft has the right shape and two ideas worth keeping, but it is under-specified for execution, contains a routing error the code contradicts, proposes a stateless token that cannot satisfy its own revocation use case, and its phase order contradicts its own sequencing answer. Merge from Codex; borrow Gemini's brevity, its offer-selection hybrid as an interview option, and its branch question.

## Claim verification

Claims from the drafts checked against source. "Confirmed" means the cited code says what the draft says.

| # | Claim | Draft | Verdict | Evidence |
|---|---|---|---|---|
| V1 | `OrderRequest` has no `offerId`; only `OfferSummary`/`OrderSummary` carry it. UI mirror matches. | Codex | Confirmed | `BFF/routes/shortTermPass/schemas.ts:74-83` (fields: visitDate, adult, waiver, saveCard, marketingOptIn, smsNoticeShown, generation); `offerId` only at 134, 186. UI `interfaces/api/shortTermPass.ts:71` same shape, `offerId` at 128/211. |
| V2 | Bootstrap, `requireOffer`, `consentSetFor`, `createOrderShell` and purchase validation all take the first catalog offer. | Codex | Confirmed | `BFF/routes/shortTermPass/checkouts.ts:61` `const [offer] = …getOffers`; `STP/order.ts:37` same; `order.ts:53` and `:88` call `requireOffer`; `STP/identify.ts:190-191` and `STP/purchaseOrchestrator.ts:150` use them. Five call sites, matching Codex's audit list. |
| V3 | `requireOrder` refuses order edits before verification. | Codex | Confirmed | `STP/order.ts:141-146`: 409 `ORDER_NOT_READY` unless state is `recognized` or `newVisitor`. |
| V4 | `App.tsx` already bypasses `SignupShell` for Day Pass; `PAGES.shortTermPassDone` is `/pass` under basename `/signup`; a `/pass/:token` route must be matched before that branch. | Codex | Confirmed | `UI/App.tsx:14-22` uses `isPathWithin(pathname, PAGES.shortTermPass \|\| shortTermPassDone)`; `UI/common/constants.ts:13,15` (`/day-pass`, `/pass`); `UI/index.tsx:18` `basename="/signup"`. `isPathWithin` (`UI/helpers/utils.tsx:280`) is a prefix match, so `/pass/<token>` would today render `ShortTermPassPage` and bootstrap a checkout. |
| V5 | Gemini mounts the public page in `UI/routes/SignupShell.tsx`. | Gemini | **Contradicted** | Per V4, `SignupShell` is never reached for any path under `/pass`. A route added there would be dead. Gemini's own architecture text says "outside `isShortTermPassRoute`", which is the right idea, but its file list points at the wrong file. |
| V6 | `MockOutbox` lives in `adapters/mock/verification.ts`, not `adapters/mock/outbox.ts`. | Codex | Confirmed | `rg` shows the class only in `STP/adapters/mock/verification.ts`; no `outbox.ts` exists in `adapters/mock/`. |
| V7 | No standalone `consentEvents.test.ts`; consent-event cases live in existing route tests. | Codex | Confirmed | `BFF/routes/shortTermPass/__tests__/` contains checkouts, identify, order, purchase, schemas, session, testingRoutes, verify, wallet. |
| V8 | `inputMode="tel"` and `autoComplete="tel"` already exist on both mobile paths; only the helper is new work. | Codex | Confirmed | `UI/routes/ShortTermPass/steps/NewVisitorStep.tsx:106,116`; `RecognizedStep.tsx:122,131`. `MOBILE_HELP` defined in both files (lines 25 and 40). Gemini lists the attributes as if new. |
| V9 | SMTP `passEmail()` hard-codes "1-day"; publisher imports it and sends its pass mail with no club context, so billing falls back to `00000`. | Codex | Confirmed | `STP/adapters/smtp/mailer.ts:28,30,39`; `adapters/publisher/emailPublisher.ts:108-115` passes `undefined` for club; `:67` builds `${club?.clubNumber ?? '00000'}-suffix`. |
| V10 | Mock QR is `STP1\|passId\|club\|visitDate\|sig`, sig a truncated unkeyed sha256. | Codex | Confirmed | `STP/adapters/mock/passSale.ts:14,44-45` (12 hex chars of sha256 over body + receiptNumber, no key). |
| V11 | `checkoutChain` requires the checkout cookie; `requireShortTermPass` resolves the club from body or record and fails closed on flag/`onlineProspects`. | Codex | Confirmed | `BFF/routes/shortTermPass/context.ts:104-109,154`; `index.ts:72-84` every checkout route uses it; `utils/middlewares/requireShortTermPass.ts:24,29-32,44-67`. Reusing it for a token route needs a new club resolver, as Codex says. |
| V12 | Existing UTC calendar helper and club-local "today" exist. | Codex | Confirmed | `STP/order.ts:8` `clubLocalToday(timezone)`, `:21` `addDays(iso, days)` via `Date.UTC`; `fixtures/consentTemplates.ts:69-79` `visitDateLabel` renders one day with `timeZone: 'UTC'`. |
| V13 | `generation` is compared inside the store update but is optional and is not bumped on order edits, so stale writes at equal generation are possible. | Codex (implied) | Confirmed | `STP/identify.ts:33-41` returns early when `requested` is undefined; increments only at `checkouts.ts:166`, `identify.ts:54`, `verify.ts:79`. `routes/shortTermPass/order.ts:26` re-checks inside `update`, but nothing bumps after an order edit. |
| V14 | Consent revision covers document hashes, notices and Pay text only, so static club-overridden Pass Terms would not change revision on a range change. | Codex (R4) | Confirmed | `fixtures/consentTemplates.ts:150-159` hashes `id:renderedHash`, notices, `pay:${text}`. Range appears only through `passTermsHtml` (`:103-105`), which `consentOverrides` can replace. |
| V15 | v4 keeps the sidebar as a skeleton until an order exists; selecting an offer before verification should not invent an early order. | Codex | Confirmed | `docs/prd/day-passv4.html:614-617` ("placeholder skeleton until an order exists"); UI `OrderSummary.tsx:32,65-70` already mirrors this. |
| V16 | HTML entrypoint injects AppDynamics; token paths could leak through it. | Codex | Confirmed | `BFF/routes/static/index.html.ts:1,60` and `routes/static/utils/getAppDynamicsIntegration.ts`. |
| V17 | `STP_SESSION_SECRET` exists and could sign pass tokens. | Gemini | Confirmed but inadvisable | `STP/config.ts:126` (`STP_CODE_SECRET` at 127). Reusing a session secret for a long-lived public bearer token removes key separation. No `STP_PUBLIC_BASE_URL` exists yet; Codex's new setting is needed by either draft. |
| V18 | Harness parity inputs live at `TOOLS/parity/elements.json` and `approved-deltas.json`. | Gemini | Path convention undefined, files real | Actual: `tools/day-pass-harness/parity/{elements.json,approved-deltas.json}`, currently pinned to `day-pass-v1.2.html` by sha256 (`elements.json` header). |
| V19 | CR-10 "says `offerId` already exists" and "asks to add Riverside multi-day offers". | Codex (reconciliation table rows 2–3) | **Stale** | `Change_Requests_2026-09-15.md:11` already carries the 2026-09-15 correction that `OrderRequest` has no `offerId` and states "Riverside stays single-offer as the demo default". There is no discrepancy left to record under CF-04. |
| V20 | Core `m@m.com` fixture is currently Jordan Reyes. | Both | Confirmed | `STP/fixtures/directory.ts:75-83`. Catalog: Riverside `day-pass-1-day` $18.00, Core `day-pass-gym-floor` $25.00, both `durationDays: 1` (`fixtures/catalog.ts:85-100`). |
| V21 | `qrcode` is not in the BFF; `qrcode.react` is in the UI. | Both | Confirmed | `online-join-ui/package.json:35`; no match in `online-join-bff/package.json`. Node engine `>=22`. |
| V22 | `capability.ts` port exists for a `provisional` marker. | Codex | Confirmed | `STP/ports/capability.ts:5-7` (`CapabilityStatus`, `CapabilityReport`). |
| V23 | Codex's cited UI files (`selectors/shortTermPass.ts`, `hooks/usePayAction.ts`, `components/{CheckoutController,ConsentBlock}.tsx`) and BFF files (`log.ts`, `env.ts`, `.env.example`, `routes/shortTermPass/{session,consentEvents,challenge,verify}.ts`, `adapters/platform/catalog.ts`, `fixtures/directory.ts`) exist. | Codex | Confirmed | Directory listings. |
| V24 | Checkout lifetimes are "30-minute/two-hour"; `transformers.test.ts` has a pre-existing timezone baseline failure. | Codex | Not verified | `transformers.test.ts` exists at `online-join-ui/__tests__/helpers/`; failure state and TTL values were not run or found by search. Treat as claims to confirm at A1. |

Net: Codex's code findings are accurate in 15 of 16 checkable rows; the one miss (V19) argues against a CR document version that no longer exists. Gemini makes fewer checkable claims; of those, one is contradicted by the router (V5), one is a path-convention slip (V18), and one is a weak security choice rather than a factual error (V17).

## Codex draft

### Architectural soundness

Strong. The design holds the right invariants: the BFF is the only source of price, duration and `validUntil`; selection is persisted on the checkout record as `selectedOfferId` and threaded through every first-offer call site (V2); the pre-verification sidebar stays a skeleton, matching v4 (V15); consent revision is bound to canonical commercial fields, closing the override gap in V14; the pass credential has its own port and store with a lifetime decoupled from the checkout sweep; the public route chain never touches `checkoutChain` (V11); token format is a versioned HMAC capability with a dedicated secret and no identifiers in the token; the response DTO is an explicit allowlist. The purchase orchestration keeps issuance and delivery separate so a QR or SMTP failure cannot refund an issued pass, which respects the existing orchestrator boundary at `purchaseOrchestrator.ts:533-579`.

Two design points need a second look at the interview:

- **Dedicated `PUT /checkouts/:id/offer` versus reusing `PUT /order`.** Codex argues for one route and says "choose one at A2, not both". That is right for implementation (one recalculation service), but Gemini's hybrid, which uses the dedicated route pre-verification and `offerId` on `PUT /order` afterwards, is what a UI developer would reach for because the order-summary sidebar already drives `PUT /order`. Recommend Codex's single route usable in all non-terminal states, with the UI calling it from both the identify grid and any later "change pass" affordance; record the hybrid as the rejected alternative.
- **Reusing `requireShortTermPass` for the public route** requires a new club resolver (the middleware reads body or record, V11). Codex says this but files it under C2 without a task line. Make it explicit.

### Completeness

Covers every CR, PR-05/06 and CF-04…07, plus regression baselines from Sprint 0001/0002. Sixteen use cases map each behaviour to a task and a proof. It answers all ten intent questions (OQ-1…12). It also catches items the intent missed: publisher billing code falls back to `00000` (V9), the receipt fine print claims delivery independently of PassBlock, `qrcode.react` is a browser dependency, and the HTML entrypoint injects tracking scripts (V16).

Gaps:

- **Parity input location (A3, E4).** Codex writes new inputs to `docs/validation/parity/sprint-0003/` and requires `tools/day-pass-harness/` unchanged. The harness's `elements.json` is pinned to v1.2 by sha256 (V18). After this sprint the runnable inputs would still describe v1.2 and a second copy would describe v4. The intent allows re-baselining inputs; only running the loop is deferred. Either update the files in place (v1.2 stays in git history) or state explicitly that the tools copy is the stale one and why.
- **Stale reconciliation rows (V19).** Rows 2 and 3 of the source-reconciliation table should be dropped or rewritten against the current CR document; otherwise the traceability table carries a phantom CF-04 discrepancy.
- **No explicit UI test list for the public page** beyond "routing tests"; D5's "Done when" should name the App-level test that proves `/pass/<token>` does not render `ShortTermPassPage`.
- **Receipt content** is specified for the email, but the done page's receipt block (which today lists number/item/amount) is only mentioned for the fine print. State whether the on-page receipt stays (v4 keeps it) and whether it must match the email line for line.

### Phasing and ordering

Good. A freezes contract and decisions, B1–B3 with D1–D3 form a first demonstrable slice (select 5-day before email, verify, change date, inspect Pass Terms and Pay text), then C with D4/D5, then E. This answers intent question 9 correctly and puts the user-visible result first. A4's time-boxed feasibility checks (Node QR package, base path, timezone helper, CID MIME shape) are the right thing to do before committing to the transport table.

Concern: D4 removes the done-page QR and both CR-14 helpers in one task, but D4 depends on C3 for the "View your pass" CTA to have a target. If C slips, D4 should still be shippable with the QR removed and the CTA hidden; the draft implies this ("only offer the link when available") but the task exit should say it.

### Risk coverage

The strongest of the two by a distance. R1–R13 are concrete, each with a mitigation that maps to a task. Notable catches: latest-request filtering in the UI does not stop equal-generation writes at the BFF (V13), DST and browser timezone must not shorten a pass, static club terms can hide a range change (V14), a club flag turning off would also disable retrieval of a paid pass (R13), CID images and screenshots cannot be recalled by revocation, external image caches defeat `no-store`.

Missing or thin:

- **Publisher path is effectively unproven this sprint** (dev 503). Codex says so, but the hosted-image choice for the publisher means the first live email will exercise a public image endpoint over a base URL that has never been tested from outside. Add a register row for "publisher image fetch from real clients" and consider embedding a text fallback line with the View URL near the top of the email so the mail is useful with images blocked.
- **Restart loses credentials** is covered (R9) but the demo script and orchestrator smoke restart the BFF often. State that E3 runs against a single BFF process, or the link checks will fail intermittently.

### Feasibility

The plan is technically feasible on the current code; every file it names exists (V23) and the new files fit the ports-and-adapters layout. The concern is size. Codex's own estimate is 15–19 engineering days plus review. Sprint 0002 A–C took roughly one sprint for less surface. Three items inflate the estimate and can be trimmed without hurting the success criteria:

1. **Sprint-wide mandatory `generation` (OQ-9, "existing fields plus mandatory v3 generation", audit of every mutating call including DELETE and headers).** Today `generation` is optional and checked when present (V13). Making it mandatory is a contract break for deployed clients and a cross-cutting change unrelated to CR-10…17. Recommend: new offer route requires it; order and purchase keep the optional-but-checked semantics; bump `generation` on committed offer and order edits so equal-generation stale writes are refused. Leave the full matrix for a later sprint.
2. **Instrumentation and logging audit on the token surface** (AppDynamics suppression, access-log path redaction, history fallback, Redux persistence). Real concerns, but for a local Mailpit proof they can shrink to: `Referrer-Policy: no-referrer` and `no-store` on API, image and HTML; redact `/passes/` paths in the BFF request log; do not load the AppDynamics snippet when the path starts with `/pass/`. Defer the rest to a register row for live readiness.
3. **Rate limits on both JSON and image endpoints with per-credential and per-IP keys.** Reuse the existing `rateLimit` middleware with one per-IP rule; per-credential limiting can wait for a durable store.

With those trims the plan is closer to 11–14 days, which is still a full sprint for two lanes.

### Definition of done

Excellent. T0–T8 are distinct from earlier G and S gates, each has an owner slot and an observable pass condition, and the completion vocabulary extends the intent's sentence with "static QR only; desk verification and rotation unverified". The rule that a failed gate must be named rather than absorbed into the completion sentence is worth keeping verbatim. Coverage floors are stated numerically and "no lowered thresholds/exclusions" is explicit. E2 correctly separates the six product-by-width smoke runs from the deferred parity loop.

One addition: T4 should state that the Mailpit QR is decoded by a test-side decoder and compared byte-for-byte to the issued payload, not judged visually; Codex says this under §4 and U9 but the gate text says only "rendered and decoded".

### Strongest ideas to keep

- `selectedOfferId` on the checkout record, `offers[]` plus a compatibility `offer` on `POST /checkouts`, and the audit list of the five first-offer call sites.
- Skeleton sidebar until an order exists; no early payable order.
- Consent revision bound to canonical commercial fields, with waiver acceptance preserved only when its rendered hash is unchanged.
- Separate `PassCredentialStorePort` with idempotent `getOrCreateForPurchase`, lifetime decoupled from checkout sweep, revocation as an internal operation, no public resend.
- Versioned HMAC capability token with a dedicated secret and no identifiers in the token; identical 404 body for malformed, tampered, unknown, revoked and expired.
- Transport table: CID for SMTP, hosted token-protected image for the publisher, data URI rejected as default with a reason.
- Truthful done-page copy variants for sent, pending and failed, and mapping publisher acknowledgement to `pending`.
- First demonstrable slice B1–B3 + D1–D3; A4 feasibility time-box.
- T0–T8 gates and the extended completion vocabulary.
- Fixing publisher club context so billing code is not `00000`.

### Weaknesses and gaps

- Sizing and the three scope inflators above.
- Two stale reconciliation rows (V19).
- Parity inputs written to a second location while the harness copy stays on v1.2.
- Density: several paragraphs mix decisions, rationale and implementation detail; the merged plan should move rationale into the contract doc and keep task lines short.
- Unverified numbers presented as fact (checkout TTLs, `transformers.test.ts` baseline; V24).
- D4's dependency on C3 not stated.

## Gemini draft

### Architectural soundness

The skeleton is right: catalog returns a list, a dedicated pre-verification offer route, `validUntil` computed in the BFF as inclusive calendar days, server-side QR, a public token route in the BFF and a public page in the UI, static QR first. Four choices are unsound as written:

- **Stateless JWT with `{passId, visitDate, durationDays, clubNumber, maskedEmail, iat, exp}`** puts pass and contact data in a bearer URL that will sit in mail logs and browser history, and a purely stateless token cannot be revoked, yet U6 and the success criteria require revocation. The draft hedges in OQ-4 ("stored temporarily or generated purely statelessly") without choosing. Codex's random id plus server record resolves both problems.
- **Signing with `STP_SESSION_SECRET`** (V17) couples a multi-day public credential to the session key; rotating one forces rotating the other.
- **Data URI QR "preferred if email clients allow it"**: major webmail clients block or strip data-URI images; CID is the demonstrable choice in Mailpit and the draft already names it as the fallback. Choose CID as default.
- **Public page file list names `SignupShell.tsx`** (V5); the route would never render because `App.tsx` diverts every `/pass*` path to `ShortTermPassPage`, which would then bootstrap a checkout. The fix is an exact `/pass/:token` match in `App.tsx` before the Day Pass branch.

Smaller issues: `defaultOfferId` on `POST /checkouts` without also returning the selected `offer` summary breaks every current consumer of `checkout.offer`; the hybrid selection API (offer route pre-verify, `offerId` on `PUT /order` afterwards) creates two mutation paths for the same field without saying they share one recalculation.

### Completeness

Each CR is named once, but the plan stops at the heading level. Missing entirely: regression baseline for Riverside and the Sprint 0002 behaviours; the concurrency and `generation` story (V13); consent-revision binding when price or range changes (only "flushing consent caches" in Risks); receipt field list; delivery `pending`/`failed` variants on the done page; rate limiting and response headers on the public route; the publisher club-context bug (V9); the mock outbox and demo script; test file names; coverage floors; traceability table; CF-04…07 register rows; the completion vocabulary the intent requires. The tel attributes are listed as work although they already exist (V8). Intent questions 5, 7 and 8 get one-line answers; question 9 is answered in a way that contradicts the phase order (below).

### Phasing and ordering

Five phases, A–E, are sequential by area rather than by demonstrable outcome. Two problems:

- **Phase C ships the done page without a QR and the token page before Phase D ships the email that carries the QR.** Between C and D there is no credential anywhere except the token page, and the done page copy would claim an email that does not yet contain the QR. Either D precedes C, or C keeps the on-page QR behind a flag until D lands.
- **OQ-9 says "Offer Selection, then Mail Delivery, then Token Page"**, which is the sensible order and the opposite of Phases C and D. The phase table should follow the OQ-9 order.

There is no named first demonstrable slice and no statement of what the user sees first.

### Risk coverage

Three risks, each one sentence. Inline image stripping, token PII and consent invalidation are real but the mitigations are thin ("BFF will be strict"). Not covered: stale writes and races, DST and timezone arithmetic, static club-overridden terms, club flag disabling retrieval, credential loss on restart, duplicate charge on delivery failure, token leakage through referrers and instrumentation, publisher path unproven, harness scope creep, late pricing decisions.

### Feasibility

The named files mostly exist and the shape fits the codebase, so the plan could start. But it is not executable without another planning pass: no task exits, no owners, no sizing, and the D-before-C dependency above would surface in the first week. Nothing in the draft is infeasible; the risk is that gaps get filled ad hoc during execution.

### Definition of done

Seven bullets, mostly restating scope. "Multi-day pass selection functionally populates `PUT /order`" is not observable as written and names the wrong surface for pre-verification selection. There are no gates, no owners, no coverage numbers, no browser smoke at 1440/375 per product, no PR-06 decode check, no traceability or register requirement, and no completion vocabulary. The last bullet (B1/S5 remain accurately documented) is good and should carry into the merge.

### Strongest ideas to keep

- **Brevity and structure.** The Pyramid Index and architecture sections are readable in two minutes; the merged plan should aim for this density in its summary layers while keeping Codex's task tables.
- **Hybrid selection surface as an interview option**: a pre-verification offer route plus `offerId` on `PUT /order`. Recommend against, but it is the natural alternative and should be recorded as such under OQ-1.
- **New branch `prospect-wallet/sprint-0003`.** The intent's default is to continue on `sprint-0001`, but the branch now carries prerelease version bumps and two sprints of history. Gemini is the only draft that raises the cost of that. Put it to the user with both options and the effect on PRs #524/#96.
- **"Place the View link prominently in the email rather than on the done pane."** Half right: the done page needs the link for the pending and failed cases, but making the email the primary surface for the link is consistent with v4's intent to move the credential off the done page.

### Weaknesses and gaps

- Router error (V5), stateless-token revocation contradiction, session-secret reuse, data URI default.
- Phase order contradicts its own sequencing answer.
- No concurrency, consent-binding, regression, security-header, rate-limit, receipt, delivery-state, register or traceability content.
- DoD not observable; no gates, owners or numbers.
- Tel attributes listed as new work.
- Undefined `TOOLS/` path convention.

## Head to head

| Dimension | Codex | Gemini |
|---|---|---|
| Architectural soundness | Strong; two points to settle at interview | Right shape; four unsound choices |
| Completeness | Full coverage plus catches beyond the intent | Heading-level only |
| Phasing and ordering | First demonstrable slice named; A4 feasibility box | Phase C/D order wrong; contradicts OQ-9 |
| Risk coverage | 13 concrete risks with task-mapped mitigations | 3 one-line risks |
| Feasibility | Feasible; oversized by roughly a third | Feasible but not executable without another pass |
| Definition of done | T0–T8 gates, owners, floors, vocabulary | Restated scope, no gates |
| Code accuracy | 15 of 16 checkable rows confirmed | 1 contradicted, 1 path slip, 1 weak choice |

## Recommendations for the merge

1. **Use the Codex draft as the base.** Keep its architecture, use cases, task tables, risks and T0–T8 gates. Drop reconciliation rows 2 and 3 (V19).
2. **Trim three scope inflators**: `generation` mandatory only on the new offer route with bumps on committed offer and order edits; token-surface hardening reduced to headers, log-path redaction and skipping the AppDynamics snippet under `/pass/`; one per-IP rate rule via the existing middleware. Re-size after trimming.
3. **Decide the parity-input location** at the interview (intent question 8). Preferred: update `tools/day-pass-harness/parity/*.json` in place to v4 and keep the sprint-0003 evidence folder for the state list and citations, so the deferred harness is not left pointed at v1.2.
4. **Adopt from Gemini**: the compact summary style for L0/L1; the hybrid selection API recorded as the rejected alternative under OQ-1; the branch question (continue `sprint-0001` versus new `sprint-0003`) as an explicit interview item with the prerelease-tag consequence spelled out.
5. **Make three exits explicit** in the merged plan: D4 is shippable without C3 (QR removed, CTA hidden); T4 requires a decoded byte-for-byte QR comparison; E3 runs against one BFF process because the credential store is in-memory.
6. **Interview decision surface**, in order: OQ-1 selection route; CF-04 prices and club assignment (Core 1/3/5, Riverside single); CF-05 inclusive calendar days with `maxDaysAhead` on the start date; CF-06 lifetime (end of window plus 24 h view-only grace) and internal-only revocation; CF-07 static QR everywhere with CID locally and hosted image for the publisher; parity-input location; branch.
