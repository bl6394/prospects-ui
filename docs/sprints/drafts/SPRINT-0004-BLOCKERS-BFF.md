# Sprint 0004 — BFF lane blockers (`online-join-bff`)

None blocked the lane. Recorded:

- **B1 Pay Page credentials absent locally** — hosted capture unverified; the mock capture (`STP_CAPTURE_MODE=mock` + test hooks) stands in. Dev has `PAY_PAGE_*`; the browser step there is pending.
- **CF-13 / CF-14 / CF-15** — DataTrak service layer lacks the guest-pass fields, `saleItems.spr` is member-scoped, `addProspect` field names unanswered: `DatatrakServiceCatalog` ships unit-pinned against labelled synthetic fixtures; platform `ProspectPort` `notEnabled`. E4 (2026-09-18) additionally could not resolve `datatrak-service.dev.abcfitness.net` from the executor's network (ENOTFOUND) — one boot, not retried.
- **Fault switch is in-process** — no browser API can flip it (by design); the E2 smoke ran one BFF process per fault. A successful compensation after recovery is proven at HTTP level (Demo 6), not in the browser.
- **Two-sends-per-hour cap (D59)** broke suites that identified one address three times — fixed by `challenges.resetLimits()` in the harness / `beforeEach`; the purchase limiter (10 / IP / hour) likewise needed `resetLimits` per demo and per browser flow.
- **Circular import** `config.ts → verificationCode.ts → challenge.ts → config.ts` when the OTP template loader moved to boot — split into `adapters/smtp/templates/otpTemplate.ts`.
- **Sonar** — the first scan on PR #107 failed with 13 new issues despite the conventions applied while coding; all fixed in `9b8ed8c` / `c6d4136` (see the lane summary); the re-scan passed.
