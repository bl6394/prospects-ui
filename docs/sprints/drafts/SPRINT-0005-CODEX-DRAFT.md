# Sprint 0005: G1 — DataTrak guest-pass service fields and reversible database feature gates

**Status:** CODEX DRAFT, 2026-10-07. Recommendations for planning review, not approved architecture or evidence of implementation. Owner slots are assigned by name at kickoff; pending decisions and external work retain explicit verdicts.

**Sources:** `docs/sprints/drafts/SPRINT-0005-INTENT.md` governs scope and the flag-off invariant; `docs/DT-21555-guest-pass-email-prd/REVIEW-2026-09-23.md` supplies G1/G2/G8/G9/G12; `docs/sprints/SPRINT-0004.md` supplies contract v4, house style, carried CF/RQ registers and V-P0…V-P6. Sprints 0001–0003 are history, not authority to restore cancelled features. No Chapter Context applies.

**Evidence boundary:** local files and locally fetched Git objects only. No remote host, API, database, LaunchDarkly project, CI run or deployed application was probed for this draft. Remote PR/merge/deployment facts are carried from the intent, not independently reverified. The DataTrak working tree is on `main`; PR #6643 was read with `git show feat/NOJIRA-guest-pass-email:<path>` and targeted searches, without switching branches. The shallow clone has no merge base for `main...feat/NOJIRA-guest-pass-email`; do not mislabel a two-tip comparison as the PR diff. All DataTrak PR-source citations below refer to that branch unless explicitly marked baseline.

## Pyramid Index

- **L0:** Expose the guest-pass fields through `datatrak-service`, protect every PR #6643 database/template dependency in `datatrak`, align the BFF to the agreed wire contract, and prove that flags off permit deployment before migration and operation after schema rollback, with dev catalog activation separately evidenced and no production exposure.
- **L1:**
  - **A — Baselines, contract and ownership:** inventory all new-column/template paths, freeze legacy SQL/JSON/XML/page baselines, decide DTO serialization, confirm memberless product listing and named rollout owners.
  - **B — DataTrak service:** one default-off, club-targeted flag selects legacy versus extended SQL/mappers/responses; timezone uses the existing lookup; memberless listing returns flagged products without member enrichment.
  - **C — DataTrak M&O:** guard catalog load/save/deployment, Edit Club liability, both POS completion paths and `ADD_GUEST` construction; retain legacy operations; exercise schemas with and without the additions.
  - **D — BFF/UI:** confirm field names and types, reject unknown item types/timezones, preserve consent safety and fail-closed routing, label evidence and flag observations truthfully, verify the existing unavailable UI.
  - **E — Delivery and proof:** reviewable PRs, default-off deployment/runbook, dev-only ordered activation or exact blocker, rollback rehearsal, CF/RQ and pilot register updates, four separate completion verdicts.
- **L2:** §Overview (scope and source findings) · §Use Cases (U1–U16) · §Architecture (flags, wire contract, legacy branches, compatibility, rollback) · §Implementation Plan (A–E, files and done-when) · §Files Summary · §Definition of Done (V0–V8) · §Risks & Mitigations · §Dependencies · §Open Questions (CF/RQ).

## Overview

Sprint 0004 delivered mock-proven Guest Pass v1 on the existing Online Join stack. This sprint addresses G1: the real catalog fields are absent from the service responses, and the M&O handoff assumes new database columns and email-template rows already exist. These are two separate implementation PRs in two DataTrak-owned repos, plus BFF alignment and an owned dev rollout. The delivery bar is executable flag-off safety and mock/contract proof; a dev catalog read is separately **done** or **blocked**, never inferred from fixtures or an adapter named “live.”

**In scope:** sale-item guest-pass flag, visits, contract days and actual item type; club liability text and existing timezone; all new schema/template dependencies in PR #6643; the smallest G2 memberless path and G12 product filtering needed for G1 to be usable; G8 wire encoding and safe browser consumption; an ordered migration/flag/source-switch/rollback runbook. G9 migration rewrite is optional and DBA-owned; migration verification and rollback safety are mandatory.

**Out of scope:** production flags or rollout, DataTrak merges by this team, real prospect/payment/sale adapters, durable checkout stores, QR redesign, pass pages, access enforcement, returns policy, new email content, multi-visit support, legal decisions, a new host, direct Oracle access from the BFF, and a new harness lane. V-P0…V-P6 remain independently owned. Nothing here settles G3–G7/G10/G11/G14 beyond registering dependencies encountered in these paths.

### Source findings that shape the plan

Path aliases used below resolve under this repo's `repos/` token cache; braces denote individual files, not a proposed directory.

| Alias | Root |
|---|---|
| DS | `repos/datatrak-service` |
| DS-J / DS-T | `DS/dtWar/src` / `DS/dtWar/test/java` |
| DT | `repos/datatrak` at `feat/NOJIRA-guest-pass-email` |
| DT-J / DT-T | `DT/dtWar/src/main/java` / `DT/dtWar/src/test/java` |
| BFF / STP | `repos/online-join-bff` / `BFF/src/services/shortTermPass` |
| UI | `repos/online-join-ui` |
| HELM | `repos/helm-configs` |

1. **The response owner is DS.** `DS-J/com/abcfs/club/external/controller/ClubExternalController.java:189` sets VPD before `ClubExternalServiceImpl.getClubDefaultExternal`; the service enriches branding/hideEnrollPage after the DAO (`.../service/ClubExternalServiceImpl.java:71`). `.../dao/DtManagedClubSql.java:462` reads only `serviceProviderLocations`; `DS-J/com/abcfs/repository/club/mapper/ClubDefaultExternalRowMapper.java` creates the shared `com.abcfinancial.ws.api.common.ClubDefaultExternal` and base64-encodes existing terms. Shared interface dependencies are in `DS/dtWar/build.gradle:131`. Editing only the similarly named DT classes cannot fix the deployed service response.
2. **Both list and single-item SQL paths need coverage.** `DS-J/com/abcfs/controller/POSController.java:87` requires a member, chooses `getOnlineSaleItem` or `getOnlineSaleItems`, then performs member scheduling enrichment. `.../validator/OnlinePosValidator.java:251` requires a GUID. `.../repository/pos/jdbc/JdbcPointOfSaleDao.java:110` and `:125` select separate queries with `DiscountOnlineSaleItemMapper`. `SaleItem`, `SaleItemWithDiscount`, `SaleItemResponse` under `DS-J/com/abcfs/api/pos/` are local JAXB-annotated DTOs.
3. **The existing query excludes products.** Both queries in `DS-J/com/abcfs/repository/pos/sql/PointOfSaleSql.java:25–67` constrain `cgi_service = '1'` and `cgi_online = '1'`. PR-source `DT-J/com/seqtek/abcfs/dt/inventory/catalogItems/EditCatalogItemsState.java:21` defines product `0`, service `1`, billing `2`; `CatalogItemsDB.loadCatalogItem` maps `CGI_SERVICE` to item type. Merely adding columns would still return no v1 products. Do not reinterpret `scheduleEventType` as product type or broaden MICO's member shop silently.
4. **Timezone needs no new column.** `DS-J/com/seqtek/abcfs/dt/util/TimeZoneSupport.java:58` reads `SERVICEPROVIDERLOCATIONS.TZL_ID → TIMEZONELOOKUP.TZL_ABC_CODE`. Its later use of `TimeZone.getTimeZone` is not strict validation: unknown values can silently become GMT. The named `getLocalTimeZoneAbcCode` method was not found in this local `JdbcClubDao`; use the directly inspected lookup as the citation.
5. **Flags have concrete local wrappers.** `DS-J/com/abcfs/launchdarkly/FeatureService.java` and `DT-J/com/abcfinancial/datatrak/common/launchdarkly/feature/FeatureService.java` expose `computeBooleanFeature(key, vpdId, clubIdOrNumber, defaultValue)`. The DS wrapper lacks the DT safe helper; wrap unexpected evaluation errors explicitly. Existing helper precedent: `DS-J/com/abcfs/launchdarkly/helper/FeatureFlagHelper.java`. Org conventions were read in `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/themes/feature-flags.md`; DataTrak facts come from these local sources, not that wallet-only index.
6. **PR #6643 touches reads, writes, pages and completion callbacks.** `DT-J/com/seqtek/abcfs/dt/inventory/catalogItems/CatalogItemsDB.java:469,886,925,1070,1099`, `DT-J/com/abcfs/inventory/catalogItems/repository/CatalogItemDaoImpl.java:149`, `DT-J/com/abcfs/repository/editClub/EditClubOnlineDaoImpl.java:28`, `DT-J/com/abcfs/repository/eae/jdbc/JdbcClubDao.java:376`, `DT-J/com/abcfs/sales3/repository/PointOfSaleDaoImpl.java:1032`, and `DT-J/com/abcfs/services/ProspectServiceTransactionsImpl.java:190` are direct dependency sites. Both `sales/common/repository/PointOfSaleDB.java:512` and `sales3/common/repository/PointOfSaleDB.java:268` invoke guest email before publishing the existing POS event. UI-only hiding is insufficient.
7. **The BFF is fail-closed in several ways, but needs stricter mapping.** `STP/adapters/platform/datatrakServiceCatalog.ts` currently accepts any nonempty timezone and maps every item type other than `SERVICE` to product. `BFF/src/utils/middlewares/requireShortTermPass.ts` resolves the club before evaluating `guest-pass-online`. Tighten these paths; do not claim invalid-zone or missing-type rejection is already proven. Its separate club/offers caches default to 60 seconds and require rollback handling.
8. **Compatibility requires actual converters.** `repos/mico/src/main/java/com/abcfs/repository/WsShop.java:46` has an unknown-field-tolerant ObjectMapper, but online items are fetched through `OrasvcClient` (`:94`); `WsClubDefaults.java:86` also follows a separate response path. This is useful precedent, not proof that all Feign/JAXB consumers tolerate every extension. JSON and XML consumer tests are required.
9. **Test discovery is a gate.** DS uses an explicit test include list (`DS/dtWar/build.gradle:292–303`) and JaCoCo XML for Sonar. `DS-T/com/abcfs/club/external/controller/ClubExternalControllerTest.java` currently tests the logo endpoint, not these fields. DT's PR schema (`DT/dtWar/src/test/resources/schema.sql`) already contains all seven new columns, so default H2 tests alone cannot demonstrate pre-migration safety.

