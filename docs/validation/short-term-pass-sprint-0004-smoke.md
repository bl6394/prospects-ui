# Sprint 0004 — smoke (local browser smoke E2, dev smoke E3, live read E4)

**Status:** §dev recorded 2026-09-18 (Phase D); §local and §live completed at Phase E. Vocabulary: every check names its mode (mock adapters / dev mock with the pinned code / live). Nothing here is a pilot verdict.

## §dev — E3 dev smoke (2026-09-18, before the v4 deploy)

**Environment.** `https://onlinejoin.dev.abcfitness.net`, BFF image `online-join-bff:v1.2.3` (**contract v3**, mock adapters, `STP_CAPTURE_MODE=paypage` against Pay Page dev, `STP_MOCK_OTP_CODE` pinned by helm-configs #3088, `STP_TEST_HOOKS=true`). The Sprint 0004 (contract v4) BFF is not deployed yet — it reaches dev when its PR merges to `main` (E5) — so this run proves the **current** dev deployment and the two mechanics E3 depends on (pinned code, hooks through the pod); the v4 assertions (`pass.beginDate = today`, no `viewPath`, `useBy`, five documents, `contractVersion`) are **pending the v4 dev deploy** and marked so below.

| Step | Request | Result | Verdict |
|---|---|---|---|
| Create | `POST /api/short-term-pass/checkouts {"clubNumber":"90033"}` (Origin allowlisted) | 201; `adapterMode: mock`, `captureMode: paypage`, `testHooks: true`; three v3 offers `day-pass-gym-floor` $25 / 1 day, `-3` $60 / 3, `-5` $90 / 5; four consent documents; **no `contractVersion`** (v3) | pass (v3 shape as deployed) |
| Identify Kelly | `POST …/identify {"email":"m@m.com"}` | 200 `outcome: challenge`; `expiresAt` = issue + **10 min**, `resendAfter` = + 30 s (v3 constants — v4 sets 5 min) | pass (v3) |
| Verify with the pinned code | `POST …/verify {"code": <STP_MOCK_OTP_CODE>}` | 200 `outcome: recognized`, `person.firstName: Kelly`; order shell `{offerId: day-pass-gym-floor, amountMinor: 2500, durationDays: 1, visitDate: 2026-09-17, validUntil: 2026-09-17}` (v3 dates; no `useBy`) | pass — the pinned code completes verify in dev |
| Wallet | `GET …/wallet` | `status: ok`, `[Visa 4242]` (no `expired` field — v3) | pass (v3) |
| State through the ingress | `GET …/testing/state` via `https://onlinejoin.dev…` | **403** "Testing routes are local-only." | pass — loopback rule intact (Q8) |
| State through the pod | `kubectl --context k8s-lower-wlr -n dev port-forward deploy/online-join-bff 18080:8080` → `GET http://127.0.0.1:18080/…/testing/state?checkoutId=…` with `X-STP-TEST-KEY` | 200: `state: recognized`, `generation: 2`, `emailVerified: true`, `boundMember: true`, order keys `[amountMinor, consents, currency, durationDays, offerId, offerName, saveCard, validUntil, visitDate]`, `purchases: []`; the string `viewPath` does not appear (no purchase yet) | pass — R14 mechanism works; no hooks-policy change |
| Hosted-card purchase (Pay Page dev test card) | browser flow | **not run in this step** — needs the browser (Pay Page embed); recorded as unverified until the E3 browser pass or the v4 deploy | unverified (B1) |
| Standalone host | `https://guestpass.dev.abcfitness.net/?club=90030` | no DNS record yet (curl exit 6 / `dig` empty) — expected before helm PR #3090 merges and deploys | pending #3090 |
| Entry-document flag hint | `GET /signup/day-pass?club=90030` (text/html) | v3 key `oj_short_term_pass_checkout:true` (override on) | pass (v3); v4 key `guest_pass_online` pending the v4 deploy |

**Dev verdicts (E3 as of 2026-09-18):** existing host with the pinned code — **pass for the deployed v3 build**; v4 assertions — **pending the v4 dev deploy** (after the BFF/UI PRs merge; helm #3090 for the host); standalone host — **pending #3090**; hosted capture — **unverified**.

## §local — E2 local browser smoke (Phase E)

*Completed at E2.* Environment: one BFF process on :3000 (`node --env-file=.env dist/src/server`, contract v4 build) with `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=mock`, `STP_TEST_HOOKS=true`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_CATALOG_SOURCE=fixture`, `STP_EMAIL_TRANSPORT=smtp` → Mailpit (`stp-mailpit`, SMTP :2525, API :8025), `STP_STANDALONE_HOSTS=guestpass.localhost`; UI dev server on :3001 proxied by the BFF; driver headless Google Chrome via `puppeteer-core` 23.11 (scratch install `/tmp/stp-smoke4`, script `smoke4.mjs` — orchestrator scratchpad), one fresh browser context per flow, `POST /testing/reset` before every flow, codes read from `GET /testing/outbox`. Fixture cards only; mock gateway; no live charge.

Flows (plan E2): Riverside Jordan success at 1440 · Core Kelly Flex Day Pass (7 days) at 375 with the opt-in checked → snapshot hash; "use by" · Core new visitor decline → deactivated → "Try another card" → success · Kelly decline → reverted · Priya expired chip → hosted slot · deactivate failure → RECONCILING → compensate · flag off · `/guest-pass?club=` alias · overflow 320–440 · Mailpit: OTP from the template slot, stand-in prospect email without an image part · state shows no `viewPath` / `qr` / `pv1`.

| Flow | Checks | Result |
|---|---|---|
| *E2* | | |

Screenshots: `docs/validation/screenshots/sprint-0004/`.

## §live — E4 live DataTrak read

*Gated CF-13 / CF-14.* One `STP_CATALOG_SOURCE=datatrak` boot against a dev club: blocked on 2026-09-18 — `getClubDefaultExternal.spr` carries no guest-pass / waiver / timezone fields and `saleItems.spr` refuses a member-less query (contract §8a). E4 records the adapter's fail-closed behaviour against the recorded responses instead; the live read stays **blocked** until Chancy's DT PR.
