# Sprint 0005: G1 — the guest-pass fields through the DataTrak service layer, with every production DB dependency behind a feature flag

**Status:** draft (Claude lane), 2026-10-07 — written from `docs/sprints/drafts/SPRINT-0005-INTENT.md` and the token cache (`repos/datatrak-service`, `repos/datatrak` branch `feat/NOJIRA-guest-pass-email` = PR #6643, `repos/online-join-bff`, `repos/online-join-ui`, `repos/helm-configs`, `repos/mico` as a consumer reference). For critique, interview and merge. Owners named at kickoff.

**Sources (precedence in this order):** the intent's seed and flag rule; `docs/DT-21555-guest-pass-email-prd/REVIEW-2026-09-23.md` (G1, touching G2, G8, G9, G12 where the same code path is opened); `docs/contracts/short-term-pass-bff.md` v4 (§8, §8a, §10); `docs/validation/guest-pass-pilot-gates.md` (V-P1a/b); `docs/sprints/SPRINT-0004.md` (conventions, verdict vocabulary); the code facts below, which **override** the intent where they differ (five corrections are recorded in §Overview).

## Pyramid Index

- **L0:** Expose the guest-pass sale-item fields, the club liability text and the club timezone on the two DataTrak service-layer responses the Guest Pass BFF reads, widen the online sale-items query so flagged **products** can appear at all, and put every read or write of the new production columns — in datatrak-service, in Chancy's datatrak PR #6643, and in the BFF's consumption — behind LaunchDarkly flags that default off everywhere, so that code deploys before the DBA scripts, the scripts can be rolled back under deployed code, and the live catalog read (Sprint 0004 verdict 3) is switched on per environment and per club after the scripts land and off again without a release. Proven mock-first in this repo's stack; the dev live read recorded as done or blocked with the exact reason; no production exposure.
- **L1:**
  - **A — Freeze and feasibility (~1.5 days, one session).** Field-name table (contract v4 → v4.1), two flag keys, the DTO decision (local response pair, not a jar bump), the `cgi_service = '1'` finding and the `guestPass=true` request shape, MICO consumer check (JSON and XML tolerance), timezone value list requested, delivery into Chancy's branch agreed, branches and ledger.
  - **B — datatrak-service PR (~4 days, DT-service lane).** Flag `datatrak-service-DT-21555-guest-pass-fields` (club context); `getClubDefaultExternal.spr` gains `prospectLiability` (base64 HTML, same convention as `prospectTerms`) and `timezone` via a local response pair when on; `saleItems.spr?guestPass=true` lists flagged products without a member id and carries `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType` when on; flag off ⇒ the `main` SQL strings and classes verbatim; golden tests both ways (SQL string and JSON/XML shape); tests added to the `build.gradle` include list; Sonar green.
  - **C — datatrak PR #6643 flag-gating pass (~2.5 days, DT-M&O lane).** Flag `datatrak-DT-21555-guest-pass` (club context) guards the catalog-item fields and sync, the Edit Club liability field, the POS completion hook's guest-pass email and the `ADD_GUEST` template lookup; `main` SQL retained verbatim as the off-branch; Mockito tests for both states in the PR's own style; delivered as a PR **onto** `feat/NOJIRA-guest-pass-email` with a per-site review map; G9 script rewrite offered as a separate commit.
  - **D — BFF/UI consumption (~2.5 days, BFF lane).** Adapter on the confirmed names and the `guestPass=true` call; the {columns absent, flag off, flag on} × {club defaults, sale items} matrix on recorded and labelled fixtures; timezone validated, unknown ids fail closed; capability report names the inferred DT flag state; club liability HTML path checked; dev switched to `STP_CATALOG_SOURCE=datatrak` only after the DT dev flag is on, otherwise recorded pending with the reason; UI unchanged beyond proof.
  - **E — Runbook, proof, docs (~1.5 days, orchestrator).** `docs/deploy/guest-pass-db-and-flags.md`: ordered steps (flags created → code with flags off → scripts → M&O flag → service flag → BFF source switch → `guest-pass-online` per club), each with owner, verification and rollback; registers, contract v4.1, pilot gate V-P1a rewritten, smoke §live for this sprint, ledger, PR descriptions, four verdicts.
- **L2:** §Overview (what orientation got right, five corrections, seven positions) · §Use Cases (U1–U22) · §Architecture (flags; club defaults; sale items; M&O gating; BFF matrix; rollout order) · §Implementation Plan (A–E with files and "done when") · §Files Summary · §Definition of Done (V0–V7; pilot gates touched; completion vocabulary) · §Risks & Mitigations · §Dependencies · §Open Questions (CF-19…, RQ-10…).

## Overview

Sprint 0004 left the Guest Pass BFF reading the DataTrak service layer through `DatatrakServiceCatalog` and failing closed, because the two `.spr` responses carry none of the fields it needs (CF-13) and `saleItems.spr` is member-scoped (CF-14). The handoff review found the cause (G1): Chancy's work adds columns and M&O screens but never touches the web-service layer. Orientation then found that the layer lives in a **second repository**, `abcfinancial/datatrak-service`, so G1 is a second DataTrak PR. This sprint writes that PR, flag-gates Chancy's PR so neither repo ever executes SQL against a column that may not exist, aligns the BFF, and writes the rollout order down with owners. It does not merge anything in the DataTrak repos, does not run scripts, does not flip a production flag, and does not claim a live read it cannot observe.

### Corrections to the intent (read during drafting, 2026-10-07; cite these)

1. **The online sale-items query returns services only.** `GET_ONLINE_SALE_ITEMS` in `repos/datatrak-service/dtWar/src/com/abcfs/repository/pos/sql/PointOfSaleSql.java:25-45` filters `cgi.cgi_service = '1' and cgi.cgi_online = '1'`. Chancy's PR makes guest passes **products** (`CatalogItemType.product` = code `"0"`, `EditCatalogItemsState.java:21-25`; `guestPassItem = productItem && …` in the `CatalogItemsDB` hunk). Adding fields to the response is therefore not enough: a flagged product would never be a row. The flag-on query must also admit `sai.sai_guest_pass = '1'` products. The review did not know this; G12's "item type" field becomes essential, not optional.
2. **Adding rows is not consumer-safe; adding fields is.** MICO reads `saleItems.spr` as JSON (`repos/mico/src/main/java/com/abcfs/feignclients/OrasvcClient.java:95`, `produces = APPLICATION_JSON_VALUE`) into a mapper with `FAIL_ON_UNKNOWN_PROPERTIES=false` (`repos/mico/src/main/java/com/abcfs/repository/WsShop.java:46`) — new **fields** are safe, but new **rows** would put guest passes in the member shop. The widened query must sit behind a request parameter the BFF sends and MICO never does (`guestPass=true`), on top of the flag.
3. **The club-defaults DTO comes from `com.abcfinancial.rest.api:internal-interface:4.2.0`**, a direct dependency (`repos/datatrak-service/dtWar/build.gradle:136`), not transitively via `dt-interfaces`/`abc-common`. `ClubDefaultExternal` is JAXB-annotated (`@XmlElement` on every field) and `ClubDefaultExternalResponse` carries `@XmlRootElement` (javap of the cached 4.1.0 jar). The XML path is JAXB (`jaxb-runtime 4.0.0`, `build.gradle:114`; `SpringConfiguration.java:176` customises only the JSON converter), so a runtime subclass placed in the jar-typed `club` field would serialise in JSON and fail in XML. MICO's `WsClubDefaults.getDtClubDefaultExternal` uses `RestTemplate.getForObject(…, ClubDefaultExternalResponse.class)` (`repos/mico/src/main/java/com/abcfs/repository/WsClubDefaults.java:221-231`) with the default converter set, which lists XML before JSON in `Accept` — MICO most likely receives **XML** from this endpoint (A2 verifies).
4. **Timezone source.** `JdbcClubDao.getLocalTimeZoneAbcCode` does not exist in datatrak-service. The lookup is `select tzl.tzl_abc_code from serviceproviderlocations spl join timezonelookup tzl …` in `repos/datatrak-service/dtWar/src/com/abcfs/repository/dbUtil/ClubDaoImpl.java:49-54` (private `getTimezone(clubId)`), `com/seqtek/abcfs/dt/util/TimeZoneSupport.java:58-62` (`getTimezoneForClub`) and `com/seqtek/abcfs/dt/common/ClubDB.java:1271`. The value feeds `TimeZone.getTimeZone(...)` (`TimeZoneSupport.java:81`), so it is a Java zone id; whether every row is an IANA id is unknown (RQ-11).
5. **No H2 harness is wired in datatrak.** `dtWar/src/test/resources/schema.sql` carries the new columns, but no test under `dtWar/src/test/java` loads it (`rg` for `schema.sql`, `jdbc:h2`, `EmbeddedDatabaseBuilder` finds nothing); the PR's own tests (`PointOfSaleDBGuestEmailTest`, `ProspectServiceTransactionsImplEmailTest`) are Mockito/`mockStatic`. The gating tests in C follow that style plus SQL-string goldens; "H2-backed both states" in the intent is not available. Also: datatrak-service's `FeatureService` (`dtWar/src/com/abcfs/launchdarkly/FeatureService.java`) has `isFeatureFlagOn(key[, kind, value])` and `computeBooleanFeature(key, vpdId, clubIdOrNumber, default)` only — `isFeatureFlagOnSafe` exists in **datatrak** (`com/abcfinancial/datatrak/common/launchdarkly/feature/FeatureService.java:26`), not here. The datatrak-service README still says the test task is disabled; `build.gradle:256-305` now runs an `include` list.

### Positions taken (the interview settles them)

| # | Question (intent §Open Questions) | Position | Alternatives costed |
|---|---|---|---|
| P1 | DTO strategy for `ClubDefaultExternal` | **Local response pair** in datatrak-service: `GuestPassClubDefaultExternalResponse` (`@XmlRootElement(name = "clubDefaultExternalResponse")`) whose `club` is `GuestPassClubDefaultExternal extends ClubDefaultExternal` with two new `@XmlElement(required = false)` fields. Flag off → the untouched jar classes (byte-identical); flag on → the local pair. No cross-repo release; JAXB knows the declared type. | Jar bump of `internal-interface` (another repo, release, two bumps; cleanest long-term — recorded as the v2 follow-up, RQ-12). Runtime subclass in the jar-typed field (breaks XML — rejected). Sibling endpoint (G1 asked for the same response; MICO path untouched either way — fallback if PK refuses the pair). |
| P2 | Flag granularity and naming | **Two keys, one family, club context, default off:** `datatrak-service-DT-21555-guest-pass-fields` (constant `GUEST_PASS_FIELDS` in `LDFeatureFlagConstants`, evaluated with `computeBooleanFeature(key, vpdId, clubNumber, false)`) and `datatrak-DT-21555-guest-pass` (datatrak `LDFeatureFlagConstants`, same evaluator). The repos deploy independently and the rollout flips them at different steps. | One shared key read by both (one switch, but a flip exposes the service fields before the M&O columns are populated, or vice versa). Global/VPD-only context (loses per-club pilot). |
| P3 | Delivery into Chancy's PR | **PR onto `feat/NOJIRA-guest-pass-email`** (base = his branch) with a review-comment map listing every gated site, agreed with Chancy first (CF-19). ~2.5 days. | Stacked follow-up to `main` after #6643 merges (same code; leaves a window in which unflagged SQL is on `main` — violates the seed). Written change request only (~0.5 day, no guarantee of timing; it is produced anyway as the review map). |
| P4 | G2 inside G1 | **Yes, scoped:** `saleItems.spr?guestPass=true` with the flag on makes `memberId` optional and skips the appointment enrichment (club-scoped listing). Without the parameter, or with the flag off, a missing `memberId` reproduces today's 400 exactly (`MissingServletRequestParameterException` thrown by hand). | Sibling endpoint `/external/pos/guestPassItems.spr` (cleaner isolation; a second controller method and MICO-irrelevant — fallback if PK prefers). Leave G2 to a later sprint (the live read stays blocked — defeats the sprint). |
| P5 | Timezone format | Emit `TZL_ABC_CODE` **normalised**: `ZoneId.of(code)` → `getId()`; failing that `ZoneId.of(code, ZoneId.SHORT_IDS)`; failing that emit the raw code and log once per club. BFF validates with `Intl.DateTimeFormat` and fails the club closed on an unknown id (today's behaviour, now explicit). | Raw code only (BFF must know Java legacy ids). Lookup table in the BFF (two sources of truth). |
| P6 | Liability text size/format (G8) | **Wire convention only:** `prospectLiability`, base64 of the stored string, exactly like `prospectTerms` (`ClubDefaultExternalRowMapper.java:28-32`); column type stays Terry's (CF-21). BFF decodes with the existing `decodeBase64Html` and the UI shows it through the path the club waiver already uses (D5 checks whether that path renders HTML or text and sanitises if HTML). | CLOB + plain text (column change in another owner's hands; not this sprint's call). |
| P7 | Verifying "byte-identical when off" (Q8) | **Both.** SQL-string goldens (`ArgumentCaptor` on `NamedParameterJdbcTemplate`; the captured string equals a test constant copied from `main`) and shape goldens (serialise the flag-off response through the app's Jackson converter and a JAXB context; compare key sets and element names to the recorded §8a fixtures). Plus an `rg` map: every hit for `GUEST_PASS`, `SPLEX_PROSPECT_LIABILITY`, `ADD_GUEST`, `guestPass` in both repos is listed with its guard. | Either alone (SQL goldens miss serializer drift; shape goldens miss a stray column read). |

### What stays with its owner

G3 (POS sets the prospect window), G4/CF-15 (`addProspect` contract), G5/RQ-0 (two emails), G6 (email content), G7 (PRD wording for the new email type), G10 (returns), G11 (recipient), G13 (enablement guide), G14 (deployment details) are not opened here except where a sentence in the runbook or a register row records them. The LD flag `guest-pass-online`, the DT credential secret and Cloudflare remain PLATFORM/PK handoffs (contract §10).

## Use Cases

Environments named per check: **unit** (Gradle/jest), **mock** (BFF fixtures), **dev** (the dev cluster, VPN, credential never printed). Clubs: `09003` (the dev club recorded in §8a) for datatrak-service; a dev test club Chancy flags for the end-to-end step (RQ-13). Fixture clubs 90030/90033 stay for the mock lane.

| ID | Behaviour and required result | Source | Tasks |
|---|---|---|---|
| U1 | **Service flag off (default):** `GET /external/club/getClubDefaultExternal.spr?clubNumber=09003` answers the same JSON and XML as `main` — same SQL string, same classes, same key set and element order; the recorded `fixtures/datatrak/getClubDefaultExternal.recorded.json` key set matches | seed rule; §8a | B2, B4 |
| U2 | **Service flag on:** the response adds `club.prospectLiability` (base64 of `SPL_EXTENSIONS.SPLEX_PROSPECT_LIABILITY`, `""` encoded when null — like `prospectTerms`) and `club.timezone` (normalised zone id from `TIMEZONELOOKUP.TZL_ABC_CODE`); every existing field unchanged; XML and JSON both carry the two elements | G1, G8, P1, P5 | B2, B4 |
| U3 | **Service flag on, columns absent (scripts not yet run):** the flag-on club query fails with the Oracle missing-column error → the service logs `guest-pass.columns-absent {club}` once and answers the flag-off shape (reads are self-healing; no 500) | seed (a) | B2, B4 |
| U4 | **Sale items, flag off or no `guestPass` param:** `GET /external/pos/saleItems.spr?club=&memberId=` returns today's rows, fields and SQL; a request without `memberId` still answers Spring's 400 problem detail (`Required parameter 'memberId' is not present.`) | seed rule; §8a; P4 | B3, B4 |
| U5 | **Sale items, flag on, `guestPass=true`, no `memberId`:** 200 with the club's active, online items where `cgi_service = '1'` **or** (`sai_guest_pass = '1'` and `cgi_service = '0'`); each item carries `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType` (`PRODUCT` / `SERVICE` / `BILLING`); the appointment/services-to-fund enrichment is skipped; `bookOnline=false`; MICO-shaped fields untouched | G1, G2, G12, correction 1 | B3, B4 |
| U6 | **Sale items, flag on, `guestPass=true`, `memberId` present:** same rows as U5 plus the enrichment MICO gets today (no behaviour lost) | P4 | B3 |
| U7 | **Sale items, flag off, `guestPass=true`:** the parameter is ignored; behaviour identical to U4 (a stale BFF cannot widen the list) | seed rule | B3, B4 |
| U8 | **Consumer safety:** the flag-on JSON of both endpoints deserialises into MICO's classes (`ClubDefaultExternalResponse` from `internal-interface` 4.1.0; `SaleItemResponse` in `repos/mico/src/main/java/com/abcfs/dto/response/`) with no error; the flag-on XML of club defaults unmarshals with a default JAXB context (unknown elements ignored) — unit tests in datatrak-service using the jar classes | correction 2–3 | A2, B4 |
| U9 | **M&O flag off:** catalog-item pages (`EditCatalogItemsState`, `EditCatalogItemsSecondaryPage(.jsp)`), `CatalogItemsDB` select/insert/update and the sale-item sync, Edit Club → Online prospect page and `EditClubOnlineDaoImpl`, Fast Add, POS completion in both `PointOfSaleDB` classes run the `main` SQL strings and show no guest-pass or liability field; no statement references `CGI_GUEST_PASS*`, `SAI_GUEST_PASS*`, `SPLEX_PROSPECT_LIABILITY`; `ContactsDB.load` is never asked for `ADD_GUEST` | seed rule | C2–C6 |
| U10 | **M&O flag on (club context from the session or the transaction's club):** Chancy's behaviour as in #6643 — fields editable on product items, 1–100 validation, active required, sync to `SALEITEMS`, liability saved to `SPL_EXTENSIONS`, `handlePosTransactionCompleted` → `sendGuestPassSaleEmail` only for transactions with a guest-pass line, `ADD_GUEST` resolved through `ContentsSuppliedEmail` | #6643; D61 | C2–C6 |
| U11 | **M&O flag on, columns absent:** a page load that selects the new columns fails loudly with the Oracle error (writes and page reads are **not** self-healed — the runbook forbids this order); the POS hook's guest-pass check is wrapped so a missing column logs and the sale completion and webhook publish proceed (`publishPosTransactionCompletedEvent` still runs) | seed (b); RQ-14 | C5, E1 |
| U12 | **Flag evaluation without a club** (static DB helpers, no session): evaluates with VPD-only or no context → LaunchDarkly default `false` → feature off; logged at debug, never an exception | fail-closed | B1, C1 |
| U13 | **LaunchDarkly unreachable:** the SDK returns the default `false` (datatrak `FeatureService` Javadoc, `FeatureService.java:20-24`) → both features off; no page or endpoint errors | fail-closed | B1, C1 |
| U14 | **BFF, columns absent (today):** `DatatrakServiceCatalog` against the recorded responses → club incomplete (missing `timezone`), offers none, gate 404, capability report `DT flag: off or columns absent` (existing tests kept, relabelled) | §8a; CF-13 | D2, D4 |
| U15 | **BFF, DT flag off:** identical to U14 by construction (same wire shape); one test asserts the two fixtures are byte-equal so nobody adds a "flag off" fixture that drifts | P7 | D2 |
| U16 | **BFF, DT flag on:** `saleItems.spr?club=…&guestPass=true` (no member id) and `getClubDefaultExternal.spr` on the confirmed names → club resolves with `timezone`, `prospectLiability` decoded as the waiver override, products with `guestPassOnline=true`, `guestPassVisits=1`, positive `guestPassContractDays` eligible; services and multi-visit items skipped with reasons; capability report `DT flag: on (fields present)`; the `*.synthetic.json` fixtures renamed to the confirmed names and still labelled synthetic until a dev recording replaces them | G1; U20 (0004) | D1, D2, D4 |
| U17 | **BFF timezone validation:** `timezone` that `Intl.DateTimeFormat` rejects → club fails closed with `missing: ['timezone:invalid']` in the report; `America/Chicago` and `US/Central` accepted | P5 | D3 |
| U18 | **BFF liability text:** decoded `prospectLiability` reaches the UI through the same path as the club waiver text today; if that path renders HTML, the BFF sanitises (allow-list) before it leaves the server; if it renders text, nothing changes — recorded either way with the `rg` evidence | G8 | D5 |
| U19 | **UI:** zero eligible offers and flag-off both render the unavailable block (`ShortTermPassPage.tsx:188-211`, existing test re-run); no UI code change expected | 0004 U23 | D6 |
| U20 | **Dev switch-over (gated):** only after Chancy confirms the service flag is on for the test club in dev **and** PLATFORM has set `STP_DATATRAK_SERVICE_URL`/`STP_DATATRAK_SERVICE_AUTH` in the secret: helm `STP_CATALOG_SOURCE=datatrak` (signed PR), one boot, capability report and `GET /checkouts` for the club recorded; otherwise the step is recorded **pending** with the missing precondition named | success criterion 3 | D7, E2 |
| U21 | **Runbook:** `docs/deploy/guest-pass-db-and-flags.md` lists, per environment, the ordered steps with owner, verification (query or call, no secret) and rollback; the DBA rollback is only permitted with both DT flags off; production rows exist with owners but no dates | success criterion 4 | E1 |
| U22 | **Gradle proof:** `./gradlew :dtWar:test` with JDK 17 runs the new datatrak-service tests because they are in the `include` list; the test report lists them by name; Sonar new-code coverage passes on the PR | constraint | B5, B6 |

Regression (always): Sprint 0004 BFF/UI suites green; `requireShortTermPass` still answers 404 when the club, the flag or the items are missing; the production guard unchanged; MICO's two consumers unaffected (U8); datatrak-service's existing `include` tests green; Chancy's PR tests green with the flag on.

## Architecture

### 1. Flags (both DataTrak repos)

Both repos use `abc-starter-launchdarkly-lib` (datatrak-service `build.gradle:151`, 1.2.0) with `launchdarkly.sdkKey` / `localMode` / `localModeFile` from `bootstrap.yml:15-18` and a local file (`dtWar/src/resources/launchdarkly-local.yml`, `dtWar/test/resources/featureflag-local.yml`). Convention: constants in `LDFeatureFlagConstants`, keys `datatrak-service-<TICKET>-<slug>` / `datatrak-<TICKET>-<slug>`, club context via `computeBooleanFeature(key, vpdId, clubNumber, false)` (`FeatureService.java:44-72`; datatrak `FeatureService.java:99`), static access via `StaticSpringApplicationContext.getSpringObject(FeatureService.class)` (`FeatureFlagHelper.java:45`; datatrak `DropDownTagBootstrap.java:264`).

| Repo | Constant | Key | Evaluator | Context | Default |
|---|---|---|---|---|---|
| datatrak-service | `LDFeatureFlagConstants.GUEST_PASS_FIELDS` | `datatrak-service-DT-21555-guest-pass-fields` | new `GuestPassFeature.isOn(clubNumber)` helper (`com/abcfs/launchdarkly/helper/`) → `computeBooleanFeature(key, vpdFromThread, clubNumber, false)`, exceptions → `false` + warn | `club` (five-digit number) + `vpd` when set | off |
| datatrak | `LDFeatureFlagConstants.GUEST_PASS` | `datatrak-DT-21555-guest-pass` | new `GuestPassFeature.isOn(SessionInfo \| clubId)` static helper mirroring `FeatureFlagHelper`, resolving the club number from the session or `PointOfSaleDaoImpl.getClubNumber(posTransactionId)` (already in #6643) | `club` + `vpd` | off |

Local files: both keys `false` in `launchdarkly-local.yml` (so a local run is the production default) and present in the test file so `FeatureFlagStarterWiringTest`-style tests can flip them. `LDFeatureFlagConstantsTest` gains the two key assertions (its existing pattern).

### 2. Club defaults (`/external/club/getClubDefaultExternal`)

```
ClubExternalController.getClubDefaultExternal(clubNumber)              (controller/ClubExternalController.java:189-209)
  → clubDao.setVpdFromClubNumber → ClubExternalServiceImpl.getClubDefaultExternal(clubNumber)   (service/ClubExternalServiceImpl.java:70-80)
      flag off: dtManagedClubDao.getClubDefaultExternal(clubNumber)    → GET_CLUB_DEFAULT_EXTERNAL (DtManagedClubSql.java:462-483), ClubDefaultExternalRowMapper
                 + branding + hideEnrollPage (as today)                 → ClubDefaultExternalResponse (jar)                       [byte-identical]
      flag on : dtManagedClubDao.getClubDefaultExternalGuestPass(clubNumber)
                 → GET_CLUB_DEFAULT_EXTERNAL_GUEST_PASS: the same select + "left join spl_extensions splex on splex.spl_id = spl.spl_id and splex.vpd_id = spl.vpd_id"
                   + "join timezonelookup tzl on tzl.tzl_id = spl.tzl_id" selecting splex.SPLEX_PROSPECT_LIABILITY "prospectLiability", tzl.tzl_abc_code "timezone"
                 → GuestPassClubDefaultExternalRowMapper (delegates the shared columns to the existing mapper's logic; encodes liability base64; normalises the zone id)
                 + branding + hideEnrollPage                            → GuestPassClubDefaultExternalResponse (local; @XmlRootElement name "clubDefaultExternalResponse")
                 on BadSqlGrammarException (ORA-00904): warn once per club, fall back to the flag-off path (U3)
```

The controller's return type becomes `Object` (Spring resolves the converter from the runtime type; `produces` and the header match unchanged). `GuestPassClubDefaultExternal extends ClubDefaultExternal` adds `@XmlElement(required = false) public String prospectLiability; public String timezone;` with `@JsonInclude(NON_NULL)` so a null never prints. Field names are the proposal; the confirmed names (CF-20) are a rename in one class and one BFF type.

### 3. Sale items (`/external/pos/saleItems`)

```
POSController.getOnlineSaleItems(club, memberId?, saleItemId?, guestPass?)            (controller/POSController.java:86-160)
  guestPassMode = "true".equals(guestPass) && GuestPassFeature.isOn(club)
  if (!guestPassMode && memberId == null) throw new MissingServletRequestParameterException("memberId", "String")   [today's 400, U4/U7]
  validator: guestPassMode ? validateGuestPassSaleItemRequest(club) : validateSaleItemRequest(club, memberId)       (validator/OnlinePosValidator.java:251-267)
  rows:      guestPassMode ? pointOfSaleDao.getOnlineSaleItemsGuestPass(splId, ts) : pointOfSaleDao.getOnlineSaleItems(splId, ts)   (repository/pos/jdbc/JdbcPointOfSaleDao.java:110-123)
             GET_ONLINE_SALE_ITEMS_GUEST_PASS = today's select + sai.sai_guest_pass "guestPassOnline", sai.sai_guest_pass_visits "guestPassVisits",
               sai.sai_guest_pass_contract_days "guestPassContractDays", cgi.cgi_service "itemTypeCode"
               where … and (cgi.cgi_service = '1' or (sai.sai_guest_pass = '1' and cgi.cgi_service = '0')) …   (cgi_online, actives, abc_code null unchanged)
             GuestPassOnlineSaleItemMapper extends DiscountOnlineSaleItemMapper: sets the four fields; itemType from the code (0 PRODUCT / 1 SERVICE / 2 BILLING)
  enrichment: only when memberId is present (today's loop)              → SaleItemResponse (local, com/abcfs/api/pos/SaleItemResponse.java)
```

`SaleItem` (local, `com/abcfs/api/pos/SaleItem.java`) gains `@XmlElement(required = false) @JsonInclude(NON_NULL) public Boolean guestPassOnline; public Integer guestPassContractDays; public Integer guestPassVisits; public String itemType;` — null on every flag-off path, so JSON and XML are byte-identical (U4). `GET_ONLINE_SALE_ITEM` (single item) gets the same treatment so the BFF's re-read before side effects can use `saleItemId`. Whether `cgi_online = '1'` stays a requirement for guest-pass products is RQ-15 (position: yes — "Available online" is the club's explicit intent and the enablement guide says to tick both).

### 4. M&O app gating (datatrak PR #6643)

Every site below gets `if (GuestPassFeature.isOn(…))` around the **new** behaviour, and the `main` statement retained verbatim as the else-branch (not re-derived). Review map (file → added lines in #6643 → guard):

| Site | What the PR added | Off-branch | Context source |
|---|---|---|---|
| `CatalogItemsDB` (`dt/inventory/catalogItems/CatalogItemsDB.java`) select, insert (63 placeholders), update, `SALEITEMS` sync | three columns in each statement | `main` strings for all four | session club (`EditCatalogItemsState` → `SessionInfo`) |
| `EditCatalogItemsState` / `EditCatalogItemsSecondaryPage(.java,.jsp)` | three fields, product-only reset, 1–100 and active validation, JS enable/disable | fields hidden (`<c:if>`/state flag), validation skipped, state values forced `"0"` | session club |
| `EditClubOnlineDaoImpl` read/`saveProspectContent`, `EditClubServiceImpl`, `EditClubOnlineProspect(.java,.jsp)` | liability select (left join `spl_extensions`), second update, field + size check | `main` select and `saveTermsAndConditions` update; field hidden | club being edited |
| `JdbcClubDao.getProspectLiabilityLanguage` | new query | method only reachable from the gated email path | — |
| `sales/...PointOfSaleDB` and `sales3/...PointOfSaleDB` `handlePosTransactionCompleted` → `sendGuestPassSaleEmail` | guest-pass email before the webhook publish | call skipped; `publishPosTransactionCompletedEvent` unchanged | `PointOfSaleDaoImpl.getClubNumber(posTransactionId)` (in #6643) |
| `ProspectServiceTransactionsImpl.sendGuestPassSaleEmail` (`transactionContainsGuestPassItem` reads `sai_guest_pass`; `ContentsSuppliedEmail(ADD_GUEST, …)` → `ContactsDB.load` by abc code) | the whole method | early return when off (double guard: the static hook and the service) | transaction's club |
| `JdbcMemberDao.getGuestEmailInformation` | new query on existing columns | not gated (no new column) — noted in the map | — |
| `sql/*.sql` (identical to `docs/DT-21555-guest-pass-email-prd/sql/*` up to line endings) | — | G9 rewrite offered as a separate commit (CF-22) | — |

The call-site swaps in `EAEApi`, `POSApi`, `PosPayPageCheckoutCompleteService` to `handlePosTransactionCompleted` stay: the new method is a pass-through when off.

### 5. BFF matrix and capability report

`DatatrakServiceCatalog` (`src/services/shortTermPass/adapters/platform/datatrakServiceCatalog.ts`) changes in four places: the sale-items URL gains `&guestPass=true`; `DatatrakSaleItem` renames `contractDays`/`visits` → `guestPassContractDays`/`guestPassVisits` (or the confirmed names); `DatatrakClubDefaultResponse.waiverText` → `prospectLiability`; `mapClubDefault` validates `timezone` with `Intl.DateTimeFormat` and reports `timezone:invalid`. The `ClubReport` gains `dtFlag: 'on' | 'off-or-absent'` inferred from the presence of `timezone` on the wire (the only field that is never null when the flag is on), printed in `capability()`. Fixtures: `getClubDefaultExternal.recorded.json` (today = flag off) is reused as the flag-off case; `*.synthetic.json` move to the confirmed names and keep their `_label`; a `*.flag-on.recorded.json` slot is documented in `fixtures/datatrak/README.md` for the first dev recording (scrubbed). Tests (`__tests__/datatrakServiceCatalog.test.ts`) grow a `describe('matrix')` with the six cells.

### 6. Rollout order (the runbook's spine; owners are slots until kickoff)

```
0. LD: create both DT keys (dev + prod, default off, club targeting enabled) — PLATFORM / Chancy      rollback: n/a
1. Code with flags off: datatrak-service PR merged → main → dev image + deploy (ci-trunk.yml);        verify: diff dev JSON/XML of both endpoints against the recorded fixtures = no change
   datatrak #6643 (+gating) merged → dev                                                             rollback: previous tag (deploy-by-tag.yml)
2. DBA runs sql/* in dev — Terry                                                                      verify: handoff §Deployment verification queries; rollback: handoff §Rollback (flags must be off)
3. datatrak flag on for the test club (dev) — Chancy; configure one product: guest pass, visits 1,   verify: SALEITEMS row shows SAI_GUEST_PASS='1'; Edit Club liability saved; POS test sale sends ADD_GUEST
   contract days N, online, active; Edit Club → Online → liability text                              rollback: flag off (pages return to main behaviour; data stays)
4. datatrak-service flag on for the test club (dev) — Chancy/PK                                      verify: curl both endpoints (credential from the shell, never printed) → fields present; MICO dev shop unchanged
                                                                                                      rollback: flag off (responses return to step-1 shape)
5. BFF: secret keys STP_DATATRAK_SERVICE_URL/AUTH — PLATFORM; helm STP_CATALOG_SOURCE=datatrak (signed PR) — Bjorn   verify: capability report, POST /checkouts for the club
                                                                                                      rollback: STP_CATALOG_SOURCE=fixture
6. guest-pass-online per club (dev: override stands in until CF-17 lands) — PLATFORM                 verify: page lists the live item; rollback: flag off
Production: the same six steps as V-P1 rows with owners; no dates in this sprint.
```

## Implementation Plan

**Sizing:** ~12 engineering days — A (~1.5, one session) → B (DT-service lane, ~4) ∥ C (DT-M&O lane, ~2.5) ∥ D (BFF lane, ~2.5) → E (~1.5, orchestrator). **Vertical slice first:** A → B1 + B2 (club defaults both ways with goldens) → D1 + D2 (BFF reads the flag-on shape from a fixture) proves the pattern before the sale-items query, the M&O pass or the runbook. **Cuts if the lanes run long, in order:** C8 (G9 rewrite) → register row; D7 (dev switch-over) → pending with reason; B3's `saleItemId` single-item variant → follow-up. Never cut the goldens (B4, C7), the `include` list entry (B5) or the runbook (E1). Execution model as Sprint 0004: A by one session, then three detached lanes against the frozen field table, each with its own blockers and summary files; the orchestrator owns E. No lane merges anything in a DataTrak repo; no lane prints a credential.

### A — Freeze and feasibility · ~1.5 days · one session

| # | Task | Files | Done when |
|---|---|---|---|
| A1 | Branches: `prospect-wallet/sprint-0005` in `online-join-bff` (and `online-join-ui` only if D6 finds a change); `DT-21555-guest-pass-service-fields` in `datatrak-service` off `main`; `DT-21555-guest-pass-flag-gating` in `datatrak` off `feat/NOJIRA-guest-pass-email`; ledger `SPRINT-0005 in-progress` with heads; sync the shallow clones first (`git -C repos/<r> fetch --depth=…`) | three clones; `docs/sprints/ledger.yaml` | branches exist locally; ledger updated |
| A2 | **Feasibility (½ day, no remote probe needed):** (a) `javap`/`rg` confirm the jar classes and JAXB annotations (done in drafting — record); (b) unit-level proof that MICO's default `RestTemplate` lists XML before JSON in `Accept` for `ClubDefaultExternalResponse` (a tiny TestNG test in datatrak-service constructing `new RestTemplate()` and inspecting `AcceptHeaderRequestCallback` output, or a documented Spring reference) — decides whether U8 needs the XML unmarshal test (it does if XML wins); (c) `rg` the whole `GET_ONLINE_SALE_ITEMS` family for other callers of `getOnlineSaleItems` (MICO shop, kiosk) to confirm the new query is only reachable via `guestPass=true`; (d) ask Chancy/Terry for `select distinct tzl_abc_code from timezonelookup` output (RQ-11) and agreement on P3 (CF-19) | contract §8a(e) | each check recorded as done or as a CF/RQ row |
| A3 | **Contract v4.1 field table** (`docs/contracts/short-term-pass-bff.md` §8 "DataTrak service-layer fields"): endpoint, request parameter, field, type, source column, encoding, null when, flag; the BFF's wire types mirror it; "proposed until CF-20" marker | contract §2, §8, §8a, §10 | table frozen; D1 codes against it |
| A4 | **Review map and gating inventory** for both DT repos: every `rg -n 'GUEST_PASS|SPLEX_PROSPECT_LIABILITY|ADD_GUEST|guestPass' --type java --type jsp` hit in `repos/datatrak` (branch) and the planned sites in `repos/datatrak-service`, with the guard each will sit under; becomes the C9 review comment | NEW `docs/sprints/drafts/SPRINT-0005-BLOCKERS.md` §Gating inventory | list matches `rg`; Chancy has seen it |
| A5 | **Flag keys registered** (names, context kinds, defaults) in the contract and a PLATFORM/Chancy handoff text; local yml entries drafted | contract §10; handoff text | keys named once, identically, in both repos' plans |

**Exit:** field table and keys frozen; DTO and request-shape positions confirmed or replaced; MICO path known; inventory agreed; branches and ledger updated.

### B — datatrak-service PR · ~4 days · DT-service lane

Paths relative to `repos/datatrak-service/dtWar/`.

| # | Task | Files | Done when |
|---|---|---|---|
| B1 | **Flag plumbing.** `GUEST_PASS_FIELDS` constant; `GuestPassFeature` helper (club + VPD from `ThreadStorage`/`Database.VPD_KEY`, exceptions → `false`); keys in both yml files; `LDFeatureFlagConstantsTest` assertion; `GuestPassFeatureTest` (mocked `FeatureService`, context captured) | `src/com/abcfs/launchdarkly/LDFeatureFlagConstants.java`, NEW `src/com/abcfs/launchdarkly/helper/GuestPassFeature.java`, `src/resources/launchdarkly-local.yml`, `test/resources/featureflag-local.yml`, `test/java/com/abcfs/launchdarkly/LDFeatureFlagConstantsTest.java`, NEW `…/helper/GuestPassFeatureTest.java` | U12, U13 pinned |
| B2 | **Club defaults both ways.** `GET_CLUB_DEFAULT_EXTERNAL_GUEST_PASS` in the SQL bundle; `DtManagedClubDao.getClubDefaultExternalGuestPass`; `GuestPassClubDefaultExternal`, `GuestPassClubDefaultExternalResponse`, `GuestPassClubDefaultExternalRowMapper` (base64 like `prospectTerms`; `ZoneId` normalisation per P5); `ClubExternalServiceImpl` branch + `BadSqlGrammarException` fallback with a once-per-club warn; controller return type `Object` | `src/com/abcfs/club/external/dao/{DtManagedClubSql,DtManagedClubDao,DtManagedClubDaoImpl}.java`, NEW `src/com/abcfs/club/external/api/GuestPassClubDefaultExternal{,Response}.java`, NEW `src/com/abcfs/repository/club/mapper/GuestPassClubDefaultExternalRowMapper.java`, `src/com/abcfs/club/external/service/{ClubExternalService,ClubExternalServiceImpl}.java`, `src/com/abcfs/club/external/controller/ClubExternalController.java` | U1–U3 at the service level |
| B3 | **Sale items both ways.** `guestPass` request param; manual `MissingServletRequestParameterException` when neither mode supplies `memberId`; `OnlinePosValidator.validateGuestPassSaleItemRequest(club)`; `GET_ONLINE_SALE_ITEMS_GUEST_PASS` and `GET_ONLINE_SALE_ITEM_GUEST_PASS`; `JdbcPointOfSaleDao.getOnlineSaleItems{,Item}GuestPass`; `GuestPassOnlineSaleItemMapper`; four nullable fields on `SaleItem` with `@JsonInclude(NON_NULL)`; enrichment only with a member | `src/com/abcfs/controller/POSController.java`, `src/com/abcfs/validator/OnlinePosValidator.java`, `src/com/abcfs/repository/pos/sql/PointOfSaleSql.java`, `src/com/abcfs/repository/pos/{PointOfSaleDao,jdbc/JdbcPointOfSaleDao}.java`, NEW `src/com/abcfs/repository/pos/mapper/GuestPassOnlineSaleItemMapper.java`, `src/com/abcfs/api/pos/SaleItem.java` | U4–U7 at the controller level |
| B4 | **Goldens.** (i) SQL: `ArgumentCaptor<String>` on the mocked `NamedParameterJdbcTemplate` — flag-off strings equal constants copied from `main` (`DtManagedClubSql.java:462-483`, `PointOfSaleSql.java:25-45`); flag-on strings contain the three/four new selects and the widened `where`. (ii) Shape: serialise flag-off and flag-on responses through `new MappingJackson2HttpMessageConverter(SpringConfiguration's mapper)` and `JAXBContext.newInstance(...)` (precedent: `POSControllerCommentTest` marshals with `JAXBContext`); flag-off key set == recorded §8a fixture keys (copied scrubbed into test resources); flag-on == off + the new names only. (iii) Consumer: deserialise flag-on JSON into the jar `ClubDefaultExternalResponse` and MICO-shaped `SaleItemResponse`; unmarshal flag-on XML with a default JAXB context (if A2 says XML wins). (iv) Fallback: `BadSqlGrammarException` → off shape + one warn. Controller tests follow `ClubExternalControllerTest` (`@InjectMocks`) | NEW `test/java/com/abcfs/club/external/service/ClubExternalServiceImplGuestPassTest.java`, NEW `test/java/com/abcfs/club/external/dao/DtManagedClubDaoImplGuestPassSqlTest.java`, NEW `test/java/com/abcfs/controller/POSControllerGuestPassTest.java`, NEW `test/java/com/abcfs/repository/pos/jdbc/JdbcPointOfSaleDaoGuestPassSqlTest.java`, NEW `test/java/com/abcfs/api/pos/SaleItemSerializationTest.java`, test resources `guest-pass/*.json|xml` | U1–U8 pinned; every test name appears in the Gradle report |
| B5 | **Make the tests run.** Add each new test to the `include` list; `./gradlew :dtWar:test` on JDK 17 (`/Library/Java/JavaVirtualMachines/jdk-17.0.1.jdk`) shows them; README note corrected (test task runs an include list) | `build.gradle:256-305`, `README.md` | U22 pinned |
| B6 | **PR.** Title `DT-21555 Expose guest-pass fields on saleItems.spr and getClubDefaultExternal.spr behind a feature flag`; description: field table, flag key, flag-off proof, consumer safety, rollout pointer; **no header literal, no credential**; Sonar new-code gate green; reviewers PK + Chancy | PR on `abcfinancial/datatrak-service`; `docs/sprints/drafts/SPRINT-0005-PR-DESCRIPTIONS.md` | PR open, CI green, Sonar green, link in the ledger |

**Exit:** U1–U8, U12, U13, U22 pinned; PR open and green; `SPRINT-0005-EXECUTION-SUMMARY-DTS.md` and `-BLOCKERS-DTS.md` written.

### C — datatrak PR #6643 flag-gating pass · ~2.5 days · DT-M&O lane

Paths relative to `repos/datatrak/dtWar/src/main/java/`; branch off `feat/NOJIRA-guest-pass-email`; **never** rewrite or force-push Chancy's branch.

| # | Task | Files | Done when |
|---|---|---|---|
| C1 | **Flag plumbing.** `GUEST_PASS` constant; static `GuestPassFeature.isOn(SessionInfo)` / `isOn(clubNumber, vpdId)` mirroring `FeatureFlagHelper`'s null-safe static lookup; keys in `launchdarkly-local.yml`; constants test | `com/abcfinancial/datatrak/common/launchdarkly/LDFeatureFlagConstants.java`, NEW `com/abcfinancial/datatrak/common/launchdarkly/feature/GuestPassFeature.java`, `dtWar/src/main/resources/launchdarkly-local.yml`; tests | U12, U13 pinned (datatrak side) |
| C2 | **Catalog item DB.** Restore the four `main` statements as the off-branch of `CatalogItemsDB` (select, insert, update, `SALEITEMS` sync); the PR's statements as the on-branch; guest-pass state values forced `"0"` when off | `com/seqtek/abcfs/dt/inventory/catalogItems/CatalogItemsDB.java` | U9/U10 (DB half) pinned by SQL goldens |
| C3 | **Catalog item page.** Fields and JS hidden when off (`EditCatalogItemsSecondaryPage.jsp`), validation block and product reset gated (`EditCatalogItemsSecondaryPage.java`), state unchanged | `…/catalogItems/EditCatalogItemsSecondaryPage.java`, `dtWar/src/main/webapp/WEB-INF/jsp/inventory/catalogItems/EditCatalogItemsSecondaryPage.jsp`, `EditCatalogItemsState.java` (no change expected) | page renders as `main` when off |
| C4 | **Edit Club liability.** `EditClubOnlineDaoImpl`: the `main` select and `saveTermsAndConditions` as the off-branch (keep both method names; `saveProspectContent` delegates when off); `EditClubServiceImpl` passes the flag; JSP field hidden; `EditClubOnlineProspect` size check gated | `com/abcfs/repository/editClub/{EditClubOnLineDao,EditClubOnlineDaoImpl}.java`, `com/abcfs/services/EditClubServiceImpl.java`, `com/seqtek/abcfs/dt/cfg/editclub/online/EditClubOnlineProspect.java`, `…/jsp/editClub/online/EditClubOnlineProspect.jsp` | U9/U10 (club half) pinned |
| C5 | **POS hook.** Both `PointOfSaleDB.handlePosTransactionCompleted`: resolve the club, call `sendGuestPassSaleEmail` only when on; wrap the guest-pass check so a missing column logs and the webhook publish still runs (U11); `ProspectServiceTransactionsImpl.sendGuestPassSaleEmail` early-returns when off (second guard) | `com/seqtek/abcfs/dt/sales/common/repository/PointOfSaleDB.java`, `com/seqtek/abcfs/dt/sales3/common/repository/PointOfSaleDB.java`, `com/abcfs/services/ProspectServiceTransactionsImpl.java` | U9–U11 (POS half) pinned |
| C6 | **`ADD_GUEST` lookup.** Reachable only through C5's gated path; `ContactsDB.load` never asked for `ADD_GUEST` when off (asserted with `mockStatic`) | as C5 | pinned |
| C7 | **Tests (PR style).** Extend `PointOfSaleDBGuestEmailTest` (off → `verify(never())`, on → `verify`), `ProspectServiceTransactionsImplEmailTest` (off → no DAO call); NEW `CatalogItemsDBGuestPassSqlTest` and `EditClubOnlineDaoImplGuestPassTest` with `ArgumentCaptor` goldens against `main` strings; `GuestPassFeatureTest` | `dtWar/src/test/java/...` (TestNG, Mockito, `mockStatic(StaticSpringApplicationContext)` as in the PR) | both states green; `./gradlew test` includes them (datatrak runs the whole TestNG suite — confirm in A2(c) that the suite is green on the branch today, else record the baseline) |
| C8 | **G9 (optional, separate commit):** `ALTER TABLE … ADD (col … DEFAULT …)` without the full-table `UPDATE`, rerun guards (`user_tab_cols` checks), identical end state; handoff doc updated | `sql/project-guest-pass-catalog-item.sql`, `sql/project-prospect-liability-language.sql`, `docs/DT-21555-guest-pass-email-prd/…` | Terry has the diff (CF-22) |
| C9 | **PR onto Chancy's branch.** Title `DT-21555 Gate the guest-pass columns, liability field and ADD_GUEST email behind datatrak-DT-21555-guest-pass`; body = the A4 review map with a line per site; CI green | PR on `abcfinancial/datatrak` (base `feat/NOJIRA-guest-pass-email`) | PR open; Chancy acknowledged (CF-19) |

**Exit:** U9–U13 pinned; PR open; `SPRINT-0005-EXECUTION-SUMMARY-DTM.md` and `-BLOCKERS-DTM.md` written.

### D — BFF/UI consumption · ~2.5 days · BFF lane

Paths relative to `repos/online-join-bff/src/services/shortTermPass/` unless noted.

| # | Task | Files | Done when |
|---|---|---|---|
| D1 | **Wire types and call on the field table.** `DatatrakSaleItem` / `DatatrakClubDefaultResponse` renamed fields; `&guestPass=true` on the sale-items URL (and on the single-item re-read if used); `mapSaleItem` reads the new names; `mapClubDefault` reads `prospectLiability` into `waiverText` | `adapters/platform/datatrakServiceCatalog.ts` | U16 mapper half |
| D2 | **Matrix fixtures and tests.** Recorded = flag-off/absent (one assertion that they are the same bytes — U15); synthetic renamed to the confirmed names and relabelled; README documents the `*.flag-on.recorded.json` slot; `describe('matrix')` with the six cells; existing CF-13/CF-14 tests kept | `fixtures/datatrak/{README.md,getClubDefaultExternal.synthetic.json,saleItems.synthetic.json}`, `__tests__/datatrakServiceCatalog.test.ts` | U14–U16 pinned |
| D3 | **Timezone validation.** `isSupportedTimeZone(id)` via `Intl.DateTimeFormat` try/catch; `missing: ['timezone:invalid']`; both IANA and legacy ids tested | `adapters/platform/datatrakServiceCatalog.ts`, tests | U17 pinned |
| D4 | **Capability report.** `dtFlag` inference and wording `DT flag: on (fields present) \| off or columns absent`; demo prints it | `adapters/platform/datatrakServiceCatalog.ts`, `scripts/short-term-pass-demo.ts` | U14/U16 report lines pinned |
| D5 | **Liability text path.** `rg` how the club waiver override reaches the UI (`DocumentDialog`, `ConsentBlock`; `renderConsentDocumentSet` in `fixtures/consentTemplates.ts`); if HTML is rendered, add an allow-list sanitiser at decode time (no new dependency without a note) and a test; else record "text" | `fixtures/consentTemplates.ts`, `adapters/platform/datatrakServiceCatalog.ts`; UI `src/routes/ShortTermPass/components/{DocumentDialog,ConsentBlock}.tsx` (read) | U18 recorded with evidence |
| D6 | **UI proof.** Re-run `ShortTermPassPage` tests for the unavailable block; no code change unless D5 requires one | `repos/online-join-ui/__tests__/routes/ShortTermPass/ShortTermPassPage.test.tsx` | U19 recorded |
| D7 | **Dev switch-over (gated).** Preconditions: step 4 of §6 confirmed by Chancy and the secret keys set by PLATFORM. Then helm `online-join-bff/dev.yaml` `STP_CATALOG_SOURCE=datatrak` (signed: `/usr/bin/git -c gpg.format=ssh -c user.signingkey=~/.ssh/id_ed25519_signing.pub`), comment block updated; one boot; capability report via `kubectl port-forward` and `POST /checkouts` for the test club recorded. Otherwise: **pending** with the missing precondition | `repos/helm-configs/online-join-bff/dev.yaml`; `docs/deploy/dev.md` | U20 recorded done or pending |
| D8 | **Contract and PR.** BFF `schemas.ts` unchanged (browser contract v4 stays); contract §8/§8a/§10 rows; PR `feat: read the guest-pass fields from the DataTrak service layer (contract v4.1)` | `docs/contracts/short-term-pass-bff.md`; PR on `online-join-bff` | PR open, Sonar green |

**Exit:** U14–U19 pinned; coverage floors kept (BFF ≥ 84/67/67/84); `SPRINT-0005-EXECUTION-SUMMARY-BFF.md` and `-BLOCKERS-BFF.md` written.

### E — Runbook, proof, docs · ~1.5 days · orchestrator

| # | Task | Evidence |
|---|---|---|
| E1 | **Runbook** `docs/deploy/guest-pass-db-and-flags.md`: §6 as a table per environment (dev now; staging/prod rows with owner slots, no dates); verification query/call per step (no secret); rollback per step; the rule "scripts roll back only with both DT flags off"; U11 ordering warning; registered in pilot gates (V-P1a rewritten into V-P1a-i…vi) and contract §10 | runbook; `docs/validation/guest-pass-pilot-gates.md`; contract §10 |
| E2 | **Proof.** BFF jest + lint + coverage; datatrak-service `./gradlew :dtWar:test` report naming the new tests; datatrak suite on the gating branch; demo green; D7 result; smoke doc §live for this sprint (done / blocked / pending, each with its reason) | NEW `docs/validation/short-term-pass-sprint-0005-smoke.md` |
| E3 | **Registers.** CF-13/CF-14 updated (code exists; "blocked" → "pending DT review/merge/flag"); CF-19…CF-22, RQ-10…RQ-16 rows; G1 traceability (each review ask → task → state) | contract §10; NEW `docs/validation/short-term-pass-sprint-0005-traceability.md` |
| E4 | **Docs, status, PRs.** `docs/SEMANTIC-INDEX.md` Sprint 0005 code map (both DT repos, the local response pair, the five corrections); ledger; PR descriptions (three); execution summary with the four verdicts | as named |

Local commands:

```text
# datatrak-service (JDK 17)
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-17.0.1.jdk/Contents/Home
cd repos/datatrak-service && ./gradlew :dtWar:test --tests '*GuestPass*' && open dtWar/build/reports/tests/test/index.html
# datatrak (gating branch)
cd repos/datatrak && git switch DT-21555-guest-pass-flag-gating && ./gradlew :dtWar:test --tests '*GuestPass*' --tests '*GuestEmail*'
# BFF
cd repos/online-join-bff && npm ci --ignore-scripts && npm test -- datatrakServiceCatalog && npm run lint && npm run build
# dev, only after §6 steps 4–5 (credential and URL from the shell environment, never echoed)
kubectl --context k8s-lower-wlr -n dev port-forward deploy/online-join-bff 18080:8080
curl -s -H "X-STP-TEST-KEY: $KEY" 'http://127.0.0.1:18080/api/short-term-pass/testing/state?checkoutId=…' | jq '.capabilities[] | select(.adapter=="DatatrakServiceCatalog") | .note'
```

## Files Summary

| Repo | Paths | Action |
|---|---|---|
| datatrak-service | `dtWar/src/com/abcfs/launchdarkly/LDFeatureFlagConstants.java`, `dtWar/src/com/abcfs/club/external/{controller/ClubExternalController,service/ClubExternalService,service/ClubExternalServiceImpl,dao/DtManagedClubSql,dao/DtManagedClubDao,dao/DtManagedClubDaoImpl}.java`, `dtWar/src/com/abcfs/controller/POSController.java`, `dtWar/src/com/abcfs/validator/OnlinePosValidator.java`, `dtWar/src/com/abcfs/repository/pos/{PointOfSaleDao,jdbc/JdbcPointOfSaleDao,sql/PointOfSaleSql}.java`, `dtWar/src/com/abcfs/api/pos/SaleItem.java`, `dtWar/src/resources/launchdarkly-local.yml`, `dtWar/test/resources/featureflag-local.yml`, `dtWar/build.gradle` (include list), `README.md` | MODIFY |
| datatrak-service | `dtWar/src/com/abcfs/launchdarkly/helper/GuestPassFeature.java`, `dtWar/src/com/abcfs/club/external/api/GuestPassClubDefaultExternal{,Response}.java`, `dtWar/src/com/abcfs/repository/club/mapper/GuestPassClubDefaultExternalRowMapper.java`, `dtWar/src/com/abcfs/repository/pos/mapper/GuestPassOnlineSaleItemMapper.java`, tests `…GuestPass*Test.java` + `test/resources/guest-pass/*` | NEW |
| datatrak (PR onto `feat/NOJIRA-guest-pass-email`) | `com/abcfinancial/datatrak/common/launchdarkly/LDFeatureFlagConstants.java`, `com/seqtek/abcfs/dt/inventory/catalogItems/{CatalogItemsDB,EditCatalogItemsSecondaryPage}.java` + `.jsp`, `com/abcfs/repository/editClub/{EditClubOnLineDao,EditClubOnlineDaoImpl}.java`, `com/abcfs/services/{EditClubServiceImpl,ProspectServiceTransactionsImpl}.java`, `com/seqtek/abcfs/dt/cfg/editclub/online/EditClubOnlineProspect.java` + `.jsp`, `com/seqtek/abcfs/dt/sales/common/repository/PointOfSaleDB.java`, `com/seqtek/abcfs/dt/sales3/common/repository/PointOfSaleDB.java`, `dtWar/src/main/resources/launchdarkly-local.yml`, PR tests extended; optional `sql/*.sql` (G9) | MODIFY |
| datatrak | `com/abcfinancial/datatrak/common/launchdarkly/feature/GuestPassFeature.java`, tests `GuestPassFeatureTest`, `CatalogItemsDBGuestPassSqlTest`, `EditClubOnlineDaoImplGuestPassTest` | NEW |
| online-join-bff | `src/services/shortTermPass/adapters/platform/datatrakServiceCatalog.ts`, `fixtures/datatrak/{README.md,*.synthetic.json}`, `__tests__/datatrakServiceCatalog.test.ts`, `scripts/short-term-pass-demo.ts`, (`fixtures/consentTemplates.ts` if D5 sanitises) | MODIFY |
| online-join-ui | none expected (D5/D6 may touch `DocumentDialog.tsx` + test) | READ / MODIFY only if D5 requires |
| helm-configs | `online-join-bff/dev.yaml` (`STP_CATALOG_SOURCE=datatrak`, comment) — signed PR, gated by D7 preconditions | MODIFY (gated) |
| this repo | `docs/contracts/short-term-pass-bff.md` (v4.1 §2, §8, §8a, §10), `docs/validation/guest-pass-pilot-gates.md` (V-P1a), `docs/deploy/dev.md`, `docs/SEMANTIC-INDEX.md`, `docs/sprints/ledger.yaml` | MODIFY |
| this repo | `docs/deploy/guest-pass-db-and-flags.md`, `docs/validation/short-term-pass-sprint-0005-{smoke,traceability}.md`, `docs/sprints/drafts/SPRINT-0005-{BLOCKERS,EXECUTION-SUMMARY}{,-DTS,-DTM,-BFF}.md`, `docs/sprints/drafts/SPRINT-0005-PR-DESCRIPTIONS.md` | NEW |
| Handoffs (outside the cache) | LD keys ×2 (PLATFORM / Chancy); `STP_DATATRAK_SERVICE_URL`/`AUTH` in `platform-online-join-bff` (PLATFORM); scripts in dev (Terry); flag flips in dev (Chancy / PK); PR reviews (PK, Chancy); `guest-pass-online` (CF-17, PLATFORM) | register rows with owner slots |

Not modified: `repos/mico/**` (consumer reference only); the browser contract (`schemas.ts`, UI interfaces); `requireShortTermPass.ts`; the production guard; Chancy's branch history; any `sql/*` unless C8 is accepted; wallet repos.

## Definition of Done

Role slots: DTS (datatrak-service lane), DTM (datatrak gating lane), BFF, QA, SECURITY, DT (Chancy), PK, DBA (Terry), PLATFORM, PRODUCT. A gate with no named owner does not sign. An unrun check is pending, not passed. Sprint gates V0–V7; the pilot gates touched (V-P1a/b) are **not** part of sprint completion.

| Gate | Owner | Passes when |
|---|---|---|
| V0 — Freeze | DTS+BFF | Field table (A3) frozen and mirrored in the BFF types and the datatrak-service classes; flag keys named identically in both repos' constants, local ymls and the contract; positions P1–P7 confirmed or replaced at the interview; gating inventory (A4) matches `rg`; branches and ledger updated |
| V1 — Flag off is today | DTS+DTM+QA | SQL-string goldens pass against the `main` literals in both repos; shape goldens: flag-off JSON/XML key sets equal the recorded §8a fixtures; a request without `memberId` and without `guestPass=true` answers today's 400; `rg` for the new column names and `ADD_GUEST` in both repos lists only guarded sites; MICO path untouched (no `guestPass` param, additive fields only) |
| V2 — Flag on exposes the fields | DTS+QA | U2, U5, U6 pass at the controller level; products with `sai_guest_pass = '1'` are rows; `itemType` present; timezone normalised; liability base64 like `prospectTerms`; `BadSqlGrammarException` fallback (U3) tested |
| V3 — Consumer safety | DTS+SECURITY | Flag-on JSON deserialises into the jar/MICO classes; flag-on XML unmarshals with a default JAXB context (if A2 shows XML wins); no header literal or credential in any PR text, test or doc |
| V4 — M&O gating | DTM+DT | Every site in the A4 map guarded; off-branch strings verbatim from `main`; both `PointOfSaleDB` hooks skip the email when off and still publish the webhook; `ContactsDB.load` never asked for `ADD_GUEST` when off; PR onto Chancy's branch open with the review map; Chancy's own tests green with the flag on |
| V5 — BFF matrix | BFF+QA | Six matrix cells pinned on recorded/synthetic fixtures; `timezone:invalid` fails closed; capability report states the inferred DT flag; fixtures labelled; coverage floors kept; Sonar green on the BFF PR; UI unavailable-block tests green |
| V6 — Tests actually run | DTS+QA | Every new datatrak-service test listed in `build.gradle` `include` and present in the Gradle report; Sonar new-code coverage gate green on the datatrak-service PR; datatrak suite baseline recorded |
| V7 — Runbook and status | orchestrator+PLATFORM(observer) | `docs/deploy/guest-pass-db-and-flags.md` complete (owners, verification, rollback per step; flags-off rule); V-P1a rewritten; contract v4.1 and registers updated; smoke §live recorded (D7 done **or** pending with the named precondition); ledger; execution summaries; four verdicts |

**Completion vocabulary (four separate verdicts, never merged):** *(1) Implementation and mock acceptance: datatrak-service PR and datatrak gating PR open and green with flag-off goldens and flag-on tests; BFF matrix pinned on fixtures. (2) Standalone dev host: unchanged from Sprint 0004 {verified | pending helm #3090 / deploy}. (3) Live integration: DataTrak catalog read {done — dev flag on, `STP_CATALOG_SOURCE=datatrak`, fields observed | pending — PRs unmerged / scripts not run / flag off / secret missing, named} ; prospect create/repaint/deactivate {mock only — CF-15}; hosted capture {verified | unverified B1}; QR, Add Guest email and access enforcement are DataTrak's and unverified from this build. (4) Pilot: not eligible until V-P0…V-P6 pass; this sprint rewrites V-P1a into the six runbook steps.* A failed or pending gate is named in the sentence, never absorbed.

### Pilot gates touched

| Gate | Change |
|---|---|
| V-P1a | Rewritten as six rows (runbook §6 steps 0–5) with owner slots: LD keys · code with flags off · scripts (Terry) · M&O flag + item configured (Chancy) · service flag (Chancy/PK) · BFF secret + source switch (PLATFORM/Bjorn). Evidence column names the verification per row. |
| V-P1b | Unchanged text; now explicitly step 5 of the runbook. |
| V-P6 / CR-21 | One sentence added for the enablement guide: "a guest pass item is a **product**, flagged, visits 1 (v1 online), contract days 1–100, active, and **available online**" (G12, G13, RQ-15). |

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | The review never saw the `cgi_service = '1'` filter; PK or Chancy object to widening the online query | The widening is doubly gated (flag **and** `guestPass=true`); MICO never sends the parameter; the sibling-endpoint fallback (P4) is a controller method away |
| R2 | JAXB rejects or mis-orders the local response pair | Declared types only (no runtime subclass in a jar-typed field); JAXB and Jackson goldens in B4; the jar bump (RQ-12) stays as the alternative |
| R3 | MICO's `RestTemplate` takes XML and a future JAXB strictness breaks on unknown elements | A2(b) decides; U8's XML unmarshal test runs against the 4.1.0 jar classes; additive elements only |
| R4 | Chancy declines a PR onto his branch or the branch moves | CF-19 asked in A; the review map (A4) is deliverable on its own; rebase cost is small (gating touches the same hunks) |
| R5 | Static DB code evaluates the flag without a club → always off → feature "mysteriously" hidden | Club resolved from the session or `getClubNumber(posTransactionId)`; VPD-only fallback; a debug log names the context used (U12) |
| R6 | A flag flipped on before the scripts run | Reads self-heal (U3); M&O writes do not — the runbook orders scripts first and says so twice; the POS hook is wrapped so a sale never fails on the guest-pass check (U11) |
| R7 | The DBA rolls the scripts back while a flag is still on | Runbook rule: rollback only with both DT flags off; verification query before the drop |
| R8 | New datatrak-service tests never run (missing from the `include` list) | B5 is its own task and V6 its own gate; the Gradle report is evidence |
| R9 | `TZL_ABC_CODE` values are not IANA ids | P5 normalisation; RQ-11 value list; BFF fails closed on an unknown id (U17) |
| R10 | Sonar new-code gate on a repo with sparse coverage | Tests target every new branch; goldens are cheap; precedent from Sprint 0004's Sonar fixes |
| R11 | Shallow clones go stale during the sprint | A1 syncs; lanes record heads; PRs are opened from fresh fetches |
| R12 | A credential or the header literal leaks into a PR or doc | V3 names it; every quoted controller line is redacted; `curl` reads from the shell environment; the BFF never logs `Authorization` (existing) |
| R13 | The dev live read cannot be observed in the sprint window (PRs unmerged, scripts not run, VPN) | Verdict 3 records **pending** with the precondition; nothing claims "done" without the capability report and a recorded response |
| R14 | Estimate at the top of the box | Cut order fixed (C8 → row; D7 → pending; B3 single-item variant → follow-up); goldens, include list and runbook protected |

## Dependencies

- **Code/infra:** the four shallow clones synced; JDK 17 at `/Library/Java/JavaVirtualMachines/jdk-17.0.1.jdk`; Gradle wrapper in both DT repos; Node ≥ 22 for the BFF; `kubectl` context `k8s-lower-wlr` ns `dev`; helm-configs signing key (`~/.ssh/id_ed25519_signing`, `/usr/bin/git -c gpg.format=ssh`).
- **Access (outside the cache, never printed):** LD dev/prod rights or a PLATFORM ticket for the two keys; the DT service credential already in MICO's config for the dev `curl` (step 4 verification, run by whoever holds it); PR rights on `abcfinancial/datatrak-service` and `abcfinancial/datatrak`.
- **Other owners' work (dependency with fallback, never a blocker):** PK's review of both DT PRs (fallback: PRs stay open, verdict 3 pending); Terry's scripts in dev (fallback: U3 fallback path proven in unit tests; D7 pending); Chancy's flag flips and a flagged test item (fallback: pending); PLATFORM secret keys (fallback: pending); CF-15 and RQ-0 untouched.
- **Decided before this sprint:** DataTrak service layer for reads (0004 Decision 3); mock-proven bar with live gates (0004 Decision 4); four verdicts; `guest-pass-online` as the BFF's club flag (CF-17).
- **Index leaves consulted:** `themes/feature-flags.md` (LaunchDarkly-per-service, local yml convention — matches both DT repos); `themes/dt-to-wallet-sync.md`, `datatrak-data-access.md` (why not direct Oracle). No leaf for the DT repos; everything above was read with `rg`/`sed` from `repos/`.

## Open Questions

**Positions taken in this draft (for the interview):** local response pair, not a jar bump (P1); two club-context keys, default off (P2); PR onto Chancy's branch with a review map (P3); G2 inside G1 via `guestPass=true` (P4); timezone normalised server-side, validated client-side (P5); `prospectLiability` base64 like `prospectTerms` (P6); SQL and shape goldens both (P7); reads self-heal on missing columns, writes do not (U3/U11).

**Requested (owner and date at kickoff; unanswered questions block only the named capability):**

| # | Question | Owner slot | Effect if unanswered |
|---|---|---|---|
| CF-19 | Will Chancy accept a flag-gating PR onto `feat/NOJIRA-guest-pass-email` (P3)? | Chancy | The review map ships as a written change request; verdict 1 for the M&O half reads "PR prepared, not opened" |
| CF-20 | Field names: `prospectLiability`, `timezone`, `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType`; request parameter `guestPass=true` | Chancy → PK | Proposed names ship in both PRs and the BFF; a rename is one class + one type |
| CF-21 | Liability column type (`VARCHAR2(4000)` vs `CHAR` semantics vs CLOB — G8) | Terry + Chancy | Wire convention unaffected; UI limit stays the M&O `MAX_VARCHAR` check |
| CF-22 | Accept the G9 script rewrite (`ADD … DEFAULT`, rerun guards)? | Terry | Scripts ship as in #6643; the runbook warns about the full-table UPDATE window |
| RQ-10 | Does PK prefer the local response pair (P1) or a jar bump of `internal-interface` now? | PK | Pair ships; jar bump recorded as RQ-12 follow-up |
| RQ-11 | Distinct `TZL_ABC_CODE` values in prod (`select distinct tzl_abc_code from timezonelookup`) | Chancy / Terry | Normalisation handles IANA and `SHORT_IDS`; anything else fails closed per club and is logged |
| RQ-12 | Follow-up: add the two fields to `internal-interface` and bump both consumers | PK / middleware owner | Local pair remains |
| RQ-13 | Which dev club gets the flagged test product and the liability text? | Chancy | D7 pending |
| RQ-14 | Should M&O reads (not writes) also self-heal on a missing column, like the service layer? | Chancy + PK | Position: no — pages fail loudly so a misordered flip is noticed; only the POS hook is wrapped |
| RQ-15 | Must a guest-pass product also be "Available online" (`cgi_online = '1'`) to be listed? | PRODUCT + Chancy | Position: yes; enablement guide sentence (V-P6) says both |
| RQ-16 | Who flips which flag in dev and when (dates become runbook rows); production flips are V-P1 | Chancy / PK / PLATFORM | Runbook rows carry owner slots without dates; verdict 3 pending |

**Carried (unchanged owners):** CF-13 and CF-14 move from "blocked" to "code prepared — pending DT review, merge, scripts and flag" at E3; CF-15, CF-17, CF-18, RQ-0 … RQ-9 as in contract §10; G3–G7, G10, G11, G13, G14 with the review's owners.

**Deferred (recorded so nobody rebuilds it):** jar bump (RQ-12); a sibling guest-pass endpoint (only if P4 is refused); M&O read self-healing (RQ-14); production flag flips and dates (V-P1); H2-backed DAO tests in datatrak (no harness exists — a separate decision for the DT team); CLOB migration (CF-21).