## Use Cases

Use two distinct club/VPD contexts and real-shape local fixtures. Fixture club numbers are not claims about configured dev clubs. Every use case has an evidence row in the sprint traceability artifact.

| ID | Behaviour and required result | Scope / tasks |
|---|---|---|
| U1 | New code, old schema, both DT flags off: legacy catalog CRUD/deploy, Edit Club terms, POS completion and both service endpoints still work. No statement mentioning new columns and no `ADD_GUEST` lookup executes. | Seed; A1, B1–B4, C1–C5, E1 |
| U2 | New schema, flags off: identical deterministic SQL/binds, response bytes and rendered page bytes to pinned legacy baseline; no new null/false/zero fields or hidden HTML/JS residue. Existing data in the new columns is untouched by legacy saves. | Seed; A1, B5, C5 |
| U3 | DS flag on for club A only: extended club defaults include valid timezone and base64 liability; club B gets legacy response and SQL. Missing extension row leaves club present; invalid timezone fails BFF club resolution. | G1; B1–B2, D1 |
| U4 | DS flag on: item guest flag, visits, days and type reflect deployed `SALEITEMS` and catalog type. List and single-item reads agree; cross-club item lookup returns no item. Existing price/tax/discount fields retain their semantics. | G1/G12; B3, B5 |
| U5 | Club-only listing before identity succeeds only for enabled clubs and returns online guest-pass products; never calls scheduling/member services. Existing valid-member requests retain service-list membership and appointment enrichment. Missing/empty/invalid member with flag off retains baseline status and envelope. | CF-14/G2; B4 |
| U6 | Enable M&O for an eligible admin context: product flag/days/visits load, validate and save; deployment copies values only to enabled destination clubs. Services/billing cannot become online guest-pass products. A disabled destination retains legacy deployment behaviour. | C1–C2 |
| U7 | Flag turns off between form load and save: new submitted values cannot trigger new-column SQL or validation failures; legacy fields still save, stored new fields are not reset. Edit Club liability field/validation follows the same rule. | C1–C3 |
| U8 | Completed POS sale while flag off: no guest detection SQL, liability read, QR construction or guest-template instantiation; existing webhook/event still runs with its original return/error semantics. Flag on: existing guest email path is reached after context/flag evaluation. | C4 |
| U9 | Direct invocation of guest-email service cannot bypass the guard; empty/unresolvable transaction context fails closed before new SQL. Both POS variants and POSApi/EAE/Pay Page/electronic-agreement call sites obey the invariant. Existing `ADD_PROSPECT` behaviour remains as before. | C4–C5; RQ-0 remains open |
| U10 | MICO JSON/XML consumes flag-on additive fields without breaking existing data; flag-off endpoint serialization is byte-identical under fixed inputs. | B5 |
| U11 | Absent/off/partial/on responses map deterministically: no synthetic fallback, missing/unknown type is rejected, zero/invalid days or visits skipped, visits >1 hidden, unknown timezone closes club, HTTP/service errors close catalog. | D1–D3 |
| U12 | `guest-pass-online` off stops live catalog consumption before upstream fetches even with warm caches; enabled plus no eligible offers renders the current unavailable UI. Nonproduction fixture override does not bypass DS gates. | D2–D3 |
| U13 | Club liability HTML is decoded once, safely rendered, and the sanitized content is what the consent version/hash binds. Null/empty liability uses the existing explicitly reported fallback policy; malicious HTML cannot execute. | G8; D1, D3 |
| U14 | After on-state traffic, BFF exposure off, both DT flags off, in-flight work drained, caches cleared/expired, columns/template rows removed in isolated test schema: U1 passes again with unchanged binaries. | C5, E1, E3 |
| U15 | Missing flag, initial SDK unavailability, evaluation exception, malformed club or unresolved VPD cannot enable new paths. Two clubs in one VPD and two VPDs do not leak state across requests, sessions, jobs or caches. | B1, C1, D2 |
| U16 | Authorized dev execution records pinned deployed revisions, flag context, schema readiness, redacted response provenance and source-switch result, or a precise blocker. Successful read does not imply a paid purchase, email delivery, scanner acceptance or pilot eligibility. | E2–E4 |

## Architecture

### 1. Flags protect operations before database access

Recommend **one schema-dependent feature flag per DataTrak repo**, with the existing BFF exposure flag retained. Separate keys permit independent rollback of the reader and M&O implementation; a shared key couples unrelated release readiness and LD-project configuration. No additional schema-readiness flag is needed for the initial scope: DBA verification is a prerequisite to enabling either DT flag.

| Key (proposed; confirm with Chancy/PK) | Evaluator / scope | Default and protected work |
|---|---|---|
| `datatrak-service-DT-21555-guest-pass-fields` | DS FeatureService, authenticated validated club number + established VPD | False in local/test/dev/stage/prod; new club/item SQL, extended serialization and memberless product listing |
| `datatrak-DT-21555-guest-pass` | DT FeatureService, resolved operation club + VPD | False everywhere; new catalog/liability reads and writes, deployment copies, guest detection and `ADD_GUEST` email path |
| `guest-pass-online` | Existing BFF club-context evaluator | False by default; public Guest Pass access and live catalog consumption; enable per dev club only after upstream verification |

Use canonical club **number**, preserving leading zeroes, for LD club keys in both Java repos and the BFF. Resolve internal SPL IDs and transaction IDs through existing-schema lookups; never send an internal ID as though it were a club number. Require known context and evaluate with `false`, handling exceptions as disabled. The caller's query string is not authorization or evidence of a valid club/VPD. Maintain existing authentication, tenant routing and validation before exposing data.

