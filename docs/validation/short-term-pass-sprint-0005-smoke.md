# Sprint 0005 — smoke and proof (E2): unit / mock proof per repo, the `rg` map, and §live

**Status:** complete for this sprint (E2, 2026-10-07): BFF PR #112 green; datatrak-service PR #591 green (draft); datatrak PR #6800 Build green (draft, Sonar gate unobserved); §live pending. Vocabulary: every row names its mode — **unit** (Gradle / jest), **mock** (BFF fixtures, demo), **CI** (the pull request's check runs — the only compile and test run available for the DataTrak repos this session, see `SPRINT-0005-BLOCKERS.md` BL-1), **live** (the dev cluster — nothing live was observed this sprint). Nothing here is a pilot verdict; the four verdicts are in `docs/sprints/drafts/SPRINT-0005-EXECUTION-SUMMARY.md`.

## §BFF — `online-join-bff` PR #112 (`prospect-wallet/sprint-0005`, base `5e370a0`)

| Check | Mode | Result |
|---|---|---|
| jest (full) | unit | **69 / 69 suites, 706 passed, 2 skipped**; `__tests__/datatrakServiceCatalog.test.ts` 15 tests + `__tests__/timezoneId.test.ts` 2 (was 9) |
| coverage | unit | **97.47 / 86.5 / 97.19 / 98.28** (floors 84 / 67 / 67 / 84 unchanged in `jest.config.js`) |
| eslint · `tsc --noEmit` · `npm run build` | unit | clean · clean · clean |
| demo 0–6 | mock | **58 / 58** (`STP_EMAIL_TRANSPORT=mock`; the demo now prints the `DT fields` line — `n/a` on the fixture catalog — and the verdict-3 line "live DataTrak read pending (datatrak-service PR, scripts, flag, secret)") |
| six-cell matrix (U14–U16) | mock | pinned — table in `SPRINT-0005-EXECUTION-SUMMARY-BFF.md` §matrix: absent / off / on × club / items, each cell with its fixture file; `timezone:invalid` (U17) and `unknown-type` fail closed; `dtFields` wording asserted |
| UI unavailable block (U19) | unit | `online-join-ui` `main` `3967c43`, no code change: `ShortTermPassPage.test.tsx` **16 / 16** (flag off, 404 from the BFF, zero eligible offers → the same block) |
| D5 liability path (U18) | read | no new sink: `prospectLiability` travels the same path as `prospectTerms` (`consentTemplates.ts` override → `ConsentDocument.html` → `DocumentDialog.tsx` `html-react-parser`, and the mock stand-in mail); sanitiser registered as a carried finding (contract §10, owner SECURITY + UI); no code change |
| PR checks | CI | first head: CI / Build pass, Endor pass, LD flag diff pass, **SonarQube fail (S3776 cognitive complexity in the demo script)** → fixed behaviour-unchanged in `b22febc` (helper extracted); re-scan result recorded in the execution summary §PR checks |

## §DS — `datatrak-service` draft PR #591 (`DT-21555-guest-pass-service-fields`, base `d280934`, head `2a5d599`)

