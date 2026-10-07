# Sprint 0005 — Codex critique of Claude and Gemini drafts

**Recommendation:** use Claude as the merge base, with the blocking corrections below. Gemini is a useful scope outline but is not executable yet. Neither draft currently proves the governing promise: flags off execute no SQL referencing the new columns, perform no `ADD_GUEST` lookup, and preserve legacy response and page bytes.

## Review basis

Read the intent and both drafts, then checked local source only. No remote host was probed and no repository code was changed. The `repos/datatrak` working tree is on `main`; PR-specific checks used `git show` / `git grep` against the local `feat/NOJIRA-guest-pass-email` branch (head `50a00ffb0538994a0920e637878c16795baed7fa`), without checking it out. Paths below are relative to the workspace; branch references explicitly mean that branch. Runtime serialization, database execution, CI and live integration were not exercised during this review.

### Verified facts that affect the decision

| Local evidence | Consequence for the plans |
|---|---|
| `repos/datatrak-service/dtWar/src/com/abcfs/repository/pos/sql/PointOfSaleSql.java:25` and `:47`: both list and single-item queries require `cgi_service = '1'` and `cgi_online = '1'`. PR-branch `EditCatalogItemsState.java:21` defines product `0`, service `1`, billing `2`. | Claude correctly identifies a missing prerequisite: projecting guest-pass columns alone cannot list products. Gemini misses it. Widening rows must be isolated from MICO requests. |
| `repos/datatrak-service/dtWar/src/com/abcfs/validator/OnlinePosValidator.java:251` requires a numeric club and GUID member; `POSController.java:92–153` selects list/single-item DAO paths, then performs member-based appointment enrichment. | Member-less listing requires a deliberate controller/validator/enrichment branch. Merely making the request parameter optional is insufficient. |
| `repos/datatrak-service/dtWar/build.gradle:136` directly declares `internal-interface:4.2.0`; the same build declares both Jakarta-era JAXB runtime and older `javax.xml.bind` dependencies. `SaleItem.java` uses Jakarta annotations. | Claude's dependency correction is supported. Its inspection of a cached **4.1.0** jar is not proof that a local subclass works with the service's actual **4.2.0** runtime. |
| `repos/datatrak-service/dtWar/src/com/abcfs/club/external/dao/DtManagedClubSql.java:462` selects only from `serviceProviderLocations`; `ClubExternalServiceImpl.java:70` subsequently adds branding and hide-enrollment data. | Retaining the old path and adding a separate gated query/enrichment path is reasonable. Existing post-DAO fields must survive the new response mapping. |
| PR-branch `dtWar/src/main/java/com/abcfs/inventory/catalogItems/repository/CatalogItemDaoImpl.java:149–183` has independent `updateSaleItemRecord` and `insertSaleItemRecord` SQL referencing both CGI and SAI guest-pass columns. `CatalogItemsDB.java` has additional sync statements at approximately 1078, 1108 and 1124. | A gate only around catalog-page SQL is incomplete. Every deployment/sync variant needs its own mapped guard and tests. |
| PR-branch `ProspectServiceTransactionsImpl.java:190` checks `transactionContainsGuestPassItem` **before** resolving the club; liability and `ADD_GUEST` use follow later. | Resolve the context using legacy-safe data and gate **before** the first guest-pass query, including direct service callers. |
| Both local `FeatureService.computeBooleanFeature` implementations construct VPD-only or generic contexts when club is absent and then call `boolVariation`. | Missing club does not automatically return false. The new helper must explicitly reject absent/unresolvable club context. |
| PR-branch tests contain no matches for `schema.sql`, `jdbc:h2`, or `EmbeddedDatabaseBuilder`; its `dtWar/build.gradle:204–209` includes HSQLDB, not an established H2 test harness. Service tests have an explicit include list at `dtWar/build.gradle:261–304`. | Claude correctly challenges the supposed ready-made H2 harness; Gemini's H2 assurance is unsupported. A schema file alone proves nothing about tests running. |
| `repos/online-join-bff/src/services/shortTermPass/adapters/platform/datatrakServiceCatalog.ts:199–209` checks timezone presence, not validity; `:360–374` requests sale items without a member and caches offers. | Both drafts overstate current invalid-timezone fail-closed behavior. Claude at least schedules the missing validation. Cache behavior matters during rollback. |
| `repos/mico/src/main/java/com/abcfs/repository/WsShop.java:46` ignores unknown JSON properties; `feignclients/OrasvcClient.java:95` requests sale-item JSON. `WsClubDefaults.java:221` uses `oraSvcRestTemplate`; `configuration/MicoConfiguration.java:35` builds it with `RestTemplateBuilder`. | JSON tolerance does not prove XML tolerance. A bare `new RestTemplate()` in the service project is not a faithful test of MICO's configured client and dependency set. |
| `repos/datatrak-service/dtWar/src/com/seqtek/abcfs/dt/util/TimeZoneSupport.java:58–81` reads the lookup code and passes it to Java timezone handling. `getLocalTimeZoneAbcCode` is absent from the named service `JdbcClubDao`. | Claude's source-location correction is supported. This does not establish that every stored value is a browser-supported IANA zone. |

