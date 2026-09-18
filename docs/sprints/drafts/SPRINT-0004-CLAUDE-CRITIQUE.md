# Sprint 0004 — Claude critique of the CODEX and GEMINI drafts

**Status:** critique for the planning interview, 2026-09-17. Reviews `SPRINT-0004-CODEX-DRAFT.md` and `SPRINT-0004-GEMINI-DRAFT.md` against `SPRINT-0004-INTENT.md`, `Consolidated_PRD_v3.6.md` (Rounds 5–7, §4.6, §9, §10), `Change_Requests_2026-09-10_v3.md`, `Next_Steps_2026-09-10_v2.md`, `day-passv6.html`, `docs/sprints/SPRINT-0003.md`, and the code in `repos/online-join-bff` (`origin/main` f5c92ca), `repos/online-join-ui`, `repos/mico` and `repos/helm-configs`. Every code claim below was checked by reading the file named; drafts' claims that could not be checked are marked as such.
**Path shorthand:** `BFF/` = `repos/online-join-bff/src/`, `STP/` = `BFF/services/shortTermPass/`, `UI/` = `repos/online-join-ui/src/`, `MICO/` = `repos/mico/src/main/java/com/abcfs/`.

## 1. Verdict in brief

- **CODEX** is the plan to build from. It answers the three interview questions with reasons, gives the per-capability keep/hide/remove table with code paths that the intent's first success criterion demands, catches four code facts the intent and the CR list get wrong (OTP constants, numeric keypad already present, fixture offer under the "live" catalog label, production guard silent on the pinned OTP), and its failure/recovery matrix is the only serious treatment of D65. Its weaknesses are density, an estimate with no slack, and a DT read-path recommendation (direct Oracle first) that its own MICO finding argues against.
- **GEMINI** is a sketch, not a sprint plan. Its L1 positions on the three questions are stated clearly and two of them are right for the wrong reasons, but the body omits the returning lane (CR-14/15), the LaunchDarkly gate semantics, D62's "club defaults untouched", the attempt-log/Cloudflare posture, the CF/RQ register and any DoD with owners. It hard-codes "valid for 30 days" from the v6 prototype in U2, which D71 forbids, and it names a test stack the repo does not use. Its five-file Files Summary is a fraction of the surface that actually changes.
- **Both drafts miss the same code fact** that decides Open Question 3: MICO has no Oracle connection at all. It reaches DataTrak through a Feign client to DT's own `.spr` web-service layer ("orasvc"), which already exposes online sale items, prospect creation and club online settings. The realistic read path is that layer, not a new Oracle driver in the BFF and not "MICO's Oracle link".

## 2. Code facts the drafts must be measured against

