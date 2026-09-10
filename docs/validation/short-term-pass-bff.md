# Validation — short-term pass BFF (Sprint 0001, E2/E4)

**Repo:** `repos/online-join-bff`, branch `prospect-wallet/sprint-0001`. **Executor:** Claude Fable 5.1, 2026-09-09/10.
**Commands:** `npm run lint` · `npm run build` · `npx jest --coverage --forceExit` (the harness suites set `jest.setTimeout(30_000)`; `--forceExit` because the toolkit logger keeps a handle open) · `npm run demo:short-term-pass [-- --hosted]`.

## Numbers (final, after Phase E)

See `SPRINT-0001-EXECUTION-SUMMARY.md` for the exact final figures recorded from the last run; at Phase C close the full suite was 58 suites / 481 tests passing (2 pre-existing skips) with coverage **97.52 % statements · 85.81 % branches · 95.13 % functions · 98.04 % lines** against floors 84/67/67/84. No threshold or exclusion was changed.

## Security and fault matrix (E2)

Each row names the test that pins it. All rows pass.

| Area | Behaviour | Test |
|---|---|---|
| Pre-verify disclosure | Identify returns only outcome, masked contact, channel availability, expiry and resend time; no name, member id, kind or alternate address | `routes/shortTermPass/__tests__/identify.test.ts` "only the masked contact…" |
| Ambiguous match | Two people on one phone → `ambiguous`, no code sent, no prospect | `identify.test.ts` ambiguous case |
| OTP wrong / expired / locked / replayed / superseded | 401 `CODE_INVALID` with attempts remaining, lock after 5 (429 `CHALLENGE_LOCKED`), `CODE_EXPIRED`, replay → `CHALLENGE_MISSING`, resend supersedes the old code | `routes/shortTermPass/__tests__/verify.test.ts` |
| Resend / switch / limits | 30 s cooldown shared with identify; 5 sends per contact+club per 15 min across identify, resend and fresh cookies; switch never returns a mask of the unsubmitted address | `identify.test.ts` "resend and switch-channel" |
| Change contact invalidates challenge | `DELETE /identity` → old code no longer verifies | `identify.test.ts` "invalidate the challenge on Change" |
| Cookie / CSRF / Origin | HttpOnly, SameSite=Lax, host-only, Secure when secure; missing or foreign cookie → 404; wrong CSRF → 403; missing or disallowed Origin → 403; expired → 401 and cookie cleared | `routes/shortTermPass/__tests__/session.test.ts`, `checkouts.test.ts` |
| Cross-checkout / cross-club substitution | Another checkout's id with my cookie → 404; another checkout's selection ref → 403; another checkout's hosted session → 404; a checkout for another club is a fresh checkout | `session.test.ts`, `routes/shortTermPass/__tests__/purchase.test.ts` "gates, ownership and hostile input" |
| Generic Pay Page bypass | `GET/PUT /api/pay-page/session/:id[/close]` refuse pass-purpose sessions (registry and metadata) | `routes/payPage/__tests__/index.test.ts`, `services/payPage/__tests__/sessionOwnership.test.ts` |
| Price / date / terms tampering | Bodies with `amountMinor`, `offerId`, `terms.version`, `memberId`, `pgToken`, `pan`, `cvc`, `expiry`, `tokenId`, `ownerId` → 400; past date → 400; unaccepted terms → 409 `ORDER_NOT_READY` and no authorization | `routes/shortTermPass/__tests__/order.test.ts`, `purchase.test.ts` hostile-body table |
| Terms as an affirmative act | `method` required; version, method and server time recorded; version change clears acceptance (409) | `order.test.ts`, `services/shortTermPass/__tests__/order.service.test.ts` |
| Idempotency | same key + body replays with one authorization; different body → 409 `IDEMPOTENCY_CONFLICT`; concurrent second attempt → 409 `PURCHASE_IN_PROGRESS` + `Retry-After` | `purchase.test.ts`, `services/shortTermPass/__tests__/idempotency.test.ts` |
| Identity rules 1–8 | owner by bound member UUID / MEMBER / org; existing owner reused (`createOwner` never for Jordan); metadata exactly the allowlist; call order authorize → prospect → owner → entry → sale → issue → deliver; save off → no wallet call; recursive upstream payload scan for `PROSP` (word-bounded), `agreementNumber`, `dt_agreementNumber`, `dt_memberNumber`, `dt_memberOrdinal` | `purchase.test.ts` "Demo 1 · First visit" U13, `services/shortTermPass/__tests__/walletWrites.test.ts` |
| Member match | Casey Morgan proceeds as member; record unchanged; no owner created | `purchase.test.ts` U15 |
| Failure boundaries | decline (nothing persisted, retry allowed); auth timeout → one `status()`; prospect failure → void; void unknown → `RECONCILING`; contact race → void + back to identify; wallet failure → `failed-retryable`, sale continues, wallet-retry saves without payment calls; wallet unavailable distinct; sale failure → void, prospect and saved card kept; issuance failure → bounded retry then refund; delivery failure → `COMPLETE` with `delivery.failed` | `purchase.test.ts` "failure table (U16)" |
| Wallet-retry ownership | requires verified identity (401 for a new visitor's checkout); own purchase from a later verified checkout allowed; stranger → 404; nothing to retry → 409 | `purchase.test.ts` "POST /purchases/:pid/wallet-retry" |
| Redaction | Only allowlisted keys reach the log; codes, contacts, names, tokens, member ids never do; `debug.code` absent in platform mode | `services/shortTermPass/__tests__/log.test.ts`, `identify.test.ts` |
| Dark / isolated | Flag off or club closed → 404 on every registered pass route; production refuses mock mode / override / faults; boot guard | `utils/middlewares/__tests__/requireShortTermPass.test.ts`, `services/shortTermPass/__tests__/config.test.ts`, `routes/shortTermPass/__tests__/checkouts.test.ts` |
| Platform adapters (contracts) | `PlatformPayPageSessionReader` reads `result.NEW_PAYMENT_METHOD.TOKEN[0]`; `PlatformWallet` owner query and owner-scoped entry query, NOT_ENABLED without switches; `PlatformClubCatalog` from MICO getClub + location resolver | `services/shortTermPass/__tests__/{payPageSession,platformWallet,platformCatalog}.test.ts` |

## Demo (E1)

`docs/demos/short-term-pass-local-demo.md` — 47/47 checks, exit 0; `--hosted` reports BLOCKED (B1).

## Pre-existing findings (unchanged)

- `rawBodyCapture` breaks JSON bodies for `/api/*` routes other than `/api/pay-page/` and now `/api/short-term-pass/` (see blockers).
- `jest --coverage` needs `--forceExit` on this machine because a toolkit handle stays open after the suites finish (also true for the baseline suite before this sprint).
