# Sprint 0002 — UI lane execution summary

**Sprint:** Day Pass review changes (`docs/sprints/SPRINT-0002.md`). **Lane:** UI — Phase C (C1–C9), Addendum P1-1, P1-2, P1-3 (UI), P1-4 (UI), P1-5, P1-6, the UI-side P2 items, E4 for `repos/online-join-ui`.
**Executor:** Claude Fable 5.1, 2026-09-10, running in parallel with the BFF lane. Entered at UI `eafada1` on `prospect-wallet/sprint-0001`. Not pushed. Coded against contract v2 §4/§4a with the service module mocked in tests (Sprint 0001 style); never run against a BFF.
**Status:** lane complete — C1–C9, the six P1 fixes and the listed P2 items are implemented and test-pinned; E4 numbers recorded below. Notes and questions in `SPRINT-0002-BLOCKERS-UI.md`.

## 1. Tasks

Legend: ✅ done · ◐ done with a recorded limit · ⛔ blocked.

| Task | Status | Commit | Evidence (tests) |
|---|---|---|---|
| C1 slice / selectors / service on v2: `checkout.consent`, `order.consents`, identify → code entry always, verify three outcomes + `retryLookup`, `changeContact`, `switchChannel` removed, `draftProfile`, `capture.formReady` only from `onReady`, `canPay`, `postConsentEvent`, `attestation` | ✅ | `29ebc96` | `__tests__/reducers/shortTermPass/shortTermPassSlice.test.ts` (35), `__tests__/selectors/shortTermPass.test.ts` (30), `__tests__/services/shortTermPass.test.ts` (5) |
| C2 identify with offer card + inline code (CR-05, 07, 08); `VerifyStep` deleted | ✅ | `29ebc96` | `IdentifyStep.test.tsx` (12: U1, U2, U3, U4, U7, U9, 429 cooldown, raw-message guard, Core perks) |
| C3 sidebar skeleton / order / receipt, `ConsentBlock`, `DocumentDialog`; `PayBar`, `TermsDialog` deleted; `pendingVisitDate` retired | ✅ | `29ebc96` | `OrderSummary.test.tsx` (14: U1/P1-5, U10, U11 ×2, U12, U13, U17, P1-1, date debounce + Pass Terms hash, WAIVER_HASH refresh, Core line item) |
| C4 recognized per v1.2 (header, "We found you.", kv rows, `.paysel`, new-card branch, required Mobile) | ◐ alert only with a saved card (U-4) | `29ebc96` | `RecognizedStep.test.tsx` (6: U5, new card ↔ saved, wallet unavailable/empty, saved-card pay, test-card pay, D37 mobile) |
| C5 new visitor (Edit → `changeContact`, names, required Mobile + SMS notice, `MarketingOptIn`, danger alert, no Pay in panel) | ✅ | `29ebc96` | `NewVisitorStep.test.tsx` (10: U6, CR-09 opt-in, `smsNoticeShown` once, v1.2 validation via sidebar Pay, card message, purchase with profile + attestation, names kept after Try again, Edit, raw-message guard, no Sprint 0001 copy) |
| C6 `PayPageEmbed` additive `onReady`; `CheckoutController`; `CardCaptureSlot` embed / loading / failure Retry / `closed`; `TestCardPanel`; `SaveCardSwitch` default off; PCI scan rules; `MockCardCapture`, `SaveCardToggle` deleted | ✅ | `29ebc96` | `CardCaptureSlot.test.tsx` (7: U15 ×3, no session while saved, U16 ×2, invalid fixture), `SaveCardSwitch.test.tsx` (5: U14), `__tests__/routes/PaymentPage/PayPageEmbedOnReady.test.tsx` (2: absent / present), `pci.test.ts` (no `<select>` under capture components; deleted files gone); membership `PayPageEmbed.test.tsx` and `PaymentPageWithPayPage.test.tsx` unchanged and green |
| C7 done per v1.2 (header, pass block, saved alert / not-saved help / retry alert, actions order; FAILED / RECONCILING kept) | ✅ | `29ebc96` | `DoneStep.test.tsx` (6: U17 four card outcomes, delivery truthfulness, FAILED / RECONCILING, Start again) |
| C8a shell, tabs, tokens (brand word/tag, static switcher, "Secure checkout", `nav.dt-tabs` Class · Membership · Day Pass · Visit, v1.2 640 px tab rule) | ✅ | `fa1878c` | `CheckoutShell.test.tsx` (3) |
| C8b main-panel styles (`.identify-row`, `.offer`, `.inline`, `.otp`, `.kv`, `.paysel`, `.savecard`/`.switch`, `.payfields`, `.test-cards`, alerts, `.dt-check .sub`, `.links`, `.req`, `.dt-modal-meta`, dialog body); Sprint 0001-only rules removed | ◐ `DtCheckbox`/`DtAlert` unchanged (U-8) | `fa1878c` | `layout.test.ts` (rules present / removed), `isolation.test.ts` unchanged and green |
| C8c sidebar and receipt styles (`.skeleton`, `.dayfield`, `.srow`, `.total`, `.agree`, `.side-actions`, `.fine`) | ✅ | `fa1878c` | `layout.test.ts`, `isolation.test.ts` |
| C9 page + pay action (`CheckoutControllerProvider` in the page; `usePayAction` builds `attestation` from `checkout.consent` and validates `draftProfile` with v1.2 messages; step switch without verify; v1.2 copy pinned; consent fixtures in `shortTermPassTestData.ts`) | ✅ | `29ebc96` | `ShortTermPassPage.test.tsx` (9), `OrderSummary.test.tsx` U11/U13, `NewVisitorStep.test.tsx`, `format.test.ts` (7) |
| P1-1 receipt and `/pass` keyed off `purchase.state === 'COMPLETE'` | ✅ | `29ebc96` | `OrderSummary.test.tsx` "P1-1", `ShortTermPassPage.test.tsx` "P1-1", `selectors` "P1-1" |
| P1-2 `applySnapshot` sets `paymentChoice.useSaved=false` for `newVisitor` | ✅ | `29ebc96` | `shortTermPassSlice.test.ts` "P1-2" |
| P1-3 (UI) 401 `CHECKOUT_EXPIRED` → restart with the session-expired toast; toast survives the reset; no raw server message anywhere | ✅ | `29ebc96` | `ShortTermPassPage.test.tsx` "P1-3", `IdentifyStep.test.tsx` / `NewVisitorStep.test.tsx` raw-message guards, `format.test.ts`, slice "reset keeps the toast" |
| P1-4 (UI) `generation` on identify / verify / order / purchase; 409 `STALE_GENERATION` → re-sync (re-bootstrap) with a toast | ✅ | `29ebc96` | `shortTermPassSlice.test.ts` "thunks … generation (P1-4)", "STATE_CONFLICT under its reason", `ShortTermPassPage.test.tsx` "P1-4", service test |
| P1-5 skeleton sidebar until the order exists; no browser-local "Today"; `pendingVisitDate` retired | ✅ | `29ebc96` | `OrderSummary.test.tsx` "U1 / P1-5" |
| P1-6 `.page` grid `minmax(0,1fr)` at every width; shrinkable widgets / inputs / OTP / frame; header never wider than the viewport; no intrinsic-width control | ◐ CSS assertions in jsdom; 320–440 px visual check is manual (§7) | `fa1878c` | `layout.test.ts` (5) |
| P2 client `maxLength` (120/60/32) + friendly copy on email / names / mobile | ✅ | `29ebc96` | `IdentifyStep`, `NewVisitorStep`, `RecognizedStep` tests |
| P2 429 retry seconds shown; Continue / Resend disabled for the cooldown | ✅ | `29ebc96` | `IdentifyStep.test.tsx` "P2: a 429 …", `format.test.ts` |
| P2 optimistic checkbox / toggle / date with revert on error | ✅ | `29ebc96` | `OrderSummary.test.tsx` "U11: … optimistic", `SaveCardSwitch.test.tsx`, slice "order (optimistic…)" |
| P2 debounced date `PUT` (400 ms); toast only after the server accepts | ✅ | `29ebc96` | `OrderSummary.test.tsx` "debounces the date PUT" |
| P2 out-of-order `PUT /order` responses dropped (latest request id + server generation) | ✅ | `29ebc96` | slice "drops an out-of-order response", "drops a response from an older server generation" |
| P2 names kept after a decline + Try again (A3-04) | ✅ | `29ebc96` | `NewVisitorStep.test.tsx`, slice `retryAfterFailure` |
| BFF D-4 reconciliation: bare 409 after three lookup retries ends the Retry loop | ✅ | `41d7444` | slice "a bare 409 …", `format.test.ts` |
| E4 (UI) lint / build / coverage | ✅ | — | §3 |

