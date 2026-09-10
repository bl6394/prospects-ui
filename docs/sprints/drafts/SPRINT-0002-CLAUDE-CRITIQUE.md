# Sprint 0002 — Claude critique of the Codex and Gemini drafts

**Critic:** Claude Fable 5.1, 2026-09-10.
**Inputs read in full:** `SPRINT-0002-INTENT.md`, `SPRINT-0002-CODEX-DRAFT.md` (326 lines), `SPRINT-0002-GEMINI-DRAFT.md` (91 lines), `docs/prd/Change_Requests_2026-09-10.md`, `SPRINT-0001-BLOCKERS.md`, `SPRINT-0001-EXECUTION-SUMMARY.md`. PRD v3.4 and the v1.2 HTML were spot-checked where a draft made a claim about them.
**Code checked on `prospect-wallet/sprint-0001` (both repos) before judging the drafts:**

| Claim | Who made it | Verdict |
|---|---|---|
| `PayPageEmbed` receives the SDK `onLoad` internally but does not expose it; `CardCaptureSlot` fakes readiness with a `setTimeout` in render | Codex | **True** — `PayPageEmbed.tsx:58` has `onLoad`; `CardCaptureSlot.tsx:45` dispatches `setCaptureFormReady(true)` from a `setTimeout(…, 0)` |
| `identify()` looks up the directory first and returns `newVisitor` without a challenge | Both | **True** — `services/shortTermPass/identify.ts:60–90` |
| `debug.code` is echoed in mock mode | Codex | **True** — `identify.ts:17,46`; and `scripts/short-term-pass-demo.ts:124` **depends on it** (`identified.body.debug.code`) |
| Wallet `providedId` currently receives the purchase id (`pur_…`) but universal-wallet requires a UUID | Codex | **True and material** — `wallet.ts:143–144` documents "the purchase id"; `commerce-universal-wallet-sdk/.../CreditCardRequestVO.java:36` is `private UUID providedId`. A live write would be rejected. Gemini does not mention it |
| In mock adapter mode the wallet is always `MockWallet`, so `STP_WALLET_WRITES` alone cannot reach the dev wallet | Codex | **True** — `adapters/index.ts:127` |
| Challenge: 10-minute TTL, 5 attempts, lock is per challenge; no hourly send window | Codex | **True** — `challenge.ts:9,11,118–120`; §5A.1 (PRD line 288) wants 5 sends/address/hour, 20/IP/hour, 15-minute address lock |
| v1.2 Pass Terms promise a full refund before the first valid day; PRD D15/D22 say no online refunds | Codex | **True** — `day-pass-v1.2.html:366` vs PRD D15, D22, FR-P13. Gemini does not mention it |
| `SPRINT-0001.md` header says `planned` while `ledger.yaml` says `in-progress` | Codex | **True** |
| v1.2 loads Inter from Google Fonts | (needed for parity) | **True** — `day-pass-v1.2.html:8`. Neither draft says how the product loads Inter |
| Membership's generic `GET /api/pay-page/session/:id` poll is what the pass orchestrator uses | Gemini | **False** — Sprint 0001 deliberately routes pass sessions through `/api/short-term-pass/checkouts/:id/capture` and the generic Pay Page routes *refuse* pass-purposed sessions (execution summary §B, contract §4) |
| Test harness lives at `BFF/testing/harness.ts` | Gemini | **Wrong path** — it is `src/routes/shortTermPass/testing/harness.ts` |

## 1. Summary verdict

**Codex is the base to merge from. Gemini is a table of contents.** Codex read the code and the PRD and found three defects the intent did not know about (UUID `providedId`, the refund-copy conflict, the fake readiness timer). Its consent model, OTP redesign and parity contract are concrete enough to execute. Its cost is scope: it adds an evidence store, a consent-event endpoint, hourly limiters, disposable-domain policy, waiver reuse, an SMTP lane, a bearer-leased test server and a browser broker, and estimates 11–17 engineer-days. Several of those are PRD-required and belong in; a few should be cut or demoted to the readiness register so the sprint stays executable by agents in a bounded number of sessions.