Use a small testable per-repo helper and an operation-scoped decision shared by SQL selection and serialization. Off selects the original query/bind list/mapper; on selects the extended variant. Do not put new identifiers inside SQL `CASE`, `COALESCE`, a disabled WHERE clause or a join executed for every request: Oracle still resolves them. Do not attempt new SQL and treat “invalid identifier” as the flag mechanism. Row mappers must not read columns absent from the selected query.

A default of false does **not** guarantee a previously enabled SDK forgets cached true values during an LD outage. Shutdown requires observed off evaluation on every relevant instance and drained work; if off propagation cannot be verified, leave schema intact and stop activation/rollback. A request already admitted on may finish before draining. No promise of instantaneous revocation is made.

**Shared catalogs and bulk jobs:** determine the editing context separately from each destination club. CGI data can be shared across clubs; per-club flags govern use, not separate storage of catalog values. Off admin context uses original catalog SQL. Enabled admin context may change shared guest metadata, but per-destination SAI propagation must resolve and evaluate that destination. Partition mixed batches before generating SQL; a missing club context does not fall back to a globally enabled flag. A disabled destination receives only legacy fields. Register the explicit synchronization/redeploy needed when that destination later becomes enabled; do not mutate all disabled clubs to zero. Confirm this scope in A3 before coding the bulk paths.

### 2. Wire contract v4.1: additive and optional

Propose retaining the BFF's synthetic names to minimize churn, subject to DS/DT owner confirmation in CF-13/CF-19. These are **proposed names**, not observed service fields. Contract document v4.1 records the upstream agreement; do not change the browser's runtime contract-version string unless browser DTOs actually change.

| Response field | Source | Flag-on wire convention | Off |
|---|---|---|---|
| `saleItems.saleItem[].guestPassOnline` | `SALEITEMS.SAI_GUEST_PASS` | Boolean from explicit `'1'` / `'0'`; null/invalid cannot confer eligibility | Absent |
| `…contractDays` | `SAI_GUEST_PASS_CONTRACT_DAYS` | Nullable integer; preserve invalid/missing data for rejection, no default to 1 | Absent |
| `…visits` | `SAI_GUEST_PASS_VISITS` | Nullable integer; DT supports 1–100, online v1 accepts exactly 1 | Absent |
| `…itemType` | `CATALOGITEMS.CGI_SERVICE` | `PRODUCT`, `SERVICE`, `BILLING`; unknown/null rejected by BFF | Absent |
| `club.waiverText` | `SPL_EXTENSIONS.SPLEX_PROSPECT_LIABILITY` | UTF-8 base64 HTML, nullable for missing/empty text | Absent |
| `club.timezone` | `TIMEZONELOOKUP.TZL_ABC_CODE` via SPL | Validated IANA-compatible string; invalid/missing not replaced by server zone/GMT | Absent |

`prospectTerms`, existing JSON/XML wrappers, names, types, price formatting, ordering and status envelopes remain unchanged. A missing waiver differs from a missing required timezone or item discriminator. Preserve current waiver fallback semantics pending CF-18; capability evidence states whether content came from the club or a template.

**Club DTO recommendation:** retain the original shared DTO instance and legacy mapper on the off path; use a local `GuestPassClubDefaultExternal extends ClubDefaultExternal` only on the on path, populated from a separate extended mapper/enrichment result. Preserve the existing response envelope and fields, including branding/hideEnrollPage. Do not use JSON-only `@JsonUnwrapped`, dynamic maps or globally changed null serialization to work around a shared Java type. A half-day spike must prove subclass fields survive the actual MVC JSON and XML converters without unwanted type attributes/root changes and are tolerated by MICO. JAXB polymorphism is a risk, not a solved detail. If the spike fails, use an additive shared-interface release with nullable omitted extension fields; record the extra repo/version/release dependency and keep activation blocked until proven. A local full response replacement is a higher-maintenance fallback requiring owner approval and complete parity tests, not an automatic shortcut.

Item fields can use nullable local DTO fields with per-field JSON omission and optional non-nillable XML elements, or an extended local subtype if the converter tests require it. Primitive defaults must not appear when off. Explicit off-byte goldens decide the implementation, not assumed annotation behaviour.

**Club query:** leave `GET_CLUB_DEFAULT_EXTERNAL` untouched. Add an on-only query/projection with a left join to SPL extensions on both SPL and VPD and a left join to the existing timezone lookup. Preserve club activity/physical-location predicates and VPD isolation. Null extension rows must not remove valid clubs. Validate zone IDs strictly in Java and against Node's timezone support; aliases need an explicit tested map, not silent fallback. No timezone DDL is planned.

### 3. Sale-item paths: bounded G2 and G12 work

Retain both legacy SQL constants and mapper paths. For valid-member requests with DS flag on, extend the existing list/single query with fields while retaining its service-only selection and appointment logic. This adds truthful item type without injecting products into MICO's current shop.

For an enabled **memberless** request on the same `saleItems.spr` endpoint, use a separate guest product query: active sale item and catalog item, requested club, `cgi_service = '0'`, guest-pass flag on, and the confirmed online-availability rule. Recommended initial rule retains `cgi_online = '1'`; confirm how admins set this for products in A3 and the enablement guide. Select SAI days/visits, not catalog defaults, so the response reflects deployed club data. Retain price/tax/discount semantics; do not add new quantity or pricing policy under G1. Single `saleItemId` lookup uses the same club/type/availability restrictions. Skip all member scheduling calls; do not fabricate a member GUID or borrow another person's identity.

Preserve flag-off missing-member behaviour, including Spring's missing-parameter 400 versus the empty-member legacy error envelope. Prefer distinct MVC mappings for member-present and member-absent requests, delegating the absent path to a guard that reproduces the baseline missing-parameter failure when off. If making the parameter optional internally is simpler, explicit request/response tests must preserve those observable distinctions. A supplied invalid member remains invalid; it must not silently become a guest catalog request. Empty-member behaviour is frozen explicitly in A3. Existing authentication stays on both mappings.

Alternative: a sibling club-scoped endpoint is cleaner in isolation but adds a permanent API and adapter path; use only if owners reject the bounded memberless branch. Deferring G2 is allowable only with live catalog verdict **blocked CF-14**; it does not make G1 usable. G12 query selection and truthful type mapping cannot be omitted from a claimed successful live catalog.

### 4. M&O guard inventory and unchanged legacy operations

| Dependency | Required gate placement / legacy action | Source |
|---|---|---|
| Catalog SELECT and mapping | Decide before building/executing SELECT; off mapper never reads guest columns | `DT-J/com/seqtek/abcfs/dt/inventory/catalogItems/CatalogItemsDB.java` |
| Catalog INSERT/UPDATE | Select original statement **and original bind positions** when off; ignore posted guest fields; preserve existing guest data on new schema | Same; `EditCatalogItemsState.java`, `EditCatalogItemsSecondaryPage.java` |
| Catalog-to-sale deployment/sync | Gate both static and Spring DAO insert/update paths, including existing/new destination rows and multi-club calls | Same; `DT-J/com/abcfs/inventory/catalogItems/repository/CatalogItemDaoImpl.java` |
| Catalog page and validation | Server-side suppress markup, initialization JS, new validation/messages and guest-state-dependent normalization when off; do not merely hide controls with CSS | `DT/dtWar/src/main/webapp/jsp/inventory/catalogItems/EditCatalogItemsSecondaryPage.jsp`; inspect bootstrap/alternate render paths |
| Edit Club load/save | Off executes original terms query/write; on-only liability join/mapper/write; gate posted values and length validation | `DT-J/com/abcfs/repository/editClub/{EditClubOnLineDao,EditClubOnlineDaoImpl}.java`, `.../services/EditClubServiceImpl.java`, `.../cfg/editclub/online/EditClubOnlineProspect.java` |
| Liability page / email accessor | Restore legacy terms layout/height when off; gate accessor before SQL, return absent internally; missing SPL extension row behaviour must be defined | `DT/dtWar/src/main/webapp/jsp/editClub/online/EditClubOnlineProspect.jsp`; `DT-J/com/abcfs/repository/eae/{ClubDao.java,jdbc/JdbcClubDao.java}` |
| POS guest detection | Resolve transaction club with old-schema SQL, evaluate flag, then execute guest-item detection | `DT-J/com/abcfs/sales3/repository/PointOfSaleDaoImpl.java`; `.../services/ProspectServiceTransactionsImpl.java` |
| Guest email/template | Guard public service entry and POS call sites before guest SQL, content/QR construction and `ContentsSuppliedEmail(ADD_GUEST,…)`; preserve ordinary prospect mail | Same; both `com/seqtek/abcfs/dt/sales{,3}/common/repository/PointOfSaleDB.java` |
| Completion event | Flag suppresses only the added guest work; normal publication, transaction handling, return value and error isolation continue | Both PointOfSaleDB classes; `DT-J/com/abcfs/{domain/pos/POSApi,api/EAEApi,commerce/pospaypage/service_v2/checkout/PosPayPageCheckoutCompleteService}.java`; `.../paperless/electronicAgreement/ElectronicAgreementDB.java` |

