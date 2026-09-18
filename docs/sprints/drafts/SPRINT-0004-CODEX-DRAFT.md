# Sprint 0004: Guest Pass v1 — DT catalog, purchase-time access, and DT credential delivery

**Status:** CODEX draft, 2026-09-17; recommendations for the planning interview, not a record of approved architecture or completed integration.
**Inputs:** `SPRINT-0004-INTENT.md`; `docs/prd/Consolidated_PRD_v3.6.md` (Decision log Rounds 5–7, §4.6, §9); `Change_Requests_2026-09-10_v3.md`; `Next_Steps_2026-09-10_v2.md`; `day-passv6.html`, diffed against `day-passv4.html`. Earlier evidence: Sprints 0001–0003, contract v3, PRD v3.4 and `Change_Requests_2026-09-15.md`.
**Chapter:** none; no chapter link selected in the intent.
**Duration and ownership:** 1–2 weeks; BFF lane (Mark), UI lane (Bjorn), orchestrator integration/proof; Chancy owns DT, Terry Smith owns DBA changes, PK reviews DT/operational assumptions, Kelly owns product/legal escalation. Estimates below are planning ranges, not commitments from those owners.
**Path shorthand:** `BFF/` = `repos/online-join-bff/src/`; `STP/` = `BFF/services/shortTermPass/`; `UI/` = `repos/online-join-ui/src/`; `UI-T/` = `repos/online-join-ui/__tests__/`. Documentation paths are relative to this planning repository. Proposed new files are explicitly marked NEW.

## Pyramid Index

- **L0:** Reconcile the shipped v3 checkout with Rounds 5–7: sell DT-flagged products through a standalone Guest Pass surface, derive dates/visits at purchase, create or repaint the prospect before payment and deactivate on failure, and leave QR generation and credential email entirely to DT.
- **L1:**
  - **A — Decisions and contract.** New requirements supersede the Sprint 0003 inputs; retire cancelled credential paths; recommend keeping React/Koa in the existing repos with a standalone deployment, and a read-only Oracle catalog adapter. Freeze contract v4 and external operation contracts before lane work.
  - **B — BFF.** DT-sourced products, terms and waiver; server-owned validity; create/update → authorize → consented wallet save → sale/capture; idempotent deactivate recovery, explicit uncertain outcomes, and DT delivery status without a web credential.
  - **C — UI.** v6 layout with one configured single-visit product, no picker or age gate, optional legal opt-in modal, OTP expiry display, returning-card fallback, receipt and truthful email-only success states.
  - **D/E — Integration and proof.** Standalone origin, cookie/CSRF/Pay Page/Cloudflare checks; local failure matrix and dev browser smoke; distinct pilot gates for Oracle, live adapters, scanner, webhook propagation and maintenance server.