| # | Fact | Where | Codex | Gemini |
|---|---|---|---|---|
| F1 | OTP code TTL is **10 minutes** and the per-address limit is **5 sends/hour**, on `origin/main` as well as the cookie-fix branch. D58/D59 say 5 minutes and 2 sends. CR-10 and CR-30 are marked "Done" in the CR list but are not implemented. | `STP/challenge.ts:11,16` | Found and scheduled (B6) | Not mentioned; treats CR-30 as done |
| F2 | `inputMode="numeric"` is already on the OTP inputs; the only visible countdown is the 30 s resend cooldown. There is no five-minute expiry display. | `UI/routes/ShortTermPass/components/InlineCodeEntry.tsx:66,123,148` | Found; C2 adds the expiry display | C4 "add inputmode=numeric" is already-done work |
| F3 | The "live" platform catalog reads MICO `club/getClub` but returns `FIXTURE_OFFER` and hard-codes `America/Chicago`; its capability report says `status: 'live'`. | `STP/adapters/platform/catalog.ts:18,92,105` | Found; B2 removes the fallback and splits the capability report | Not mentioned |
| F4 | **MICO does not read Oracle.** `build.gradle:75-76,92` exclude `spring-boot-starter-jdbc`/`data-jpa`; no `DataSource`/`JdbcTemplate` anywhere under `src/main/java`. Every DT read or write goes through `OrasvcClient` (Feign) to `.spr` endpoints: `/pos/saleItems.spr` (`getOnlineSaleItems`), `/pos/onlineSale.spr` (`performOnlineSale`), `/member/addProspect.spr`, `/external/club/getClubDefaultExternal.spr` (source of `prospectTerms`). | `MICO/feignclients/OrasvcClient.java:95-96,130-140`; `MICO/repository/{WsShop,WSProspect,WsClubDefaults}.java`; `MICO/domain/mapper/DtClubInfoMapper.java:71` | Partly: notes `oraSvcRestTemplate`/`orasvcClient.addProspect` and "no ready-made direct Oracle query", but still recommends direct Oracle first | Wrong: "MICO already has safe read access to DT … the Oracle link established" |
| F5 | DT's `SaleItem` already carries `catalogItemName`, `catalogPrice`, `expiration`, `taxed`, `unlimited`. The D61 flag is described as "like the existing 'available online'"; the new flag/days/visits are Chancy's DT PR, and the natural place they surface is this endpoint or a sibling. | `MICO/dto/response/SaleItem.java` | Not found | Not found |
| F6 | The production boot guard refuses mock mode, smtp, flag override, mock faults, test hooks, test clock and mock capture, but **not `STP_MOCK_OTP_CODE`**, which the dev helm values set. | `STP/config.ts:211-240`; `repos/helm-configs/online-join-bff/dev.yaml` | Found ("audit the guard for that exact key") | Not mentioned |
| F7 | Every route is gated on the LaunchDarkly flag **and** the club's `onlineProspects` (free-trial) setting. D50 as revised by D61 replaces the enable switch with "presence of flagged items". | `BFF/utils/middlewares/requireShortTermPass.ts:29-30,61-68` | Found (B1 decouples) | Not mentioned |
| F8 | Orchestrator order today: VALIDATED → AUTHORIZED → PERSON_PERSISTED → WALLET_RESULT → SALE_FINALIZED → ISSUED → COMPLETE. `ProspectPort` has only `create(input, idempotencyKey)`; no update, lookup or deactivate. `PaymentPort` has `status/capture/void/refund`. | `STP/purchaseOrchestrator.ts:395-834`; `STP/ports/prospect.ts`; `STP/ports/payment.ts:29-36` | Correct; extends the port | Correct at the sketch level |
| F9 | The UI mounts under `BrowserRouter basename="/signup"`; `PAGES.shortTermPass='/day-pass'`, `passView='/pass/:token'` matched first in `App.tsx`. | `UI/index.tsx:18`; `UI/common/constants.ts:13-17`; `UI/App.tsx:17-27` | Says the consumer URL "must not require /signup" but never names `index.tsx` | Not addressed |
| F10 | `STP_PUBLIC_BASE_URL` is used only to build pass view/QR URLs. Helm dev sets `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS`, `STP_PUBLIC_BASE_URL`. | `STP/passCredentials.ts:77`; `BFF/routes/shortTermPass/purchase.ts:248`; helm `dev.yaml` | Found (audit/remove) | Silent on env keys |
| F11 | `MarketingOptIn` is rendered once, in the new-visitor profile form. v6 puts the checkbox in the right sidebar under the waiver, for both lanes. | `UI/routes/ShortTermPass/steps/NewVisitorStep.tsx:119` | Close ("remove the older one near the profile fields"; there is one, not a duplicate) | Silent on placement |
| F12 | v6 HTML still has `adultCb` gating Pay (lines 628-645, 743, 767), `VALID_DAYS = 30` with expiry `today + 30` (401-404), refund copy "before the pass is first used" (373), and a marketing paragraph that hard-codes "Core South" (386). | `docs/prd/day-passv6.html` | All four recorded as deltas not to copy | Copies "valid for 30 days" into U2 |
| F13 | Browser QA in this repo is Playwright/headless-Chrome agents plus the `short-term-pass-demo.ts` script. | `docs/validation/qa/sprint-0001/*`, memory | Consistent | "Update Cypress/Selenium smoke flows" |
| F14 | `SPRINT-0002` is `status: in-progress` with phases A–C complete and D/E1/E2 deferred. | `docs/sprints/ledger.yaml:27-35` | RQ-8 | Not addressed (intent Q9) |
| F15 | MICO's own prospect create sets `commSms/commEmail/commPushNotif/commDirectMail` from one consent value. The `AddProspectRequest` class lives in an external jar, so "already accepts begin/expiration/visits" (CR list §F) cannot be verified from source here. | `MICO/controller/ProspectController.java:197-273` | Treats field names as an owner contract to be supplied (RQ-2) | Assumes |

