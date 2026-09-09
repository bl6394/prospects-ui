# Sprint 0001: Day Pass single-flow checkout — Online Join UI and BFF

**Status:** CODEX draft for review, 2026-09-09. No implementation or deployment is claimed. Sprint dates and individual owners remain unassigned.
**Inputs:** [Sprint intent](SPRINT-0001-INTENT.md), [requirements prototype](../../prd/day-pass.html) (all 723 lines, including styling and behavior), [token-cache configuration](../../SEMANTIC-INDEX.md); sibling `prospects1/docs/prd/short-term-passes-prospect-identity-prd.md` §§4–6 and `prospect-wallet-plan-v2.md`; house style from `prospects1/docs/sprints/SPRINT-0001.md`.
**Chapter:** none selected; there is no chapter file to apply. This draft does not change any sprint's status. The sibling sprint's header says “planned,” while this intent describes backend work as in progress; neither is evidence of an enabled deployment.
**Path conventions:** `UI/` = `repos/online-join-ui/`; `BFF/` = `repos/online-join-bff/`; `MICO/` = read-only `repos/mico/`; `W/` = `/Users/bjornloftis/claudeprojects/wallet-repos/`; `S/` = `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/`. Files below are proposed unless identified as existing.
**Inspected source snapshot:** UI `f3242b1`, BFF `bc8a4bd`, MICO `5dad4d66`, Universal Wallet `b380cd0`. BFF has an existing uncommitted `src/server.ts` change that skips the CDN manifest fetch when `OJ_UI_URL` is set; preserve it. No source refresh, installation, test run, or service mutation was performed during planning.

## Pyramid Index

- **L0:** Build the prototype's single-page Day Pass checkout at `/signup/day-pass?club=NNNNN`, dark by default, with inline verification, person-owned wallet reuse, hosted card collection, a date/terms sidebar, and an honest purchase result; deliver deterministic BFF adapters for missing services.
- **L1:**
  - **A — contracts and readiness:** establish typed catalog, contact verification, prospect, payment, wallet, and pass contracts; separate verified integrations from local simulations.
  - **B — BFF trust boundary:** club-scoped gating, opaque browser sessions, OTP controls, member-ID binding, tenant isolation, and protected Pay Page sessions.
  - **C — checkout orchestration:** server-owned quotes and idempotency; authorize → persist prospect → consented wallet provisioning; sale/capture, issuance, delivery, and recovery tracked separately.
  - **D — product surface:** scoped Ignite tokens, independent checkout state, prototype copy, hosted payment form, accessible terms modal, receipt, and restart.
  - **E — proof:** browser demo through the BFF, fault fixtures, security regressions, existing signup regressions, full coverage/lint/build evidence, and a named integration readiness register.
- **L2:** §Use Cases maps prototype states to proof; §Architecture fixes defaults and trust boundaries; §Implementation Plan names files and phase exits; §Definition of Done distinguishes sprint delivery from real-service enablement; §Dependencies and §Open Questions register external handoffs.

## Overview

This is the first consumer-facing checkout for the prospect wallet identity model. A contact finds a candidate; a one-time code proves possession; the server binds the checkout to an Ignite member UUID. Wallet owners and, when needed, authorized users resolve by that UUID with type `MEMBER` within the home-club organization. A new buyer becomes a persisted prospect even when they decline card storage.

The sprint delivers UI and BFF code plus a fully executable local flow. Missing upstream services are represented by typed adapters with deterministic state and failure scenarios. Real integrations land only where their contracts can be demonstrated. A mock-complete sprint is explicitly recorded as **local checkout complete; live integration blocked**, rather than claiming a live sale, SMS, usable access credential, or cross-channel wallet availability.

Implementation scope is `online-join-ui` and `online-join-bff`, including their contract/demo documentation. MICO, wallet services, DataTrak, platform configuration, engagement app, and POS remain reference/handoff surfaces. Multi-day sales, membership conversion, recurring billing, bank accounts, digital wallets, wallet management, cross-club purchasing, and persistent “remember me” login are outside this sprint. Internal types use `ShortTermPass`, `durationDays`, and date ranges so later durations do not require a new identity or checkout model.

### Evidence that changes the implementation approach

| Finding | Source inspected | Planning consequence |
|---|---|---|
| `/signup` basename is in `src/index.tsx`; `App.tsx` owns routes, signup header/footer, loading, club fetches, and trackers | `UI/src/{index,App}.tsx`, `common/constants.ts` | Add a separate route shell before signup-only initialization. Preserve existing route behavior and avoid membership stepper/tracker side effects in pass checkout. |
| Guest submit/review is a prospect lead flow, not paid pass checkout | `UI/src/routes/{GuestPage,GuestReviewPage}.tsx`, `services/gym.ts`, `reducers/index.ts` | Reuse conventions and small controls, not guest state or `/trial/submit` as the sale orchestrator. |
| Due-today Pay Page is an add-token session with `deferAuthorizationToPayment: true`; UI reads `result.NEW_PAYMENT_METHOD.TOKEN` | `BFF/src/routes/payPage/index.ts`, `UI/src/routes/PaymentPage/hooks/usePayPageSession.ts` | Token collection does not prove authorization. Add an explicit pass payment adapter and verify token compatibility with wallet `pgToken`. |
| Existing Pay Page polling/close validates session UUID and resolves org from supplied club, without checking browser ownership; origin presence alone is checked at creation | `BFF/src/routes/payPage/index.ts` | Add session ownership and origin controls; a pass-specific endpoint alone must not leave a generic poll/close bypass. |
| Runtime variables are injected under `window.process.env`, flags under `window.featureFlags` | `BFF/src/routes/static/index.html.ts`, `UI/src/utils/featureFlags.ts` | Follow the actual serialization path rather than introducing a separate `window.env` convention. Preserve script escaping and CSP hashing. |
| Existing `SESSION-ID` helpers do not establish an OTP/member session; React `SessionContext` is a network-block UI | `BFF/src/utils/cookies.ts`, `services/application.ts`; `UI/src/contexts/SessionContext.tsx` | Use a dedicated checkout session, with no assumption that existing session state authenticates a person. |
| Prospect creation returns a member ID internally; personal lookup requires an authenticated member session | `MICO/src/main/java/com/abcfs/controller/{ProspectController,AccountController}.java`, `feignclients/OrasvcClient.java` | MICO proves useful backend operations exist, not that its current public endpoints satisfy this new flow. No new MICO dependency is invented. |
| Owner creation needs UUID, type, location, not agreement; card entry creation needs a PG token and additional card metadata | Index routes below → owner validator/VO, credit-card controller/VO | Separate Ignite member UUID, wallet owner ID, wallet entry ID, Pay Page session ID, and PG token in contracts. |
| The index's historical missing-agreement dedup error is already changed in the current wallet checkout | `W/universal-wallet/.../DeduplicationJobKeyByWalletEntryOwnerCalculator.java` at the snapshot above | Record index drift. Require backend-owned test/deployment evidence; neither repeat the obsolete claim as current fact nor mark the backend sprint complete. |

