# Sprint 0002 — blockers, deviations and notes from execution

Executor: Claude Fable 5.1, 2026-09-10 (single detached session). Branches `prospect-wallet/sprint-0001` in `repos/online-join-ui` and `repos/online-join-bff` (product commits only; not pushed — the orchestrator pushes after review). Planning-repo deliverables left uncommitted.

## Blockers

### B1 — Pay Page dev credentials still absent (E3, gate S5)

Checked by key name at the start of execution: none of `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN`, `ABC_CORE_API_URL` is present in `repos/online-join-bff/.env` (22 lines; the sprint 0001 `STP_*` values are). Effect: the hosted proof (E3) cannot run; gate S5 is *pending* and the register reads "hosted capture unverified (B1)". Everything else — `captureMode` default `paypage`, the `onReady`-driven readiness, Retry, `TestCardPanel` behind hooks, membership regression — is implemented and test-pinned. To unblock: add the six keys (values from the team's secret store), then run the E3 command list in the execution summary.

## Notes and citations relied on

- Index leaves consulted before Phase B/C (as instructed): `themes/identity-by-member-id.md` (owner `(externalId = member UUID, MEMBER, org)`; email/phone never identity — B1 verify binds the member only after the code is consumed), `themes/agreement-number-and-prosp.md` hazards #1/#4/#5/#10/#11 (`OWNER_METADATA_FORBIDDEN` unchanged; `STP_WALLET_WRITES` stays false until the dedup-key fix ships — hazard #10 is the exact reason), `repos/universal-wallet/walletentry/credit-card.md` + `commerce-universal-wallet-sdk` `CreditCardRequestVO.java` (`private UUID providedId` → B6 allocates `walletProvidedId = randomUUID()`; entry `metadata` is a free key/value map → `oj_*` allowlist), `themes/feature-flags.md` (club-kind context, fail-closed; untouched by B5).
- Prior art read before changing it: `PaymentPageWithPayPage.tsx` / `PayPageEmbed.tsx` (SDK `onLoad` → `rendered`; `submit()` rejects until rendered), Sprint 0001 `identify.ts` (lookup before code), `wallet.ts` (`providedId = purchaseId`), `config.ts` (capture default mock in mock mode), `scripts/short-term-pass-demo.ts` (`debug.code` dependency), `setSecurityHeaders.ts` (CSP allows Google Fonts — left as is: the pass page no longer requests them; the allowlist entries also serve other pages and are not this sprint's to remove).

## Phase A notes

- **husky:** `npm run prepare` (husky 9, `husky install` deprecation notice) created `.husky/_` in the BFF clone; `lint-staged` (prettier + eslint --fix) now runs on every BFF commit.
- **Inter:** the four latin woff2 files come from `@fontsource/inter@5.3.0` (SIL OFL 1.1; licence copied to `src/assets/fonts/LICENSE-Inter-OFL.txt`), fetched with `npm pack` — no dependency added to the UI. `@font-face` rules sit at the stylesheet root (Sass does not bubble them); the isolation test now allows `@font-face` (only) at the root and asserts no third-party font host is referenced.
- **Contract v2 artefacts:** the prose contract (`docs/contracts/short-term-pass-bff.md` §4 v2) is written in Phase A; the `schemas.ts` / `interfaces/api/shortTermPass.ts` rewrites land with the first Phase B and Phase C commits respectively so that every product commit builds and its suite is green. A2's "both repos type-check against v2" is met at those commits.
- **`createOrderShell` `saveCard:false`** (A3) is applied in B3 together with the consent model, for the same reason (the Sprint 0001 order/purchase suites assert the old default).
- **Fixture twin:** `m@m.com` Jordan is homed at 90033 only (`JORDAN_CORE_TWIN`, fixed UUID `7a8b9c0d-…`), with a seeded Visa 4242 owner in the Core organisation; Riverside data is unchanged. `MockWallet` seed counts moved from 4/4 to 5/5 owners/entries.
- **Core legal name:** `CatalogClub.legalName` ('Core Health and Fitness Club') added so documents read exactly as v1.2 (`CLUB` constant) while the header keeps the location suffix.

## Scope changes

(recorded as they occur; see also the execution summary)
