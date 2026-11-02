# Sprint 0005: G1 — the guest-pass fields through the DataTrak service layer, with every production DB dependency behind a feature flag

**Status:** executed 2026-10-07 (Phase A single session; DTS / DTM / BFF lanes as parallel subagents; Phase E by the orchestrator) — PRs online-join-bff #112 (merged 2026-11-02 as `333b8e1`), datatrak-service #591 (merged 2026-11-02 as squash `4988e45`, PR head `086ec67`), datatrak #6800 and Chancy's #6643 (both merged to datatrak main 2026-10-20); online-join-bff #121 was closed unmerged on 2026-11-02, its import-order lint fix is in #112. The DT PRs were merged by their owners, the BFF and datatrak-service PRs by mithrandr; nothing was merged by this sprint, no script run, no flag flipped, no live read (verdict 3 pending with the runbook preconditions: the dev flag states and the DBA scripts, which Chancey Toombs and Paul Knuth have not confirmed). Execution record: `docs/sprints/drafts/SPRINT-0005-EXECUTION-SUMMARY.md`; ledger `SPRINT-0005`. Planned 2026-10-07 (three drafts, three critiques, interview and merge; see `docs/sprints/drafts/SPRINT-0005-*`). Owners named at kickoff.

**Sources (precedence in this order):** `docs/sprints/drafts/SPRINT-0005-INTENT.md` (seed and the flag rule); `docs/DT-21555-guest-pass-email-prd/REVIEW-2026-09-23.md` (G1; G2, G8, G9, G12 where the same code path is opened); `docs/contracts/short-term-pass-bff.md` v4 (§2, §8, §8a, §10); `docs/validation/guest-pass-pilot-gates.md` (V-P1); `docs/sprints/SPRINT-0004.md` (conventions, verdict vocabulary); the code facts in §Overview, which override the intent where they differ.

## Pyramid Index

- **L0:** Expose the guest-pass sale-item fields, the club liability text and the club timezone on the two DataTrak service-layer responses the Guest Pass BFF reads, add a club-scoped guest-pass items endpoint beside the club-defaults one (because the existing sale-items query returns services only and requires a member), and put every read or write of the new production columns — in `datatrak-service`, in Chancy's `datatrak` PR #6643, and in the BFF's consumption — behind two club-targetable LaunchDarkly flags that default off everywhere, so that code deploys before or after the DBA scripts without breaking anything, the scripts can be rolled back under deployed code, and the live catalog read (Sprint 0004 verdict 3) is switched on per environment and per club after the scripts land and off again without a release. Proven mock-first with goldens; the dev live read recorded as done or pending with the exact precondition; no production exposure. **Executed 2026-10-07:** the M&O half was already gated by PK on Chancy's branch (`MO_guest_day_pass_DT-21555`) and became an audit; local Gradle was unavailable (Artifactory / VPN) so the pull requests' CI was the compile and test run; the dev live read is pending (runbook R0–R5).
- **L1:**
  - **A — Freeze and feasibility (~1.5 days, one session).** DTO spike in both converters (gate), field-name table (contract v4.1), two flag keys, the service-only query finding and the club-scoped endpoint, complete gating inventory for PR #6643, delivery into Chancy's branch agreed, branches and ledger.
  - **B — datatrak-service PR (~4 days, DTS lane).** Flag `datatrak-service-DT-21555-guest-pass-fields`; `getClubDefaultExternal.spr` gains `prospectLiability` (base64 HTML like `prospectTerms`) and `timezone` on the on-path only; a new `/external/club/guestPassItems.spr?clubNumber=` lists the club's flagged deployed products without a member id and carries `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType`; the POS `saleItems.spr` endpoint, its validator and its queries are untouched; flag off ⇒ the club-defaults `main` SQL, binds, classes and bytes, and the new endpoint answers an unavailable envelope without executing any SQL; SQL and body goldens both ways; MICO JSON and XML consumer proof; tests in the `build.gradle` include list; Sonar green.
  - **C — datatrak PR #6643 flag-gating audit and gap-fill (~3 days planned; reduced at execution, DTM lane).** At A1 (2026-10-07) Paul Knuth had already pushed the gating onto Chancy's branch under flag **`MO_guest_day_pass_DT-21555`** (`0d0f2d06`…`77f12719`: every inventory site guarded, the POS email reordered club → flag → guest SQL and sent after commit, page fields gated server-side, the three existing tests updated, G9 done). The lane audits every inventory row against the code, fills the gaps (SQL + bind goldens for `CatalogItemsDB` / `CatalogItemDaoImpl` / `EditClubOnlineDaoImpl`, the local yml key, `never()` on the `ADD_GUEST` path, the duplicate import) and delivers a draft PR onto `feat/NOJIRA-guest-pass-email` with the review map.
  - **D — BFF consumption (~2.5 days, BFF lane).** Adapter on the confirmed names and the new club-scoped items endpoint; the {absent, off, on} × {club, items} matrix on recorded and labelled fixtures; strict timezone and item-type validation; capability report with an observed (never inferred-as-authoritative) flag state; liability path checked; dev `STP_CATALOG_SOURCE=datatrak` only after the DT dev flag is confirmed on, else pending with the reason; `online-join-ui` proof only.
  - **E — Runbook, proof, docs (~1.5 days, orchestrator).** `docs/deploy/guest-pass-db-and-flags.md` R0–R7 with owner, verification and rollback per step and the stop rules; contract v4.1; registers; V-P1a rewritten; smoke §live; ledger; PR descriptions; four verdicts.
- **L2:** §Overview (orientation findings; corrections; interview decisions; what stays with owners) · §Use Cases (U1–U20) · §Architecture (flags; club defaults; sale items; M&O gating inventory; BFF; goldens; rollout order) · §Implementation Plan (A–E) · §Files Summary · §Definition of Done (V0–V7; pilot gates touched; completion vocabulary) · §Risks & Mitigations · §Dependencies · §Open Questions.

## Overview

Sprint 0004 left the Guest Pass BFF reading the DataTrak service layer through `DatatrakServiceCatalog` and failing closed: the two `.spr` responses carry none of the fields it needs (CF-13) and `saleItems.spr` is member-scoped (CF-14). The handoff review found the cause (G1): Chancy's work adds columns and M&O screens but never touches the web-service layer. Orientation then found that the layer lives in a **second repository**, `abcfinancial/datatrak-service` (the image behind `datatrak-service.{dev,prod}.abcfitness.net`), so G1 is a second DataTrak PR. This sprint writes that PR, flag-gates Chancy's PR so neither repo ever executes SQL against a column that may not exist, aligns the BFF, and writes the rollout order down with owners. It merges nothing in the DataTrak repos, runs no scripts, flips no production flag, and claims no live read it cannot observe.

### Code facts that reshape G1 (read 2026-10-07; cite these)