Gemini is correct in outline and gives sensible answers to seven of the ten open questions, but it has no task granularity, no tests, no gates with evidence, one architectural error (generic Pay Page poll), and it omits mobile-required (D37), rate limits, the sidebar skeleton/date change, waiver versioning, the consent-event record, the offer card's file, and any definition of "no differences" for the parity loop. It cannot be handed to an executor as written.

## 2. Codex draft

### Architectural soundness — strong, with two over-reaches

**Right calls.**
- **Lookup after consumption** (`identify` issues for every email; `verifyRoute` returns a `recognized | newVisitor | unresolved` union). This is the only shape that satisfies CR-05 and §5A.1 "the page reveals nothing". The note that directory failure must not undo consumed-code semantics is the kind of edge only someone who read `verify.ts` would raise.
- **`consentRevision` bound to the order** with `PUT /order` for acts (adult, waiver, save, marketing) and `POST /purchases` carrying the revision the buyer saw, 409 on stale revision before authorization, revision folded into the idempotency fingerprint. This cleanly answers intent OQ-3 and R2. `version = sha256(canonical rendered content)` plus a separate `templateVersion` is the right split: the hash proves *what was shown*, the template version says *which authored text*.
- **Single `CheckoutController` owning the embed ref and Pay action** above main panel and sidebar. Moving Pay into `OrderSummary` (CR-01) while the embed lives in the step component is exactly the kind of change that produces two sessions or a stale ref; lifting once is correct. "A missing ref is an error; do not optional-chain past it" is a good rule.
- **Expose `onLoad` readiness from `PayPageEmbed`** instead of the render-time timer. Small, real, and it fixes a Sprint 0001 shortcut the blockers file admits to.
- **UUID `providedId` allocated per purchase and persisted before the first save**, reused by `retryWalletStep`, with response-loss read-back. This is a live-correctness fix hiding inside CR-06.
- **Three named lanes** (deterministic local, hosted sandbox, dev wallet) with separate evidence. Prevents the Sprint 0001 mistake of one demo command covering incompatible truths.
- **Refund copy**: PRD wins, delta recorded, CF-02 stays open. Correct; the alternative is shipping a promise counsel never made.

**Over-reaches.**
- **`ConsentStorePort` + waiver reuse per `(memberId, club, waiverVersion)` (D24).** D24 is real PRD, but no CR asks for it and the returning-buyer fixture is one person at one club. An in-memory store that nobody can query from the desk adds a port, an adapter and tests for a behaviour that cannot be demonstrated as intended. Recommend: record waiver acceptance *on the purchase record* this sprint (needed anyway for evidence), register D24 reuse as a readiness item with the store contract sketched, and always present the waiver checkbox (which is what v1.2 renders).
- **Separate BFF test-server entrypoint with bearer lease, peer-address check and run-scoped leases.** The security reasoning is sound, but Sprint 0001 already has a working pattern: `mockCaptureRoute` returns 404 unless `isMockMode(deps) && captureMode === 'mock'`, and production boot refuses mock. Extending that pattern with `STP_TEST_HOOKS=true` (refused in production, loopback-only) for the outbox read route gets 90% of the isolation at 20% of the build. Leases matter only if agents share one BFF process; give each agent its own checkout and correlate outbox messages by checkout id and the race Codex worries about disappears. Recommend the lighter design; keep Codex's "test support absent from ordinary/production runtime" test.
- **Mailpit/SMTP lane.** Intent PR-03 allows it, but there is no platform email adapter yet (L1), so an SMTP sink verifies nothing the mock outbox does not. Recommend: design note only, no compose file, no dependency.

### Completeness — near-total, one dependency unstated

Every CR and PR maps to tasks (traceability line is explicit). It also covers the things the intent asked drafts to answer: offer card, date default, header location label, `pendingVisitDate` retirement, `secondaryContact → mobile`, removal of `switchChallengeChannel`, `debug.code` removal, CF owners, Sprint 0001 status, timezone-flaky test baseline, Inter font pinning, QR mask.