## 3. CODEX draft

### Architectural soundness

Sound where it matters. It keeps the trust boundary (opaque cookie, server-owned order, Pay Page as the only card entry, one consent snapshot) and changes product semantics only. The contract v4 table is right to remove writable `visitDate`/`adult`, add server-owned `beginDate/expirationDate/contractDays/numberOfVisits`, and make pre-pay dates a quote confirmed at Pay. Refusing a multi-visit configuration at purchase rather than coercing visits to 1 is the correct reading of D72. Retiring the public credential routes to a generic 404 rather than a flag is the right call under D63 ("nowhere else"); its argument that a disabled second credential implementation is permanent test and security surface, and that `STP2`/`pv1` is not the v2 dynamic-link design anyway, holds.

Three soundness problems:

1. **Read path contradicts its own evidence.** §2 recommends a BFF-owned Oracle adapter first and a MICO/DT endpoint as fallback, while its orientation notes correctly that MICO uses `oraSvcRestTemplate`/`orasvcClient` and has no direct Oracle query. F4/F5 make the case stronger than Codex realised: DT already publishes online sale items and club online settings through orasvc, and Chancy's DT PR is the change that adds the flag/days/visits to DT anyway. A direct Oracle read from Node needs a driver, read-only credentials, VPD context handling, a network path and a DBA relationship the BFF has never had, for data that the DT service layer is about to expose. The A1 time-box should decide this on day one with the orasvc evidence in hand, and the default should be the service endpoint (via MICO `/iclub`, which the BFF already calls for `getClub`, or directly), with direct Oracle as the fallback only if Chancy confirms the fields will not be exposed. CR-31's "no enterprise-API change" is about the enterprise API; orasvc is DT's own layer, so this is not a deviation from D64 in substance.
2. **Sale adapter left implicit.** `PassSalePort` is `notEnabled`; `performOnlineSale` (`/pos/onlineSale.spr`) is the existing online POS sale MICO uses. Codex's orchestration puts "finalize product sale + confirm capture" after authorization but never names where the product sale is recorded. Same owner contract, same A1 item.
3. **Standalone home is described without the file that blocks it.** F9: the UI is compiled with `basename="/signup"` and the BFF serves it via `historyFallback`. Codex's D1/C6 talk about "asset base/history fallback" but a plan that promises `/guest-pass?club=NNNNN` on a new host must name `UI/index.tsx`, the `historyFallback` allowlist and whether the standalone origin is a second helm release of the same chart or a second host on the same release (different flag and config need the former). Codex flags "validate chart support in A1" — right instinct, under-specified.

### Completeness against CR v3 and Rounds 5–7

