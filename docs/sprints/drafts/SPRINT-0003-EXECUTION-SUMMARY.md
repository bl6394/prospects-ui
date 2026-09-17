# Sprint 0003 — execution summary (orchestrator)

**Sprint:** Design v4 — selectable 1/3/5-day passes, QR and receipt by email, login-free "View your pass" (`docs/sprints/SPRINT-0003.md`). **Dates:** planned 2026-09-15 (three drafts, three critiques, interview, merge), executed 2026-09-16.
**Executors:** Claude Fable 5.1 — Phase A in one detached session, then two parallel detached lanes (BFF B1–B7 + E1; UI C1–C8 + E1); D1, D2, E2, E5 by the orchestrator. Lane reports: `SPRINT-0003-EXECUTION-SUMMARY-{A,BFF,UI}.md`, blockers `SPRINT-0003-BLOCKERS{,-BFF,-UI}.md`.
**Branches (interview):** `prospect-wallet/sprint-0003` in both repos off the `sprint-0001` heads, pushed; PRs **online-join-ui #525** and **online-join-bff #99**, stacked on `prospect-wallet/sprint-0001` (#524 / #96) — retarget to `main` when those merge. Prerelease versions and the `daypass` dist-tag untouched (RQ-8).
**Interview decisions applied:** CR-13 in full (link on done page, email and receipt; login-free page with static QR; owner-only rotate-and-resend); link grace 24 h view-only; harness lane still **deferred until the user says** (PR-05 re-baselined its inputs on v4 in place).
**Completion vocabulary (T0–T8 evidence recorded):** *v4 changes complete; pass email + link proven locally (Mailpit); static QR only, desk verification and rotation unverified; live email unverified (publisher 503); hosted capture unverified (B1); parity and agents deferred.* Gate owners sign at their convenience; the DESIGN review of the PROPOSED email and page (PC-1) is open.

## 1. Commits

| Repo | Hash | Content |
|---|---|---|
| online-join-bff | `5915c96` `0121512` `a3cdbfc` | A2 contract v3 types/schemas · A3 Core 1/3/5 offers, Kelly, Pass Terms 2026-09.2, `validity.ts` · A4 `qrcode` + decode round-trip, `.env.example` rows |
| online-join-bff | `77a5695` `0fc4365` `a3b3332` `295edde` | B1 offer selection (`PUT /offer`, `selectedOfferId`, `requireOffer` threaded, generation bumps) · B2 stored `validUntil`, offer-aware consent, midnight re-check · B3 range on sale/issue/`STP2` payload · B4 immutable receipt snapshot |
| online-join-bff | `0774fb8` `d829dde` `562b002` `a0cbb58` `6dfa0cd` | B5 credential store, `pv1` HMAC token, public `/passes/:token{,/qr.png}`, PA-1 rewrite, log redaction, AppDynamics skip · B6 pass email (CID / hosted PNG, billing code fix, `pending`) · B7 `GET`/`POST …/pass-link`, Demo 3 · reset clears link limiters · UI Q1 pin |
| online-join-ui | `d97afbe` `b6ae307` | A2 contract v3 mirror + factories · A3 factories pinned to BFF fixtures |
| online-join-ui | `44026f5` `72858ab` `37af94e` `ad1ef91` `d1ee1d7` `1f23204` `6243e8b` | C1 slice/services (`selectOffer`, `loadPassLink`, `resendPassEmail`, `getPassView`) · C2 `OfferCards` radiogroup · C3+C4 sidebar range, done page without QR, View/Resend · C5 `PassViewPage` routed ahead of `/pass` · C6 mobile helper removed · C8+C7 v4 styles and copy table · tidy |
| prospects-ui | `5c025e6` `f7f3507` `0b0dda4` `757ac5d` `0a9068c` `87619c4` + this commit | plan · Phase A artefacts (contract v3, parity v2) · D1 · lane docs · E5 |

## 2. Quality (E1, foreground, per lane)

| Repo | tsc | Lint | Tests | Coverage (stmts / branches / funcs / lines) | Floors | Other |
|---|---|---|---|---|---|---|
| online-join-bff | clean | 0 errors | 70 suites / 698 passed (2 pre-existing skips) | 97.22 / 86.76 / 96.44 / 98.12 | 84 / 67 / 67 / 84 | demo 88 / 88 incl. Demo 3; husky on every commit |
| online-join-ui | 8 pre-existing errors (PaymentPage only), none new | 0 errors / 760 warnings (baseline 756) | 109 suites / 734 tests: 733 passed + the pre-existing `transformers.test.ts` timezone baseline (accepted exception) | 92.90 / 85.65 / 88.46 / 92.90 | 80 / 80 | webpack build clean |

No threshold lowered, no exclusion added.

## 3. Orchestrator browser smoke (E2, 2026-09-16) and PR-06

