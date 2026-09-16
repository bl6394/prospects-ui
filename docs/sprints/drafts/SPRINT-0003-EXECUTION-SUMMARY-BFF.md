# Sprint 0003 — execution summary, BFF lane (Phase B: B1–B7 + BFF half of E1)

**Sprint:** Design v4 (`docs/sprints/SPRINT-0003.md`). **Date:** 2026-09-16. **Executor:** Claude Fable 5.1, one session, B1 → B2 → B3 → B4 → B5 → B6 → B7 in order, then lint / build / coverage / demo in the foreground.
**Branch:** `repos/online-join-bff` `prospect-wallet/sprint-0003`, head **`6dfa0cd`** on top of the Phase A head `a3cdbfc`. **Not pushed** (orchestrator). Working tree clean. Nothing committed in the planning repo; the UI clone untouched. Prerelease version and `daypass` dist-tag untouched.
**Phase B exit (plan):** *U2, U4–U10, U13–U19 pass at the router level; demo green; production boot still refuses every hook and a missing `STP_PASS_LINK_SECRET`; `STP_PUBLIC_BASE_URL` required only when a real transport is on; coverage ≥ floors; summary and blockers written* — **met**. Contract v3 implemented as frozen; no shape changed. PA-1 fixed inside B5. Blockers file: `SPRINT-0003-BLOCKERS-BFF.md` (no open blockers; three E2 attention items; deviations; contract notes for the UI lane).

## 1. Commits

| Hash | Task | One line |
|---|---|---|
| `77a5695` | B1 | Offer selection (CR-10): `PUT /checkouts/:id/offer`, `CheckoutRecord.selectedOfferId`, `requireOffer(catalog, club, offerId)` threaded through every consent render, order shell committed with the selection read inside the store mutation, generation bumps on committed offer and order edits, typed 409 `OFFER_UNAVAILABLE` |
| `0fc4365` | B2 | Validity and consent (CR-11, CR-17): stored `validUntil` recomputed on date edits, offer-aware `consentSetFor` everywhere, date re-checked at authorization (midnight rollover) |
| `a3b3332` | B3 | Sale, issue and QR payload carry the range: `STP2\|passId\|club\|visitDate\|validUntil\|sig`; `pass.{label, validUntil}` |
| `295edde` | B4 | Immutable receipt snapshot at ISSUED (`PurchaseRecord.receipt`), `PurchaseResult.receipt` subset, `STP/receipt.ts` |
| `0774fb8` | B5 | Credential store, `pv1` HMAC tokens minted at ISSUED, public `GET /passes/:token{,/qr.png}`, `PassView`, `renderQrPng`, boot guard + env, PA-1 rewrite, log redaction, AppDynamics skip, hooks revoke, leak scan |
| `d829dde` | B6 | Pass email with QR and receipt: `renderPassMail`, `cid:pass-qr` on SMTP, hosted `qr.png` on the publisher (acknowledgement → `pending`, club billing code), `DeliveryInput` v3 from the snapshot, outbox `label` / `validUntil` / `viewPath`, old `passEmail()` deleted |
| `562b002` | B7 | `GET`/`POST …/purchases/:pid/pass-link` (owner as `wallet-retry`, per-purchase serialization, mint → deliver → revoke-on-accept, `WindowLimiter(3, ONE_HOUR_MS)`), Demo 3 · Core South multi-day, capability notes (provisional offers, credential store, email image mode) |
| `a0cbb58` | B7 follow-up | `POST /testing/reset` also clears the pass-view and resend limiters |
| `6dfa0cd` | UI Q1 | Pins `GET …/pass-link` for a new visitor's resumed `complete` checkout (answer to the UI lane's question 1; all seven answers in the blockers file) |

nine commits; 59 files changed over Phase B (19 added, 1 deleted — `qrFeasibility.test.ts` folded into `qr.test.ts` — 39 modified); +4 207 / −276 lines. Husky (prettier + eslint --fix) ran on every commit.