**Semantic retrieval followed:** `S/README.md` → `themes/identity-by-member-id.md` and `themes/agreement-number-and-prosp.md` → `repos/universal-wallet/identity/{owner,authorized-user}.md`, `walletentry/{credit-card,deduplication}.md`, and `repos/commerce-universal-wallet-sdk/sdk.md`. Leaf citations were followed into `W/universal-wallet/src/main/java/com/abcfinancial/api/universalwallet/owner/{vo/WalletEntryOwnerBaseVO,validator/WalletEntryOwnerValidator}.java`, `walletentry/creditcard/CreditCardWalletEntryController.java`, `scheduler/job/data/walletentry/deduplication/util/DeduplicationJobKeyByWalletEntryOwnerCalculator.java`, and the SDK's `walletentry/creditcard/vo/CreditCardBaseVO.java`. Targeted `rg` searches covered the UI/BFF source and MICO Java source; the legacy webapp was not scanned.

The toolkit mock exposes `universalWallet`, payment-gateway, and order-session methods, but a Jest mock is not a verified production client contract. The adapter spike must check installed exports, argument types, scopes, tenant headers, and actual response shapes before selecting a toolkit method.

## Use Cases

| ID | Behavior and required result | Proof |
|---|---|---|
| U1 | Enabled club opens the chosen URL; preselected “Gym Floor” offer, price/perks, one “Mobile number or email” field, Continue, skeleton Order Summary | D1/D2, E1 |
| U2 | Unique email or phone match sends a real challenge in live mode; six-digit code stays inline, with Change, Resend, and alternate channel when available. No name, member ID, wallet data, or alternate address is disclosed before verification | B3/B4, D3, E2 |
| U3 | Correct code rotates/binds session to member UUID; “Welcome back, {first},” masked contacts, saved card brand/last4/source, no card re-entry | B4/B5, D3/D4 |
| U4 | Recognized buyer uses a different hosted card, save default on; saving adds to the existing owner. Save off preserves existing entries | C3/C4, D4 |
| U5 | No match shows “Welcome — a few details”; first/last name, optional other contact with prototype explanation, hosted card, save default on | B3, C3, D3/D4 |
| U6 | New purchase authorizes, persists prospect to obtain member UUID, then creates wallet identity/entry only if saving. Save off still persists the prospect and secondary contact | C3/C4, E2 |
| U7 | Returning prospect with zero usable cards verifies normally and enters a new card. Wallet lookup failure shows Retry rather than pretending the wallet is empty | B5, D4, E2 |
| U8 | Sidebar on either checkout path has blank date initially, minimum today, authoritative line item/total, independent unchecked terms, “Agree and close,” and gated Pay | C1/C2, D5 |
| U9 | Confirmed purchase shows “You're in, {first},” pass/QR, selected day, delivery to masked contact, truthful save status, Receipt sidebar, app link, Start again | C5, D6 |
| U10 | Start again clears authentication/challenge/order/consents and allows another verification; a newly saved person's primary or secondary contact resolves the same member/owner | B4, C4, D6, E1 |
| U11 | Wrong/expired/replayed code, resend limits, ambiguous matches, changed contacts, cross-browser IDs, cross-club IDs, stale async responses, and expired sessions never reveal or charge another wallet | B3–B6, E2 |
| U12 | Double-click, lost response, refresh, authorization timeout, prospect failure, wallet failure, sale/issuance failure, and delivery failure resume or compensate without duplicate charge/person/entry/pass | C2–C5, E2 |
| U13 | Flag off, missing/invalid club, unavailable settings, or `onlineProspects` disabled makes checkout unavailable in UI and BFF; legacy signup and guest paths still work | B1/B2, D1, E3 |

Prototype fixture: Jordan Reyes, `m@m.com`, `(555) 019-2231`, Visa `4242`, source “Saved in the app last week”; Gym Floor, USD 25.00 inclusive total, Classes / Steam & Sauna / Basketball court. Fixture identities use valid deterministic UUIDs, replacing illustrative `mbr_*` values. The fictional phone is accepted only by the mock adapter; it is never sent to a live SMS provider.

## Architecture

### Route, shell, state, and design

Choose **`/signup/day-pass?club=NNNNN`**, retaining `BrowserRouter basename="/signup"`. Register `PAGES.shortTermPass = '/day-pass'`. A narrow `App.tsx` route branch renders `ShortTermPassPage` with its own bootstrap and shell; existing signup initialization remains in a legacy shell component. Missing club must produce a useful unavailable state, not the existing indefinite loading behavior. Changing club starts a fresh navigation/session and reevaluates configuration.

Create a Redux Toolkit slice/thunks under `reducers/shortTermPass/`, typed axios services, and selectors. State is a discriminated union: `bootstrapping → identify → challenge → recognized | newVisitor → submitting → complete`, with explicit recoverable errors and `processing` purchase state. Challenge is visually part of Identify, so the sidebar remains skeleton until verification or the no-match path creates a quote. Maintain form values while opening terms, changing date, or switching payment mode. Discard stale responses using request IDs and checkout generation. OTP digits stay component-local; payment tokens, full card details, and authenticating session credentials never enter Redux or browser storage.

Use `src/styles/short-term-pass.scss` for prototype `--ig-*` tokens and `dt-*` compositions under `.short-term-pass`. Scope resets, typography, grid, widgets, fields, buttons, and modal styling; port no global `:root`, body, or universal-selector overrides. MUI v4 Dialog supplies focus trap, Escape behavior, labeling, and focus restoration; its portal gets the scoped class/tokens. Reuse the existing Pay Page embed rather than mimicking its card fields.

Preserve prototype desktop geometry (1440px max layout, 424px sidebar), stacked layout below 960px, offer layout below 1100px, narrow form below 520px, and reduced-motion support. Validate keyboard use, code paste/autofill/backspace, focus-visible, error association, status announcements, zoom, and 375px mobile layout. Avoid nested main landmarks and multiple page-level h1s when mounting inside the existing `main#app`.

Header uses trusted club branding/location and “Secure checkout.” Day Pass is active. Membership/Visit links may use existing valid club URLs; Class, app destination, and location switching require configured targets. Do not ship dead `href="#"` controls. Missing destinations render noninteractive labels or omit the action with a documented design deviation; an app link is a launch dependency. Prototype-only restart controls and “Behind the scenes” panel are omitted; the product's Start again remains. Deterministic server traces provide the demo diagnostics.

### Gates and server-owned club context

Proposed LaunchDarkly key **`oj-short-term-pass-checkout`**, serialized as `oj_short_term_pass_checkout`, default false. Evaluate with trusted resolved home club and the existing normalized five-digit club context; Pay Page's location search currently pads club numbers to six digits, so keep that upstream mapping distinct and test both representations.

Every pass API enforces flag + `onlineProspects` + valid club/product capability. Settings/LD failures fail closed. The HTML flag is a UI hint, never API authorization. A query club chooses a bootstrap candidate only; the server resolves organization/location and binds them to the checkout. Subsequent requests cannot replace them. A flag flip blocks new charge/provisioning work, while already-started purchases retain a narrowly scoped status/reconciliation path so disabling checkout cannot strand an uncertain charge.