The email service currently checks `transactionContainsGuestPassItem` **before** resolving the club. Reorder using the existing-schema transaction context, then guard, then query. Guarding only `sendMemberEmail` is too late. Audit other callers of every new DAO method; either they carry a validated operation decision or the DAO resolves/rechecks context safely. Do not disable all POS completion processing with the new flag. Generic administration that lists existing email types must tolerate absence of the new rows; dedicated `ADD_GUEST` selection/sending is guarded.

Liability size is Terry's schema decision. The current PR validates Java string length against 4000, which is not proof of fitting Oracle byte semantics. A3 must agree on encoding/byte limit or a DBA-owned type change; the enabled form rejects over-limit input before SQL, without truncating legal text. Off must retain baseline validation and layout.

### 5. BFF consumption, cache and evidence

Keep Oracle access behind the DS service. Move the BFF club exposure check ahead of live catalog reads using the same normalized club context; enforce it at the adapter entry points as well if any callers bypass route middleware (demo, host bootstrap, purchase refresh). No new DT-LD key is evaluated speculatively in the BFF's separate project. `STP_CATALOG_SOURCE` selects an adapter; it is not a database kill switch. The DS flag remains the authoritative guard on every schema-dependent service read.

Make `mapSaleItem` accept only an explicit recognized type and require required guest fields before eligibility. Make `mapClubDefault` validate timezone support. Preserve existing commercial and single-visit filters. Decode base64 UTF-8 and sanitize club-authored HTML before consent rendering/version/hash creation. `UI/.../DocumentDialog.tsx` calls `html-react-parser`, and `STP/fixtures/consentTemplates.ts:211` directly uses club HTML; neither inspected path establishes sanitization. Choose an existing approved sanitizer if available, otherwise add a narrowly scoped tested dependency. This is protection of the newly live content path, not a UI redesign. Keep malformed encoding distinguishable from intentionally absent waiver text.

Capability evidence records source, club/VPD where known, service revision, timestamp, field completeness, DS key name, and flag **observation**: `confirmed-on`, `confirmed-off`, or `unknown`, with provenance. Missing fields alone cannot distinguish old code, off flag, absent schema or a mapping bug. Do not emit off-state JSON fields merely to advertise a flag: that violates legacy byte equivalence. The smoke/runbook attaches operator-confirmed LD evaluation evidence; the runtime report remains `unknown` unless a separately proven service signal supplies it. Adapter `status: live` describes implementation, not verification.

Evaluate exposure on every request before using cached offers; no flag-off cache hit may authorize the route. Test separate club and offer cache ages and on→off transitions. Rollback disables BFF exposure first, observes off, clears/restarts caches on every BFF pod or waits the configured maximum TTL after in-flight reads finish, and then disables/drains DS and DT. In local proof use `clearCache()` and a fake clock; do not add a public cache-clear endpoint. A DS-only flag flip may leave a BFF cached offer visible until expiry, so it is not the documented full exposure rollback.

### 6. Schema lifecycle and runbook contract

Execution creates `docs/deploy/guest-pass-db-and-flags.md`. It specifies each environment, actual owner, pinned revisions, precondition, command/query or request shape, expected observation, timeout and inverse action. This draft does not execute these steps. Production entries document a later handoff only; every production flag stays off.

Prefer scripts → code off → per-club dev activation for the normal rollout, while explicitly proving code off → scripts as a supported alternative. DS main auto-deploys to dev (`DS/.github/workflows/ci-trunk.yml`), so default-off safety must exist **before** its PR is merged by the owner.

| Step | Owner slot | Verification | Rollback / stop rule |
|---|---|---|---|
| R0 — Pin release and off flags | Chancy + PK + PLATFORM (name at kickoff) | Correct project/environment, false defaults/off variations, no broad VPD targeting, selected/unselected club evaluations; record existing BFF fixture/override configuration | No changes to database; do not proceed if off is unobserved |
| R1 — DBA preflight and scripts in dev | Terry Smith / DBA | Correct schema, seven column names/types/defaults, timezone lookup, template uniqueness/billing collision check, target club template-location row; approved script checksums and backup/export | Keep flags off; partial migration is incomplete, not enableable; repair or approved rollback |
| R2 — Deploy reviewed code with flags off | Chancy/PK (DT/DS), BFF owner | Pinned image revisions, old-schema test evidence, legacy endpoint and M&O smoke, no added SQL; release/CI evidence | Keep schema additions; revert code if needed; no activation |
| R3 — Enable M&O for selected dev context | Chancy + QA | Save product metadata/liability, deploy item, query SAI values for target club and confirm disabled clubs unchanged; email test only in approved sink | M&O flag off, verify quiescence; retain data while investigating |
| R4 — Enable DS selected club | Chancy/PK + QA | Both service responses, list/single consistency, memberless product result, MICO JSON/XML regression, valid timezone | DS flag off, verify old response after drain; BFF still dark |
| R5 — Wire secret and switch BFF source | PLATFORM + BFF | Secret reference exists without displaying value; `STP_CATALOG_SOURCE=datatrak`, URL configured, fixture fallback absent, mock purchase ports still explicitly labelled | BFF exposure remains off; revert dev source to fixture only if needed, keeping it dark until deliberate mock-demo exposure |
| R6 — Enable BFF selected dev club | PLATFORM + QA | Disable `STP_LOCAL_FLAG_OVERRIDE`; verify real club targeting on/off; unavailable negative control and live-read-only page smoke; attach redacted recordings | BFF flag off first; observe refusal, drain and expire/clear caches; then R4/R3 inverses |
| R7 — Rehearse schema rollback | DBA + Chancy/PK + QA | Both DT flags observed off everywhere, BFF off, jobs/in-flight SQL/email work drained; backup new values; approved drops/deletes in isolated schema; U1 rerun on deployed code | If propagation/drain cannot be proved, **do not drop**. Reapply only approved scripts/data restores with flags off if recovery is needed |

Verification query shapes (DBA executes under the proper schema/VPD; no credentials or customer data in evidence):

```sql
-- Safe before migration: metadata only; expect exactly these seven columns after migration.
SELECT table_name, column_name, data_type, data_length, data_default
FROM user_tab_columns
WHERE (table_name = 'CATALOGITEMS' AND column_name IN
       ('CGI_GUEST_PASS', 'CGI_GUEST_PASS_VISITS', 'CGI_GUEST_PASS_CONTRACT_DAYS'))
   OR (table_name = 'SALEITEMS' AND column_name IN
       ('SAI_GUEST_PASS', 'SAI_GUEST_PASS_VISITS', 'SAI_GUEST_PASS_CONTRACT_DAYS'))
   OR (table_name = 'SPL_EXTENSIONS' AND column_name = 'SPLEX_PROSPECT_LIABILITY');

-- After metadata verification only: verify configured target item, not a full-table dump.
SELECT sai.sai_id, sai.sai_guest_pass, sai.sai_guest_pass_visits,
       sai.sai_guest_pass_contract_days, cgi.cgi_service, cgi.cgi_online
FROM saleitems sai JOIN catalogitems cgi ON cgi.cgi_id = sai.cgi_id
WHERE sai.spl_id = :club_id AND sai.vpd_id = :vpd_id AND sai.sai_id = :sale_item_id;

SELECT tzl.tzl_abc_code
FROM serviceproviderlocations spl JOIN timezonelookup tzl ON tzl.tzl_id = spl.tzl_id
WHERE spl.spl_id = :club_id AND spl.vpd_id = :vpd_id;

SELECT COUNT(*) AS guest_template_locations
FROM contactTemplateLocation loc JOIN contactTemplate t ON t.ctem_id = loc.ctem_id
WHERE t.ctem_abc_code = 'ADD_GUEST' AND loc.spl_id = :club_id AND loc.vpd_id = :vpd_id;
```