## Claude draft

### Architectural soundness

**Keep:** two independently controlled, default-off flags; explicit legacy SQL branches; a BFF-only `guestPass=true` mode; club-targeted evaluation; optional nullable wire fields; preservation of the original jar response on the off path; early DTO feasibility work; and protection of POS completion/webhook publication from guest-email failure. These are substantially more concrete than Gemini's proposals.

**Blocking: the M&O inventory is incomplete.** The detailed architecture table and C2–C7 omit `CatalogItemDaoImpl`, despite its two independent new-column statements. A generic A4 search task does not repair a missing implementation/test task. Add both methods, their callers, legacy SQL and bind parameters, and context resolution. Enumerate every `CatalogItemsDB` sync statement rather than describing all of them as one of “four statements.” Confirm all insert placeholder counts and all off-path mappers; using old SQL with a mapper that still requests new columns is also a failure. Require negative assertions for new-column SQL and template lookup across page, sync, Fast Add, direct service and both POS entry points.

**Blocking: U12's missing-context guarantee is false as written.** VPD-only or generic contexts may match flag rules; `false` is an evaluation fallback, not an unconditional result. Return false locally before evaluation when the target club cannot be established. Standardize club-number normalization, including leading zeros, and resolve the target club rather than blindly using the operator's session club for cross-club catalog deployment. Test missing context, club mismatch and targeted versus untargeted clubs. Capture a consistent mode for each operation so query selection, parameter binding and row mapping cannot disagree if a flag changes mid-operation.

**U13 also promises more than the code establishes.** Passing a false default does not itself prove that an already initialized SDK returns false whenever connectivity drops; locally retained flag state needs explicit consideration. Test initialization failure, evaluator exceptions, normal false targeting and retained-state behavior separately. Operational rollback must verify that every serving instance has observed off, then drain in-flight work before dropping columns or deleting templates.

**The DTO pair is a credible candidate, not a demonstrated solution.** Declaring the local nested type addresses a real concern with a subtype inside a jar-typed field. However, runtime subclass failure is not universally established merely by the draft's cached-jar inspection. Gate P1 on a small executable test with service 4.2.0, actual message converters, annotations/namespaces, inherited fields, root/element names, and response envelope. Preserve branding, hideEnrollPage, null/error behavior and existing field encodings. Test MICO's actual consumer version separately, with its actual XML converter/context. Do not make XML testing conditional on which media type currently wins negotiation: XML is explicitly supported and required by the intent. A JSON annotation such as `@JsonInclude` cannot establish JAXB behavior.

**The goldens are too weak for the stated requirement.** P7/B4 mostly compare key sets and element names, which can pass despite changed values, ordering, escaping, null emission or wrappers. Compare deterministic full JSON/XML response bodies and rendered page bodies against a pinned pre-change baseline using real serialization/rendering paths. Cover success and error responses. The hand-thrown missing-member exception must be exercised through MVC, including requests missing multiple parameters, not assumed byte-equivalent from its message. Capture all executed SQL and bind parameters, not just selected SQL constants.

**Flag-on query risks need explicit handling.** The proposed inner timezone join can remove an otherwise valid club when its lookup is absent; preserve the legacy club row with a left join and fail Guest Pass eligibility closed separately. Limit missing-column fallback to recognized Oracle missing-column causes rather than all `BadSqlGrammarException`s. The draft promises self-healing “reads” broadly, but only specifies the club-query fallback; sale-items currently catches errors into its response envelope. Either implement both deliberately or narrow the promise. A failed query followed by fallback is not evidence of zero new-column SQL when off.

