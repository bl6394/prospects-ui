# Sprint 0005 — DTS lane execution summary (`datatrak-service`, branch `DT-21555-guest-pass-service-fields`, PR #591)

Executor: Claude Fable 5.1 (DTS lane), 2026-10-07. Base `origin/main` `d280934`; A2 commit `f5aa9ea` was already on the branch. Every statement below is about code that was **not compiled by Gradle locally** (BL-1, Artifactory unreachable); "observed" means a standalone `javac` + TestNG run against cached jars (§Standalone run), "unobserved" means the PR's CI is the first compile and run. No credential and no header literal appear in any commit, test, golden, doc or PR text (`git diff --cached | grep -c "Basic "` was 0 for every commit except B2/B3, where the single occurrence is the sibling `headers = {…}` line copied byte-for-byte into the new endpoint — verified equal in a script, never printed).

## Commits (after A2 `f5aa9ea`)

| Commit | Task | What landed |
|---|---|---|
| `29bf512` | B1 | `LDFeatureFlagConstants.GUEST_PASS_FIELDS = "datatrak-service-DT-21555-guest-pass-fields"` (javadoc in the `SKIP_MICRO_AMOUNT_LINE_TAX_ADJUSTMENT_IGS_20342` style); NEW `launchdarkly/helper/GuestPassFeature.isOn(club)` / `isOn(club, vpd)`; `: false` in `src/resources/launchdarkly-local.yml` and `test/resources/featureflag-local.yml`; `LDFeatureFlagConstantsTest.guestPassFields_matchesLaunchDarklyKey`; NEW `GuestPassFeatureTest` (9 cases) |
| `24006c4` | B2 + B3 | **One commit for two tasks** (deviation, see §Deviations): `DtManagedClubSql` gains `GET_CLUB_DEFAULT_EXTERNAL_GUEST_PASS`, `GET_GUEST_PASS_ITEMS`, `GET_GUEST_PASS_ITEM` (`GET_CLUB_DEFAULT_EXTERNAL` untouched); `DtManagedClubDao{,Impl}.getClubDefaultExternalGuestPass(club)` and `.getGuestPassItems(club, saleItemId)`; NEW `repository/club/mapper/GuestPassClubDefaultExternalRowMapper` and `GuestPassItemRowMapper`; NEW `club/external/api/GuestPassItem` and `GuestPassItemResponse`; `ClubExternalService{,Impl}.getClubDefaultExternal(club, vpd)` (old signature delegates with `0`) and `.getGuestPassItems(club, vpd, saleItemId)`; `ClubExternalController.getClubDefaultExternal` passes the resolved VPD; NEW `ClubExternalController.getGuestPassItems` at `/external/club/guestPassItems` |
| `c793570` | B4 | NEW tests `DtManagedClubDaoImplGuestPassSqlTest`, `DtManagedClubDaoImplGuestPassItemsSqlTest`, `ClubExternalServiceImplGuestPassTest`, `ClubExternalControllerGuestPassItemsTest`, `GuestPassClubDefaultExternalRowMapperTest`, `GuestPassItemRowMapperTest`, `GuestPassItemSerializationTest`, helper `GuestPassGoldens`; the A2 spike test extended with seven golden cases (name kept); eight goldens under `test/resources/guest-pass/` |
| `1ac07f4` | B5 | Eight new test classes added to the `include` list in `dtWar/build.gradle` (beside the spike test); README test note corrected (the include list governs what runs; the task is not disabled) |
| — | B6 | Draft PR **#591** `https://github.com/abcfinancial/datatrak-service/pull/591`, base `main`, head `1ac07f4` at opening; body in `SPRINT-0005-PR-DESCRIPTIONS-DTS.md`; reviewers not requested |
| `b36f727` | B4 fix | After CI run 1: `ClubExternalControllerGuestPassItemsTest` builds the controller per method (see §CI) |
| `4fae6a9` | B6 Sonar | After CI run 2: the 12 Sonar new-code findings cleared behaviour-unchanged (text blocks, param-name constants, cause-chain walk, `@XmlElement`, prose comments — see §CI) |
| `2a5d599` | B6 Sonar | After CI run 3: the last finding (S6201, pattern-matching `instanceof`); PR head is now `2a5d599` |

