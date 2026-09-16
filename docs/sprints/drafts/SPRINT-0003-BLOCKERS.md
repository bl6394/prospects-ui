# Sprint 0003 — blockers, deviations and notes from execution (Phase A)

Executor: Claude Fable 5.1, 2026-09-16 (Phase A, single session). Branches `prospect-wallet/sprint-0003` in `repos/online-join-ui` and `repos/online-join-bff`, created off the `prospect-wallet/sprint-0001` heads and **not pushed** (the orchestrator pushes after review). Planning-repo deliverables (contract v3, this file, the two parity JSON files, the Phase A execution summary) are left uncommitted in the working tree. `docs/sprints/ledger.yaml` is not touched by the executor.

## Baseline

| Item | Value |
|---|---|
| `online-join-ui` head at branch creation | `151846d` (`chore: publish prerelease builds under the npm dist-tag 'daypass'`), was on `prospect-wallet/sprint-0001`, clean |
| `online-join-bff` head at branch creation | `53e549e` (`feat: STP_NON_PRODUCTION lets dev/qa clusters run the Day Pass mock adapters; prerelease 1.2.0-daypass.1`), was on `prospect-wallet/sprint-0001`, clean |
| New branch (both clones) | `prospect-wallet/sprint-0003`, stacked on `prospect-wallet/sprint-0001`; not pushed |
| Prerelease versions / dist-tags | untouched: UI `8.33.0-daypass.1`, BFF `1.2.0-daypass.1`, npm dist-tag `daypass` (RQ-8: bump only when the user asks) |
| Node / npm | Node v26.3.0 (BFF engine `>=22`), npm 11.16.0, registry `https://registry.npmjs.org/` |
| `node_modules` | present in both clones; no `npm install` needed for the baseline |
| BFF `npx tsc --noEmit` | clean (exit 0) |
| UI `npx tsc --noEmit -p tsconfig.json` | **8 pre-existing errors**, none under `routes/ShortTermPass`, `interfaces/api`, `reducers/shortTermPass` or `__tests__/routes/ShortTermPass` (unchanged from the Sprint 0002 summary "8 pre-existing errors") — see list below |
| UI pre-existing test baseline | `__tests__/helpers/transformers.test.ts` › "transformAgreement builds the agreement payload using today payment info" **fails on this machine's timezone** (expects month text "June" for value `06`, receives "May"); 7 of 8 in the suite pass. Confirmed by running the suite alone on 2026-09-16. Accepted exception, never counted as green (T6). |
| Mailpit | running (`stp-mailpit`, Docker, up 5 days, healthy): SMTP `localhost:2525` open, API `http://localhost:8025/api/v1/info` answers v1.31.1 |
| Husky | BFF `.husky/pre-commit` → `npm run pre-commit` (lint-staged: prettier + eslint --fix on staged `*.ts`); UI has no working pre-commit hook (husky v4-style config under husky 8, pre-existing) |

UI pre-existing `tsc` errors (file:line → code):

```
__tests__/hooks/usePayPageSession.test.tsx(316,9): TS6133
__tests__/routes/PaymentPage/PayPageEmbed.test.tsx(119,5): TS2454
src/routes/PaymentPage/PaymentPage.tsx(290,43): TS2532
src/routes/PaymentPage/PaymentPage.tsx(290,67): TS2339
src/routes/PaymentPage/PaymentPage.tsx(294,8): TS2322
src/routes/PaymentPage/PaymentPageWithPayPage.tsx(1,8): TS6133
src/routes/PaymentPage/PaymentPageWithPayPage.tsx(386,22): TS2769
src/routes/PaymentPage/PaymentPageWithPayPage.tsx(457,20): TS2769
```

## Blockers

### PA-1 — `/signup/pass/<token>` is 404'd by the history-fallback dot rule (found at A4; fix specified, not applied — B5 owns the file)

`koa2-connect-history-api-fallback@0.1.3` (`src/utils/middlewares/historyFallback.ts`) refuses to rewrite any path whose pathname contains a `.` unless `disableDotRule` is set. The plan's token `pv1.<id>.<exp>.<sig>` contains three dots, so `GET /signup/pass/pv1.…` with `Accept: text/html` falls through to the routers and answers 404 instead of the SPA entry document — the "View your pass" page (C5 / U20) can never load, whatever `App.tsx` does. Proved by calling the library with the production options (see contract §8a(c)); API and image requests are unaffected. **Fix for B5:** `rewrites: [{ from: /^\/signup\/pass\/pv1\.[A-Za-z0-9_.-]+$/, to: '/' }]` (rewrites run before the dot rule; probe green for the token path with and without a query, `/signup/pass?club=` unchanged, `/signup/main.abc123.js` still not rewritten). Do not set `disableDotRule` globally. Add a route-level test (`historyFallback` + `getIndex` for the token path). C5 must not assume the page is reachable until B5 lands this. **Effect if unfixed:** T3 and U20 fail; email links dead-end on a 404 page.

