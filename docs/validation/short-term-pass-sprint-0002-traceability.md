# Sprint 0002 traceability — change request → task → commit → evidence → verdict

Source: `docs/prd/Change_Requests_2026-09-10.md`. Commits are on `prospect-wallet/sprint-0001` (UI PR #524, BFF PR #96). Verdict vocabulary: **done** (implemented, test-pinned, observed in the browser smoke where applicable) · **done, hosted pending** · **deferred** (user decision 2026-09-10) · **open** (no build change; confirmation with an owner slot).

| # | Request | Tasks | Commits | Evidence | Verdict |
|---|---|---|---|---|---|
| CR-01 | T&C control and Pay in the Order Summary panel; save-card stays in the payment section | C3, C9 | UI `29ebc96`, `fa1878c` | `OrderSummary.test.tsx` U10/U11, `ConsentBlock`; smoke screenshots `*-05-consented-*` | done |
| CR-02 | T&C modal content replaced by PRD §4.5 documents (not from the Pay Page) | A3, B3, B4, C3 | BFF `289220e`, `7ecdf58`, `9ad75d8`; UI `29ebc96` | `consentTemplates.test.ts`, `order.test.ts`, `consentEvents.test.ts`, `purchase.test.ts` (attestation, one snapshot); `DocumentDialog` tests; PROPOSED marker in fixture/config; refund copy per PRD (delta recorded) | done — content still PROPOSED (CF-02) |
| CR-03 | Embed the Commerce Pay Page like membership online join | B5, C6 | BFF `531f4f4`; UI `29ebc96` | `captureMode` defaults `paypage`; `PayPageEmbed` `onReady` + regression test; `CardCaptureSlot.test.tsx` loading/failure/Retry; hosted run **not** possible (B1) | done, hosted pending (S5) |
| CR-04 | No saved-card dropdown for a first-time buyer | B5, C6 | BFF `531f4f4`; UI `29ebc96` | `MockCardCapture` deleted; `TestCardPanel` only with `STP_TEST_HOOKS`; PCI scan "no `<select>`"; router-stack 404 test; boot guard. Root cause recorded: the review saw `MockCardCapture` in mock capture mode; browser autofill is additionally disabled by the harness policy | done |
| CR-05 | Email OTP for both lanes | B1, B2, C1, C2 | BFF `34b5493`; UI `29ebc96` | `identify.test.ts` / `verify.test.ts` (identical responses known/unknown, lookup after consumption, limits, address lock); `IdentifyStep.test.tsx`; smoke flows 1–4 (every email got a code) | done |
| CR-06 | Save-card writes the token to the prospect wallet | B6 | BFF `fc77007` | `walletWrites.test.ts`, `platformWallet.test.ts` (UUID `providedId`, `oj_*` metadata, read-back); smoke flow 4 (1 entry); live enablement checklist in contract §10 | done (mock) — live wallet L3 |
| CR-07 | Remove generator explanatory text | C2, C8a | UI `29ebc96`, `fa1878c` | tests assert Sprint 0001 help lines absent; smoke screenshots | done |
| CR-08 | Visual parity with HTML v1.2 via the diff loop | C2–C8, D1, E1 | UI `29ebc96`, `fa1878c` | every v1.2 copy string pinned; orchestrator eyeball review at 1440/375; **parity loop deferred** | build done; loop deferred (S2 not started) |
| CR-09 | Unchecked marketing opt-in at the contact field | B3, C5 | BFF `7ecdf58`; UI `29ebc96` | `order.test.ts` marketing default false; `NewVisitorStep.test.tsx` CR-09; smoke screenshot `first-*-03-new-visitor-*` | done (new visitors; recognized preference is a readiness item) |
| PR-01 | Visual-parity agent loop | D1, E1 | — | `tools/day-pass-harness/` scaffolding only | deferred |
| PR-02 | Multiple independent simulated-user agents | D4, E2 | — | — | deferred |
| PR-03 | OTP mail sink | B5, D2 | BFF `531f4f4` | `GET /api/short-term-pass/testing/outbox?checkoutId=` (hooks, loopback, key) — used by the orchestrator smoke; CLI wrapper deferred | server side done; CLI deferred |
| PR-04 | Sandbox test cards, autofill off, never real cards | B5, D3 | BFF `531f4f4` | fixture cards 4242 / 4444 / 0002 / 0003 / 1111-expired via `TestCardPanel`; smoke Chrome launched with autofill and payments disabled; browser-policy self-test deferred with the harness | fixtures done; policy tooling deferred |
| CF-01 | Counsel confirms right-panel consent placement | — | — | register row, owner PM | open |
| CF-02 | Counsel approves T&C content | — | — | register row, owner PM+LEGAL; templates `approval:'PROPOSED'`; refund delta | open |
| CF-03 | Owner for the OTP sink and test-card list | — | — | register row, owner PM | open |
| P1-1 | Declined purchase showed a paid receipt | C3, C9 | UI `29ebc96` | `OrderSummary.test.tsx` P1-1, `ShortTermPassPage.test.tsx` P1-1; smoke flow 5 (FAILED purchase, no receipt) | done |
| P1-2 | Reload into new visitor left Pay disabled | C1 | UI `29ebc96` | `shortTermPassSlice.test.ts` P1-2 | done |
| P1-3 | Lost cookie dead end | B1, C1 | BFF `34b5493`; UI `29ebc96` | `checkouts.test.ts` P1-3 (401 `CHECKOUT_EXPIRED`); `ShortTermPassPage.test.tsx` P1-3 (restart + toast) | done |
| P1-4 | Two tabs, one cookie | B1, B4, C1 | BFF `34b5493`; UI `29ebc96` | generation on identify/verify/order/purchase; 409 `STALE_GENERATION`; slice tests | done |
| P1-5 | Browser timezone mislabels Today | C3 | UI `29ebc96` | skeleton sidebar until the order exists; `pendingVisitDate` retired | done |
| P1-6 | Horizontal overflow under 393 px | C8a | UI `fa1878c` | `layout.test.ts`; smoke overflow check 320–440 px | done |
