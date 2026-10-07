# Sprint 0005 — Claude critique of the Codex and Gemini drafts

**Status:** CRITIQUE, 2026-10-07. Input to the planning interview and the merge; not a plan. Reviewed against `docs/sprints/drafts/SPRINT-0005-INTENT.md` and the code in the token cache (`repos/datatrak-service` on `main`, `repos/datatrak` with `feat/NOJIRA-guest-pass-email` read via `git show`, `repos/online-join-bff`, `repos/online-join-ui`, `repos/mico`, `repos/helm-configs`).

**Evidence boundary:** local files only. No remote host, LaunchDarkly project, CI run or database was probed. The shared interface jar (`internal-interface:4.2.0` / `dt-interfaces:4.13.2`) is not in the local Gradle cache, so the annotations on `ClubDefaultExternal` / `ClubDefaultExternalResponse` were **not** inspected; every statement about them below is inference from how they are used. The two controllers carry a literal Basic `Authorization` header in source; it is not reproduced here and must not be reproduced in the merged plan.

## 0. Verdict in one paragraph

The Codex draft is the right skeleton: its flag-off invariant (separate legacy and extended SQL strings and mappers, never a flag inside SQL), its DTO spike, its memberless-listing and product-type findings, and its R0–R7 runbook with stop rules are correct and verified below. Its weakness is volume: 16 use cases, 26 tasks, 9 gates, a sanitizer dependency, cache-transition proofs and rendered-JSP byte goldens are more than two weeks of work in repos we do not own, and some of it (page-byte goldens in `datatrak`) is not feasible with that repo's test setup. The Gemini draft is readable and correctly ordered at the top level, but it misses three facts that make its plan unexecutable as written: the existing sale-items query only returns services, so flag-on returns no guest-pass products; the H2 schema already contains the new columns, so "H2 handles both states" proves nothing about absent columns; and `ClubDefaultExternalResponse` is in the shared jar too, so its "sibling element on the response" is also a jar change. Merge on the Codex structure, cut to roughly 60% of its size, and take Gemini's shared-flag question and its compact phase ordering into the interview.

## 1. Claims verified against the code

