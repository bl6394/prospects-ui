# Sprint 0005 Merge Notes

Merged 2026-10-07 by the orchestrator from three drafts (`SPRINT-0005-{CLAUDE,CODEX,GEMINI}-DRAFT.md`), three cross-critiques and the interview. Final document: `docs/sprints/SPRINT-0005.md`.

## Claude Draft Strengths
- Verified the three facts that reshape G1: the shared club DTO comes from `internal-interface:4.2.0` (direct dependency), the XML path is JAXB and MICO's club-defaults client most likely receives XML; both online sale-items queries filter `cgi_service = '1'` so a guest-pass **product** is never a row today; no H2 harness is wired in `datatrak` (the schema file exists, nothing loads it).
- The `guestPass=true` request mode (superseded at the interview by the club-scoped endpoint, but it established the need for a product-capable, member-less read).
- The site-by-site review map for the gating pass over PR #6643, and the delivery as a PR **onto** Chancy's branch with that map as the review comment.
- SQL-string goldens via `ArgumentCaptor` against literals copied from `main`, plus shape goldens through the real converters.
- Concrete tasks with files and "done when", the `build.gradle` include-list task as its own gate, and the four-verdict vocabulary.
- Timezone normalised server-side with `ZoneId`, validated client-side with `Intl`.

## Codex Draft Strengths
- The invariant stated as a design rule: legacy and extended SQL are **separate** constants, bind lists and mappers; never a flag inside SQL (`CASE`/`COALESCE`/disabled `WHERE`), because Oracle resolves identifiers at parse time.
- The DTO half-day spike as a hard gate before any field work, with the jar bump as the costed fallback; rejection of `@JsonUnwrapped` and dynamic maps.
- The complete M&O guard inventory, including `CatalogItemDaoImpl.updateSaleItemRecord/insertSaleItemRecord`, the three sale-item sync statements in `CatalogItemsDB`, and the finding that `sendGuestPassSaleEmail` runs new-column SQL **before** resolving the club (must be reordered).
- Missing-club context must return false **locally**, not rely on the LaunchDarkly default; evaluation exceptions are off; canonical five-digit club number as the key.
- R0–R7 runbook with stop rules: observed off on every instance and drained work before any drop; DDL is not transactional; metadata-only verification SQL.
- Off-path serialisation leak: `@XmlElement(required=true)` and primitive defaults would print `0`/`false` when off; nullable wrappers with per-field omission, decided by off-byte goldens.
- The honest capability report (`confirmed-on | confirmed-off | unknown`), never an off-state field emitted to advertise a flag.

## Gemini Draft Strengths
- The compact shape (five use cases, four phases) and the one-line statement of criterion 3: stage the helm change, merge only after the DT dev flag is confirmed on.
- The shared-key question, which the Claude critique then showed is feasible (both repos already share `datatrak-DT-18445_disable_spring_auditUser`).

## Consensus Critiques (multiple agents agreed)
- Claude's draft is the merge base; Codex's structure and corrections are folded in (Codex and Gemini critiques).
- The DTO cannot be a bare subclass: spike first in both converters, `@XmlSeeAlso` on a local root subclass if JAXB needs it, jar bump only if the spike fails (all three).
- G1 is unusable without a product-capable query and a member-less mode; deferring G2 leaves verdict 3 blocked by construction (all three).
- Goldens must compare full deterministic bodies (JSON, XML, and the no-`Accept` case), not key sets; SQL goldens must capture binds too (Codex and Claude critiques).
- Timezone: emit `TZL_ABC_CODE` as-is or normalised, validate strictly in the BFF, no GMT fallback; ask the DBA for the distinct values (all three).
- Rollback: BFF exposure off first, then both DT flags observed off everywhere, drain, then the DBA rollback (Codex and Gemini critiques).