`git diff --stat origin/main..HEAD` at `2a5d599`: 37 files, +2307 / −19; **no file under `controller/POSController.java`, `validator/`, `repository/pos/`, `api/pos/`** (U4; the POS SQL bundle is only *read* by `DtManagedClubDaoImplGuestPassItemsSqlTest` to prove the taxed CASE is identical).

## Per task

### B1 — flag plumbing (U12, U13)

- `GuestPassFeature.isOn(club, vpd)`: `StringSupport.isEmptyString(club) || !StringSupport.isValidClubNumber(club)` → `false` + debug, **before** any bean lookup (probed standalone against abc-common 6.14.0: `09003` valid; `9003`, `090030`, `0900a`, `""`, `"  "`, `null` invalid); `StaticSpringApplicationContext.getSpringObject(FeatureService.class)` null → `false`; `computeBooleanFeature(GUEST_PASS_FIELDS, vpd, club, false)`; `catch (Exception)` → `false` + `warn` (slf4j, `FeatureFlagHelper` style). `getSpringObject` throws `IllegalStateException` when the context is not initialised — covered by the catch and by a test.
- Observed standalone: `GuestPassFeatureTest` 9 / 9 (null / blank / non-canonical → `false` with `verifyNoInteractions` on the service **and** on the static context; bean null → `false`; context not initialised → `false`; evaluation throws → `false`; targeted → `true` with the exact `(key, 42, "09003", false)` call; club-only overload → `(key, 0, …)`; untargeted → `false`). `LDFeatureFlagConstantsTest` 5 / 5.

### B2 — club defaults both ways (U1–U3)

- **Off-path SQL literal** (unchanged `GET_CLUB_DEFAULT_EXTERNAL`, pinned by `DtManagedClubDaoImplGuestPassSqlTest.MAIN_GET_CLUB_DEFAULT_EXTERNAL` and by `bundleConstant_getClubDefaultExternal_isUnchangedFromMain`):
  ```
  SELECT
      spl.spl_name "name",
      spl.spl_abc_id "clubNumber",
      CASE WHEN spl.spl_phone IS NOT NULL THEN spl.spl_phone  || ' Ext. ' || spl.spl_phone_ext ELSE spl.spl_phone END "phone",
      spl.spl_url "website",
      spl.spl_facebook "facebook",
      spl.spl_twitter "twitter",
      spl.ctl_id_billing "billingCountry",
      spl.spl_online_class "classes",
      spl.spl_online_prospect "prospects",
      spl.SPL_PROSPECT_TERMS "prospectTerms",
      spl.spl_address_1 "address.address1",
      spl.spl_address_2 "address.address2",
      spl.spl_city "address.city",
      spl.stl_id "address.state", 
      spl.spl_zip "address.zip",
      spl.ctl_id "address.country"
  From serviceProviderLocations spl
  WHERE 
      spl.spl_active = :active 
      and spl.spl_physical_location = :active
      and spl.spl_abc_id = :clubNumber
  ```
  (the Java literal has `"\n"` line ends and the trailing spaces shown after `"address.state",`, `WHERE` and `:active`; the test string is the same concatenation). **Binds:** `MapSqlParameterSource` with parameter names exactly `[clubNumber, active]`, `clubNumber = <club>` `Types.CHAR`, `active = 1` `Types.CHAR`; mapper `ClubDefaultExternalRowMapper`.