### PA-2 — Dev ingress mount path for `STP_PUBLIC_BASE_URL` not verifiable locally (PLATFORM)

The BFF serves the SPA at `/` and the UI's `BrowserRouter` basename is `/signup`, so `STP_PUBLIC_BASE_URL` is the **origin only** and the BFF appends `/signup/pass/<token>` and `/api/short-term-pass/passes/<token>/qr.png` (contract §2, §8a(c)). Whether the dev deployment mounts the BFF under a prefix could not be checked from the cache (no ingress config; the dev hostname is known only from the Sprint 0002 notes). Not blocking the build; blocks the first live email link. Owner: PLATFORM at kickoff.

No other blockers. Mailpit was up (no Docker action needed); the npm registry served `qrcode`, `jsqr`, `pngjs`; Pay Page credentials (B1) remain absent, unchanged and out of Phase A scope.

## Feasibility (A4)

Time-box respected (about half a day). Full findings in `docs/contracts/short-term-pass-bff.md` §8a; summary:

| Check | Result | Evidence |
|---|---|---|
| Node QR render + independent decode | **passes** — `qrcode@1.5.4` PNG (M, margin 1, scale 6) decodes byte-for-byte with `jsqr@1.4.0`; blank PNG decodes to nothing; version ≤ 6 for the STP2 payload class | `src/services/shortTermPass/__tests__/qrFeasibility.test.ts` (BFF `a3cdbfc`) |
| nodemailer CID MIME shape in Mailpit | **passes** — `multipart/alternative` → `multipart/related` → `image/png` with `Content-ID: <pass-qr>`, `Content-Disposition: inline`; Mailpit exposes it under `Inline[]` (not `Attachments[]`) with a `PartID`; the part bytes equal the sent buffer | one-off script against `smtp://localhost:2525` / `http://localhost:8025` (Mailpit v1.31.1 up, `stp-mailpit` Docker container healthy); message left in the inbox (subject `A4 CID feasibility <ts>`) |
| `STP_PUBLIC_BASE_URL` + `/signup` basename through the history fallback | **blocker found (PA-1) with a specified fix**; base URL = origin only | probe of `koa2-connect-history-api-fallback` with the production options |
| Club-local next-day + 24 h helper | **done (A3)** — `validity.ts` `linkExpiresAtOf`; DST, month/year/leap day, TZ-independence tested | `validity.test.ts` |
| Where request paths are logged | two sites: `@abc/bff-toolkit@11.29.1` `loggerMiddleware()` (`→ IN {url}` / `← IN {originalUrl} -> status`, `endpointUri`) and the `historyFallback.ts` debug logger (`Rewriting GET … to /` when `LOG_LEVEL=debug`); the fallback logger was shown to carry the raw token; redaction design (winston format on `loggerService` + regex in the fallback logger) handed to B5 | contract §8a(d) |
| Publisher attachment capability | **not assumed** — `EmailEngineRequest` has no attachment slot; publisher path uses the hosted `qr.png` URL; no live call attempted (503 on 2026-09-10) | `adapters/publisher/emailPublisher.ts` |
| `.env.example` | three rows added: `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS=24` (commented, like every other `STP_*` row) | BFF `a3cdbfc` |

## Phase A notes

