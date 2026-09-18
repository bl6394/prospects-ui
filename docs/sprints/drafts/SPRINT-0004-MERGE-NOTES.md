# Sprint 0004 Merge Notes

Inputs: `SPRINT-0004-INTENT.md`; drafts `SPRINT-0004-{CLAUDE,CODEX,GEMINI}-DRAFT.md`; critiques `SPRINT-0004-{CLAUDE,CODEX,GEMINI}-CRITIQUE.md`; interview 2026-09-17 (four questions, all answered with the recommended option). Orchestrator verified the code facts the drafts and critiques cite before merging (see "Code facts verified" below).

## Claude Draft Strengths

- The reconciliation inventory: a per-capability keep / hide / remove table with exact code paths, env keys and dependencies for everything Sprint 0003 built (offers grid kept, range model, picker, pass page, QR routes, 18+ removed; pass email demoted to a mock-mode stand-in; receipt kept).
- The MICO finding that decides the DT read path: MICO has no JDBC or JPA starter; every DataTrak read and write goes through the `OrasvcClient` Feign client / `oraSvcRestTemplate` to DT's `.spr` web-service layer (`/pos/saleItems.spr`, `/external/club/getClubDefaultExternal.spr`, `/member/addProspect.spr`, `/pos/onlineSale.spr`). "Read DT configuration like Myko" therefore means that layer, not Oracle.
- Hosting analysis: standalone host on the existing ingress with host-scoped routing, costed against a MICO fork and against new repos, with a host-agnostic fallback if CF-11 stayed open.
- Use cases with pinned copy strings, a phased plan with per-task files and "done when", V-gates separated from pilot gates, and full CF/RQ registers with "effect if unanswered".
- Corrections to the requirement documents: numeric keypad already built (CR-13), v6 hard-codes `VALID_DAYS = 30` and keeps `adultCb`, v6 refund sentence contradicts PRD D15/D22 (CF-16).

## Codex Draft Strengths

- The only serious treatment of D65: the failure and recovery matrix (create response lost, authorization unknown vs declined, deactivate timeout → `RECONCILING`, wallet failure after auth, sale failure before capture, capture unknown, replay and concurrency, late compensation vs a newer record, returning repaint overwriting active paid access).
- Code facts the intent and CR list get wrong: OTP constants are 10 min / 5 sends per hour on `main` (D58/D59 say 5 min / 2 sends; CR-10/CR-30 marked "Done" are not implemented); the "live" `PlatformClubCatalog` returns `FIXTURE_OFFER` with a hard-coded `America/Chicago` timezone and reports `status: 'live'`; the production boot guard does not refuse `STP_MOCK_OTP_CODE`; the gate still couples the paid pass to the free-trial `onlineProspects` setting (D61 replaces that with flagged-item presence).
- Contract v4 discipline: server-owned dates as a quote confirmed at Pay, no writable `visitDate`/`adult`, refuse (never coerce) multi-visit configurations at purchase, contract-version guard for stale bundles, retired routes answer a generic 404.
- The Q/P gate split with a completion vocabulary that never lets mock proof read as pilot readiness; the D52-vs-J1 question (does DT email the QR on create, i.e. before payment?).
- Approved v6 delta list: things in the prototype that are not requirements (`adultCb` gating Pay, `VALID_DAYS` constant, `today + 30` arithmetic, the refund sentence, "Core South" hard-coded in the marketing paragraph, prototype SMS channel branches).

## Gemini Draft Strengths

- The concise one-item v1 framing and the reminder that the multi-offer layout stays while one single-visit item ships.
- Recognition that compensation must eventually run independently of the buyer's tab (a process-local retry sweep now; a service-owned reconciliation later).
- Reuse of the existing React/Koa work rather than any port to MICO.

## Consensus Critiques (multiple agents agreed)

