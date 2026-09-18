# Sprint 0004 — UI lane blockers (`online-join-ui`)

None blocked the lane. Recorded:

- **Baseline failures (never counted green):** `__tests__/helpers/transformers.test.ts` (date-dependent) failed this run; `__tests__/routes/ReviewPage/OfferDetails/OfferDetails.test.tsx` (intermittent) passed this run. `tsc` baseline: `routes/PaymentPage/{PaymentPage,PaymentPageWithPayPage}.tsx`, `__tests__/hooks/usePayPageSession.test.tsx`, `__tests__/routes/PaymentPage/PayPageEmbed.test.tsx` (pre-existing).
- **`App.test.tsx` mocked the deleted `PassViewPage`** (`jest.mock` of a missing module fails the suite) — the mock and the `/pass/:token` cases were replaced by the alias and standalone-host cases in C1.
- **Defect found by the new page suite (C8):** a `contractVersion` mismatch on the first bootstrap never re-bootstrapped after the restart and the toggling `busy` flag re-bootstrapped over the pending error — fixed in `ShortTermPassPage.tsx` (`0c920fa`).
- **Defect found by E2:** `.srow .v { white-space: nowrap }` overflowed the 375 px viewport with the v6 Valid sentence — fixed (`4d5a8e8`) and pinned in `layout.test.ts`.
- **Design HTML v6 carries "18 or older"** — the copy table's design-source check does not assert its absence; the UI static scan does.
- **Hosted Pay Page embed** unverified locally (B1); the fixture panel stands in. No hosted-card checkout was run on the standalone host (saved card was).
- **Sonar** — the first scan on PR #532 failed with 3 new issues; fixed in `3435039`; the re-scan is read by the orchestrator.
- **CI version bump** finalised `8.33.0-daypass.2` to `8.33.0` (`80495fb`); `e62a67c` restored the line as `8.34.0-daypass.1`, the precedent being #525's `da25d3a`.
