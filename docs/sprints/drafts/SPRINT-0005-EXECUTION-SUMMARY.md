# Sprint 0005 — execution summary (orchestrator view), 2026-10-07

Executor: Claude Fable 5.1 — Phase A single session, then the DTS (datatrak-service), DTM (datatrak) and BFF lanes as parallel subagents, Phase E by the orchestrator. Planning-repo commits `7a779a9` (Phase A) and the E4 docs commit on `main`. Lane files: `SPRINT-0005-EXECUTION-SUMMARY-{DTS,DTM,BFF}.md`, `SPRINT-0005-BLOCKERS{,-DTS,-DTM,-BFF}.md`, `SPRINT-0005-PR-DESCRIPTIONS{,-DTS,-DTM,-BFF}.md`.

## The four verdicts (never merged)

1. **Implementation and mock acceptance — done.** datatrak-service draft PR #591 (`2a5d599`): `prospectLiability` and `timezone` on `getClubDefaultExternal.spr` and a NEW club-scoped `guestPassItems.spr`, behind `datatrak-service-DT-21555-guest-pass-fields`; flag off = `main` SQL, binds, classes and bodies (SQL + bind goldens equal the `main` literals; JSON / XML / no-`Accept` bodies pinned); flag on tested at DAO, service, controller and converter level; ORA-00904 self-heal; XML unmarshals into the jar envelope; CI Build / Endor / Sonar green, 607 / 607 tests incl. the 77 new ones, POS files untouched. datatrak draft PR #6800 (`1c5755b2`, onto `feat/NOJIRA-guest-pass-email`): PK's same-day gating under `MO_guest_day_pass_DT-21555` audited site by site against the A4 inventory, SQL + bind goldens for the off path, the `ADD_GUEST` path proven never when off, three small defects fixed (whitespace club, duplicate import, local yml key); CI Build green 1615 / 0 / 0 (Sonar gate unobserved — BL-5). BFF PR #112 (`b22febc`): adapter on the v4.1 names and the new endpoint, six-cell {absent, off, on} × {club, items} matrix on labelled fixtures, strict timezone (never GMT) and item-type validation, `dtFields` observation; jest 69 / 69, coverage 97.47 / 86.5 / 97.19 / 98.28, demo 58 / 58, Sonar green. **The two DataTrak PRs are open drafts, not merged** — named as such, not counted as merged.
2. **Standalone dev host — carried from Sprint 0004, not re-verified.**
3. **Live integration — pending.** DataTrak catalog read: **pending** — PRs unmerged, scripts not run, neither DT flag created or on, `STP_DATATRAK_SERVICE_URL` / `STP_DATATRAK_SERVICE_AUTH` not in the secret (runbook R0–R5; first unmet step R0); no remote host was probed. Prospect create / repaint / deactivate: mock only (CF-15). Hosted capture: carried (B1). QR, Add Guest email and access enforcement are DataTrak's and unverified from this build.
4. **Pilot — not eligible** until V-P0…V-P6 pass; V-P1a is now the runbook rows R0–R7 (`docs/validation/guest-pass-pilot-gates.md`).

## What shipped

| Repo | Branch / head | PR | Commits |
|---|---|---|---|
| datatrak-service | `DT-21555-guest-pass-service-fields` `2a5d599` (off `main` `d280934`) | https://github.com/abcfinancial/datatrak-service/pull/591 (**draft**, CI + Endor + Sonar pass) | A2 `f5aa9ea`; B1 `29bf512`; B2/B3 `24006c4`; B4 `c793570`; B5 `1ac07f4`; test fix `b36f727`; Sonar `4fae6a9`, `2a5d599` |
| datatrak | `DT-21555-guest-pass-flag-gating` `1c5755b2` (off `feat/NOJIRA-guest-pass-email` `77f1271`; Chancy's branch untouched) | https://github.com/abcfinancial/datatrak/pull/6800 (**draft**, base Chancy's branch, Build pass) | C1 `5e36837c`; C2 `03dfab2d`; C3 `7236c29f`; C4 `16731730`; C5 `e9862a2c`; C6 `ee71e15b`; `3f683a8a` (withdrawn approach); fix `1c5755b2` |
| online-join-bff | `prospect-wallet/sprint-0005` `b22febc` (off `main` `5e370a0`; version 1.3.0) | https://github.com/abcfinancial/online-join-bff/pull/112 (open, all checks pass) | D3 `2213ba8`; D1/D2 `43ff8bf`; D4 `8f8e156`; bump `ca3bb38`; Sonar `b22febc` |
| online-join-ui | `main` `3967c43` | none — proof only (16 / 16) | — |
| helm-configs | — | none — D7 pending (BL-2) | — |
| prospects-ui | `main` | not pushed (per instruction) | Phase A `7a779a9`; E4 docs commit |

## Proof (E2) — `docs/validation/short-term-pass-sprint-0005-smoke.md`