1. **The online sale-items queries return services only.** `GET_ONLINE_SALE_ITEMS` and `GET_ONLINE_SALE_ITEM` (`repos/datatrak-service/dtWar/src/com/abcfs/repository/pos/sql/PointOfSaleSql.java:45,66`) filter `cgi.cgi_service = '1' and cgi.cgi_online = '1'`. Chancy's PR makes guest passes **products** (`EditCatalogItemsState.java:21-25`: product `0`, service `1`, billing `2`; `CatalogItemsDB` sets `guestPassItem = productItem && …`). Adding fields to that response is therefore not enough: a flagged product would never be a row, and the endpoint also requires a member id (CF-14). The plan reads the club's deployed items through a **new club-scoped endpoint** instead of modifying the POS one (interview 2026-10-07), and G12's `itemType` is essential.
2. **Both the DTO and the envelope are in a shared jar, and the XML path is JAXB.** `ClubDefaultExternal` (`com.abcfinancial.ws.api.common`) and `ClubDefaultExternalResponse` (`com.abcfinancial.ws.api.clubdefaults`) come from `com.abcfinancial.rest.api:internal-interface:4.2.0` (`dtWar/build.gradle:136`). `SpringConfiguration.java:280-285` sets `defaultContentType(APPLICATION_XML, APPLICATION_JSON)`; XML is produced by `Jaxb2RootElementHttpMessageConverter`, whose context is built from the root class only, so a runtime subclass placed in the jar-typed `club` field serialises in JSON and **fails in XML** unless registered. MICO's `WsClubDefaults.getDtClubDefaultExternal` (`repos/mico/.../WsClubDefaults.java:221-231`) uses a bare `RestTemplate` into the jar envelope and most likely receives XML; MICO's sale items go through Feign with `Accept: application/json` (`OrasvcClient.java:95`) into a tolerant mapper (`WsShop.java:46`). JSON tolerance is not XML tolerance.
3. **No H2 harness is wired in `datatrak`.** `dtWar/src/test/resources/schema.sql` carries the new columns, but nothing loads it (`rg` for `schema.sql`, `jdbc:h2`, `EmbeddedDatabaseBuilder` finds nothing; the build declares HSQLDB). The PR's own tests are Mockito/`mockStatic`. Absent-column safety is proven with SQL goldens and a state unit test, not with H2.
4. **The guest email runs new-column SQL before it knows the club.** `ProspectServiceTransactionsImpl.sendGuestPassSaleEmail` (branch, `:190-199`) calls `transactionContainsGuestPassItem` (reads `sai_guest_pass`) first and resolves the club afterwards. A club-context flag cannot guard it without reordering. Both `PointOfSaleDB` copies call it before publishing the POS event; six call sites (`EAEApi.java:974,1059`, `POSApi.java:131,194`, `PosPayPageCheckoutCompleteService.java:446`, `ElectronicAgreementDB.java:2583`).
5. **Flag evaluation without a club is not "off".** Both `FeatureService.computeBooleanFeature(key, vpdId, club, default)` implementations build a VPD-only or generic context when the club is absent and still call `boolVariation`; the DS variant has no exception-safe method. The helpers must return false locally before evaluation when no club can be established, and treat exceptions as off.
6. **Timezone exists.** `SERVICEPROVIDERLOCATIONS.TZL_ID → TIMEZONELOOKUP.TZL_ABC_CODE` (`TimeZoneSupport.java:52-62`; in datatrak-service the helper `getLocalTimeZoneAbcCode` is on `SessionInfo`, `SpringSessionInfo.java:697`, not on `JdbcClubDao` as the intent said). The value feeds `TimeZone.getTimeZone`, which silently returns GMT for unknown ids, so it is a Java zone id of unverified form (RQ-11).
7. **The two DataTrak repos already share a LaunchDarkly key** (`datatrak-DT-18445_disable_spring_auditUser` in both constants classes), so one shared key was feasible; two keys were chosen for independent rollback.
8. **The BFF validates nothing about the timezone today** (`datatrakServiceCatalog.ts:199-209` checks presence only) and maps every non-`SERVICE` type to product (`:171`); `requireShortTermPass.ts:54-66` evaluates `guest-pass-online` on every request before the adapter cache is consulted; adapter cache 60 s.
9. **DS `main` auto-deploys to dev** (`.github/workflows/ci-trunk.yml`), so default-off safety must exist before the DS PR is merged by its owner. DS tests run only if listed in `dtWar/build.gradle:284-305`; Sonar reads JaCoCo.

### Decisions (interview 2026-10-07)

| # | Decision | Alternatives recorded |
|---|---|---|
| D1 | **M&O gating delivered as a PR onto `feat/NOJIRA-guest-pass-email`** with a per-site review map, agreed with Chancy first (CF-19). | Stacked follow-up to `main` (leaves unflagged SQL on `main` and auto-deployed to dev); written change request only (recorded as the blocked deliverable if Chancy declines). |
| D2 | **A club-scoped items endpoint, not a mode on the POS one** (revised at the interview): NEW `/external/club/guestPassItems.spr?clubNumber=[&saleItemId=]` in `ClubExternalController`, behind the service flag, returning the club's active deployed products with `sai_guest_pass = '1'` and the four fields; no member id, no validator change, no enrichment; `POSController`, `OnlinePosValidator` and both POS queries stay byte-for-byte as on `main`. G2 (member-less POS listing) leaves the sprint because the BFF no longer calls `saleItems.spr`; G12 stays. | `saleItems.spr?guestPass=true` mode on the POS endpoint (rejected: touches the member-scoped endpoint MICO uses and needs the 400-parity work); defer the product listing (verdict 3 blocked by construction). |
| D3 | **Two flag keys**, club context, default off: `datatrak-service-DT-21555-guest-pass-fields` and — **superseded by a code fact at A1 (2026-10-07)** — the M&O key is PK's **`MO_guest_day_pass_DT-21555`** (constant `MO_GUEST_DAY_PASS`, `GuestDayPassFeatureFlag.isOn(club)`, commit `0d0f2d06` on `feat/NOJIRA-guest-pass-email`), not the planned `datatrak-DT-21555-guest-pass`; the runbook flips M&O first, then the service. | One shared key (feasible; loses independent rollback). |
| D4 | **Goldens:** SQL-string (+binds) goldens and full-body JSON/XML goldens stay; DataTrak page-byte goldens replaced by a server-side conditional, a state unit test and before/after screenshots (no JSP harness exists). | — |
| D5 | **Screens:** the only screens this sprint touches are the DataTrak M&O pages Chancy already changed (gated server-side). `online-join-ui` gets no planned code change — proof only. | — |
| A1–A3 | **Assumed (scope-cuts question unanswered; reversible at kickoff):** BFF HTML sanitiser deferred as a carried finding after a code check (D5 task); G9 rewrite optional, separate DBA-reviewed commit; BFF cache-transition test matrix reduced to a runbook rule. | — |

### What stays with its owner

G3 (POS sets the prospect window), G4/CF-15 (`addProspect` contract), G5/RQ-0 (two emails), G6 (email content), G7 (PRD wording), G10 (returns), G11 (recipient), G13 (enablement guide — one sentence added here), G14 (deployment details) are not opened except where a runbook sentence or a register row records them. LD `guest-pass-online`, the DT credential secret and Cloudflare remain PLATFORM/PK handoffs (contract §10).

## Use Cases

Environments per check: **unit** (Gradle / jest), **mock** (BFF fixtures), **dev** (the dev cluster; VPN; credential never printed). Clubs: `09003` (the dev club recorded in contract §8a) for datatrak-service; a dev test club Chancy flags for the end-to-end step (RQ-13). Fixture clubs 90030/90033 stay for the mock lane. "Byte-identical" means the full deterministic body through the real converters under fixed inputs, for `application/json`, `application/xml` and **no `Accept`** (DS defaults to XML).