Live wallet reads/writes additionally require confirmed wallet enablement and prospect-readiness for that home club. Until that mapping is verified, the live pass feature remains off rather than silently substituting guest or legacy card entry. A dev-only server override may enable an allowlisted fixture club in mock mode; it is rejected in production and never enabled by a URL or browser flag.

### Browser session and OTP

Use a new opaque random checkout cookie (proposed `OJ-PASS-SESSION`), with server-side `CheckoutStore` records. Do not overload `SESSION-ID`. Production: HttpOnly, Secure, SameSite=Lax, host-only, path `/`; v1 entry is top-level. For HTTP localhost mock mode only, permit a non-Secure cookie with the same isolation semantics. Embedded pass checkout is deferred unless approved origin/cookie behavior is verified; an unsupported iframe offers a top-level checkout link, never legacy raw card entry.

Proposed bounds: 30-minute idle and two-hour absolute checkout lifetime; five-minute OTP lifetime; five incorrect attempts per challenge; 30-second resend cooldown; five sends per contact+club per 15 minutes; 20 sends per IP per 15 minutes, plus a bounded lookup limit. These are implementation defaults pending security review. Use injected clocks in tests. Resend, switch, and Change invalidate old challenges; send limits apply across fresh cookies, channels, and resends. Use provider verification or cryptographic random codes stored as a keyed digest; no plaintext code logging in live mode. A fixed test code exists only in isolated mock mode.

Before verification, server records candidate UUID and alternate contact privately. Browser receives an opaque challenge ID, submitted-channel mask, alternate-channel availability, expiry, and resend time. Switching sends to the server-held alternate contact without revealing its value; show “Code sent by text/email,” not a mask derived from an unsubmitted address. A successful verify atomically consumes the challenge and rotates session identity. Change/Edit, expiry, Start again, or club change revokes binding, challenges, quote, and attached hosted sessions. Successful new-person creation establishes only access to that order's result; later wallet retrieval requires OTP, because this path has not proved ownership of a contact.

No-match and challenge are intentionally different prototype states, so complete anti-enumeration is impossible without changing requirements. Expose only this necessary branch and alternate-channel availability; standardize error text, limit abuse, omit candidate counts/identifiers, and record this residual disclosure for review. Multiple matches are an explicit ambiguous state with a desk-help message, never “first match” or “no match.” A newly submitted secondary contact is an unverified lookup key, not proof or merge authority. Prospect creation must report contact conflicts/races; never attach an unverified buyer to an existing member or reveal that member's wallet. Re-enter verification before proceeding if a match appears during creation.

Require allowlisted Origin and a session-bound CSRF token for browser mutations. Use no-store responses and redacted logs. The initial bootstrap has origin checks and sets the CSRF value; GETs do not create people, send codes, or charge. Authorization errors are typed so ordinary session expiry/rate limits do not accidentally trigger the existing global “network blocked” modal.

An in-memory bounded store is acceptable for isolated local mocks only; restart invalidates sessions and simulated purchases. Real-money mode requires a shared store with atomic challenge consumption, locks, durable purchase checkpoints, and expiration/reconciliation policy. Specify its interface this sprint; keep live mode unavailable until a concrete durable implementation is proven. Process memory is not a distributed idempotency guarantee.

### Proposed browser-facing contract

Prefix **`/api/short-term-pass`** avoids the existing `/api/online-join/*` wildcard proxy. Mount before static fallback. Dedicated router schemas reject unknown security-sensitive fields and validate every response from upstream. Browser bodies never accept `memberId`, owner/user IDs, org/location, agreement metadata, price, terminal ID, or PG token.

| Method / path | Request | Response / server work |
|---|---|---|
| `POST /checkouts` | `{clubNumber}` | Validate club/gates; create anonymous context; return checkout ID, CSRF token, club timezone/branding/links, selected offer, terms version/content, capabilities |
| `POST /checkouts/:id/identify` | `{contact}` | Normalize by supported country policy; lookup in home club; return `challenge`, `newVisitor`, or `ambiguous`; atomically send first code for unique match |
| `POST /checkouts/:id/challenges/:challengeId/resend` | `{}` | Rotate challenge/code, apply shared rate limits |
| `POST /checkouts/:id/challenges/:challengeId/channel` | `{channel: 'email' | 'phone'}` | Use only candidate's stored eligible channel; invalidate old challenge |
| `POST /checkouts/:id/challenges/:challengeId/verify` | `{code}` | Consume challenge, rotate cookie, bind member UUID; return masked profile and create quote |
| `DELETE /checkouts/:id/identity` | no body | Revoke challenge/binding/hosted session; restart Identify with safe contact hint only |
| `GET /checkouts/:id/wallet` | no identity parameters | Verified session only; return permitted active-card summaries and opaque selection references; empty differs from unavailable |
| `PUT /checkouts/:id/order` | `{offerId, visitDate, quoteVersion, terms: {accepted, version, method}, saveCard}` | Validate club-local date and terms; resolve authoritative price; store quote/consent state and return versioned order summary |
| `POST /checkouts/:id/purchases` | `{quoteVersion, payment: {kind: 'saved', selectionRef} | {kind: 'hosted', sessionId}, profile?: {firstName,lastName,secondaryContact}}`; `Idempotency-Key` header | Validate all gates/ownership; orchestrate purchase; `200/201` final or `202` processing with purchase ID/status URL |
| `GET /checkouts/:id/purchases/:purchaseId` | no body | Session-scoped sanitized status, receipt, pass data, independent wallet and delivery results |
| `POST /checkouts/:id/purchases/:purchaseId/wallet-retry` | same operation identity, current save consent | Retry failed wallet step only; never authorize/sell again; require verified identity after authentication expiry |
| `DELETE /checkouts/:id` | no body | Start again: revoke checkout browser access; preserve durable transaction audit/reconciliation data |

Hosted card endpoints use the existing Pay Page router: add `POST /api/pay-page/session/short-term-pass` with `{checkoutId}` and route-fixed `CARD`/deferred authorization; add a pass-scoped sanitized status endpoint and session-close support. Share the existing OAuth/location/session transport, not its unrestricted response pass-through. Response exposes session URL/ID and sanitized readiness/card display only; the BFF reads the trusted token result when executing purchase.

Store browser ownership and purpose for **all BFF-created Pay Page sessions**, including existing signup sessions, and enforce it on generic and pass-specific poll/close paths. This prevents a caller using legacy `GET /session/:sessionId?clubNumber=...` to bypass pass authorization. Unknown/unowned sessions fail closed; test existing signup creation/poll/close and refresh using the same cookie. Plan compatibility for preexisting sessions at rollout rather than adding an unrestricted fallback. Purpose/binding survive token expiry long enough to prevent replay. Client origin, ancestor origins, branding, and terminal routing receive server allowlists; client overrides cannot change the pass session's purpose or payment methods.

