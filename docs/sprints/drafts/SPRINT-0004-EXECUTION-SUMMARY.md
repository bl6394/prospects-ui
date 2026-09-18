# Sprint 0004 — execution summary (orchestrator view), 2026-09-18

Executor: Claude Fable 5.1 — Phase A single session, then the BFF and UI lanes and Phases D/E in a resumed executor session. Planning repo commits `076bfbd … 3c91fd2` (Phase A/D) plus the E5 docs commit; code on `prospect-wallet/sprint-0004` in both online-join repos. Lane files: `SPRINT-0004-EXECUTION-SUMMARY-{BFF,UI}.md`, `SPRINT-0004-BLOCKERS{,-BFF,-UI}.md`, `SPRINT-0004-PR-DESCRIPTIONS.md`.

## The four verdicts (never merged)

1. **Implementation and mock acceptance — done.** Rounds 5–7 changes complete: single-visit catalog checkout (Riverside one item, Core three), begin-on-purchase validity with "use by", create → pay → deactivate / revert, RECONCILING + compensate, consent and opt-in evidence, no QR / pass page / age gate, OTP 5 min / 2 sends, standalone-host routing — proven with mock adapters locally (both suites green, demo 0–6 58 / 58, browser smoke 71 / 71) and, for the deployed **v3** build only, in dev with the pinned code (E3).
2. **Standalone dev host — pending** helm-configs #3090 (open; the executor does not merge it). Local proof on `guestpass.localhost` incl. a saved-card checkout; no hosted-card checkout on the host yet.
3. **Live integration — blocked / mock only / unverified.** DataTrak catalog read blocked (CF-13 fields absent, CF-14 member-scoped; the E4 boot failed closed and the dev host did not resolve from the executor's network); prospect create / repaint / deactivate mock only (platform port `notEnabled`, CF-15); hosted capture unverified locally (B1) and not run in dev; QR email and access enforcement are DataTrak's.
4. **Pilot — not eligible** until V-P0…V-P6 pass (`docs/validation/guest-pass-pilot-gates.md`).

## What shipped

| Repo | Head | PR | Commits |
|---|---|---|---|
| online-join-bff | `c6d4136` (version 1.2.4 — the CI bump job chose a patch, `9731717`) | https://github.com/abcfinancial/online-join-bff/pull/107 | A3/A4 `9bad883`; B0 `61b32cf`; B1 `c57d95a`; B2 `a9a9d37`; B3 `7f0c721`; B4 `5e9f07e`; B9/B10 `cec29f3`; B11 `938acb5`; B12 `0f7d323`; B13 `0589049`; CI bump `9731717`; Sonar fixes `9b8ed8c`, `c6d4136` |
| online-join-ui | `3435039` (version `8.34.0-daypass.1` — the CI bump job finalised the line to `8.33.0` in `80495fb`; `e62a67c` restored the daypass prerelease line as #525 did) | https://github.com/abcfinancial/online-join-ui/pull/532 | A3/A4 `38777e9`; C0 `5b6e541`; C1 `2aa81d0`; C2 `d909696`; C3 `54332b2`; C4 `d54ae0a`; C5 `42cedfe`; C6 `8792f95`; C7 `62ac29a`; C8 `0c920fa` (fix); C9 `72279b8`; E2 fix `4d5a8e8`; CI bump `80495fb`; version `e62a67c`; Sonar fixes `3435039` |
| helm-configs | — | https://github.com/abcfinancial2/helm-configs/pull/3090 (open, signed, not merged) | D1 |
| prospects-ui (this repo) | E5 docs commit | not pushed (per instruction) | Phase A `076bfbd`, D4 `8fadce3`, D1/D2 `de0dc17`, traceability draft `9011e74`, smoke §dev `3c91fd2`, E5 docs |

## Proof (E1–E4)

| Check | Result |
|---|---|
| BFF jest | 68 / 68 suites, 698 passed, 2 skipped; coverage 97.42 / 85.98 / 97.13 / 98.26 (floors 84 / 67 / 67 / 84); eslint clean; `tsc` clean (src + scripts) |
| UI jest | 111 / 112 suites, 775 / 776 tests; `transformers.test.ts` baseline; coverage 95.75 % lines / statements (floor 80 / 80); `npm run lint` 0 errors; `npm run build` ok; `tsc` baseline unchanged |
| Demo 0–6 | 58 / 58 (`docs/demos/short-term-pass-local-demo.md`) |
| E2 local browser smoke | **71 / 71** — nine flows (`docs/validation/short-term-pass-sprint-0004-smoke.md` §local, `screenshots/sprint-0004/`); found and fixed one UI overflow defect |
| E3 dev smoke | recorded 2026-09-18 against the deployed v3 build with the pinned code (pass for v3; v4 assertions pending the v4 deploy; standalone host pending #3090; hosted capture unverified) |
| E4 live DataTrak read | blocked; one `STP_CATALOG_SOURCE=datatrak` boot failed closed (404), dev host unresolvable from the executor's network |
| Sonar gates | first scan **failed on both PRs**: BFF 13 new issues (S5852 slow regexes ×5, S3776, S3516, S7735, S3358 ×2, S4624 ×6, S6582, S4323, S1313), UI 3 (S5852, S7764, S6772) — all fixed behaviour-unchanged in `9b8ed8c` / `c6d4136` (BFF) and `3435039` (UI); Build, Endor Labs and the LaunchDarkly flag diff passed on the first heads; **re-scan result to be read by the orchestrator** (`gh pr checks 532` / `gh pr checks 107`; findings arrive as check-run annotations) before closing V6 |

## Gates V0–V8

V0 passed · V1 passed (mock) · V2 passed with approved deltas (DESIGN observer not consulted) · V3 passed (mock; PK observer not consulted) · V4 passed · V5 passed (mock; LEGAL observer not consulted) · V6 passed except Sonar (first scan failed, findings fixed, re-scan to be read) · V7 each item its own verdict (routing local-proven; helm pending; E3 v3 pass / v4 pending; LD flag pending; adapter pinned; live read blocked) · V8 passed. Detail: `docs/validation/short-term-pass-sprint-0004-traceability.md` §Use cases → gates.

## Defects found during proof (both fixed in the UI PR)

1. `contractVersion` restart never re-bootstrapped on a first-load mismatch; the toggling `busy` flag re-bootstrapped over the pending error (found by `ShortTermPassPage.test.tsx`, fixed `0c920fa`).
2. The v6 "Valid" sentence in the sidebar (`.srow .v`, nowrap) widened the page to 460 px at 375 px (found by E2, fixed `4d5a8e8`).

## D3 handoffs (no ticket ids — the executor has no ticketing tool; text ready to paste)

- **PLATFORM — LaunchDarkly:** create flag `guest-pass-online` (club kind, default off; serialised to the UI as `guest_pass_online`) in dev and prod; the never-created `oj-short-term-pass-checkout` is retired; until then `STP_LOCAL_FLAG_OVERRIDE=true` stands in on dev only.
- **PLATFORM — secret `platform-online-join-bff`:** add `STP_DATATRAK_SERVICE_URL` and `STP_DATATRAK_SERVICE_AUTH` (the static Basic credential MICO uses for the DataTrak service layer) once CF-13 / CF-14 are answered by Chancy's DT PR; until then `STP_CATALOG_SOURCE=fixture`.
- **PK — prod host and Cloudflare:** DNS / TLS for the production Guest Pass host, rate limiting and bot rules "as on OJ" (V-P3, RQ-5); the BFF's own limiter is 10 purchases / IP / hour.
- **Chancy / Mark:** CF-13 (guest-pass fields on the sale item and club default), CF-14 (member-less `saleItems.spr` or a dedicated call), CF-15 (`addProspect` begin / expiration / visits / item / opt-in names, idempotency, deactivate), RQ-0 (DT prospect email timing — V-P0), CR-34 (OTP HTML template for the slot).
- **Kelly + Legal:** CF-08 (waiver with no age gate; fallback text still says "18 or older"), CF-09 (opt-in modal / Twilio), CF-16 (refund sentence).
- **PAYMENTS:** B1 Pay Page credentials for a local hosted-capture run.

## How to resume

1. Read the Sonar re-scan on #532 and #107 (the first scan's findings were fixed and pushed); if anything remains, pull first — the bump job pushes version commits to the branch.
2. Merge order does not matter (v1.2.3 ignores the new keys; v4 ignores the old ones). After the BFF merge and the dev deploy: re-run E3 for v4 (five documents, `contractVersion`, `useBy`, `pass.beginDate`, no `viewPath`, `guest_pass_online` hint), and — after #3090 deploys — the standalone host (`docs/deploy/dev.md` §D2) with a hosted-card checkout.
3. Close SPRINT-0004 in `docs/sprints/ledger.yaml` only then; keep the four verdicts separate.
4. Baseline failures stay listed by name; never lower a floor.
