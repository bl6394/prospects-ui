# Sprint 0004 — BFF lane execution summary (`online-join-bff`, branch `prospect-wallet/sprint-0004`, PR #107)

Executor: Claude Fable 5.1 (the resumed executor session finished B0 and ran B1–B13), 2026-09-18. Every statement below is about the **mock** adapter set unless it says otherwise.

## Commits (after A3/A4 `9bad883`)

| Commit | Task | What landed |
|---|---|---|
| `61b32cf` | B0 | Removal inventory executed: pass page / QR / pass-link routes, secrets, `visitDate`, `adult`, CID image part, `qrcode` / `jsqr` / `pngjs`; v3-pinned suites rewritten or deleted; `rg` proof (only changelog comments remain) |
| `c57d95a` | B1 | `CODE_TTL_MS = 5 min`, `SENDS_PER_ADDRESS = 2` (D58 / D59, CR-10 / CR-30) |
| `a9a9d37` | B2 | Catalog v4 gate: flag `guest-pass-online` AND ≥ 1 eligible flagged single-visit item; `offers[]` / `selectedOfferId` / `contractVersion: 4` on `POST /checkouts`; `STP_CATALOG_SOURCE` |
| `7f0c721` | B3 | Order and validity pinned at the router: `useBy` quote, no date / adult, five documents, waiver reset per purchase |
| `5e9f07e` | B4 | Purchase order v4: create / repaint before pay, deactivate / revert on a confirmed decline, RECONCILING + `compensate` + sweeper, `PURCHASE_IN_PROGRESS` while unresolved, `purchase.attempt` log, 10 / IP / hour |
| `cec29f3` | B9 / B10 | OTP template slot (`STP_OTP_TEMPLATE_PATH`, `{{code}}` / `{{clubName}}`, built-in PROPOSED template), production guard v4 (refuses `fixture` and `STP_MOCK_OTP_CODE`; datatrak needs https URL + credential) |
| `938acb5` | B11 | `DatatrakServiceCatalog` (service layer, 60 s cache incl. failures, fails closed, capability report without the credential) against recorded + labelled synthetic fixtures |
| `0f7d323` | B12 | `standaloneHost` middleware (`STP_STANDALONE_HOSTS`), `window.guestPass`, flag hint `guest_pass_online`, generic 404 off the guest-pass surface |
| `0589049` | B13 | Demo 0–6 rewritten for v4 (58 checks, per-demo limiter reset, U24 limiter check, four verdicts) |
| `9731717` | CI | bump job: `1.2.4` (a patch — the plan expected the next minor; left to CI) |
| `9b8ed8c`, `c6d4136` | Sonar | 13 findings cleared behaviour-unchanged (linear scans for the placeholder / tag / trailing-char regexes, `resolveClub` / `getOffers` split, `WireScalar`, single return in `persistPerson`, no nested ternaries / template literals, OS-derived loopback peers in the demo); suites 68 / 68, demo 58 / 58 after |

B5–B8 (consent snapshot with the `marketing` document, stand-in delivery, compensation registry / sweeper, expired-card refusal) landed inside B3 / B4 / B9 commits; B0's HTTP harness (`testing/harness.ts`) sends the waiver only and resets the identify + purchase limiters.

## Proof

- `npx jest --coverage`: 68 / 68 suites, 698 passed (2 skipped); coverage 97.42 % statements / 85.98 % branches / 97.13 % functions / 98.26 % lines (floors 84 / 67 / 67 / 84). `eslint` clean. `tsc --noEmit` clean for `src` and `scripts`.
- `npm run demo:short-term-pass`: 58 / 58 (transcript in `docs/demos/short-term-pass-local-demo.md`).
- `rg -n 'pv1|viewPath|qrPayload|validUntil|durationDays|visitDate|adult|PASS_LINK|passCredential|passView|renderPassMail|redactPassTokens|isPassDocument|PASS_VIEW|maxDaysAhead|linkExpiresAt' src --glob '!**/__tests__/**'` → changelog comments only; `rg 'image/png|cid:' src/services/shortTermPass/adapters` → nothing; lockfile without `qrcode` / `jsqr` / `pngjs`.
- Served the E2 browser smoke (71 / 71) from `dist/` built at `0589049` — four processes (main, `decline`, `deactivate-failure`, flag off).
- E4: one `STP_CATALOG_SOURCE=datatrak` boot failed closed (404) — the dev service host did not resolve from the executor's network; live read stays blocked (CF-13 / CF-14).

## Decisions taken in the lane (recorded, not re-decided)

1. A RECONCILING purchase blocks a new Pay on the checkout (409 `PURCHASE_IN_PROGRESS`, `details.state: RECONCILING`) — the UI removes Pay entirely.
2. A thrown `authorize` (transport error, no reference to poll) resolves to RECONCILING, never to a deactivate.
3. `DatatrakServiceCatalog` derives the currency from a `#countries` map keyed by `billingCountry` (the `#billingCountry` seam was replaced).
4. `STP_ADAPTER_MODE=platform` with `STP_CATALOG_SOURCE=fixture` is allowed outside production (dev runs exactly this until the DT PR).
5. `.env` keys the v3 build used (`STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_*`) are ignored, not refused, so mixed deploy order is safe.

## Known limitations

Hosted Pay Page capture unverified locally (B1). Platform `ProspectPort` `notEnabled` (CF-15) — prospect writes are mock only. Live DataTrak read blocked (CF-13 / CF-14). The mock fault switch is in-process — the browser smoke needed one process per fault. In-memory stores by declaration (V-P1).
