# Sprint 0001 — Codex critique of Claude and Gemini drafts

Reviewed 2026-09-09 against `SPRINT-0001-INTENT.md`, both competing drafts, and targeted local code reads. Recommendation: use Claude as the implementation-plan base after correcting its payment and security contracts; retain Gemini's simpler workstream structure. Neither draft is ready to execute unchanged.

The intent permits mock adapters for unavailable services. A complete, deterministic local checkout is therefore a valid sprint outcome. It does not establish that a payment was authorized, a desk-valid entitlement was issued, or a card can be reused through real wallet services. The merged plan must distinguish those proofs.

## Assessment at a glance

| Dimension | Claude | Gemini |
|---|---|---|
| Architectural soundness | Strong boundaries and repository fit; consequential contradictions in payment, authorization, and adapter modes | Sensible direction, but session, payment, wallet, and runtime mock contracts remain sketches |
| Completeness | Broad prototype coverage, concrete files and tests; missing recovery and several identity edge cases | Omits required purchase variants, much of the sidebar/done behavior, and operational plumbing |
| Phasing / ordering | Parallel lanes and task-level tests are useful; payment feasibility and security decisions must move earlier | Logical outline, but contracts follow scaffolding and meaningful security verification comes too late |
| Risk coverage | Substantial risk register; some mitigations do not address the stated risk | Three risks are insufficient for an identity-and-payment checkout |
| Feasibility | Plausible mock-first scope, optimistic ten-workday BFF critical path, excessive optional breadth | Easy to understand, impossible to estimate reliably without contracts, owners, or work breakdown |
| Definition of done | Mostly measurable; several contradictory or weak proof requirements | High-level aspirations rather than reproducible acceptance gates |

## Code evidence used

Paths below are relative to the planning repository. These are source observations, not claims of tested upstream behavior.

| Evidence | What it establishes |
|---|---|
| `repos/online-join-ui/src/index.tsx:18`; `src/App.tsx:177` | Router basename is `/signup`; existing routes render without a `Switch`. The browser URL can be `/signup/day-pass`, while the route constant should be `/day-pass`. A separate shell branch is reasonable. |
| `repos/online-join-ui/src/routes/PaymentPage/PaymentPageWithPayPage.tsx:256`; `hooks/usePayPageSession.ts:119` | The existing flow submits the embed before reading the session token. `pollSession()` performs one GET per invocation; it is not a built-in retry-until-token loop. |
| `repos/online-join-bff/src/routes/payPage/index.ts:363` | Due-today capture fixes card payment methods and sets `deferAuthorizationToPayment: true`. Receiving a token is not evidence of an authorized charge. |
| `repos/online-join-bff/src/routes/payPage/index.ts:374` and `:447` | Session reads validate UUID format and resolve the tenant from a supplied club. This code does not itself bind that session to the day-pass browser principal or purchase. |
| `repos/online-join-bff/src/utils/cookies.ts`; reference search across `src` | `SESSION-ID` helpers exist, but their callers found here are tests, not production routes. This is not an existing authenticated day-pass session implementation. |
| `repos/online-join-bff/src/routes/static/index.html.ts:82` | Runtime environment values are injected under `window.process.env`, alongside `window.featureFlags`, supporting Claude's correction to the intent. |
| `repos/online-join-bff/node_modules/@abc/bff-toolkit/dist/types/clients/UniversalWallet.d.ts:18` | `getWalletEntries(externalId)` is deprecated and explicitly documented as “Only for QA use.” It accepts no owner-type argument. The client returns `got.Response`, so Gemini's proposed Axios mocks need a deliberate boundary rather than an assumed transport match. |
| `repos/mico/src/main/java/com/abcfs/controller/ProspectController.java:55` | `/trial/submit` accepts a much larger request and validates address/email/home-phone data. It is not a demonstrated name-plus-one-contact prospect adapter. |
| `repos/mico/src/main/java/com/abcfs/controller/ShopController.java:167`; `feignclients/OrasvcClient.java:95` | Existing shop operations use authenticated member context; sale-item lookup takes `memberId`. Endpoint existence does not prove anonymous short-term-pass compatibility. |
| Both repositories' `jest.config.js` | UI floors are 80% lines/statements; BFF floors are 84% lines/statements and 67% branches/functions. UI SCSS imports are mocked, limiting what Jest can establish about rendered styles. |

No application tests were run for this document review. Wallet service behavior, gateway token compatibility, provider availability, and deployment readiness were not independently established.