- Rounds 5–7 supersede Sprint 0003's sources; remove the cancelled credential surfaces rather than flag them off (Claude, Codex, both substantive critiques). Gemini's flag proposal alternated between two key names, had no production guard, and hiding the React page would not disable the public BFF routes.
- Contract days are a redemption window, not multiple visits: keep the inclusive calendar arithmetic (`expiration = begin + contractDays − 1`) and the date helpers; replace the commercial model and copy.
- Direct Oracle from the BFF is the wrong first choice (driver, credentials, network path, VPD context call, schema nobody here holds); the MICO facade is a legitimate fallback that costs a Java owner and a release; wallet-account-sync is the wrong owner and the wrong data.
- Two hosting defects in the Claude draft: the UI is compiled with `BrowserRouter basename="/signup"` (`online-join-ui/src/index.tsx:18`) so a root URL on the new host does not route to the checkout by itself; and a strict "only `/api/short-term-pass`" allowlist would break card capture, which uses `/api/pay-page` (`services/shortTermPass.ts:70`, `routes/payPage/index.ts`).
- The compensation graph must not treat an unknown authorization as a decline; the existing `PaymentPort.status` lookup and the `unknown` branch in the orchestrator stay.
- "Attempts logged, not persisted" forbids a failed-attempt reporting feature; it does not permit dropping idempotency or compensation state.
- Both drafts sit at the top of the two-week box; live DT catalog, prospect create and pilot checks must be gates, not exit criteria.
- The pinned-copy U-rows, the `rg`-proof removal lists and the source-qualified CR ids (CR v3 vs the 2026-09-15 list) are worth keeping from whichever draft has them.

## Valid Critiques Accepted

- Fix the OTP constants to D58/D59 (5 minutes, 2 sends per address per hour) and add the five-minute expiry countdown; keep the 30 s resend cooldown; pin `inputMode="numeric"` (already present).
- Remove the fixture fallback from every catalog source in production (not only `STP_CATALOG_SOURCE=fixture`); split the capability report so club, offers, consent texts and timezone are reported separately; supply an authoritative club timezone from the DT read.
- Decouple the gate from `onlineProspects`: eligibility = LaunchDarkly flag on for the club AND at least one eligible flagged item; free-trial defaults untouched (D61, D62).
- Extend the production guard to refuse `STP_MOCK_OTP_CODE`.
- Keep `unknown` authorization as a status lookup then `RECONCILING`; never deactivate a possibly paid prospect.
- Replace Claude's `restore` for a returning buyer with a decision gate: repaint of an existing record and its compensation need DT's conditional-update semantics (RQ-4/CF-15); until then the pilot excludes the overlapping-active-pass case and mock proves repaint + revert on decline only.
- Name the hosting files: `UI/src/index.tsx` basename, `utils/middlewares/historyFallback.ts`, `common/constants.ts`, `routes/static/index.html.ts`; allow the guest-pass Pay Page routes on the standalone host with their existing ownership controls; prove a hosted-card checkout on the new host before calling it functional.
- Separate verdicts in the completion vocabulary: implementation/mock acceptance, standalone dev host, live integration, pilot eligibility.
- Add RQ-0 (does DT send the prospect email with the QR on create, i.e. before payment? effect: no pilot) and an RQ for the `AddProspectRequest` field names (begin/expiration/visits/item/opt-in; MICO maps one consent value to four `comm*` flags).
- The fallback waiver template still contains "I confirm I am 18 or older" (`fixtures/consentTemplates.ts:121`); removing the checkbox is not enough — review the copy with Kelly (CF-08) and do not rewrite club-supplied text silently.
- Wallet port fields are `listEntries`, `expMonth`, `expYear` (not `listCards`/`expiresAt`): expired = end of the expiry month, club-local.
- Freeze one consent acceptance model (Pay-tap Pass Terms attestation + separate waiver checkbox + optional marketing checkbox) and reset waiver acceptance per purchase.
- D12 member block stays as an explicit gap/gate, not a permissive default (Codex critique on RQ-4).
- Do not add a `STP_CREATE_BEFORE_PAY` switch (Codex critique): reversing the state machine later is not a one-line reorder; record the v2 direction (no record until payment) in the register instead.
- Move the feasibility probe (A4) before the final contract freeze for the fields it can change (token field, compensation semantics, DT response shapes).

## Critiques Rejected (with reasoning)