Gaps:
- **`debug.code` removal breaks `short-term-pass-demo.ts` line 124.** Codex removes the echo in B2/B3 and updates the demo in F1, four phases later. The demo will be red for most of the sprint unless F1's demo rewrite (read the code from the outbox) is pulled into B4. Make it an explicit B4 deliverable.
- **How the product loads Inter.** v1.2 uses Google Fonts. The parity loop asserts "Inter loaded" on both sides, but the draft never says whether the UI adds a Google Fonts link (external request from a checkout page), self-hosts the woff2 (licence is OFL, fine, but bundle change), or falls back. D5 needs a line and the decision needs a DESIGN/UI owner.
- **Recognized-lane returning fixture setup for agents** is mentioned ("run-scoped setup") but not which route creates it. The mock directory is a fixture file; a "create returning person" needs either a fixture email (Jordan) plus a pre-seeded wallet, or a test hook. Say which.
- **CR-04's root cause.** The CR blames Google Pay autofill; the intent says it was `MockCardCapture`. Codex fixes both (delete the customer component, launch Chrome with autofill off) but never states which one the review actually saw, so the traceability record for CR-04 will be ambiguous. One sentence in F3.

### Phasing and ordering — sound; A is under-estimated

A → B/C → D → E → F is right: freeze the contract before touching UI, tooling scaffolding in parallel, proof last. Two notes:
- **Phase A at 0.5–1 day is not credible.** A2 freezes the identify/verify union, mobile, four documents, revision, events, evidence store, order-update and replay rules with examples. That is the sprint's hardest design work. Either call it 1.5–2 days or split "freeze" (types and examples) from "decide" (which is what plan review is for).
- **D5 (all v1.2 styling) is one task.** It will be the longest UI task and the one the parity loop iterates against. Split into D5a shell/header/tabs/tokens, D5b main-panel forms and dialogs, D5c sidebar/receipt, so parity failures land on a named task.

### Risk coverage — the best part of the draft

R1–R14 cover every risk the intent lists plus four the intent missed (R4 duplicate embeds when Pay moves, R7 parity loop passing by masking, R8 mock wallet accepting what Java rejects, R12 agents passing by self-report). Mitigations are specific ("detector self-tests", "freeze thresholds", "UUID providedId"). The "completion vocabulary" paragraph is the right defence against a future summary claiming G4 passed on mock evidence.

One risk is missing: **parity threshold too tight to ever pass.** 0.1% changed pixels per region and zero computed-style deltas across font/colour/border/padding/bounds, between a hand-written prototype and a React+MUI v4 app, with Inter possibly loading from different sources, is likely to fail on sub-pixel rounding alone. Codex caps at five repair iterations and exits nonzero, which terminates, but a plan that terminates by failing is not the same as one that can pass. Recommend the two-render calibration Codex already proposes *plus* a written rule for raising a threshold: only by the human reviewer, recorded in the expected-delta manifest, never by the loop.

### Feasibility — high per task, uncertain in aggregate

Every task names real files (spot-checked a dozen; all exist or are plausible NEW paths). Estimates total 11.5–17 days for two engineers plus tooling. For agent execution that is roughly 5–7 executor sessions before proof. Cutting the three over-reaches above (consent store, leased test server, SMTP lane) removes ~2 days and two new ports.

Two feasibility concerns:
- **Tooling in `repos/online-join-ui/scripts/short-term-pass/` puts puppeteer-core, pixelmatch, pngjs and agent goal files into PR #524's lockfile.** Reviewers of a product PR will push back on 1,500 lines of harness. The intent offered planning-repo `tools/`. A `tools/day-pass-harness/` with its own `package.json` and lockfile is equally reproducible (Codex's stated reason for the UI repo) and keeps the product PR about the product. Recommend planning repo.
- **`claude -p` agents deciding browser actions through a broker** is the right reading of PR-02 ("independent"), and Codex is right that three replays of one script do not satisfy it. But it is also the least predictable deliverable in the sprint. Put a floor under it: E3 must first prove one scripted run end to end (a smoke agent), then the three autonomous agents. Otherwise a broker bug and an agent-judgement failure are indistinguishable.

### Definition of done — rigorous; renumbering hazard

G0–G8 with owner slots and evidence per gate; unassigned slot cannot sign. Coverage floors restated, timezone baseline called out, "all green" claims forbidden without evidence. This is the strongest DoD of the two by a wide margin.

