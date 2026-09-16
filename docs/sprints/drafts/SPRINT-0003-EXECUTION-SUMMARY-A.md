# Sprint 0003 — execution summary, Phase A (contract v3 freeze, fixtures, feasibility, parity skeleton)

**Sprint:** Design v4 (`docs/sprints/SPRINT-0003.md`). **Date:** 2026-09-16. **Executor:** Claude Fable 5.1, one session, tasks A1–A5 in order.
**Branches:** `prospect-wallet/sprint-0003` in both clones, created off the `prospect-wallet/sprint-0001` heads (UI `151846d`, BFF `53e549e`). **Not pushed.** Prerelease versions and the `daypass` dist-tag untouched. `docs/sprints/ledger.yaml` untouched (orchestrator).
**Planning repo:** nothing committed; changed in the working tree for the orchestrator — `docs/contracts/short-term-pass-bff.md` (v3), `docs/sprints/SPRINT-0003.md` (one "Phase A note" paragraph under the header; Pyramid Index untouched), `tools/day-pass-harness/parity/{elements,approved-deltas}.json` (v2), NEW `docs/sprints/drafts/SPRINT-0003-BLOCKERS.md`, NEW this file.
**Phase A exit (plan):** *v3 frozen and type-checked in both repos; fixtures and validity tested; feasibility notes recorded; inventory skeleton valid; branches and ledger updated* — met except "pushed" and "ledger", which are the orchestrator's by instruction. T0 is claimable once the orchestrator pushes and updates the ledger.

## 1. Commits

| Repo | Hash | Task | Content |
|---|---|---|---|
| online-join-bff | `5915c96` | A2 | Contract v3 types and ajv schemas (`OfferRequest`/`offerSchema` with mandatory `generation`, `OfferSummary.label`, `OrderSummary.{durationDays,label,validUntil}`, `snapshot.offerId`, `offers[]`/`selectedOfferId`/`offer`, `OfferResponse`, `pass.{label,validUntil,viewPath}`, `receipt`, `PassLinkResponse`, `PassLinkRotateResponse`, `PassView`, `PASS_TOKEN_PATTERN` + `isPassTokenShape`, `OFFER_UNAVAILABLE`); NEW `services/shortTermPass/validity.ts`; `toOfferSummary`; minimal migration of `toOrderSummary` and `buildCheckoutResponse`; schema tests |
| online-join-bff | `0121512` | A3 | Core 1/3/5 offers (`provisional` on 3 and 5, listed in the capability note), Kelly Reyes (`KELLY_CORE`) + wallet seed, Pass Terms `2026-09.2` with `offerLabel`/`validity` context and commercial binding in `consentRevisionOf`; tests (`validity`, `catalog`, `identityDirectory`, `consentTemplates`, `purchase` version pins, demo check) |
| online-join-bff | `a3cdbfc` | A4 | `qrcode` (+ dev `@types/qrcode`, `jsqr`, `pngjs`, `@types/pngjs`) with lockfile; `qrFeasibility.test.ts` encode → decode round-trip; `.env.example` rows `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS` |
| online-join-ui | `d97afbe` | A2 | `interfaces/api/shortTermPass.ts` v3 mirror; `shortTermPassTestData.ts` factories (`coreOffers`, `kelly`, `makeCoreCheckoutResponse`, `makeMultiDayOrder`, `makeReceipt`, `makeMultiDayPurchase`, `makePassView`, `PASS_TOKEN`, `validUntilOf`) so the test tree type-checks against v3 |
| online-join-ui | `b6ae307` | A3 | NEW `shortTermPassTestData.test.ts` pinning the factories to the BFF fixtures (ids, amounts, labels, inclusive range, receipt, `PassView` key set); Pass Terms document fixture `2026-09.2` |

A5 (parity skeleton) has no clone commit — it changes only the two JSON files in this repo.

## 2. Quality (foreground runs after the last commit)

| Repo | `tsc --noEmit` | Lint | Tests | Coverage (stmts / branches / funcs / lines) | Floors |
|---|---|---|---|---|---|
| online-join-bff | clean (exit 0) | `eslint src/ --quiet`: 0 errors | 64 suites / **640 passed**, 2 pre-existing skips (642) | **97.19 / 85.86 / 96.12 / 97.91** | 84 / 67 / 67 / 84 |
| online-join-ui | **8 pre-existing errors**, all under `routes/PaymentPage` and two payment tests — identical list to the baseline, none new | `eslint src/`: **0 errors**, 756 warnings (the Sprint 0002 baseline count) | 104 suites / 651 tests: **650 passed, 1 failed** = the pre-existing `__tests__/helpers/transformers.test.ts` timezone baseline (accepted exception, not counted green) | **92.47 / 84.2 / 87.5 / 92.47** | 80 / 80 (lines / statements) |