**G2 is sensibly scoped, but pin its boundaries.** The BFF's current member-less request makes this necessary for a live read. Keep normal MICO requests on the original query even with the service flag on. Validate supplied member IDs before enrichment and retain existing invalid-input behavior. Exercise both list and single-item routes; if the latter is cut, explicitly constrain the supported request contract and prove no consumer relies on it. Current BFF source shows list reads, not the draft's asserted dedicated single-item reread.

### Completeness against the intent

Claude covers most success criteria: field-name contract, service PR, M&O PR, matrix, UI regression, test discovery, quality gates, runbook, registers, ledger and four verdicts. Its strengths are traceability and honest synthetic-versus-recorded labeling.

Two changes to acceptance must be explicit. First, Mockito/SQL assertions replace the intent's H2-backed requirement; document that as a proposed revision, with a bounded executable absent-schema proof or clearly named residual limitation. Mocks cannot establish Oracle execution correctness. Second, flag-on fixtures remain synthetic until captured from dev; that is useful mock acceptance, not satisfaction of a recorded live matrix. Mark the live evidence pending when unavailable.

The inferred capability label must describe **observed fields**, not claim authoritative LD state. Timezone alone cannot prove both endpoints are ready or distinguish an off flag from old code, fallback or cached responses. Include observation time, per-endpoint readiness and unknown/off-or-absent wording. Check mixed states and stale caches as well as the six nominal matrix cells.

The liability path deserves a definite task, not a late discovery placeholder: `consentTemplates.ts:217–219` places `waiverText` into an HTML override. Trace the final renderer and pin sanitization/encoding without double decoding or altering consent hashes accidentally. The UI unavailable path is present (`ShortTermPassPage.tsx:151,189`); preserve its regression proof.

### Phasing, risk and two-week feasibility

The draft's code-off → scripts order demonstrates an important safety property but reverses the intent's stated operational scripts → code-off order. Distinguish an **absent-schema compatibility test** from the agreed deployment sequence. Retain the intent's operational order unless the DataTrak/DBA owners explicitly select code-first; either order must keep flags off until schema readiness is verified.

Keep early DTO/member-less/product-list feasibility, parallel implementation after the contract freezes, and optional G9 cuts. Its approximately 12 engineering days can fit ten working days only with real parallel staffing, build access and owner review availability. Four days for service DTO/XML, query widening, validation, tests and Sonar is tight; 2.5 days for the M&O pass is particularly optimistic given the omitted DAO and cross-club operations. Add a day-one build baseline and owner checkpoint, a short DTO decision deadline, and review/rebase contingency. External merges, DBA work, LD access and secret provisioning are dependencies, not “never a blocker”; they block live acceptance even when local work continues.

Rollback is underspecified. Close BFF exposure, handle the dev local override, expire/invalidate cached club and offer data, turn off both DataTrak flags, verify propagation and drain work, then roll back schema/template changes. Switching to fixtures can restore a mock demo but must be labeled that way; it is not proof that live availability has been safely withdrawn. Do not describe flag-off as erasing persisted guest-pass data.

### Definition of done

V0–V7 and the four verdicts are worth retaining. Strengthen them with complete SQL-site coverage, full-byte response/page assertions, actual-runtime XML proof, explicit absent-schema evidence and propagation-aware rollback. A written review map or “PR prepared, not opened” is a useful blocked deliverable, but does not satisfy the intent's delivered-reviewable-PR criterion. Unconfirmed wire names are provisional, not “confirmed” merely because both proposed PRs use them. Replace owner slots with accepted owners and dates before execution; correct the runbook's inconsistent six-step/0–6 numbering and GET-versus-POST checkout verification references.

## Gemini draft

### Architectural soundness

**Keep:** the compact service/M&O/BFF/runbook breakdown, explicit original-query off branches, club-targeted default-off flag, include-list task, additive liability encoding and ordered source-switch precondition. A shared key is a legitimate option and the intent allows it.

**Blocking: DTO design remains undecided.** “Wrapper or sibling … or subclass” is not an implementable contract. `@JsonUnwrapped` and MICO's unknown-JSON-property setting do not protect XML. Decide an exact wire envelope and test it with actual service and MICO dependencies before estimating implementation. Define per-field JSON omission and XML optionality: simply adding fields to `SaleItemWithDiscount` can expose false/zero/null defaults when off.