## Claude draft

### Architectural soundness

**Keep:** typed ports for directory, messaging, prospect, sale, wallet, and payment-session reads; deterministic adapters; server-resolved identity; existing-owner reuse; separate short-term-pass route and scoped styles. Re-reading the payment session server-side is a good trust-boundary improvement. The repository-specific corrections are materially useful, especially the unused cookie helpers, runtime flag injection, and unsuitable trial endpoint.

**Must fix before implementation:**

1. **The proposed new-card Pay gate deadlocks.** The state section requires `capture.status === 'TOKENIZED'` before enabling Pay, while D10 makes Pay initiate embed submission and token retrieval. Existing code submits first, then polls. Enable the action when day, recorded terms, required profile fields, and hosted-form readiness permit submission; transition through submitting, token retrieval, authorization, and purchase. Specify bounded polling/retry behavior and test this with the real embed interface, not just `MockCardCapture`.

2. **Authorization, sale, and issuance are conflated.** The intent fixes authorize → persist prospect → wallet. Claude repeatedly substitutes `sell`, returns a pass before prospect creation, and describes OQ-R7 as though the intent mandated a completed sale first. The due-today route explicitly defers authorization. Define what `PassSalePort.sell` actually guarantees: authorization versus capture, sale recording, entitlement creation, and failure/compensation boundaries. Preserve the required authorization-first ordering while defining what happens if prospect persistence fails. A paid result plus “say your name at the desk” is not a recovery contract when no prospect record exists.

3. **Payment-session ownership is missing.** An opaque session ID and server-side reread do not establish that the session belongs to this browser, club, or purchase. The existing Pay Page read route does not supply that guarantee. Add a trusted binding when creating the capture session, validate tenant/location, status and card eligibility, and prevent cross-principal reuse and replay. This may require a day-pass wrapper around session creation; the promise to leave all Pay Page integration boundaries unchanged should not preclude it. The assertion that the extracted token is “exactly” the required wallet `pgToken` also needs a gateway/tenant contract or integration evidence, beyond compatible field names.

4. **Server gates contradict the use cases.** U1 promises both flag and `onlineProspects` protection for every BFF operation, while the route map and OQ-R10 enforce only LD on the BFF. Apply both checks server-side unless an explicit rationale changes the scope. Bind the club used for gating to the challenge/session/identify token and resolved organization, rejecting mismatches. Several request examples omit club information even though `requireFlag` expects query/body `clubNumber`; make the authoritative source unambiguous for every route.

5. **Wallet reads do not yet prove the identity invariant.** The selected QA-only lookup is insufficiently justified as a platform adapter, even with tenant context. Resolve the owner by `(externalId=memberId, type=MEMBER, org_id)` and use a supported owner-scoped entry query with pagination and eligibility filtering. Treat location as a resolved scope/input, not a replacement for organization in the identity key. Existing-owner checks must include tenant and type, not merely a matching member string.

The new signed cookie is a reasonable explicit choice, but signing does not encrypt its claims. “Member ID never leaves the BFF” overstates the protection: it is present in a browser-held JWT, though unavailable to page JavaScript through an httpOnly cookie. More importantly, step 8 creates the same session for a new visitor who never verified contact possession. Model checkout ownership separately from OTP-verified recognition, or explicitly justify and constrain that session's authority.

### Completeness

The use-case matrix, masking rules, save checkbox defaults, second-contact storage, terms versioning, receipt/delivery conditions, and failure injection are the strongest coverage in either draft.

Add explicit behavior for a recognized person with no wallet/card (including someone who previously opted out), expired or unusable cards, recognized-new-card with save off, directory/wallet outages, ambiguous matches, and conflicting second contacts. Treating multiple matches as “no match” invites another prospect and wallet for an already-known person; use a neutral unresolved-contact outcome until policy is decided. Never attach an additional contact to an existing identity merely because it was typed.

“Change contact” needs server invalidation of the old challenge, stale request rejection, and session/payment/terms reset rules, not just a local field reset. Resend and channel switching must invalidate old codes and share attempt/send limits. The server date interval `[today-1, today+30]` both permits a past date and invents a maximum absent from the intent. Use a configured club time zone and test midnight boundaries; any maximum needs an explicit product decision.

### Phasing and ordering

The two-lane structure and tests within B/C/D are good. Move contract decisions, an actual hosted-capture spike, session ownership, and mandatory origin protection into foundations. A complete mock vertical slice should precede optional platform reads and diagnostics.