Common error envelope: `{code, message, retryable, correlationId, retryAfterSeconds?}` with safe field errors where appropriate. Use 400 validation, 401 expired/unverified, 404 disabled/not-owned, 409 ambiguity/quote or idempotency conflict, 429 throttling, and 502/503 upstream unavailable. A timed-out mutation with unknown outcome returns processing/status lookup rather than a retry invitation that could charge again. Browser identity and payment references are checked against server bindings on every request.

### Upstream adapters and mock strategy

| Adapter | Required operations and guarantees | Existing evidence / selected approach |
|---|---|---|
| `ClubCatalogAdapter` | Resolve club/org/location/timezone; eligibility, offer ID/duration, integer minor-unit amount/currency/tax, terms version, app/brand links | Existing club fetch and Pay Page location lookup are starting points. Mock per-club catalog first; live POS catalog mapping requires owner approval of schema. No production hardcoded $25. |
| `IdentityAdapter` | Club-scoped contact lookup; explicit none/unique/ambiguous; persisted member UUID/type/home club; create prospect with idempotency and optional secondary contact; conflict instead of unsafe merge | MICO's `addProspect.spr` proves persistence, but required address/signature/campaign fields and response mapping differ from prototype. Prefer a future purpose-built service contract; direct DataTrak adapter only when its auth/schema is demonstrated. |
| `VerificationAdapter` | Send/verify code, expiry, delivery failure, replay prevention, alternative registered channel | No phone/email lookup or OTP provider established in MICO. BFF controls challenge/session orchestration; live provider and credentials are an external handoff. |
| `PaymentAdapter` | Validate owned hosted result; translate token to PG token; authorize stored/new card for exact quote; status inquiry, capture or sale finalization, void/refund | Reuse Pay Page token collection. Toolkit method names are candidates, not evidence that authorization/capture without an agreement works. No call to `submitAgreement`. |
| `WalletAdapter` | Resolve owner/user by `(org, member UUID, MEMBER)`; list active permitted cards; idempotent create owner/user and credit-card entry; preserve existing member metadata | UW owner/user and `/wallet-entry/credit-card` contracts verified in source. Prefer toolkit only after signatures/scopes are proven, else a small authenticated HTTP client to verified UW endpoints. |
| `PassSaleAdapter` | Finalize one sale per purchase key against authorized payment; return settlement result and entitlement/QR, exact dates and receipt; status inquiry/compensation | DataTrak `/pos/saleItems.spr` and `/pos/onlineSale.spr` are references. Determine whether sale captures or accepts prior authorization; never both charge paths. |
| `DeliveryAdapter` | Idempotent receipt/pass email or SMS, independently queryable outcome | Provider unknown; live response must distinguish queued/delivered/failed. Mock records delivery in an inspectable outbox. |

Server-only `SHORT_TERM_PASS_ADAPTER_MODE=mock|live` defaults to a disabled live configuration unless explicitly configured for local mocks. A production process refuses mock mode and any mock flag override. Each adapter has a runtime-validated schema, sanitized error mapping, timeout, and typed capability report. Missing live operations fail closed; there is no automatic fallback to successful fixtures. New secrets belong in untracked `.env`; add names and descriptions only to `.env.example` and typed optional env declarations, with mode-conditional validation so feature-off startup remains compatible.

Mocks exercise the same routers, authorization checks, sequencing, and schemas as live adapters. Persist mock people/wallets across checkout resets within the process so save → Start again → secondary-contact verification → saved-card purchase is real stateful behavior. Seed separate same-club prospects, another org, a member, no-card person, ambiguous contacts, expired cards, and failure controls. Fault selection/reset/outbox inspection is test harness or local-server-only, never a production browser API.

For card collection, the required integration demonstration uses the actual Pay Page SDK and sandbox token sessions while business services may be mocked. Fully offline Jest/local demonstration can use a test-only SDK fixture producing synthetic opaque session results with no card-number inputs. Label that run as simulated hosted collection; it does not satisfy the sandbox payment gate. Configure modes independently enough to combine sandbox hosted fields with mock sale/wallet behavior safely, and forbid live charges in that combination.

### Identity and wallet write rules

1. For recognized visitors, derive member UUID and home club from the verified session. Resolve the existing MEMBER owner and validate its org/location before listing or charging an entry. Never use broad agreement-number searches or remote-club owner helpers that silently re-home identities.
2. For a new visitor, collect/tokenize and authorize without provisioning a wallet identity. Persist the prospect and validate the returned canonical member UUID and home club. A DataTrak agreement row may internally contain `PROSP`; that value never enters wallet identity or agreement metadata.
3. If save consent is false, create no new owner/user/entry solely for storage. Preserve any existing wallet and persist the prospect plus additional contact regardless of consent.
4. If consent is true, resolve/create MEMBER owner and any required MEMBER authorized user by the same member UUID; handle uniqueness races by re-reading and validating the same tenant/person. Stamp new prospect owner/user/entry metadata with `dt_clubNumber`, `dt_memberId`, `dt_vpdId`, `dt_memberType=PROSPECT` from trusted persistence data. Omit `dt_agreementNumber`, `dt_memberNumber`, `dt_memberOrdinal`; never synthesize VPD or copy client metadata. Existing members retain their real lifecycle/metadata.
5. Create entry with server-verified `pgToken`, `ownerIds: [walletOwnerId]`, `type=CREDIT_CARD`, status, and required gateway-supplied card metadata. A session ID or browser callback token is not automatically a PG token. Respect entry token uniqueness; a conflict requires read-and-validate of that purchase's existing entry, not assignment to a different owner.
6. The web read path is owner association based, not an agreement assignment query. Do not create PRIMARY, ALTERNATE, CLUB_ACCOUNT, or CARD_ON_FILE roles to make a library call work. Authorized user existence alone does not establish an assignment. An upstream requiring such roles blocks that live adapter until its owner provides a supported person-owned payment path.
7. New card for a recognized person adds an entry to the existing owner; it does not replace/delete the old entry. Map card selection through server-held references and revalidate eligibility just before authorization. Never infer identical cards from last4.

### Payment ordering, consent, and recovery

Date is a calendar date in the club's timezone, blank initially, minimum club-local today. The BFF validates it again at purchase time, including midnight rollover; catalog supplies any future-date limit and duration. Amounts use integer minor units/currency, never browser arithmetic or floating point as authority. A price/terms revision requires a refreshed quote and fresh terms acceptance.

Terms checkbox starts false and is distinct from default-on save-card consent. Opening/closing terms is not acceptance; checkbox or “Agree and close” records version, method, server timestamp, checkout and quote. Persist the purchase's terms/save consent snapshot before authorization. Prototype terms are explicitly placeholders: their tax-inclusive/refund language is not adopted as a live club policy. Use trusted versioned terms, sanitized if HTML. Pay is disabled until date and terms are set and while busy; required profile/card readiness also prevents execution and receives inline validation. The BFF independently enforces these rules.

