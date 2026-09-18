# Sprint 0004 — UI lane execution summary (`online-join-ui`, branch `prospect-wallet/sprint-0004`, PR #532)

Executor: Claude Fable 5.1 (the resumed executor session ran C1–C9 on top of C0), 2026-09-18. Version line `8.33.0-daypass.N` (CI bumps from the `feat:` title).

## Commits (after A3/A4 `38777e9`)

| Commit | Task | What landed |
|---|---|---|
| `5b6e541` | C0 | Removal: pass page, `PassCredential` / `PassReceipt`, `qrcode.react`, date field, 18+; v6 components (cards with `validityLine`, Valid row from `useBy`, waiver + marketing block, v6 pass block, decline / RECONCILING blocks, expired chip, expiry countdown, `/guest-pass` route + host-aware basename, `guest_pass_online`, `contractVersion` guard, compensate thunk) |
| `2aa81d0` | C1 | Slice / selector / service / format tables re-pinned to v4; `shortTermPassSliceV4.test.ts` replaces the v3 suite; `App.test.tsx` alias + standalone host |
| `d909696` | C2 | `OfferCards.test.tsx` — three Core cards, single Riverside card, PUT /offer + toast, no perks |
| `54332b2` | C3 | `OrderSummary.test.tsx` — Valid row, `.agree` order, Pay gates, Receipt without a link, no Pay while RECONCILING |
| `d54ae0a` | C4 | `MarketingOptIn.test.tsx` (own PUT, TCPA document dialog, never a gate); `NewVisitorStep.test.tsx` (opt-in in the sidebar, no 18+) |
| `42cedfe` | C5 | `PassBlock.test.tsx`, `DoneStep.test.tsx` — truthful delivery sentences, decline → "Try another card", RECONCILING → "Check again" |
| `8792f95` | C6 | `SavedCardChip.test.tsx`; Priya's expired-only wallet on `RecognizedStep.test.tsx` |
| `62ac29a` | C7 | `InlineCodeEntry.test.tsx` — "Code expires in m:ss" → "Code expired — request a new one"; `IdentifyStep.test.tsx` v6 cards |
| `0c920fa` | C8 | **Fix:** `contractVersion` restart re-bootstraps once (effect keyed on `epoch`, skips while an error is pending); `hosting.test.ts`, `ShortTermPassPage.test.tsx` (flag hint, alias, standalone host, zero offers, 409 `details.contractVersion`) |
| `72279b8` | C9 | `copy.test.ts` v6 table + static scans (no `type="date"`, no 18+ / adult, no QR / pass page / link / resend); `layout.test.ts` v6 guards |
| `4d5a8e8` | E2 fix | `.srow.valid .v` wraps — the Valid sentence widened the page to 460 px at 375 px |
| `80495fb` | CI | bump job: `8.33.0` (finalised the prerelease) |
| `e62a67c` | version | `8.34.0-daypass.1` — the daypass prerelease line restored (as #525 did) |
| `3435039` | Sonar | S5852 (`resolveBasename` loop), S7764 (`globalThis.featureFlags`), S6772 (sentence period) |

## Proof

- `npx jest` (coverage on): 111 / 112 suites, 775 / 776 tests — the one failure is the pre-existing date-dependent `__tests__/helpers/transformers.test.ts`; `OfferDetails.test.tsx` (intermittent baseline) passed this run. Coverage 95.75 % lines / statements (floor 80 / 80).
- `npm run lint` (`eslint src/`): 0 errors (warnings pre-existing). `npm run build`: compiles. `tsc --noEmit -p tsconfig.json`: the pre-existing PaymentPage / two payment-test errors only (Sprint 0003 baseline); the Sprint 0004 files are clean.
- Static scans: `copy.test.ts` walks `routes/ShortTermPass/**` — no `type="date"`, no "18 or older" / `ADULT_` / `adult:`, no `qrcode.react` / `PassCredential` / `PassViewPage` / `PassReceipt` / `viewPath` / `pv1.` / "View your pass" / "Resend pass email"; the three v3 files are absent.
- E2 browser smoke 71 / 71 (mock) with screenshots — `docs/validation/short-term-pass-sprint-0004-smoke.md`.

## Decisions taken in the lane

1. On the existing host the router base stays `/signup`, so the checkout paths are `/signup/day-pass` and `/signup/guest-pass`; the bare `/guest-pass?club=` entry document still renders (history strips no base) and the standalone host mounts at `/`.
2. The design HTML (`day-passv6.html`) still contains an "18 or older" string; the static scan covers the UI source only.
3. Test-file style is not linted by `npm run lint` (`src/` only); authored suites were `eslint --fix`ed, `App.test.tsx` kept its semicolon style.

## Known limitations

Hosted Pay Page embed unverified locally (fixture panel stands in). A hosted-card checkout on the standalone host was not run (saved card was). Baseline failures listed by name above.