No threshold lowered, no exclusion added. Short-term-pass-only BFF run at A3: 33 suites / 384 tests green. Husky (prettier + eslint --fix) ran on every BFF commit.

## 3. A4 feasibility findings (details: contract §8a; blockers file)

1. **QR:** `qrcode@1.5.4` PNG (error correction M, margin 1, scale 6) decodes byte-for-byte with `jsqr@1.4.0` via `pngjs` — proof pattern for T4 established (never re-encode equality).
2. **CID email:** nodemailer inline attachment `cid:pass-qr` arrives in Mailpit as `multipart/related` → `image/png` with `Content-ID: <pass-qr>` and `Content-Disposition: inline`; Mailpit lists it under `Inline[]` with a `PartID`; `GET /api/v1/message/{ID}/part/{PartID}` returns the identical bytes. E2 should read `Inline`, not `Attachments`.
3. **History fallback (blocker PA-1):** the dotted `pv1.` token path is *not* rewritten to the SPA entry (dot rule) → 404. B5 adds `rewrites:[{from:/^\/signup\/pass\/pv1\.[A-Za-z0-9_.-]+$/, to:'/'}]` (probe green). `STP_PUBLIC_BASE_URL` is the origin only; the BFF appends `/signup/pass/<token>` and `/api/short-term-pass/passes/<token>/qr.png`. Dev ingress prefix unverified (PA-2, PLATFORM).
4. **Log sites:** `@abc/bff-toolkit@11.29.1` `loggerMiddleware()` (`→ IN url`, `← IN originalUrl -> status`, `endpointUri`) and the `historyFallback.ts` debug logger; redaction via a winston format on `loggerService` plus the fallback logger regex (design for B5).
5. **Helper:** `linkExpiresAtOf` done in A3 (3-day Sep 16–18 Chicago → `2026-09-20T05:00:00.000Z`).
6. **Publisher:** no attachment slot; hosted PNG URL path stands; no live call attempted (503 on 2026-09-10).
7. **`.env.example`** has the three rows; `env.ts` / `config.ts` / boot guard entries are B5's.

## 4. What the BFF and UI lanes must know before they start

**Contract decisions taken at A2 (plan left them open — do not re-decide):**
- `OrderSummary.validUntil` optional alongside `visitDate`; `durationDays` and `label` required. `OfferSummary.label` computed by the BFF (`durationLabelOf`).
- `POST …/pass-link` answers `{viewPath, linkExpiresAt, delivery}`; `GET …/pass-link` answers `{viewPath, linkExpiresAt}`.
- `PUT /offer`: unknown or foreign `offerId` → 400 `VALIDATION_FAILED`; after an order / during a purchase → 409 `STATE_CONFLICT` "Start again to choose a different pass." (no reason); stale → `STALE_GENERATION`; a *stored* selection that later left the catalog → 409 `STATE_CONFLICT` / `OFFER_UNAVAILABLE` with `details.offers` + `details.selectedOfferId`. `OFFER_ID_PATTERN = ^[a-z0-9][a-z0-9-]{1,63}$`.
- Token shape: `PASS_TOKEN_PATTERN` / `isPassTokenShape()` exported from `schemas.ts` (path-param predicate, ≤ 120 chars, strict regex) — B5 checks shape before signature before store.
- `PurchaseReceiptSummary` (browser) vs the fuller `PurchaseRecord.receipt` snapshot (B4 types it; documented in contract §5). `PassView` key set per §4b-5; `club.links` = `{app?}` only.
- `validityLabel(visitDate, validUntil, todayIso?)`: "Today" only when `todayIso` is given; email and receipt snapshot omit it. `dateFieldLabelOf(durationDays)` and `passStatusOn(visitDate, validUntil, todayIso)` exist for B5/B6; the UI (C3) mirrors the strings — BFF `validity.test.ts` is the fixture source.
- Mock QR payload becomes `STP2|passId|club|visitDate|validUntil|sig` (B3); UI factories already use it.