| Check | Mode | Result |
|---|---|---|
| A2 DTO / converter spike | unit (standalone `javac` + TestNG, cached jars; version proxies in `SPRINT-0005-BLOCKERS.md` §A2) | **7 / 7** — off bodies carry neither field; on JSON = off + two fields; on XML carries `<prospectLiability>` / `<timezone>` under `<club xsi:type="guestPassClubDefaultExternal">`; no-`Accept` = XML; null fields omitted; on-path XML unmarshals into the jar envelope; on-path JSON into the jar envelope with unknown properties ignored |
| Gradle `:dtWar:test` locally | unit | **not run — BL-1** (Artifactory unreachable without VPN; no pre-existing failure can be named locally) |
| Standalone run of the self-contained classes | unit | **50 / 50** (constants 5, `GuestPassFeatureTest` 9, both row mappers 8 + 5, `GuestPassItemSerializationTest` 9, spike + goldens 14), then 28 / 28 after the Sonar DTO change |
| CI run 1 (`1ac07f4`) | CI | first compile of everything: clean; `:dtWar:test` **607 completed, 5 failed** — all in `ClubExternalControllerGuestPassItemsTest` (stale `@InjectMocks` under TestNG's single instance); 72 / 77 new tests green; **0 pre-existing failures** |
| CI run 2 (`b36f727`) | CI | **607 / 607 green** (controller built per method); Sonar gate fail — 12 new-code findings (S6126 ×6, S1192 ×2, S2589, S1104, S2293, S125) |
| CI run 3 (`4fae6a9`) | CI | Build pass, 607 green; Sonar 1 new finding (S6201) |
| CI run 4 (`2a5d599`) | CI | **Build pass, Endor pass, SonarQube pass (0 new issues)** — 607 tests incl. the 77 DT-21555 tests; string equality of every SQL constant before/after the text-block change proven standalone (6 / 6) |
| goldens (SQL + binds; bodies JSON / XML / no-`Accept`; consumer unmarshal; ORA-00904 fallback; `never()` when off) | CI | all green in runs 2–4: `DtManagedClubDaoImplGuestPassSqlTest` 4, `DtManagedClubDaoImplGuestPassItemsSqlTest` 6, `ClubExternalServiceImplGuestPassTest` 16, `ClubExternalControllerGuestPassItemsTest` 6, mappers 8 + 5, serialisation 9, spike 14, helper 9, constants 5; eight golden files under `test/resources/guest-pass/` (the `ResponseMessages` XML golden matched under the real `CommonWsObjects` 1.2.0) |
| include list (V6) | CI | nine `DT-21555` entries in `dtWar/build.gradle`; the CI job's published test results name every class |
| POS files untouched (U4) | unit | `git diff --stat origin/main..HEAD`: 37 files, none under `controller/POSController.java`, `validator/`, `repository/pos/`, `api/pos/` |
| credential / header literal | read | added lines containing `Basic `: exactly one — the new endpoint's `headers` attribute, byte-identical (ignoring whitespace) to the eight existing ones; nothing in tests, goldens, docs or the PR body |

## §DT — `datatrak` draft PR #6800 onto `feat/NOJIRA-guest-pass-email` (`DT-21555-guest-pass-flag-gating`, base `77f1271`, head `1c5755b2`)

| Check | Mode | Result |
|---|---|---|
| Baseline | CI | PR #6643 `CI / Build` **pass** on `77f1271` (PK's head) — the datatrak baseline proxy; local Gradle blocked (BL-1) |
| Audit of PK's gating against the A4 inventory | read | every site guarded as described; every off-path statement is `main`'s literal or a recorded deviation (catalog INSERT whitespace inside `values (…)`; Edit Club off SELECT adds `SPL_ABC_ID`; one existing-column club lookup runs in both states); binds match placeholders (60 / 63, 53 / 56); email ordering club → flag → guest SQL; both hooks publish regardless of the flag — `SPRINT-0005-EXECUTION-SUMMARY-DTM.md` §review map |
| Findings fixed in PK's code (C1) | read + CI | whitespace-only club number reached LaunchDarkly (`safeEmpty` does not trim) → one-line trim; duplicate import in `ProspectServiceTransactionsImpl`; missing `MO_guest_day_pass_DT-21555: false` in `launchdarkly-local.yml` |
| CI run 1 (`ee71e15b`) | CI | first compile: clean; **1615 completed, 7 failed** — all seven new tests that did `mock( PointOfSaleState.class )` (inline retransform fails on that class); **0 pre-existing failures** |
| CI run 2 (`3f683a8a`) | CI | **withdrawn** — a per-mock subclass mock maker broke the inline maker for the whole JVM: 1637 completed, 230 failed, 233 skipped |
| CI run 3 (`1c5755b2`) | CI | **`CI / Build` pass — 1615 / 0 failed / 0 skipped**; all eight DTM test classes green (56 tests): `GuestDayPassFeatureFlagTest` (+2), `CatalogItemsDBGuestPassSqlTest` 10, `CatalogItemDaoImplGuestPassSqlTest` 6, `EditCatalogItemsSecondaryPageGuestPassTest` 5, `EditClubOnlineDaoImplGuestPassTest` 4, `ProspectServiceTransactionsImplEmailTest` (+4), both `PointOfSaleDBGuestEmailTest` (+2 each); `:dtWar:sonarqube` ran inside the job — the repo surfaces no separate Sonar gate check, so the gate verdict is **unobserved** (recorded, not claimed) |
| G9 | read | done upstream by PK (`77f12719`); `sql/` untouched by this PR |
| screenshots (C4 / C5) | — | **pending** — no M&O runtime here (BL-3); Chancy / QA on the PR |
| credential | read | added lines with a `Basic ` token: 0 |

## §rg map (re-run at E2 — every hit guarded)

`datatrak` (`DT-21555-guest-pass-flag-gating` `1c5755b2`): `rg -c 'GUEST_PASS|SPLEX_PROSPECT_LIABILITY|ADD_GUEST|guestPass|GuestDayPass' dtWar/src/main` → 13 files (`GuestDayPassFeatureFlag` 3, `LDFeatureFlagConstants` 1, `CatalogItemDaoImpl` 11, `EditClubOnlineDaoImpl` 7, `ProspectServiceTransactionsImpl` 7, `EditClubOnlineProspect` 2, `CatalogItemsDB` 29, `EditCatalogItemsSecondaryPage` 4, `EditCatalogItemsState` 16, both `PointOfSaleDB` 2 + 2, `launchdarkly-local.yml` 1, `EditCatalogItemsSecondaryPage.jsp` 12) — the same file set as the A4 inventory on `77f1271` plus the yml key; every hit guarded per `SPRINT-0005-BLOCKERS.md` §A4 and the DTM review map. `datatrak-service` (`DT-21555-guest-pass-service-fields` `2a5d599`): `rg -c 'GUEST_PASS|SPLEX_PROSPECT_LIABILITY|guestPass|GuestPass' dtWar/src` → 14 files, all under `club/external/**` (api 4, controller, dao 3, service 2), `repository/club/mapper/**` (2) and `launchdarkly/**` (2); none under the POS paths.

## §live — D7 / U20: **pending** (BL-2)

No remote host was probed this sprint (no VPN, no credential). The dev switch-over (helm `STP_CATALOG_SOURCE=datatrak`, boot, capability report `DT fields: present`, `POST /checkouts` 201 for the test club, scrubbed `*.flag-on.recorded.json`) is recorded as **pending** with the preconditions named, in runbook order (`docs/deploy/guest-pass-db-and-flags.md`):

1. R0 — the two LaunchDarkly keys created (PLATFORM / Chancy / PK; CF-24) — not done;
2. R1 — the DBA scripts run in dev (Terry) — not done;
3. R2 — the datatrak-service PR and the datatrak PRs reviewed, merged and deployed (PK, Chancy) — draft PRs open, unmerged;
4. R3 / R4 — `MO_guest_day_pass_DT-21555` then `datatrak-service-DT-21555-guest-pass-fields` on for the dev test club (RQ-13 unanswered) — not done;
5. R5 — `STP_DATATRAK_SERVICE_URL` / `STP_DATATRAK_SERVICE_AUTH` in `platform-online-join-bff` (PLATFORM) — not done; then the signed helm PR.

Operator-confirmed LD state: none recorded (nothing has been created). The BFF's `dtFields` line is an observation and is `n/a` in fixture mode.
