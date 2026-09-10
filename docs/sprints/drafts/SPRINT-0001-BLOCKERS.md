# Sprint 0001 — blockers, deviations and notes from execution

Executor: Claude Fable 5.1, 2026-09-09. Branches `prospect-wallet/sprint-0001` in `repos/online-join-ui` and `repos/online-join-bff` (not pushed).

## Blockers

### B1 — Pay Page dev credentials are not available locally (A6(a), E1 hosted run, gate G4)

The payPage route reads `PAY_PAGE_API_URL`, `PAY_PAGE_CLIENT_ID`, `PAY_PAGE_CLIENT_SECRET`, `PAY_PAGE_CONSUMER_ID`, `PAY_PAGE_ORIGIN` and `ABC_CORE_API_URL` from `process.env`. None of these keys are present in `repos/online-join-bff/.env`, in `.env.example`, or in the environment of the dev BFF process listening on :3000 (checked by key names only; no values were printed). The prompt stated the credentials were available; they are not in this checkout. Effect: the real hosted-capture run (session create → embed → submit → poll → BFF re-read) cannot be executed here. The platform `PayPageSessionReader` adapter is implemented and unit-tested against the documented session shape; G4 is reported as "mock demo complete; hosted capture unverified". To unblock: add the six variables to the BFF `.env` (values from the team's secret store) and run `npm run demo:short-term-pass -- --hosted`.

### B2 — LaunchDarkly flag `oj-short-term-pass-checkout` does not exist (A6(c), handoff)

Verified with the dev SDK key: `boolVariationDetail` returns `FLAG_NOT_FOUND` → default `false`. The gate fails closed as designed. A human with LaunchDarkly write access must create the flag (club kind, default off) before any environment can turn the feature on. Local development uses `STP_LOCAL_FLAG_OVERRIDE=true`.

## Pre-existing defects found (not fixed beyond what the sprint needs)

- **`rawBodyCapture` breaks JSON bodies for every `/api/*` route except `/api/pay-page/`.** The middleware drains the request stream to capture `rawBody` and koa-bodyparser then throws `stream is not readable` (500). Verified against the running dev BFF: `POST /api/online-join/club/getClub` with a JSON body returns 500. The MICO proxy reads `rawBody`, so proxied POSTs presumably still work only when bodyparser is skipped or fails silently; a JSON POST through the proxy answers 500 today. This sprint exempts `/api/short-term-pass/` the same way `/api/pay-page/` is exempted (commit "Phase B"); the general fix is left for the team.

## Notes and citations relied on

- Wallet identity rules: `themes/identity-by-member-id.md`, `repos/universal-wallet/identity/owner.md` (owner keyed `(externalId, ownerType, org)`, `locationId` required for non-ORGANIZATION owners, create validation ignores metadata), `repos/universal-wallet/walletentry/credit-card.md` (`pgToken @NotNull`, `ownerIds`, `providedId`, `GET /wallet-entry/credit-card?q=`), `themes/agreement-number-and-prosp.md` hazards #1, #4, #5, #10, #11 (never send `dt_agreementNumber` / `dt_memberNumber` / `dt_memberOrdinal` for a prospect owner; `STP_WALLET_WRITES` stays false until the backend sprint fixes the dedup key calculator).
- Toolkit typings inspected: `node_modules/@abc/bff-toolkit/dist/types/clients/UniversalWallet.d.ts` (`getAllWalletEntries`, `getWalletOwners`, `createWalletOwner`, `createCreditCard`; `getWalletEntries` deprecated QA-only), `@abc/shared-types` `ICreateWalletOwner`, `ICreateWalletCreditCard`, `IAddTokenSession`.
- Pre-existing repo state: the UI suite has one failing test unrelated to this sprint (`__tests__/helpers/transformers.test.ts` "transformAgreement builds the agreement payload using today payment info" — month label depends on the machine timezone: expected "June", received "May"). The UI has 25 lines of pre-existing `tsc --noEmit` errors in PaymentPage / PayPageEmbed tests; the production build uses babel and does not type-check. Neither was touched.
- Platform wallet adapter uses `fetch` + the shared OAuth client-credentials token service rather than the toolkit `universalWallet` client: this BFF never bootstraps the toolkit's platform auth (`authorization.initialize` is not called; `healthCheck.validateAuthorities` is commented out), so the toolkit client cannot be used without adding that bootstrap. Same pattern as the payPage route. The owner-scoped rsql attribute path (`OWNER_SCOPED_CREDIT_CARD_QUERY`) is isolated and marked as L3 evidence.
- Cookie `Secure` attribute follows `ctx.secure` (the `cookies` library refuses Secure cookies on plain HTTP); real production (`NODE_ENV=production`) refuses to start a checkout over an insecure connection.
- BFF `tsconfig` extends `@abc/ui-configs/typescript/tsconfig-node.json` with `erasableSyntaxOnly: true`: no `enum`, `namespace` or parameter properties in new code (`as const` unions used instead).

## Phase C notes (executor session 2, 2026-09-09)

- Phase B was found committed (`b76de82`); no uncommitted work. Phase C was executed against the revised plan and the Riverside addendum.
- **Fixture change (addendum):** `90030` is now Riverside Athletic Club (USD 18.00 "1-day pass", no perks); Jordan Reyes' email is `jordan.reyes@email.com` (mask `j•••••@email.com`). `90031`/`90032` stay as closed / club-authored-terms Riverside locations; Core Health and Fitness Club — South moved to `90033` in a second fixture organization with the USD 25.00 "Gym Floor" offer. Phase B tests were updated for the new values; nothing else in phase B changed.
- **Visit date default:** the order shell now carries `visitDate = club-local today` (created on verify and on the new-visitor identify outcome); `PUT /order` still changes it. The harness clock is `2026-09-09T15:00Z` so the default is `2026-09-09` in every fixture timezone.
- **Rule 8 payload scan interpretation:** the recursive scan of upstream payloads treats `PROSP` as the datatrak placeholder agreement token and matches it word-bounded (`/\bPROSP\b/`). `dt_memberType: 'PROSPECT'` is required by rule 4 and must not trip the scan; the test says so inline.
- **Wallet-retry ownership:** a purchase may be retried from the checkout that created it, or from any later checkout whose *verified* member id matches the purchase (so a new visitor whose card save failed re-verifies by their persisted contact and retries). Anyone else sees 404.
- **Terms version change:** `PUT /order` compares the stored terms version with the catalog's current version; a change clears acceptance and refuses the acceptance in that request with 409 `STATE_CONFLICT` (message "The Terms & conditions have been updated…"). Unreachable with the fixture catalog; unit- and route-tested with a stubbed catalog.
- **Concurrency test:** mock adapters resolve in microtasks, so two "concurrent" HTTP requests would otherwise run back-to-back; the test slows `authorize` by 40 ms to prove the atomic one-active-attempt lock (`PURCHASE_IN_PROGRESS`, `Retry-After: 2`).
- **Harness timeout:** HTTP-level suites set `jest.setTimeout(30_000)`; under full parallel coverage the first request of three suites exceeded jest's 5 s default on this machine (they passed alone). No thresholds or exclusions touched.
- Index citations relied on in phase C: `repos/universal-wallet/walletentry/credit-card.md` (`pgToken @NotNull`, `ownerIds`, `providedId`) for `saveCardToWallet`; `repos/universal-wallet/identity/owner.md` for the `(externalId, MEMBER, org)` owner key and `locationId`; `themes/agreement-number-and-prosp.md` hazards #1/#4/#5/#10/#11 for `OWNER_METADATA_FORBIDDEN`.

## Phase D / E notes (executor session 2, 2026-09-10)

- **UI test style.** Step and component tests render through a real RTK store (`__tests__/routes/ShortTermPass/shortTermPassTestData.ts` → `renderWithStore`) with the service module mocked, rather than mocking `useSelector`/`useDispatch` as the older route tests do: thunks, reducers and copy are exercised together. Files under `__tests__/` are all test files for this jest config; shared helpers must end in `Data.ts` (the repo's `testPathIgnorePatterns`), hence the helper's name.
- **Hosted-form readiness.** `PayPageEmbed` exposes no onLoad callback, so the Pay gate treats the mounted embed as "payment method ready" (`capture.formReady`); `submit()` rejecting ("PayPage not ready") is surfaced as "Please complete the card details." and no purchase request is made. Pay is never gated on a token.
- **Visit date before the order shell exists.** The sidebar shows "Pick a day" from the identify step (Riverside demos) but the BFF creates the order only at verify / new-visitor. A date chosen earlier is held in the slice (`pendingVisitDate`, browser-local today as the initial value) and sent through `PUT /order` once the order exists; the BFF's `minVisitDate` then becomes the source of truth.
- **Fine print on identify/verify.** The plan's U2 asks for "No membership. No recurring billing. Change plan any time before you pay." while the demos' runtime shows the "Defaults to today…" sentence from the first render; the UI uses U2's sentence on identify/verify and the demos' sentence on the new-visitor step (recorded as a G2 deviation in the UI validation doc).
- **`dist/.tsbuildinfo`** had been committed with the UI phase A commit; phase D stops tracking it and adds `/dist` to `.gitignore`.
- **`qrcode.react@3.2.0`** added to the UI (`npm install --legacy-peer-deps`; the tree already has an unrelated `webpack-dev-server` peer conflict with `@pmmmwh/react-refresh-webpack-plugin`, pre-existing).
- **Dev servers.** The BFF on :3000 was restarted (`npm start`) to load the sprint code; the UI dev server on :3001 was restarted so the phase A proxy entries apply (they were not active in the long-running process). `repos/online-join-bff/.env` (gitignored) gained the four non-secret local values `STP_ADAPTER_MODE=mock`, `STP_CAPTURE_MODE=mock`, `STP_LOCAL_FLAG_OVERRIDE=true`, `STP_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001`.
- **Demo runner.** No runner dependency was added: `npm run demo:short-term-pass` compiles with the repo's `tsc` and runs `dist/scripts/short-term-pass-demo.js`. The `n/no-unpublished-import` rule is disabled at the top of the script (it imports the BFF sources it exercises; `npm run lint` covers `src/` only).
- **Not performed:** the manual browser check at 1440/375 px (no browser tooling in this session) and the real hosted Pay Page run (B1). Both are named in the validation docs and the execution summary.

## Scope changes

- **PAYMENT_DECLINED reporting.** The contract listed `PAYMENT_DECLINED 402` as an error envelope. Execution returns every orchestration outcome as a 2xx `PurchaseResult`; a decline is `state:'FAILED'` with `failure.code:'PAYMENT_DECLINED'`, `payment.status:'declined'` and nothing else attempted. One result shape for the UI; the code stays in the vocabulary. Contract §4 updated.
- **Route count.** Two routes added in phase B (`GET /checkouts/:id/capture`, mock-only `POST /checkouts/:id/capture/mock`) — see contract §4.
- **Fixture club numbers.** A fourth fixture club (`90033`, Core South) was added so the Core offer survives the Riverside default without displacing the closed/terms fixtures.
- **Completion URL.** `PAGES.shortTermPassDone = '/pass'` was added and `App.tsx` routes both `/signup/day-pass` and `/signup/pass` to the pass shell (the demos move the URL to `…/pass` on completion); the plan named only `/signup/day-pass`.
- **Demo runs.** Executed as eight mock runs plus reload checks (the plan said six): the extra runs are the decline-then-recover path and the wallet-failure → wallet-retry path. The hosted run exists behind `--hosted` and reports BLOCKED (B1).

## Review notes (orchestrator, 2026-09-10)

- **Defect fixed:** new-visitor terms checkbox disabled (Pay unreachable except via the modal). BFF now returns the order shell on the `newVisitor` identify outcome; UI stores it and no longer gates the checkbox on `order`. Found by the headless visual pass, not by the suites — the PayBar tests always rendered with an order present.
- **Defect fixed:** header overflowed the viewport at 375 px (horizontal page scroll, brand wrapping). Header now wraps at ≤640 px with the nav on its own scrollable row.
- **Formatting:** 19 sprint files in the BFF did not match the repo's prettier config. The repo enforces prettier through husky + lint-staged on commit, but the hook was never installed in this clone (dependencies were installed with `--ignore-scripts`, so `prepare`/`husky install` did not run) and the executor's commits bypassed it. Files reformatted; the UI sprint files already matched. Recommendation: run `npm run prepare` in the BFF clone before further commits.
- `dist/.tsbuildinfo` removed from the UI branch history (phase A commit rewritten; hashes changed to `fcf9b9d` / `9753a70`).
- Pre-existing, observed on the legacy signup page during the pass: `GET /api/pay-page/club-feature-flag` returns 500 locally (Pay Page credentials absent, B1) and an external avatar image fails to load. Not sprint work.