Defect: **the gate letters collide with Sprint 0001's.** Sprint 0001 G2 = prototype parity, G4 = PCI boundary. Codex's G2 = consent, G3 = UI/parity, G4 = hosted/PCI, then says "G3 replaces Sprint 0001 G2 obligation" and "G4 carries Sprint 0001 G4". Anyone reading the ledger will misread it. Number this sprint's gates differently (G10–G18, or S2-G0…) or keep Sprint 0001's meanings for G2 and G4 and slot consent in elsewhere.

### Strongest ideas worth keeping from Codex

1. Lookup after consumption; `recognized | newVisitor | unresolved` union; no `debug.code`.
2. `consentRevision` + `templateVersion`/rendered-hash `version`; revision in the idempotency fingerprint; 409 before money moves.
3. UUID `providedId` persisted on the purchase record; read-back on response loss.
4. `CheckoutController` lifting the embed ref; `PayPageEmbed` readiness via existing `onLoad`; delete the render-time timer.
5. Three evidence lanes and the completion vocabulary.
6. PR-01 parity contract: fixed viewports/DPR/clock, `document.fonts.ready`, exclusion = `.proto`/`#syslog`/hosted internals/QR modules only, expected-delta manifest, twice-consecutive pass, five-iteration cap, self-tests for mask over-reach.
7. Refund copy: PRD wins, delta recorded.
8. OQ-7: flag D12 member blocking and last-four step-up as *not* in this sprint rather than silently adding them.
9. Traceability table CR/PR → task → gate; ledger/header status mismatch caught.

### Weaknesses and gaps in Codex

- Scope: consent store + waiver reuse, leased test server, SMTP lane (cut or demote).
- `debug.code` removal vs demo script dependency (sequence B4 before removal).
- Inter font loading undecided.
- Tooling location in the product repo.
- Phase A under-estimated; D5 monolithic.
- Gate letters collide with Sprint 0001.
- Parity threshold may be unreachable; no rule for who may loosen it.
- Prose density: several tasks bundle 8+ files with no acceptance line; an executor will need the Use Cases table to know when B1 is done. Add one "done when" sentence per task in the merge.

## 3. Gemini draft

### Architectural soundness — outline correct, one real error, two muddles

The high-level shape matches the intent: consent and Pay to `OrderSummary`, versioned four-document set from the catalog port, identify returns a generic challenge, inline OTP on `IdentifyStep`, Pay Page via the SDK, wallet write by member UUID behind `STP_WALLET_WRITES`.

Errors:
- **"Orchestrator relies on token polling `GET /api/pay-page/session/:id`."** That is membership's generic route. Sprint 0001 built pass-scoped session creation and polling under `/api/short-term-pass/checkouts/:id/capture` precisely so the generic routes can refuse pass sessions (purpose tagging, contract §4). Following Gemini here would either reopen the generic route to pass sessions or duplicate the poll. Wrong prior art.
- **Wallet paragraph** ("identifying MEMBER strictly by UUID … without `PROSP` fallback … effectively bypassing existing RCM sync duplication hazards via `#4` … (backend dedup fix required)") both claims the hazard is bypassed and that the backend fix is required. It is the latter. And it misses that `providedId` must be a UUID.
- **"Hardcode the fallback marker PROPOSED alongside all template text instances rendered."** The intent says the marker lives in catalog fixture/config, never hard-coded in React, and Codex adds that it is not a customer-facing banner. Gemini's wording reads as a UI string.

Reasonable but unargued: keeping `identify`/`verify` as separate Redux states rendered by one step component (agrees with Codex; fine).

### Completeness — large gaps

Present: CR-01, 02, 03, 04, 05, 06 (thin), 07 (in files list only), 09 (misplaced on `IdentifyStep`), PR-01, 02, 03; CF owners mentioned in DoD; Sprint 0001 closure; branch strategy.