| ID | Behaviour and required result | Source | Tasks |
|---|---|---|---|
| U1 | **Service flag off (default):** `GET /external/club/getClubDefaultExternal.spr?clubNumber=` executes the `main` SQL string with the `main` binds and answers byte-identical JSON and XML; the jar classes are the response types | seed rule; §8a | B2, B4 |
| U2 | **Service flag on:** response adds `club.prospectLiability` (base64 of `SPLEX_PROSPECT_LIABILITY`, `""` encoded when null — like `prospectTerms`) and `club.timezone` (zone id from `TZL_ABC_CODE`); every existing field, `branding` and `hideEnrollPage` unchanged; XML and JSON both carry the two elements; a club with no `spl_extensions` row or no timezone row is still returned (left joins) with the field absent | G1, G8 | B2, B4 |
| U3 | **Service flag on, columns absent (scripts not yet run):** the on-path club query fails with ORA-00904 → one warn per club `guest-pass.columns-absent` → the flag-off shape is answered (no 500). Only this read self-heals; this is a compatibility proof, not the rollout order | seed (a) | B2, B4 |
| U4 | **POS sale items untouched:** `GET /external/pos/saleItems.spr` source files, SQL constants and bytes are identical to `main` in both flag states (`git diff` shows no change under `controller/POSController.java`, `validator/OnlinePosValidator.java`, `repository/pos/**`, `api/pos/**`) | seed rule; D2 | B3, B4 |
| U5 | **Guest-pass items, flag on:** `GET /external/club/guestPassItems.spr?clubNumber=` → 200 with the club's active deployed items joined to their catalog item where `sai_guest_pass = '1'` and the item is a product (`cgi_service = '0'`), online rule per RQ-15; each item carries `saleItemId`, `catalogItemId`, `catalogItemName`, `catalogPrice`, `salePrice`, `taxed`, `guestPassOnline`, `guestPassContractDays`, `guestPassVisits` (from `SALEITEMS`, not catalog defaults), `itemType`; `&saleItemId=` narrows to one row for the BFF's re-read before side effects; no member, scheduling or branding call | G1, G12 | B3, B4 |
| U6 | **Guest-pass items, flag off (default) or club unknown:** 200 with the standard envelope `messages.status = error, text "Not available"` and `saleItems = null`, and **no SQL executed** (asserted with `never()` on the template); the BFF already treats a non-success envelope as "no offers" | seed rule | B3, B4 |
| U7 | **Guest-pass items, flag on, columns absent:** ORA-00904 → one warn per club → the U6 envelope (same self-healing rule as U3); never a 500 | seed (a) | B3, B4 |
| U8 | **Consumer safety:** on-state JSON of both endpoints deserialises into the jar `ClubDefaultExternalResponse` / MICO-shaped `SaleItemResponse` with Jackson; on-state club-defaults XML unmarshals with a JAXB context built from the jar classes (unknown elements / `xsi:type` ignored, observed not assumed) | fact 2 | A2, B4 |
| U9 | **M&O flag off:** catalog-item page and `CatalogItemsDB` select/insert/update and every sale-item sync statement, `CatalogItemDaoImpl` insert/update, Edit Club → Online page and `EditClubOnlineDaoImpl`, Fast Add, POS completion in both `PointOfSaleDB` classes run the `main` statements with the `main` binds; no statement references `CGI_GUEST_PASS*`, `SAI_GUEST_PASS*`, `SPLEX_PROSPECT_LIABILITY`; `ContactsDB.load` is never asked for `ADD_GUEST`; page markup, JS and validation for the new fields are not rendered (server-side); a posted guest value is ignored; existing guest data in the new columns is not cleared by an off-path save | seed rule | C2–C7 |
| U10 | **M&O flag on (club from the session or the transaction):** #6643 behaviour — fields editable on product items, 1–100 validation, sync to `SALEITEMS`, liability saved to `SPL_EXTENSIONS`, `handlePosTransactionCompleted` → `sendGuestPassSaleEmail` only for transactions with a guest-pass line, `ADD_GUEST` through `ContentsSuppliedEmail` | #6643; D61 | C2–C7 |
| U11 | **M&O flag on, columns absent:** page reads and writes fail loudly (not self-healed — the runbook forbids this order); the POS hook's guest-pass check is wrapped so a missing column logs and the sale completion and webhook publish proceed | seed (b); RQ-14 | C6, E1 |
| U12 | **No club context** (static DB helpers, no session, unresolvable transaction): the helper returns `false` **before** calling LaunchDarkly; debug log names the reason; never an exception | fact 5 | B1, C1 |
| U13 | **LaunchDarkly unavailable or throwing:** initialisation failure → off; evaluation exception → off (wrapped); a previously cached `true` is not assumed to clear — the runbook requires observed off on every instance before any drop | fact 5; R8 | B1, C1, E1 |
| U14 | **BFF, columns absent (today's recorded responses):** club incomplete (`missing: timezone`), offers none, gate 404, capability report `DT fields: absent (off, old code or columns missing — unknown which)` | §8a; CF-13 | D2, D4 |
| U15 | **BFF, DT flag off:** identical to U14 by construction; one test asserts the two fixture files are byte-equal | goldens | D2 |
| U16 | **BFF, DT flag on:** `guestPassItems.spr?clubNumber=` and `getClubDefaultExternal.spr` on the confirmed names → club resolves with a validated `timezone`, `prospectLiability` decoded as the waiver override, products with `guestPassOnline=true`, `guestPassVisits=1`, positive days eligible; services, multi-visit and unknown-type items skipped with reasons; report `DT fields: present`; synthetic fixtures renamed and still labelled synthetic until a dev recording replaces them | G1 | D1, D2, D4 |
| U17 | **BFF timezone validation:** an id Node rejects (`Intl.supportedValuesOf('timeZone')` + explicit alias map) → club fails closed with `missing: ['timezone:invalid']`; `America/Chicago` accepted; a Java-only alias is either mapped or closed, never GMT | fact 6 | D3 |
| U18 | **BFF liability text:** decoded `prospectLiability` reaches the UI through the same path as the club waiver today (`consentTemplates.ts:217-219` → `DocumentDialog` with `html-react-parser`); the D5 check records whether club HTML is rendered and registers the sanitiser as a carried finding with an owner (no new dependency this sprint unless the check finds new exposure) | G8; A1 | D5 |
| U19 | **UI:** zero eligible offers and flag-off both render the unavailable block (`ShortTermPassPage.tsx:151,189`; existing test re-run); no `online-join-ui` code change | 0004 U23; D5 | D6 |
| U20 | **Dev switch-over (gated):** only after Chancy confirms the service flag on for the test club in dev **and** PLATFORM has set `STP_DATATRAK_SERVICE_URL`/`AUTH` in the secret: helm `STP_CATALOG_SOURCE=datatrak` (signed PR, merged only then), one boot, capability report and `POST /checkouts` for the club recorded with scrubbed responses as `*.flag-on.recorded.json`; otherwise **pending** with the missing precondition named | criterion 3 | D7, E2 |

Regression (always): Sprint 0004 BFF/UI suites green; `requireShortTermPass` still 404s on missing club, flag or items; production guard unchanged; MICO's two consumers unaffected (U4, U8); datatrak-service's existing include-list tests green; Chancy's PR tests green with the flag on and updated for the flag off.

## Architecture

### 1. Flags (both DataTrak repos)

Both repos use `abc-starter-launchdarkly-lib` with `launchdarkly.localMode`/`localModeFile` (`launchdarkly-local.yml`, `flagValues:`) and test files (`featureflag-local.yml`). Constants live in each repo's `LDFeatureFlagConstants`.

| Repo | Constant | Key | Evaluator | Context | Default |
|---|---|---|---|---|---|
| datatrak-service | `GUEST_PASS_FIELDS` | `datatrak-service-DT-21555-guest-pass-fields` | NEW `com/abcfs/launchdarkly/helper/GuestPassFeature.isOn(clubNumber)`: canonical five-digit club number required → else `false` locally; `computeBooleanFeature(key, vpdFromThread, club, false)`; any exception → `false` + warn | `club` (+ `vpd` when set) | off everywhere |
| datatrak | `MO_GUEST_DAY_PASS` (PK, `0d0f2d06`) | `MO_guest_day_pass_DT-21555` | PK's static `GuestDayPassFeatureFlag.isOn(clubNumber)` (blank club → `false` locally; `FeatureService` missing or throwing → `false` + warn; `FEATURE_FLAG_KIND_CLUB`); club from the session for pages, from `ClubDB.getClubNumber(connection, clubId)` per destination for the sale-item sync, from `PointOfSaleDaoImpl.getClubNumber(posTransactionId)` for the POS email | `club` | off everywhere |

Rules: one decision per operation, captured once and shared by query selection, bind list and row mapper (a flip mid-operation cannot mix paths); the caller's query string is never a club context; keys `false` in both local yml files; constants tests extended.

### 2. Club defaults (`/external/club/getClubDefaultExternal`)

```
ClubExternalController.getClubDefaultExternal(clubNumber)  →  ClubExternalServiceImpl.getClubDefaultExternal
  off: dtManagedClubDao.getClubDefaultExternal        → GET_CLUB_DEFAULT_EXTERNAL (unchanged) → ClubDefaultExternalRowMapper (unchanged)
       + branding + hideEnrollPage                    → jar ClubDefaultExternalResponse                                    [byte-identical]
  on : dtManagedClubDao.getClubDefaultExternalGuestPass
       → GET_CLUB_DEFAULT_EXTERNAL_GUEST_PASS = same select
           + LEFT JOIN spl_extensions splex ON splex.spl_id = spl.spl_id AND splex.vpd_id = spl.vpd_id
           + LEFT JOIN timezonelookup tzl ON tzl.tzl_id = spl.tzl_id
           selecting splex.SPLEX_PROSPECT_LIABILITY "prospectLiability", tzl.tzl_abc_code "timezone"
       → GuestPassClubDefaultExternalRowMapper (delegates shared columns; base64 like prospectTerms; zone id normalised: ZoneId.of → SHORT_IDS → raw + warn)
       + branding + hideEnrollPage                    → the on-path response type decided by A2
       on BadSqlGrammarException whose cause is ORA-00904: warn once per club, answer the off path (U3)
```

**DTO (A2 spike, gate):** try (a) local `GuestPassClubDefaultExternalResponse extends ClubDefaultExternalResponse` with the same `@XmlRootElement` name and `@XmlSeeAlso(GuestPassClubDefaultExternal.class)`, `GuestPassClubDefaultExternal extends ClubDefaultExternal` with `@XmlElement(required=false)` + `@JsonInclude(NON_NULL)` fields, returned only on the on-path; prove through the app's real Jackson and JAXB converters (JSON, XML, no-`Accept`) and (b) a JAXB unmarshal of the produced XML into the **jar** envelope (what MICO does) — the `xsi:type` on `<club>` must be ignored. If (a)+(b) pass: no jar bump. If not: additive fields in `internal-interface` (another repo and release; RQ-12) and B2 waits — the calendar risk is named in R2. No bare subclass, no `@JsonUnwrapped`, no dynamic map, no global null-serialisation change.

### 3. Guest-pass items (NEW `/external/club/guestPassItems`)

A club-scoped read of the club's deployed items, placed in `ClubExternalController` beside `getClubDefaultExternal` (same `@Stateless`, same `produces`, same header match, same `setVpdFromClubNumber` prelude). The POS endpoint, its validator, its two queries and its DTOs are **not touched**.

```
ClubExternalController.getGuestPassItems(clubNumber, saleItemId?)   →   ClubExternalServiceImpl.getGuestPassItems
  vpd = clubDao.setVpdFromClubNumber(clubNumber); vpd == 0 → unavailable envelope
  !GuestPassFeature.isOn(clubNumber) → unavailable envelope, no SQL (U6)
  on : dtManagedClubDao.getGuestPassItems(splId, saleItemId?)
       → GET_GUEST_PASS_ITEMS: SELECT sai.sai_id, cgi.cgi_id, cgi.cgi_name, cgi.cgi_sale_price, sai.sai_sale_price,
            <taxed CASE copied from GET_ONLINE_SALE_ITEMS>, sai.sai_guest_pass, sai.sai_guest_pass_visits, sai.sai_guest_pass_contract_days, cgi.cgi_service
          FROM saleitems sai JOIN catalogitems cgi ON cgi.cgi_id = sai.cgi_id
          WHERE sai.spl_id = :splId AND sai.sai_active = '1' AND cgi.cgi_active = '1' AND sai.sai_guest_pass = '1' AND cgi.cgi_service = '0'
            [AND cgi.cgi_online = '1' per RQ-15] [AND sai.sai_id = :saleItemId]
          ORDER BY cgi.cgi_name
       → GuestPassItemRowMapper → GuestPassItemResponse { club, saleItems { saleItem[] }, messages }   (local JAXB DTOs, same envelope style as SaleItemResponse)
       on BadSqlGrammarException whose cause is ORA-00904: warn once per club → unavailable envelope (U7)
```

Response types are local to datatrak-service (`com/abcfs/club/external/api/GuestPassItem{,Response}.java`), so no jar is involved. Field names are the proposal (CF-20). `itemType` is derived from `cgi_service` (`0` PRODUCT, `1` SERVICE, `2` BILLING) and is always `PRODUCT` here by the `WHERE`; it is kept on the wire so the BFF's strict type check and the contract stay uniform. Because the endpoint does not exist on `main`, "flag off is today" for items means two things: the POS files are byte-identical (U4), and the new endpoint executes no SQL when off (U6).

### 4. M&O gating inventory (datatrak PR #6643)

Every site gets `if (GuestDayPassFeatureFlag.isOn(…))` around the **new** behaviour, with the `main` statement and bind list retained verbatim as the else-branch. **Execution note (A1, 2026-10-07):** PK implemented this table on Chancy's branch before the lane started; the verified per-site inventory with PK's guard, the off-branch, the proof task and the remaining gap is `docs/sprints/drafts/SPRINT-0005-BLOCKERS.md` §A4 — the DTM lane works from that table. Planned review map (becomes the C9 PR body; A4 verified it against `rg`):

| Site (branch) | What the PR added | Off-branch | Context |
|---|---|---|---|
| `CatalogItemsDB` select (~472), insert (~574-576, 63 placeholders), update (~886, ~925), sale-item sync statements (~1078, ~1108, ~1124-1125) | guest columns in each | `main` strings and binds for every statement, listed one by one; the off mapper never reads guest columns | editing club from the session; per-destination evaluation during sync only if A3 says catalogs are edited across clubs (CF-23) |
| `CatalogItemDaoImpl.updateSaleItemRecord` / `insertSaleItemRecord` (~149-183) | guest columns in both | `main` statements; both callers audited | destination club |
| `EditCatalogItemsState`, `EditCatalogItemsSecondaryPage(.java,.jsp)` | three fields, product-only reset, 1–100 and active validation, JS | fields and JS not rendered (server-side conditional on the state), validation skipped, posted values ignored, state values forced `"0"` | session club |
| `EditClubOnlineDaoImpl` load (merged SELECT, ~28-40) and `saveProspectContent`; `EditClubServiceImpl`; `EditClubOnlineProspect(.java,.jsp)` | liability join, second update, field + size check | **separate legacy SELECT string** and `saveTermsAndConditions`; field not rendered; size check gated | club being edited |
| `JdbcClubDao.getProspectLiabilityLanguage` | new query | reachable only from the gated email path | — |
| `ProspectServiceTransactionsImpl.sendGuestPassSaleEmail` (~190) | `transactionContainsGuestPassItem` → club → liability → `ContentsSuppliedEmail(ADD_GUEST,…)` | **reordered**: `getClubNumber(posTransactionId)` (old schema) → flag → only then the guest SQL; early return when off (second guard) | transaction's club |
| `sales/...PointOfSaleDB` and `sales3/...PointOfSaleDB` `handlePosTransactionCompleted` | guest email before the webhook publish | call skipped when off; `publishPosTransactionCompletedEvent` and its return value unchanged; the guest check wrapped so a missing column never fails the sale (U11) | as above |
| Call sites `EAEApi`, `POSApi`, `PosPayPageCheckoutCompleteService`, `ElectronicAgreementDB` | swapped to `handlePosTransactionCompleted` | unchanged (pass-through when off) | — |
| `JdbcMemberDao.getGuestEmailInformation` | new query on existing columns | not gated (no new column) — noted | — |
| Existing PR tests `ProspectServiceTransactionsImplEmailTest`, both `PointOfSaleDBGuestEmailTest` | assert the email unconditionally | updated for off (`verify(never())`) and on | — |
| `sql/*.sql` | — | G9 rewrite offered as a separate DBA-reviewed commit (CF-22) | — |

### 5. BFF consumption

`DatatrakServiceCatalog` changes in five places: `getOffers` calls `/club/guestPassItems.spr?clubNumber=` instead of `/pos/saleItems.spr?club=` (and `&saleItemId=` for the single-item re-read); wire types renamed to the confirmed names; `mapClubDefault` reads `prospectLiability` into `waiverText` and validates `timezone` (`Intl.supportedValuesOf('timeZone')` + explicit alias map; invalid → `missing: ['timezone:invalid']`); `mapSaleItem` accepts only `PRODUCT`/`SERVICE`/`BILLING` and rejects missing or unknown types (skip reason `unknown-type`); the `ClubReport` gains `dtFields: 'present' | 'absent'` with the wording "absent (off, old code or columns missing — unknown which)" — an **observation**, never a claim about the remote flag; operator-confirmed LD state lives in the smoke doc. `requireShortTermPass` is unchanged (it already evaluates the exposure flag per request before the cache). Fixtures: `getClubDefaultExternal.recorded.json` (2026-09-18) = absent/off case for the club; the two `saleItems.*.recorded.json` files are kept as history of CF-14 and a new `guestPassItems.unavailable.synthetic.json` (the U6 envelope) is the off case for items; `*.synthetic.json` renamed and still labelled; the `*.flag-on.recorded.json` slot documented for the first scrubbed dev recording. Cache rule (runbook, not a test matrix): exposure flag off first, then TTL (60 s) or restart before any upstream flip is treated as withdrawn.

### 6. Goldens (the proof of "flag off is today")

- **SQL goldens (both DT repos):** `ArgumentCaptor` on the mocked `NamedParameterJdbcTemplate` / `JdbcTemplate` (and on the static DB helpers' connection in `datatrak`, in the PR's `mockStatic` style) captures the executed SQL **and the bind parameters**; off-path captures equal constants copied from `main`; on-path captures contain the new selects and the widened `WHERE`; negative assertions (`never()`) for every new-column statement, for the `ADD_GUEST` lookup, and for the guest-pass items query when off.
- **Body goldens (datatrak-service):** serialise off- and on-path responses through the app's real converters for `application/json`, `application/xml` and no `Accept`; off bodies equal recorded baselines captured from `main` under fixed inputs (scrubbed §8a fixtures as the starting point); on bodies equal off + the new elements only. Success and error envelopes both. Precedent: `POSControllerCommentTest` marshals with `JAXBContext`.
- **Consumer goldens:** on-state XML unmarshalled into the jar envelope; on-state JSON into the jar/MICO classes.
- **M&O pages:** server-side conditional on the state object; unit test that the off-path state carries no guest fields and the off-path render path is not entered; before/after screenshots in the PR (no JSP harness).
- **`rg` map:** every hit for `GUEST_PASS`, `SPLEX_PROSPECT_LIABILITY`, `ADD_GUEST`, `guestPass` in both repos listed with its guard (A4), re-run at E2.

### 7. Rollout order (the runbook's spine; owner slots until kickoff)

| Step | Owner slot | Verification (no secret, no customer data) | Rollback / stop rule |
|---|---|---|---|
| R0 — Create both DT keys (dev + prod; default off; club targeting); pin releases | PLATFORM / Chancy / PK | off observed for a selected and an unselected club; BFF override and fixture config recorded | nothing to roll back; do not proceed if off is unobserved |
| R1 — DBA preflight and scripts in dev | Terry Smith | seven columns in `user_tab_columns`; template rows and `CTEM_UNIQUE_BILLING` collision check; target club's `ADD_GUEST` location row; backup / export | flags stay off; partial migration is not enableable; repair or approved rollback |
| R2 — Deploy reviewed code with flags off (DS via `main` auto-deploy; DT per its release) | Chancy / PK; BFF owner | pinned revisions; off goldens green in CI; dev JSON/XML of both endpoints diffed against the recorded fixtures = no change | previous tag (`deploy-by-tag.yml`); schema stays |
| R3 — M&O flag on for the dev test club; configure one product (guest pass, visits 1, contract days N, active, online); Edit Club liability text | Chancy + QA | `SALEITEMS` row shows the three values for the club; disabled clubs unchanged; POS test sale sends `ADD_GUEST` to an approved sink | flag off; verify quiescence; data stays |
| R4 — Service flag on for the dev test club | Chancy / PK + QA | both endpoints (JSON and XML) carry the fields; member-less product listing; MICO dev shop unchanged; timezone valid | flag off; verify the off body after drain; BFF still dark |
| R5 — `STP_DATATRAK_SERVICE_URL`/`AUTH` into the BFF secret; helm `STP_CATALOG_SOURCE=datatrak` (signed PR, merged only now) | PLATFORM + Bjorn | capability report `dtFields: present`; `POST /checkouts` 201 for the club via port-forward | `STP_CATALOG_SOURCE=fixture` (restores the mock demo, labelled as such; not proof that live exposure was withdrawn) |
| R6 — `guest-pass-online` per dev club (override stands in until CF-17) | PLATFORM + QA | page lists the live item; unavailable negative control | exposure flag off first; observe refusal; TTL or restart |
| R7 — Schema rollback rehearsal (dev only) | Terry + Chancy / PK + QA | BFF exposure off → both DT flags **observed off on every instance** → drain → export new values → scripts' rollback → U1/U4/U9 re-run on the deployed code | if propagation or drain cannot be proved, **do not drop** |

Production rows exist in the runbook with owner slots and no dates (V-P1). Oracle DDL is not a transaction: flags make code compatible; they do not make dropped data recoverable.

## Implementation Plan

**Sizing:** ~12 engineering days — A (~1.5, one session) → B (DTS lane, ~4) ∥ C (DTM lane, ~3) ∥ D (BFF lane, ~2.5) → E (~1.5, orchestrator). **Vertical slice first:** A2 spike → B1 + B2 (club defaults both ways with goldens) → D1 + D2 (BFF reads the on shape from a fixture). **Cut order if lanes run long:** C8 (G9) → register row; D7 (dev switch-over) → pending with reason; B3's `saleItemId` filter → follow-up with the contract saying list-only (the BFF then re-reads the list). Never cut the goldens, the include-list entry, the inventory or the runbook. Execution as in Sprint 0004: A by one session, then three detached lanes against the frozen field table, each with blockers and summary files; the orchestrator owns E. No lane merges anything in a DataTrak repo; no lane prints a credential; no lane probes a remote host without the recorded precondition.

### A — Freeze and feasibility · ~1.5 days · one session

| # | Task | Files | Done when |
|---|---|---|---|
| A1 | Sync the shallow clones; branches `prospect-wallet/sprint-0005` (online-join-bff), `DT-21555-guest-pass-service-fields` (datatrak-service off `main`), `DT-21555-guest-pass-flag-gating` (datatrak off `feat/NOJIRA-guest-pass-email`); ledger `in-progress` with heads; day-one build baseline in both DT repos (`./gradlew :dtWar:test` on JDK 17) with pre-existing failures named | clones; `docs/sprints/ledger.yaml` | branches, heads and baselines recorded |
| A2 | **DTO and converter spike (½ day, gate):** §2 (a)+(b) with the real 4.2.0 jar and the app's converters; XML/JSON/no-`Accept`; MICO-side JAXB unmarshal; record pass → local pair, or fail → jar route with owner and calendar impact | NEW `test/java/com/abcfs/club/external/api/GuestPassClubDefaultSerializationSpikeTest.java` (kept as a test if it passes) | decision recorded in contract §8a(e) |
| A3 | **Contract v4.1 field table** (`docs/contracts/short-term-pass-bff.md` §8): endpoint, request mode, field, type, source column, encoding, null-when, flag; "proposed until CF-20"; the online rule for products (RQ-15); liability byte limit (CF-21); shared-catalog editing context (CF-23); the MICO XML finding | contract §2, §8, §8a, §10 | table frozen; D1 codes against it |
| A4 | **Gating inventory** = §4 table verified with `rg -n 'GUEST_PASS|SPLEX_PROSPECT_LIABILITY|ADD_GUEST|guestPass'` on the branch and the planned DS sites; every hit has a guard, a task and a negative test | NEW `docs/sprints/drafts/SPRINT-0005-BLOCKERS.md` §Gating inventory | matches `rg`; Chancy has seen it (CF-19 asked) |
| A5 | Flag keys registered (names, contexts, defaults) in the contract and the PLATFORM/Chancy handoff; local yml entries drafted; RQ-11 (distinct `TZL_ABC_CODE` values) and RQ-13 (dev test club) asked | contract §10; handoff text | keys named once, identically, everywhere |

### B — datatrak-service PR · ~4 days · DTS lane (paths under `repos/datatrak-service/dtWar/`)

| # | Task | Files | Done when |
|---|---|---|---|
| B1 | Flag plumbing: constant; `GuestPassFeature` helper (no club → `false` locally; exception → `false` + warn; canonical club number); keys in both yml files; constants test; helper test (missing context, mismatch, exception, targeted/untargeted) | `src/com/abcfs/launchdarkly/LDFeatureFlagConstants.java`, NEW `…/launchdarkly/helper/GuestPassFeature.java`, `src/resources/launchdarkly-local.yml`, `test/resources/featureflag-local.yml`, tests | U12, U13 pinned |
| B2 | Club defaults both ways per §2: new SQL constant (left joins), DAO method, on-path mapper and response types per A2, service branch, narrowed ORA-00904 fallback with once-per-club warn | `src/com/abcfs/club/external/dao/{DtManagedClubSql,DtManagedClubDao,DtManagedClubDaoImpl}.java`, `…/service/{ClubExternalService,ClubExternalServiceImpl}.java`, `…/controller/ClubExternalController.java`, NEW `…/club/external/api/GuestPassClubDefaultExternal{,Response}.java`, NEW `src/com/abcfs/repository/club/mapper/GuestPassClubDefaultExternalRowMapper.java` | U1–U3 at service level |
| B3 | Guest-pass items endpoint per §3: controller method, service method, flag check before any SQL, one new SQL constant with optional `saleItemId`, DAO method, row mapper, local response DTOs, unavailable envelope, narrowed ORA-00904 fallback; POS files untouched | `src/com/abcfs/club/external/{controller/ClubExternalController,service/ClubExternalService,service/ClubExternalServiceImpl,dao/DtManagedClubSql,dao/DtManagedClubDao,dao/DtManagedClubDaoImpl}.java`, NEW `src/com/abcfs/club/external/api/GuestPassItem{,Response}.java`, NEW `src/com/abcfs/repository/club/mapper/GuestPassItemRowMapper.java` | U4–U7 at controller level; `git diff --stat` shows no POS file |
| B4 | Goldens per §6: SQL + binds; bodies for three media types; consumer unmarshal; fallback; controller tests in the `ClubExternalControllerTest` style | NEW `test/java/com/abcfs/club/external/{service/ClubExternalServiceImplGuestPassTest,dao/DtManagedClubDaoImplGuestPassSqlTest}.java`, NEW `test/java/com/abcfs/club/external/controller/ClubExternalControllerGuestPassItemsTest.java`, NEW `test/java/com/abcfs/club/external/dao/DtManagedClubDaoImplGuestPassItemsSqlTest.java`, NEW `test/java/com/abcfs/club/external/api/GuestPassItemSerializationTest.java`, `test/resources/guest-pass/*` | U1–U8 pinned |
| B5 | Add every new test to the `include` list; `./gradlew :dtWar:test` report names them; JaCoCo covers the new code; README note corrected | `build.gradle:284-305`, `README.md` | V6 evidence |
| B6 | PR `DT-21555 Expose the club liability text and timezone on getClubDefaultExternal.spr and add a club-scoped guestPassItems.spr, behind a feature flag`: field table, key, off proof, consumer safety, runbook pointer; **no header literal, no credential**; CI + Sonar green; reviewers PK + Chancy | PR on `abcfinancial/datatrak-service`; `docs/sprints/drafts/SPRINT-0005-PR-DESCRIPTIONS.md` | PR open and green; link in the ledger |

### C — datatrak PR #6643 flag-gating pass · ~3 days · DTM lane (branch off `feat/NOJIRA-guest-pass-email`; never rewrite or force-push Chancy's branch)

**Executed as an audit and gap-fill (2026-10-07):** C1–C6 and C8 were found implemented by PK on the branch head `77f1271` (key `MO_guest_day_pass_DT-21555`); the lane verifies each row below against the code, adds the missing goldens and tests (C7), the local yml key and the small fixes listed in `SPRINT-0005-BLOCKERS.md` §A4, and opens the draft PR (C9). The task rows are kept as the checklist the audit answers.

| # | Task | Files | Done when |
|---|---|---|---|
| C1 | Flag plumbing: constant; static `GuestPassFeature` helper (session / transaction club; no club → `false` locally); keys in yml; tests | `com/abcfinancial/datatrak/common/launchdarkly/{LDFeatureFlagConstants,feature/GuestPassFeature}.java`, `dtWar/src/main/resources/launchdarkly-local.yml`, tests | U12, U13 (datatrak) |
| C2 | `CatalogItemsDB`: every statement in the inventory (select, insert, update, each sync) with the `main` string and binds as the off-branch; off mapper reads no guest column; posted values ignored when off | `com/seqtek/abcfs/dt/inventory/catalogItems/CatalogItemsDB.java` | SQL goldens both ways |
| C3 | `CatalogItemDaoImpl` insert/update and their callers gated by destination club | `com/abcfs/inventory/catalogItems/repository/{CatalogItemDao,CatalogItemDaoImpl}.java` | SQL goldens both ways |
| C4 | Catalog page: server-side conditional (fields, JS, validation, product reset); state values forced `"0"` when off; before/after screenshots | `…/catalogItems/{EditCatalogItemsState,EditCatalogItemsSecondaryPage}.java`, `…/jsp/inventory/catalogItems/EditCatalogItemsSecondaryPage.jsp` | state unit test; screenshots in the PR |
| C5 | Edit Club liability: separate legacy SELECT; `saveTermsAndConditions` as the off-branch; service passes the decision; field not rendered; size check gated | `com/abcfs/repository/editClub/{EditClubOnLineDao,EditClubOnlineDaoImpl}.java`, `com/abcfs/services/EditClubServiceImpl.java`, `com/seqtek/abcfs/dt/cfg/editclub/online/EditClubOnlineProspect.java`, `…/jsp/editClub/online/EditClubOnlineProspect.jsp` | SQL goldens; terms still load/save |
| C6 | POS hook: reorder (club → flag → guest SQL) in `sendGuestPassSaleEmail`; early return when off; both `PointOfSaleDB` wrappers skip the call when off and always publish; guest check wrapped (U11); six call sites audited | `com/abcfs/services/ProspectServiceTransactionsImpl.java`, both `PointOfSaleDB.java`, `com/abcfs/sales3/repository/PointOfSaleDaoImpl.java` | U9–U11 (POS) pinned |
| C7 | Tests in the PR's style: update the three existing tests for off/on; NEW SQL golden tests for C2/C3/C5; `never()` for `ContactsDB.load(ADD_GUEST)` when off; `GuestPassFeatureTest` | `dtWar/src/test/java/…` (TestNG, Mockito, `mockStatic`) | both states green; suite baseline from A1 unchanged |
| C8 | Optional G9 (separate commit, DBA-reviewed): `ALTER TABLE … ADD (col … DEFAULT …)` without the full-table `UPDATE`; rerun guards; identical end state; handoff doc updated | `sql/*.sql`, `docs/DT-21555-guest-pass-email-prd/…` | Terry has the diff (CF-22) or the row says deferred |
| C9 | PR onto `feat/NOJIRA-guest-pass-email`: `DT-21555 Gate the guest-pass columns, liability field and ADD_GUEST email behind datatrak-DT-21555-guest-pass`; body = A4 map; CI green | PR on `abcfinancial/datatrak` | PR open; Chancy acknowledged (CF-19) |

### D — BFF consumption · ~2.5 days · BFF lane (paths under `repos/online-join-bff/src/services/shortTermPass/`)

| # | Task | Files | Done when |
|---|---|---|---|
| D1 | Wire types on the field table; `getOffers` and the single-item re-read call `guestPassItems.spr`; `mapSaleItem` strict type; `mapClubDefault` reads `prospectLiability`; the U6 unavailable envelope maps to "no offers" with reason `unavailable` | `adapters/platform/datatrakServiceCatalog.ts`, `catalogEligibility.ts` (`unknown-type`) | U16 mapper half |
| D2 | Matrix fixtures and tests: club recorded = absent/off (byte-equality assertion); items off = the U6 envelope fixture; synthetic renamed to `guestPassItems.synthetic.json` and relabelled; README slot for `*.flag-on.recorded.json`; `describe('matrix')` six cells; CF-13/CF-14 tests kept as history | `fixtures/datatrak/*`, `__tests__/datatrakServiceCatalog.test.ts` | U14–U16 pinned |
| D3 | Timezone validation with alias map; `timezone:invalid` | adapter + tests | U17 pinned |
| D4 | Capability report `dtFields` observation wording; demo prints it | adapter, `scripts/short-term-pass-demo.ts` | U14/U16 report lines pinned |
| D5 | Liability path check: trace `waiverText` → `consentTemplates.ts:217-219` → `DocumentDialog`; record HTML or text; register the sanitiser as a carried finding with an owner; code change only if new exposure is found | `fixtures/consentTemplates.ts` (read), UI `DocumentDialog.tsx` (read) | U18 recorded with evidence |
| D6 | UI proof: re-run the unavailable-block tests; no code change | `repos/online-join-ui/__tests__/routes/ShortTermPass/ShortTermPassPage.test.tsx` | U19 recorded |
| D7 | Dev switch-over (gated by R4 + secret): helm `STP_CATALOG_SOURCE=datatrak` (signed), boot, capability report and `POST /checkouts` via port-forward, scrubbed recording; else **pending** with the precondition | `repos/helm-configs/online-join-bff/dev.yaml`, `docs/deploy/dev.md` | U20 done or pending |
| D8 | Contract §8/§8a/§10 rows; PR `feat: read the guest-pass fields from the DataTrak service layer (contract v4.1)`; browser contract unchanged | contract; PR on `online-join-bff` | PR open, Sonar green |

### E — Runbook, proof, docs · ~1.5 days · orchestrator

| # | Task | Evidence |
|---|---|---|
| E1 | Runbook `docs/deploy/guest-pass-db-and-flags.md`: §7 per environment with owner, verification, rollback and stop rules; the flags-off-before-drop rule; U11 ordering warning; cache rule; registered in V-P1a (rewritten as R0–R7 rows) and contract §10 | runbook; `docs/validation/guest-pass-pilot-gates.md`; contract §10 |
| E2 | Proof: BFF jest + lint + coverage; DS Gradle report naming the new tests; DT suite on the gating branch vs the A1 baseline; demo green; `rg` map re-run; D7 result; smoke §live | NEW `docs/validation/short-term-pass-sprint-0005-smoke.md` |
| E3 | Registers: CF-13/CF-14 → "code prepared — pending DT review, merge, scripts, flag"; CF-19…CF-25, RQ-10…RQ-16; G1 traceability | contract §10; NEW `docs/validation/short-term-pass-sprint-0005-traceability.md` |
| E4 | Docs and status: `docs/SEMANTIC-INDEX.md` Sprint 0005 code map; ledger; three PR descriptions; execution summary with four verdicts | as named |

Local commands:

```text
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-17.0.1.jdk/Contents/Home
cd repos/datatrak-service && ./gradlew :dtWar:test --tests '*GuestPass*'
cd repos/datatrak && git switch DT-21555-guest-pass-flag-gating && ./gradlew :dtWar:test --tests '*GuestPass*' --tests '*GuestEmail*'
cd repos/online-join-bff && npm ci --ignore-scripts && npm test -- datatrakServiceCatalog && npm run lint && npm run build
# dev, only after R4/R5 (URL and credential from the shell environment, never echoed)
kubectl --context k8s-lower-wlr -n dev port-forward deploy/online-join-bff 18080:8080
```

## Files Summary

| Repo | Paths | Action |
|---|---|---|
| datatrak-service | `dtWar/src/com/abcfs/launchdarkly/LDFeatureFlagConstants.java`; `dtWar/src/com/abcfs/club/external/{controller/ClubExternalController,service/ClubExternalService,service/ClubExternalServiceImpl,dao/DtManagedClubSql,dao/DtManagedClubDao,dao/DtManagedClubDaoImpl}.java`; `dtWar/src/resources/launchdarkly-local.yml`; `dtWar/test/resources/featureflag-local.yml`; `dtWar/build.gradle`; `README.md` | MODIFY |
| datatrak-service | `…/launchdarkly/helper/GuestPassFeature.java`; `…/club/external/api/GuestPassClubDefaultExternal{,Response}.java`; `…/repository/club/mapper/{GuestPassClubDefaultExternalRowMapper,GuestPassItemRowMapper}.java`; `…/club/external/api/GuestPassItem{,Response}.java`; tests `…GuestPass*Test.java`, `test/resources/guest-pass/*` | NEW |
| datatrak (PR onto `feat/NOJIRA-guest-pass-email`) | `com/abcfinancial/datatrak/common/launchdarkly/LDFeatureFlagConstants.java`; `com/seqtek/abcfs/dt/inventory/catalogItems/{CatalogItemsDB,EditCatalogItemsState,EditCatalogItemsSecondaryPage}.java` + `.jsp`; `com/abcfs/inventory/catalogItems/repository/{CatalogItemDao,CatalogItemDaoImpl}.java`; `com/abcfs/repository/editClub/{EditClubOnLineDao,EditClubOnlineDaoImpl}.java`; `com/abcfs/services/{EditClubServiceImpl,ProspectServiceTransactionsImpl}.java`; `com/seqtek/abcfs/dt/cfg/editclub/online/EditClubOnlineProspect.java` + `.jsp`; `com/seqtek/abcfs/dt/sales/common/repository/PointOfSaleDB.java`; `com/seqtek/abcfs/dt/sales3/common/repository/PointOfSaleDB.java`; `com/abcfs/sales3/repository/PointOfSaleDaoImpl.java`; `dtWar/src/main/resources/launchdarkly-local.yml`; three existing PR tests; optional `sql/*.sql` | MODIFY |
| datatrak | `…/launchdarkly/feature/GuestPassFeature.java`; tests `GuestPassFeatureTest`, `CatalogItemsDBGuestPassSqlTest`, `CatalogItemDaoImplGuestPassSqlTest`, `EditClubOnlineDaoImplGuestPassTest` | NEW |
| online-join-bff | `src/services/shortTermPass/adapters/platform/datatrakServiceCatalog.ts`, `catalogEligibility.ts`, `fixtures/datatrak/*`, `__tests__/datatrakServiceCatalog.test.ts`, `scripts/short-term-pass-demo.ts` | MODIFY |
| online-join-ui | none (D5/D6 read only) | READ |
| helm-configs | `online-join-bff/dev.yaml` — signed PR, merged only after R4 and the secret | MODIFY (gated) |
| this repo | `docs/contracts/short-term-pass-bff.md` (v4.1), `docs/validation/guest-pass-pilot-gates.md`, `docs/deploy/dev.md`, `docs/SEMANTIC-INDEX.md`, `docs/sprints/ledger.yaml` | MODIFY |
| this repo | `docs/deploy/guest-pass-db-and-flags.md`; `docs/validation/short-term-pass-sprint-0005-{smoke,traceability}.md`; `docs/sprints/drafts/SPRINT-0005-{BLOCKERS,EXECUTION-SUMMARY}{,-DTS,-DTM,-BFF}.md`; `docs/sprints/drafts/SPRINT-0005-PR-DESCRIPTIONS.md` | NEW |
| Handoffs (outside the cache) | two LD keys (PLATFORM / Chancy); `STP_DATATRAK_SERVICE_URL`/`AUTH` in `platform-online-join-bff` (PLATFORM); scripts in dev (Terry); flag flips (Chancy / PK); PR reviews (PK, Chancy); `guest-pass-online` (CF-17) | register rows |

Not modified: `repos/datatrak-service` POS endpoint files (`controller/POSController.java`, `validator/OnlinePosValidator.java`, `repository/pos/**`, `api/pos/**`); `repos/mico/**` (consumer reference); the browser contract (`schemas.ts`, UI interfaces); `requireShortTermPass.ts`; the production guard; Chancy's branch history; `repos/orasvc` (unrelated); wallet repos.

## Definition of Done

Role slots: DTS (datatrak-service lane), DTM (datatrak gating lane), BFF, QA, SECURITY, DT (Chancy), PK, DBA (Terry), PLATFORM, PRODUCT. A gate with no named owner does not sign. An unrun check is pending, not passed. Sprint gates V0–V7; the pilot gates touched are **not** part of sprint completion.

| Gate | Owner | Passes when |
|---|---|---|
| V0 — Freeze | DTS+BFF | A2 decision recorded; field table frozen and mirrored in BFF types and DS classes; keys named identically in both constants, ymls and the contract; A4 inventory matches `rg`; baselines, branches and ledger recorded |
| V1 — Flag off is today | DTS+DTM+QA | SQL + bind goldens equal the `main` literals in both repos; off bodies byte-equal the baselines for JSON, XML and no-`Accept`; the POS endpoint files are unchanged (`git diff --stat`); the new endpoint executes no SQL when off (`never()`); `rg` map lists only guarded sites; MICO's two calls are untouched |
| V2 — Flag on exposes the fields | DTS+QA | U2, U5 at controller level; products with `sai_guest_pass='1'` are rows and services never are; `itemType` present; timezone normalised; liability base64 like `prospectTerms`; left-join cases; ORA-00904 fallback tested |
| V3 — Consumer safety | DTS+SECURITY | on-state XML unmarshals into the jar envelope; on-state JSON into the jar/MICO classes; no header literal or credential anywhere in PR text, tests or docs |
| V4 — M&O gating | DTM+DT | every inventory site guarded with the verbatim `main` off-branch; email reordered; both POS hooks skip the email when off and still publish; `ContactsDB.load(ADD_GUEST)` never when off; existing PR tests updated; PR onto Chancy's branch open with the review map (or recorded as the blocked deliverable per CF-19) |
| V5 — BFF matrix | BFF+QA | six cells pinned; `timezone:invalid` and `unknown-type` fail closed; `dtFields` observation wording; fixtures labelled; coverage floors kept (BFF ≥ 84/67/67/84); Sonar green; UI unavailable tests green |
| V6 — Tests actually run | DTS+QA | every new DS test in the include list and in the Gradle report; Sonar new-code gate green on the DS PR; DT suite vs A1 baseline recorded |
| V7 — Runbook and status | orchestrator+PLATFORM(observer) | runbook complete with stop rules; V-P1a rewritten; contract v4.1 and registers updated; smoke §live (D7 done **or** pending with the named precondition); ledger; execution summaries; four verdicts |

**Completion vocabulary (four separate verdicts, never merged):** *(1) Implementation and mock acceptance: DS PR and DT gating PR open and green with off goldens and on tests; BFF matrix pinned on fixtures; a prepared-but-unopened DT PR is named as such, not counted. (2) Standalone dev host: unchanged from Sprint 0004 — carried, not re-verified. (3) Live integration: DataTrak catalog read {done — dev flags on, `STP_CATALOG_SOURCE=datatrak`, fields observed and recorded | pending — PRs unmerged / scripts not run / flag off / secret missing, named}; prospect create/repaint/deactivate {mock only — CF-15}; hosted capture {carried B1}; QR, Add Guest email and access enforcement are DataTrak's and unverified from this build. (4) Pilot: not eligible until V-P0…V-P6 pass; this sprint rewrites V-P1a into the R0–R7 rows.* A failed or pending gate is named in the sentence, never absorbed.

### Pilot gates touched

| Gate | Change |
|---|---|
| V-P1a | Rewritten as R0–R7 rows with owner slots and the stop rules; evidence column names the verification per row |
| V-P1b | Unchanged text; now R5/R6 |
| V-P6 / CR-21 | One sentence for the enablement guide: "a guest pass item is a **product**, flagged, visits 1 (v1 online), contract days 1–100, active, and available online per RQ-15" (G12, G13) |

## Risks & Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | PK or Chancy prefer the fields on `saleItems.spr` rather than a new endpoint | The new endpoint is additive and touches no POS file; the POS-mode variant is recorded in the merge notes and costs the G2 work if chosen |
| R2 | A2 spike fails → jar bump → calendar slip | Spike on day 1; the jar route named with owner (RQ-12); B3/B4 and C/D proceed; verdict 1 for club defaults reads "pending jar release" if it slips |
| R3 | JAXB polymorphism or MICO's XML unmarshal breaks on the on-path | Declared types with `@XmlSeeAlso`; XML, JSON and no-`Accept` goldens; consumer unmarshal into the jar envelope; additive optional elements only |
| R4 | Chancy declines a PR onto his branch or the branch moves | CF-19 asked in A; the review map is the blocked deliverable; rebase cost small |
| R5 | Flag evaluated without a club → VPD-only context matches a rule, or default `false` mistaken for a guarantee | Helpers return `false` locally before evaluation; exception → off; canonical club number; tests for missing/mismatch/exception |
| R6 | A flag flipped on before the scripts run | Service read self-heals (U3); M&O does not — runbook orders scripts first; the POS hook never fails a sale (U11) |
| R7 | Scripts rolled back while a flag is on or cached true | R7 stop rule: BFF off → both DT flags observed off on every instance → drain → export → drop |
| R8 | Off path leaks new fields as `0`/`false` | Nullable wrappers with per-field omission; off-byte goldens decide the annotations |
| R9 | New DS tests never run | B5 own task; V6 own gate; the Gradle report is evidence |
| R10 | `TZL_ABC_CODE` values are not Node-supported ids | Normalisation + alias map; RQ-11 value list; BFF closes the club on unknown (never GMT) |
| R11 | Shared-catalog edits span clubs and the sync writes guest values to disabled destinations | CF-23 confirmed in A3 before C2/C3; per-destination evaluation only if needed |
| R12 | A credential or the header literal leaks into a PR or doc | V3 names it; every quoted controller line redacted; `curl` reads from the environment |
| R13 | The dev live read cannot be observed in the window | Verdict 3 records **pending** with the precondition; nothing claims done without the capability report and a recording |
| R14 | Estimate at the top of the box; DT review availability | Cut order fixed; goldens, include list, inventory and runbook protected; reviewers reserved in A4 |

## Dependencies

- **Code/infra:** the five shallow clones synced; JDK 17; Gradle wrappers; Node ≥ 22; `kubectl` context `k8s-lower-wlr` ns `dev`; helm-configs signing key.
- **Access (never printed):** LD dev/prod rights or a PLATFORM ticket for the two keys; the DT service credential already in MICO's config for the R4 check (run by whoever holds it); PR rights on both DataTrak repos; VPN for dev.
- **Other owners' work (dependency with fallback):** PK's review of both DT PRs; Terry's scripts in dev; Chancy's flag flips, test club and liability text; PLATFORM secret keys; CF-15 and RQ-0 untouched. Each blocks only its named live gate, never the local implementation.
- **Decided before this sprint:** DataTrak service layer for reads (0004 D3); mock-proven bar with live gates (0004 D4); four verdicts; `guest-pass-online` as the BFF's club flag (CF-17).
- **Index leaves consulted:** `themes/feature-flags.md` (LD-per-service, local yml convention); `themes/dt-to-wallet-sync.md`, `datatrak-data-access.md` (why not direct Oracle). No leaf for the DT repos; everything above was read with `rg`/`sed` from `repos/`.

## Open Questions

**Decided (interview 2026-10-07 and merge):** PR onto Chancy's branch (D1); a new club-scoped `guestPassItems.spr` instead of a mode on the POS endpoint, G2 out of the sprint (D2); two keys, club context, default off (D3); SQL and body goldens, no JSP page goldens (D4); `online-join-ui` proof only (D5); DTO = local on-path pair proven by the A2 spike, jar bump as fallback; timezone emitted (normalised) by the service and validated strictly by the BFF; `prospectLiability` base64 like `prospectTerms`; reads self-heal on ORA-00904, writes do not; operational order scripts → code off → M&O flag → service flag → BFF switch → exposure flag; assumptions A1–A3 (sanitiser deferred after a check, G9 optional, cache matrix dropped) reversible at kickoff.

| # | Question | Owner slot | Effect if unanswered |
|---|---|---|---|
| CF-19 | Will Chancy accept a flag-gating PR onto `feat/NOJIRA-guest-pass-email`? | Chancy | Review map ships as a written change request; verdict 1 (M&O half) reads "PR prepared, not opened" |
| CF-20 | Endpoint name `/external/club/guestPassItems.spr` and field names `prospectLiability`, `timezone`, `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType` | Chancy → PK | Proposed names ship; a rename is one class + one type + one URL |
| CF-21 | Liability column type / byte limit (G8) | Terry + Chancy | Wire convention unaffected; on-path form rejects over-limit input before SQL |
| CF-22 | Accept the G9 script rewrite? — **the rewrite is already on the branch** (PK `77f12719`, `ALTER TABLE … ADD (col … DEFAULT …)`, no full-table UPDATE); what stays open is the rerun guard on the ALTERs | Terry | Scripts ship as on the branch; runbook R1 notes the ALTERs are not rerun-safe |
| CF-23 | Are catalog items edited across clubs in practice; does `cgi_online` apply to products and how is it set? | Chancy + PRODUCT | One-club evaluation ships; RQ-15 default (online required) stays |
| CF-24 | Who creates the two LD keys and when; same LD project for both repos? | PLATFORM / Chancy / PK | Default-off code proceeds; no activation |
| CF-25 | Named owners and dates for R1–R6 in dev | Terry / Chancy / PK / PLATFORM | Source stays fixture; verdict 3 pending with the missing prerequisite |
| RQ-10 | Does PK prefer the local pair (if A2 passes) or a jar bump now? | PK | Pair ships; jar bump recorded as RQ-12 |
| RQ-11 | Distinct `TZL_ABC_CODE` values in dev/prod | Chancy / Terry | Normalisation + alias map; unknown closes the club and is logged |
| RQ-12 | Follow-up: add the two fields to `internal-interface` and bump both consumers | PK / middleware owner | Local pair remains |
| RQ-13 | Which dev club gets the flagged test product and the liability text? | Chancy | Answered 2026-11-02: dev test club is `99921` (supplied by Bjorn; not yet confirmed by Chancy). R3/R4 flags not flipped. D7 pending |
| RQ-14 | Should M&O page reads also self-heal on a missing column? | Chancy + PK | Position: no — pages fail loudly; only the POS hook is wrapped |
| RQ-15 | Must a guest-pass product be "available online" (`cgi_online='1'`) to be listed? | PRODUCT + Chancy | Position: yes; if products cannot carry it, the on-path drops the predicate for `cgi_service='0'` rows and uses `SAI_GUEST_PASS='1'` |
| RQ-16 | Measured LD propagation and drain bound for R7 | PLATFORM + DT | No schema drop claimed verified |

**Carried (unchanged owners):** CF-13 moves to "code prepared — pending DT review, merge, scripts and flag" and CF-14 to "not required — the BFF reads `guestPassItems.spr`" at E3; CF-15, CF-17, CF-18, RQ-0…RQ-9 as in contract §10; G3–G7, G10, G11, G13, G14 with the review's owners; the BFF HTML sanitiser as a carried finding (owner at kickoff).

**Deferred (recorded so nobody rebuilds it):** jar bump (RQ-12); the `saleItems.spr?guestPass=true` mode and the member-less POS listing (G2 / CF-14 — the BFF no longer needs `saleItems.spr`; CF-14 closes as "not required" at E3); M&O read self-healing (RQ-14); production flag flips and dates (V-P1); an H2/HSQLDB DAO harness in datatrak (a DT-team decision); CLOB migration (CF-21); cache-transition test matrix; JSP page goldens.
