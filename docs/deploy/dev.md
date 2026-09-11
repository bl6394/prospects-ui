# Day Pass checkout — dev environment deployment

**Status (2026-09-11):** first dev deployment in progress from branch `prospect-wallet/sprint-0001` in both repos (prerelease builds, PRs #96 / #524 stay open). Feature is dark for real clubs.

## How the two apps deploy

| App | Artifact | Publish | Deploy to an environment | Runtime config |
|---|---|---|---|---|
| `online-join-bff` | container image `node_images/online-join-bff:v<package.json version>` (Harbor) | workflow **Publish release** (`release.yml`; on push to `main` or manual dispatch on any ref) → also creates the GitHub release/tag | workflow **Deploy Container: ENV** (`deployment-env.yml`, manual, input `environment`, run on the **tag** ref) → shared `nodejs-deploy-container-env.yml` → helm on EKS | `abcfinancial2/helm-configs` `online-join-bff/{default,dev}.yaml` (read from that repo's default branch `master` at deploy time); secrets from k8s secret `platform-online-join-bff` |
| `online-join-ui` | npm package `@abc/online-join-ui@<version>` in Artifactory (`abc-npm-internal`), built `public/` inside | workflow **Publish release** (`release.yml`) | workflow **Deploy to CDN: ENV** (`deployment-env.yml`) → shared `nodejs-deploy-cdn-env.yml` → `aws s3 cp` of `package/public/` to `s3://abcfinancial-<env>-cdn/online-join-ui/` | none; the BFF reads `online-join-ui/assets-manifest.json` from the CDN every 60 s |

Dev host: `https://onlinejoin.dev.abcfitness.net` (ingress `internal`, k8s namespace `dev`, `NODE_ENV=dev`). MICO for the proxy: `http://mico:8080/iclub/` in-cluster. Pay Page dev: `https://qa.30preprod.com/api` with the `PAY_PAGE_*` values in `dev.yaml` and the secret.

GitHub environments: BFF `dev, dev-dal, qa, beta, beta-dal, staging, staging-dal, prod, prod-dal`; UI `dev, qa, beta, staging, prod`. Neither `dev` environment has protection rules.

## Why a prerelease from the branch

The PR CI's "Bump package version" job fails because the PR titles are not Conventional Commits, so the PRs cannot merge yet, and `main` builds only publish what is on `main`. Decision (user, 2026-09-11): build prerelease versions from the branch instead — BFF `1.2.0-daypass.1`, UI `8.33.0-daypass.1` — and deploy those tags to dev. On merge the PR CI bumps the versions normally.

## What had to change for dev

- **BFF `STP_NON_PRODUCTION`** (commit `53e549e`): `isProduction` is `NODE_ENV !== 'development'`, so the dev cluster counted as production and the boot guard refused mock adapters, test hooks and the flag override. The new switch declares a cluster non-production for this feature only; it is ignored when `NODE_ENV=production`. Cookie/proxy behaviour unchanged.
- **helm-configs PR:** https://github.com/abcfinancial2/helm-configs/pull/3083 adds to `online-join-bff/dev.yaml`: `STP_NON_PRODUCTION=true`, `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=paypage`, `STP_EMAIL_TRANSPORT=mock`, `STP_TEST_HOOKS=true`, `STP_TEST_HOOKS_KEY=<dev key>`, `STP_LOCAL_FLAG_OVERRIDE=true` (temporary), `STP_ALLOWED_ORIGINS=https://onlinejoin.dev.abcfitness.net`, `STP_SESSION_SECRET`, `STP_CODE_SECRET` (random dev-only values). Must merge before the BFF deploy.

## Deploy steps (tags from the branch builds)

1. Wait for **Publish release** on `prospect-wallet/sprint-0001` in both repos (runs started 2026-09-11 17:33/17:34 UTC). They create tags `v8.33.0-daypass.1` (UI) and `v1.2.0-daypass.1` (BFF).
2. Merge helm-configs PR #3083.
3. BFF: dispatch `deployment-env.yml` with `ref=v1.2.0-daypass.1`, `environment=dev`.
4. UI: dispatch `deployment-env.yml` with `ref=v8.33.0-daypass.1`, `environment=dev`.
5. Smoke (see below).

API form of a dispatch (token needs `workflow` scope):
```
POST /repos/abcfinancial/<repo>/actions/workflows/deployment-env.yml/dispatches
{"ref":"<tag>","inputs":{"environment":"dev"}}
```

## Smoke checks after deploy

```
# entry renders with the flag serialized (override on in dev)
curl -s -H 'Accept: text/html' 'https://onlinejoin.dev.abcfitness.net/signup/day-pass?club=90030' | grep -o 'oj_short_term_pass_checkout[^,}]*'
# checkout creation
curl -s -i -X POST -H 'Content-Type: application/json' -H 'Origin: https://onlinejoin.dev.abcfitness.net' \
  -d '{"clubNumber":"90030"}' https://onlinejoin.dev.abcfitness.net/api/short-term-pass/checkouts | head -20
# existing signup still fine
curl -s -o /dev/null -w '%{http_code}\n' -H 'Accept: text/html' 'https://onlinejoin.dev.abcfitness.net/signup/plan?club=09003'
```
Browser: `https://onlinejoin.dev.abcfitness.net/signup/day-pass?club=90030`. Returning visitor fixture: `jordan.reyes@email.com` / `(555) 019-2231`. One-time codes: `GET /api/short-term-pass/testing/outbox` with header `X-STP-TEST-KEY: <dev key>` (key value is in the helm PR; also kept in the session scratchpad, not in this repo). Hosted card capture is real Pay Page dev; use Pay Page test cards.

## Rollback

BFF: dispatch **Deploy Container: ENV** on the previous tag (last dev deploy before this was `v1.1.4`, 2026-07-22). UI: dispatch **Deploy to CDN: ENV** on the previous tag (`v8.31.6`, 2026-07-08). Removing the `STP_*` block from `dev.yaml` (or unsetting `STP_ADAPTER_MODE`) disables the feature without a code rollback: every pass route then answers 404.

## Open items

- LaunchDarkly flag `oj-short-term-pass-checkout` (club kind, default off) still does not exist in the dev project; `STP_LOCAL_FLAG_OVERRIDE=true` stands in for it and must be removed when the flag lands.
- Dev email-publisher returned 503 (Sprint 0002); codes are read from the outbox until it works, then switch `STP_EMAIL_TRANSPORT=publisher` with `STP_EMAIL_PUBLISHER_URL`, `STP_EMAIL_PUBLISHER_AUTH`, `STP_EMAIL_SENDER`.
- PR titles need Conventional Commits (`feat: …`) for the bump job before merging to `main`.
- In-memory checkout / purchase / rate-limit stores: one replica in dev (`replicaCount: 1`), fine for testing; a shared store is a live-enablement gate (L4).
