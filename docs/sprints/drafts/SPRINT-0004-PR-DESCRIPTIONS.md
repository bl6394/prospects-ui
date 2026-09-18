# Sprint 0004 — PR descriptions (as opened 2026-09-18)

After opening: the CI bump job pushed `8.33.0` (UI) and `1.2.4` (BFF); the UI line was restored to `8.34.0-daypass.1` (`e62a67c`); the first Sonar scans failed and their findings were fixed (`3435039`; `9b8ed8c`, `c6d4136`).

## online-join-ui — `feat: Guest Pass v1 — catalog cards, use-by validity, v6 done page, expired card, standalone host (Sprint 0004, contract v4)`

Branch `prospect-wallet/sprint-0004` → `main`. Version line stays `8.33.0-daypass.N` (CI bumps from the title; never approve a `-daypass.*` build into staging).

### What changes (contract v4, Design v6 — `docs/prd/day-passv6.html` in the planning repo)

- **Catalog cards (CR-28, D57):** one card per eligible flagged item the BFF returns (`offers[]` — Riverside one, Core South three), catalog name, price without cents, the server validity line ("One time use only, valid for 7 days"); no perks, no duration label, no compatibility fallback; zero offers → the unavailable block (D61).
- **No date field, no 18+ (CR-35, D66, D71):** the sidebar shows "Valid — One time use only, valid for 7 days · use by Wed, Sep 23" from the server `useBy`; the waiver is the only consent gate; the optional marketing box (legal-written TCPA paragraph behind "marketing", D67) records its own `PUT /order {marketingOptIn}` and never gates Pay.
- **Done page (CR-25, D63):** "{name} · use by {date}" and one truthful sentence per delivery status ("Check your email — we've sent your QR access code directly to …"); the QR renderer, "View your pass" page, pass links and resend are removed (`qrcode.react` gone).
- **Decline and reconciliation (U9, U10, D65):** "Payment didn't go through" + "Try another card" (fresh idempotency key, hosted slot, names kept); RECONCILING shows the reference line, "Check again" → `POST …/compensate`, and removes Pay everywhere.
- **Expired saved card (CR-15, U14):** disabled chip "This card has expired", hosted slot auto-selected.
- **Code entry (CR-30, D58):** "Code expires in m:ss" from the server `expiresAt`, "Code expired — request a new one" with Verify held; the 30 s resend cooldown stays separate.
- **Hosting (D60, CR-20):** router base from `window.guestPass.basename` (`/` on the standalone Guest Pass host, `/signup` elsewhere); `/guest-pass` alias; flag hint key `guest_pass_online`; `contractVersion` guard — one restart with a toast, then unavailable.

### Fixes found by the new suites / smoke

- `ShortTermPassPage`: a `contractVersion` mismatch on the first bootstrap never re-bootstrapped after the restart (and the toggling `busy` flag re-bootstrapped over the pending error).
- `.srow.valid .v`: the "Valid" sentence widened the page to 460 px at a 375 px viewport (E2).

### Proof

- Jest: 111 / 112 suites, 775 / 776 tests; the one failure is the pre-existing date-dependent `__tests__/helpers/transformers.test.ts`. Coverage 95.75 % lines / statements (floor 80 / 80). `npm run lint` 0 errors. `npm run build` compiles. `tsc` baseline unchanged (PaymentPage errors pre-existing).
- Static scans in `copy.test.ts` fail the build on any `type="date"`, 18+ / adult term, QR renderer, pass page, pass link or resend surface under `routes/ShortTermPass/**`.
- Local browser smoke (mock adapters, fixture cards, Mailpit): **71 / 71** — `docs/validation/short-term-pass-sprint-0004-smoke.md` §local and `screenshots/sprint-0004/` in the planning repo.

### Not in this PR / verdicts kept separate

Mock proof only. Hosted Pay Page capture unverified locally (B1). Standalone dev host pending helm-configs #3090. Live DataTrak read blocked (CF-13 / CF-14). Not a pilot verdict.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

## online-join-bff — `feat: Guest Pass v1 — contract v4: catalog gate, create → pay → deactivate/revert, RECONCILING + compensate, standalone host, DataTrak adapter (Sprint 0004)`

Branch `prospect-wallet/sprint-0004` → `main`. Next minor by CI (`feat:`).

### What changes (contract v4 — `docs/contracts/short-term-pass-bff.md` in the planning repo)