Near-complete. Every CR-v3 §A/§B row is addressed by a task, including the ones Gemini drops (CR-14 returning re-accept, CR-15 expired card → Pay Page, CR-24 distinct subjects, CR-20 flag semantics). D62 (club defaults untouched), D65 (attempts logged ≠ dropping idempotency state, Cloudflare on the exact host), D67 (phase-one fields; one control for both lanes), D71 (never hard-coded; inclusive `days − 1`), D72 (refuse multi-visit configs) are all there. The §G cancelled register and the Sprint 0003 "Carried to Sprint 0004" list are both disposed of explicitly. The source-qualified ID rule (September-15 CR-11 = multi-day validity; v3 CR-11 = cancelled QR renderer) is a real collision and worth keeping verbatim.

Gaps:

- **D52 vs J1 email trigger** is raised (§5) but not turned into a blocking gate. If DT sends the prospect email with the QR on create, and create now precedes payment, a declined buyer holds a QR. That is a pilot blocker on its own, independent of PR-14. It should be RQ-0 with "effect if unanswered: no pilot".
- **`AddProspectRequest` fields** (F15). The plan assumes begin/expiration/visits/opt-in exist on the create call because the CR list says so; it should carry an RQ with the effect "mock adapter only" and note that MICO sets four `comm*` flags from one value, so "the opt-in value" may be four fields.
- **Opt-in for the returning lane.** CR-12 sends the opt-in on the repaint too; Codex's "one control in the sidebar for both lanes" implies it but U6 does not assert it.
- **Intent Q8** (hooks policy on declared non-production clusters) is answered only by implication (E2: browser never reads `/testing/*` through the ingress). Say it explicitly: no policy change this sprint; pinned OTP suffices.

### Phasing and ordering

A (1 day) → B/C in parallel → D → E mirrors Sprints 0002–0003 and is right. Within B, "B1 schema skeleton → B2/B3 → B4 → B5" is correct; B6 (OTP constants and template) is independent and should be first in the lane because it is the smallest CR-list correction with the most visible dev impact. One ordering risk: C1 (consume v4) cannot start until A2 freezes the contract and B1 lands the skeleton; A is only one day, so A2 must be the day's first deliverable.

### Risk coverage

The best of the two by a wide margin. The recovery matrix's rows for "create response lost", "authorization unknown", "late compensation vs newer record" and "repaint overwrites active paid access" (RQ-4) are the risks that will actually bite a pilot. Also good: "D65 attempts logged does not mean delete replay protection", the `onlineProspects` false-positive/negative on a paid product, and mock/pinned config leaking to production (F6). Missing: the email-on-create risk as a named gate (above), and the helm/ingress cookie regression already fixed once in PR #106 is mentioned but not as a smoke row on the new host.

### Feasibility

A 1 + B 5–7 ∥ C 4–5 + D 1–2 + E 1–2 = roughly 9–11 working days, which is the whole two-week bound with no slack. The load is in B4 (eleven-row failure matrix), B2 (a new database adapter), and the removals across both repos with their test churn. Two cuts keep it inside the window: (a) B2 ships the port change, fixtures and a query/mapping boundary only, with the live adapter (orasvc or Oracle) built the day the owner contract arrives; (b) B4 splits into must-have (create before auth; decline → deactivate with stable key; deactivate failure → RECONCILING; same-key replay; no wallet on decline) and register rows (late compensation vs newer record; overlapping-active-pass refusal; unknown-auth status reconciliation beyond the existing `status()` call). Codex already says "if Oracle consumes the time-box, finish typed adapter/mocks"; make that the plan, not the fallback.

### Definition of done

Q0–Q8 sprint gates and P0–P5 live gates with owners, plus a completion vocabulary, follow the Sprint 0003 T-gate convention and keep "mock proof" separate from "pilot ready". Q6's coverage floors are the real numbers (UI 80/80; BFF 84/67/67/84). Two improvements: Q4 should include a negative DOM/API test list by route (it says "retired routes negative-tested" but the smoke list in E2 is where the routes are enumerated), and Q7 should name the dev host and version string it expects, since "recorded with versions/mode" has been the point of failure before.

### Answers to Open Questions 1–3