- **Contract v3 landed as types + schemas only (A2).** `buildCheckoutResponse` answers `offers[]`, `selectedOfferId` (= the order's offer once an order exists, else `offers[0]`; B1 inserts `CheckoutRecord.selectedOfferId` between the two) and the compatibility `offer`; `toOrderSummary` derives `durationDays`, `label`, `validUntil` (B2 stores `validUntil` on the order and recomputes it on date edits). `PurchaseResult.pass.{label,validUntil,viewPath}` and `receipt` are optional in the type so no orchestrator change was needed for `tsc`. UI: interfaces mirrored; the slice still reads `checkout.offer` (C1 migrates to `offers`/`offerId`).
- **Decisions the plan left open, taken at A2 (lanes: do not re-decide):** (1) `OrderSummary.validUntil` is optional alongside `visitDate` (present whenever `visitDate` is); `durationDays` and `label` are required. (2) `POST …/pass-link` answers `{viewPath, linkExpiresAt, delivery}` (superset of the plan's `{viewPath, delivery}`) so the done page can show the lifetime without a second call. (3) A stored selection that left the catalog is a 409 `STATE_CONFLICT` with `details.reason:'OFFER_UNAVAILABLE'`, `details.offers` and `details.selectedOfferId`; a foreign/unknown `offerId` on `PUT /offer` is 400 `VALIDATION_FAILED` (plan U4). (4) `OFFER_ID_PATTERN = ^[a-z0-9][a-z0-9-]{1,63}$` on the offer body (fixture ids are lower-case slugs). (5) The `pv1` token shape check is exported from `schemas.ts` as `PASS_TOKEN_PATTERN` + `isPassTokenShape()` (a path-param predicate, not an ajv body schema). (6) `PurchaseReceiptSummary` (browser) = `{receiptNumber, item, label, amountMinor, currency, visitDate, validUntil, purchasedAt}`; the fuller `PurchaseRecord.receipt` (seller, paidWith, firstName, offerId) is documented in contract §5 and typed by B4. (7) `PassView.club.links` carries `app` only. (8) `validityLabel(visitDate, validUntil, todayIso?)` says "Today" only when `todayIso` is passed — durable surfaces omit it.
- **`validity.ts` is dependency-free on purpose** so it can be `require`d by plain Node in the TZ-independence test (Node ≥ 22.6 strips types; the file has only type imports and `erasableSyntaxOnly`-safe syntax). It duplicates the zoned-date logic of `order.ts` `clubLocalToday` rather than importing it; B2 may point `clubLocalToday` at `zonedDateOf`.
- **Fixture rename:** `JORDAN_CORE_TWIN` → `KELLY_CORE` (`fixtures/directory.ts`); the mock wallet seed and its card holder name follow; UUID unchanged so wallet-owner tests keep their keys. `identityDirectory.test.ts` pins that no Jordan remains at 90033.
- **Pass Terms `2026-09.2`** changed the version pinned by `purchase.test.ts` (4 places) and the demo script's consent-summary check (`scripts/short-term-pass-demo.ts:326`); both updated. The 1-day Core sentence is byte-identical to the v1.2 wording, so existing 1-day assertions still hold.
- **Tests added/updated for every A3 item:** `catalog.test.ts` (three offers, provisional list in the capability note, 3-day Pass Terms sentence + hash/revision difference), `identityDirectory.test.ts` (Kelly), `consentTemplates.test.ts` (template version, v4 sentences for 1/3/5-day, hash/revision behaviour, static-override commercial binding), NEW `validity.test.ts` (54 cases), UI NEW `shortTermPassTestData.test.ts` (factories pinned to the BFF fixture ids/amounts/labels, key-set discipline for `PassView`).
- **Contract §7 was updated at A2/A3** (Kelly row, Core offers, `STP2` payload) although the task list names §7 for E5 — leaving it stale while the fixtures changed would have misled the lanes. E5 still owns the final register.
- **Approved-delta numbering.** The plan numbers the new placeholders AD-10…AD-12, but `approved-deltas.json` already carried AD-10 (v1.2 tab-row width at 375 px, Sprint 0002 C8a). Ids must stay unique for the runner, so AD-10 is kept and re-cited against v4 (lines 72/75) and the new placeholders are **AD-11** (single-offer grid), **AD-12** (View link + Resend), **AD-13** (truthful delivery variants). Recorded as a Phase A note in `SPRINT-0003.md`; U3, U12 and D1 should read AD-11…AD-13.
- **A5 skeleton:** `elements.json` v2 — prototype `docs/prd/day-passv4.html` sha256 `c0a5fd8d3f511705145687037a3cc7a02a3163ad75d902a4282eefc391316616`, 13 states (`identify-offer-3day`, `identify-offer-5day` inserted after `identify`), `done.qr` element and `qr-modules` mask removed, `side.day.label` re-pointed at `.dayfield .dt-label`, 14 v4 selector pairs added with `stub:true` (radiogroup, `.days`, per-card ids `#offer-d1/d3/d5` ↔ `#offer-day-pass-gym-floor{,-3,-5}`, `.lead`, done/receipt View rows), `build.recognizedFirstName: 'Kelly'`; every state has at least one element. `approved-deltas.json` v2 — AD-01…AD-10 re-cited to v4 lines, AD-11…AD-13 `placeholder:true`. `git diff tools/` shows only the two JSON files. Nothing was run.
- **`npm install` warnings** about `unrs-resolver` install scripts (`allow-scripts`) are npm 11 policy noise for an existing transitive dependency; nothing was approved or run.
- **Husky** ran on every BFF commit (prettier + eslint --fix via lint-staged); it reformatted nothing beyond the staged files. The UI has no working hook (pre-existing).

## Scope changes

- Added dev dependencies `pngjs` + `@types/pngjs` to the BFF (not in the plan's list): `jsqr` decodes raw RGBA, so a PNG decoder is required to prove the round-trip on the PNG bytes rather than on a re-encoded matrix.
- The ledger (`docs/sprints/ledger.yaml`) and the push of both branches, listed under A1 in the plan, are left to the orchestrator as instructed; A1's "branches pushed; ledger shows 0003 in-progress" is therefore **not** claimed here.