Missing or unaddressed:
- **Mobile required (D37)** — not mentioned anywhere; the new-visitor form change is absent.
- **Rate limits per §5A.1** — "rate-limits" in one open-question answer, no numbers, no file.
- **Sidebar skeleton before order, `pendingVisitDate`, date default** — absent.
- **Removal of "Text me instead" / `switchChallengeChannel` and the SMS copy** — absent.
- **Consent record split** between `PUT /order` and `POST /purchases`; pass-terms-by-Pay with exact button text; document open/close evidence; stored-card disclosure version on the wallet entry — all absent. "Acceptance explicitly recorded at `PUT /order`" is the whole model.
- **Offer card** — recommended in open questions, no component or task.
- **CR-08 itself** — no task does the v1.2 restyle. Phase C builds the diff tool; nothing schedules the fixes it will find beyond "agent fixes".
- **PR-04** — the browser-launch policy (autofill off, no profile), the card list, "never real cards" preflight: absent apart from the title.
- **Termination criterion for parity** — "zero unauthorized differences" is undefined; the intent explicitly requires a defined, terminating criterion.
- **Tests, coverage floors, lint/build gates, existing-suite regression, prettier/husky** — absent.
- **Documentation surfaces** (contract, validation docs, readiness register, semantic index, ledger) — one bullet.
- **Refund-copy conflict** — not seen.
- **Pre-existing baseline failures** (timezone test, PaymentPage type errors) — not seen.

### Phasing and ordering — wrong order in two places

Four phases, each 3–4 bullets.
- **Phase A does UI Pay-Page wiring and `OrderSummary` consent before Phase B changes the BFF identify/verify contract** and before the consent schema exists in the catalog. UI would be built against an unfrozen contract and rebuilt in B. Contract first (Codex A2) is the correct order.
- **Phase C parity tool precedes any styling work**, and no phase contains the styling. The loop would run against an unchanged v1.1 build.
- **Phase D mixes the wallet write with the agent harness and the OTP sink**, which is the prerequisite for PR-02 and should precede agent work, not share a phase with it.
- No validation/handoff phase; no estimates.

### Risk coverage — three risks, generic mitigations

B1 credentials, wallet dedup, §4.5 unapproved. All three are already in the intent. Nothing on duplicate embeds when Pay moves, enumeration/brute force, parity loop non-termination, agent independence, mock wallet vs live Java, test-hook exposure, or pre-existing test baseline. "Drive isolated tests targeting API structures until secrets are shared" is not a mitigation for B1 that anyone can act on.

### Feasibility — cannot be estimated from the draft

Files named exist (with the harness path wrong), but tasks are at the level of "Enforce §4.5 consent variables traversing up to `/checkouts/:id/order`". An executor would have to make every design decision Codex already made. `tools/parityLoop.js` and `tools/agentSimulator.sh` have no dependency plan, no viewport/exclusion/threshold spec, no report format. Deleting `MockCardCapture` "completely" with B1 still missing and no test-only capture hook would leave mock-mode agents unable to enter a card at all, which contradicts U7 in the same draft.

### Definition of done — four bullets, no evidence

"All CRs implemented", "parity shows zero unauthorized differences", "agents drive complete mock-payments", "docs updated", "Sprint 0001 closed". No owner, no artefact, no coverage or lint gate, no distinction between mock and hosted proof, no vocabulary for a B1-blocked outcome. This would let the sprint be declared done on mock evidence, which is exactly what the Sprint 0001 review found unacceptable.

### Strongest ideas worth keeping from Gemini

1. **Absorb the review changes into PRs #96 and #524 on the existing branches** rather than stacking. The PRs are unmerged and the review changes are corrections to what those PRs propose; a stacked PR asks reviewers to approve a design that the second PR then reverses. This is a genuinely better default than Codex's stacked branches, and it is the intent's interview item OQ-9. Recommend it, with the caveat that if the 0001 PRs are expected to merge first for any reason, stack instead.
2. **Mark Sprint 0001 complete with G2/G4 explicitly transferred** — a clean answer to intent OQ-10. Codex prefers "keep in-progress until explicit disposition", which just defers the same question. Gemini's answer, plus Codex's wording rule ("transferred, never passed"), is the merge.
3. **Version = catalog string, fall back to content hash.** Simpler than Codex's dual field for teams that will author versions by hand; but Codex's rendered-hash is needed anyway for dynamic Pass Terms (price/day). Keep Codex's model, borrow Gemini's framing for the docs.
4. **Render the single offer as a permanently selected offer card** — agrees with Codex; two drafts agreeing removes an interview item.
5. **Lookup post-verification; pre-OTP acts only on rate limits** — agrees with Codex.
6. Brevity. The merged plan should be closer to Gemini's length per section than Codex's.