- **On-path SQL** `GET_CLUB_DEFAULT_EXTERNAL_GUEST_PASS` = the literal above with `,\n    splex.SPLEX_PROSPECT_LIABILITY "prospectLiability",\n    tzl.tzl_abc_code "timezone"` appended to the select list and `LEFT JOIN spl_extensions splex ON splex.spl_id = spl.spl_id AND splex.vpd_id = spl.vpd_id` / `LEFT JOIN timezonelookup tzl ON tzl.tzl_id = spl.tzl_id` between `From` and `WHERE`; same binds. The test strips exactly those additions and asserts equality with the main literal (so the WHERE is identical by construction). `spl_extensions` is already joined by the `CLUB_DATA_*` statements on `main` (same key pair), so the table and the join shape are established.
- **Mapper:** `GuestPassClubDefaultExternalRowMapper` delegates the shared columns to `ClubDefaultExternalRowMapper` and copies the 13 fields; `prospectLiability` null → `""` → base64 `""` (exactly the `prospectTerms` code); timezone: `null` → `null`; `ZoneId.of` ok → raw; `ZoneId.SHORT_IDS` → mapped; else raw + `warn("guest-pass.timezone-unknown …")`. Probed on JDK 17: `ZoneId.of("EST")` **throws** (so `EST` reaches the alias table → `-05:00`; `CST` → `America/Chicago`; `PST` → `America/Los_Angeles`; `US/Central` accepted as is). Blank `""` is not special-cased (it is "unknown" → raw + warn) — RQ-11 (which values `TZL_ABC_CODE` really holds) stays with Chancy/Terry.
- **Service:** `boolean guestPassFieldsOn = GuestPassFeature.isOn(clubNumber, vpd)` once; on → `GuestPassClubDefaultExternalResponse` + on DAO; `catch (BadSqlGrammarException)` → `isColumnsAbsent` (`getSQLException().getErrorCode() == 904` or any cause message containing `ORA-00904`, cycle-safe) → `warnColumnsAbsentOnce` (instance `ConcurrentHashMap.newKeySet()`, log key `guest-pass.columns-absent`) → fall through to the off path; otherwise rethrow. Off path = the exact three lines from `main` (DAO call, branding, `enroll_page_hide`) moved into `fillClubDefaultExternal`, used by both paths. The on statement is retried on each request (only the warning is deduplicated) so the read heals when the scripts land without a restart. **DTO decision:** the A2 pair (local subclasses, no jar bump) — unchanged from `f5aa9ea`.
- **Controller:** `getClubDefaultExternal` now calls `getClubDefaultExternal(clubNumber, vpd)`; everything else (vpd 0 → empty club, catch → empty club) byte-identical.
- Observed standalone: `GuestPassClubDefaultExternalRowMapperTest` 8 / 8; the spike test 14 / 14 (7 original + 7 goldens). **Unobserved (CI):** `DtManagedClubDaoImplGuestPassSqlTest` (4), `ClubExternalServiceImplGuestPassTest` club-defaults cases (9) — they need `DtManagedClubDaoImpl` / `ClubExternalServiceImpl` and their app dependencies.

### B3 — guestPassItems endpoint (U4–U7)

- `ClubExternalController.getGuestPassItems(@RequestParam clubNumber, @RequestParam(required=false) saleItemId)` at `/external/club/guestPassItems`, `produces` and `headers` lines copied from `getClubDefaultExternal` (verified byte-identical by script), same `setVpdFromClubNumber` prelude; vpd 0 / service throws → `{club, saleItems: null, messages: error "Not available"}`.
- Service: `!GuestPassFeature.isOn(club, vpd)` → unavailable envelope, **no DAO call**; on → `dtManagedClubDao.getGuestPassItems(club, saleItemId)` → `saleItems` list (possibly empty) + `getSuccessMessage()`; ORA-00904 → warn once per club → unavailable; other `BadSqlGrammarException` / exceptions propagate (the controller turns them into the unavailable envelope).
- **Club resolution choice:** the statement joins `serviceproviderlocations spl ON spl.spl_id = sai.spl_id` and binds `spl.spl_abc_id = :clubNumber` (`Types.CHAR`) — one statement, no second query, no new DAO dependency. The contract's `sai.spl_id = :splId` form would have needed `clubDao.getClubIdForClubNumber` (a second query per request). Recorded as the documented choice.
- SQL `GET_GUEST_PASS_ITEMS`: `SELECT sai.sai_id "saleItemId", cgi.cgi_id "catalogItemId", cgi.cgi_name "catalogItemName", cgi.cgi_sale_price "catalogPrice", sai.sai_sale_price "salePrice", <taxed CASE verbatim from GET_ONLINE_SALE_ITEMS> "taxed", sai.sai_guest_pass "guestPassOnline", sai.sai_guest_pass_visits "guestPassVisits", sai.sai_guest_pass_contract_days "guestPassContractDays", cgi.cgi_service "itemType" FROM saleitems sai JOIN catalogitems cgi ON cgi.cgi_id = sai.cgi_id JOIN serviceproviderlocations spl ON spl.spl_id = sai.spl_id WHERE spl.spl_abc_id = :clubNumber AND sai.sai_active = '1' AND cgi.cgi_active = '1' AND sai.sai_guest_pass = '1' AND cgi.cgi_service = '0' AND cgi.cgi_online = '1' ORDER BY cgi.cgi_name`; `GET_GUEST_PASS_ITEM` = the same with `AND sai.sai_id = :saleItemId` before `ORDER BY` (a test asserts the single-item constant equals the list constant with that one line inserted). Blank `saleItemId` → list statement.
- DTOs: `GuestPassItem` (10 public fields, jakarta `@XmlElement`, `itemType` PRODUCT / SERVICE / BILLING from `cgi_service` 0/1/2, anything else → `null` i.e. omitted — the BFF skips it as `unknown-type`), `GuestPassItemResponse` (`@XmlRootElement(name="guestPassItemResponse")`, `club`, `SaleItemList saleItems` with `List<GuestPassItem> saleItem`, `ResponseMessages messages`) — the `SaleItemResponse` shape.
- Observed standalone: `GuestPassItemRowMapperTest` 5 / 5; `GuestPassItemSerializationTest` 9 / 9; DTOs, mappers and the SQL bundle compile. **Unobserved (CI):** `DtManagedClubDaoImplGuestPassItemsSqlTest` (6), `ClubExternalServiceImplGuestPassTest` items cases (7), `ClubExternalControllerGuestPassItemsTest` (6).