- **Removed (D63, D66, CR-35):** the pass page and QR (`GET /passes/*` → 404; `qrcode`, `jsqr`, `pngjs` out of the lockfile), pass-link routes and secrets (`STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS`), the visit date and the 18+ term from every schema and snapshot, the CID image part from every email. `rg` proof in the planning repo's blockers file.
- **Catalog gate (CR-28, D61, CR-20):** `POST /checkouts` answers the club's eligible flagged single-visit items in catalog order (`offers[]`, `selectedOfferId`, `contractVersion: 4`); gate = LaunchDarkly `guest-pass-online` (club kind) **and** ≥ 1 eligible item; `STP_CATALOG_SOURCE=fixture | datatrak`.
- **Validity (D71):** the order quotes `useBy = club-local today + contractDays − 1`; Pay recomputes it (409 `CONSENT_REVISION` if the day moved); the pass carries `beginDate` / `expirationDate` / `visits`.
- **Purchase order (D65, CR-12, CR-32, CR-06):** VALIDATED → PERSON_PERSISTED (create or repaint **before** pay, with begin / expiration / visits / opt-in / item) → AUTHORIZED → WALLET_RESULT (save card only after AUTHORIZED) → SALE_FINALIZED → COMPLETE; a confirmed decline deactivates a new record / reverts a repainted one; a failed compensation → `RECONCILING` + `POST …/purchases/:pid/compensate` (owner-only, retries only the pending step) + sweeper; a second Pay is refused while RECONCILING (409 `PURCHASE_IN_PROGRESS`); `purchase.attempt` log without PAN / token / email; 10 purchases per IP per hour.
- **Delivery (D63):** `delivery {status, renderer: 'dt' | 'bff-stand-in'}` — DataTrak renders and sends the QR email in platform mode (`delegated`); mock mode sends a labelled text + HTML stand-in with no image part.
- **Consent (D67):** five documents incl. the versioned `marketing` document; the snapshot records `marketingOptIn {optedIn, templateVersion, renderedHash, at}`; explicit `false` on create / repaint; waiver re-accepted every purchase.
- **OTP (D58, D59, CR-29):** 5-minute code, 2 sends per address per hour; `STP_OTP_TEMPLATE_PATH` template slot (`{{code}}`, `{{clubName}}`), built-in PROPOSED template until Chancy's HTML arrives.
- **Standalone host (D60):** `STP_STANDALONE_HOSTS` — the Guest Pass entry document at `/` and `/guest-pass` with `window.guestPass = {standalone, basename}`, membership paths and non-guest-pass APIs answer a generic 404; `app.proxy` unchanged.
- **DataTrak service-layer catalog adapter (CR-31):** `DatatrakServiceCatalog` (`getClubDefaultExternal.spr`, `saleItems.spr`), 60 s cache incl. failures, fails closed per club, unit-pinned against recorded + labelled synthetic fixtures; the live read is **blocked** (CF-13 fields absent, CF-14 member-scoped query).
- **Production guard:** refuses `STP_CATALOG_SOURCE=fixture` and `STP_MOCK_OTP_CODE`; datatrak needs an https URL and the credential; testing routes stay loopback-only.

### Proof

- Jest: 68 / 68 suites, 698 tests (2 skipped); coverage 97.42 / 85.98 / 97.13 / 98.26 against the 84 / 67 / 67 / 84 floors. `eslint` clean; `tsc --noEmit` clean for `src` and `scripts`.
- `npm run demo:short-term-pass`: Demo 0–6, **58 / 58** checks (transcript in the planning repo's demo doc).
- Local browser smoke through the UI PR: 71 / 71 (mock).

### New / changed env keys

`STP_CATALOG_SOURCE`, `STP_DATATRAK_SERVICE_URL`, `STP_DATATRAK_SERVICE_AUTH` (secret), `STP_DATATRAK_CACHE_SECONDS`, `STP_STANDALONE_HOSTS`, `STP_OTP_TEMPLATE_PATH`; removed `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS` (helm-configs #3090 carries the dev values).

### Verdicts kept separate

(1) implementation and mock acceptance — done; (2) standalone dev host — pending #3090; (3) live integration — DataTrak read blocked, prospect writes mock only (platform `ProspectPort` `notEnabled`, CF-15), hosted capture unverified locally (B1); (4) pilot — not eligible.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