### Weaknesses and gaps in Gemini

Listed above; in one line: correct headline, wrong prior art for the Pay Page poll, no D37, no §5A.1 numbers, no consent evidence model, no CR-08 task, no PR-04 detail, no termination criterion, no tests or gates, phases in the wrong order, no estimates.

## 4. Where the drafts disagree, and a recommendation for each

| Question | Codex | Gemini | Recommendation |
|---|---|---|---|
| Branches | New `prospect-wallet/sprint-0002` stacked on 0001 | More commits on 0001 branches, PRs #96/#524 absorb | **Gemini.** The 0001 PRs are unmerged corrections-in-waiting. Interview only if the team wants 0001 merged first. |
| Sprint 0001 status | Keep `in-progress` until explicit disposition | Close, transfer G2/G4 | **Gemini's action, Codex's wording**: status `complete — G2/G4 transferred to SPRINT-0002 (not passed)`; fix the `planned` header at the same time. |
| Tooling location | UI repo `scripts/short-term-pass/` with pinned deps | Planning repo `tools/` | **Planning repo `tools/day-pass-harness/` with its own lockfile.** Keeps PR #524 about the product; still reproducible. |
| Test hooks | Separate loopback test-server entrypoint, bearer lease | `/api/test/otp-sink` under mock modes | **Middle:** extend Sprint 0001's `isMockMode` gating pattern with `STP_TEST_HOOKS=true`, loopback-only, production boot refuses; outbox read route keyed by checkout id; the "absent from ordinary/production runtime" test from Codex. |
| Mock card capture | Delete customer component; fixture selection only via private broker/test process | Delete completely | **Codex.** Agents and the demo script still need a card in mock mode; it just must never render in the buyer UI. |
| Consent evidence | Order-bound revision, events endpoint, store port, waiver reuse | Recorded at `PUT /order` | **Codex minus store/reuse.** Revision + `PUT /order` acts + `POST /purchases` snapshot; document open/close as a bounded event endpoint; waiver always presented; D24 reuse to readiness. |
| OTP limits | §5A.1 numbers, cross-checkout lock, disposable domains | unspecified | **Codex minus disposable-domain policy** (fixture list is fine; no provider). |
| SMTP sink | Mailpit lane in addition to mock outbox | mock outbox only | **Gemini.** No email adapter exists to point at it. |
| Parity termination | Fixed thresholds, twice-consecutive pass, 5-iteration cap, self-tests | "zero unauthorized differences" | **Codex**, plus a human-only rule for loosening thresholds. |
| Offer card | Render selected single offer | Same | **Agreed; drop from interview.** |
| Date default | Server club-local today after verify; skeleton before | not addressed | **Codex.** |

## 5. Shape of the merged plan

Take Codex's architecture, phases and gates as the skeleton. Then:

1. **Cut:** `ConsentStorePort` and waiver reuse (→ readiness item with sketched contract); leased test-server entrypoint (→ `STP_TEST_HOOKS` gating in the existing router); Mailpit/SMTP lane (→ design note); disposable-domain provider (→ fixture list only).
2. **Add:** Inter loading decision in D5; B4 rewrites the demo script to read codes from the outbox *before* `debug.code` is removed; returning-fixture setup route for agents named; one "done when" sentence per task; a smoke-scripted run before the three autonomous agents; the Codex traceability line kept.
3. **Change:** branch strategy to Gemini's; Sprint 0001 status to complete-with-transfer; tooling to planning-repo `tools/`; renumber the gates so they do not collide with Sprint 0001's; split D5 into three tasks; re-estimate Phase A at 1.5–2 days.
4. **Keep verbatim from Codex:** the UUID `providedId` fix, the refund-copy ruling, the readiness `onLoad` change, the three-lane evidence table, the completion vocabulary, R1–R14, OQ-7's "do not silently add member blocking".
5. **Interview items that survive both drafts:** (a) header location switcher as static label vs dropped; (b) whether the team wants the 0001 PRs merged first (decides branch strategy); (c) who owns the parity expected-delta manifest on the design side; (d) whether Inter may be loaded from Google Fonts on a checkout page or must be self-hosted.