Add a post-migration liability presence/byte-length check rather than printing waiver content. Verify exact template/header/footer/active requirements from the migration guide; a count alone is not delivery proof. Service checks name only `GET /external/club/getClubDefaultExternal.spr?clubNumber=<club>` and `GET /external/pos/saleItems.spr?club=<club>[&saleItemId=<id>]`, with JSON and XML Accept variants and existing credential injection. No literal authorization header, shell tracing, verbose authenticated curl output or raw pod environment enters evidence.

Rollback deletes template-location dependents before their template as required by DBA scripts, preserves preexisting rows identified by the preflight, and exports guest settings before any drop. Oracle DDL is not a reversible transaction; flags make code compatible, not dropped data recoverable. G9 rerun guards must not reset already configured guest values. Do not rerun the current unconditional full-table UPDATE after activation.

## Implementation Plan

Planning estimate: **10 working days elapsed with a DS owner and DT owner working alongside BFF/QA**, approximately 17–21 engineering person-days plus DBA/platform/review lead time. These are staffing estimates, not a request to spawn agents during drafting. One implementer should budget sequentially. Shared-interface release fallback can extend the calendar. Critical path: A contract/serialization decision → B/C guarded paths → E old-schema/off/on/rollback proof → reviewed deployment → conditional dev read.

### A — Baseline, decisions and contract · days 1–2 · DS + DT + BFF + QA

| ID | Task | Files | Done when |
|---|---|---|---|
| A1 | Pin local/current execution heads and original pre-feature baselines; inventory new identifiers, template code and transitive callers in both Java repos. Record SQL/binds and deterministic JSON/XML/page golden fixtures. Distinguish PR changes from unrelated newer main changes in shallow history. | DS/DT paths in §Overview and §Architecture; proposed per-repo test resources `guest-pass/legacy/**`; proposed `docs/validation/guest-pass-sprint-0005-traceability.md` | Every dependency has a gate and test owner; existing main state is reproducible; no credentials copied; all source claims cite paths |
| A2 | Half-day actual converter/consumer spike for shared club DTO; inspect resolved jar annotations and MVC configuration; prove on-only local subtype or select shared-interface fallback. | `DS-J/com/abcfs/club/external/{controller/ClubExternalController,service/ClubExternalServiceImpl}.java`; `DS/dtWar/build.gradle`; proposed DS serialization tests; MICO reference paths | JSON and XML results support a recorded decision; fallback repo/version/release owner is explicit if needed |
| A3 | Freeze field names/types/encoding, memberless routing, product online-availability policy, club/VPD normalization, shared-catalog target evaluation, liability byte limit and default-off keys. Assign rollout owners/dates. | `docs/contracts/short-term-pass-bff.md` §2/§8/§8a/§10; proposed runbook; CF-13/14 and CF-19…25 | DT/DS/BFF contract agreement recorded; unanswered questions block only named capability; no fake member IDs |
| A4 | Agree delivery branch with Chancy and reserve reviewers. Record scope/cut order and explicit dev recording requirement. | Proposed execution/blocker docs and PR descriptions | Branch strategy approved by owner; implementation can be reviewed without rewriting his branch |

### B — Service endpoints and compatibility · days 2–6 · DS owner, Chancy/PK review

| ID | Task | Files | Done when |
|---|---|---|---|
| B1 | Add default-off key and safe club/VPD helper; resolve correct context before new operations; keep request decisions consistent through mapping. | `DS-J/com/abcfs/launchdarkly/LDFeatureFlagConstants.java`; proposed `.../helper/GuestPassFeatureFlagHelper.java`; `DS/dtWar/src/resources/launchdarkly-local.yml`, `DS/dtWar/test/resources/featureflag-local.yml`; helper/constant/wiring tests | U15 passes for missing/off/error and cross-club contexts; new key false in shipped defaults |
| B2 | Add gated club query/enrichment and optional DTO according to A2; use existing timezone lookup and UTF-8 liability encoding; retain original off mapper and enrichment. | `DS-J/com/abcfs/club/external/{dao/DtManagedClubDao.java,dao/DtManagedClubDaoImpl.java,dao/DtManagedClubSql.java,service/ClubExternalService.java,service/ClubExternalServiceImpl.java,controller/ClubExternalController.java}`; `.../repository/club/mapper/ClubDefaultExternalRowMapper.java`; proposed extended mapper/DTO | U1–U3 pass; absent extension row, empty liability and invalid zone covered; original terms unchanged |
| B3 | Add on-only list/single projections and mappers with guest fields and true product discriminator; member query remains service-scoped; guest product query is distinct. | `DS-J/com/abcfs/repository/pos/{PointOfSaleDao.java,jdbc/JdbcPointOfSaleDao.java,sql/PointOfSaleSql.java,mapper/DiscountOnlineSaleItemMapper.java}`; proposed guest mapper; `.../api/pos/{SaleItem,SaleItemWithDiscount,SaleItemResponse}.java` | U4 passes; disabled calls use exact baseline SQL/binds; no missing-column mapper reads; product data comes from SAI |
| B4 | Implement memberless branch under the DS flag with legacy off validation/status parity; skip member enrichment only on the new branch. | `DS-J/com/abcfs/controller/POSController.java`; `.../validator/OnlinePosValidator.java`; controller/validator tests | U5 passes at HTTP mapping level, including omitted/empty/malformed/present member, list/single, authentication and club isolation |
| B5 | Prove converter bytes and MICO decoding with fixtures; add SQL capture and negative-interaction tests; register every new test in Gradle and inspect generated test reports. | `DS-T/com/abcfs/{club/external/**,controller/**,repository/pos/**,launchdarkly/**}`; proposed `GuestPass*Test` classes/resources; `DS/dtWar/build.gradle` | U1–U5/U10/U15 discovered and run; JSON/XML on/off pass; JaCoCo includes new code; CI/Sonar results linked at delivery |

### C — PR #6643 gating pass · days 2–7 · DT owner, Chancy review