**BFF lane (B1–B7):**
- B1: `CheckoutRecord.selectedOfferId` + `PUT /offer` route (`validateBody('offer', …)` exists); `buildCheckoutResponse` already builds `offers`/`selectedOfferId`/`offer` — insert the stored selection between "order's offer" and "`offers[0]`"; `requireOffer(catalog, club)` still returns the first offer — change its signature to `(catalog, club, offerId)` and thread it through `consentSetFor`, `createOrderShell`, `validatePurchase` (fact 1). Tests must assert label, amount and validity, not hash equality.
- B2: store `validUntil` on `StoredOrder` and recompute in `applyOrderUpdate`; `toOrderSummary` currently derives it via `validUntilOf` — keep the same helper. `consentRevisionOf` already binds the commercial line; `renderConsentDocumentSet` computes it from `input.visitDate` and `offer.durationDays`. Committed order edits must bump `generation`.
- B3/B4/B5/B6/B7 as planned; **B5 additionally owns PA-1 (rewrite rule + test) and the log redaction** (contract §8a(c)/(d)). Use `pngjs` + `jsqr` in `qr.test.ts` the way `qrFeasibility.test.ts` does; delete or fold that feasibility file into `qr.test.ts` when `renderQrPng` lands.
- B6: for the Mailpit proof, read `Inline[0].PartID` and fetch `/api/v1/message/{ID}/part/{PartID}`.
- Fixture exports: `CORE_SOUTH_OFFERS`, `CORE_SOUTH_OFFER_3_DAY`, `CORE_SOUTH_OFFER_5_DAY`, `provisionalOffersOf`, `KELLY_CORE` (was `JORDAN_CORE_TWIN`).

**UI lane (C1–C8):**
- `checkout.offer` still works (compatibility) — C1 adds `offers`/`offerId` from `response.offers` / `snapshot.offerId ?? selectedOfferId`. `OfferSummary.label` is already on every offer; `OrderSummary.label`/`durationDays`/`validUntil` are already typed.
- Factories: `coreOffers`, `kelly`, `makeCoreCheckoutResponse(selected)`, `makeMultiDayOrder(3|5, visitDate)`, `makeMultiDayPurchase(3|5, visitDate)` (carries `pass.viewPath` and `receipt`), `makePassView()`, `PASS_TOKEN`, `validUntilOf`; `makePurchase()` now has `pass.label/validUntil`, `receipt`, `STP2` payload and `passTermsVersion: '2026-09.2'`.
- C5: the page cannot be reached in a browser until B5 lands the rewrite (PA-1); jest routing tests are unaffected. `getPassView` is a plain fetch (no CSRF, no credentials) against `/api/short-term-pass/passes/:token`; expect one identical 404 body `{code:'NOT_FOUND', message:"This link isn't valid."}`.
- Approved deltas are AD-11 (single-offer grid), AD-12 (View link + Resend), AD-13 (delivery variants) — not AD-10…AD-12.

**Orchestrator (D1, E):** parity JSON v2 skeleton is in place (13 states, stubs flagged `stub:true`, placeholders `placeholder:true`); D1 completes selector coverage per state × width and writes the state list into `docs/validation/short-term-pass-ui.md`. Ledger and push pending.

## 5. Deviations from the plan (with reasons)

| Deviation | Reason |
|---|---|
| Dev deps `pngjs` + `@types/pngjs` added (plan listed only `qrcode`, `@types/qrcode`, `jsqr`) | `jsqr` takes raw RGBA; proving the round-trip on the PNG bytes needs a decoder |
| `@types/qrcode` placed in `devDependencies` | matches `@types/nodemailer` in this repo; types are not needed at runtime |
| New placeholders numbered AD-11…AD-13 (plan: AD-10…AD-12) | AD-10 already existed (v1.2 tab-row width); ids must stay unique for the runner |
| Contract §7 (fixtures) updated in Phase A (plan lists §7 under E5) | fixtures changed in A3; a stale §7 would mislead both lanes. E5 still owns the final register |
| `validity.ts` duplicates the zoned-date logic instead of importing `clubLocalToday` from `order.ts` | keeps the file dependency-free so the TZ-independence test can `require` it under plain Node; B2 may unify |
| A1 "branches pushed; ledger updated" not performed | orchestrator owns push and ledger by instruction |
| One feasibility email left in the Mailpit inbox | test sink; nothing deleted from the user's environment |

## 6. Next

Orchestrator: review the working-tree docs, push both branches, set the ledger to `SPRINT-0003 in-progress`, then start the BFF lane (B1 → B2 → B3 → B4 → B5 → B6 → B7, with PA-1 inside B5) and the UI lane (C1 → C2 → C3 → …) against contract v3; D1 from day 2.