Deleted as planned: `steps/VerifyStep.tsx`, `components/{PayBar,TermsDialog,SaveCardToggle,MockCardCapture}.tsx` and their tests. Added as planned: `components/{CheckoutController,OfferCard,InlineCodeEntry,ConsentBlock,DocumentDialog,MarketingOptIn,SaveCardSwitch,TestCardPanel}.tsx`. New tests: `CheckoutShell.test.tsx`, `CardCaptureSlot.test.tsx`, `SaveCardSwitch.test.tsx`, `layout.test.ts`, `PaymentPage/PayPageEmbedOnReady.test.tsx`.

## 2. Commits (UI, `prospect-wallet/sprint-0001`, on top of `eafada1`)

| Hash | Message (first line) |
|---|---|
| `29ebc96` | Sprint 0002 Phase C (UI lane): contract v2 slice/service, identify with inline code, sidebar consent + Pay, recognized / new visitor / done per v1.2, Pay Page capture, P1 fixes |
| `fa1878c` | Sprint 0002 Phase C (UI lane): C8 v1.2 shell, tabs and stylesheet; P1-6 no horizontal overflow on phones |
| `41d7444` | Sprint 0002 Phase C (UI lane): end the lookup Retry loop on the BFF's bare 409 after three retries (BFF D-4) |