| ID | Task | Files | Done when |
|---|---|---|---|
| C1 | Add DT key/helper and operation-context contract. Gate catalog form/state/validation and original versus extended load/insert/update SQL/binds. Reevaluate at submit rather than trusting session state. | `DT-J/com/abcfinancial/datatrak/common/launchdarkly/LDFeatureFlagConstants.java`; proposed guest helper; local/test flag YAML; `DT-J/com/seqtek/abcfs/dt/inventory/catalogItems/{EditCatalogItemsState,EditCatalogItemsSecondaryPage,CatalogItemsDB}.java`; catalog JSP(s) | U1/U2/U6/U7/U15 pass; off page includes no new guest JS/markup and legacy saves preserve guest values |
| C2 | Gate both catalog-to-SAI implementations and every bulk/direct caller by destination; carry validated context without changing unrelated inventory logic; document later enablement resync. | `CatalogItemsDB.java`; `DT-J/com/abcfs/inventory/catalogItems/repository/{CatalogItemDao,CatalogItemDaoImpl}.java`; calling service methods identified in A1 | New/existing deployment and mixed enabled/disabled clubs pass; off SQL has no CGI/SAI guest identifiers |
| C3 | Split Edit Club and email liability reads/writes into safe off/on branches; gate page layout, validation and service binding; address enabled byte limit and missing extension row. | `DT-J/com/abcfs/repository/editClub/{EditClubOnLineDao,EditClubOnlineDaoImpl}.java`; `.../services/EditClubServiceImpl.java`; `.../repository/eae/{ClubDao.java,jdbc/JdbcClubDao.java}`; `.../cfg/editclub/online/EditClubOnlineProspect.java`; liability JSP | Terms still load/save on old schema; new text round-trips only on; off HTML matches legacy; no posted-value bypass |
| C4 | Resolve transaction club before guest SQL; guard service entry and both completion wrappers; audit every call-site swap; preserve POS event outcomes when guest work is off or fails. | `DT-J/com/abcfs/services/{ProspectServiceTransactions,ProspectServiceTransactionsImpl}.java`; `.../sales3/repository/PointOfSaleDaoImpl.java`; both PointOfSaleDB classes; POSApi, EAEApi, Pay Page completion, ElectronicAgreementDB | U8/U9 pass with `never()` assertions on detection/liability/template construction; existing webhook regression tests still pass |
| C5 | Isolated H2 legacy/extended schemas; capture actual SQL/binds; old→new→rollback lifecycle; pages under fixed session inputs; update existing email/webhook tests and add missing path tests. | `DT/dtWar/src/test/resources/schema.sql`; proposed `guest-pass/schema-legacy.sql` or fixture-generated isolated legacy schema; `DT-T/.../ProspectServiceTransactionsImplEmailTest.java`, both `PointOfSaleDBGuestEmailTest.java`, new catalog/liability/rollback tests | U1/U2/U6–U9/U14/U15 pass with columns **physically absent**, not merely all zero; H2 limitations versus Oracle documented |
| C6 | Optional G9 change only after DBA review: rerunnable additive DDL, preserve existing configured values and document partial application/rollback. | `DT/sql/project-{guest-pass-catalog-item,prospect-liability-language,add-guest-email-type}.sql`; matching `docs/DT-21555-guest-pass-email-prd/sql/` copies | DBA approves exact semantics/checksums and rerun/rollback proof; otherwise defer G9 explicitly without weakening C5/E1 |

### D — BFF contract and UI proof · days 3–7 · BFF + UI/QA

| ID | Task | Files | Done when |
|---|---|---|---|
| D1 | Adopt confirmed fields, strict item-type/zone parsing, explicit encoding and sanitized HTML before consent hashes; keep eligibility rules and fallback policy visible. | `STP/adapters/platform/datatrakServiceCatalog.ts`, `catalogEligibility.ts`, `fixtures/consentTemplates.ts`; proposed consent sanitizer; dependency manifest/lockfile only if needed | U11/U13 pass; malformed fields cannot become a sellable product; no client contract change without reason |
| D2 | Gate live consumption before fetch/cache use, audit route/bootstrap/demo/purchase callers, add honest flag/evidence report and cache transition proof. Preserve production config guard. | `BFF/src/utils/middlewares/requireShortTermPass.ts`; `STP/{flag,config}.ts`, adapter/report types; `BFF/src/routes/shortTermPass/testing/*`; `.env.example`; `BFF/scripts/short-term-pass-demo.ts`; other callers found by A1 | U12/U15 pass; flag-off issues no live request; report distinguishes unknown state from confirmed state; credentials/content excluded |
| D3 | Add response matrix tests and fixture provenance; verify unavailable and consent rendering in existing UI; keep purchase mock regressions. | `STP/fixtures/datatrak/{README.md,*.recorded.json,*.synthetic.json}`; `STP/__tests__/{datatrakServiceCatalog,flag,config}.test.ts`; middleware tests; `UI/src/{utils/featureFlags.ts,routes/ShortTermPass/ShortTermPassPage.tsx}` and matching UI tests | U11–U13/U15 pass; existing UI production source changes only if a regression requires them; mock demo 0–6 passes |

### E — Reviewable delivery, runbook and evidence · days 7–10 · QA + release owners

| ID | Task | Files | Done when |
|---|---|---|---|
| E1 | Assemble safety matrix below, prove rollback locally, run required Java/TS checks and inspect discovery/coverage; document exact failures/unrun checks. | Both Java tests/build reports, BFF/UI tests; proposed `docs/validation/guest-pass-sprint-0005-{smoke,traceability}.md` | All implementation gates have actual local/CI evidence or named failures; no “zero tests” pass |
| E2 | Deliver DS and DT PRs for owner review, BFF PR and conditional signed helm PR; attach contracts, test reports, defaults and rollout ordering. Never merge DT-owned PRs ourselves. | PR descriptions; `HELM/online-join-bff/dev.yaml`; `HELM/datatrak-service/dev.yaml` reference/config only if needed | Reviewable PR links/pinned heads and owners exist; no secret committed; CI/Sonar actual state recorded |
| E3 | Write and, only under execution authorization/access, perform R0–R7 dev steps. Capture redacted state-qualified responses; record exact blocker instead of attempting arbitrary host probes. | `docs/deploy/guest-pass-db-and-flags.md`; fixtures README/recordings; smoke doc; helm dev source change | Dev read and rollback are separately verified or blocked; source switch happens only after prerequisites; production remains off |
| E4 | Update contract, code map, pilot register and ledger; close only evidenced CF/RQ rows; write execution summary and separate blocker rows by repo/capability. | `docs/contracts/short-term-pass-bff.md`, `docs/SEMANTIC-INDEX.md`, `docs/validation/guest-pass-pilot-gates.md`, `docs/sprints/ledger.yaml`; proposed `docs/sprints/drafts/SPRINT-0005-{EXECUTION-SUMMARY,BLOCKERS}.md` | Four-verdict statement complete; every U id maps to gate/evidence; all deferred work retains an owner |

**Cut order:** optional C6 first; convenience capability formatting second; extra visual screenshots last. Do not cut old-schema tests, all dependency guards, XML compatibility, product selection, or rollback proof. If G2, DTO release, DBA/LD/secret access or reviews slip, retain fixture dev configuration and report the corresponding live/deployment gate blocked. A written request for DT gating is not completion of that implementation.

### Required test matrix and execution evidence

| Schema / data | Governing DT flag | Expected result |
|---|---|---|
| Columns/template rows absent | Off / missing / evaluation error | Full legacy operations pass; zero new-column statements/template lookups |
| Columns/rows present with populated guest data | Off | Same legacy SQL/binds/bytes; no clearing of populated guest data |
| Columns/rows present | On, selected club | Correct fields, product query, M&O persistence/sync and guarded email path |
| Same schema/VPD | Off, other club | Legacy operations and no cross-club leakage |
| Partially migrated schema or missing required template-location rows | Off | Legacy safe; preflight blocks enablement |
| Absent/partial schema deliberately misconfigured on | On | Controlled failure/unavailable evidence; no fixture fallback; operator disables flag; never counted as a supported activation |
| On traffic followed by observed off, drain and schema rollback | Off | Same binaries pass old-schema suite again |

For each endpoint, tests cover the full absent/off/on matrix in JSON and XML, list/single where applicable, null/invalid values, errors and context isolation. DS uses mocked JDBC/ResultSet assertions plus actual converter tests; DT adds H2 integration with physically absent columns. H2 is not Oracle proof: DBA dev verification remains separate. Golden bytes use fixed inputs/time/session tokens; normalize only documented nondeterministic transport/session values, never changed fields, markup or SQL. Capture raw deterministic payload bytes as well as semantic assertions.

BFF replays old recorded responses and separately labelled new synthetic/generated contract fixtures until authorized dev recordings exist. New `.recorded.json` files require actual timestamp/environment/club/flag/schema/code provenance and sanitization; a local serializer snapshot is a generated fixture, not a live recording. If dev access is unavailable, that portion remains blocked while local matrix proof remains valid.