## 2. Quality (foreground runs at `a0cbb58`; `6dfa0cd` adds one assertion to `passes.test.ts` — 11/11 green, lint clean)

| Check | Result |
|---|---|
| `npx tsc --noEmit` | clean (exit 0) |
| `npm run lint` (`eslint src/ --quiet`) and `eslint scripts/` | 0 errors |
| `npm run build` | clean (run by `npm run demo:short-term-pass`) |
| `npx jest` | **70 suites / 698 passed**, 2 pre-existing skips (700) — was 64 / 640 at the Phase A exit |
| `npx jest --coverage` | **97.22 / 86.76 / 96.44 / 98.12** (statements / branches / functions / lines) vs floors 84 / 67 / 67 / 84; no threshold lowered, no exclusion added |
| `npm run demo:short-term-pass` | **88 / 88 checks passed**, exit 0 — Demo 0, 1, 2 and the new **Demo 3 · Core South multi-day** (Runs 9–11); hosted capture `skipped` (no `--hosted`) |
| Mailpit (manual, run of the demo against the local `.env` with `STP_EMAIL_TRANSPORT=smtp`) | pass email "Your 3-day pass at Core Health and Fitness Club · Wed, Sep 23 – Fri, Sep 25" to `m@m.com`: `Inline[0] = {PartID 2.2, image/png, ContentID pass-qr, 1896 bytes}`, `Attachments []`, HTML references `cid:pass-qr`, no `data:` URI, text part carries "View your pass: http://localhost:3000/signup/pass/pv1.…", no "Today"; the part decoded with `pngjs` + `jsqr` (210 × 210 px) to `STP2\|pass_…\|90033\|2026-09-23\|2026-09-25\|…`. Two such emails exist for the same pass — the original and the accepted resend of Run 11 |

Pre-existing baseline failures: none in the BFF (the UI's `transformers.test.ts` timezone failure is the UI lane's).

## 3. Use cases → tests