1. **Reconciliation:** Rounds 5–7 supersede; remove the runtime QR/pass-page/date/age code; keep offers, receipt, calendar helpers. Agreed, with the code-path table as the deliverable. The alternative cost (1–2 days plus permanent surface) is fair.
2. **Home/repo:** existing React/Koa at a standalone origin; MICO fork 4–7 days plus platform work; rehost 1–2 code days plus 1–2 platform days. Agreed, and the "if CF-11 is unanswered, build host-independent and prove on the existing dev origin" fallback is the right hedge. Needs the F9 file list.
3. **DT read:** direct Oracle first, MICO endpoint fallback. **Disagree on the order** (F4/F5); agree on "fixtures until the schema exists, live read is a separate gate, wallet-account-sync is not a catalog service".

### Strongest ideas to keep

Disposition table with code paths; source-qualified CR IDs; F1/F2/F3/F6/F7 corrections as B1/B6/C2 tasks; contract v4 table (server-owned dates, `contractVersion`, no writable `visitDate`/`adult`); refuse multi-visit configs; the recovery matrix (trimmed as above); "D65 logging ≠ dropping idempotency"; D52-vs-J1 email trigger question; approved v6 delta list (F12); Q/P gate split and vocabulary; RQ register with "effect if unanswered"; explicit deferred/cancelled register including the Sprint 0003 carries.

### Weaknesses

Read-path order; sale adapter unnamed; `/signup` basename and chart/release shape unnamed; estimate at the top of the box; prose density (many tasks are "files … as needed"); U-rows lack the pinned copy strings Sprint 0003's U-rows carried (the "You have 1 day to use this pass" / "Use by {date}" / "We've emailed your QR code for club access" strings appear only in §3 and §5, not as test-pinned rows).

## 4. GEMINI draft

### Architectural soundness

The three L1 positions are defensible as headlines: keep React/Koa and rehost; read DT through a MICO endpoint; create → pay → deactivate. The reasoning under two of them does not hold against the code:

- "MICO already has safe read access to DT … the Oracle link established" is false (F4). The conclusion (use a service endpoint, not a Node Oracle driver) is still the better one, but the plan must say why: the orasvc `.spr` layer, extended by Chancy's DT PR, is where the flag/days/visits will surface.
- "Hidden / configured off: … routes behind `STP_QR_V2_ENABLED`" (Overview) vs "`STP_V2_CREDENTIALS`" (Phase B3): two names for one flag, and the approach itself keeps a public credential route mounted in production behind configuration, which D63 excludes and which the production boot guard would have to learn to refuse. Preserving the code for v2 is also moot: the v2 credential (D63, §10) is a different design (public app rendering a one-minute QR from barcode and club number), not `pv1` tokens over `STP2`.
- U2 "Valid: One time use only, valid for 30 days — use by {expiration}" copies v6's `VALID_DAYS = 30` (F12). D71 and the intent both say N comes from the item; the same draft says v1 is one visit with the date fixed to purchase. This is the one line in either draft that would build something the PRD forbids.
- Purchase order step 4 "return 400" ignores the existing typed purchase result (`payment.status: 'declined'`, state `FAILED`) and the RECONCILING/unknown paths already in the orchestrator (F8). "Guarantee idempotent recovery of deactivations" has no mechanism beyond the sweep in Risks, and `ProspectPort` has no deactivate to sweep with.
- Phase B "issue, deliver" and U4 "pass issued" survive unchanged; under D63 there is nothing for the BFF to issue or deliver. What replaces those checkpoints (receipt snapshot; DT delivery acknowledgement) is not said.

### Completeness