- Claude critique's suggestion to base the merge on Codex wholesale: Codex's read-path recommendation contradicts its own MICO evidence and its tasks are "files … as needed"; the merged plan takes Codex's recovery matrix, contract table and code-fact corrections onto Claude's phased skeleton and U-rows.
- Codex critique's request to keep `restore` out entirely: the intent to leave a returning buyer's previous access intact on a decline is right; what changes is that it becomes a gated port capability (mock proves it, live waits on DT semantics), not a rule claimed from D65.
- Gemini's "hide behind a flag" and "MICO already has the Oracle link": both disproved by source (`build.gradle` excludes JDBC/JPA; MICO uses orasvc HTTP).
- Codex critique's "estimate is 9.5 days with no slack" leads not to cutting the two-lane shape but to naming the cuts: B9 (live datatrak-service adapter) and second-order recovery rows become gated items if the lanes run long; the removal (B0/C0) and the vertical slice are protected.
- Gemini's Cypress/Selenium smoke: the repo's browser QA is Playwright/headless-Chrome agents plus the demo script.

## Interview Refinements Applied

1. **Home / repo (CF-11 answered by the user):** existing `online-join-ui` + `online-join-bff`, served at a standalone Guest Pass host on the existing ingress with host-scoped routing, its own LaunchDarkly flag and Cloudflare rules. MICO fork and new repos recorded as alternatives (v2 home decision for the latter).
2. **Sprint 0003 code:** remove; git history and the sprint-0003 history tag preserve it.
3. **DT read path:** BFF adapter over the DataTrak service layer MICO uses (orasvc `.spr` endpoints), fixtures until Chancy's DT PR exposes the new fields, day-one probe, fail closed per club. Direct Oracle and a MICO facade recorded as alternatives.
4. **Delivery bar:** mock-proven in two weeks; live DT catalog read, live prospect create, hosted capture, standalone dev host and pilot checks are gated steps with owners, each with its own verdict.

## Code facts verified by the orchestrator (2026-09-17)

- `online-join-bff` `origin/main` `src/services/shortTermPass/challenge.ts`: `CODE_TTL_MS = 10 * 60 * 1000`, `SENDS_PER_ADDRESS = 5`, `RESEND_COOLDOWN_MS = 30 * 1000`.
- `adapters/platform/catalog.ts` imports `FIXTURE_OFFER`, `DEFAULT_CLUB_TIMEZONE = 'America/Chicago'`, reads MICO `club/getClub`.
- `repos/mico`: `feignclients/OrasvcClient.java` declares `/pos/saleItems.spr`; `controller/ClubController.java` → `clubDao.getClubDefaultExternal`; `repository/WsShop.java` maps `saleItems.saleItem`; `.spr` endpoints under `external/` in use. No JDBC.
- Dev: BFF v1.2.0 + helm values live in mock mode; PR #106 (secure-cookie fix, 1.2.3) green and unmerged at merge time; testing routes loopback-only; `STP_MOCK_OTP_CODE` pinned in dev.

## Final Decisions

- Sprint 0004 = "Guest Pass v1": Rounds 5–7 supersede Sprint 0003's sources; single-visit catalog-flagged products; begin on purchase; DT is the sole QR renderer; create → pay → deactivate with the unknown branch preserved; legal opt-in modal; no 18+; standalone host; OTP constants corrected.
- Skeleton: Claude draft phases A–E and U-rows; Codex recovery matrix, contract v4 rules, F1–F7 corrections and Q/P vocabulary folded in; Gemini's one-item framing and process-local compensation sweep kept.
- Sizing: A ~2 days (both lanes), B ~5.5 days ∥ C ~4.5 days ∥ D ~2 days (orchestrator + platform, from day 3), E ~2 days. Cuts if the lanes run long, in order: B9 live adapter → gate; second-order recovery rows (capture unknown, late compensation) → gate; D2/D3 → pending register rows. Never cut B0/C0, the vertical slice, B6 or the failure tests for decline and deactivate.
- Ledger: SPRINT-0004 `planned` now; SPRINT-0002 closed as `done` with the deferral note in task A1 (user approved the recommendation implicitly by choosing the recommended options; the note lists D/E1/E2 deferred and S2/S5/S7 carried, no gate marked passed).