Keep authorization → prospect → consented wallet writes, but document capture/issuance/recovery as separate states. Do not reopen this requirement as a casual “confirm or invert” question. Establish idempotency before implementing side effects, with tests during orchestration work.

### Risk coverage

The register usefully covers enumeration, duplicate submissions, logging, upstream gaps, styling, and backend wallet dependencies. Several proposed mitigations need strengthening:

- An idempotency header is not an implementation. Define atomic in-flight exclusion, principal/club binding, request fingerprints, stored outcomes, retention, same-key/different-payload rejection, and handling of an upstream timeout with unknown outcome. Wallet retry must resume the failed stage without another charge or prospect. Single-instance memory is acceptable for a declared local demo, but cannot establish restart-safe financial recovery.
- `SameSite=None` cookies need an explicit cross-site request policy. An origin allowlist only “when set,” introduced in final threat notes, leaves a default gap. Specify fail-closed configuration for enabled authenticated mutations and test disallowed/missing-origin behavior appropriate to the client contract.
- `platform` mode alone does not solve in-memory challenge/rate-limit limitations. Define a supported environment matrix; refuse unsupported enabled configurations while allowing an ordinary flag-off production deployment to boot.
- The mode/write controls conflict: “no wallet write in any environment” versus C3 implementations enabled by `STP_WALLET_WRITES`; partial platform adapters versus no complete platform checkout. Resolve the configuration combinations and list all referenced env variables, including write and origin controls. Never permit real card capture to silently feed a mock sale presented as paid.
- Mock messaging logs codes while E3 bans codes in logs. Choose a dev-only diagnostics channel with an explicit exception, or remove those logs; make production assertions test the actual runtime boundary.

### Feasibility

For the BFF engineer, A + B + C + E totals approximately nine days in the proposed ten-workday window, leaving little room for contract discoveries or review. Eight UI primitives, exact-copy tests, duplicate OAuth/location infrastructure, optional platform reads, and diagnostics broaden the sprint without proving the core uncertainty.

Keep scoped styles and reuse suitable existing primitives; make diagnostics truly optional, and defer platform reads unless credentials and supported contracts are established early. Prefer a small capture/authorization contract spike over implementing dormant wallet writes. Record available engineers and named decision owners before treating the schedule as a commitment. Preserve local uncommitted changes rather than making a blanket pull a readiness requirement.

### Definition of done

Keep the named evidence gates, fixture-driven four runs, failure matrix, threshold checks, and production deferrals. Correct these weaknesses:

- The route map lists nine method/path operations, not seven. Enumerate every registered operation in gate tests.
- A class-name snapshot cannot prove computed-style isolation when SCSS is mocked. Add a real-browser visual/responsive check of the new page and existing signup route. Basic keyboard, focus, labels, and status announcements belong in this sprint even if a broader accessibility audit is deferred.
- Static PAN-pattern scans supplement, rather than establish, hosted-only collection. Test request schemas and actual integration boundaries. Do not count a mock-card demo as proof that Pay Page works.
- Make “reject” versus “ignore” consistent for hostile fields: `additionalProperties:false` implies rejection when validation is enforced.
- Add executable tests for concurrent purchase replay, cross-club/session substitution, no-card recognition, stale challenges, terms revocation/version changes, and post-payment recovery. Mock-call ordering alone cannot prove upstream semantics.
- Separate sprint acceptance from production enablement. The latter still requires real authorization, safe persistence/recovery, supported wallet queries, issuance/delivery, and deployment-safe stores.

## Gemini draft

### Architectural soundness

**Keep:** the concise UI/BFF/integration workstreams, use of Redux and existing Pay Page components, mockable service boundaries, member-ID identity, and strict MICO read-only scope. Avoiding Claude's extensive dormant platform implementation could help keep delivery focused.

The architecture needs concrete contracts before it can guide implementation. `SESSION-ID context, partitioned from general traffic` describes no implemented authentication mechanism; the existing helpers provide cookie plumbing only. Select an explicit session store/token design, lifetime, trust claims, club binding, invalidation, and rehydration behavior.

`lookup`, `otp`, and `checkout` may be sufficient endpoint groupings, but their request/response types, actions, validation, error outcomes, principal sources, and authorization rules are unspecified. Separate send, verify, resend, switch, and cancel semantics even if they share a URL. Define catalog, terms, saved-card read, session reset, and receipt behavior too.