Against CR v3 §A/§B: covers CR-09, CR-12 (partly), CR-13 (already done, F2), CR-25, CR-26, CR-27, CR-28, CR-29, CR-31, CR-32, CR-06. **Missing:** CR-14 (returning lane re-accepts terms and waiver), CR-15 (expired card → different card via Pay Page), CR-20 semantics (flag off = existing behaviour; what "own flag" means against the current key), CR-24, CR-30 (assumes done; F1), CR-35's "never hard-coded" (violated in U2). Against Rounds 5–7: D62 "club default prospect settings untouched", D65 attempt logging and Cloudflare on the new host, D67 phase-one fields and TCPA record, D72 refusal of multi-visit configs, D74 tests as dependencies. §G cancelled register: absent, so nothing stops a later lane from rebuilding the picker or the QR. Sprint 0003's "Carried to Sprint 0004" list: not mentioned. CF-08…CF-11 and PK's D65 answer: three lines under Dependencies with no "effect if unanswered"; PR-14 is assigned to PK, but the CR list gives it to Chancy and Kyle. Intent questions 4–9: not attempted (Q8 hooks, Q9 ledger absent).

### Phasing and ordering

A → B ∥ C → D is the right shape. But Phase A "Fixture updates … source the new DT product payload shape" precedes any decision on what that shape is; Phase D "Traceability: update Cypress/Selenium smoke flows" names tooling the repo does not use (F13) and puts the scanner and webhook checks, which are owner-gated pilot steps, inside a two-day orchestrator phase as if they were sprint work.

### Risk coverage

Two risks. The first (ghost prospects if the process dies mid-deactivate) is real and the mitigation (a background sweep retrying stalled deactivations) is a good idea worth keeping, with the caveat that the purchase store is in-memory so the sweep is process-local until durable state exists. The second (modal vs inline) matches Next Steps' fallback. Not covered: email-on-create before payment, `onlineProspects` gating, mock/pinned config in production, new-host cookie/CSRF/Pay Page origin, repaint over an active pass, unknown authorization outcome, card testing before Cloudflare is on the host.

### Feasibility