Each purchase gets a durable server operation record keyed by checkout + idempotency key and a canonical request fingerprint. Reuse the key after lost responses; differing payload gets 409. Atomic transition/locking prevents concurrent execution even if a client supplies two keys for the same active order. Checkpoints: `VALIDATED → AUTHORIZING → AUTHORIZED → PERSON_PERSISTED → WALLET_RESULT → SALE_FINALIZING → ISSUING → COMPLETE`, plus `RECONCILING`/`COMPENSATING`/`FAILED`. For recognized people, the person checkpoint is already satisfied; new-card saving still occurs only after authorization. Delivery and wallet outcomes are independent fields rather than a single success boolean.

Default transaction proposal: authorize → persist person if new → attempt consented save → finalize sale/capture once → issue pass → send delivery. Whether the POS sale performs capture or a payment API performs it must be settled in A2. Never display “Paid” or “Your pass is ready” from authorization alone. If finalization combines issuance atomically, adapt checkpoints to that demonstrated contract without changing identity ordering.

| Failure boundary | Required behavior |
|---|---|
| Tokenization/card validation or explicit authorization decline | No prospect/wallet/sale; allow correction with a new payment attempt only after final decline is known |
| Authorization timeout/unknown | Query by provider reference/idempotency key; show processing; do not initiate another authorization |
| Prospect persistence fails after authorization | No owner/user/entry; void authorization; if void outcome unknown, reconciliation state with order reference and no success claim |
| Contact race/conflict at create | Do not use returned candidate as authenticated identity; void/reconcile authorization and return to verification |
| Owner/user/entry creation fails after prospect commit | Keep prospect and existing entries; retain a retryable wallet result, continue sale if supported, never say saved. Retry only missing wallet work, not payment. Partial new identities remain attached to the valid person |
| Sale/capture fails after wallet save | Keep valid prospect/consented wallet; void or refund according to confirmed payment state; no usable pass until settled/issued. Explain purchase failure separately from save outcome |
| Issuance fails after settlement | Resume issuance by purchase ID; no second charge. If permanently impossible, refund and mark pass revoked/not issued; reconciliation owner handles unresolved outcomes |
| Delivery fails | Keep successful pass/receipt visible; display delivery pending/failed, allow bounded delivery retry; never claim “emailed/texted” before confirmation |
| Refresh/browser loss/session expiry | Recover through owned purchase status; reverify to regain wallet access where needed. Payment reconciliation continues independent of browser lifetime |

Retries use stable upstream keys per operation, not broad retry-on-5xx loops. Owner lookup/create uniqueness is not sufficient to make entry, payment, prospect, or sale mutations idempotent. Persist upstream references and intended entry `providedId` where supported; after an uncertain result, query and validate before resubmitting. Token retention and wallet-retry TTL must be agreed before live saving; expired tokens require hosted re-entry without recharging a completed purchase.

Done renders an actual issuance response (QR payload or trusted image plus human-readable pass reference), not the prototype's decorative grid. Mock QR and outbox are visibly marked as demo outputs. Save confirmation and “Next time” copy depend on confirmed wallet storage and supported channel capabilities; cross-channel availability remains a live gate. “Your card stays on file at the club — not on this website” remains the checkout fine print; it does not justify logging tokens or storing card data in the browser.

## Implementation Plan

**Sizing:** approximately 20–27 engineering days across UI, BFF, and QA, with contract decisions front-loaded; elapsed sprint length depends on staffing and upstream access. Assign individual owners at kickoff. A precedes dependent integrations; B/C and D can proceed against the same frozen fixtures after A. No dates from the sibling sprint are inherited.

### A — contract and evidence baseline · 2–3 days

| ID | Task | Files / exit evidence |
|---|---|---|
| A1 | Record source SHAs, existing working changes, package versions, route/proxy ordering, feature serialization, and pre-change checks. Document index drift and distinguish backend source availability from deployment readiness | NEW `BFF/docs/short-term-pass-contract.md`; evidence section in `BFF/docs/short-term-pass-validation.md` |
| A2 | Resolve adapter operations, required fields, identity/tenant rules, token-to-PG conversion, stored-card authorization, sale/capture/void semantics, and status inquiry. Confirm prospect creation can work with prototype fields; do not fabricate address/signature defaults | NEW `BFF/src/services/shortTermPass/{contracts,schemas}.ts`; contract capability table, live fixtures where available |
| A3 | Freeze browser DTOs/error codes, state transitions, quote/consent, fixture identities, failure scenarios, and mock/live startup rules | NEW `UI/src/interfaces/api/shortTermPass.ts`, `BFF/src/routes/shortTermPass/schemas.ts`, BFF contract examples checked by both suites |
| A4 | Assign service/security/product/design owners and classify each live capability proven or blocked. Record chosen scope as local complete target with explicit sandbox/live gates | BFF contract decision register; all P0 blockers named |

**Exit:** executable schema fixtures and adapters with explicit unsupported responses; no implementation relies on an assumed upstream endpoint or “any six digits” outside mocks.

### B — BFF access, identity, hosted sessions · 5–7 days

| ID | Task | Files |
|---|---|---|
| B1 | Create dedicated router, bounded schemas/error envelope, no-store handling; mount before static and verify history fallback never rewrites APIs with HTML Accept headers | NEW `BFF/src/routes/shortTermPass/{index,schemas}.ts`; MODIFY `src/routes.ts`, `src/utils/middlewares/historyFallback.ts` if required |
| B2 | Club resolver + feature/onlineProspects/readiness gates; correct trusted LD context and HTML serialization; mode-conditional env checks, mock production refusal | NEW `BFF/src/services/shortTermPass/{clubContext,config}.ts`; MODIFY `src/routes/static/index.html.ts`, `src/env.ts`, `src/services/healthCheck.ts`; reuse LD wrapper/context |
| B3 | Normalization, candidate lookup, typed ambiguity, challenge creation/send/resend/channel/verify with atomic caps and rate limits | NEW `BFF/src/services/shortTermPass/{identity,verification,rateLimit}.ts`, `adapters/{identity,verification}.ts` |
| B4 | Opaque cookie, rotation/revocation/expiry, CSRF and origin validation; bounded in-memory local store and production store contract; stale-request and club-change protection | NEW `BFF/src/services/shortTermPass/{session,store}.ts`, `BFF/src/utils/shortTermPassSecurity.ts` |
| B5 | Member-owned wallet listing, empty/unavailable distinction, eligible-card references, tenant/location validation; return only masked permitted data | NEW `BFF/src/services/shortTermPass/wallet.ts`, `adapters/wallet.ts` |
| B6 | Extract Pay Page transport helpers; add pass token-only session route; record ownership/purpose for create/poll/close including generic routes, sanitized pass status, server-fixed methods/terminal/origin | MODIFY `BFF/src/routes/payPage/index.ts`; NEW `BFF/src/services/payPage/{client,sessionOwnership}.ts`; MODIFY existing payPage tests and security-header tests where applicable |

**Exit:** U2/U3/U11/U13 security contract tests green; neither a forged cookie/body nor a generic Pay Page route retrieves another checkout's data. Existing signup session regression remains green.

### C — purchase, persistence, wallet, fulfillment · 5–7 days

