# Day Pass and Guest Pass — release notes

**As of:** 2026-11-02 · **Covers:** Sprints 0001–0005 · **Source of truth:** `docs/sprints/ledger.yaml`, checked against GitHub PR states on 2026-11-02

**Production status:** nothing from Sprints 0001–0005 has been released to production. Dev and mock environments only. Production push needs approval (requested with Paul Knuth on 2026-10-15).

---

## Summary

| Sprint | What it delivers | Merged to `main` | Status |
|---|---|---|---|
| 0001 | Day Pass single-flow checkout in Online Join | UI #524 (2026-09-17), BFF #96 (2026-09-17) | Done. Design parity and hosted Pay Page were transferred to Sprint 0002 |
| 0002 | Design v1.2 parity, consent, Pay Page embed, email OTP for every buyer, prospect-wallet save | **Not verified on `main`** (see below) | Marked done in ledger; evidence on `main` is missing |
| 0003 | Selectable 1/3/5-day passes, QR and receipt by email, login-free "View your pass" page | UI #525 (2026-09-17), BFF #99 (2026-09-17) | Done. Live email and hosted capture unverified |
| 0004 | Guest Pass v1: catalog-flagged single-visit passes from DataTrak, create → pay → deactivate, standalone Guest Pass host | UI #532 (2026-09-18), BFF #107 (2026-09-18), helm #3090 | Done in mock. Live DataTrak read not run |
| 0005 | Guest-pass fields through the DataTrak service layer, every production DB dependency behind a flag (default off) | datatrak #6643 and #6800 (2026-10-20). datatrak-service #591: open, ready for review. BFF #112 and #121: open | Implementation done; awaiting review; live read pending |

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

**Open (as of 2026-11-02):**
- datatrak-service #591: out of draft, head `086ec67`. CI, Endor and Sonar green. Reviewers requested: mithrandr, bgfaulk. No reviews yet.
  - Circuit review of the previous head (`943c368`) raised two issues: the flag-off path ran a database query before the flag check, and a failed VPD lookup returned a 500. Both are fixed in `086ec67`, with tests.
  - Circuit has not re-reviewed `086ec67` yet.
- online-join-bff #112: head `bc79e91`, rebased onto `main` on 2026-11-02 with main's dependency bumps kept (version 1.3.0). CI, Endor, Sonar and the flag scan green. Reviewers requested: rlankit, deepthi-rachumallu, djaynarayan, paulobrien109. No reviews yet. Circuit rated it Medium risk.
- online-join-bff #121: lint fix for `main` (one `import/order` error from #120). Head `d1c2ed2` (includes the repo's automatic version bump to 1.2.18). Sonar and flag scan green; CI / Build and Endor were still running at last check. Reviewers requested: the same four as #112. No reviews yet.

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
| Review and merge #112, #121 | Reviewers above | Review. Review requests posted as PR comments on 2026-11-02 |
| Review and merge #591 | mithrandr, bgfaulk | Review. Circuit re-review of `086ec67` not yet seen |
| Sprint 0002 verification on `main` | Sprint 0002 owner | See gap above |
| Production release | Bjorn Loftis | Approval |

---

## Feature flags

| Key | Where | Default | Purpose |
|---|---|---|---|
| `MO_guest_day_pass_DT-21555` | DataTrak (club) | Off | Guest-pass M&O fields and email |
| `datatrak-service-DT-21555-guest-pass-fields` | datatrak-service (club) | Off | Guest-pass fields on club defaults and `guestPassItems.spr` |
| `guest-pass-online` | LaunchDarkly (platform) | — | Guest-pass exposure in Online Join |
| `STP_CATALOG_SOURCE` | helm / BFF env | — | `datatrak` switches the catalog read to DataTrak |

---

## Known doc inconsistencies

- `SPRINT-0002.md` and `SPRINT-0004.md` still say "planned". The ledger says "done". The ledger is treated as current here.
- The Sprint 0005 doc header refers to PR #591 as a draft with 2026-10-07 test runs. Current state is in the table above.
