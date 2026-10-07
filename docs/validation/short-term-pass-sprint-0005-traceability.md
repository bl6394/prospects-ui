# Sprint 0005 — traceability: G1 and the flag rule → use cases U1–U20 → evidence → gates

**Status:** completed at E3 (2026-10-07). PRs: online-join-bff #112 (open, green), datatrak-service #591 (draft, green), datatrak #6800 (draft onto `feat/NOJIRA-guest-pass-email`, Build green). Vocabulary per row: **implemented** (built this sprint, pinned by a test that ran — CI or jest), **implemented (standalone)** (pinned by a test that ran only in the standalone `javac` run — BL-1), **audited** (PK's code verified against the plan and pinned by a new test), **pending** (cannot be observed from this build; precondition named), **external gate** (another owner's work). Nothing here claims a live DataTrak read, a merged PR, a created flag or pilot readiness. Sources: `docs/sprints/SPRINT-0005.md`; `docs/contracts/short-term-pass-bff.md` v4.1 §8a(e); the lane summaries `SPRINT-0005-EXECUTION-SUMMARY-{DTS,DTM,BFF}.md`; `short-term-pass-sprint-0005-smoke.md`.

## G1 and the flag rule → what was built

| Ask | Status | Where |
|---|---|---|
| G1: expose the guest-pass sale-item fields, the liability text and the club timezone through the service layer the BFF reads | implemented behind `datatrak-service-DT-21555-guest-pass-fields` — `getClubDefaultExternal.spr` on-path adds `prospectLiability` + `timezone`; NEW club-scoped `guestPassItems.spr` lists flagged products with `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType` | datatrak-service #591 |
| Flag rule (every production-column read/write behind a club flag, default off; deploy before or after the scripts; rollback-safe) | datatrak-service: every new SQL behind the service flag, off = `main` literals; datatrak: PK's `MO_guest_day_pass_DT-21555` audited, gaps filled; BFF: fail-closed on absent fields, observation-only `dtFields` | #591, #6800, #112; runbook `docs/deploy/guest-pass-db-and-flags.md` |
| G2 (member-less `saleItems.spr`) | **not required** — the BFF no longer calls `saleItems.spr` (CF-14 closed) | contract §10 |
| G8 (liability size / format) | wire convention = base64 HTML like `prospectTerms`; 4000-byte column (CF-21 with Terry); sanitiser carried finding (SECURITY + UI) | contract §8a(e), §10 |
| G9 (full-table UPDATE in the DDL) | done upstream by PK (`77f12719`); rerun guard open (CF-22, Terry) | #6643 branch |
| G12 (product-only enforcement) | `guestPassItems.spr` lists `cgi_service = '0'` only and carries `itemType`; the BFF skips anything but `PRODUCT` | #591, #112 |
| G13 (enablement sentence) | added to `guest-pass-pilot-gates.md` §Enabling a club | pilot gates |

## Use cases → evidence → gate

