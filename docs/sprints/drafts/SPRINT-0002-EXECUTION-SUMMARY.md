# Sprint 0002 — execution summary (orchestrator)

**Sprint:** Day Pass review changes (`docs/sprints/SPRINT-0002.md`). **Date:** 2026-09-10.
**Executors:** Claude Fable 5.1 — one detached session for Phase A, then (user decision 19:05 UTC) two parallel detached lanes: BFF (Phase B, P1-3, P1-4, E4) and UI (Phase C, P1-1/2/3/4/5/6, listed P2s, E4). Lane reports: `SPRINT-0002-EXECUTION-SUMMARY-{BFF,UI}.md`, notes `SPRINT-0002-BLOCKERS{,-BFF,-UI}.md`.
**Branches:** `prospect-wallet/sprint-0001` in both repos (interview decision: PRs absorb). Pushed 2026-09-10 20:09 UTC — UI `a3c61b6..41d7444` (PR #524), BFF `db81011..fc77007` (PR #96).
**Deferred by the user:** the harness lane (Phase D) and the parity and agent runs (E1, E2). Not started; `tools/day-pass-harness/` holds the first executor's untouched scaffolding.
**Completion vocabulary for this run:** *review changes complete; parity and agents deferred; hosted capture unverified (B1)*.

## 1. Commits

| Repo | Hash | Content |
|---|---|---|
| online-join-ui | `eafada1` | Phase A: self-hosted Inter (OFL, from `@fontsource/inter` files) replaces the Google Fonts import |
| online-join-ui | `29ebc96` | Phase C: v2 slice/service/selectors; identify with offer card and inline code; sidebar consent block + Pay; document dialog; recognized / new visitor / done per v1.2; `PayPageEmbed` `onReady`; `CheckoutController`; `TestCardPanel`; `SaveCardSwitch` default off; P1-1…P1-5, P2s; `VerifyStep`, `PayBar`, `TermsDialog`, `SaveCardToggle`, `MockCardCapture` deleted |
| online-join-ui | `fa1878c` | Phase C: v1.2 shell, tabs, stylesheet; P1-6 `minmax(0,1fr)` grid |
| online-join-ui | `41d7444` | Reconciliation with BFF D-4 (bare 409 after three lookup retries ends Retry) |
| online-join-bff | `289220e` | Phase A: §4.5 consent templates (PRD refund copy), disposable-domain list, Core `m@m.com` twin, consent types on the catalog port |
| online-join-bff | `34b5493` | Phase B: OTP for every email, lookup after consumption, §5A.1 limits + address lock, P1-3 (401 on missing cookie), P1-4 (generation), demo reads codes from the outbox, `debug.code` removed |
| online-join-bff | `7ecdf58` | Phase B: consent set on every response, `order.consents`, waiver hash check, consent-events route, save-card default off |
| online-join-bff | `9ad75d8` | Phase B: Pay-tap attestation checked before authorization, one consent snapshot per purchase, mobile required |
| online-join-bff | `531f4f4` | Phase B: capture defaults `paypage`; mock capture and testing routes only behind `STP_TEST_HOOKS`; boot guard; test clock |
| online-join-bff | `fc77007` | Phase B: UUID `walletProvidedId`, `oj_*` consent metadata, read-back on response loss |

## 2. Quality (E4, per lane)

| Repo | Lint | Build | Tests | Coverage (stmts / branches / funcs / lines) | Floors |
|---|---|---|---|---|---|
| online-join-bff | 0 errors | ok | 60 suites / 549 passed / 2 pre-existing skips | 97.39 / 85.11 / 95.74 / 98.08 | 84 / 67 / 67 / 84 |
| online-join-ui | 0 errors (756 pre-existing warnings) | ok (3 pre-existing size warnings) | 103 suites / 644 of 645 (1 pre-existing timezone baseline in `transformers.test.ts`) | 93.09 / 84.56 / 87.5 / 93.09 | 80 / 80 lines / statements |

No threshold lowered, no exclusion added. BFF demo `npm run demo:short-term-pass` 66/66; `--hosted` BLOCKED (B1). UI `tsc --noEmit`: 8 pre-existing errors (down from 11), none new.

## 3. Orchestrator browser smoke (2026-09-10 20:06 UTC)

Both dev servers restarted on the new code (UI dev server :3001 proxied by the BFF on :3000 with `STP_ADAPTER_MODE=mock STP_CAPTURE_MODE=mock STP_TEST_HOOKS=true`). Headless Chrome via `puppeteer-core`, fresh browser context per flow, codes read from the hooks-only outbox route, fixture cards only. Script and results in `docs/validation/short-term-pass-sprint-0002-smoke.md`; screenshots in `docs/validation/screenshots/sprint-0002/`.

| Flow | Width | Result |
|---|---|---|
| Returning (Jordan, saved Visa 4242) | 1440 and 375 | purchase COMPLETE, payment captured, wallet `saved` (existing), URL → `/signup/pass` |
| First-time, save off | 1440 | COMPLETE, person created, wallet `not-requested`, 0 entries |
| First-time, save on | 375 | COMPLETE, person created, wallet `saved`, 1 entry with UUID `providedId` |
| Duplicate-mobile attempt (script error, kept as evidence) | 375 | FAILED at `persist-person` "Someone with this contact already exists", payment voided, no receipt shown (P1-1 fix confirmed) |
| P1-6 overflow at 320 / 360 / 375 / 393 / 440 px on identify, code entry, new visitor | — | `scrollWidth == innerWidth` everywhere |
| Third-party font requests | — | none (Inter self-hosted) |

## 4. Gates

| Gate | Verdict | Evidence |
|---|---|---|
| S0 Ready | met | contract v2 frozen (`docs/contracts/short-term-pass-bff.md` §4/§4a); both repos type-check against it; husky active in the BFF clone; ledger updated |
| S1 Traceability | met | `docs/validation/short-term-pass-sprint-0002-traceability.md` |
| S2 Parity terminated | **not started** (deferred by the user) | v1.2 copy pinned string-for-string in UI tests; orchestrator screenshots reviewed by eye against v1.2 at 1440/375 — no visible layout deviation beyond the approved-delta list |
| S3 Consent recorded | met | BFF `order.test.ts`, `purchase.test.ts`, `consentEvents.test.ts`; smoke state shows the snapshot on each COMPLETE purchase; PROPOSED marker in fixture/config/capability report only |
| S4 OTP for everyone | met | `identify.test.ts`, `verify.test.ts`, `challenge.test.ts` (identical key sets known/unknown, no directory call before verify, hourly limits, address lock); demo run 0 |
| S5 Pay Page only | **pending (B1)** | `captureMode` defaults `paypage`; mock capture unreachable without hooks (router-stack test); `TestCardPanel` only with hooks; `onReady` readiness with regression test; no hosted run (credentials absent) |
| S6 Prospect-wallet save | met (mock) | `walletWrites.test.ts`, `platformWallet.test.ts`; smoke first-save-on created 1 entry with a UUID `providedId`; enablement checklist in contract §10 |
| S7 Simulated users | **not started** (deferred) | — |
| S8 Quality | met | §2 |
| S9 Docs and status | met | contract §10 rows, validation docs, traceability, `docs/SEMANTIC-INDEX.md`, ledger, PR descriptions updated |

## 5. Left for the user or a later run

1. **B1 — Pay Page dev credentials** (six keys in `repos/online-join-bff/.env`) → run `npm run demo:short-term-pass -- --hosted` and the first-time hosted browser lane; closes S5.
2. **Harness lane** (Phase D, E1, E2) when the user says so; `tools/day-pass-harness/` scaffolding present; the smoke script in the session scratchpad is a starting point for the browser driver.
3. **Contract questions from the UI lane** (Q-1…Q-9 in `SPRINT-0002-BLOCKERS-UI.md`): Q-2 is the one open behaviour — the BFF ignores `profile` for a recognized checkout, so a recognized person with no mobile on file is not persisted with the mobile they type (fixture persons all have one; readiness item D37-recognized). Q-1 brand casing: Riverside renders correctly; Core would read "CORE's Pass Terms" until a `brand.sentence` field exists (parity delta on one state). Q-4, Q-5, Q-6, Q-9 verified in BFF code; Q-3 partially (BFF validation copy is customer-facing for name/mobile).
4. **UI repo hygiene** (pre-existing): `husky` v4-style config under husky 8 means no UI pre-commit hook runs; `lint-staged` names `stylelint` with no config.
5. **Open P2 items** listed in `SPRINT-0002-BLOCKERS-UI.md` (A6-05…A6-10, A3-05, A5-02/03/05).
6. **Register rows without owners**: CF-01, CF-02, CF-03, consent ledger platform adapter, D24 waiver reuse, recognized marketing preference, email transport.
7. The 60 MB QA evidence from the parallel session (`docs/validation/qa/**`, `docs/validation/screenshots/sprint-0001/mobile/**`) is not committed by the orchestrator.

## 6. Addendum 2026-09-10 — fake email service (PR-03 SMTP lane, built on request)

The user asked to receive the OTP as email to keep testing manually, so the SMTP lane that the merge had deferred was built by the orchestrator: BFF commit on `prospect-wallet/sprint-0001` (pushed) adds `adapters/smtp/mailer.ts` (`SmtpMailer` wrapping `MockOutbox`, nodemailer), `STP_EMAIL_TRANSPORT|STP_SMTP_URL|STP_EMAIL_FROM` in config/env/boot guard (mock mode only, refused in production), tests (`smtpMailer.test.ts`, config and adapter tests). Full BFF suite after the change: 61 suites / 558 tests, coverage 97.37 / 85.27 / 95.81 / 98.04. Mailpit runs in Docker (`stp-mailpit`, SMTP :2525, inbox http://localhost:8025). Smoke rerun with SMTP on: 4 purchases COMPLETE, 13 emails delivered. Register row "email transport" updated. The OTP service itself (issue, verify, limits) was already in place from Sprint 0001/0002; this adds human-readable delivery.

**Email template (later on 2026-09-10):** the user supplied `docs/prd/email-1-verification-code.html`; the code email now renders that template (BFF `adapters/smtp/templates/verificationCode.ts`; catalog gained `address` and `links.passTerms|privacy`; the challenge service passes the club mail context and the real TTL). Verified live against Mailpit for Core South (subject "Your Core Health and Fitness Club code: 881054", footer address and links present); screenshots `email-1-design.png` vs `email-1-delivered.png`. Delta recorded: expiry copy says 10 minutes (service TTL), not the mock-up's 5. Full suite 61 / 559 green.

**Publisher transport (later on 2026-09-10, user request):** `STP_EMAIL_TRANSPORT=publisher` — `adapters/publisher/emailPublisher.ts` posts the designed code email and the pass email to email-publisher-service with `route: "AMZ"` (aws-email-engine), per-club billing code, verified sender, static Authorization header; "Sent" = queued; failures fail closed. Mock and platform mode wiring; config/env/boot guard; 12 new tests; full suite 62 / 569 green, coverage 97.28 / 85.79 / 95.94 / 98.00. BFF commit `00fc940` pushed (PR #96). **Live send blocked:** the dev publisher ingress returns 503 N503 to everything; recorded in the demo doc and the register. Local `.env` runs `smtp` until it answers.