| UC | Pinned by |
|---|---|
| U2 selection, reload, Change, Start again, code-entry selection | `routes/shortTermPass/__tests__/offer.test.ts` (U2 block) |
| U3 (API half) Riverside single offer | `offer.test.ts` |
| U4 refusals (400 unknown/foreign/malformed/missing generation, 409 post-order in every state, 409 active purchase, 409 stale, 409 `OFFER_UNAVAILABLE`) | `offer.test.ts` (U4 block) |
| U5 order shell for the selected offer at verify and on resume; races offer vs verify / retryLookup / identity reset; order edit vs purchase | `offer.test.ts` (U5 and races blocks) |
| Fact 1 cross-response (label, amount, validity on every route + the consent snapshot; 1-day attestation refused at Pay) | `offer.test.ts` (fact 1 block) |
| U6 range moves with the start date, new Pass Terms hash and revision, past refused not clamped | `routes/shortTermPass/__tests__/order.test.ts` (U6/U8), `services/shortTermPass/__tests__/order.service.test.ts` (recompute, catalog maximum bounds the start only) |
| U8 Pass Terms 2026-09.2, static override still changes revision | `order.test.ts` (fact 10), `consentTemplates.test.ts` (A3), `offer.test.ts` |
| U9 stale attestation before authorization; midnight re-check | `offer.test.ts` (fact 1), `routes/shortTermPass/__tests__/purchase.test.ts` (B2 midnight, CR-02 block) |
| U10 Core 3-day Sep 16: sale dates, `pass.{label, validUntil, STP2}`, `receipt` exact key sets, snapshot immutable after a catalog edit, `viewPath` on the 201 only, consent hash = dialog | `purchase.test.ts` (Demo 3 block, U11), `services/shortTermPass/__tests__/purchaseMocks.test.ts` |
| U13 email content and structure | `services/shortTermPass/__tests__/passEmail.test.ts`, `smtpMailer.test.ts` |
| U14 image transport: SMTP `cid:pass-qr` decodes to `qrPayload`; publisher hosted `qr.png` URL, `90033-STP`, display name, route `AMZ`, no data URI, `pending` | `smtpMailer.test.ts`, `emailPublisher.test.ts` |
| U15 `PassView` key set and leak list (upcoming 3-day, active 1-day) | `routes/shortTermPass/__tests__/passes.test.ts`, `services/shortTermPass/__tests__/passView.test.ts` |
| U16 identical 404 across 12 refusals, revoke hook, flag off / `onlineProspects` false / catalog error, 61st → 429, headers on every response incl. errors and PNG, no cookie / CSRF, GET only | `passes.test.ts`, `passCredentials.test.ts` (shape → signature → tamper matrix) |
| U17 `qr.png` image/png + nosniff, decoded by `jsqr`, 404 when expired | `passes.test.ts`, `qr.test.ts` |
| U18 lifetime: upcoming / active / expired without QR / 404 from `linkExpiresAt`, DST-safe boundaries | `passes.test.ts` (clock travel), `passView.test.ts`, `validity.test.ts` (A3) |
| U19 current link, rotate-and-resend, revoke-on-accept, failed transport keeps the old link, 3/hour, 409 without a pass, strangers 404, unverified 401, concurrent resends leave one live link, mint-failed purchase → 404 then first link via resend | `purchase.test.ts` (pass-link block) |
| U20 (API half) page after checkout expiry, no cookie; token never in `GET /purchases/:pid`, replay, `/testing/state`, stored result | `passes.test.ts`, `purchase.test.ts` (U11), `testingRoutes.test.ts` (leak scan `pv1.` / `viewPath`) |
| PA-1 rewrite rule + real-library probe; debug-logger redaction | `utils/middlewares/__tests__/historyFallback.test.ts` |
| Log-sink redaction (`message`, `endpointUri`, child loggers) | `utils/__tests__/logRedaction.test.ts` |
| AppDynamics skipped on `/pass/` documents | `routes/static/__tests__/index.test.ts` |
| Boot guard: missing / short / shared secret outside mock mode, bad grace hours, base URL required with a real transport, https in production | `services/shortTermPass/__tests__/config.test.ts` |
| Mint failure leaves the pass issued, delivery failed, no link; `wallet-retry` never mints or mails; replay returns no link and sends no email | `purchase.test.ts` |
| Capability report lists the credential store | `services/shortTermPass/__tests__/adapters.test.ts`; demo "Sprint 0003 notes" (provisional offers, credential store, email image mode) |

## 4. Deviations from the plan

Recorded with reasons in `SPRINT-0003-BLOCKERS-BFF.md` §"Deviations". The ones that touch other lanes: `PassCredentialStorePort` has two extra methods (`currentForPurchase`, `revokeToken`); `DeliveryInput` carries `links: {viewUrl, qrUrl}`; `executePurchase` returns `{record, passLink?}`; `POST …/pass-link` updates the stored `result.delivery`; only the pass path maps the publisher acknowledgement to `pending`; `snapshot.offerId` is always present; committed order edits bump `generation` (three v2 test pins updated); the shared test helpers live under `services/shortTermPass/testing/`, not `__tests__`.

## 5. Decisions the plan left to the lane (taken here, not re-decided from A2)

- Order shell under a racing selection: the shell is built from the latest snapshot and the store mutation aborts and rebuilds (bounded to 3) when `selectedOfferId` moved; a checkout that left `verified` during the lookup refuses the commit (409) instead of resurrecting an order on a reset identity.
- Rotate-and-resend with no live credential (mint failed at ISSUED): the resend mints the first credential; on a refused transport the new credential is kept (there was no working link to protect).
- Resend lifetime never moves: the new token carries the current credential's `linkExpiresAt` (or `linkExpiresAtOf(validUntil, timezone, grace)` when none existed).
- Pass-route handlers log `clubNumber` and the view status only; never a token, token id or purchase id.