Phase 4 evaluates tokens, persists a prospect, and creates an entry, but omits explicit payment authorization and owner resolution/creation. Tokenization does not authorize the payment. The wallet entry needs a gateway token and an owner tied to the returned member ID, with consent governing persistence. Recognized-new-card must reuse the existing owner; saved-card payment must verify entry ownership server-side. Do not accept client member/owner IDs or raw payment tokens as authoritative.

### Completeness

UC2 unconditionally ends in wallet creation, contradicting save-off behavior. Required omissions include recognized-new-card checkout, new visitor without saving, an empty-wallet returning visitor, exact date gating, skeleton-to-order sidebar behavior, terms modal acceptance, masked contact/card presentation after verification, receipt and QR/pass output, truthful delivery/save confirmation, and Start again.

UC3 conflates switching to an on-file alternate channel with changing contact. The former must remain tied to the candidate; the latter unbinds and starts identification again. “Without losing session context” needs correction to prevent stale authorization.

The file list also omits store registration, BFF router mounting, runtime flag serialization/UI keys, env documentation and validation, test files, typed API interfaces, contract documentation, and a demo script. Internal `dayPass` naming misses the intent's short-term-pass-friendly direction. Choose scoped SCSS now; the late suggestion of `@abc/ui-configs` bundles does not resolve packaging.

### Phasing and ordering

Keep the five-phase outline but put typed contracts and executable fixtures before or alongside scaffolding. Validate hosted capture and the session trust boundary immediately. Build a single end-to-end path, then variants and recovery. Add security and state-machine tests in each phase instead of waiting for Phase 5 to “ramp” coverage.

Resolve route and styling decisions in foundations rather than leaving them open after promising implementation. Clarify that `/signup/day-pass` is the browser URL and `/day-pass` is the route inside the existing basename.

### Risk coverage

The three listed risks are valid but insufficient. Add challenge expiry and atomic consumption, per-contact throttling, resend/switch abuse, contact enumeration limits, cross-site requests, tenant/session substitution, forged price/day/terms, double charging, unknown charge outcomes, prospect failure after authorization, contact conflicts, session expiry, and mock-mode production exposure. Document distributed-store limits and redact PII/tokens rather than logging member-ID assertions as a security measure.

Wallet save failure must produce a truthful, typed partial-success result and a retry path that cannot recharge. Also register the sibling wallet safety dependency, unavailable lean prospect/lookup interfaces, real pass issuance/delivery, and member-versus-prospect policy. Listing MICO endpoints as options does not establish compatibility with the required inputs or authentication.

### Feasibility

There are no estimates, lane assignments, decision deadlines, or explicit mock-versus-platform exit conditions. A smaller document is not necessarily a smaller implementation. Specify runtime adapter selection with stateful deterministic fixtures: static Axios responses will not prove that a newly created visitor can subsequently be identified and use the saved card. A `src/__mocks__` file alone also does not define runtime wiring.

Set a concrete local fallback for catalog, delivery, sale, and prospect creation so unresolved providers do not block the demo. Name live integration work separately and avoid implying that available credentials for Pay Page also authorize datatrak calls.

### Definition of done

“All workflows” is not testable without enumerated scenarios and expected outcomes. Replace it with the four required purchase runs plus negative cases, exact fixture contacts, start command/URL, and reproducible resets. Add lint, complete repository coverage floors, flag-off tests for every backend action and the UI, club-setting enforcement, member-ID/owner-type/tenant assertions, consent and operation-order tests, and prototype visual/interaction review.

Logging assertions is not equivalent to automated contract verification and may disclose identifiers. Use captured adapter payload assertions and redacted runtime logs. Explicitly require the Pay Page session route path, not just an iframe. Track mock acceptance and actual hosted-capture verification independently.

## Recommended synthesis

1. Use Claude's ports, use-case matrix, scoped styles, failure outcomes, and evidence gates, organized under Gemini's simpler workstreams.
2. Freeze a short contract covering principal/club binding, capture-session ownership, authorization/capture/issuance distinctions, idempotency, consent, and recovery before building the orchestrator.
3. Deliver one deterministic mock vertical slice early, then all required variants and negative cases. Validate the real Pay Page submission sequence independently of the card mock.
4. Keep both LD and club-setting checks server-side, model unresolved/no-card identities explicitly, and defer unsupported platform adapters behind a clear environment matrix.
5. Remove optional diagnostics and dormant writes from the critical path. Finish with measurable flow, security, visual, lint, and coverage evidence, plus named external contracts required for production enablement.