| ID | Task | Files |
|---|---|---|
| C1 | Catalog/quote/date validation with club timezone and integer money; versioned terms and separate save-consent persistence | NEW `BFF/src/services/shortTermPass/{catalog,quote,consent}.ts`, `adapters/catalog.ts` |
| C2 | Purchase state machine, request fingerprints, one active attempt per order, checkpoint/lock interface, safe retries/status inquiry | NEW `BFF/src/services/shortTermPass/{purchase,purchaseStore}.ts` |
| C3 | Hosted-token validation and stored-card authorization; authorize-before-prospect flow; canonical member UUID/home-club validation, second-contact persistence and collision behavior | NEW `BFF/src/services/shortTermPass/adapters/payment.ts`; integrate identity adapter and purchase service |
| C4 | Consent-only idempotent owner/user/entry provisioning, metadata allowlist, existing-owner reuse, no agreement roles, scoped wallet-only retry | `wallet.ts`, `adapters/wallet.ts`, purchase service; source-backed payload fixtures |
| C5 | Sale/finalization, issuance, delivery and compensation; honest independent status responses and reconciliation contract | NEW `BFF/src/services/shortTermPass/{fulfillment,reconciliation}.ts`, `adapters/{passSale,delivery}.ts` |
| C6 | Deterministic stateful mock adapters, fake clock/fault injection, secondary-contact repeat purchase, synthetic PG/session values and delivery outbox; redact diagnostic output | NEW `BFF/src/services/shortTermPass/adapters/mock.ts`, `fixtures.ts`; NEW `BFF/scripts/short-term-pass-demo.ts` |

**Exit:** U4/U6/U10/U12 pass through actual router/service code with ordered call assertions and state inspection. Unknown payment outcomes never trigger a blind retry; mock restart limitations are explicit.

### D — UI single-page checkout · 5–7 days

| ID | Task | Files |
|---|---|---|
| D1 | Add isolated route/bootstrap/unavailable shell; preserve basename and existing signup initialization in extracted shell; avoid guest/review analytics side effects; add feature mapping | MODIFY `UI/src/App.tsx`, `common/constants.ts`, `utils/featureFlags.ts`; NEW `src/routes/SignupShell.tsx`, `src/routes/ShortTermPass/ShortTermPassPage.tsx` |
| D2 | Typed axios API, Redux state/thunks/selectors, request generation, teardown; scoped Ignite styles, responsive shell and offer | NEW `UI/src/services/shortTermPass.ts`, `reducers/shortTermPass/shortTermPassSlice.ts`, `selectors/shortTermPass.ts`, `styles/short-term-pass.scss`; MODIFY `configureStore.ts`; NEW route `components/{CheckoutShell,PassOffer}.tsx` |
| D3 | Identify, inline code controls, validation/loading/retry/expiry, recognized/new profile states, secondary contact, safe contact editing and masking | NEW route `components/{IdentifyPanel,VerificationCode,VisitorDetails}.tsx` |
| D4 | Saved-card selector, no-card state, different-card toggle, hosted form with save checkbox; reuse PayPageEmbed and its submit/cleanup API; pass-specific hook exposes readiness only | NEW route `components/PaymentMethod.tsx`, `hooks/useShortTermPassPayment.ts`; MODIFY `UI/src/services/payPage.ts` for typed pass calls; existing embed reused |
| D5 | Persistent summary skeleton → quote, blank date/minimum, independent terms gate/modal, loading/validation Pay states and server consent updates | NEW route `components/{OrderSummary,TermsDialog}.tsx` |
| D6 | Processing/retry/partial-success views, receipt/pass, truthful save/delivery copy, configured app link, server-backed reset; prevent duplicate submit and recover refresh via status | NEW route `components/{PurchaseStatus,PassConfirmation}.tsx`; integrate slice/thunks |

**Exit:** all happy paths match prototype states and layout, with intentional hosted-field and error-state differences documented. Modal/date rerenders do not erase entered names or reset the iframe unnecessarily.

### E — verification, demo, readiness record · 3 days

| ID | Task | Files / evidence |
|---|---|---|
| E1 | Script the fixture returning saved-card flow; new visitor save on/off; returning different card save on/off; Start again via secondary contact; returning zero-card case. Capture browser evidence at desktop/mobile and sandbox hosted-field run | NEW `BFF/docs/short-term-pass-demo.md`, `UI/docs/short-term-pass-ui-validation.md`; demo script from C6 |
| E2 | Security/fault matrix: preverify leakage, expired/wrong/replayed OTP, channel invalidation, cookies/CSRF/origin, tenancy, generic Pay Page bypass, price/terms tampering, concurrent purchase, every failure checkpoint and retry | NEW `BFF/src/routes/shortTermPass/__tests__/index.test.ts`, `src/services/shortTermPass/__tests__/{identity,wallet,purchase,recovery,adapters}.test.ts`; extend existing payPage tests |
| E3 | UI state/interaction/error tests and existing signup/guest/Pay Page regressions; deep-link refresh, disabled club, missing club, history fallback, stale requests and modal accessibility | NEW `UI/__tests__/routes/ShortTermPass/*.test.tsx`, `__tests__/reducers/shortTermPass/shortTermPassSlice.test.ts`, `__tests__/services/shortTermPass.test.ts`; extend existing App tests |
| E4 | Run full lint/build/coverage commands in both repos; record exact commands, source SHAs, outputs, scenario adapter modes, remaining live blockers and named approvals | `BFF/docs/short-term-pass-validation.md`, UI validation doc |
| E5 | Add bounded metrics and redacted correlation traces; demonstrate mocked authorization/persist/save/sale/delivery outcomes and zero sensitive payload logging. Record enable/disable and reconciliation behavior | NEW `BFF/src/services/shortTermPass/metrics.ts` with tests; reuse `prom-client`/existing metrics endpoint; validation doc |

**Execution commands:** UI `npm run lint`, `npm run build`, `npm run test:cov -- --runInBand`; BFF `npm run lint`, `npm run build`, `npm run test:cov -- --runInBand`. Run affected tests during implementation, full suites at the final candidate; do not lower thresholds or add exclusions to pass. Record unrelated baseline failures separately, and do not label a failing final suite green.

Local demo runs UI on :3001 and opens **`http://localhost:3000/signup/day-pass?club=<fixtureClub>`** through the BFF so runtime configuration/cookies are exercised. Use `OJ_UI_URL` and the existing local manifest bypass; no MICO change is required. The script must verify API results and mock outbox/wallet state, not merely print instructions. Add a documented npm demo command and any runner dependency deliberately; scripts must not assume TypeScript runs natively under every supported Node 22 version. Optional wallet compose validation uses the sibling infrastructure without changing it, and is labeled separately from mock proof.

## Files Summary