## 6. What the orchestrator must know for E2

**Env keys to add to the BFF `.env` (names only; the local file has none of them today):** `STP_PUBLIC_BASE_URL` (the origin the browser reaches the BFF at, e.g. the local BFF origin; required because `STP_EMAIL_TRANSPORT=smtp` is on — the boot guard refuses to start without it), `STP_PASS_LINK_SECRET` (≥ 32 random characters, dedicated — must differ from `STP_SESSION_SECRET` / `STP_CODE_SECRET`; never printed), optional `STP_PASS_LINK_GRACE_HOURS` (default 24). `.env.example` documents all three (Phase A).

**Reading the link.** The creating `POST /purchases` 201 carries `pass.viewPath = /signup/pass/pv1.<id>.<exp>.<sig>`; `GET /purchases/:pid`, replay and `/testing/state` never do. After reload use `GET /api/short-term-pass/checkouts/:id/purchases/:pid/pass-link` (owner cookie + CSRF not required for GET, but the checkout cookie is). The hooks outbox `GET /api/short-term-pass/testing/outbox?checkoutId=` lists `kind:'pass'` messages with `label`, `validUntil`, `viewPath`. The page is `${STP_PUBLIC_BASE_URL}/signup/pass/<token>`; the API is `GET /api/short-term-pass/passes/<token>` (JSON) and `…/qr.png`.

**Mailpit (PR-06 proof).** `GET http://localhost:8025/api/v1/search?query=subject:"Your 3-day pass"` → `GET /api/v1/message/{ID}` → read **`Inline[0].PartID`** (not `Attachments`; observed `2.2`) → `GET /api/v1/message/{ID}/part/{PartID}` returns the `image/png`; decode it with `repos/online-join-bff/src/services/shortTermPass/testing/qrDecode.ts` (`pngjs` + `jsqr`, dev deps) and compare byte-for-byte to `pass.qrPayload` from the 201 or `/testing/state`. The HTML part contains `src="cid:pass-qr"`, the text part the "View your pass: …" line. A successful resend produces a second email for the same pass with a **different** link; the first link then answers 404.

**Hooks revoke.** `POST /api/short-term-pass/testing/passes/revoke?checkoutId=<chk_…>&purchaseId=<pur_…>` from loopback with header `X-STP-TEST-KEY: <STP_TEST_HOOKS_KEY>` → `{ok:true, revoked:true}` (`revoked:false` when nothing is live; 404 when the purchase is not that checkout's). Afterwards `GET /passes/<token>` and `GET …/pass-link` answer 404.

**Limits and resets.** `/passes/*`: 60 per IP per 15 minutes (404s count). `POST …/pass-link`: 3 per purchase per hour. `POST /testing/reset` (hooks) now clears both together with the identify/send limiters and address locks. `STP_TEST_CLOCK` moves `today`, the pass status and `linkExpiresAt` checks together (the test clock advances with wall time).

**Curl checks.** `curl -sI "$BASE/api/short-term-pass/passes/<token>/qr.png"` → `content-type: image/png`, `cache-control: no-store`, `referrer-policy: no-referrer`, `x-robots-tag: noindex, nofollow`, `x-content-type-options: nosniff`, no `set-cookie`. `curl -s -H 'Accept: text/html' "$BASE/signup/pass/<token>"` → the SPA document without `adrum`. Any tampered token → `{"code":"NOT_FOUND","message":"This link isn't valid.",…}`.

**Completion vocabulary for the BFF half:** *v4 BFF changes complete; pass email + link proven locally (jest + demo + one Mailpit decode); static QR only; live email unverified (publisher 503); hosted capture unverified (B1); credential store in-memory by declaration (a restart loses links and purchases alike).*