### B4 — goldens

- Eight goldens under `dtWar/test/resources/guest-pass/`, **written from the fixed inputs** of the tests through the same converters in the standalone run (BL-4: no `main` body could be captured — no DB, no live service): `club-defaults-{off,on}.{json,xml}`, `guest-pass-items-{success,unavailable}.{json,xml}`. "No `Accept`" is asserted as the XML golden (the app's `defaultContentType(APPLICATION_XML, APPLICATION_JSON)`). The loader tolerates one trailing newline in the file and nothing else.
- Facts the goldens show: off bodies carry neither new element (XML has no `xsi:type`); on JSON = off JSON + `"prospectLiability":"PHA+TGlhYmlsaXR5PC9wPg=="` + `"timezone":"America/Chicago"` (asserted by string removal); on XML keeps `<clubDefaultExternalResponse>` and carries `<club xmlns:xsi=… xsi:type="guestPassClubDefaultExternal">`; JSON emits `null` for unset jar fields (today's behaviour — `facebook`, `address2`, `branding.*`) while XML omits them; the items success JSON is `{"club":"09003","saleItems":{"saleItem":[…]},"messages":{"status":"success","message":[]}}`, the unavailable JSON `{"club":"09003","saleItems":null,"messages":{"status":"error","message":[{"text":"Not available"}]}}`.
- Consumer safety (U8): on XML unmarshals into the jar envelope (spike, kept); on JSON into the jar envelope with `FAIL_ON_UNKNOWN_PROPERTIES=false` (spike, kept); items JSON reads into the POS `com.abcfs.api.pos.SaleItemResponse` shape with a tolerant mapper (new; a read-only import of the POS DTO) and back into the local type.

### B5 — include list and README

`dtWar/build.gradle` `tasks.named('test')` include list: nine `DT-21555` entries (spike + eight new). README "Test" bullet and the `test/**` line rewritten: the task is not disabled; the include list governs what runs; CI runs `check jacocoTestReport sonar`.

### B6 — PR

Draft PR #591 opened with `gh pr create --draft --base main --head DT-21555-guest-pass-service-fields`; head `1ac07f4` at opening, `b36f727` after the run-1 fix, `4fae6a9` and `2a5d599` after the Sonar passes; the first attempt without `--head` was refused by `gh` ("you must first push the current branch…", despite the push having succeeded — tracking was set) and the retry with `--head` succeeded. Body: `SPRINT-0005-PR-DESCRIPTIONS-DTS.md`. **CI result: see §CI below.**

## Standalone run (what was observed)

`/tmp/dts-standalone`, JDK 17.0.20.1, `javac` + `org.testng.TestNG` on a classpath from the Gradle cache (**proxies**, the build's versions in brackets): `internal-interface-4.1.0` [4.2.0], `CommonWsObjects-1.0.2-SNAPSHOT` [1.2.0 — its `ResponseMessages` carries **javax** JAXB annotations, so JAXB 4 used default public-field access for `messages` in the goldens; the element names are the same (`status`, `message`, `text`) but this is the one proxy that could change the XML goldens in CI], `abc-common-6.14.0` [6.8.1], `spring-web/beans-7.0.8` + `spring-jdbc/tx/context/core-6.2.10` [Boot 3.0.1], `jackson-2.14.1` [same], `jaxb-runtime-4.0.9` [4.0.0], `testng-7.9.0` [6.9.5], `mockito-core-5.17.0` [mockito-inline 4.5.1], `launchdarkly-java-server-sdk-7.1.0`. The three Jackson modules (`MrBean`, `Joda`, `Guava`) are not in the cache, so the standalone copies of `GuestPassGoldens` and the spike test had the `registerModules` line stripped (none of the serialised types uses them); logback was left off the classpath (a proxy jar ships a `logback.xml` needing `logback-contrib`).

Compiled standalone: `LDFeatureFlagConstants`, `FeatureService`, `StaticSpringApplicationContext`, `GuestPassFeature`, the four `club/external/api` DTOs, the three `repository/club/mapper` classes, `ServiceSupport`, `DtManagedClubSql`, `SaleItem*` (read-only). Ran standalone — **50 / 50**: `LDFeatureFlagConstantsTest` 5, `GuestPassFeatureTest` 9, `GuestPassClubDefaultExternalRowMapperTest` 8, `GuestPassItemRowMapperTest` 5, `GuestPassItemSerializationTest` 9, `GuestPassClubDefaultSerializationSpikeTest` 14.

Not compilable standalone (app dependencies: `ClubDao`, `MicoClubDao`, `BillingSystemService`, `TriPosTerminalDao`, `CountryUtil`, lombok): `DtManagedClubDaoImpl`, `ClubExternalServiceImpl`, `ClubExternalController` and their four tests (`DtManagedClubDaoImplGuestPassSqlTest`, `DtManagedClubDaoImplGuestPassItemsSqlTest`, `ClubExternalServiceImplGuestPassTest`, `ClubExternalControllerGuestPassItemsTest`) — reviewed by hand against the Mockito 4 / TestNG 6.9.5 APIs the included tests already use (`mockStatic`, `MockedStatic.verify`, `verifyNoInteractions`, `expectThrows` — the last is used by the included `TriposChargePaymentProcessorServiceTest`).

## CI

**Run 1** — head `1ac07f4`, workflow `CI: Pull Request` run `37676324912` (`abcfinancial2/github-workflows java-ci.yml`: `build check jacocoTestReport sonar`), 2026-10-07 19:41–19:44 UTC. `compileJava` and `compileTestJava` **passed** (the first compile of every file in this PR). `:dtWar:test`: **607 tests completed, 5 failed** — all five in `ClubExternalControllerGuestPassItemsTest` (`getGuestPassItems_unresolvableVpd_answersNotAvailable_doesNotCallService`, `getGuestPassItems_serviceThrows_answersNotAvailable_never500`, `getGuestPassItems_knownClub_returnsTheServiceResponse`, `getGuestPassItems_saleItemId_isPassedThrough` (`WantedButNotInvoked`), `getClubDefaultExternal_unresolvableVpd_answersEmptyClubLikeToday`); the sixth (first in TestNG's alphabetical order) passed. Every other new class passed in CI: spike 14 / 14, `GuestPassItemSerializationTest` 9 / 9 (the goldens, including the `ResponseMessages` XML, matched under the real `CommonWsObjects` 1.2.0 — BL-DTS-1 did not materialise), `DtManagedClubDaoImplGuestPassSqlTest` 4 / 4, `DtManagedClubDaoImplGuestPassItemsSqlTest` 6 / 6, `ClubExternalServiceImplGuestPassTest` 16 / 16, `GuestPassFeatureTest` 9 / 9, both mapper tests 8 / 8 and 5 / 5, `LDFeatureFlagConstantsTest` 5 / 5 — **72 / 77 new tests green on run 1; no pre-existing test failed** (602 / 602 of the rest). `CI / Scan with Endor Labs` passed. Evidence: job log via `gh api …/actions/jobs/112980656037/logs` and the `test-results` artifact (HTML report with stack traces).

**Cause (from the stack traces):** TestNG reuses one test instance; `MockitoAnnotations.openMocks(this)` in `@BeforeMethod` created fresh `@Mock` objects for every method, but the `@InjectMocks` controller built by the first method kept the first method's mocks (the controller's fields are `final`; Mockito does not re-run constructor injection on a non-null field). From the second method onward the controller saw `setVpdFromClubNumber → 42` and the first method's service stub / an unstubbed service, hence `response.club == null`, `null` responses and `WantedButNotInvoked`. The sibling `ClubExternalControllerTest` (the style the brief named) has the same latent pattern and is **not** in the include list, so it never ran under Gradle — recorded as a finding for the repo owners, not changed here.

**Fix** — `b36f727` `DT-21555 B4 fix: build the controller per test method instead of @InjectMocks (stale mocks under TestNG)`: `controller = new ClubExternalController( … five mocks … )` in `setUp` after `openMocks`; `@InjectMocks` and its import removed; nothing else changed.

**Run 2** — head `b36f727`, run `37677260485`: `CI / Build` **pass** (`BUILD SUCCESSFUL`, `:dtWar:test` with no failure — all 607 tests green, the 77 new ones included; `jacocoTestReport` and `sonarqube` ran), `CI / Scan with Endor Labs` **pass**, **`SonarQube Code Analysis` fail** — quality gate condition "new issues" with **12 new issues** (read from the check-run annotations, no server token): S6126 "replace this String concatenation with a text block" ×6 (the three new SQL constants, the two test literals, and — because the entry's closing line had changed — the untouched `GET_CLUB_DEFAULT_EXTERNAL` statement at line 462), S1192 duplicated literals `"clubNumber"` (11×) and `"active"` (4×) in `DtManagedClubDaoImpl` (the two "failure"-level findings), S2589 gratuitous boolean in `isColumnsAbsent`, S1104 public field `SaleItemList.saleItem`, S2293 diamond operator, S125 commented-out code (a prose comment ending in a semicolon).

**Sonar pass** — `4fae6a9` `DT-21555 B6 Sonar: clear the 12 new-code findings on PR #591 without changing behaviour`: the three new SQL constants and the two test literals are **text blocks** (`\s` keeps the main statement's three trailing spaces; the closing delimiter on the last content line keeps the no-trailing-newline form); the three new entries now sit **before** the untouched `GET_CLUB_DEFAULT_EXTERNAL` entry, whose lines are therefore unchanged against `main` (`git diff origin/main -- DtManagedClubSql.java` shows additions only); `PARAM_CLUB_NUMBER` / `PARAM_ACTIVE` constants replace the `addValue` parameter-name literals across `DtManagedClubDaoImpl` (10 + 4 occurrences, the column-label `getString("clubNumber")` left alone); `isColumnsAbsent` walks the cause chain once (`SQLException` code 904 or the `ORA-00904` text); `@XmlElement` on `SaleItemList.saleItem` (FIELD access, same element name) and `new ArrayList<>()`; the SQL comments rewritten as prose. **Proof the strings did not change:** a standalone harness compared the new bundle values and the test's text-block literal with the concatenated strings captured before the edit — `GET_CLUB_DEFAULT_EXTERNAL` unchanged, the test literal equals it, the on statement equals its previous value and equals `main` once its additions are stripped, both items statements equal their previous values (6 / 6 true); standalone serialisation + mapper tests 28 / 28 after the DTO change (goldens untouched). The file-convention trade-off (every other constant in `DtManagedClubSql` is concatenated) is recorded in §Deviations.

**Run 3** — head `4fae6a9`: `CI / Build` **pass** (build, all tests, JaCoCo), Endor **pass**, Sonar gate **fail on 1 new issue** — S6201 "replace this instanceof check and cast with `instanceof SQLException sqlException`" on the cause-chain walk. Fix `2a5d599` `DT-21555 B6 Sonar: pattern-matching instanceof in isColumnsAbsent (last new-code finding)` (one line; `sourceCompatibility` is 17).

**Run 4** — head `2a5d599`, run `37679053945`: `CI / Build` **pass** (3m38s; build, every included test, JaCoCo), `CI / Scan with Endor Labs` **pass**, `SonarQube Code Analysis` **pass** (quality gate green, 0 new issues). **PR #591 is green on all three checks** at head `2a5d599`; still a draft; no reviewer requested; not merged.


## Gates (DTS share)

| Gate | Verdict | Evidence |
|---|---|---|
| V1 — flag off is today | **passed** — CI run 4 green on every pinned test (DTS share; the DTM share and MICO call check are the orchestrator's) | off SQL literal + binds pinned (`DtManagedClubDaoImplGuestPassSqlTest`); off bodies pinned for JSON / XML / no-Accept (spike goldens); POS files untouched (`git diff --stat`); items off → `verifyNoInteractions(dtManagedClubDao)`; service flag off → on DAO `never()`. Caveat: the off body goldens are from fixed inputs through the real converters, not a `main` capture (BL-4) |
| V2 — flag on exposes the fields | **passed at controller/service level** — every case observed in CI run 4 (the dev read with the flag on stays with E2/D7) | U2 (`clubDefaults_flagOn_runsTheGuestPassDaoAndAnswersTheSubclassPair`), U5 (`items_flagOn_answersTheMappedRowsWithSuccess`, SQL predicates `cgi_service = '0'`, `sai_guest_pass = '1'`, `cgi_online = '1'`), `itemType` PRODUCT, timezone normalised (8 mapper cases), liability base64 like `prospectTerms`, left-join nulls, ORA-00904 fallback (code 904 and message-only, once-per-club across two calls, other codes propagate) |
| V3 — consumer safety | **passed (observed)** for the converter half; the "no header literal / credential" half verified by `grep -c "Basic "` on every staged diff, the PR body and these docs | spike `onPath_xml_unmarshalsIntoTheJarEnvelope_likeMico`, `onPath_json_deserialisesIntoTheJarEnvelope_likeMico`; `GuestPassItemSerializationTest.success_json_readsIntoThePosSaleItemResponseShapeWithATolerantMapper` |
| V6 — tests actually run | **passed** — the Gradle report of run 4 lists all nine DT-21555 classes (77 tests) and the Sonar new-code gate is green | nine include-list entries; Gradle report and Sonar new-code gate per §CI |

## Deviations from the plan

1. **B2 and B3 share one commit** (`24006c4`): the SQL bundle, DAO interface/impl, service interface/impl and controller carry both tasks; splitting by hunk without a compile was judged riskier than one commit. B1, B4, B5 are separate.
2. **Club resolution in the items statement** through `serviceproviderlocations.spl_abc_id` instead of the contract's `sai.spl_id = :splId` (allowed by the brief; one statement instead of two).
3. **Warn-once set is per service instance**, not static — the service is a singleton, so it is per JVM in practice, and tests observe it through a package-private accessor instead of a log appender.
4. **The on statement is retried on every request** after an ORA-00904 (only the warning is deduplicated) — self-healing without restart; the plan did not say either way.
5. `expectThrows` (TestNG) and `MockedStatic.verify` are used in the unobserved tests; both are already used by tests in the include list.
6. **Text blocks for the new SQL constants and the two test literals** (Sonar S6126) although every other constant in `DtManagedClubSql` is concatenated — the gate counts every new issue, and the byte-equality of the strings is proven (§CI, Sonar pass). The three new entries sit before `GET_CLUB_DEFAULT_EXTERNAL` so that entry stays unchanged code.
7. **Parameter-name constants replace `addValue("clubNumber"|"active", …)` across `DtManagedClubDaoImpl`** (Sonar S1192), touching ten pre-existing lines in a file the PR already changes; values and types unchanged, pinned by the bind goldens.

## Open items for the orchestrator

- RQ-11: `TZL_ABC_CODE` value forms — the mapper maps legacy three-letter ids through `ZoneId.SHORT_IDS` (`EST` → `-05:00` is an offset, not a region; the BFF's strict check decides whether an offset is acceptable).
- CF-20: field names are the frozen §8a(e) names; the PR's field table is the same table.
- Ledger row and PR link are the orchestrator's (this lane did not edit `SPRINT-0005.md`, the contract or `ledger.yaml`).
