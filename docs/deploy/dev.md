# Guest Pass (short-term pass) checkout — dev environment deployment

**Status (2026-09-18, Sprint 0004 D1):** dev runs online-join-bff **v1.2.3** (contract v3, mock adapters, `STP_MOCK_OTP_CODE` pinned by helm-configs #3088, deployed) and the UI 8.33.0-daypass.2 line. The Sprint 0004 (contract v4) builds are on the `prospect-wallet/sprint-0004` branches and reach dev only after their PRs merge to `main` (E5). helm-configs **PR #3090** (https://github.com/abcfinancial2/helm-configs/pull/3090, signed, not merged by the executor) adds the standalone Guest Pass host and the v4 keys; its values apply on the next dev deploy of the BFF. Sections marked *E3 result* are filled in by the dev smoke.

## How the two apps deploy

| App | Artifact | Publish | Deploy to an environment | Runtime config |
|---|---|---|---|---|
| `online-join-bff` | container image `node_images/online-join-bff:v<package.json version>` (Harbor) | workflow **Publish release** (`release.yml`; on push to `main` or manual dispatch on any ref) → also creates the GitHub release/tag | `deployment.yml` on `release: [released]` runs the shared promotion pipeline: **dev deploys automatically**, then waits for the `staging` environment approval; the manual **Deploy Container: ENV** (`deployment-env.yml`, input `environment`, run on the tag ref) re-deploys after a helm-configs change (values are read from `helm-configs` `master` at deploy time) | `abcfinancial2/helm-configs` `online-join-bff/{default,dev}.yaml`; secrets from k8s secret `platform-online-join-bff` |
| `online-join-ui` | npm package `@abc/online-join-ui@<version>` in Artifactory (`abc-npm-internal`), built `public/` inside; prerelease line `8.33.0-daypass.N` under dist-tag `daypass` | **Publish release** (`release.yml`) | promotion pipeline → **Deploy to CDN: ENV** (`aws s3 cp` of `package/public/` to `s3://abcfinancial-<env>-cdn/online-join-ui/`) | none; the BFF reads `online-join-ui/assets-manifest.json` from the CDN every 60 s |

Dev hosts: `https://onlinejoin.dev.abcfitness.net` (existing; ingress `internal`, namespace `dev`, `NODE_ENV=dev`) and, after #3090 deploys, `https://guestpass.dev.abcfitness.net` (same ingress object, same BFF; `STP_STANDALONE_HOSTS`). Pay Page dev: `https://qa.30preprod.com/api` with the `PAY_PAGE_*` values in `dev.yaml` and the secret. MICO for the membership proxy: `http://mico:8080/iclub/` in-cluster (not used by the Guest Pass routes).

**Every publish from a branch must be cancelled at the staging gate** (or the approvers told to reject). Never approve a `-daypass.*` build into staging. PR titles must be Conventional Commits (`feat: …`) — the "Bump package version" job derives the version from them and CI is skipped when it fails; a successful bump pushes a version commit to the branch (pull before touching it locally).

## What changes for Sprint 0004 (contract v4)

| Where | Change | State |
|---|---|---|
| helm-configs `online-join-bff/dev.yaml` (PR #3090) | second host `guestpass.dev.abcfitness.net` on `ingress[0]` hosts + tls (`dev-wildcard`); `STP_STANDALONE_HOSTS=guestpass.dev.abcfitness.net`; `STP_ALLOWED_ORIGINS` both origins; `STP_CATALOG_SOURCE=fixture`; **removed** `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS`; comment block for Guest Pass and the `guest-pass-online` flag key | PR opened 2026-09-18; **not merged** |
| BFF | contract v4 build (`prospect-wallet/sprint-0004`): retired pass routes → 404; `STP_STANDALONE_HOSTS`; `STP_CATALOG_SOURCE`; production guard refuses `fixture` and `STP_MOCK_OTP_CODE`; OTP 5 min / 2 sends | PR #107 opened 2026-09-18 (not merged) |
| UI | contract v4 build: `/guest-pass` route; router base from `window.guestPass.basename`; flag key `guest_pass_online` | PR #532 opened 2026-09-18 (not merged) |
| LaunchDarkly | flag `guest-pass-online` (club kind, default off) in dev and prod replaces the never-created `oj-short-term-pass-checkout`; `STP_LOCAL_FLAG_OVERRIDE=true` stands in until then | PLATFORM ticket (D3) — pending |
| Secret `platform-online-join-bff` | `STP_DATATRAK_SERVICE_URL`, `STP_DATATRAK_SERVICE_AUTH` when `STP_CATALOG_SOURCE=datatrak` becomes possible (CF-13 / CF-14) | PLATFORM ticket (D3) — pending on the DT PR |

Merge order does not matter: the v1.2.3 BFF ignores the two new keys and still reads the three removed ones as optional; the v4 BFF ignores leftover pass-link keys.

## D2 — DNS / TLS / host check after #3090 deploys

```
# DNS: external-dns should publish the new host to dev-global.abcfitness.net like the existing one
dig +short guestpass.dev.abcfitness.net
dig +short onlinejoin.dev.abcfitness.net
# TLS: dev-wildcard must cover the host (no certificate warning, SAN *.dev.abcfitness.net)
echo | openssl s_client -servername guestpass.dev.abcfitness.net -connect guestpass.dev.abcfitness.net:443 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName
# Entry document on the standalone host (v4 BFF only; v1.2.3 answers the membership entry document)
curl -s -H 'Accept: text/html' 'https://guestpass.dev.abcfitness.net/?club=90030' | grep -o 'guestPass[^}]*}'
curl -s -o /dev/null -w '%{http_code}\n' -H 'Accept: text/html' 'https://guestpass.dev.abcfitness.net/signup/plan'   # 404 on the standalone host (v4)
curl -s -o /dev/null -w '%{http_code}\n' -H 'Accept: text/html' 'https://onlinejoin.dev.abcfitness.net/signup/plan?club=09003'  # 200 unchanged
```

*E3 result:* pending (PR #3090 not merged at the time of writing).

## Smoke checks (existing host, any BFF version)

```
# entry renders with the flag serialized (override on in dev): v3 key oj_short_term_pass_checkout, v4 key guest_pass_online
curl -s -H 'Accept: text/html' 'https://onlinejoin.dev.abcfitness.net/signup/day-pass?club=90030' | grep -o 'short_term_pass_checkout[^,}]*\|guest_pass_online[^,}]*'
# checkout creation
curl -s -i -X POST -H 'Content-Type: application/json' -H 'Origin: https://onlinejoin.dev.abcfitness.net' \
  -d '{"clubNumber":"90030"}' https://onlinejoin.dev.abcfitness.net/api/short-term-pass/checkouts | head -20
# existing signup still fine
curl -s -o /dev/null -w '%{http_code}\n' -H 'Accept: text/html' 'https://onlinejoin.dev.abcfitness.net/signup/plan?club=09003'
```

Browser: `https://onlinejoin.dev.abcfitness.net/signup/day-pass?club=90030` (v4 also `/signup/guest-pass?club=90030`; standalone `https://guestpass.dev.abcfitness.net/?club=90030`). Returning fixtures: Riverside `jordan.reyes@email.com`; Core South (`club=90033`) `m@m.com` (Kelly) and `priya@example.com` (expired card). One-time code: the value pinned by `STP_MOCK_OTP_CODE` in `dev.yaml` (never written into this repo). Hosted card capture is real Pay Page dev — use Pay Page test cards.

## Reading state in dev (hooks are loopback-only by design)

The testing routes answer 403 through the ingress. Port-forward to the pod and call them on loopback (verified 2026-09-18, contract §8a(c)):

```
kubectl --context k8s-lower-wlr -n dev port-forward deploy/online-join-bff 18080:8080
curl -H "X-STP-TEST-KEY: $KEY" 'http://127.0.0.1:18080/api/short-term-pass/testing/state?checkoutId=<id>'
curl -H "X-STP-TEST-KEY: $KEY" 'http://127.0.0.1:18080/api/short-term-pass/testing/outbox?checkoutId=<id>'
```

`$KEY` is `STP_TEST_HOOKS_KEY` from `dev.yaml` (read it with `awk` into a variable; never echo it). No policy change: the browser never reads `/testing/*` through the ingress (Q8).

## Rollback

BFF: dispatch **Deploy Container: ENV** on the previous tag (`v1.2.3` is the current dev tag; before it `v1.2.0-daypass.1`, `v1.1.4`). UI: dispatch **Deploy to CDN: ENV** on the previous tag (`v8.33.0-daypass.2`; before the Day Pass line `v8.31.6`). Removing the `STP_*` block from `dev.yaml` (or unsetting `STP_ADAPTER_MODE`) disables the feature without a code rollback: every pass route then answers 404. Reverting #3090 removes the standalone host and restores the three pass-link keys (harmless to the v4 BFF).

## Open items

- LaunchDarkly flag `guest-pass-online` does not exist; the override stands in and must be removed when it lands (CF-17, D3).
- `STP_CATALOG_SOURCE=fixture` in dev until the DataTrak service layer exposes the guest-pass fields (CF-13) and a member-less query (CF-14); then `datatrak` + the credential secret.
- Dev email transport is `mock`; the pinned code replaces reading the outbox. The publisher path (`STP_EMAIL_TRANSPORT=publisher`) returned 503 in Sprint 0002 and is unverified.
- Dev values file carries secrets in plain text (pre-existing; not changed by this sprint) — PLATFORM housekeeping row.
- In-memory checkout / purchase / rate-limit / compensation stores: one replica in dev is fine; a shared store is a pilot gate (V-P1d).