`docs/validation/short-term-pass-sprint-0003-smoke.md`, screenshots `docs/validation/screenshots/sprint-0003/`. **240 / 240 checks**: Core Kelly 1-day @1440 (email + page + tamper + resend + revoke), Core Kelly 3-day future start @375 (Upcoming), Core new visitor 5-day save-off @1440, Core Kelly 3-day @375, Riverside Jordan 1-day @1440 (regression), overflow 320–440 px, two-tab stale selection (409 re-sync). Mailpit inline PNG decoded byte-for-byte to `pass.qrPayload` in three flows; the public page renders in fresh contexts without cookie or club query; identical 404s, `no-store` / `no-referrer` / `noindex` / `nosniff`; no raw token in `/testing/state`; no third-party font; no AppDynamics on the pass page. Screenshots reviewed by eye against v4 (offer grid, "Pass starts on" + range, done without QR, View link in block and Receipt).

## 4. Gates

| Gate | Verdict (evidence) | Notes |
|---|---|---|
| T0 Contract ready | met | v3 frozen A2; both repos type-check; fixtures + validity + feasibility; branches + ledger |
| T1 Multi-product checkout | met | U1–U10, U23 in jest + smoke; Riverside unchanged; provisional prices flagged |
| T2 v4 copy and layout | met (browser review) | every v4 string pinned; screenshots at 1440/375; single-offer collapse AD-11, variants AD-13; **DESIGN review of PROPOSED email/page open (PC-1)** |
| T3 Credential boundary | met | cookie-free after expiry (jest), identical 404s, headers, 429, key-set leak test, redaction, AppDynamics skip; static QR only |
| T4 Credential by email | met (local) | Mailpit CID decode ×3; publisher shape unit-pinned; **live send unverified (publisher 503)** |
| T5 Transaction/consent integrity | met | stale offer/date/attestation refused; one consent + one receipt snapshot; replay/resend/wallet-retry rules pinned |
| T6 Quality | met | §2; baseline failures listed by name |
| T7 Traceability and deferred inputs | met (inputs only) | `short-term-pass-sprint-0003-traceability.md`; parity v2 complete; **S2/S7 not run (user decision)** |
| T8 Docs and status | met | contract §10, demo doc, `docs/SEMANTIC-INDEX.md`, validation docs, design notes, ledger, PRs #525 / #99 |

Carried unchanged: Sprint 0002 S5 (hosted Pay Page, B1), S2/S7 (harness, deferred). Counsel action (e) reported satisfied by Sprint 0002's consent set.

## 5. Findings during execution

- **PA-1** (Phase A): the history fallback's dot rule 404'd the dotted token path; fixed in B5 with a rewrite rule and a real-library probe test.
- **Publisher billing code** was `00000-STP` for the pass email (`deliver` passed no club); fixed in B6.
- **Approved-delta ids**: AD-10 already existed, so the new deltas are AD-11…AD-13 (plan said AD-10…AD-12).
- **Smoke script assumptions** (not product defects): the smoke must press "Verify and continue"; the receipt-row selector; the shell's header icon is an `svg` in `main`; CDN + AppDynamics hosts load on checkout pages (not fonts); the masked email contains bullets; headless Chrome throttles background tabs (`--disable-renderer-backgrounding`).
- The UI lane's seven contract questions were all answered as confirmations by the BFF lane (no UI change needed); question 1 pinned by BFF `6dfa0cd`.

## 6. Left open (owners in contract §10)

CF-04 pricing and club → duration matrix (PM); CF-05 window semantics / Q19 (PM); CF-06 lifetime beyond 24 h, admit interval, anomalies (ENG+PM); CF-07 static vs link-only, desk verifier (PM/PASS); PC-1 designs (DESIGN); PA-2 dev ingress prefix for `STP_PUBLIC_BASE_URL` (PLATFORM); durable credential store + key rotation + staff revoke (PLATFORM); rotating QR (PRODUCT+SECURITY); sprint-wide mandatory `generation` (BFF); club sales flag vs issued-pass retrieval (PRODUCT+SECURITY); B1 hosted proof; live publisher; harness lane when the user says; RQ-8 prerelease bump; RQ-9 retarget PRs to `main` after #524 / #96.

## 6a. Post-execution merge (2026-09-16)

PR #96 (`prospect-wallet/sprint-0001`) received five Sonar commits (`be8aa9e`…`50a54c4`; quality gate failed → passed, 0 new issues / 0 hotspots) plus four fixes from another agent. Merged into `prospect-wallet/sprint-0003` as `65c1a8d` (ten conflicts; Sprint 0003 receipt snapshot, credential mint and v3 delivery re-homed into the Sonar step functions). Post-merge: tsc clean, lint 0, jest 71 / 709 passed, coverage 97.15 / 86.37 / 96.79 / 98.18, demo 88 / 88, browser smoke 240 / 240 on the rebuilt BFF. PR #99 description updated.

## 7. Local state after the run

BFF on :3000 built from `65c1a8d` (`node --env-file=.env dist/src/server`, `.env` now has `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS`), UI dev server on :3001, Mailpit up. Entry `http://localhost:3000/signup/day-pass?club=90033`.