**Blocking: field projection does not make products visible.** Both existing SQL queries filter to services. Add an isolated guest-pass query mode and preserve MICO's row set. Gemini's plan to change the existing query conditionally for an entire flagged club provides no consumer isolation if widened later. Also settle G2 now: the BFF currently sends no member ID. Leaving it “parallel” means a complete field-exposure PR can still leave live catalog reads blocked. Either implement the narrowly scoped member-less mode or explicitly plan a blocked live verdict.

**A shared flag couples both deployments.** It avoids coordinating two flips but cannot independently roll back M&O writes/email and service exposure. Require both repos' gated versions and schema readiness before enabling it; define club/VPD normalization, SDK/project/environment alignment, absent-context rejection and an owner for the combined readiness gate. Two keys are preferable here because the codebases deploy independently, but a shared key is not intrinsically unsafe if these prerequisites are enforced.

**The no-SQL guarantee is an aspiration, not a complete design.** “All 17 modified files” is not a call-path inventory. B2 at least names `CatalogItemDaoImpl`, which Claude's detailed tasks omit, but no task maps every insert/update/sync, mapper or `ADD_GUEST` lookup to its guard. Hide page markup and validation as well as writes. Gate before the POS service's initial guest-pass query and protect the pre-existing webhook. Require actual executed-SQL/binding assertions and page/serializer goldens.

### Completeness, risks and feasibility

The core three implementation areas are present, but key success evidence is missing: frozen field/type/null/encoding table and contract update; explicit capability-report work; smoke evidence; UI unavailable regression; CF/RQ and ledger changes; four separately stated verdicts; and Sonar evidence for every affected PR. “The adapter stops synthesizing fields” misdescribes current code: it already maps optional wire fields and separately has synthetic fixtures. The work is contract alignment, not removal of runtime synthesis.

The H2 promise is unsupported by the local branch. Budget building a harness or explicitly revise the intent's acceptance requirement; do not claim the schema file guarantees development or both-state coverage. G9 is optional in the intent but mandatory in V2, creating avoidable external scope. Make it a separate DBA-reviewed optional commit.

Timezone validity is neither established by Java lookup usage nor currently checked by the BFF mapper. Add normalization policy and browser-runtime validation tests. Risk coverage also needs missing-context behavior, invalid/partial schema, default serialization drift, cross-club sync, flag propagation, cache expiry, template rollback, POS failure isolation and external-owner delays. The three listed risks are insufficient for the seed's deployment/rollback promise.

No effort estimates, staffing assumptions, feasibility spike, review allowance or cut order demonstrate a two-week fit. A stacked PR after #6643 merges can leave unguarded code deployable; require the gating patch to land before any rollout of that code. Work must be delivered for Chancy/PK review, not as an unqualified direct push to their branch.

### Phasing and definition of done

D1 follows the intent's scripts → code-off → flag-on → BFF-switch ordering and is worth keeping. Expand “flag on” into schema verification, both-app readiness, test-club configuration, service JSON/XML proof, MICO regression, BFF secret/source switch, and club exposure. Add an owner, verification and rollback at every step. Write the runbook early enough to constrain implementation.

V1–V4 are too coarse to establish completion. They need evidence locations, named owners, test-discovery reports, full-byte/SQL proof, confirmed wire contract, recorded-versus-synthetic status, and explicit done/pending live reasons. Restore all four house verdicts: implementation/mock acceptance, standalone host, live integration, and pilot. “Production unexposed” is necessary but does not replace these distinctions.

## Required changes before merging a sprint plan

1. Adopt Claude's product-query discovery, request isolation, separate flags, detailed tasks and four-verdict evidence model; retain Gemini's concise operational sequence.
2. Complete the M&O inventory, especially `CatalogItemDaoImpl`, every catalog sync variant and direct email-service invocation. Bind each site to an implementation task and negative off-path test.
3. Make DTO/XML feasibility, missing-context rejection, member-less validation and product visibility first-day decisions. Test actual producer and consumer dependency versions.
4. Replace shape-only claims with full deterministic body/page comparisons and comprehensive SQL/binding capture. Explicitly resolve the intent's H2 requirement rather than silently weakening it.
5. Freeze the wire contract with owner acceptance; add invalid-timezone, HTML liability, mixed-state and cache tests. Report observed capability without pretending to know remote flag state.
6. Separate deployment order from code-before-schema compatibility proof. Require verified off-state propagation and drained work before destructive DB rollback; distinguish fixture rollback from live rollback.
7. Commit to reviewable PRs and mock evidence within the two-week staffing budget. Treat merges, scripts, secrets, real recordings and live switching as separately owned gates, with honest pending verdicts when unavailable.