Execution commands are run in each owning repo with its configured toolchain: DS/DT Gradle wrapper `:dtWar:test` (Java 17 for DS; inspect DT configuration), DS JaCoCo report and explicit include entries for new tests; BFF `npm test -- --runInBand`, `npm run test:cov`, `npm run lint`, `npm run build`; UI repository equivalents and targeted Guest Pass/unavailable/consent tests. Inspect generated test XML for named classes and nonzero case counts. Run broader required CI/Sonar gates once per final change set; do not lower existing coverage floors (Sprint 0004 UI 80/80, BFF 84/67/67/84, plus current repo configuration). Record preexisting failures by name. No tests or builds were run as part of writing this draft.

## Files Summary

All entries below describe **future sprint execution**, not additional files written during this drafting task.

| Repo | Paths / action |
|---|---|
| DS | MODIFY club controller/service/DAO/SQL and interfaces; retain legacy mapper; NEW on-only club DTO/mapper per A2; MODIFY POS controller/validator/DAO/interface/SQL, optional local item DTO fields; NEW guest product projection/mapper as needed |
| DS | NEW `com/abcfs/launchdarkly/helper/GuestPassFeatureFlagHelper.java`; MODIFY `LDFeatureFlagConstants.java`, local/test flag YAML, `dtWar/build.gradle`; NEW/EXTEND helper, DAO, controller, serialization and consumer compatibility tests and golden fixtures |
| DT PR #6643 | MODIFY catalog state/secondary page/JSP, `CatalogItemsDB`, `CatalogItemDaoImpl` and affected interfaces/callers; Edit Club DAO/service/model/JSP and liability accessor; prospect-email service, guest detection DAO, both POS completion wrappers and audited call sites |
| DT | NEW flag helper and old-schema/off/on/rollback tests; MODIFY flag constants/local/test settings and existing email/POS tests; optional approved SQL changes and test fixture additions |
| BFF | MODIFY `STP/adapters/platform/datatrakServiceCatalog.ts`, `catalogEligibility.ts`, `flag.ts`, middleware and audited callers, consent override path/report types, fixtures/tests/demo/config documentation; NEW narrowly scoped sanitizer/tests if required |
| UI | TEST existing unavailable/flag and consent-dialog paths; no feature redesign or source changes expected beyond a demonstrated regression |
| HELM | CONDITIONAL MODIFY `online-join-bff/dev.yaml`: DS URL, secret reference, source switch, override off; DS chart remains reference unless a concrete change is required; signed commits on master |
| This repo | Future MODIFY contract v4.1, code map, ledger, pilot gates; NEW runbook, smoke/traceability, execution summary/blockers. Optional sync of DBA-approved SQL copies |
| Shared interface repo | CONDITIONAL additive DTO version/release only if A2 rejects the local subtype; owner and exact repo must be confirmed before adding this dependency |

MICO and wallet repos remain read-only references. No code changes belong in `orasvc` merely because MICO's client is named OrasvcClient. The only drafting artifact is this file.

## Definition of Done

**Owner slots:** DS engineer **[name at kickoff]**; DT engineer **[name at kickoff]**; BFF engineer **[name at kickoff]**; UI/QA **[names at kickoff]**; SECURITY **[name at kickoff]**; PLATFORM **[name at kickoff]**; DBA **Terry Smith, subject to acceptance**; DT review **Chancy**; release review **PK**; product/legal **Kelly + Legal** where carried. Bjorn coordinates assignment and dependency dates. Role labels are not signatures; a gate without a named accepting owner cannot pass. No unrun test, unavailable CI result or external handoff is silently marked done.

| Gate | Owner slots | Passes when |
|---|---|---|
| V0 — Inventory and contract | DS + DT + BFF; Chancy/PK | A1–A4 complete, sources/DTO/encoding/flags/product/memberless/context decisions recorded, every dependency has a test, CF owners and dates assigned |
| V1 — DS off safety | DS + QA | U1/U2/U15: unchanged SQL/binds, no missing-column mapping, byte-identical JSON/XML under deterministic inputs, legacy member validation preserved, all tests discovered |
| V2 — DS on and consumer compatibility | DS + QA; Chancy/PK | U3–U5/U10: correct on-only fields, strict zone, truthful type and actual product query, list/single scope, member enrichment preserved, actual MICO JSON/XML compatibility evidence |
| V3 — M&O safety | DT + QA; Chancy | U1/U2/U6–U9: catalog/read/write/deploy/liability/template inventory covered; off pages and events preserved; old-schema H2 tests plus SQL/negative-interaction proof |
| V4 — BFF/UI fail closed | BFF + UI/QA + SECURITY | U11–U13/U15: strict mapping, safe consent content/hash, pre-read exposure guard, no fallback, cache transitions, production guard and unavailable UI pass; mocks/demo remain green |
| V5 — Rollback and migration procedure | Terry + DT + DS + QA | U14 local rehearsal complete; runbook defines preflight, seven columns, templates, partial scripts, off propagation, drain, cache handling and data backup; actual dev rehearsal separately marked verified/blocked |
| V6 — Quality and delivery | Repo engineers + Chancy/PK reviewers | Reviewable implementation PRs, required build/lint/tests/coverage and CI/Sonar green on each applicable code PR; no lowered floors; signed helm PR if needed; no secrets in changes |
| V7 — Dev catalog outcome | PLATFORM + QA + Chancy/PK | U16 evidence states **verified** with both endpoint recordings, product listing and BFF source/flag proof, **or blocked** with exact owner/reason; blocked outcome never counts as live verification |
| V8 — Documentation/status | BFF + DS + DT; Bjorn | Contract/runbook/code map/registers/ledger/traceability updated; every gate states pass/fail/pending/blocked as appropriate; four-verdict completion vocabulary used |

Implementation completion requires V0–V6 implementation evidence and V8. V7 may be recorded blocked under the mock-proven delivery bar; code awaiting required CI or guards is not implementation-complete. A recorded dev blocker satisfies reporting, not live acceptance. Production enablement is never an outcome of this sprint.

**Completion vocabulary — four separate verdicts:**

1. **Implementation and mock acceptance:** `{complete | incomplete, named gate}` — G1 fields and every new-column/template dependency guarded, old-schema/off/on/rollback and consumer tests evidenced, BFF/UI mock acceptance preserved. State PR review/merge status separately from implementation tests.
2. **Standalone dev host:** `{prior state carried, not reverified | verified with evidence | blocked/pending named owner}` — this sprint does not rebuild the host. A catalog page read is not a hosted-card checkout.
3. **Live integration:** DataTrak catalog `{done, pinned dev proof | blocked CF-13/CF-14/CF-19…25 or exact access reason}`; prospect create/update/deactivate remains mock-only; hosted capture retains B1's actual status; QR email/access enforcement remain DataTrak-owned and unverified unless separately evidenced. Catalog success does not close these other capabilities.
4. **Pilot:** **not eligible** until V-P0…V-P6 pass; no production exposure authorized by this sprint. G1 contributes to V-P1 only.

### Carried gates

CF-13 closes only on agreed fields plus actual service/BFF evidence; local implementation without deployment is recorded as implemented, live pending. CF-14 closes only when memberless service behaviour and BFF use are observed. CF-15, RQ-0, CF-08/09/16/18 and B1 carry their previous unresolved status. The inspected post-sale guest email path does not settle pre-payment `ADD_PROSPECT`, recipient identity, online sale trigger or access enforcement. V-P1 still needs durable real operations even after catalog completion; V-P0 and V-P2…V-P6 are unchanged. Sprint 0004 removals and v2 deferrals remain closed/deferred as recorded.

## Risks & Mitigations