| # | Claim (draft) | Verified? | Where |
|---|---|---|---|
| 1 | Club-defaults SQL selects from `serviceProviderLocations` only; no `spl_extensions` join, no timezone (both) | Yes | `datatrak-service/dtWar/src/com/abcfs/club/external/dao/DtManagedClubSql.java:461-480` |
| 2 | Service enriches `branding` / `hideEnrollPage` after the DAO, so there is a post-DAO enrichment seam (Codex) | Yes | `.../club/external/service/ClubExternalServiceImpl.java:70-79` |
| 3 | `ClubDefaultExternal` **and** the envelope `ClubDefaultExternalResponse` come from the shared jar | Yes (envelope not noted by either draft) | `ClubExternalServiceImpl.java:6` imports `com.abcfinancial.ws.api.clubdefaults.ClubDefaultExternalResponse`; mapper imports `com.abcfinancial.ws.api.common.ClubDefaultExternal` (`.../repository/club/mapper/ClubDefaultExternalRowMapper.java:3-4`) |
| 4 | `saleItems.spr` requires `memberId`; validator requires a strict GUID (Codex) | Yes | `.../controller/POSController.java:86-92`; `.../validator/OnlinePosValidator.java:251-258` |
| 5 | Both sale-item queries constrain `cgi_service = '1' and cgi_online = '1'` — **services only, products excluded** (Codex) | Yes | `.../repository/pos/sql/PointOfSaleSql.java:45` and `:66` |
| 6 | Catalog item type: product `"0"`, service `"1"`, billing `"2"` (Codex) | Yes | `datatrak` branch `.../inventory/catalogItems/EditCatalogItemsState.java:21-25` |
| 7 | `SaleItem` / `SaleItemWithDiscount` / `SaleItemResponse` are local JAXB-annotated DTOs (Codex) | Yes | `.../api/pos/SaleItem.java:10-40` (`@XmlElement(required=true)`), `SaleItemResponse.java:14` (`@XmlRootElement`) |
| 8 | Timezone comes from `SERVICEPROVIDERLOCATIONS.TZL_ID → TIMEZONELOOKUP.TZL_ABC_CODE`; no new column needed (both) | Yes | `.../seqtek/abcfs/dt/util/TimeZoneSupport.java:52-62` |
| 9 | `getLocalTimeZoneAbcCode` is not on `JdbcClubDao` (Codex correcting the intent) | Yes — it is on `SessionInfo` | `.../common/SpringSessionInfo.java:697` |
| 10 | DS `FeatureService` has `computeBooleanFeature(key, vpd, club, default)` but no `isFeatureFlagOnSafe` (Codex) | Yes | `.../launchdarkly/FeatureService.java:18-43`; DT's has it at `datatrak` branch `.../common/launchdarkly/feature/FeatureService.java:26` |
| 11 | Test discovery is an explicit `include` list; `ClubExternalControllerTest` only covers the logo endpoint (Codex) | Yes | `datatrak-service/dtWar/build.gradle:284-305`; `dtWar/test/java/.../ClubExternalControllerTest.java:67-148` |
| 12 | DS `main` auto-publishes and deploys to dev on push (Codex) | Yes | `datatrak-service/.github/workflows/ci-trunk.yml:3,19-26` |
| 13 | DT H2 `schema.sql` already has all seven columns, so default H2 tests cannot prove absent-column safety (Codex) | Yes | `datatrak` branch `dtWar/src/test/resources/schema.sql:287,1781-1783,1836-1838` |
| 14 | Guest email checks `transactionContainsGuestPassItem` (new-column SQL) **before** resolving club, so a club-context flag cannot be evaluated first without reordering (Codex) | Yes | `datatrak` branch `.../services/ProspectServiceTransactionsImpl.java:190-199`; the SQL at `.../sales3/repository/PointOfSaleDaoImpl.java:1032-1043` |
| 15 | Both `PointOfSaleDB` copies call the guest email before publishing the POS event; six external call sites | Yes | `sales/.../PointOfSaleDB.java:512-520`, `sales3/.../PointOfSaleDB.java:268-276`; callers in `EAEApi.java:974,1059`, `POSApi.java:131,194`, `PosPayPageCheckoutCompleteService.java:446`, `ElectronicAgreementDB.java:2583` |
| 16 | Edit Club `load` merges the new column into the **existing** SELECT (so flag-off needs a separate legacy string) | Yes (neither draft states it this precisely) | `datatrak` branch `.../repository/editClub/EditClubOnlineDaoImpl.java:28-40` |
| 17 | BFF accepts any non-empty timezone and maps any non-`SERVICE` type to product (Codex) | Yes | `online-join-bff/src/services/shortTermPass/adapters/platform/datatrakServiceCatalog.ts:171,199-209` |
| 18 | BFF middleware resolves the club before evaluating `guest-pass-online`; cache default 60 s (Codex) | Yes | `online-join-bff/src/utils/middlewares/requireShortTermPass.ts:54-66`; adapter `:103` |
| 19 | No HTML sanitizer in BFF or UI; `DocumentDialog` uses `html-react-parser` (Codex) | Yes | no `dompurify`/`sanitize-html` in either `package.json`; `online-join-ui/src/routes/ShortTermPass/components/DocumentDialog.tsx:1` |
| 20 | MICO shop uses a tolerant `ObjectMapper` but fetches items through a Feign client (Codex) | Yes | `mico/src/main/java/com/abcfs/repository/WsShop.java:46,94`; `.../feignclients/OrasvcClient.java:95-96` (Accept JSON) |
| 21 | MICO club defaults go through a plain `RestTemplate` into the shared `ClubDefaultExternalResponse` | Yes — and this is **likely the XML path** (see §2.1) | `WsClubDefaults.java:221-226`; `MicoConfiguration.java:35-37` |
| 22 | The two DataTrak services evaluate at least one identical LD key, so a shared key is feasible (Gemini's assumption) | Yes | `datatrak-DT-18445_disable_spring_auditUser` in `datatrak-service/.../LDFeatureFlagConstants.java:15` and `datatrak` branch `.../LDFeatureFlagConstants.java:30` |

Not verified: the annotations on the shared jar classes (jar absent locally); whether MICO's `RestTemplate` has a JAXB converter on its classpath (it is a Spring Boot app with Jackson; JAXB presence decides the Accept header); whether the DS and DT LaunchDarkly SDK keys point at the same project and environment (values are secrets and were not read).

## 2. Architectural soundness

### 2.1 The shared-DTO question, and the XML path

Facts that change the answer:

- `datatrak-service` registers no custom message converters (`SpringConfiguration` has no `configureMessageConverters`) and sets `defaultContentType(APPLICATION_XML, APPLICATION_JSON)` with `ignoreAcceptHeader(false)` (`.../configuration/SpringConfiguration.java:280-285`). XML is produced by `Jaxb2RootElementHttpMessageConverter` (JAXB runtime on the classpath, `dtWar/build.gradle:113-114,122,159`); JSON by Jackson. There is no `jackson-dataformat-xml`.
- A client that sends no `Accept`, or whose `RestTemplate` lists the JAXB converter first, gets **XML**. MICO's `oraSvcRestTemplate` is a bare `RestTemplateBuilder().basicAuthentication(...).build()`. If JAXB is on MICO's classpath, the default converter order puts XML first in its `Accept` header, and MICO's club-defaults call is the XML path. The intent's "MICO's `ObjectMapper` tolerates unknown fields" is JSON evidence about a different class (`WsShop`) and does not cover this call.
- `Jaxb2RootElementHttpMessageConverter` builds the `JAXBContext` from the root class only. A locally subclassed `ClubDefaultExternal` placed in `response.club` (declared type: the jar class) is **not known to that context** and will fail at marshal time with the flag on, unless the subclass is registered (`@XmlSeeAlso` on a local root subclass, or a converter that builds the context with the extra class). Jackson, by contrast, serialises the runtime type and is fine.

Consequences for the drafts:

- **Codex** is right to call JAXB polymorphism "a risk, not a solved detail" and to make a half-day converter spike (A2) a gate before any field work. It is also right to reject `@JsonUnwrapped` (JSON-only) and dynamic maps. It should go one step further and say what the spike must try: (a) a local `GuestPassClubDefaultExternalResponse extends ClubDefaultExternalResponse` carrying the same `@XmlRootElement` name plus `@XmlSeeAlso(GuestPassClubDefaultExternal.class)`, returned only on the on-path; (b) what MICO's JAXB unmarshaller does with the resulting `xsi:type` attribute on `<club>` (the JAXB RI normally ignores an unknown `xsi:type` and falls back to the declared type, which is the behaviour we want, but it must be observed, not assumed); (c) the JSON side with the same instance. If (a)+(b) pass, no jar bump; if not, the jar bump is the only clean route.
- **Gemini** lists "sibling JSON structure", "local wrapper", and "subclass locally" as interchangeable and backs them with `FAIL_ON_UNKNOWN_PROPERTIES=false`. Two of the three cannot work as described: a sibling field on the response needs a change to `ClubDefaultExternalResponse`, which is also in the jar; and a bare subclass breaks the XML path on. Its risk R1 says "verify `FAIL_ON_UNKNOWN_PROPERTIES=false` on MICO's end", which verifies the wrong thing.
- Neither draft notes that the **envelope** is shared. The merged plan should state it so the "sibling object" option is costed as a jar change or a full local response type, not as a free third way.

For the sale-item side both drafts are correct that the DTOs are local. Codex adds the point that matters: `@XmlElement(required=true)` on the existing fields and primitive defaults would make new fields appear on the off path as `0` / `false` unless they are nullable wrapper types with per-field omission; off-byte goldens decide it. Gemini does not consider off-path serialisation of the new fields at all.

### 2.2 Does flag-off execute no SQL against the new columns and return identical bytes?

- **Codex:** yes by construction. Legacy SQL constants, bind lists and mappers are retained unchanged; the on-path is a *separate* query and mapper; the rule "never put new identifiers in a `CASE`, `COALESCE`, disabled `WHERE` or always-executed join, because Oracle resolves identifiers at parse time" is correct and is the single most important sentence in either draft. Its proof shape (SQL-string and bind assertions on the DAO plus deterministic JSON/XML goldens) answers intent question 8 with "both". The one gap: it does not say that DS runs with `ignoreAcceptHeader(false)` and an XML-first default, so the golden set must include the no-`Accept` case, because that is what a naive consumer gets.
- **Gemini:** the intent is right ("original SQL, no new fields") but task A2 says "update `GET_CLUB_DEFAULT_EXTERNAL` via a flag-gated conditional, joining `spl_extensions`". If that conditional lives in Java and selects between two constants, it is fine; if it is inside the SQL, it fails with ORA-00904 the moment the columns are absent, flag or no flag. The draft never makes the distinction, and "SQL falls back seamlessly to schemas without new columns" (B2) is asserted rather than designed. It also does not say how "byte-identical" will be proved; intent question 8 is unanswered.

### 2.3 Is MICO protected?

- **Codex:** the only draft that separates the two MICO paths (RestTemplate into the shared envelope for club defaults; Feign with Accept JSON through `OrasvcClient` for sale items) and demands JSON **and** XML consumer tests. Correct. It could have been more concrete: the XML test should be a MICO-side JAXB unmarshal of a captured on-state body into the jar's `ClubDefaultExternalResponse`, which is a cheap test that can live in DS's test tree using the same jar.
- **Gemini:** "MICO ignores unknown JSON properties" is true of the sale-items Feign path (Spring's auto-configured Jackson is lenient) but is argued from the wrong class, and the club-defaults XML path is not covered. Its R1 mitigation would pass while the real risk remained.

### 2.4 Flag granularity

- The two repos already share at least one key (`datatrak-DT-18445_disable_spring_auditUser` is a constant in both), so **Gemini's one shared key is feasible** and Codex's objection ("couples LD-project configuration") is weaker than written. Codex's remaining argument stands: separate keys let the reader (service fields) and the writer (M&O catalog save, SAI sync, POS email) be rolled back independently, and the M&O flag gates writes and emails while the service flag gates reads. Recommendation for the interview: two keys, both club-targetable, both default off, names per each repo's convention (`datatrak-service-DT-21555-guest-pass-fields`, `datatrak-DT-21555-guest-pass`), with the runbook stating they are flipped in the fixed order M&O → service. If the DataTrak team prefers one key, the plan still works; only the independent-rollback row in the risk register changes.
- Both drafts put a club context on the flag. Codex adds the operationally important details: use the canonical club number (leading zeros) as the LD key in all three evaluators, evaluate with default `false`, treat evaluation exceptions as off, and never let the caller's query string stand in for a validated club. The DS `FeatureService` has no exception-safe variant (`.../launchdarkly/FeatureService.java:18-43`), so Codex's "wrap unexpected evaluation errors explicitly" is a real task, not boilerplate; Gemini does not mention it.
- Codex's note that a default of `false` does not make an SDK forget a cached `true` during an LD outage, and that rollback of the scripts must therefore wait for *observed* off on every instance, is right and belongs in the runbook. Gemini has no rollback stop rule.

### 2.5 The M&O gating pass (PR #6643)

- **Codex's guard inventory** (§4 table) matches the branch: catalog SELECT/INSERT/UPDATE and the SAI sync statements in `CatalogItemsDB.java` (lines 472, 574-576, 886, 925, 1078-1125 on the branch), `CatalogItemDaoImpl`, `EditClubOnlineDaoImpl` (merged SELECT at `:30-33`, so a legacy string is needed), `JdbcClubDao.getProspectLiabilityLanguage`, `PointOfSaleDaoImpl.transactionContainsGuestPassItem`, both `PointOfSaleDB` wrappers and the six call sites. Its key insight is verified: `sendGuestPassSaleEmail` runs the new-column query *first* (`ProspectServiceTransactionsImpl.java:192-193`) and only then resolves the club, so a club-context flag requires reordering (resolve club from old-schema SQL → evaluate flag → only then `transactionContainsGuestPassItem`). "Guarding only `sendMemberEmail` is too late" is exactly right.
- **Gemini's** "add `FeatureService` gates to all 17 modified files" is the wrong unit. Six Java files reference the new identifiers on the branch; the rest (state class, JSP, `PointOfSaleDB`, call-site swaps) are reached through them. Gating by file count would over-touch Chancy's branch and still miss the ordering problem above. "For UI/M&O pages, the fields are hidden" does not say server-side, and a CSS-hidden field still posts its value into the save path.
- Codex's shared-catalog paragraph (catalog items are shared across clubs; per-destination evaluation during SAI propagation; partition mixed batches) is a real concern given the `UPDATE saleitems ... (SELECT ... FROM catalogitems)` sync at `CatalogItemsDB.java:1124-1125`, but it is the most expensive single item in the plan. It should be confirmed with Chancy in A3 before any code, and if the catalog edit context is always one club in practice, it collapses to "evaluate once with the editing club".

### 2.6 The product-type problem (G12) and the member-id problem (G2)

Only Codex notices that **flag-on returns nothing useful unless the query changes**: both queries select `cgi_service = '1'` (`PointOfSaleSql.java:45,66`), and guest passes are products (`CatalogItemsDB.java:830` on the branch: `guestPassItem = productItem && ...`). Gemini's U2 ("`saleItems.spr` returns the `guestPassOnline` flag …") would be satisfied by an empty list. This, plus CF-14 (the strict-GUID `memberId`), means Gemini's success criterion 3 (dev switch to `STP_CATALOG_SOURCE=datatrak`) cannot be reached under its own plan, and its open question 3 ("leave G2 strictly parallel") defers the thing that blocks it.

Codex's answer (a separate guest-product query, reached by a memberless branch on the same endpoint, with the member path untouched so MICO's shop is not widened) is the smallest change that makes G1 usable. Two cautions for the merge:

- Preserving the exact flag-off failure for a missing `memberId` (Spring's missing-parameter 400 versus the validator's envelope) is a correctness point, but "prefer distinct MVC mappings" is over-engineering; an `@RequestParam(required=false)` plus an explicit guard that reproduces the baseline when off is simpler and testable.
- `cgi_online = '1'` for products is a policy question (how does an admin set it for a product?) and is correctly parked as CF-23. The merged plan should say what happens if the answer is "they cannot": the on-path query drops the predicate for `cgi_service = '0'` items and relies on `SAI_GUEST_PASS = '1'` as the online marker.

## 3. Completeness against the intent's success criteria

| Criterion | Codex | Gemini |
|---|---|---|
| 1 Service PR, one club-targetable flag, tests both ways, field-name table | Covered (B1–B5, contract v4.1 table, V1/V2). Over-delivers with memberless + product query, which the criterion needs anyway. | Partially: fields and flag yes; the field table is not written; proof method for "today's SQL and shape" unspecified; product query absent. |
| 2 M&O PR gated, H2 both states, delivery Chancy can accept, G9 optional | Covered (C1–C6), including a physically-absent-column H2 schema (C5) and the costed delivery options. | Named but not designed: "H2 handles both states" is false as stated; no legacy schema; delivery costed only as "stacked". |
| 3 BFF adapter/fixtures, {absent, off, on} × {club, items} matrix, capability report with flag state, dev switch only after DT flag | Covered (D1–D3, R5/R6) and improved: strict zone/type, honest `unknown` flag observation, no off-state fields added just to advertise a flag. Adds a sanitizer, which is outside the criterion. | Covered at the level of a sentence each (C1–C3). "Capability report reflects DT flag state" is listed but the BFF cannot observe the DT flag; Codex explains why. |
| 4 Runbook with owner, verification, rollback per step; registered in V-P1 and §10 | Covered (R0–R7 with stop rules, verification SQL shapes, register updates in E4). | A single task D1 with the sequence in one line; no verification queries, no rollback steps, no owners beyond "assigned". |
| 5 House rules: mock suites, Sonar, no secrets, four verdicts, ledger | Covered explicitly (V6, V8, completion vocabulary section). | Four verdicts reduced to a parenthetical; no Sonar/coverage floors; ledger not mentioned. |

## 4. Phasing and ordering

- **Codex:** A (decide) → B/C in parallel → D → E matches the intent's order (scripts → code off → flag on in dev → verify through the service → BFF switch → `guest-pass-online`). It adds two correct refinements: default-off safety must exist *before* the DS PR is merged because `main` auto-deploys to dev; and "code off → scripts" must also be proven, because that is the state production will be in if the DBA window slips. Its R-sequence enables M&O before the service, which is right (data must exist before the reader is switched on). Weakness: A1–A4 are all "day 1–2" and A2 is a gate for B2; if the spike fails the jar route pushes B2 past the sprint, which Codex acknowledges but does not reflect in the day plan.
- **Gemini:** phases are in the right macro order, but D1's sequence ends "BFF switch → Verification", whereas the intent verifies through the service *before* the BFF switch. Phase C3 "stage the helm change" is fine as long as the signed commit is not merged until R4 is observed; the draft does not say so.

## 5. Risk coverage

- Codex's R1–R16 cover the real failure modes and are mostly tied to a gate. R2 (flag inside SQL), R7 (email gate after guest SQL), R8 (LD cached true during drop), R14 (test include list) and R15 (auto-deploy before readiness) are all verified concerns. Missing: the XML-first default content type as a golden-set risk; the `@XmlElement(required=true)` / primitive-default leak on the off path is mentioned in text but not as a register row; and no risk row for "A2 spike fails → jar route → calendar slip", although Dependencies costs it.
- Gemini's three risks are thin and R1's mitigation is wrong (see §2.3). R3 ("pass `TZL_ABC_CODE` as-is, letting the BFF rely on Java's valid IANA lookup strings") conflates Java and Node; the BFF validates nothing today (`datatrakServiceCatalog.ts:199`), and `TimeZone.getTimeZone` on the Java side silently returns GMT for unknown ids, as Codex notes. No risk for the product filter, the member id, LD propagation, the include list, or auto-deploy.

## 6. Feasibility in two weeks, in repos we do not own

- **Codex** estimates 17–21 person-days across four roles in ten working days and says so. Realistic only if a DS engineer and a DT engineer are actually assigned and Chancy/PK review inside the window. Items that should be cut or deferred to keep the critical path (A2 → B2/B3/B4 → B5 → PR) inside two weeks:
  - U2's "rendered page bytes" for the M&O JSPs. `datatrak` has TestNG + H2 and a handful of `MockMvc` integration tests; there is no JSP-rendering harness. Replace with: server-side conditional on the state object, a unit test that the off-path state carries no guest fields, and a manual before/after screenshot in the PR.
  - The BFF HTML sanitizer (D1/U13). It is a sound security point, but club-authored HTML already reaches the dialog through `prospectTerms` today, so it is not new exposure from G1. Register it as a carried finding with an owner rather than adding a dependency in this sprint.
  - Cache-transition proofs with a fake clock (U12/D2). Keep the rule ("BFF exposure flag first, then wait TTL or restart") in the runbook; drop the test matrix.
  - CF-23's mixed-batch partitioning until A3 confirms the editing context is ever multi-club.
  - Per-request exposure re-evaluation ahead of cache use is already how `requireShortTermPass` behaves (flag at `:66` on every request); D2 should not re-implement it.
- **Gemini** fits in two weeks because it is incomplete; executing it would produce a service PR that returns no products, an M&O PR that cannot prove absent-column safety, and a BFF that still cannot call `saleItems.spr`.

## 7. Definition of done

- **Codex:** V0–V8 with named owner slots, a gate that cannot pass without an accepting owner, and the four verdicts spelled out with the right "blocked ≠ verified" discipline. "Implementation complete requires V0–V6 and V8; V7 may be blocked" is the correct reading of the mock-proven bar. It is the house style from 0004.
- **Gemini:** four gates, owners given as roles ("BFF/DT", "PRODUCT/QA" for a deploy runbook), no CF/RQ register, no traceability from U-ids to gates, no Sonar/coverage floors, no statement of what "blocked" means for the dev read.

## 8. Strongest ideas to keep

From **Codex**:
1. Separate legacy and extended SQL constants, bind lists and mappers; the "Oracle resolves identifiers at parse time" rule; SQL-string assertions plus JSON/XML goldens as the proof of byte-identity.
2. The A2 converter spike as a hard gate before field work, and the explicit rejection of `@JsonUnwrapped`.
3. The product-filter and memberless-listing findings, and the separate guest-product query that leaves MICO's shop untouched.
4. The email reorder (resolve club from old-schema SQL → flag → guest SQL) and the six-call-site audit.
5. The R0–R7 runbook with stop rules, "observed off on every instance" before any drop, and the metadata-only verification SQL that prints no customer data.
6. The honest capability report: `confirmed-on` / `confirmed-off` / `unknown` with provenance, and the rule that no off-state field is emitted merely to advertise a flag.
7. The costed delivery options into Chancy's branch and the costed jar-bump fallback.
8. The physically-absent-column H2 schema (C5) as the only way to prove U1 in `datatrak`.

From **Gemini**:
1. The shared-key question, now backed by evidence that the repos already share keys; it should be an explicit interview item, not dismissed.
2. The compact five-use-case / four-phase shape. The merged plan should read closer to this length while keeping Codex's content; 0004 was readable and this sprint's plan should be too.
3. "Stage the helm change, merge only after the DT flag is confirmed on" as a one-line statement of criterion 3's condition.

## 9. Gaps in both drafts

1. **Shared envelope.** `ClubDefaultExternalResponse` is from the jar; the "sibling object" option is not free. State it.
2. **XML-first default content type** in DS (`SpringConfiguration.java:284`) and the likely-XML MICO club-defaults path. The golden set must include no-`Accept`, `application/xml` and `application/json`, and the MICO-side proof is a JAXB unmarshal, not a Jackson one.
3. **Timezone format.** `TZL_ABC_CODE` values were not sampled (DB access is out of bounds); neither draft says what the BFF should do if the value is a Java-only alias (for example a three-letter id). Codex's "explicit alias map, no GMT fallback" is the right policy; the merged plan should add a one-line task to ask the DBA for the distinct values in dev rather than guessing.
4. **The DS flag helper is not exception-safe.** Both evaluators must treat an LD exception as off; only Codex says so, and neither names the test.
5. **DT PR tests.** The branch already has `ProspectServiceTransactionsImplEmailTest` and two `PointOfSaleDBGuestEmailTest` classes; the gating pass must update them (they currently assert the email is sent unconditionally). Codex lists them in C5; Gemini does not know they exist.
6. **The intent's own small error** (`JdbcClubDao.getLocalTimeZoneAbcCode`) should be corrected in the merged plan so it does not propagate.

## 10. Positions on the intent's open questions, for the interview

1. **DTO strategy:** on-path local subtype, proven by the A2 spike in both converters, with `@XmlSeeAlso` on a local root subclass if JAXB needs it; jar bump only if the spike fails. Never a bare subclass without the spike.
2. **Flags:** two keys, club context, default off everywhere; shared project confirmed by precedent, so either choice is implementable.
3. **Delivery into Chancy's PR:** PR onto `feat/NOJIRA-guest-pass-email` (Codex's recommendation, about one day of coordination). A stacked follow-up is only acceptable with a release rule that the unguarded PR never deploys alone, which we cannot enforce in a repo we do not own.
4. **G2 inside G1:** yes, as the bounded memberless branch on the same endpoint. Deferring it leaves criterion 3 blocked by construction.
5. **Timezone:** emit `TZL_ABC_CODE` as-is from the service; validate strictly in the BFF against Node's `Intl.supportedValuesOf('timeZone')` with an explicit alias map; unknown closes the club.
6. **Liability wire format:** base64 UTF-8 HTML like `prospectTerms`; the byte-versus-character limit is Terry's; the on-path form rejects over-limit input before SQL.
7. **Ownership:** Codex's R-table owner slots, filled with names at kickoff.
8. **Proof of byte-identity:** both SQL-string/bind assertions and converter goldens, including the no-`Accept` case.