| Check | Result |
|---|---|
| A2 spike (gate) | 7 / 7 standalone (version proxies recorded) → local DTO pair, no jar bump; 14 / 14 with goldens in CI |
| datatrak-service CI | run 1: compile clean, 607 completed / 5 failed (new controller tests, stale `@InjectMocks`), 0 pre-existing failures; run 2: 607 / 607, Sonar 12 new findings; run 3: 1 finding; **run 4: Build, Endor, Sonar pass** |
| datatrak CI | run 1: compile clean, 1615 / 7 failed (new tests mocking `PointOfSaleState`), 0 pre-existing; run 2: withdrawn (230 failures from a mock-maker change); **run 3: 1615 / 0 / 0** |
| BFF | jest 69 / 69 (706 passed, 2 skipped); coverage 97.47 / 86.5 / 97.19 / 98.28; lint / tsc / build clean; demo 58 / 58; first Sonar scan failed on S3776 → fixed `b22febc` → pass |
| UI | `ShortTermPassPage.test.tsx` 16 / 16, no code change |
| `rg` map | re-run on both DT heads at E2 — the A4 file set, every hit guarded; DS hits only under `club/external/**`, `repository/club/mapper/**`, `launchdarkly/**` |
| Credential scan | regex `Basic [A-Za-z0-9+/=]{12,}` over every added line in the three branches and over `docs/`: the single hit is the new endpoint's `headers` attribute, byte-identical (ignoring whitespace) to the eight sibling lines; a fake test token in a lane note was redacted |
| Local Gradle baselines | **blocked** (BL-1, Artifactory / VPN) — CI runs 1 are the baseline proxies |
| D7 / §live | **pending** with the preconditions named |

## Gates V0–V7

V0 passed · V1 passed (CI) · V2 passed (CI) · V3 passed · V4 passed (CI; CF-19 acknowledgement open; screenshots pending BL-3) · V5 passed (mock) · V6 passed for datatrak-service (include list + CI results + Sonar new-code green) and for the datatrak Build; the datatrak Sonar gate is unobserved (BL-5) · V7 passed for the documents, §live pending. Detail: `docs/validation/short-term-pass-sprint-0005-traceability.md`.

## What changed during execution (recorded in the sprint document)

- **PK pre-empted Phase C.** Four commits on Chancy's branch on 2026-10-07 implemented the M&O gating under `MO_guest_day_pass_DT-21555` (decision D3's second key superseded by the code fact), reordered the email, sent it after commit and rewrote the DDL (G9 done). Phase C became an audit and gap-fill; C8 needed no commit.
- **No local Gradle.** Both DataTrak baselines failed at dependency resolution (Artifactory unreachable without VPN). The A2 gate and every self-contained DS class were proven with a standalone `javac` + TestNG run; the pull requests' CI was the first compile of everything else, with one test-fix round per DT PR and three Sonar rounds on #591.
- **Deviations accepted (lane records):** B2/B3 and D1/D2 share a commit each; the items statement resolves the club through `serviceproviderlocations.spl_abc_id` in one query; DS SQL constants became text blocks with byte-equality proven; the catalog INSERT / UPDATE expressions were lifted into package-private helpers to be testable; the Edit Club off SELECT adds `SPL_ABC_ID` (existing column); an unparsable `salePrice` falls back to `catalogPrice`.

## Findings worth a sentence to the owners

1. `ClubExternalControllerTest` (datatrak-service) carries the stale-mock pattern and is not in the include list (never runs).
2. `PointOfSaleState` (datatrak) cannot be a Mockito mock; the stub-subclass pattern in the audit tests is the way.
3. Three small defects in PK's gating fixed in #6800 C1 (whitespace club reached LaunchDarkly; duplicate import; no local yml key).
4. Club-authored consent HTML (`prospectTerms`, now also `prospectLiability`) is rendered unsanitised in the UI dialog and the mock stand-in mail — carried finding, SECURITY + UI (contract §10).

## Handoffs (no ticket ids — the executor has no ticketing tool; text ready to paste)

- **PLATFORM / Chancy / PK (CF-24):** create `datatrak-service-DT-21555-guest-pass-fields` and `MO_guest_day_pass_DT-21555` in the LaunchDarkly project each service uses, dev and prod, boolean, club context, default off, no targeting (runbook R0). `guest-pass-online` (CF-17) still pending.
- **PLATFORM:** `STP_DATATRAK_SERVICE_URL` / `STP_DATATRAK_SERVICE_AUTH` into `platform-online-join-bff` at runbook R5 (not before).
- **Terry Smith:** R1 scripts in dev (the `77f12719` form); rerun guard on the ALTERs (CF-22); liability column size (CF-21); distinct `TZL_ABC_CODE` values dev / prod (RQ-11); drain bound with DT (RQ-16).
- **PK:** review #591 (RQ-10: the local DTO pair vs a jar bump; RQ-12 follow-up); review #6800; the datatrak Sonar gate (BL-5).
- **Chancy:** CF-19 (the PR onto his branch — PK already commits there); CF-20 names; RQ-13 dev test club; R3 / R4 flips; screenshots for #6800 (BL-3); RQ-14 / RQ-15 positions.
- **SECURITY + UI:** the sanitiser carried finding.

## How to resume

1. Get on VPN; re-run `./gradlew :dtWar:test` in both DT repos on the branch heads and record pre-existing local failures by name (BL-1's open half).
2. Ask PK / Chancy to review #591 and #6800 (drafts → ready when they say so); never rebase Chancy's branch.
3. Follow the runbook in order; the first unmet step is R0. Verdict 3 moves to **done** only when R5's capability report and the `*.flag-on.recorded.json` exist.
4. Keep the four verdicts separate; close SPRINT-0005 in the ledger only when verdict 1's PRs are merged or the user says the mock-proven bar closes it.