- **L2:** [Overview](#overview) (precedence and reconciliation); [Use Cases](#use-cases); [Architecture](#architecture) (home, read path, v4, purchase recovery, consent, delivery); [Implementation Plan](#implementation-plan) (A–E); [Files Summary](#files-summary); [Definition of Done](#definition-of-done); [Risks & Mitigations](#risks--mitigations); [Dependencies](#dependencies); [Open Questions](#open-questions).

## Overview

Sprint 0003 delivered useful checkout and receipt infrastructure, but its multi-day/date-picker and BFF credential model are no longer the v1 product. The four new inputs win by explicit direction in the intent, irrespective of their September 10 filenames. Within those inputs, later decisions D70–D74 override earlier rounds and stale journey prose; the PRD governs behavior where the HTML is still a demonstration. Traceability must qualify identifiers by source: for example, September 15 CR-11 means multi-day validity, whereas CR-v3 CR-11 is the cancelled BFF QR renderer. Never overwrite historical acceptance evidence to make old work appear unimplemented or newly compliant.

This sprint delivers a reviewable v4 implementation in the existing UI and BFF, deterministic mocks for the external DT operations, an isolated direct-DT catalog read adapter, and deployment/proof instructions for a standalone Guest Pass origin. Real transactions remain gated on contracts and access from the owning teams. The current deployed dev service uses mock identity/prospect/payment/sale adapters: a working browser flow there is not evidence of a DT record, charge, credential email, or admission.

### Orientation and semantic prior art

- Sprint 0001 established typed ports, opaque `OJ-PASS-SESSION`, server-owned checkout/payment data, Pay Page capture, synchronous purchase checkpoints and mock fixtures. Sprint 0002 added inline email OTP, §4.5 consent evidence, wallet save, mail transports and hooks. Sprint 0003 added offer selection, range-bound consent, immutable receipt, credential store, QR mail and public pass routes. Preserve the trust boundary and receipt model, change the product semantics.
- Read `docs/SEMANTIC-INDEX.md` and the external entrypoint `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/README.md`; followed `themes/identity-by-member-id.md` → `repos/universal-wallet/identity/owner.md`, and `themes/dt-to-wallet-sync.md` → `repos/wallet-account-sync/datatrak-management-config/datatrak-data-access.md`. The index covers the wallet stack only; it is not an index of OJ or MICO.
- Opened cited source and searched narrowly: wallet `owner/entity/WalletEntryOwner.java:27` defines immutable UUID external identity; `owner/validator/WalletEntryOwnerValidator.java:39` validates external-ID/type uniqueness and location, not an agreement. Keep wallet identity `(member UUID, MEMBER, organization)`; never key by `PROSP`, barcode, email or catalog item.
- Wallet-account-sync `datatrak/member/repository/MemberRepository.java:50,60,99` still contains the legacy `PROSP`/`PROSPECT` exclusions. The same file now also has `isProspect` and prospect backfill queries at approximately lines 105–118. Thus “all sync excludes prospects” is too broad: a separate prospect lane exists, but normal member selection is not a catalog service. Its Oracle SQL/VPD discipline is prior art, not a reason to make checkout depend on the sync daemon. `docs/prd/concerns.txt` records unresolved prospect classification/metadata/flag/retry review; a successful wallet API write alone does not prove DT/POS propagation.
- Local code contradicts two tempting assumptions. `STP/adapters/platform/catalog.ts` reads MICO `club/getClub` but returns `FIXTURE_OFFER` and defaults timezone to America/Chicago. MICO `repository/WsClubDefaults.java` uses `oraSvcRestTemplate`/DT service endpoints, and `WSProspect.java:27` calls `orasvcClient.addProspect`; these inspected classes do not supply a ready-made direct Oracle catalog query. SQL schema, grants and connectivity remain dependencies.
- Local checkout branches inspected: BFF `fix/stp-cookie-secure-behind-ingress`, UI `prospect-wallet/sprint-0003`; these are source observations, not a fresh audit of deployed main. `STP/challenge.ts:11,16` still sets **10 minutes and 5 sends/address/hour**, contradicting the intent's 5-minute/2-send description. B6 must change these constants and their tests to D58/D59, then verify the deployed version.
- `InlineCodeEntry.tsx` already has `inputMode="numeric"`; its displayed timer is resend cooldown, not visibly a five-minute expiry countdown. Verify CR-30 in the actual build and add the missing expiry display if still absent. Do not count “Done” in the request list as implementation proof.

### Sprint 0003 reconciliation — position on intent question 1

**Recommendation: remove cancelled runtime capabilities, retain reusable infrastructure, and keep historical code in Git rather than shipping a second credential implementation behind flags.** No v1 flag may re-enable a web QR. Multi-offer layout remains reusable; contract days describe the redemption window independently of visits.

| Sprint 0003 capability | Disposition | Concrete change / reason |
|---|---|---|
| Offer grid and selection | **Keep** | `OfferCards`, `OfferCard`, `PUT /checkouts/:id/offer`, `selectedOfferId`, generation checks. Feed flagged products; one product per v1 fixture/pilot; no d1/d3/d5 price ladder. |
| Multi-day range as product entitlement | **Remove from v1** | Replace `durationDays` with `contractDays` and `numberOfVisits` in catalog/order/contracts; keep calendar arithmetic in `validity.ts`. A multi-calendar-day window for one use is not permission to sell a multi-visit pass. |
| Future date picker / `maxDaysAhead` | **Remove** | `OrderSummary`, `format.ts`, request schema, `order.ts`, consent templates and fixtures; reject client `visitDate` in v4. |
| Pass page and on-page credential | **Remove** | `PassViewPage`, `PassCredential`, `PAGES.passView`, App branch, `getPassView`, pass-link thunks. Retired URLs return a generic unavailable response, never a QR or a redirect with token. |
| BFF public QR/link APIs | **Remove** | Unmount `passes.ts`, purchase pass-link GET/POST, revoke hook; remove `passCredentials.ts`, `passView.ts`, `qr.ts`, credential port/store and obsolete decode tests. Retain useful redaction/header protections for old URL requests. |
| BFF pass email | **Remove** | Retire `passEmail.ts`, CID/hosted QR delivery branches and `STP2` issuance. SMTP/publisher still send OTP. DT alone renders and sends the credential. |
| 18+ attestation | **Remove** | `ConsentBlock`, `OrderRequest`, order/purchase validation and new consent snapshots. Historical snapshots remain historical evidence; do not rewrite them or auto-attest adults. |
| Receipt | **Keep, adapt** | `receipt.ts`, `PassReceipt`, `OrderSummary`, `DoneStep`: immutable price/item/payment/date/visits; no pass URL or barcode. DT/POS receipt mail remains external. |
| Session, OTP, Pay Page, wallet save | **Keep** | Existing ownership, CSRF, generation, email verification, capture-session purpose and stored-card disclosure remain. Wallet save stays after successful authorization. |
| Credential environment keys | **Remove obsolete use** | Delete `STP_PASS_LINK_SECRET` and `STP_PASS_LINK_GRACE_HOURS` requirements and Helm/example values. Audit `STP_PUBLIC_BASE_URL`; remove if only credential mail uses it, otherwise retain only documented origin use. No unused secret required at boot. |

Alternative: keep v3 credential and multi-day modes disabled by new configuration. Estimated extra 1–2 engineering days plus ongoing dual-contract, flag-combination and security testing; it preserves a cancelled `STP2` design that is not the proposed v2 barcode/timestamp app. Git history is cheaper and less likely to leak a prohibited route. Old dev-only links need no live credential migration; verify there were no real recipients before retirement. If real recipients exist, DT/support must own continuity before removal goes live.

### Approved design deltas to propose

The v4→v6 diff removes `.dayfield`, adds the marketing dialog/control, replaces date ranges with validity/use-by text and revises done copy. It also retains `adultCb` and `S.adult` payment guards, hard-codes `VALID_DAYS = 30`, calculates expiry with `today + 30` rather than inclusive `days − 1`, retains demo multi-visit products, and changes refunds to “before the pass is first used.” These are **not** requirements to copy. Record explicit deltas: no age gate (D66); DT days/visits/prices and inclusive dates (D71/72); one configured v1 item; PRD D15/D22 refund policy pending legal; email-only auth despite prototype channel branches; no generator/debug content; truthful pending/failed delivery text. Preserve v6 typography, responsive cards, sidebar, dialog and receipt hierarchy.

## Use Cases

| ID | Behavior and expected result | Source / proof |
|---|---|---|
| U1 | Guest Pass flag off or club unknown → unavailable; flagged catalog absent → no payable offer; existing membership/trial behavior unchanged. Direct API cannot bypass the gate. | CR-20/23/27; B1, D1 |
| U2 | Identify and code-entry show the club's flagged product and real amount; v1 clubs have one single-visit product. Selection infrastructure supports lists without manufacturing items/prices. | CR-28; B2, C1 |
| U3 | Valid email receives generic OTP response before lookup; numeric input, six digits, five-minute expiry, resend cooldown and 2 sends/address/hour across checkouts; changing email is available without itself sending a code. | CR-05/10/13/29/30; B6, C2 |
| U4 | First-time buyer supplies first/last/email/mobile, hosted card, required waiver and Pay acceptance. No adult checkbox, DOB or date field; no saved-card dropdown. | CR-03/04/26/35; C3 |
| U5 | Legal marketing control defaults unchecked; checked and unchecked purchases both succeed; modal open/close does not opt in; exact displayed text, revision, state and time retained; explicit false reaches prospect create/update. | CR-09; B3, C3 |
| U6 | Returning buyer retains verified UUID, re-accepts current terms/waiver, and has the same prospect repainted with purchase dates/visits. No duplicate identity or extension of previous expiration. | CR-12/14; B4, C4 |
| U7 | Expired saved card is not chargeable; “Use a different card” opens Pay Page, captures a new owned token and respects save off/on. Server also refuses expired saved cards. | CR-15; B4, C4 |
| U8 | Contract days 1 gives begin = use-by = club-local purchase date; a synthetic 7-day window/one visit ends six calendar days later. Browser timezone/DST cannot change it. No 30-day constant. | D48/71/72; B2/B3 |
| U9 | Midnight or changed price/terms between render and Pay returns 409 with refreshed order/consent before prospect mutation or auth; buyer reviews and taps Pay again. | Contract v4; B3 |
| U10 | Success: prospect create/repaint precedes authorization; save occurs only after successful auth and opt-in to save; sale/capture confirmed; DT delivery requested/observed without BFF QR. Immutable receipt survives reload. | CR-06/12/19/24/25/32; B4/B5 |
| U11 | Definite decline → deactivate affected prospect through supported DT operation; no wallet save, sale, credential request, or charge retry under the old key. UI offers retry only after compensation is confirmed. | CR-32; B4 |
| U12 | Deactivate fails or times out → RECONCILING, safe message and reference, no second Pay; bounded compensation retry uses same mutation identity. No silent successful decline handling. | D65, PR-14; B4/E1 |
| U13 | Unknown create/auth/capture outcome → resolve by operation reference, never blindly recreate/recharge/deactivate a possibly successful sale. Duplicate clicks and same-key replay produce one operation set. | Purchase recovery; B4/E1 |
| U14 | Wallet failure after authorization does not resell/recharge; wallet-only retry uses same providedId and consent. Save off produces no new wallet write. | CR-06; B4 |
| U15 | Done shows “We've emailed your QR code for club access” only for confirmed sent status; pending/unknown/failed states are truthful. No QR, barcode, pass link or BFF resend action in API or DOM. | CR-25, D63; B5/C5 |
| U16 | Old `/signup/pass/:token`, `/passes/:token`, image and pass-link paths cannot produce credentials; tokens absent from logs and error bodies. | Reconciliation; B1/C5/E1 |
| U17 | Wrong VPD/club, foreign offer, stale generation, unverified contact, non-owned capture or card, altered server fields → refusal before side effects. Active/frozen/past-due/banned member paths remain blocked. | Existing trust boundary; B2–B4 |
| U18 | Dev browser on deployed HTTPS uses pinned OTP and real Pay Page sandbox capture if available; test endpoints remain inaccessible from ingress. Successful mock transaction is labelled mock proof in the report. | E2 |
| U19 | Pilot emailed DT QR admits once within dates, refuses second visit and expired record; failed purchase deactivate reaches all CRM destinations; maintenance server and baselines verified. | PR-06/07/14, Next Steps 8–12; E4 |

## Architecture

### 1. Home and deployment — position on intent question 2

**Recommend existing React/Koa repos, independently surfaced at a new standalone Guest Pass host with canonical `/guest-pass?club=NNNNN`.** Keep `ShortTermPass` internal module names and `/api/short-term-pass` for this sprint; a branding rename is not a rewrite. Guest Pass must render outside the membership `SignupShell` and have its own ingress/host configuration and product flag. The consumer URL must not require `/signup` or a membership plan. This satisfies the standalone product separation, but is an explicit proposed interpretation of D60's “fork off Myko”; CF-11/Bjorn must settle repo home before production routing.

Reuse the existing artifacts initially with a separate deployment configuration. Route static UI and BFF API through the same origin to preserve host-only cookie/CSRF behavior. Add host/path values to the existing Helm chart or a separate release using that chart; validate chart support in A1 rather than assume a second `hosts` entry creates an isolated deployment. Configure DNS/TLS, UI asset base/history fallback, origin allowlist, Pay Page callback/allowed origins, runtime flag injection, CSP, trusted proxy/secure cookies and Cloudflare rules for the exact new host/API paths. Retain the ingress secure-cookie fix from BFF #106. Test direct navigation/reload and prevent a retired pass token path from falling through to checkout.

Keep `OJ-PASS-SESSION` as an internal cookie name this sprint, host-only and with a path covering `/guest-pass` and the API; changing names adds no product value. Do not share checkout cookies across OJ and the standalone domain. During rollout, an old checkout URL may redirect to the canonical host before checkout starts; an active checkout on another host must restart explicitly rather than silently lose session ownership. Pilot is a top-level club-site link; iframe embedding is a separate cookie/CSP/Pay Page proof and is not assumed to work.

Estimate: 1–2 days UI/BFF routing/config plus 1–2 platform days for host/TLS/Cloudflare/Pay Page proof, overlapping lane work. A literal MICO fork costs approximately 4–7 engineering days for application packaging, controller/session/CSRF/OTP/payment adaptation and regression proof, plus platform work. Reusing React assets inside MICO could reduce UI work but still introduces dual packaging/routing and does not magically provide the new catalog columns. Reimplementing in legacy webapp is not sprint-sized. React/Koa is the smaller reusable retail shell toward “new OJ”; membership unification is not part of this sprint.

If CF-11 is unanswered, implement host-independent modules and `/guest-pass` in the existing repos, prove the flow on the existing dev origin, and prepare proposed Helm changes. Record standalone rollout as pending; do not call the existing `/signup/day-pass` deployment D60-complete or fork another application speculatively.

### 2. DT read path — position on intent question 3

**Recommend a read-only Oracle adapter owned by the BFF behind `ClubCatalogPort`, with an explicit mock mode until DBA schema/access are ready.** This follows D64/CR-31's literal no-enterprise-API-change requirement and avoids adding checkout catalog responsibility to wallet-account-sync. Direct DB reads are server-side only. Prospect writes remain supported DT APIs so business rules and webhooks run; no direct SQL prospect mutations.

New `STP/adapters/oracle/{catalog,queries,rowMapping,pool}.ts` contains a minimal driver boundary and typed mapping. A1 time-box: confirm actual product flag/days/visits columns, price/tax source, waiver source, club timezone, VPD predicate/session context, account grants, Oracle version and approved Node driver/runtime mode. Do not invent table names from prose. Parameterized reads scope both VPD and club; pool acquisition/query timeouts and resource cleanup are mandatory. If session VPD context is used, set and clear it per borrowed connection and test no cross-tenant reuse. Read-only least-privilege credentials live in platform secret references, never browser config or source. Select only checkout fields. Sanitize club-authored HTML with an explicit allowlist before rendering; hash the rendered content users actually see.

Use a short, documented per-VPD/club catalog cache (proposed 60 seconds), invalidate/re-read authoritative commercial/config data before side effects. A change returns a refreshed 409, never a silent reprice. Flag evaluation still fails closed. Missing columns, unknown timezone, invalid days/visits/price or unavailable database must fail closed in platform mode; never fall back to fixture prices or free-trial defaults. Separate capability reporting for club branding, product/price, consent and timezone avoids the existing misleading aggregate `live` label.

A product is `{offerId, catalogItemId, type:'product', guestPassOnline, name, amountMinor, currency, contractDays, numberOfVisits, sourceRevision}`. The browser sees only eligible product summaries. Terms/waiver and a source revision join a consistent server snapshot. Fixtures: 90030 Riverside USD 18, 90033 Core South USD 25, each one flagged product with contractDays=1 and visits=1; Kelly/Jordan retained. Add isolated tests for unflagged items, list selection, missing/malformed fields, no offerings and a 7-day/1-visit window. Those test windows prove arithmetic, not approval to configure a multi-day pilot. List every flagged item; deployment validation requires the v1 one-item/one-visit configuration, and purchase refuses unsupported multi-visit settings instead of silently coercing visits to 1.

Cost: direct Oracle ~2–3 BFF days once schema/access exist, plus uncertain DBA/network lead time. **Alternative small MICO/DT endpoint:** ~1–2 days for an owning-service mapping/controller plus 0.5–1 BFF day and a second deployment, if an approved DT read API already exposes all fields. It avoids a new BFF DB dependency and is the preferred fallback if infrastructure refuses Oracle, but is a recorded deviation from literal direct-BFF reads requiring A1 decision; an enterprise API expansion conflicts with CR-31 and is not assumed. **Wallet-account-sync:** no suitable catalog endpoint was found; adding one would couple checkout to a sync service, introduce ownership/deployment work (roughly 2–4 days), and still require DBA schema. Do not use it as a shortcut.

Feasible today: fixtures and adapter query/mapping tests. A live Oracle read is **unproven** until a lower-environment query succeeds under the correct VPD. Lack of columns does not stop UI or mock completion; it does stop live catalog/pilot claims.

### 3. Contract v4 and server-owned dates

Freeze `docs/contracts/short-term-pass-bff.md` and mirrored BFF/UI schemas in A2. Keep route names and error envelope where possible, but explicitly version checkout snapshots. Incompatible active v3 checkouts restart with a clear response; completed v3 results remain read-only historical receipts if retained. Deploy BFF/UI together under the disabled flag, with a contract-version mismatch guard for cached older bundles. Do not silently accept future-date or adult-attestation fields from stale clients.

| Surface | v4 decision |
|---|---|
| Checkout/offers | `contractVersion:4`, `offers[]`, `selectedOfferId`; offer `{offerId,name,label,amountMinor,currency,contractDays,numberOfVisits}`. Label comes from the item, not a “N-day pass” inference. Remove `durationDays`/`maxDaysAhead`; preserve selection races/generation rules. |
| `PUT /checkouts/:id/offer` | Keep `{offerId,generation}` and pre-order lifecycle. Resolve only this club's eligible catalog item; no silent fallback. List architecture is retained even with one v1 product. |
| Order request | Keep save-card, marketing choice, required waiver and profile fields; remove writable `visitDate` and `adult`. No client days, visits, amount, member ID or wallet token. |
| Order response | Server `beginDate`, `expirationDate`, `contractDays`, `numberOfVisits`, price, consent revision and `generation`. Pre-pay dates are a quote, confirmed again at Pay. `canPay` excludes adult/date-input requirements. |
| Purchase | Owned capture reference or owned saved-card selection, idempotency key, generation and attestation. Freeze effective dates before first prospect mutation and preserve them on replay. |
| Receipt | Immutable catalog identity/name, amount/currency, begin/expiration, visits, paid-at, receipt number, seller and masked card. No web credential or pass-link fields. |
| Result | Payment/sale/wallet/DT-delivery outcomes plus prospect mutation/compensation status safe for the buyer; no barcode, `qrPayload`, `viewPath`, raw token or internal IDs. Owner-only status lookup remains. |
| Removed endpoints | Public pass JSON/PNG, owner pass-link GET/POST and test revoke route return generic 404; no content negotiation path can resurrect QR. |

Dates are club-local calendar dates: `beginDate = localDate(purchaseInstant, club.timezone)`, `expirationDate = addCalendarDays(beginDate, contractDays - 1)`. For 1 day: “You have 1 day to use this pass”, “One time use only”, “Use by {today's absolute club-local date}.” For N: use the item's N and inclusive date; never browser-local `new Date()+N`. At midnight, refresh and re-accept changed commercial consent before creating/repainting the prospect; once started, an idempotent replay retains the original purchase instant. Tests cover DST, month/year boundaries and browser zones.

### 4. Prospect and payment orchestration

Current `purchaseOrchestrator.ts` does authorize → persist person → wallet → sale/capture → issue → mint → deliver. New sequence:

```text
validate verified identity, eligibility, owned payment source, catalog and consent
  → reserve idempotent purchase + one consent snapshot
  → create new / repaint existing DT prospect (begin, expiration, visits, opt-in, item, payment token reference)
  → authorize against that prospect
  → save card only if auth succeeded AND save-card consent is on
  → finalize product sale + confirm capture
  → record immutable receipt + DT fulfillment/delivery acknowledgement
  → COMPLETE (delivery may still be pending/failed)
```

Remove synthetic pass issuance/minting from the success criterion. DT prospect fields are access; POS item is the financial sale. Keep sale/capture compensation and uncertain-outcome handling, adapting it to the now-earlier prospect mutation.

**Internal proposed operation shape** (logical contract, not a claim that these upstream wire names exist):

```ts
PrepareGuestPassInput = {
  purchaseId, operationKey, clubNumber, verifiedMemberId?,
  firstName, lastName, email, mobile,
  catalogItemId, beginDate, expirationDate, numberOfVisits,
  marketingOptIn: boolean,
  paymentTokenReference, // resolved by BFF from owned capture/card, never browser input
  acknowledgements: { passTerms, waiver?, marketing, privacy, storedCard? }
}
PrepareGuestPassResult = {
  memberId, homeClub, mutationId, created, revision,
  delivery: 'not-requested' | 'pending' | 'sent' | 'failed' | 'unknown'
}
```

Extend `ProspectPort` with explicit create/update, operation lookup and deactivate semantics. Map to real DT field names in the adapter once Mark/Chancy supply the API contract. The create call's token is for linking the transaction; passing it must not implicitly save a card before authorization. Validate that upstream behavior. New visitor gets a new UUID; verified returning buyer repaints only the club-scoped prospect on the bound identity. Never treat a contact conflict as authentication, and never overwrite club default trial days/visits. Existing active-pass extension is not implemented.

| Outcome | Required recovery and visible result |
|---|---|
| Validation/contact conflict before create | No payment. Re-verify for conflicting identity; no binding from an untrusted create response. |
| Create/update definite failure | No authorization; retry only if no mutation occurred. |
| Create response lost | Lookup by operation key; reuse found member/mutation. If unresolved, RECONCILING and no fresh create/auth. |
| Authorization declined / confirmed not charged | Deactivate through DT business API with stable key `{purchaseId}:deactivate`; no wallet save or sale. Finish FAILED only after compensation confirmed. |
| Deactivate failure/timeout | Record `DEACTIVATION_PENDING`, bounded retry (one immediate retry), then RECONCILING. Owner status route reports safe state. Operator resumes only this step by operation key; no create/pay replay. |
| Authorization timeout/throw/unknown | Query payment status by stable reference, including thrown transport errors (current throw path needs tightening). If unresolved, freeze RECONCILING; never claim “not charged” or blindly deactivate a possibly paid pass. |
| Wallet save failure after confirmed auth | Record retryable wallet outcome, continue sale; same providedId on wallet-only retry, no new charge or DT mutation. Recheck auth/consent before allowing that retry. |
| Sale failure before capture | Void auth, deactivate prepared prospect; unknown void or deactivate → RECONCILING. |
| Capture unknown after sale | Resolve provider/sale status. No second sale/capture and no success credential claim until confirmed. If irrecoverably failed, compensate with the supported DT/payment operations. |
| Confirmed payment, DT email failure | Keep paid receipt, truthful delivery status and desk fallback; no refund/recharge just for email. No BFF credential generation fallback. |
| Replay/concurrent request | Same key + fingerprint → same operation/result; different body → conflict. Keep unresolved purchase as a block on a new purchase for the affected checkout/person/club. |

For a returning prospect, deactivation must be scoped to the prepared mutation/revision, not blindly deactivate a member after a later purchase or membership conversion. Test two checkouts on the same identity and a late compensation. If upstream lacks conditional mutation support, serialized per-person/club execution plus a status/version check is required for live enablement; process-local serialization proves only mock behavior. Repainting an existing active pass and deactivating it on decline may destroy previous access: exclude that overlapping-active-pass case from pilot until Mark/Chancy/Kelly approve restoration or refusal behavior. Do not silently invent extension/refund semantics.

D65 “attempts logged, not persisted” means no new business table/report for failed attempts; it cannot safely mean deleting idempotency/compensation state. Keep minimal operational checkpoints in the existing purchase store and sanitized structured logs, plus required consent evidence. No PAN/CVV, raw token, OTP, full email/mobile or legal paragraph in ordinary logs. Persisting operational recovery/consent in production remains an explicit readiness dependency; in-memory mock stores cannot recover across restarts or pods. Do not claim exactly-once live behavior until durable state and upstream idempotency/status contracts are proven. No new durable-storage subsystem is smuggled into this sprint's two-lane estimate.

### 5. Consent, OTP and DT email ownership

Add marketing as a dialog-capable document while retaining a distinct optional notice/boolean. One control in the right sidebar for both lanes; remove the older duplicate near the profile fields. Use the legal-provided text, parameterized only with approved club identity; v6's hard-coded “Core South” is fixture text. Modal supports mobile scrolling, labelled title, keyboard focus trap/Escape/return; opening is evidence of availability, not acceptance. Inline full-text presentation is the documented fallback for CF-09. Missing legal approval allows PROPOSED dev content with status recorded in fixtures/reports; it does not imply pilot SMS approval.

Consent snapshots retain exact rendered text or a durable immutable text reference, hash/version, explicit opt-in/opt-out, capture time and existing privacy-preserving actor context. Bind revision to catalog item, price/currency, begin/expiration, visits and rendered documents. Required waiver and Pass Terms are re-presented on every purchase; retain per-purchase evidence without building once-per-club waiver-version state. Remove adult from new snapshots and guards, including API validation. Pass acknowledgment text to DT through the confirmed operation mapping, not through wallet metadata.

OTP uses Chancy's template with escaped club name and server-injected code. Until it arrives, adapt `adapters/smtp/templates/verificationCode.ts` as PROPOSED with the same variable interface and use it from SMTP/publisher. Do not carry pass credentials in these transports. Pin six digits, 300-second TTL, two sends/address/hour, existing cooldown/lockout and lookup-after-consumption; verify actual constants and tests rather than assume old sprint prose matches. Production must explicitly reject a configured mock OTP along with mock mode, clocks, hooks and flag overrides; the current guard should be audited for that exact key.

DT owns barcode QR rendering and prospect email; POS owns purchase-receipt mail. `DeliveryPort` becomes a DT delivery acknowledgement/request boundary, not a BFF renderer. Confirm whether create triggers email immediately or an explicit post-payment operation can trigger it. D52's “on create” conflicts with J1's “on success”; record actual behavior. Never add duplicate post-payment sends if DT already sends on create. A credential emailed before a decline is a pilot risk requiring proven deactivate/door propagation, not something a local mock can resolve. DT mail includes static barcode QR, dates and every applicable non-null acknowledgment, no adult line, and unmistakable subject distinct from the POS receipt.

## Implementation Plan

**Execution shape:** A contract/orientation phase precedes two concurrent implementation lanes B (BFF) and C (UI). D integrates those lanes; E is orchestrator-owned evidence. External work is tracked with owners/fallbacks, not silently absorbed. Implementation begins from current merged `main` including the cookie fix; record exact SHAs at kickoff. This document-writing task changes only this draft; the paths below are future sprint work.

### A — Contract and feasibility · 1 day · orchestrator + both lanes

| Task | Files / work | Exit evidence |
|---|---|---|
| A1 | Read current heads/config; decide CF-11 recommendation and time-box Oracle schema/access plus DT create/update/deactivate/status/email trigger contract with Mark/Chancy. Inspect existing Helm chart, `BFF/services/application.ts`, Pay Page origin requirements. No wholesale MICO scan. | Written home/read-path decision; unknown upstream fields/endpoints named as unknown, owner/date and fallback; no claim MICO already has the SQL. |
| A2 | MODIFY `docs/contracts/short-term-pass-bff.md`; freeze v4 request/response/examples, strict removals, dates, flag semantics, consent, operation table, retired routes and version rollout. Allocate CR-v3 versus September-15 namespaces. | UI/BFF agree schemas and sample fixtures; recovery states and acceptance cases reviewable. |
| A3 | MODIFY `STP/fixtures/{catalog,directory,consentTemplates}.ts`, UI `shortTermPassTestData.ts`; add expired card and failure cases, single-item fixtures, synthetic calendar fixtures. Set lane branches and baseline checks using Node 26 / `npm ci --ignore-scripts` and repo lockfiles. | Existing failure baseline recorded, fixed fixture IDs and clock; no secrets in artifacts. |

### B — BFF lane · 5–7 days, overlaps C

| Task | Files and tasks | Tests / exit |
|---|---|---|
| B1 | MODIFY `routes/shortTermPass/{index,context,schemas,purchase,checkouts}.ts`, `testing/routes.ts`, `STP/{config,flag}.ts`, `env.ts`, `.env.example`, `utils/middlewares/{requireShortTermPass,historyFallback}.ts`. Retire public pass/link/revoke APIs and credential wiring; remove obsolete files/env requirements. Introduce v4 guard and Guest Pass flag. Replace free-trial `onlineProspects` coupling with flagged-product eligibility. | Old route matrix returns no credentials; flag off/errors fail closed; `onlineProspects=false` does not wrongly disable a valid paid product; no flagged products cannot purchase; production mock-key refusal. |
| B2 | MODIFY `ports/clubCatalog.ts`, `adapters/{index,platform/catalog}.ts`; NEW Oracle adapter files described above, driver dependency/lockfile if approved. Read flagged products, price/days/visits and terms/waiver; remove platform fixture fallback/timezone guess. | Mapping/query boundary tests, correct VPD/club predicates, pooled context cleanup, timeouts, malformed/null config, zero/multiple offers, unflagged service excluded. Live read separately gated. |
| B3 | MODIFY `STP/{order,validity,receipt}.ts`, `ports/{checkoutStore,purchaseStore}.ts`, consent templates, route `order.ts` and consent events. Remove date/adult writes; date at Pay, revised commercial hash, optional marketing document/evidence, immutable receipt. | U5/U8/U9/U17; stale terms/static override, midnight, DST and client-forged dates/visits rejected before side effects. |
| B4 | MODIFY `purchaseOrchestrator.ts`, `ports/{prospect,payment,passSale,purchaseStore}.ts`, mock directory/payment/sale/store adapters; NEW `STP/prospectCompensation.ts` and corresponding platform prospect adapter when contract is available. Implement create/repaint-before-auth, conditional deactivate/status, replay and reconciliation. Keep real unresolved ports explicitly notEnabled. | Ordered-call tests and complete failure matrix U6–U14; response loss, deactivate retry, same-key replay, different-key duplicate prevention, late compensation vs newer record, expired card, no-wallet-on-decline. |
| B5 | MODIFY `ports/delivery.ts`, adapter wiring and DT/mock delivery boundary, receipt/result mappings. DELETE BFF pass-email/QR generation branches; remove unused QR packages only after import audit. Confirm DT trigger and avoid double email. | No QR/barcode/link in customer payloads or BFF mail; sent/pending/failed/unknown variants; receipt/consent replay immutable; sale/capture not repeated by delivery retry. |
| B6 | MODIFY `challenge.ts`, OTP mock/template/publisher/SMTP paths and `config.ts` as needed. Chancy template variables; change the inspected 10-minute/5-send constants to 300 seconds/2 sends per hour and pin six digits; preserve generic responses and test-hook limits. | Template escaping, club name, timer timestamps, resend across fresh cookies, wrong-code lockout, production pinned-code refusal. |

BFF sequencing: B1 schema skeleton → B2/B3 → B4 → B5; B6 fits alongside mock integration. Live DT write/payment adapters are implemented only against supplied contracts; stubbed mocks do not close live gates. If Oracle access consumes the time-box, finish typed adapter/mocks and record live proof pending rather than sacrificing recovery tests.

### C — UI lane · 4–5 days, overlaps B

| Task | Files and tasks | Tests / exit |
|---|---|---|
| C1 | MODIFY `interfaces/api/shortTermPass.ts`, `services/shortTermPass.ts`, reducer/slice/selectors, `components/{OfferCards,OfferCard,OrderSummary}.tsx`, `format.ts`. Consume v4, remove date request/state and generated duration labels, show DT days/use-by. | Selection/reload and 409 refresh; one-item responsive layout; no hard-coded VALID_DAYS; schema mismatch offers restart. |
| C2 | MODIFY `InlineCodeEntry.tsx`, `steps/IdentifyStep.tsx`; keep numeric keypad/paste, explicitly display five-minute countdown from server expiry independently of resend cooldown. | Numeric input, expiry and resend distinct; expiry survives re-render/reload without resetting; Change does not spend a send until Continue. |
| C3 | MODIFY `ConsentBlock`, `MarketingOptIn`, `DocumentDialog`, `NewVisitorStep`, `CheckoutController`, stylesheet. Remove adult/date gate; add one optional legal modal checkbox in sidebar; preserve waiver, terms, save-card position and hosted capture. | Opt-in off/on purchase; no duplicate checkbox; modal focus/scroll/keyboard; no age/date in DOM or Pay guard; profile/mobile required. |
| C4 | MODIFY `RecognizedStep`, `SavedCardChip`, capture hook/controller as required. Re-present waiver/terms, expired-card branch to Pay Page, preserve masked identity and verified-session boundary. | Returning fresh consent, expired card can't pay, different-card save off/on and capture failure/retry; no membership embed regression. |
| C5 | MODIFY `DoneStep`, `PassBlock`, `PassReceipt`, `OrderSummary`, slice/service; DELETE `PassViewPage`/`PassCredential` and pass-link operations. Keep receipt and wallet-only retry; recovery UI blocks duplicate Pay. | U12/U15/U16; no QR/link/resend, truthful pending/error copy, reload result, no duplicate purchase on retry. |
| C6 | MODIFY `App.tsx`, `common/constants.ts`, `CheckoutShell`, style and routing tests for `/guest-pass`; v6 responsive typography, single-item card collapse, no membership shell dependency. | Deep links and unavailable state; 1440/375 screenshots, 320–440 overflow, 1250/640 breakpoint checks; existing signup/trial tests. |

### D — Integration and standalone rollout preparation · 1–2 days · orchestrator

| Task | Files / work | Exit evidence |
|---|---|---|
| D1 | Proposed changes to `repos/helm-configs/online-join-bff/{default,dev}.yaml` and chart-supported standalone release values; UI asset/runtime configuration and BFF origin/history fallback. New product flag proposed `guest-pass-online`, no automatic fallback to old OJ flag; Mark provisions targeting. | Host/TLS, path, cookie and CSRF matrix; existing OJ unaffected, flag off reverts to existing behavior; old flag not sufficient to enable Guest Pass. |
| D2 | Remove retired credential env/secret references after code rollout; configure read-only DB secret references/network policy if available. Record DNS, Cloudflare, Pay Page origins and rollout/rollback order. | New host covered by rate limits/WAF before public exposure; no secret values captured. If host decision pending, existing-dev proof explicitly scoped. |
| D3 | Integrate v4 fixtures and docs; update parity input inventory to v6 with named PRD overrides, not a blind pixel target. | Both lanes build against same contract and the source exceptions above are enumerated. Full parity/agent harness remains deferred unless separately resumed. |

Rollout: disable Guest Pass flag → deploy compatible BFF/UI and config → verify dev → open standalone host only after Cloudflare/Pay Page/cookie proof → enable approved pilot clubs after live gates. Rollback first disables new checkout; continue recovery of in-flight payments/compensation under operational controls. Do not downgrade unresolved v4 state into v3 or reactivate cancelled QR routes as the rollback mechanism.

### E — Orchestrator proof and handoffs · 1–2 days

| Task | Work / artifacts | Required verdict |
|---|---|---|
| E1 | MODIFY BFF `scripts/short-term-pass-demo.ts`; local HTTP demo first-time save off/on, returning, expired card, opt-in off/on, decline/deactivate, compensation failure, unknown auth and replay. Run lane suites/lint/build, targeted security regressions. | Assert operation order/counts and server state, not just COMPLETE. Local hooks may inspect sanitized state/outbox; no fabricated DT QR. |
| E2 | NEW `docs/validation/short-term-pass-sprint-0004-smoke.md`, screenshots under `screenshots/sprint-0004/`. Browser against `https://onlinejoin.dev.abcfitness.net` and standalone dev host when ready; record versions/host/config mode. | Pinned OTP supplied through authorized dev configuration, not fetched through public testing endpoints. Use Pay Page sandbox fixture cards, no live charges; HTTPS cookie persists and mutation CSRF passes. Ingress hooks remain refused. |
| E3 | NEW `docs/validation/short-term-pass-sprint-0004-{traceability,design-notes}.md`; v6-v4 delta list; map each CR/PR/CF to task → commit → test/evidence → verdict/owner. Update contract/demo/code map and execution/blocker summaries during execution. | Every request in CR-v3 §§A–H classified implemented, verified existing, cancelled, external gate or deferred. No numeric-ID collision with Sprint 0003. |
| E4 | Write pilot runbook/checklist with named owners and prerequisites below; attach external evidence only when actually supplied. | Local/mock complete and live/pilot readiness remain separate verdicts. |

Dev smoke procedure: open fresh browser at Guest Pass route with club 90033; identify using dedicated fixture/test email; enter pinned six-digit OTP from non-production config; verify optional marketing and save off/on on new and returning lanes; complete sandbox Pay Page capture if available; inspect network result and receipt; repeat with expired saved-card fixture; refresh receipt; verify old pass URLs fail and no QR/link DOM exists; capture 1440/375 plus narrow overflow. Browser must not read `/testing/outbox`, `/testing/state` or `/testing/reset` through ingress. Local demo supplies deterministic decline/recovery faults. If hosted Pay Page credentials or sandbox capture fail, record B1 and complete local mock-capture proof separately—never flip public hooks or substitute fake capture to claim hosted proof. Pinned OTP is not proof that real OTP email arrived; a controlled publisher/template inbox check is a separate row.

Pilot procedure and owners:

1. **Chancy + Terry / PK:** deployed product columns and reviewed DT PR; correct one-item/one-visit configuration, waiver/terms, timezone, email template, LD targeting; Mark proves real catalog/identity/prospect/payment/sale adapters and durable operational state.
2. **Mark + PK/platform:** exact standalone host behind Cloudflare, safe sandbox velocity test produces limits, no bypass via API origin, required attempt logs; verify flag-off and in-flight recovery behavior.
3. **Chancy + Mark (PR-06):** purchase through the live integration in an approved test environment; inspect DT prospect date/visits and mail; scan emailed barcode QR once, repeat scan refused, separate expired-date case refused. No new scanner/verifier built here.
4. **Chancy + Kyle (PR-14):** force definite payment decline, correlate create/update and deactivate for the same member/operation, enumerate all CRM destinations receiving create, observe deactivate at each (including delayed/retried delivery); check door/maintenance state. Missing consumer acknowledgement blocks club enablement.
5. **Mark (PR-02/03/04):** simulated-user agent runs with controlled OTP mail sink, sandbox cards and isolated browser profiles before pilot. Existing harness remains deferred by the user; record this gate pending until explicitly resumed, not waived by manual smoke.
6. **Chancy + Kelly/product:** maintenance server operating (PR-07), capture baselines for 31239 and 31590 (repeat share, purchase time, prospect creation rate; thresholds set from data), product-marketing three-button handoff (trial/join/buy pass), legal approvals and operator recovery contacts.

## Files Summary

| Area | Planned actions |
|---|---|
| BFF contracts/routes | MODIFY `src/routes/shortTermPass/{schemas,index,context,checkouts,offer,order,purchase,consentEvents}.ts`, `testing/routes.ts`; DELETE credential route implementation `passes.ts`; retain explicit generic retirement behavior. |
| BFF domain | MODIFY `src/services/shortTermPass/{order,validity,receipt,purchaseOrchestrator,challenge,config,flag}.ts`; NEW `prospectCompensation.ts`; DELETE `{passCredentials,passView,qr}.ts`. |
| BFF ports/adapters | MODIFY `ports/{clubCatalog,prospect,payment,passSale,delivery,checkoutStore,purchaseStore}.ts`, adapter factory, mock directory/catalog/payment/sale/stores, platform catalog; NEW Oracle files and contract-backed platform prospect adapter; DELETE credential port/mock store and SMTP pass-email template. |
| BFF supporting code | MODIFY OTP template/SMTP/publisher paths, fixtures, `env.ts`, `.env.example`, middleware gating/history fallback, static runtime config as needed, package/lockfile after import audit, demo and affected unit/route tests. |
| UI contract/state | MODIFY `src/{interfaces/api,services,reducers/shortTermPass,selectors}/` STP files; remove credential thunks/services and date/adult state; update test factories. |
| UI screens | MODIFY `src/routes/ShortTermPass/components/{OfferCards,OfferCard,OrderSummary,ConsentBlock,MarketingOptIn,DocumentDialog,InlineCodeEntry,CheckoutController,SavedCardChip,PassBlock,PassReceipt,CheckoutShell}.tsx`, steps, `format.ts`, capture hook as needed; DELETE `PassViewPage.tsx` and `components/PassCredential.tsx`. |
| UI routing/style/tests | MODIFY `src/{App.tsx,common/constants.ts,styles/short-term-pass.scss}` and STP/App/state/service tests; remove obsolete page/QR tests and add negative credential-route tests. |
| Deployment | MODIFY Helm BFF defaults/dev and add chart-supported standalone values as decided; DB access, DNS/TLS/Cloudflare and LD configuration are owner handoffs, not presumed repository files. |
| Planning evidence | MODIFY contract, demo doc, semantic code map, parity inventories and ledger only during execution; NEW Sprint 0004 smoke/traceability/design-notes, screenshots and execution/blocker summaries. |
| External ownership | DT/catalog columns, DT mail/scanner/webhooks, wallet-account-sync fixes/backfill and MICO endpoint alternative remain owner work. No MICO/webapp or wallet-repo implementation in the recommended two lanes. |

## Definition of Done

Use Q0–Q8 for sprint gates and P0–P5 for live/pilot gates, distinct from previous G/S/T gates. An unrun check is pending, not passed. Assign actual reviewers at kickoff; role ownership here does not imply their approval.

| Gate | Owner | Passes when |
|---|---|---|
| Q0 — Reconciliation/contract | UI+BFF+product | Source precedence, capability disposition, v6 exceptions and v4 contract frozen; CF-11/home and DT path recommendation or explicit pending deployment outcome recorded. |
| Q1 — Catalog and validity | BFF+QA | Adapter/mapping/fixture tests pass; no production fixture fallback, hard-coded 30 days, writable dates or free-trial defaults; U2/U8/U9/U17; direct Oracle marked unverified until exercised. |
| Q2 — v6 flow | UI+design reviewer | U3–U7/U15 at desktop/mobile; no age/date gate; modal optional/accessibility checked; one configured item; expired-card Pay Page path; exact source deltas documented. |
| Q3 — Transaction recovery | BFF+QA | U10–U14 fault matrix, operation ordering, replay/concurrency, no wallet on failed auth, bounded deactivate recovery and no unsafe second Pay; restart limitations named. |
| Q4 — DT credential boundary | BFF+UI+QA | No QR renderer, barcode/payload/link in response/DOM/mail; retired routes negative-tested; receipt kept; DT delivery status reflects actual evidence, not request success alone. |
| Q5 — Security/regression | BFF+UI | OTP limits, ownership/VPD, CSRF/origin, flag gate, production test-settings refusal and logging tests; membership/trial routes and capture ownership unchanged. |
| Q6 — Quality | BFF+UI | Repo lint/build and tests pass without lowering floors (UI existing 80/80; BFF 84/67/67/84); pre-existing UI timezone/typecheck failures documented by name/head and no new failures. No inherited test count used as target. |
| Q7 — Integrated proof | Orchestrator+QA | Updated demo plus dev browser smoke recorded with versions/mode; hosted capture, live email and standalone host individually marked proven/pending. Contract v4 produces successful mock flow and tested failures. |
| Q8 — Traceability/status | Orchestrator | All CR-v3 IDs, PR-01–17, CF-01–12 have dispositions; artifacts/registers current; cancelled/deferred items not carried as active commitments. Prior gates never retroactively marked passed. |

| Live gate | Owner | Required evidence before enabling a pilot |
|---|---|---|
| P0 — Real data and operations | Mark+Chancy+Terry | Oracle read under correct tenant, real price/tax/terms/waiver/timezone, supported identity/prospect update/deactivate/status, payments and product sale; platform notEnabled ports replaced and independently proven. |
| P1 — Durable recovery | Mark+platform | Shared checkout/idempotency/recovery/consent state; process/pod restart and concurrent operation tests; operator handling of uncertain charge/deactivate; no dependence on mock store lifetime. |
| P2 — External propagation | Chancy+Kyle | PR-14 all CRM consumers and DT access state reflect deactivation; returning-record/late-compensation behavior agreed and tested. |
| P3 — Delivery/access | Chancy+Mark | Real OTP template/inbox, DT-only prospect QR email and distinct POS receipt, acknowledgments, scanner/date/visit refusal, maintenance-server proof. |
| P4 — Public surface and consent | Mark+PK+Kelly | Standalone home approved, DNS/TLS/cookie/Pay Page and Cloudflare tests; counsel/Twilio decisions for placement/content/modal/no age gate; no mock/test config in production. |
| P5 — Pilot process | Mark+Chancy+product | Simulated-user runs resumed/completed, sandbox-only test evidence, baselines at 31239/31590 and named rollout/recovery owners. |

**Completion vocabulary:** “Guest Pass v4 changes complete and proven with mocks/local fault tests; dev browser [verdict]; standalone host [verdict]; Oracle/live transactions/DT email/scanner/webhooks [individual verdicts]; pilot not enabled until P0–P5 pass.” Never equate Q-gate completion with production readiness. B1 hosted capture and Sprint 0002 S2/S7 remain pending/deferred unless actual new evidence closes them.

## Risks & Mitigations

| Risk | Mitigation / owner |
|---|---|
| Superseded files or colliding CR IDs reintroduce QR/date/age behavior | Source-qualified traceability, explicit removal matrix and negative route/schema/DOM tests; orchestrator. |
| Literal MICO home decision changes after implementation starts | Host-independent v4 contract/modules; CF-11 day-one decision; no speculative second implementation; Bjorn. |
| DBA column names/access unavailable or Node Oracle integration unsuitable | A1 time-box, typed query boundary/fixtures, explicit MICO endpoint alternative with cost; no live fallback to fabricated prices; Terry/Mark. |
| Old `onlineProspects` free-trial gate blocks or enables paid product incorrectly | Separate Guest Pass LD gate and flagged-product eligibility; trial unchanged; BFF. |
| Declined purchase remains active or triggers CRM marketing | DT business deactivate, correlation and all-consumer PR-14 proof; no pilot on mock-only success; Chancy/Kyle. |
| Retrying unknown response creates duplicate prospect/charge or deactivates newer access | Stable operation keys, status lookup, revision checks, active-operation exclusion and durable live gate; Mark. |
| Create emits credential before payment; compensation lags | Verify trigger, prevent duplicate sends, prove access/CRM deactivation; explicit pilot blocker if unsafe; Chancy/Mark. |
| Returning repaint overwrites active paid access | Exclude overlapping-active-pass pilot case until refusal/restoration contract decided; no unapproved extension; product/Mark. |
| Wallet API write mistaken for desk/app propagation | UUID identity and metadata allowlist retained; wallet review concerns external; test actual DT/POS outcome before claim; wallet owners. |
| Legal/Twilio rejects modal or waiver without age gate | PROPOSED dev content; inline opt-in fallback; CF-08/09 owners and pilot gate; Kelly. |
| New host breaks secure cookie, origins, assets or allows card-testing bypass | Same-origin BFF, retain ingress fix, host-specific smoke and Cloudflare rule proof before publication; platform/PK. |
| Mock stores, pinned OTP or fixture catalog leak into production | Explicit boot/capability guards, deployment mode evidence and P0/P1/P4; BFF/platform. |
| Sprint grows into durable platform, MICO rewrite or full harness | Two lanes limited to v4 behavior and adapter boundaries; dependencies and live gates state residual work rather than pretending it fits; orchestrator. |

## Dependencies

| Dependency / owner | Needed for | Fallback / effect if absent |
|---|---|---|
| Terry + Chancy: catalog-item product flag/days/visits schema, price mapping, deployment classification/window (CR-18/33, PR-05/17) | Live Oracle and pilot config | Fixtures/query tests complete; live catalog remains pending. September 10 “tonight” is historical urgency, not a current deployment promise. |
| Chancy + PK: reviewed DT PR, waiver field, prospect mail, QR library (CR-17/19/24, PR-11) | Real credential/access | Typed mock delivery/status only; no BFF QR substitute. |
| Mark + Chancy: identity, create/repaint/deactivate/status, token semantics, sale/payment contracts | Real transaction and recovery | Mock ports with operation assertions; notEnabled capabilities explicitly block pilot. |
| Platform/DBA: read-only Oracle credentials/network/VPD rules and supported driver/runtime | DB adapter | Fixture mode; consider documented MICO endpoint alternative at A1. |
| Chancy: OTP HTML (CR-29/34) | Template finalization | PROPOSED template with club/code variables; real send/template acceptance pending. |
| Kelly/legal: approved terms, opt-in text/presentation, waiver without age gate and email acknowledgments | Consent pilot gate | PROPOSED dev content; modal/inline variants; no legal approval inferred. |
| Bjorn: CF-11, Jira epics to Chancy (PR-10) | Repo/host commitment and DT tracking | Existing-repo implementation under draft recommendation; standalone rollout pending. |
| Mark/PK/platform: standalone host/TLS, LD flag, Cloudflare, Pay Page allowed origin and sandbox access | Hosted proof/public rollout | Existing-dev mock smoke; B1/standalone gap remains explicit. |
| Wallet owners: reviewed prospect classification/metadata/flags and propagation | Wallet usable at desk/app | Existing adapter/mock tests only; no wallet-stack changes in this sprint. |
| Chancy/Kyle/Mark: scanner, CRM consumers, maintenance, agent runs; product baselines | P2/P3/P5 | Written test steps and owners; no fabricated external proof. |

## Open Questions

### Recommended answers to intent questions 1–3

1. **Reconciliation:** Rounds 5–7 supersede the shipped Sprint 0003 sources. Remove QR/pass page/mail credential/date/age code from the runtime; retain offers/receipt/calendar helpers. Disabled legacy mode costs 1–2 days plus permanent extra test/security surface and is not recommended.
2. **Home/repo:** reuse React/Koa in the existing repos at an independent Guest Pass origin, pending CF-11 confirmation of the D60 interpretation. A literal MICO fork is roughly 4–7 engineering days plus platform work; rehosting is roughly 1–2 code days plus 1–2 platform days. Unanswered: build host-independent v4, prove existing dev, leave standalone rollout pending.
3. **DT read:** isolated read-only Oracle catalog adapter, fixtures until schema/grants/network are available; no enterprise API change. MICO/DT endpoint is the fallback if direct Oracle is declined (~1–2 owner days + 0.5–1 BFF day plus deployment), not claimed as already existing. Wallet-account-sync is not the read service. A live read is a separate proof gate.

### Confirmation and requested-question register

IDs below refer to **CR-v3 (2026-09-10)** unless explicitly qualified. Old September-15 CF-04…07 are not the same questions: multi-day pricing/window is deferred, pass-link lifetime/static-vs-link choice is superseded by D63, and fixture catalog is replaced by DT mapping.

| ID | Question / disposition | Owner | Effect if unanswered |
|---|---|---|---|
| CF-01/02/04 | Consent placement, terms text, prospect-email acknowledgments approved? | Kelly + legal | Dev PROPOSED evidence; legal pilot gate pending. |
| CF-03 | Named OTP sink/sandbox-card owner? | Kelly → Mark | Local sink/fixture smoke possible; hosted/agent gate pending. |
| CF-05 | Deferrals acknowledged under D53/D72? | Kelly | Plan ships only configured single-visit scope; no waiver once-per-club state. |
| CF-06/07/12 | Closed: DT engagement QR library; BFF OTP owner; product not service. | Recorded decisions | No new question; no implementation of superseded alternatives. |
| CF-08 | Waiver enforceable without 18+ gate? | Kelly + legal | Remove age gate as D66 requires; legal pilot gate pending, no substitute DOB control. |
| CF-09 | Legal/Twilio accept long opt-in text in modal? | Kelly | Build modal with inline fallback; no pilot SMS approval inferred. |
| CF-10 / PR-13 | PK: any legal/payment-ops rule behind pre-payment prospect creation? | PK | Keep D65 create→pay→deactivate for v1; answer informs v2, not permission to switch order now. |
| CF-11 | Approve existing repos + standalone host as implementation of D60, or require literal MICO fork? | Bjorn | Finish v4 modules/dev proof; home/standalone rollout not marked complete. |
| RQ-1 | Exact schema, authoritative timezone/price/tax, VPD access and Oracle driver mode? | Terry + Chancy + platform | Mock catalog only; no default timezone or fixture price in platform mode. |
| RQ-2 | DT conditional update/deactivate, status-by-operation-key, and early email trigger supported? | Mark + Chancy | Mock failure matrix ships; live mutation/recovery/credential gate blocked. |
| RQ-3 | Can passed payment token attach to prospect without pre-auth wallet save? | Mark + payments | Keep logical contract explicit; no live adapter enabled until token semantics confirmed. |
| RQ-4 | What happens when a returning prospect has unconsumed paid access and the repaint purchase fails? | Kelly + Chancy + Mark | Exclude overlapping-active-pass pilot case; no implicit extension or destructive rollback. |
| RQ-5 | Production operational checkpoints/consent persistence and operator compensation ownership? | Mark + platform | In-memory mock scope stated; P1 pending; “attempts logged” does not erase replay protection. |
| RQ-6 | DT “sent” evidence versus accepted-for-delivery? | Chancy | Default pending/unknown customer copy; never state email sent based only on create success. |
| RQ-7 | Resume deferred harness for PR-02, and who records baselines? | User / Mark / product | Manual browser proof proceeds; agent/baseline pilot gates pending. |
| RQ-8 | Close Sprint 0002 administratively with explicit transferred/deferred gates? | Sprint owner | Recommend completion-of-A–C note and named carries, never “all gates passed”; leave historical status unchanged unless owner confirms ledger convention. |

**Deferred/cancelled register:** No future start, multi-day/multi-visit entitlement, pass extension, guest-definition revisit, no-record-until-payment redesign, public dynamic-link/minute QR app, DOB/minor queue/M&O age policy, once-per-club waiver-version state, per-item “what's included,” reporting/insights, generic item-sale email rule or link-use counter. Sprint 0003's rotating QR/desk-verifier carry is superseded, not automatic Sprint 0004 work. Durable stores and production recovery remain named enablement dependencies; full generation matrix, broad tracking audit, metrics, Turnstile, comprehensive accessibility audit, semantic-index expansion and the deferred parity/agent harness remain separate work. Targeted concurrency, logging and accessibility checks needed for changed paths are included here.