## Valid Critiques Accepted
- M&O inventory completed with `CatalogItemDaoImpl` and every `CatalogItemsDB` sync statement, each bound to a task and a negative off-path test.
- `GuestPassFeature` helpers return false before evaluation when no club can be established; test missing context, mismatch, exception.
- Timezone join is a **left** join; a club without a lookup row stays a valid club and fails Guest Pass eligibility closed in the BFF.
- Missing-column fallback on the service club read is narrowed to the Oracle missing-column cause (ORA-00904), and the promise is limited to that read.
- Operational order stays **scripts → code with flags off → M&O flag → service flag → BFF switch → `guest-pass-online`**; "code before schema" is proven as a compatibility test, not used as the rollout path.
- The envelope `ClubDefaultExternalResponse` is also in the jar: the "sibling object" option is costed as a jar change, not a free third way.
- MICO's consumer proof is a JAXB unmarshal of the on-state XML into the jar classes, plus the Jackson JSON case.
- Existing PR tests (`ProspectServiceTransactionsImplEmailTest`, both `PointOfSaleDBGuestEmailTest`) must be updated: today they assert the email unconditionally.
- Intent error corrected: `getLocalTimeZoneAbcCode` is on `SessionInfo` in datatrak-service, not on `JdbcClubDao`.
- A written review map alone does not satisfy "delivered reviewable PR"; it is recorded as the blocked deliverable if Chancy declines.

## Critiques Rejected (with reasoning)
- Codex's rendered-JSP byte goldens: `datatrak` has no JSP rendering harness; replaced by a server-side conditional on the state object, a unit test that the off-path state carries no guest fields, and before/after screenshots in the PR (Claude critique; confirmed at the interview).
- Codex's BFF cache-transition test matrix with a fake clock: the rule lives in the runbook ("exposure flag off first, then TTL or restart"); `requireShortTermPass` already evaluates the flag on every request before the cache is consulted (interview default, see assumptions).
- Codex's HTML sanitiser as a sprint dependency: club HTML already reaches the dialog through `prospectTerms`; G1 adds no new exposure. Kept as a short code check (D5) and a carried finding with an owner (interview default).
- Codex's "distinct MVC mappings" for the member-less mode: `@RequestParam(required=false)` plus an explicit guard that reproduces today's 400 is simpler and testable at the MVC level.
- Codex's mixed-batch partitioning for shared catalogs: confirmed with Chancy in A3 first; if the editing context is one club in practice it collapses to one evaluation (CF-23).
- Gemini's single shared key: feasible, but independent rollback of reader and writer wins (interview).
- Gemini's "H2 handles both states": the schema already has the columns; absent-column safety is proven with a legacy schema variant or SQL goldens, not the default schema.

## Interview Refinements Applied (2026-10-07)
1. **M&O delivery:** PR onto `feat/NOJIRA-guest-pass-email` with the review map, agreed with Chancy first (CF-19).
2. **Items via a new club-scoped endpoint** (revised after the first interview round, user question "why not the club-items queries?"): `/external/club/guestPassItems.spr?clubNumber=` behind the service flag, local DTOs, no SQL when off; the POS `saleItems.spr`, its validator and queries untouched; G2 leaves the sprint (the BFF no longer needs `saleItems.spr`) and CF-14 closes as not required. The earlier `saleItems.spr?guestPass=true` mode is recorded as the rejected alternative: it modified the member-scoped endpoint MICO uses and needed 400-parity work.
3. **Two flag keys**, club context, default off: `datatrak-service-DT-21555-guest-pass-fields`, `datatrak-DT-21555-guest-pass`; runbook flips M&O first.
4. **Goldens plan:** SQL-string (+binds) and full-body JSON/XML goldens stay; DataTrak page goldens replaced as above.
5. **Clarified at the interview:** the only screens touched are DataTrak M&O pages Chancy already changed (server-side gating); `online-join-ui` gets no planned code change, proof only.

**Assumptions recorded (the scope-cuts question was not answered):** sanitiser deferred as a carried finding after a D5 code check; G9 script rewrite optional, separate DBA-reviewed commit; cache-transition matrix dropped to a runbook rule. Each can be reversed at kickoff without replanning.

## Final Decisions
- Base: Claude draft structure and tasks; Codex invariants, inventory, runbook and evidence rules; Gemini's brevity target.
- Sizing: ~12 engineering days across three lanes plus the orchestrator; A2 spike and A3 freeze on day 1–2; cut order fixed (C8 → row; D7 → pending; single-item variant → follow-up); goldens, include list and runbook never cut.
- Verdicts: implementation/mock; standalone host (carried); live integration (dev read done or pending with the named precondition); pilot (not eligible). Production flips never happen in this sprint.