| U | Status | Evidence | Gate |
|---|---|---|---|
| U1 service flag off: `main` SQL, binds, classes, byte-identical bodies | implemented | `DtManagedClubDaoImplGuestPassSqlTest` (off literal = `main`, binds `[clubNumber CHAR, active CHAR=1]`), `ClubExternalServiceImplGuestPassTest` (off DAO, jar response class), spike goldens `club-defaults-off.{json,xml}` (JSON, XML, no-`Accept` = XML) — CI runs 2–4 green | V1 |
| U2 service flag on: `prospectLiability`, `timezone`, left joins | implemented | on SQL = off + two columns + two LEFT JOINs (string-stripping assertion); `GuestPassClubDefaultExternalRowMapperTest` 8 (null liability → `""`, null timezone omitted, `ZoneId` / `SHORT_IDS` / raw+warn); `club-defaults-on.{json,xml}` goldens; `clubDefaults_flagOn_runsTheGuestPassDaoAndAnswersTheSubclassPair` | V2 |
| U3 flag on, columns absent → warn once → off shape | implemented | `ClubExternalServiceImplGuestPassTest` ORA-00904 cases (error code 904 and message-only; once per club across two calls; other codes propagate) | V2 |
| U4 POS sale-items untouched | implemented | `git diff --stat origin/main..HEAD` — no POS path; `DtManagedClubDaoImplGuestPassItemsSqlTest` reads the POS bundle only to assert the taxed CASE is verbatim | V1 |
| U5 items, flag on | implemented | `GET_GUEST_PASS_ITEMS` / `GET_GUEST_PASS_ITEM` constants pinned (`sai_guest_pass='1'`, `cgi_service='0'`, `cgi_online='1'`, optional `sai_id`); `GuestPassItemRowMapperTest` 5 (`itemType` PRODUCT / SERVICE / BILLING / other → omitted); `guest-pass-items-success.{json,xml}` | V2 |
| U6 items, flag off or club unknown → unavailable envelope, no SQL | implemented | `verifyNoInteractions(dtManagedClubDao)` when off; controller vpd 0 → unavailable without a service call; `guest-pass-items-unavailable.{json,xml}` | V1 |
| U7 items, flag on, columns absent → unavailable | implemented | service ORA-00904 case for items | V2 |
| U8 consumer safety (XML into the jar envelope; JSON into the jar / MICO classes) | implemented | spike `onPath_xml_unmarshalsIntoTheJarEnvelope_likeMico`, `onPath_json_deserialisesIntoTheJarEnvelope_likeMico`; `GuestPassItemSerializationTest.success_json_readsIntoThePosSaleItemResponseShapeWithATolerantMapper` | V3 |
| U9 M&O flag off: `main` statements, no new column, page not rendered, posted values ignored | audited | `CatalogItemsDBGuestPassSqlTest` 10 (off INSERT 60 placeholders / UPDATE 53 binds / sale-item sync `main` strings, captor sweep for `*_GUEST_PASS`), `CatalogItemDaoImplGuestPassSqlTest` 6, `EditClubOnlineDaoImplGuestPassTest` 4 (no `SPLEX_` when off; one UPDATE), `EditCatalogItemsSecondaryPageGuestPassTest` 5 (values forced `"0"`, no messages), `ProspectServiceTransactionsImplEmailTest` flag-off `never()` on `memberDao` / `clubDao` for both entry points (⇒ `ContactsDB.load(ADD_GUEST)` never) — CI run 3 green | V4 |
| U10 M&O flag on: #6643 behaviour | audited | the on-path cases of the same tests; PK's existing tests kept | V4 |
| U11 M&O flag on, columns absent: pages fail loudly, POS hook never fails a sale | audited | the static `sendGuestPassSaleEmail` wrappers catch every exception; after-commit synchronisation (PK's tests); both `PointOfSaleDBGuestEmailTest` flag-off / flag-on cases publish regardless | V4 |
| U12 no club context → `false` before evaluation | implemented (DS) + audited/fixed (DT) | `GuestPassFeatureTest` (null / blank / non-canonical → `verifyNoInteractions`); `GuestDayPassFeatureFlagTest` (+ whitespace-only club, fixed in C1) | V1 |
| U13 LD unavailable / throwing → off | implemented + audited | `GuestPassFeatureTest` (bean null, context not initialised, evaluation throws); PK's `GuestDayPassFeatureFlagTest` (missing service, evaluation failure) | V1 |
| U14 BFF, columns absent (recorded responses) | implemented | matrix cells absent / club, absent / items (`getClubDefaultExternal.recorded.json`, CF-14 history fixtures) → `missing: timezone`, no offers, `dtFields: absent (off, old code or columns missing — unknown which)` | V5 |
| U15 BFF, DT flag off ≡ U14 | implemented | one recorded file under two labels, deep-equal outputs; `guestPassItems.unavailable.synthetic.json` → `offers error (unavailable)` | V5 |
| U16 BFF, DT flag on | implemented (synthetic fixtures, labelled) | on / club and on / items cells: `timezone` validated, liability decoded as the waiver, exactly one eligible product, skipped `multi-visit` / `not-a-product` / `unknown-type` / `not-flagged`, `dtFields: present` | V5 |
| U17 timezone validation | implemented | `timezoneId.test.ts` + adapter test: `America/Chicago` ok; `US/Central` → `America/Chicago`; `Nonsense/Zone` → `missing: ['timezone:invalid']`; never GMT | V5 |
| U18 liability path / sanitiser | recorded | D5 trace: same path as `prospectTerms` (`consentTemplates.ts` → `DocumentDialog.tsx` `html-react-parser`; mock stand-in mail); no new sink; carried finding SECURITY + UI (contract §10) | V5 |
| U19 UI unavailable block | implemented (existing) | `ShortTermPassPage.test.tsx` 16 / 16 on `main` `3967c43`; no UI change | V5 |
| U20 dev switch-over | **pending** | preconditions: R0 keys, R1 scripts, R2 merges + deploys, R3 / R4 flags for the test club (RQ-13), R5 secret — smoke §live | V7 |
| Regression | implemented | BFF jest 69 / 69 (706 passed), demo 58 / 58; DS CI 607 / 607 incl. the existing include list; DT CI 1615 / 0 (PK's tests included); MICO untouched (U4, U8) | V6 |

## Gates V0–V7

| Gate | Verdict | Evidence |
|---|---|---|
| V0 — Freeze | **passed** | A2 decision recorded (contract §8a(e), BLOCKERS §A2); field table frozen and mirrored (BFF `DatatrakGuestPassItem` / DS `GuestPassItem`); keys named identically (constants, ymls, contract, runbook); A4 inventory = `rg` (re-run at E2); baselines recorded as blocked with the CI proxy; branches and ledger recorded |
| V1 — Flag off is today | **passed (CI)** | SQL + bind goldens = `main` literals in both repos; DS off bodies byte-pinned for JSON / XML / no-`Accept` from fixed inputs (BL-4 caveat: not a live `main` capture); POS files unchanged; `guestPassItems.spr` executes no SQL when off; `rg` map lists only guarded sites; MICO's calls untouched |
| V2 — Flag on exposes the fields | **passed (CI)** | U2, U5 at service and controller level; products only; `itemType`; timezone normalised; liability base64; left-join nulls; ORA-00904 fallback |
| V3 — Consumer safety | **passed** | XML into the jar envelope; JSON into the jar / MICO classes; no header literal or credential in PR text, tests or docs (regex scan at E2; the one copied `headers` line is byte-identical to its siblings) |
| V4 — M&O gating | **passed (CI) with CF-19 open** | every inventory site guarded (PK) and pinned (DTM tests); email reordered; both hooks skip + publish; `ADD_GUEST` never when off; existing tests kept; draft PR #6800 open onto Chancy's branch with the review map — Chancy has not acknowledged (CF-19); screenshots pending (BL-3) |
| V5 — BFF matrix | **passed (mock)** | six cells; `timezone:invalid` and `unknown-type` fail closed; `dtFields` wording; fixtures labelled; coverage 97.47 / 86.5 / 97.19 / 98.28 ≥ 84 / 67 / 67 / 84; Sonar green on #112; UI 16 / 16 |
| V6 — Tests actually run | **passed for DS (CI), passed for DT Build (CI), Sonar gate on DT unobserved** | DS: nine include-list entries, all named in the CI test results, Sonar new-code gate green on #591; DT: 1615 / 0 on #6800 run 3 vs the `77f1271` baseline (CI pass) — the datatrak repo exposes no separate Sonar gate check, so its new-code gate is **unobserved** |
| V7 — Runbook and status | **passed (docs) with §live pending** | runbook R0–R7 + P0–P7 with stop rules; V-P1a rewritten; contract v4.1 + registers; smoke §live pending with the named preconditions; ledger; execution summaries; four verdicts |

## Pilot gates touched

V-P1a rewritten as the runbook rows (status "code prepared, pending — first unmet step R0"); V-P1b wording unchanged (now R5 / R6); V-P6 / CR-21 enablement sentence added. The pilot checklist remains entirely `pending` / `blocked`.