| ID | Risk | Mitigation / gate |
|---|---|---|
| R1 | One unguarded mapper, batch writer or template constructor breaks old production schema | A1 exhaustive identifier/caller inventory, C5 physical absence tests, zero-interaction assertions; V1/V3 |
| R2 | Flag conditional embedded in SQL still references missing columns | Separate legacy/on statements and bind lists; tests inspect executed SQL, not just selected values |
| R3 | Local shared-DTO subtype breaks XML or drops new fields | A2 actual converter/MICO spike; shared-interface release fallback; V2 blocks exposure |
| R4 | Service-only query yields no online products, or broadening it changes MICO's shop | Separate guest product query, preserve member selection; confirm online flag policy; U4/U5 |
| R5 | Shared catalog/batch work uses the wrong club/VPD context | Per-destination decisions, canonical club number, mixed-batch and cross-VPD tests; CF-23 |
| R6 | Off pages differ or stale forms clear guest settings | Server-side conditional layout/JS plus submit guard; paired legacy SQL; golden page and retained-data tests |
| R7 | Guest-email gate suppresses normal POS event or is evaluated after guest SQL | Guard guest portion only; resolve club first; test both wrappers and direct service; U8/U9 |
| R8 | LD cached true or in-flight work survives a flip during schema drop | Observe all-instance off, drain jobs/transactions, halt rollback if not observed; R7 runbook step |
| R9 | Cached offers survive upstream shutdown | BFF exposure first, per-request guard, all-pod cache expiry/clear, split-cache tests; no public cache endpoint |
| R10 | Synthetic fixtures or capability labels overstate live proof | Preserve provenance, `unknown` flag state, pinned redacted recordings, four verdicts; V7 |
| R11 | Invalid zone/type or unsafe waiver reaches checkout | Strict discriminators/zone validation, sanitize before hashing, malformed content tests; V4 |
| R12 | H2 passes but Oracle DDL, joins or charset fail | SQL/bind assertions, DBA-owned dev verification, byte limit/preflight, no Oracle claim from H2 |
| R13 | Script rerun overwrites settings or rollback destroys configured data | G9 optional approved guarded rewrite; current script single-application tracking; export new values before drops |
| R14 | Test include list silently excludes new DS tests | Add explicit includes and inspect test XML/counts + JaCoCo; V1/V6 |
| R15 | DT merge auto-deploys before schema/flags are ready | Defaults off and old-schema proof before owner merge; R0/R2; no merge by this team |
| R16 | Reviews, shared jar, DBA, LD or secret handoff exceed sprint | Costed fallback and named CF dates; protect safety scope; retain fixture source, explicit blocked live verdict |

## Dependencies

- **Local project context:** `docs/SEMANTIC-INDEX.md`; cached DS, DT PR branch, BFF/UI and HELM. Wallet index is partial and does not replace source inspection. No token-cache sync or remote history fetch is part of this drafting task.
- **Toolchain:** DS Java 17 at `/Library/Java/JavaVirtualMachines/jdk-17.0.1.jdk`, Gradle wrapper and existing private artifact access during execution; DT's pinned Gradle/TestNG/H2 configuration; BFF Node ≥22/npm ≥10 and UI's declared toolchain. Missing dependencies are recorded, not worked around by disabling tests.
- **Review ownership:** Chancy/PK review DS changes and accept the gating pass onto or stacked after PR #6643. Recommended delivery is a PR targeting his feature branch, approximately 0.5–1 day coordination/review packaging beyond C. A stacked follow-up costs roughly 1–2 extra days for integration/rebase/testing and requires release ordering so the unguarded PR is never deployed alone. A written change request costs approximately 0.5 day but is only a handoff: it leaves V3 and implementation completion pending until Chancy supplies code and proof.
- **DTO fallback:** local subtype estimated 0.5-day spike plus 0.5–1 day implementation/compatibility work inside B; shared-interface option adds roughly 2–4 engineering days plus the owning team's release/review queue. Confirm actual interface repo before promising this route.
- **DBA:** Terry accepts migration window, schema identity, script checksums, template prerequisites/collisions, byte semantics, backup and rollback. No new timezone migration required. Off safety never depends on his scripts landing first.
- **Platform:** named LD owner creates each flag in correct projects/environments with false defaults, canonical context targeting and observed off evidence; named secret owner wires `STP_DATATRAK_SERVICE_AUTH` through secret references; signed helm commits and dev rollout handled by owners.
- **Dev evidence:** authorized VPN/service access and a configured target dev club/product/location mapping; email tests require an approved sink. No remote probing is authorized by this draft-writing request. Future unobserved checks stay unobserved.
- **Carried dependencies:** B1 hosted capture, real prospect/sale/payment ports, durable state, Cloudflare and all pilot/legal gates retain prior owners. They do not block local safety implementation, but they block their named live/pilot claims.

## Open Questions

These recommendations make the draft executable while leaving owner decisions visible. Dates below are kickoff-relative deadlines; replace with actual dates and accepting names, not inferred commitments. Existing register IDs keep their meanings; new IDs below are proposed continuations to reconcile at kickoff.

| ID | Decision / question and proposed answer | Owner / due | Effect if unresolved |
|---|---|---|---|
| CF-13 (carried) | Confirm proposed `guestPassOnline`, `contractDays`, `visits`, `itemType`, `waiverText`, `timezone`, exact null/encoding semantics and on-only exposure | Chancy + DS + BFF / day 1 | Freeze local synthetic contract only; live blocked |
| CF-14 (carried) | Accept gated memberless same-endpoint branch, preserve off missing-member 400 and empty-member envelope; no member enrichment; sibling endpoint only if rejected | Chancy/PK / day 1 | Live catalog blocked; no fabricated member |
| CF-19 (new) | Does the local club subtype serialize correctly through actual JSON/XML converters and MICO decoders? Prefer subtype only after A2; otherwise shared-interface release | DS + PK / day 2 | V2 blocked; jar release dependency named |
| CF-20 (new) | Accept per-repo keys, false defaults, club-number/VPD context and actual LD projects; who owns each environment's changes? | Chancy/PK + named PLATFORM / day 1 | Default-off code can proceed; no activation |
| CF-21 (new) | Normalize only validated timezone aliases or emit canonical source IDs? Prefer strict supported IDs with explicit alias mapping where needed | DS + BFF + DBA / day 2 | Affected club remains unavailable; no GMT fallback |
| CF-22 (new, G8) | Confirm base64 UTF-8 HTML and actual Oracle byte/character limit; is CLOB needed? Who handles absent SPL extension rows on save? | Terry + Chancy; Kelly/Legal on content / day 2 | Enabled liability persistence/real-content acceptance blocked; off safety unaffected |
| CF-23 (new) | Confirm shared-catalog admin context and each deployment target's gating; is `cgi_online` independently required for guest products, and how is it set? | Chancy + DT + PRODUCT / day 1 | Catalog propagation/usable live product blocked; no broadening by assumption |
| CF-24 (new) | Accept PR onto `feat/NOJIRA-guest-pass-email` (recommended) versus gated stacked release? Assign ticket/title per `DT-21555`/`DT-21560` convention | Chancy + Bjorn / day 1 | Code may be prepared, but DT delivery pending; written request is not implementation |
| CF-25 (new) | Accept named DBA, DS/DT flag, BFF secret and helm rollout owners and dates; record schema/flag state evidence without changing off wire bytes | Terry + Chancy/PK + PLATFORM / day 2 | Source stays fixture; V7 blocked with exact missing prerequisite |
| RQ-10 (new, G9) | Rewrite script DDL/rerun behaviour now? Prefer optional DBA-reviewed improvement after core guards | Terry / day 3 | Keep current script risks in runbook; never rerun unconditional UPDATE on configured data |
| RQ-11 (new) | What is measured flag propagation/drain/cache bound, including SDK disconnected state and background operations? | PLATFORM + DT/DS + QA / before E3 | No schema removal or claimed rollback verification |
| RQ-0 / CF-15 (carried) | Confirm online create/email/sale timing and real prospect create/update/deactivate contract | Chancy + Mark / pilot gate | V-P0/V-P1 blocked; catalog read does not close them |
| CF-08/09/16/18 (carried) | Existing legal copy, opt-in, refund and missing-waiver decisions | Kelly + Legal + Chancy / existing gates | Keep explicitly reported current policy; no legal approval implied |

**Deferred without reopening:** all other handoff findings remain with their existing owners; multi-visit offers, future start dates, pass-page/QR implementation in the BFF, direct database adapters, harness agents and production club enablement stay outside Sprint 0005.