| Repo | Paths | Action / purpose |
|---|---|---|
| UI | `src/App.tsx`, `src/routes/SignupShell.tsx`, `src/common/constants.ts`, `src/utils/featureFlags.ts` | MODIFY / NEW: isolated route and existing signup shell |
| UI | `src/routes/ShortTermPass/{ShortTermPassPage.tsx,components/*.tsx,hooks/useShortTermPassPayment.ts}` | NEW: prototype states, sidebar, hosted card and result |
| UI | `src/styles/short-term-pass.scss` | NEW: scoped tokens/components |
| UI | `src/interfaces/api/shortTermPass.ts`, `src/services/shortTermPass.ts`, `src/reducers/shortTermPass/shortTermPassSlice.ts`, `src/selectors/shortTermPass.ts` | NEW: typed contracts/state/API |
| UI | `src/configureStore.ts`, `src/services/payPage.ts` | MODIFY: reducer registration and protected hosted-session calls |
| UI | `__tests__/routes/ShortTermPass/*`, `__tests__/reducers/shortTermPass/*`, `__tests__/services/shortTermPass.test.ts`, existing App/Pay Page regression tests | NEW / MODIFY: interaction and regression proof |
| UI | `docs/short-term-pass-ui-validation.md` | NEW: copy/layout/accessibility and browser evidence |
| BFF | `src/routes/shortTermPass/{index,schemas}.ts`, `src/routes.ts` | NEW / MODIFY: protected API boundary |
| BFF | `src/services/shortTermPass/*.ts`, `src/services/shortTermPass/adapters/*.ts` | NEW: A–C contracts, context/session/OTP, quotes/consent, wallet/purchase/recovery, mocks and metrics |
| BFF | `src/utils/shortTermPassSecurity.ts`, `src/services/payPage/{client,sessionOwnership}.ts`, `src/routes/payPage/index.ts` | NEW / MODIFY: shared hosted-session transport and ownership checks |
| BFF | `src/routes/static/index.html.ts`, `src/env.ts`, `src/services/healthCheck.ts`, `.env.example` | MODIFY: runtime flags and conditional server-only settings |
| BFF | `src/utils/middlewares/historyFallback.ts`, `src/utils/setSecurityHeaders.ts` | CONDITIONAL MODIFY: explicit API exclusions / verified hosted origin only if existing behavior needs adjustment; add regressions |
| BFF | `src/routes/shortTermPass/__tests__/*`, `src/services/shortTermPass/__tests__/*`, existing payPage/static/env/security tests | NEW / MODIFY: runtime schema, security, failure and mode tests |
| BFF | `scripts/short-term-pass-demo.ts`, `package.json`, lockfile if required | NEW / MODIFY: reproducible scripted demo runner |
| BFF | `docs/short-term-pass-{contract,demo,validation}.md` | NEW: contracts, decision/readiness register, runnable scenarios and results |
| Planning repo | `docs/sprints/drafts/SPRINT-0001-CODEX-DRAFT.md` | This draft only during planning; no other file is changed by this planning task |

No implementation task modifies MICO, wallet repositories, platform config, the prototype, the semantic index, or the sibling sprint. Preserve the preexisting BFF server patch; integration does not require rewriting it. No shared package or schema migration is proposed without a separately justified live storage decision.

## Definition of Done

Owner slots: UI, BFF, QA, SECURITY, PRODUCT, DESIGN, PAYMENTS, IDENTITY, WALLET, PASS/DELIVERY, PLATFORM. Fill individuals at kickoff; no unnamed role signs off. Scope selection is recorded at A4, not silently changed when an upstream is unavailable.

### Sprint delivery gates

| Gate | Lane / owner | Passes when |
|---|---|---|
| G0 — Ready | eng / UI+BFF | A contract/evidence baseline complete; each upstream classified; source drift and existing patch recorded |
| G1 — Product flow | product / PRODUCT+QA | U1–U10 run locally through BFF; all save on/off variants plus next visit by secondary contact; identity and wallet state inspected, not inferred from copy |
| G2 — Prototype parity | design / DESIGN | Desktop/mobile/state review; scoped tokens; keyboard/OTP/modal behavior; complete copy checklist and documented hosted-field/navigation differences |
| G3 — Identity boundary | eng / BFF+SECURITY | No preverify profile/card disclosure; member UUID only; session/challenge ownership, rotation/revocation, attempts/rate limits and cross-tenant tests; no PROSP/agreement-based identity |
| G4 — PCI boundary | eng / PAYMENTS+QA | No PAN/CVC React fields/state/API payloads; actual Pay Page SDK sandbox run recorded. Offline fixture proof alone leaves this gate pending |
| G5 — Transaction integrity | eng / BFF+QA | Ordered authorize/persist/save proof; no-save persistence; existing-owner reuse; duplicate/concurrent requests and all recovery boundaries verified; no false paid/saved/sent status |
| G6 — Dark and isolated | eng / UI+BFF | Server and UI gates fail closed; production rejects mocks; existing signup/guest/session flows remain green; no legacy fallback for pass payment |
| G7 — Quality | eng / UI+BFF+QA | Full lint/build/suites pass; UI ≥80% lines/statements; BFF ≥84% lines/statements and ≥67% branches/functions; no lowered thresholds |
| G8 — Operable local delivery | telemetry / BFF+QA | Script deterministic, adapter modes visible, faults reproducible, metrics/traces redacted, local limitations and pending upstream handoffs recorded |

**Completion vocabulary:** G0–G8 pass = sprint implementation complete with the documented adapter coverage. If sandbox access prevents G4, report “mock demo complete; sandbox hosted collection unverified,” leaving G4 and sprint acceptance pending. Passing these gates does not authorize production enablement or establish that absent upstream features work.

### Real-service enablement gates — registered separately

| Gate | Owner | Required evidence |
|---|---|---|
| L1 — Identity/OTP | IDENTITY+SECURITY | Real club-scoped lookup, duplicate policy, secondary-contact handling, provider delivery/verify, abuse limits, contact-reassignment policy, authenticated UUID provenance |
| L2 — Charge/sale/issue | PAYMENTS+PASS/DELIVERY | Token-to-PG and stored-card payment proven without agreement; exact authorization/capture/void/refund semantics; server price/tax/date; redeemable pass and delivery status; reconciliation exercised |
| L3 — Wallet readiness | WALLET | Current deployed G8 hardening and prospect-safe event handling; no harmful member-lane event path; supported member-owned read/charge without agreement roles; required scopes and tenant controls |
| L4 — Durability/operations | PLATFORM+BFF | Shared atomic session/rate-limit store; durable purchase journal and reconciliation ownership; restart/multi-instance recovery; token retention and rotation; production config defaults off |
| L5 — Product claims | PRODUCT+DESIGN | Approved club terms/save wording, catalog/eligibility/member policy, app destinations; prove app/desk reuse before showing unconditional cross-channel claims; lifecycle risks reviewed with backend owners |

No live card saving is enabled solely because owner/entry creation succeeds. The sibling backend plan explicitly calls out read-path, conversion, consent, and retention gaps; UI copy cannot close them. Deferred lifecycle, POS/app implementation, multi-day catalog, and remember-me work remain outside sprint acceptance and have explicit triggers in the readiness register.

## Risks & Mitigations

