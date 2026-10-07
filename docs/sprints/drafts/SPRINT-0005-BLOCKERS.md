# Sprint 0005 — blockers, Phase A record, gating inventory

Executor: Claude Fable 5.1 (orchestrator), 2026-10-07. Lane files: `SPRINT-0005-BLOCKERS-{DTS,DTM,BFF}.md`. Nothing is merged in any DataTrak repo; no script is run; no flag is flipped; no remote host is probed; no credential is printed.

## A1 — repos, branches, heads (2026-10-07)

| Repo | Base | Head at A1 | Branch |
|---|---|---|---|
| online-join-bff | `origin/main` (PR #107 merged 2026-09-18 as `18ab2d4`; dependabot since) | `5e370a0` | `prospect-wallet/sprint-0005` (off main) |
| online-join-ui | `origin/main` (PR #532 merged 2026-09-18) | `3967c43` | none (D5/D6 read-only; a branch is cut only if D5 finds new exposure) |
| datatrak-service | `origin/main` | `d280934` | `DT-21555-guest-pass-service-fields` (A2 commit `f5aa9ea` on top) |
| datatrak | `origin/feat/NOJIRA-guest-pass-email` (Chancy's PR #6643, base `main` `0917d08`) | **`77f1271`** — moved today, see §PK delta | `DT-21555-guest-pass-flag-gating` (off Chancy's head; never rewritten, never pushed to) |
| helm-configs | `origin/master` `efc689c8` (PR #3090 merged 2026-09-18) | `9734da28` local branch, untouched | none — D7 is gated (no helm PR this run) |
| mico | `main` `5dad4d66` | read-only consumer reference | — |

Toolchain: JDK 17 at `/Users/bjornloftis/Library/Java/JavaVirtualMachines/jdk-17.0.20.1+1/Contents/Home` (the brief's `/Library/Java/JavaVirtualMachines/jdk-17.0.1.jdk` does not exist on this machine); Node v26.10.0; `gh` authenticated; Gradle wrappers 7.5.1 (datatrak-service) / 7.4.1 (datatrak).

### Day-one Gradle baselines — **blocked: Artifactory unreachable (no VPN)**

`./gradlew :dtWar:test --continue --no-daemon` on JDK 17 in both repos:

- **datatrak-service** (`d280934`): `BUILD FAILED` at `:dtWar:compileJava` — "Could not resolve all files for configuration ':dtWar:compileClasspath'": `artifactory.abc30ops.com` times out / terminates the TLS handshake for every ABC artifact (`internal-interface:4.2.0`, `abc-starter-launchdarkly-lib:1.2.0`, `CommonWsObjects:1.2.0`, `abc-quickbooks`, `jfree-utility`, `hashing-service-*`, `schedule-funding`, `billing-system-interface-*`, `document-service-interfaces`, `abc-starter-springboot-actuator`, plus the vendored `icepdf-core`, `yuicompressor`, `SigPlus2_52`, `db2jcc`, `comm`, `digitalpersona`, `nsoftware`, `not-yet-commons-ssl`). Nothing compiled; **no test ran; no pre-existing failure can be named**. The gradle cache holds `internal-interface:4.1.0` only.
- **datatrak** (`77f1271`): `BUILD FAILED` at plugin resolution — `org.springframework.boot:2.7.13` is only served from the Artifactory `gradle-plugins-mirror`. Nothing compiled; no test ran.
- **CI stands in for the baseline.** Both repos run `abcfinancial2/github-workflows java-ci.yml` on pull requests (`check jacocoTestReport sonar` for datatrak-service, `check sonarqube` for datatrak; test results published by `EnricoMi/publish-unit-test-result-action`). PR #6643's head `77f1271` shows `CI / Build` **pass** (2026-10-07), which is the datatrak baseline proxy. The datatrak-service baseline proxy is the CI run on the draft PR opened at B6.
- **Effect on the lanes:** DTS and DTM write Java and tests without a local compile; the draft PRs' CI is the first compile and test run. Both lanes must keep their changes small, mirror existing precedents exactly (imports, Mockito 4 `mockito-inline` / TestNG 6.9.5 in datatrak-service; TestNG 7.8 / Mockito 4.11 in datatrak) and record "unobserved locally — CI pending" for V6. The A2 spike was compiled and run standalone with `javac` + TestNG against cached jars (see §A2) so the gate decision rests on an observed run, not on reasoning.
- **Precondition to clear:** VPN to `artifactory.abc30ops.com`, then re-run both baselines and record failures by name (E2).

### PK delta on Chancy's branch (found at A1; changes Phase C)

Between the planning snapshot (`50a00ffb`, merge of main) and today's head, **Paul Knuth pushed four commits to `feat/NOJIRA-guest-pass-email` on 2026-10-07** (co-authored with Cursor):

| Commit | Title | What it does |
|---|---|---|
| `0d0f2d06` | feat: gate guest day pass behind a club flag | NEW `com/abcfinancial/datatrak/common/launchdarkly/GuestDayPassFeatureFlag.isOn(clubNumber)` (blank club → `false` locally; `FeatureService` missing or throwing → `false` + warn; `FEATURE_FLAG_KIND_CLUB`); constant `LDFeatureFlagConstants.MO_GUEST_DAY_PASS = "MO_guest_day_pass_DT-21555"`; `CatalogItemsDB` select / insert (60 vs 63 placeholders) / update / `addSaleItem` / `updateSaleItemRecord` gated (session club for the page, `ClubDB.getClubNumber(connection, clubId)` per destination club for the sync); `CatalogItemDaoImpl.updateSaleItemRecord` / `insertSaleItemRecord` gated by the sale item's / destination club's number; `EditClubOnlineDaoImpl.load` uses a legacy SELECT (`SPL_PROSPECT_TERMS, SPL_ABC_ID`) and reads the liability only when on, `saveProspectContent` returns before the liability UPDATE when off; `EditClubOnlineProspect.guestDayPassEnabled`, `EditCatalogItemsState.guestDayPassEnabled` + JSP `<dt:ifEqual>` around the fields and the JS init; `EditCatalogItemsSecondaryPage` forces the three values to `"0"` when off and skips validation; `ProspectServiceTransactionsImpl.sendGuestPassSaleEmail` **reordered** (club → flag → guest SQL); both `PointOfSaleDB.handlePosTransactionCompleted` skip the email when off and still publish; `GuestDayPassFeatureFlagTest` + the three existing email tests updated for off/on |
| `356613de` | fix: decide guest-pass email from the cart | `sendGuestPassSaleEmail(PointOfSaleState)` + `sendGuestPassEmailForSaleItems` (flag → `anySaleItemIsGuestPass(saleItemIds)` → member) for the sales3 path; `PointOfSaleDao.anySaleItemIsGuestPass` |
| `5afb5289` | fix: send guest-pass email after the sale commits | `sendGuestPassSaleEmailAfterCommit` registers a `TransactionSynchronization.afterCommit` in both `PointOfSaleDB` copies; both `PointOfSaleDBGuestEmailTest` extended |
| `77f12719` | chore: match guest-pass DDL to the applied script | **G9 done by PK:** `ALTER TABLE … ADD (col … DEFAULT …)` without the full-table `UPDATE`; `SPL_EXTENSIONS` script in the same form |

Consequences recorded for the sprint document (L0/L1 updated at E4):
- **Decision D3's second key is superseded by a code fact:** the M&O flag is **`MO_guest_day_pass_DT-21555`** (constant `MO_GUEST_DAY_PASS`), PK's name in the repo's `MO_<slug>_<TICKET>` convention — not the planned `datatrak-DT-21555-guest-pass`. The datatrak-service key stays `datatrak-service-DT-21555-guest-pass-fields`. Two keys, club context, default off — unchanged.
- **Phase C becomes an audit and gap-fill pass**, not a gating pass: C1–C6 are implemented by PK; the DTM lane verifies every inventory row against the code, fills the gaps listed in §A4 (SQL + bind goldens for `CatalogItemsDB`, `CatalogItemDaoImpl`, `EditClubOnlineDaoImpl`; the local yml key; `LDFeatureFlagConstantsTest` row if the repo has one; the duplicate import in `ProspectServiceTransactionsImpl`; `never()` on the `ADD_GUEST` send when off), and opens the PR onto Chancy's branch with the review map. C8 (G9) is **done upstream** — no separate commit needed.
- CF-19 (will Chancy accept a PR onto his branch) stays asked; PK already works on the branch directly, which is a signal, not an answer.

## A2 — DTO and converter spike (gate): **PASS → local pair, no jar bump**

Run 2026-10-07 standalone (`/tmp/a2-spike`, `javac` + `org.testng.TestNG`) because Gradle cannot resolve; classpath from the Gradle cache: `internal-interface-4.1.0.jar` (**proxy** for the 4.2.0 the build declares — `ClubDefaultExternal` / `ClubDefaultExternalResponse` carry `jakarta.xml.bind` `@XmlElement` / `@XmlRootElement` and the same 13 public fields the DS source uses), `jakarta.xml.bind-api-4.0.1`, `jaxb-runtime-4.0.9` (build: 4.0.0), `jackson-*-2.14.1` (same as the build), `spring-web-7.0.8` / `spring-core-6.0.3` / `spring-beans-7.0.8` (build: Spring Boot 3.0.x), `testng-7.9.0`.

Result **7 / 7**:
1. off path (jar types) JSON and XML carry neither `prospectLiability` nor `timezone`, no `xsi:type`;
2. on path JSON = off path JSON + exactly the two fields (string equality after removing them); no Jackson type info;
3. on path XML keeps the root `<clubDefaultExternalResponse>` and carries `<prospectLiability>` / `<timezone>` inside `<club xsi:type="guestPassClubDefaultExternal">`;
4. no-`Accept` ≡ XML (the app's `defaultContentType(APPLICATION_XML, APPLICATION_JSON)`);
5. null fields are **omitted** in both media types (no `0` / `""` leak — R8);
6. the on-path XML **unmarshals into the jar envelope** with `JAXBContext.newInstance(ClubDefaultExternalResponse.class)`: the unknown `xsi:type` is ignored, the club is a plain `com.abcfinancial.ws.api.common.ClubDefaultExternal` with every shared field intact — observed, which is what MICO's `oraSvcRestTemplate` (a `RestTemplateBuilder` default, so `Accept` lists XML before JSON and the Jaxb2 converter reads the body) does;
7. on-path JSON deserialises into the jar envelope with `FAIL_ON_UNKNOWN_PROPERTIES=false` (MICO's `WsShop` mapper setting).

Caveats recorded: version proxies above; the DS test added in `f5aa9ea` mirrors `SpringConfiguration.objectMapper()` (MrBean + Joda + Guava modules, unknown properties tolerated, default typing deactivated) and will run on the real classpath in the PR's CI (B5/V6). RQ-10 (PK's preference) and RQ-12 (jar follow-up) stay open; the pair ships.

## A3 — field table frozen (contract v4.1 §8a(e))

See `docs/contracts/short-term-pass-bff.md` §8a(e). Names are the proposal until CF-20; RQ-15 position: a listed product must be available online (`cgi_online = '1'`).

## A4 — gating inventory (verified with `rg` on `77f1271`, 2026-10-07)

`rg -n 'GUEST_PASS|SPLEX_PROSPECT_LIABILITY|ADD_GUEST|guestPass|GuestDayPass|anySaleItemIsGuestPass|getProspectLiabilityLanguage' dtWar/src/main` — every hit, its guard, the task that proves it and the gap:

| Site (`77f1271`) | Guard in code | Off-branch | Proof task | Gap for the DTM lane |
|---|---|---|---|---|
| `CatalogItemsDB.loadCatalogItem` (~473–479, 581–590) | `guestDayPassEnabled(state)` → session club | `main` column list (guest columns spliced in only when on); state values forced `"0"` | C2 golden | SQL golden test (none exists) |
| `CatalogItemsDB.saveCatalogItem` insert (~846–975) / update (~987–1056) | same decision captured once (`guestDayPass`) | `main` INSERT (60 placeholders) / UPDATE without the three assignments; parameters list omits the three | C2 golden | SQL + bind-count golden (none exists) |
| `CatalogItemsDB.addSaleItem` (~1185), `updateSaleItemRecord` (~1198–1215), `saleItemInsertSql` | `guestDayPassEnabled(connection, clubId)` → **destination club** (`ClubDB.getClubNumber`) — per-destination evaluation (CF-23 answered by code) | `main` INSERT…SELECT / `update SALEITEMS set SAI_ACTIVE = …` | C2 golden | SQL golden with `mockStatic(ClubDB)` + `mockStatic(GuestDayPassFeatureFlag)` |
| `CatalogItemDaoImpl.updateSaleItemRecord` (~152), `insertSaleItemRecord` (~168) | club resolved by SQL from the sale item / club id (`clubNumber(sql,id)`; resolution failure → off + warn) | `main` statements | C3 golden | `ArgumentCaptor` on `NamedParameterJdbcTemplate` (none exists); note the extra club-lookup query executes even when off (existing columns only — acceptable, record) |
| `EditCatalogItemsState.load` (~498), `EditCatalogItemsSecondaryPage.isValid` (~122–141), JSP (51, 174) | `GuestDayPassFeatureFlag.isOn(session club)`; `guestDayPassEnabled` state flag; `<dt:ifEqual>` | fields/JS not rendered; values forced `"0"`; validation skipped | C4 state test | state unit test for the forced `"0"` path; before/after screenshots cannot be taken here (no M&O runtime) → recorded as pending for Chancy/QA |
| `EditClubOnlineDaoImpl.load` (~31–41), `saveProspectContent` (~55–60), `liabilityLanguage` (~73) | flag from `SPL_ABC_ID` of the club being edited | legacy SELECT `select SPL_PROSPECT_TERMS, SPL_ABC_ID from serviceProviderLocations where spl_id = :clubId` — **not byte-identical to `main`** (`main` selected `SPL_PROSPECT_TERMS` only and used `String.class`); references existing columns only — recorded as an accepted deviation | C5 golden | SQL golden test (none exists) asserting no `SPLEX_` reference when off and the liability UPDATE never executes |
| `EditClubOnlineProspect.isValid` (size check 4000 on both texts) | not gated | runs on a null liability (field not rendered → `safeLength` 0) | C5 | none (record) |
| `JdbcClubDao.getProspectLiabilityLanguage` (376) | reachable only from `sendGuestPassEmailToMember` (after the flag) | — | C6 | none |
| `ProspectServiceTransactionsImpl.sendGuestPassSaleEmail(String)` (~195–220) | club → `GuestDayPassFeatureFlag.isOn` → `transactionContainsGuestPassItem` → member | early return; `transactionContainsGuestPassItem` never | C6 (PK's test `sendGuestPassSaleEmail_flagOffSkipsGuestPassQueries`) | **duplicate import** of `GuestDayPassFeatureFlag` (lines 3 and 6; legal Java, Sonar S1128) — remove |
| `…sendGuestPassSaleEmail(PointOfSaleState)` / `sendGuestPassEmailForSaleItems` (~226–258) | flag → `anySaleItemIsGuestPass` → member | early return | C6 (PK's tests) | add `verify(never())` on `memberDao.getGuestEmailInformation` **and** on the `ADD_GUEST` send path (`sendMemberEmail` is private — assert through `memberDao`/`clubDao.getProspectLiabilityLanguage` never) |
| `PointOfSaleDaoImpl.anySaleItemIsGuestPass` (1046), `transactionContainsGuestPassItem` | callers gated as above | — | C6 | none |
| `sales/...PointOfSaleDB.handlePosTransactionCompleted` (~522), `sales3/...PointOfSaleDB` (~278) | `guestDayPassEnabled(state)` → session club; `sendGuestPassSaleEmailAfterCommit`; the static `sendGuestPassSaleEmail` wrappers catch every exception (U11) | email skipped; `publishPosTransactionCompletedEvent` unchanged | C6 (PK's `PointOfSaleDBGuestEmailTest` ×2) | add a flag-off test on `handlePosTransactionCompleted` that the email is never requested and publish still runs (if the static dependencies allow `mockStatic`; else record) |
| Call sites `EAEApi`, `POSApi`, `PosPayPageCheckoutCompleteService`, `ElectronicAgreementDB` | pass-through | unchanged | — | none |
| `JdbcMemberDao.getGuestEmailInformation` | existing columns | not gated — noted | — | none |
| `sql/*.sql` | G9 done (`77f12719`) | — | C8 → done upstream | Terry still owns the rerun guard question (CF-22) |
| `dtWar/src/main/resources/launchdarkly-local.yml` | **key absent** | — | C1 | add `MO_guest_day_pass_DT-21555: false` |
| `LDFeatureFlagConstants` test | no constants test exists in datatrak (`GuestDayPassFeatureFlagTest`, `LaunchDarklyStarterFailFastTest` only) | — | C1 | extend `GuestDayPassFeatureFlagTest` with a key-literal assertion |

datatrak-service on `main`: `rg` finds **no** guest-pass hit (expected); the planned DS sites are B1–B3 and every one sits behind `GuestPassFeature.isOn`.

## A5 — flag keys (named once, identically everywhere)

| Repo | Constant | Key | Context | Default | Local yml |
|---|---|---|---|---|---|
| datatrak-service | `LDFeatureFlagConstants.GUEST_PASS_FIELDS` | `datatrak-service-DT-21555-guest-pass-fields` | `club` (+ `vpd` when set) | off | `dtWar/src/resources/launchdarkly-local.yml`: `datatrak-service-DT-21555-guest-pass-fields: false`; `dtWar/test/resources/featureflag-local.yml`: same |
| datatrak | `LDFeatureFlagConstants.MO_GUEST_DAY_PASS` (PK) | `MO_guest_day_pass_DT-21555` | `club` | off | `dtWar/src/main/resources/launchdarkly-local.yml`: `MO_guest_day_pass_DT-21555: false` |

Handoff text (PLATFORM / Chancy / PK — CF-24): create both keys in the LaunchDarkly project each service uses, dev and prod, boolean, default **off**, club targeting; no club targeted until R3/R4 of the runbook. RQ-11 (distinct `TZL_ABC_CODE` values in dev/prod) and RQ-13 (dev test club) are asked in the execution summary; unanswered at the time of writing.

## Blockers (open)

| # | Blocked | Why | Tried | Effect |
|---|---|---|---|---|
| BL-1 | Gradle in both DataTrak repos | `artifactory.abc30ops.com` unreachable without VPN | both baselines, `--continue`, cache inspection (4.1.0 jar only); standalone `javac` + TestNG for every self-contained class | no local compile or test; **CI was the compile and proved both branches** — #591 run 1 compiled clean with 0 pre-existing failures (5 new-test failures fixed), run 4 all green; #6800 run 1 compiled clean with 0 pre-existing failures (7 new-test failures fixed), run 3 1615 / 0 / 0. Still open: a VPN re-run of both local baselines to name pre-existing local failures (none seen in CI) |
| BL-2 | D7 dev switch-over | preconditions unmet by design: DT dev flags not on, secret keys not set (PLATFORM), PRs unmerged | — | pending with the named precondition; no helm PR |
| BL-3 | Before/after M&O screenshots (C4) | no DataTrak M&O runtime here | — | pending for Chancy / QA on the PR |
| BL-4 | datatrak-service off-body goldens from `main` | no DB; the only `main` body is the 2026-09-18 scrubbed dev recording | — | goldens are built from the fixed inputs in the test (same converters), not from a live capture; the dev diff against the recording is runbook step R2 |
| BL-5 | datatrak Sonar new-code gate on PR #6800 | the `datatrak` repo runs `sonarqube` inside the `CI / Build` job and exposes no separate gate check; the Sonar server needs a token | check-run and commit-status listing on the head | V6's datatrak half reads "Build green, Sonar gate unobserved" — PK / Chancy see the gate in Sonar |
| BL-6 | Chancy's acknowledgement of a PR onto his branch (CF-19) | not asked in a channel this run (no ticketing / chat tool) | PK's direct commits to the branch noted as a signal | PR #6800 is an open draft with the review map; if declined, the body is the written change request |

## Findings for the repo owners (not fixed here, outside the sprint's files)

- **datatrak-service `ClubExternalControllerTest`** uses `@InjectMocks` on a `final`-field controller with `openMocks` in `@BeforeMethod` under TestNG's single test instance — the same stale-mock pattern that failed five new tests in #591 run 1; it is not in the include list, so it never runs under Gradle (DTS lane).
- **datatrak `PointOfSaleState`** (both packages) cannot be a Mockito mock: the inline retransform fails, and a per-mock subclass mock maker breaks every mock in the test JVM (230 failures on #6800 run 2). The audit tests build a stub subclass via objenesis inside a stubbed `StaticSpringApplicationContext` (`EnvironmentProperties` is read by the sales3 class initialiser); future tests should copy that pattern (DTM lane).
- **PK's gating** had three small defects, fixed in #6800 C1: whitespace-only club number reached LaunchDarkly (`StringSupport.safeEmpty` does not trim); duplicate import in `ProspectServiceTransactionsImpl`; no local yml row for `MO_guest_day_pass_DT-21555`.