Every commit: `npm run lint` 0 errors, `npm run build` compiled, full jest green except the pre-existing baseline failure below. Nothing under `dist/`, `public/` or `coverage/` committed (all gitignored).

## 3. Final lint / build / coverage (E4, UI) at `41d7444`

| Check | Result |
|---|---|
| `npm run lint` | 0 errors, 756 warnings (all pre-existing rule classes: complexity, exhaustive-deps, unsafe-any in legacy files; the lane added no error) |
| `npm run build` | webpack 5.105.0 compiled with 3 warnings (entrypoint size 1.33 MiB and the two performance recommendations — pre-existing) |
| `npx jest --coverage` | 103 suites: 102 passed, 1 failed (baseline) · 645 tests: 644 passed, 1 failed (baseline) |
| Coverage, all files | lines **93.09 %** · statements **93.09 %** · branches 84.56 % · functions 87.5 % (floors 80 / 80 lines / statements; thresholds unchanged, no exclusions added) |
| Baseline at entry (`eafada1`) | 100 suites / 579 tests / 578 passed / 1 failed; the lane added 3 suites and 66 tests |
| Lane coverage | `reducers/shortTermPass` 98.64 % lines · `selectors/shortTermPass.ts` 99.35 % · `services/shortTermPass.ts` 99.54 % · `routes/ShortTermPass` page 98.78 %, steps 96–100 %, components 60–100 % (`CardCaptureSlot.tsx` 60.24 % — the embed branch is exercised, the `PAY_PAGE_ORIGIN` window read is not), hooks: `usePayAction.ts` 93.87 %, `useShortTermPassCapture.ts` 69.04 % (the bounded hosted poll loop needs a live embed; covered at the unit level in Sprint 0001 only through the mock path) · `components/dt` 100 % · `PayPageEmbed.tsx` 100 % |
| `npx tsc --noEmit` | 8 pre-existing errors remain, none new: `src/routes/PaymentPage/PaymentPage.tsx` ×3, `src/routes/PaymentPage/PaymentPageWithPayPage.tsx` ×3, `__tests__/hooks/usePayPageSession.test.tsx` ×1, `__tests__/routes/PaymentPage/PayPageEmbed.test.tsx` ×1. At entry there were 11 (the plan's header says 25); the 3 in `__tests__/reducers/shortTermPass/shortTermPassSlice.test.ts` disappeared with its rewrite. `tsc` is not part of `npm run build` (babel-loader only) or of jest (`isolatedModules`). |

**Pre-existing baseline failure (unchanged, not hidden):** `__tests__/helpers/transformers.test.ts › transformAgreement builds the agreement payload using today payment info` — timezone-dependent (`text: 'June'` vs `'May'` for value `'06'`); fails identically at `eafada1`. E4 asks the orchestrator to document the common test timezone.

Lane-only run: `__tests__/routes/ShortTermPass/**`, reducer / selector / service tests and `__tests__/routes/PaymentPage/**` → 21 suites, 248 tests, all green.

## 4. Runs not performed by this lane

No dev server was started, stopped or touched (`:3000` / `:3001` run old code per the brief). No parity run, no agent run, no hosted run (E1, E2, E3 are deferred / B1-gated). The UI was not exercised in a browser; all evidence is jest against the v2 contract with the service module mocked.

## 5. Gates this lane contributes evidence to

| Gate | UI-lane evidence | Verdict from this lane |
|---|---|---|
| S0 Ready | UI types compile against v2 (`interfaces/api/shortTermPass.ts` mirrors the BFF `schemas.ts` v2 shape read during the run) | contributes |
| S1 Traceability | §1 table maps C1–C9, P1-1…P1-6 and the P2 items to commits and tests; CR-01/02 (C3, C9), CR-03/04 (C6), CR-05 (C1, C2), CR-07 (C2, C8a), CR-08 (C2–C8), CR-09 (C5) | contributes |
| S2 Parity | **not started** (deferred by the execution change); build-side prerequisites in place: v1.2 copy pinned string-for-string in tests, self-hosted Inter, `.proto`/`#syslog` never built, hosted region wrapped in `.card-slot.payfields` for masking; approved-delta candidates listed in the blockers file (U-2, U-3, U-4, U-5, U-6) | pending |
| S3 Consent recorded | UI sends `waiver:{accepted, method:'checkbox'\|'modal', renderedHash}` and `adult`, `saveCard`, `marketingOptIn`, `smsNoticeShown` through `PUT /order`; `attestation:{consentRevision, payButtonText}` from the server set on `POST /purchases`; document-opened / -closed events; 409 `WAIVER_HASH` / `CONSENT_REVISION` refresh handled with no acceptance recorded locally; PROPOSED marker never rendered | contributes (server side is the BFF lane's) |
| S4 OTP for everyone | Email-only identify (`type=email`, phones refused client-side with the v1.2 message), inline code entry, no `debug` code path remains, no channel switch; the UI reveals nothing until `verify` | contributes |
| S5 Pay Page only | Hosted embed is the only card entry in every non-test mode; `TestCardPanel` only for `captureMode==='mock' && testHooks`; no `<select>` under the capture components (static scan); readiness only from `onReady`; load-failure / `closed` → Retry; membership `PayPageEmbed` tests unchanged and green + additive regression test | UI side complete; **hosted run pending (B1)** |
| S8 Quality | §3: lint 0 errors, build clean, coverage 93.09 / 93.09 ≥ 80 / 80, baseline failure listed, thresholds untouched, signup / guest / Pay Page suites green | passes for the UI repo |
| S9 Docs | this summary and the blockers file; contract questions for E5 | contributes |

## 6. Contract questions for the BFF lane (detail in the blockers file, Q-1…Q-9)

Q-1 brand word for the consent sentence / marketing copy / app button (`brand.word` "CORE" vs legal "Core"); Q-2 `profile` on `POST /purchases` for a recognized person without a mobile; Q-3 customer copy on `VALIDATION_FAILED` (shown verbatim); Q-4 `snapshot.contact.display` for `newVisitor`; Q-5 `smsTransactional` echoed in `order.consents.notices` after `smsNoticeShown`; Q-6 `waiver:{accepted:false}` clears `method`; Q-7 `PUT /order` may answer `CONSENT_REVISION`; Q-8 `DELETE /identity` `generation` adopted; Q-9 `testHooks` absent → hosted.

## 7. Left for the orchestrator or the user

1. **Manual browser check for P1-6** at 320, 360, 375, 393 and 440 px on identify, code entry, new visitor and recognized-new-card: `document.documentElement.scrollWidth <= window.innerWidth` and no clipped header. jsdom cannot lay out; `layout.test.ts` pins the rules. Needs the UI built from `41d7444` and served through a BFF running the BFF lane's v2 (the dev servers on `:3000` / `:3001` run old code).
2. **Parity (E1) and agents (E2)** deferred; approved-delta candidates from this lane: U-2 (aria-disabled Pay), U-3 (line-item dedupe for Riverside only), U-4 ("We found you." only with a card), U-5 (recognized-step mobile alert), U-6 (brand casing pending Q-1), plus the plan's own list (email notice, SMS notice + opt-in rows, Pay Page frame, static location label, Retry affordances, wallet-retry alert, refund sentence).
3. **Contract answers Q-1…Q-9** and the D-2 toast wording ("Your session expired" also fires when the checkout resumes).
4. **E5**: traceability table rows from §1; validation doc `docs/validation/short-term-pass-ui.md` update; PR #524 description; `docs/SEMANTIC-INDEX.md` file moves (new components, deleted files listed in §1).
5. **Repo hygiene outside the lane**: no stylelint config although `lint-staged` calls it; `husky` config is v4-style under husky 8 so no hook runs (U-12); the `transformers.test.ts` timezone baseline.
6. **Open P2 items** (not done, see the blockers file): A6-05, A6-06, A6-07, A6-08, A3-05, A5-02 (unmeasured), A5-03, A5-05, A6-09, A6-10.
7. **Pushing** `prospect-wallet/sprint-0001` (three new UI commits) is the orchestrator's.

## 8. Lane verdicts

- **Phase C:** complete — C1–C9 implemented and test-pinned; every v1.2 copy string pinned; `VerifyStep`, `PayBar`, `TermsDialog`, `SaveCardToggle`, `MockCardCapture` gone; `CheckoutController`, `OfferCard`, `InlineCodeEntry`, `ConsentBlock`, `DocumentDialog`, `MarketingOptIn`, `SaveCardSwitch`, `TestCardPanel` added; `PayPageEmbed` changed additively only.
- **P1 fixes (UI):** P1-1, P1-2, P1-3, P1-4, P1-5 complete; P1-6 complete in CSS with the visual check left to the orchestrator.
- **P2 (UI):** the five listed items done plus A3-04; the rest listed as open.
- **E4 (UI):** lint 0 errors · build clean · 644 / 645 tests (1 baseline) · 93.09 % lines / statements.
- **Completion vocabulary for this lane:** *review changes complete (UI); parity and agents deferred; hosted capture unverified (B1)*.