| Risk | Mitigation / proof |
|---|---|
| Prototype success is mistaken for a live contract | Explicit adapter capability report; SDK sandbox gate; distinct local/live evidence and truthful mock labels |
| Existing Pay Page tokenization assumed to charge or to yield a reusable PG token | A2 verifies both contracts; separate authorization/finalization state; unsupported live mode fails closed |
| Generic Pay Page routes bypass new pass checks | Shared browser ownership registry on all create/poll/close; unknown sessions fail closed; existing signup regression coverage |
| Multiple people share a contact or second contact collides | Explicit ambiguity/conflict; no heuristic selection or automatic merge; prove possession before exposing existing identity |
| OTP swapping, replay, brute force, or enumeration | Atomic challenge invalidation, bounded attempts/expiry, layered limits, minimal prototype-required disclosure, no alternate-address leakage |
| In-memory state loses money or double-charges after restart | Memory only for mock traffic; durable atomic store/reconciliation mandatory for live mode |
| Wallet helper re-homes owner or token conflicts cross owners | Tenant/location validation before read/write, exact member owner resolution, no last4-based dedup or ownership transfer |
| Save fails after successful payment | Independent wallet status and wallet-only retry; valid prospect/card history preserved; no false save claim |
| Captured payment without issued pass | Durable issuance retry and compensation, status reference, manual reconciliation owner; no second charge |
| Wrong timezone or changed price/terms | Server club-local calendar validation, versioned quotes/consents, integer money, reaccept on revision |
| New route inherits signup initialization or global CSS | Dedicated shell and scoped tokens; existing signup/guest visual and behavior tests |
| Static flags depend on untrusted or missing club state | Resolve server club first, explicit normalized context, API recheck, fail closed on lookup/LD errors |
| Required DataTrak fields exceed prototype profile | A2 field mapping gate; do not fabricate personal data or silently expand the form; contract handoff blocks live adapter |
| Cross-channel/lifecycle behavior remains incomplete elsewhere | L3/L5 readiness gates; preserve external member identity; no claims based only on a mock saved entry |
| Existing tracking captures contact or payment state | Pass-specific initialization, sanitized analytics/events, no OTP/token/request-body logging; test log redaction and inspect browser network |
| Scope exceeds one sprint's staffing | Commit all prototype paths against adapters first; record live handoffs explicitly; do not remove OTP, hosted fields, identity rules, failure behavior, or tests to claim completion |

## Dependencies

- **Local toolchain:** installed private npm dependencies; UI React 17/TypeScript/Redux Toolkit/MUI v4/webpack 5 and Pay Page SDK; BFF Node ≥22/npm ≥10, Koa/TypeScript/Jest/AJV. Artifactory access if installations become necessary. Existing scripts and coverage configurations are the baseline.
- **Local run:** BFF :3000 and UI :3001, `OJ_UI_URL`, approved runtime settings. The deterministic mock flow must not require a live MICO, Oracle, Kafka, SMS, or email service. Pay Page sandbox is a separate required hosted-collection validation dependency.
- **External contracts:** club catalog/timezone/terms, identity lookup/prospect persistence and optional contact semantics, OTP provider, wallet auth/scopes, payment-gateway token/charge/refund APIs, POS sale/issuance/delivery and status inquiry. Names and response examples are due at A2; unverified dependencies remain explicit blockers.
- **Backend alignment:** sibling `S/../sprints/SPRINT-0001.md` and wallet plan establish identity direction, not rollout readiness. Confirm actual deployed dedup/prospect-sync versions and checkout read path before real wallet traffic; do not change their code or status here.
- **Production infrastructure:** durable shared checkout/purchase storage, secrets, approved origins, provider credentials, allowlisted club flag, redacted observability and reconciliation owner. Choose persistence technology based on demonstrated platform availability rather than assuming a toolkit session store or Redis deployment exists.
- **Product/design:** final club catalog, member eligibility, duplicate-contact treatment, terms/stored-credential wording, card source labels, app/navigation destinations, delivery and refund policy. Prototype placeholders supply demo values only.

## Open Questions

### Proposed defaults to review with this draft

| Decision | Proposed answer |
|---|---|
| Entry route | `/signup/day-pass?club=NNNNN`; independent shell, existing basename |
| Design implementation | Scoped SCSS tokens and small React compositions; MUI Dialog/hosted embed reused; no new shared design package |
| Date picker | Required, initially blank, club-local minimum today; one-day product with duration-friendly DTO |
| Session | Opaque short-lived server session; top-level checkout; fresh verification on Start again; remember-me deferred |
| Multiple candidates | Ambiguous/help state; never select arbitrarily or create a duplicate as “new” |
| Existing member | Permit purchase only when catalog eligibility explicitly allows it; preserve MEMBER lifecycle/wallet metadata; demo covers an eligible member |
| Product source | Adapter-owned catalog; deterministic per-club fixtures locally; no production fixture pricing |
| Diagnostics | Drop browser event-log panel; use redacted server traces/test outbox |
| Read mechanism | MEMBER owner associations; no agreement-role assignments or RCM account creation |

### Decisions needed before dependent live work

| Question | Owner slot / deadline | Effect if unanswered |
|---|---|---|
| Which service owns contact lookup, duplicates and idempotent prospect creation, and can it accept only name + contacts? | IDENTITY / A2 | Mock identity only |
| Which SMS/email provider supports this challenge flow; what normalization, reassigned-contact and secondary-contact policy applies? | IDENTITY+SECURITY / A2 | Mock verification only |
| Does Pay Page output map directly to UW `pgToken`, and can the token authorize before a person exists? How are stored cards charged without agreement/AccountInfoID assumptions? | PAYMENTS+WALLET / A2 | No live authorization or saving |
| Does POS sale capture an authorization, perform its own charge, or require a separate settlement call? Which status/void/refund APIs make retries safe? | PAYMENTS+PASS / A2 | No live sale/finalization |
| What generates a redeemable credential and delivers it, and can issuance be retried independently? | PASS/DELIVERY / before C5 live adapter | Mock pass/outbox only |
| Which catalog, tax, timezone, date horizon, terms version, and member eligibility rules apply per club? | PRODUCT+PASS / before C1 live adapter | Fixture catalog only |
| Which wallet club flags and deployed prospect-lane/read-path guarantees are required, and is MEMBER user creation needed by the payment consumer? | WALLET / before C4 live adapter | No live wallet traffic; never invent assignment tags |
| What consent evidence/template and token-retention/retry policy apply without an agreement? | PRODUCT+WALLET+PAYMENTS / before live saving | Save remains simulated |
| Which shared store provides atomic limits and durable purchase recovery; who owns unresolved transactions after browser/session loss? | PLATFORM+BFF / before L4 | Live mode unavailable |
| What are the valid Class/Membership/Visit, location and app links; is embedded checkout required in v1? | PRODUCT+DESIGN / before G2 | Document deviations; no dead controls or insecure payment fallback |
| Which named people own acceptance, and what is the sprint calendar/staffing? | Sprint lead / kickoff | Estimates remain effort ranges; gates cannot be signed off |

Each answer is recorded with owner, date, schema/example evidence, and affected gate in `BFF/docs/short-term-pass-contract.md`. Unanswered external questions do not prevent building the complete local flow; they do prevent claiming the corresponding live capability.
