# Day Pass and Guest Pass — release notes

**As of:** 2026-11-03 · **Covers:** Sprints 0001–0005 · **Source of truth:** `docs/sprints/ledger.yaml`, checked against GitHub PR states on 2026-11-02

**Production status:** code is deployed to production, but the feature is not on. The release pipeline deployed datatrak-service `4988e45` (Sprint 0005, #591, v4.247.0) to dev, staging, beta and prod on 2026-11-02, and online-join-bff `333b8e1` (Sprint 0005, #112, v1.3.0) to dev, staging, beta and prod the same day. Datatrak `744008c` (v4.741.0) reached prod on 2026-10-30. **Production test (approved by Bjorn Loftis; Paul Knuth approved; DBA scripts confirmed):** both flags are on in production for club `99921` only. Their default rule serves `false`, so every other club stays off. This was set in the 2026-11-02 to 2026-11-03 session and has not yet been verified against a live request. The Online Join flow cannot reach the service layer in production until the BFF secret is set. Sprints 0001–0004 are not verified in production. The feature's production release still needs approval (requested with Paul Knuth on 2026-10-15).

---

## Summary

| Sprint | What it delivers | Merged to `main` | Status |
|---|---|---|---|
| 0001 | Day Pass single-flow checkout in Online Join | UI #524 (2026-09-17), BFF #96 (2026-09-17) | Done. Design parity and hosted Pay Page were transferred to Sprint 0002 |
| 0002 | Design v1.2 parity, consent, Pay Page embed, email OTP for every buyer, prospect-wallet save | **Not verified on `main`** (see below) | Marked done in ledger; evidence on `main` is missing |
| 0003 | Selectable 1/3/5-day passes, QR and receipt by email, login-free "View your pass" page | UI #525 (2026-09-17), BFF #99 (2026-09-17) | Done. Live email and hosted capture unverified |
| 0004 | Guest Pass v1: catalog-flagged single-visit passes from DataTrak, create → pay → deactivate, standalone Guest Pass host | UI #532 (2026-09-18), BFF #107 (2026-09-18), helm #3090 | Done in mock. Live DataTrak read not run |
| 0005 | Guest-pass fields through the DataTrak service layer, every production DB dependency behind a flag (default off) | datatrak #6643 and #6800 (2026-10-20). datatrak-service #591 (2026-11-02, squash `4988e45`). BFF #112 (2026-11-02, `333b8e1`). BFF #121 closed unmerged (its lint fix is in #112) | Merged to `main` and deployed to prod; flags on in prod for test club 99921 only; live DataTrak read pending |

---

## What each release contains

### Sprint 0001 — Day Pass checkout (UI #524, BFF #96)
- Single-flow Day Pass purchase inside Online Join, following the Riverside demos.
- Dark-mode UI flow.
- BFF routes, session handling, OTP, and purchase orchestration.

### Sprint 0002 — Review changes (not verified on `main`)
Planned scope: Design v1.2 parity, §4.5 consent, Pay Page embed, email OTP for every buyer, prospect-wallet save, and the agent test harness (the harness lane was deferred).

**Verification gap:** the ledger marks this sprint done, but the three Sprint 0002 UI commits (`29ebc96`, `fa1878c`, `41d7444`) are not on `origin/main`. They sit on the `pr-524-head` and `cursor/show-purchase-pay-errors-3308` branches. No Sprint 0002 BFF commits were found on `main`. **Do not announce Sprint 0002 features until this is checked.**

### Sprint 0003 — Design v4 (UI #525, BFF #99)
- Choose a 1-, 3-, or 5-day pass, with date-range validity.
- Pass QR code and receipt delivered by email.
- "View your pass" page that needs no login.

**Known limits:**
- Pass email and link were proven locally with Mailpit only.
- The QR is static. Desk verification and rotation are unverified.
- Live email is unverified (the publisher returned 503 during testing).
- Hosted capture is unverified (item B1).

### Sprint 0004 — Guest Pass v1 (UI #532, BFF #107, helm #3090)
- Guest passes come from DataTrak catalog items flagged for guest use.
- Validity starts when the pass is bought.
- Pass QR is rendered by DataTrak and sent by email.
- Legal opt-in at checkout.
- Flow: create → pay → deactivate (and revert on failure).
- Standalone Guest Pass host, with dev values in helm.

**Known limits:**
- Verified with mock environments only (E2: 71/71 on the mock recipe).
- Live DataTrak catalog read was not run. E4 was blocked by an ENOTFOUND error.
- Guest-pass exposure is gated by the LaunchDarkly flag `guest-pass-online`, which is a platform handoff.

### Sprint 0005 — DataTrak service layer (flags default off)
**Merged 2026-10-20**
- datatrak #6643 (Chancy's M&O changes) merged to datatrak `main`.
- datatrak #6800 (flag-gating audit, SQL goldens for the off path) merged to `feat/NOJIRA-guest-pass-email`, which is an ancestor of `main`.
- Every new production DB column and statement is behind `MO_guest_day_pass_DT-21555` (M&O) or `datatrak-service-DT-21555-guest-pass-fields` (service). Both default off.

**Deployed 2026-11-02 (all of dev, staging, beta, prod; flags off):** datatrak-service v4.247.0 (`4988e45`), online-join-bff v1.3.0 (`333b8e1`).

**Merged 2026-11-02:**
- datatrak-service #591 merged by mithrandr as squash `4988e45` (PR head `086ec67`). Approved by mithrandr. Circuit's two findings on `943c368` (a database query before the flag check; a failed VPD lookup returning a 500) were fixed in `086ec67`, with tests. bgfaulk was still listed as a requested reviewer at merge.
- online-join-bff #112 merged by mithrandr as `333b8e1` (PR head `7d4f3a5`). Approved by mithrandr and paulobrien109. Version 1.3.0. The `import/order` lint fix from #121 was folded into #112.
- online-join-bff #121 closed unmerged on 2026-11-02, replaced by the lint fix in #112. The `main` lint error is fixed in `main` (`src/routes/payPage/index.ts` imports are in order).

**Test evidence:**
- datatrak-service `:dtWar:test` on `086ec67`: 687 tests, 0 failures (local, 2026-11-02).
- online-join-bff on `bc79e91`: 70 suites, 759 passed, 2 skipped; build clean (local, 2026-11-02). Lint has one error on `main`, which #121 fixes.

---

## Not yet done

| Item | Owner | Blocker |
|---|---|---|
| Live DataTrak catalog read in dev (runbook R0–R5) | Sprint 0005 team | Confirm dev flag states and DBA scripts with Chancey Toombs and Paul Knuth. Message sent 2026-10-22, no reply yet |
| Set `STP_DATATRAK_SERVICE_URL` and auth in the BFF secret | Platform | — |
| Helm `STP_CATALOG_SOURCE=datatrak` in dev (D7, BL-2) | Platform | Needs signed helm PR after live read |
| Sprint 0002 verification on `main` | Sprint 0002 owner | See gap above |
| Name the owner of `datatrak-service-DT-21555-guest-pass-fields` (created 2026-11-02, off in every environment; maintainer set to Paul Knuth as an individual on 2026-11-02, to move to Chancey once they join LaunchDarkly) | Platform, with Chancy / PK | Chancey is not a LaunchDarkly member yet; no team owner chosen. Platform to confirm the project (`ignite-mo` chosen by analogy with the M&O flag) |
| Confirm prod is inert for clubs other than 99921 | Sprint 0005 team | Live read not run. Prod datatrak `744008c` and BFF `333b8e1` not yet checked against the flags |
| Verify guest-pass endpoints for club 99921 in prod (`getClubDefaultExternal.spr`, `guestPassItems.spr`) | Sprint 0005 team | Needs the production credential; not run |
| Guest-pass product for club 99921 in M&O prod (runbook R3) | Chancey / QA | Not started |
| Production release | Bjorn Loftis | Approval |

---

## Feature flags

| Key | Where | Default | Purpose |
|---|---|---|---|
| `MO_guest_day_pass_DT-21555` | DataTrak (club) | Off (prod: on for club 99921 only) | Guest-pass M&O fields and email |
| `datatrak-service-DT-21555-guest-pass-fields` | datatrak-service (club) | Off (prod: on for club 99921 only; created 2026-11-02, project `ignite-mo`) | Guest-pass fields on club defaults and `guestPassItems.spr` |
| `guest-pass-online` | LaunchDarkly (platform) | — | Guest-pass exposure in Online Join |
| `STP_CATALOG_SOURCE` | helm / BFF env | — | `datatrak` switches the catalog read to DataTrak |

---

## Known doc inconsistencies

- `SPRINT-0002.md` and `SPRINT-0004.md` still say "planned". The ledger says "done". The ledger is treated as current here.
- The Sprint 0005 doc header refers to PR #591 as a draft with 2026-10-07 test runs. Current state is in the table above.
