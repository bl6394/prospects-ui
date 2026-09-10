# Semantic Index Configuration

## Token Cache

The token cache is the full local materialization of the project context.
Tools like `rg`, `find`, `grep`, and `wc` operate on it directly.

**Remote source**: GitHub — `abcfinancial/mico`, `abcfinancial/online-join-ui`, `abcfinancial/online-join-bff` (this project), plus the wallet stack `abcfinancial2/universal-wallet`, `abcfinancial/commerce-universal-wallet-sdk`, `abcfinancial/wallet-account-sync`, `abcfinancial/wallet-service`, `abcfinancial2/platform-devtools`, `abcfinancial/spring-cloud-config@develop`
**Remote type**: `git`
**Local path**: two roots, both already materialized
- `/Users/bjornloftis/claudeprojects/prospects-ui/repos/` — `mico/`, `online-join-ui/`, `online-join-bff/` (gitignored in this repo; cloned 2026-09-09)
- `/Users/bjornloftis/claudeprojects/wallet-repos/` — wallet services and platform infra (cloned 2026-09-08)
**Sync command**:
```
for d in /Users/bjornloftis/claudeprojects/prospects-ui/repos/* /Users/bjornloftis/claudeprojects/wallet-repos/*; do [ -d "$d/.git" ] && git -C "$d" pull --ff-only; done
```
**Token cache scope**: the legacy MICO online-join monolith (Spring Boot, `/iclub`), the split-out Online Join React UI and its Koa BFF, and the Universal Wallet stack that prospect wallets will be keyed into. `mico/` is a reference surface only for the Day Pass sprint; changes land in `online-join-ui/` and `online-join-bff/`. `mico/src/main/webapp` is a large legacy jQuery/steal.js tree — search it with `rg` narrowly, never scan it whole.

## Semantic Index

The semantic index is a routing tree built over the token cache.
Use it to retrieve relevant citations without scanning the full token cache.

**Status**: Available (partial — covers `wallet-repos/` only; the three online-join repos are not yet indexed)
**Local path**: `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/`
**Entrypoint**: `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/README.md`
**Access**: Read the entrypoint, follow routing nodes (`themes/`, `repos/`, `devtools/`, `config/`), open leaf citations.
Citations in leaf files resolve to paths under `/Users/bjornloftis/claudeprojects/wallet-repos/`.
Most relevant routes for prospect/day-pass work: `themes/identity-by-member-id.md`, `themes/agreement-number-and-prosp.md`, `themes/dt-to-wallet-sync.md`, `themes/feature-flags.md`.

For `online-join-ui/`, `online-join-bff/`, and `mico/` there is no index yet; use `rg` directly against `/Users/bjornloftis/claudeprojects/prospects-ui/repos/`.

**Sprint 0001 code (branch `prospect-wallet/sprint-0001` in both online-join repos, 2026-09-09/10, unindexed):**
- BFF — `online-join-bff/src/routes/shortTermPass/` (router, `schemas.ts` contract, checkouts/identify/challenge/verify/wallet/order/purchase/session routes, HTTP harness under `testing/`), `src/services/shortTermPass/` (config, errors, http, log, contact, challenge, identify, person, order, wallet, idempotency, purchaseOrchestrator; `ports/*`, `adapters/{mock,platform}/*`, `fixtures/*`), `src/services/platform/{oauthToken,locationResolver}.ts`, `src/services/payPage/{client,sessionOwnership}.ts`, `src/utils/middlewares/{requireShortTermPass,csrf,originAllowlist,rateLimit}.ts`, `scripts/short-term-pass-demo.ts`.
- UI — `online-join-ui/src/routes/ShortTermPass/` (page, `steps/`, `components/`, `hooks/`, `format.ts`), `src/routes/SignupShell.tsx`, `src/reducers/shortTermPass/shortTermPassSlice.ts`, `src/selectors/shortTermPass.ts`, `src/services/shortTermPass.ts`, `src/interfaces/api/shortTermPass.ts`, `src/components/dt/*`, `src/styles/short-term-pass.scss`; tests under `__tests__/routes/ShortTermPass/**`, `__tests__/reducers/shortTermPass/`, `__tests__/selectors/`, `__tests__/services/shortTermPass.test.ts`.
- Planning deliverables — `docs/contracts/short-term-pass-bff.md`, `docs/demos/short-term-pass-local-demo.md`, `docs/validation/short-term-pass-{bff,ui}.md`, `docs/sprints/drafts/SPRINT-0001-{BLOCKERS,EXECUTION-SUMMARY}.md`.

To extend: run `/df-semantic-index /Users/bjornloftis/claudeprojects/prospects-ui/repos /Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index` in upsert mode.

## Related planning context

- `/Users/bjornloftis/claudeprojects/prospects1/docs/prd/short-term-passes-prospect-identity-prd.md` — consolidated Short-Term Passes & Prospect Identity PRD
- `/Users/bjornloftis/claudeprojects/prospects1/docs/prd/prospect-wallet-plan-v2.md` — backend Prospect Wallet plan (wallet-account-sync / universal-wallet)
- `/Users/bjornloftis/claudeprojects/prospects1/docs/sprints/SPRINT-0001.md` — backend sprint that makes the wallet repos prospect-safe
- `docs/prd/day-pass.html` (this repo) — interactive Day Pass single-flow prototype; the UI requirements source