Phase sums to about 11 days, but for the scope as written, which leaves out the schema and reducer changes, `ConsentBlock`/`usePayAction` adult removal, `OrderSummary` and `DoneStep` rework, `App.tsx`/`constants.ts` route changes, route and component test churn, helm values and the removal of the credential routes. A three-day UI lane cannot cover that. The Files Summary (five files) versus the real surface (Codex's Files Summary is a fair inventory) is the clearest sign the estimate is not grounded.

### Definition of done

Five bullets, no owners, no evidence per gate, no vocabulary, no distinction between mock proof and pilot readiness. "Deferred features correctly hidden via feature toggles, keeping `main` clean" is a DoD item for a decision this critique recommends against.

### Answers to Open Questions 1–3

1. Keep everything, flag off the QR and pass page, force multi-day components to read one visit. Reject for the runtime (D63 "nowhere else"; guard would need extending; not the v2 design); the "don't lose the work" concern is met by Git history and a tag at the Sprint 0003 merge.
2. Rehost React/Koa; MICO port "would delay pilot by a month". Right conclusion; the cost is asserted, not derived, and no host/basename/cookie/flag details are given. `guestpass.abcfitness.com` is an invented hostname; the plan should not name one until platform does.
3. MICO endpoint over direct Oracle. Right conclusion for a wrong reason (F4); keep the recommendation, replace the reasoning with F4/F5.

### Strongest ideas to keep

Service endpoint rather than a Node Oracle driver (with corrected reasoning); background retry of stalled deactivations (as a process-local retry now, durable later); modal → inline conversion behind a flag as the CF-09 fallback; the concise L1 phrasing.

### Weaknesses

Hard-coded 30 days; flagged-off public credential routes; missing returning lane; no register; no owners or evidence in the DoD; wrong test tooling; an estimate that does not match the file surface.

## 5. Coverage matrix

| Requirement | CODEX | GEMINI |
|---|---|---|
| CR-09 opt-in checkbox + modal, value on create | Yes, both lanes, sidebar | Yes, new visitor only |
| CR-12 create call fields; club defaults untouched; repaint | Yes | Fields yes; defaults/repaint not stated |
| CR-13 numeric keypad | Notes already present; adds expiry display | Plans already-done work |
| CR-14 returning re-accepts terms/waiver | Yes (C4) | No |
| CR-15 expired card → Pay Page | Yes (C4, server refusal too) | No |
| CR-20 LD flag; off = existing behaviour | New key `guest-pass-online`; old key not sufficient | "own flag", unspecified |
| CR-25 success copy, no QR | Yes, truthful pending/failed | Yes |
| CR-26 remove 18+ | Yes, incl. `usePayAction` gate | Yes |
| CR-27 standalone URL, repo home | Yes, with fallback if CF-11 open | Yes, thin |
| CR-28 flagged items, one v1 item | Yes; refuses multi-visit configs | Yes |
| CR-29 OTP template pending | PROPOSED with same variables | "Wait on Chancy" |
| CR-30 5-minute timer | Found not done (F1); B6/C2 | Assumed done |
| CR-31 DT read path | Oracle first (disputed) | MICO endpoint (right, wrong reason) |
| CR-32 create → pay → deactivate; attempts logged; Cloudflare | Full matrix | Sketch + sweep |
| CR-06 save card only on success | Yes | Yes |
| CR-24 unmistakable subjects | Yes | No |
| §G cancelled register | Yes | No |
| Sprint 0003 carried list disposed | Yes | No |
| PR-02…06/14, Next Steps 8–12 as gated steps | Yes, owners | Scanner/webhook only |
| CF-08…CF-11, PK D65 with effects | Yes | Owners only |
| Intent Q4–Q9 | Q4–Q7 yes; Q8 implicit; Q9 RQ-8 | None |
| v6 deltas (adult, 30 days, refund copy, Core South) | All four | None; copies one |

## 6. Recommendations for the merged plan

1. **Base on CODEX.** Keep its disposition table, contract v4 table, recovery matrix (trimmed), Q/P gates, registers and the F1/F2/F3/F6/F7 corrections as tasks.
2. **Flip the read-path order** using F4/F5: primary is a BFF adapter over DT's orasvc layer (through MICO `/iclub` or directly), with fixtures until Chancy's DT PR exposes flag/days/visits; direct Oracle is the fallback and a separate gate. Add `performOnlineSale` as the candidate for the sale adapter to the same A1 item. Record the correction to D64's "like Myko reads the database" as a CF for Chancy.
3. **Add RQ-0:** does DT send the prospect email (with QR) on create or on an explicit trigger? Effect if unanswered: no pilot enablement.
4. **Add an RQ for `AddProspectRequest`** (begin/expiration/visits/opt-in fields; four `comm*` flags vs one value). Effect: mock adapter only.
5. **Name the home files:** `UI/index.tsx` basename, `historyFallback`, `constants.ts`, helm release shape (second release of the same chart vs second host), Pay Page allowed origins, LD key, Cloudflare rules on the exact host.
6. **Pin the copy as U-rows** the way Sprint 0003 did: "You have 1 day to use this pass", "One time use only", "Use by {absolute club-local date}", "We've emailed your QR code for club access", and the v6 done header, so tests and traceability have strings to bind to.
7. **Cut for feasibility:** live catalog adapter and the second-order recovery rows become register/gate items; B6 first in the BFF lane.
8. **Take from GEMINI:** the deactivate retry sweep (process-local now), modal → inline via flag, and the service-endpoint conclusion.
9. **Answer Q8 and Q9 explicitly:** no hooks-policy change (pinned OTP and no ingress reads suffice); close SPRINT-0002 with a note listing D/E1/E2 as deferred and S2/S5/S7 as carried, without marking gates passed.
10. **Extend the production guard** to refuse `STP_MOCK_OTP_CODE` (F6) as a one-line B1 task with a test, and add the new host's cookie/CSRF check to the smoke as a named row given PR #106.
