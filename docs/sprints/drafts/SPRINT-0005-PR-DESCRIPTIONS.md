# Sprint 0005 — PR descriptions (as opened 2026-10-07)

Three pull requests, opened by the lanes and not merged: online-join-bff **#112** (normal, base `main`, head `b22febc`, all checks green incl. SonarQube after one S3776 fix); datatrak-service **#591** (**draft**, base `main`, head `2a5d599`, Build / Endor / SonarQube green after one test fix and two Sonar passes); datatrak **#6800** (**draft**, base `feat/NOJIRA-guest-pass-email` — Chancy's PR #6643 branch, head `1c5755b2`, CI / Build green on run 3 after a withdrawn mock-maker change; the repo's Sonar runs inside the Build job and surfaces no separate gate check). No reviewers requested. The bodies below are the lane files `SPRINT-0005-PR-DESCRIPTIONS-{BFF,DTS,DTM}.md` verbatim.

---

# Sprint 0005 — PR description (BFF lane)

PR on `abcfinancial/online-join-bff`, branch `prospect-wallet/sprint-0005` → `main`. Title: `feat: read the guest-pass fields from the DataTrak service layer (contract v4.1)`. The body below is what was passed to `gh pr create --body-file`. Opened at `8f8e156`; the bump job pushed `ca3bb38` (1.3.0); the first Sonar scan failed on one S3776 finding in the demo script, fixed behaviour-unchanged in `b22febc`; all checks green at `b22febc` (CI / Build, Endor Labs, LD flag scan, SonarQube; Bugbot posted nothing).

---

## What changes

`DatatrakServiceCatalog` (`STP_CATALOG_SOURCE=datatrak`) now codes against the **contract v4.1 §8a(e) field table** — the two DataTrak service-layer responses the Guest Pass BFF reads once the Sprint 0005 datatrak-service PR, the DBA scripts and the DT service flag land. Nothing here changes what the browser sees.

- **New endpoint.** `getOffers` reads the club-scoped, member-less `GET {base}/club/guestPassItems.spr?clubNumber=` instead of the member-scoped POS `/pos/saleItems.spr` (CF-14 no longer applies). `&saleItemId=` exists on the wire for a single-item read but is unused: the orchestrator re-reads the list (`requireOffers`) before side effects, so one path and one cache suffice.
- **Confirmed names.** `club.prospectLiability` (base64 HTML, decoded like `prospectTerms`) → `waiverText`; `club.timezone`; items carry `saleItemId`, `catalogItemId`, `catalogItemName`, `catalogPrice`, `salePrice` (wins when present and parsable, else `catalogPrice`), `taxed`, `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType`. The never-existing `waiverText` wire field is gone; `DatatrakSaleItem*` types are replaced by `DatatrakGuestPassItem` / `DatatrakGuestPassItemsResponse`.
- **Strict timezone validation** (`adapters/platform/timezoneId.ts`): a club resolves only on a Node-supported id (`Intl.supportedValuesOf('timeZone')`), an explicit alias (`US/*`, `Canada/*`, `EST`/`CST`/`MST`/`PST`/`HST`/`AST`, `GMT`/`UTC`) or a spelling `Intl.DateTimeFormat` canonicalises to a supported id. Anything else fails closed with `missing: ['timezone:invalid']` — never GMT. Missing stays `missing: ['timezone']`.
- **Strict item type.** `PRODUCT` → `product`, `SERVICE` → `service`, `BILLING` → `billing` (the `CatalogOffer` union gains `'billing'`; the v1 filter already rejects non-products as `not-a-product`). Missing or unknown → skipped with the new reason **`unknown-type`**, listed in the capability report in catalog order like every other skip; never coerced to a product.
- **U6 envelope.** `messages.status === 'error'` or `saleItems === null` (flag off, unknown club, columns absent) → no offers with the report reason `unavailable` (gate 404), never a fixture.
- **`dtFields` observation.** `ClubReport.dtFields: 'present' | 'absent'` — `present` when the club body carried `timezone` or `prospectLiability` or the items read answered a success envelope; else the note prints `DT fields: absent (off, old code or columns missing — unknown which)`. An observation about the bytes seen, never a claim about the remote flag.
- **Fixtures labelled.** `getClubDefaultExternal.recorded.json` (2026-09-18) is the absent / off club; `getClubDefaultExternal.synthetic.json` carries the v4.1 on shape; `saleItems.synthetic.json` → `guestPassItems.synthetic.json` (v4.1 envelope); new `guestPassItems.unavailable.synthetic.json` (U6); `saleItems.*.recorded.json` kept as CF-14 history; the README documents the three labels and the reserved `*.flag-on.recorded.json` slot for the first scrubbed dev recording.
- Demo and mock catalog wording: the capability notes print a `DT fields` line; the live-read line says *pending* with its four preconditions; `MockClubCatalog.standsInFor` names `guestPassItems.spr`.

## The six-cell matrix (`__tests__/datatrakServiceCatalog.test.ts` → `describe('matrix')`)

| Cell | Fixture | Pinned outcome |
|---|---|---|
| absent / club | `getClubDefaultExternal.recorded.json` | club incomplete `missing: ['timezone']`, timezone `missing`, `dtFields: absent` |
| absent / items | `saleItems.noMember.recorded.json` (400), `saleItems.emptyMember.recorded.json` (error envelope) — CF-14 **history** | no offers; `http 400` without the CF-14 hint / `error (unavailable)`; the new path never sends a member id or calls `/pos/` |
| off / club | the same recorded file (one file, two labels) | adapter output identical under both labels; the file carries none of `prospectLiability` / `timezone` / `waiverText` |
| off / items | `guestPassItems.unavailable.synthetic.json` | no offers, reason `unavailable`, `dtFields: absent`, cached like a success |
| on / club | `getClubDefaultExternal.synthetic.json` | club resolves on `America/Chicago`, `waiverText` = decoded `prospectLiability`, consent texts `club`/`club`, `dtFields: present` |
| on / items | `guestPassItems.synthetic.json` | exactly the one eligible product (`core-flex-pass`, `$30.00` from `salePrice`, 7 days, 1 visit); skipped `core-3-visit-pass (multi-visit)`, `core-pt-session (not-a-product)`, `core-mystery-item (unknown-type)`, `core-towel-service (not-flagged)`; `dtFields: present` |

Plus: timezone unit tests (`timezoneId.test.ts` — `America/Chicago` accepted, `US/Central` → `America/Chicago`, `Nonsense/Zone` → invalid, blanks → missing), the strict `itemType` and `salePrice` fallback mapper tests, and the fail-closed transport tests (404 / 5xx / network / timeout / resolver failure).

## Proof (this branch, Node 26)

- `npx jest --coverage`: **69 / 69 suites, 706 passed (2 skipped)**; coverage **97.47 % statements / 86.5 % branches / 97.19 % functions / 98.28 % lines** (floors 84 / 67 / 67 / 84 unchanged).
- `npm run lint`: clean. `npx tsc --noEmit`: clean. `npm run build`: clean.
- `STP_EMAIL_TRANSPORT=mock npm run demo:short-term-pass`: **58 / 58** (fixture catalog; the `.env` SMTP sink was not running, which is why the mock transport was selected — unrelated to this change).
- UI proof (no UI change): `online-join-ui` `__tests__/routes/ShortTermPass/ShortTermPassPage.test.tsx` **16 / 16** on `main` `3967c43` — the unavailable block renders for flag-off and for zero eligible offers.

## Browser contract unchanged

`/api/short-term-pass/*` (§4–§6) is byte-for-byte what v4 serves: `offers[]`, `selectedOfferId`, the consent set and the purchase result are untouched. Only the adapter behind `ClubCatalogPort` and its capability report changed.

## Not in this PR / verdicts kept separate

- **Live read: pending.** The datatrak-service PR (new endpoint + the two club fields) is unmerged; the DBA scripts have not run; the LaunchDarkly key `datatrak-service-DT-21555-guest-pass-fields` is not on for any dev club; PLATFORM has not set `STP_DATATRAK_SERVICE_URL` / `STP_DATATRAK_SERVICE_AUTH`. Until all four hold, the dev adapter fails closed exactly as today (verdict 3 stays pending).
- **D7 dev switch-over: pending by decision** — no helm PR, no remote host probed, no secret touched. Precondition text in `SPRINT-0005-EXECUTION-SUMMARY-BFF.md`.
- **HTML sanitiser for club-authored consent HTML:** carried finding (owner SECURITY + UI). `prospectLiability` reaches the UI `DocumentDialog` (`html-react-parser`) and the BFF stand-in prospect mail through the same path `prospectTerms` already uses — no new sink, so no new dependency this sprint.
- Contract §8 / §8a(e) / §10 row deltas are listed for the orchestrator (E3) in the execution summary; this PR does not edit the contract.

🤖 Generated with [Claude Code](https://claude.com/claude-code)


---

# Sprint 0005 — DTS lane PR description (as posted)

PR: https://github.com/abcfinancial/datatrak-service/pull/591 (draft, base `main`, head `DT-21555-guest-pass-service-fields`), opened 2026-10-07 by the DTS lane at head `1ac07f4`; head `b36f727` after the CI run-1 test fix and `4fae6a9` / `2a5d599` after the Sonar passes (body unchanged). Title: `DT-21555 Expose the club liability text and timezone on getClubDefaultExternal.spr and add a club-scoped guestPassItems.spr, behind a feature flag`. Reviewers not requested (PK + Chancy named in the body). No credential and no header literal appear below or in the PR.

---

## What this changes

Guest Pass (DT-21555) needs three things from the DataTrak service layer that the `.spr` endpoints do not expose today: the club's liability text, the club's timezone, and the club's deployed guest-pass products (the POS `saleItems.spr` is member-scoped and lists services only). This PR adds them **behind one club-targetable LaunchDarkly flag that defaults off everywhere**, so the code can deploy before or after the DBA scripts (`SPL_EXTENSIONS.SPLEX_PROSPECT_LIABILITY`, `SALEITEMS.SAI_GUEST_PASS*`) and the scripts can be rolled back under deployed code.

**Flag:** `datatrak-service-DT-21555-guest-pass-fields` (`LDFeatureFlagConstants.GUEST_PASS_FIELDS`), evaluated by the new `com.abcfs.launchdarkly.helper.GuestPassFeature.isOn(clubNumber, vpd)` — club + VPD context, default **off**, `false` in both local yml files. The helper returns `false` locally (before any LaunchDarkly call) when the club number is not a canonical five-digit club number, `false` when the `FeatureService` bean is missing, and `false` + warn when the evaluation throws. One decision per request, shared by statement, binds and row mapper.

### `GET /external/club/getClubDefaultExternal.spr?clubNumber=` — unchanged when off; on, `club` gains

| Field | Type | Source | Encoding / null rule |
|---|---|---|---|
| `club.prospectLiability` | string | `SPL_EXTENSIONS.SPLEX_PROSPECT_LIABILITY` (left join on `spl_id` + `vpd_id`) | base64, exactly like `prospectTerms`: null column or no extensions row → `""` encoded → `""` |
| `club.timezone` | string | `TIMEZONELOOKUP.TZL_ABC_CODE` via `SERVICEPROVIDERLOCATIONS.TZL_ID` (left join) | `ZoneId.of` accepted as is; `ZoneId.SHORT_IDS` alias mapped (`EST` → `-05:00`, `CST` → `America/Chicago`); otherwise raw + warn; omitted when the club has no lookup row |

Every existing field, `branding` and `hideEnrollPage` are unchanged in both states. The on path answers a local subclass pair (`GuestPassClubDefaultExternalResponse` / `GuestPassClubDefaultExternal`, same `@XmlRootElement`, `@XmlSeeAlso`) — no `internal-interface` jar bump.

### NEW `GET /external/club/guestPassItems.spr?clubNumber=[&saleItemId=]`

In `ClubExternalController` beside `getClubDefaultExternal` (same `produces`, same header match, same `setVpdFromClubNumber` prelude). Envelope `guestPassItemResponse { club, saleItems { saleItem[] }, messages }` in the `saleItemResponse` shape.

| Field | Source | Rule |
|---|---|---|
| `saleItems.saleItem[]` | `SALEITEMS sai JOIN CATALOGITEMS cgi JOIN SERVICEPROVIDERLOCATIONS spl` where `spl.spl_abc_id = :clubNumber AND sai.sai_active = '1' AND cgi.cgi_active = '1' AND sai.sai_guest_pass = '1' AND cgi.cgi_service = '0' AND cgi.cgi_online = '1'` `[AND sai.sai_id = :saleItemId]`, `ORDER BY cgi.cgi_name` | flag on only; products only; services never rows |
| `saleItemId`, `catalogItemId`, `catalogItemName` | `SAI_ID`, `CGI_ID`, `CGI_NAME` | strings |
| `catalogPrice`, `salePrice` | `CGI_SALE_PRICE`, `SAI_SALE_PRICE` | strings, as `SaleItem.catalogPrice` |
| `taxed` | the `taxed` CASE copied from `GET_ONLINE_SALE_ITEMS` (a test asserts it is identical) | boolean |
| `guestPassOnline` | `SAI_GUEST_PASS = '1'` | always `true` by the WHERE; kept on the wire |
| `guestPassContractDays`, `guestPassVisits` | `SAI_GUEST_PASS_CONTRACT_DAYS`, `SAI_GUEST_PASS_VISITS` (from `SALEITEMS`, not the catalog default) | int; null stays null |
| `itemType` | `CGI_SERVICE` `0` / `1` / `2` | `PRODUCT` / `SERVICE` / `BILLING`; always `PRODUCT` here |

Flag off, unknown club (`vpd == 0`), columns not yet added, or any failure → `200` with `messages.status = error`, text `Not available`, `saleItems = null` — never a 500. **Flag off executes no SQL** (asserted with `never()` on the template).

## Proof that "flag off is today"

- **SQL + bind goldens:** `DtManagedClubDaoImplGuestPassSqlTest` asserts the flag-off statement equals the `GET_CLUB_DEFAULT_EXTERNAL` literal copied verbatim from `main` with the `main` binds (`clubNumber` CHAR, `active` CHAR = 1) and `ClubDefaultExternalRowMapper`, and that the on statement is that literal plus exactly the two selected columns and the two `LEFT JOIN`s (same WHERE, same binds). The `main` constant is not modified; the on path has its own key.
- **Body goldens:** off and on bodies for `application/json`, `application/xml` and no `Accept` (XML, per `defaultContentType`) through `MappingJackson2HttpMessageConverter` (mirroring `SpringConfiguration.objectMapper()`) and `Jaxb2RootElementHttpMessageConverter`, compared with `test/resources/guest-pass/*` written from fixed inputs. Off bodies carry neither new element; on JSON equals off JSON plus the two fields; on XML keeps the `<clubDefaultExternalResponse>` root.
- **No POS file touched:** `git diff --stat origin/main..HEAD` lists nothing under `controller/POSController.java`, `validator/`, `repository/pos/`, `api/pos/`.

## Consumer safety

The on-path XML unmarshals into the **jar** `ClubDefaultExternalResponse` with a JAXB context built from the jar class only (the `xsi:type` on `<club>` is ignored, the club arrives as the jar `ClubDefaultExternal` with every shared field intact) — which is what MICO's `oraSvcRestTemplate` does. The on-path JSON deserialises into the jar envelope with `FAIL_ON_UNKNOWN_PROPERTIES = false` (MICO's `WsShop` setting). The items JSON reads into the POS `SaleItemResponse` shape with a tolerant mapper. Null fields are omitted in both media types.

## ORA-00904 fallback (columns not yet added)

When the flag is on but the scripts have not run, the on statement fails with `ORA-00904`. `ClubExternalServiceImpl` catches the `BadSqlGrammarException` whose cause is ORA-00904 (SQLException error code 904 or message), warns **once per club** (`guest-pass.columns-absent`) and answers the flag-off shape (club defaults) / the `Not available` envelope (items). The on statement is retried on every request, so the read heals as soon as the scripts land, without a restart. Any other failure behaves as today. This is a compatibility proof, not the rollout order — the runbook flips the flag only after the scripts.

## Tests and the include list

New test classes, every one listed in the `include` list under `tasks.named('test')` in `dtWar/build.gradle` (a test not listed there never runs): `GuestPassFeatureTest`, `LDFeatureFlagConstantsTest` (extended), `DtManagedClubDaoImplGuestPassSqlTest`, `DtManagedClubDaoImplGuestPassItemsSqlTest`, `ClubExternalServiceImplGuestPassTest`, `ClubExternalControllerGuestPassItemsTest`, `GuestPassClubDefaultExternalRowMapperTest`, `GuestPassItemRowMapperTest`, `GuestPassItemSerializationTest`, `GuestPassClubDefaultSerializationSpikeTest` (A2 spike, extended with the goldens). The README's test note now says what governs what runs.

**CI is the first compile.** Artifactory is unreachable from the authoring machine, so Gradle could not run locally; the self-contained classes (DTOs, mappers, helper, SQL bundle, serialisation tests — 50 / 50) were compiled and run standalone with `javac` + TestNG against cached jars (proxy versions recorded in the sprint summary). The DAO, service and controller tests run for the first time here. Reviewed by PK + Chancy (not requested here).

## Rollout

Runbook: `docs/deploy/guest-pass-db-and-flags.md` in the Guest Pass planning repo (flag creation, dev and prod order, stop rules). No club is targeted until the runbook's R3/R4 rows; nothing in this PR changes behaviour while the flag is off.

🤖 Generated with [Claude Code](https://claude.com/claude-code)


---

## What this is

A review-and-gap-fill pass over the `MO_guest_day_pass_DT-21555` gating Paul Knuth added to this branch on 2026-10-07 (`0d0f2d06`, `356613de`, `5afb5289`, `77f12719`). It does not re-implement or restructure that gating, does not rename the key or the helper, and does not touch `sql/`. It adds the SQL + bind goldens that prove the flag-off path runs the pre-change statements, fills four small gaps, and records the accepted deviations so the reviewers can check each inventory site in one table.

Base: `feat/NOJIRA-guest-pass-email`. Six task commits (one per task) plus two test-only commits: `3f683a8a` tried Mockito's subclass mock maker for `PointOfSaleState` and broke the whole suite (withdrawn), `1c5755b2` replaces it with a stub subclass per test. CI on `1c5755b2` is green: 1615 tests, 0 failures, 0 ignored. Kept as draft until Chancy confirms a PR onto his branch is wanted.

Reviewers to name (not requested yet): Paul Knuth (author of the gating), Chancy (branch owner).

## Review map: every site that reads or writes a new column, its guard, the off branch, and the test in this PR that pins it

| Site (head of this PR) | PK's guard | Off branch (flag off for the club) | Pinned by |
|---|---|---|---|
| `CatalogItemsDB.loadCatalogItem` (select ~473, state values ~581) | `guestDayPassEnabled(state)` → session club | select without the three `CGI_GUEST_PASS*` columns (byte-equal to `main`); state values forced `"0"` | audit (string compared to `main` offline); page test covers the forced `"0"` on validate |
| `CatalogItemsDB.saveCatalogItem` insert / update (~846–975 / ~987–1056) | same decision captured once (`guestDayPass`) | INSERT with 60 placeholders (column list byte-equal to `main`; values list differs from `main` by whitespace only), UPDATE ending `CGIPTR_ABC_CODE = ? where CGI_ID = ?` with 53 binds (byte-equal to `main`); the three binds are not added | `CatalogItemsDBGuestPassSqlTest.catalogItem{Insert,Update}Sql_*` — on the two expressions moved verbatim into `catalogItemInsertSql(boolean)` / `catalogItemUpdateSql(boolean)` |
| `CatalogItemsDB.addSaleItem` (~1185), `updateSaleItemRecord` (~1198–1215), `saleItemInsertSql` | `guestDayPassEnabled(connection, clubId)` → **destination club** via `ClubDB.getClubNumber` | legacy `INSERT…SELECT` and `update SALEITEMS set SAI_ACTIVE = (SELECT CGI_ACTIVE …)` (both byte-equal to `main`) | `CatalogItemsDBGuestPassSqlTest.addSaleItem_*`, `updateSaleItemRecord_*` (exact SQL + binds via `mockStatic(ABCDbObject)`, `mockStatic(ClubDB)`, `mockStatic(Random)`; no captured statement contains `CGI_GUEST_PASS` / `SAI_GUEST_PASS` when off; null club number → legacy through the real helper) |
| `CatalogItemDaoImpl.updateSaleItemRecord` (~152), `insertSaleItemRecord` (~168) | club number read by SQL from the sale item / destination club; lookup failure → off + warn | `main` statements (byte-equal) | `CatalogItemDaoImplGuestPassSqlTest` (`ArgumentCaptor` on `jdbc.update`; club lookup throwing → legacy, no exception). Note: the club lookup (existing columns only) runs in both states |
| `EditCatalogItemsState.load` (~498), `EditCatalogItemsSecondaryPage.validate` (~119–141), JSP `<dt:ifEqual>` (51, 174) | `GuestDayPassFeatureFlag.isOn(session club)`; `guestDayPassEnabled` state flag | fields/JS not rendered; posted values forced `"0"`; no guest validation message | `EditCatalogItemsSecondaryPageGuestPassTest` (mocked state; off/on/no-session). Screenshots: **pending** (no M&O runtime on the authoring machine) |
| `EditClubOnlineDaoImpl.load` (~31–41), `saveProspectContent` (~46–68), `liabilityLanguage` (~71) | flag from `SPL_ABC_ID` of the club being edited | `select SPL_PROSPECT_TERMS, SPL_ABC_ID from serviceProviderLocations where spl_id = :clubId ` (see deviation 2), liability null, one UPDATE (`SPL_PROSPECT_TERMS`), nothing referencing `SPLEX_` / `spl_extensions` | `EditClubOnlineDaoImplGuestPassTest` (captured SELECT/UPDATE strings and binds; `never()` on the `String.class` select when off; `times(1)` update when off, `times(2)` when on) |
| `EditClubOnlineProspect.isValid` (4000-char check on both texts) | not gated | runs on a null liability (`safeLength` 0) | audit — no change needed |
| `JdbcClubDao.getProspectLiabilityLanguage` | reachable only from `sendGuestPassEmailToMember` | — | `ProspectServiceTransactionsImplEmailTest` (`clubDao` never touched when off) |
| `ProspectServiceTransactionsImpl.sendGuestPassSaleEmail(String)` (~195–220) | club → flag → `transactionContainsGuestPassItem` → member | early return; no guest SQL | PK's `sendGuestPassSaleEmail_flagOffSkipsGuestPassQueries` + new `…transactionId_flagOff_neverReachesTheAddGuestEmail` (`memberDao`, `clubDao`, `anySaleItemIsGuestPass`, `getMemberId` all `never()`) |
| `…sendGuestPassSaleEmail(PointOfSaleState)` / `sendGuestPassEmailForSaleItems` (~226–258) | flag → `anySaleItemIsGuestPass` → member; empty cart → transaction-id path | early return | PK's `…flagOffSkipsSaleItemQuery` + new `…posStateWithCart_flagOff_…`, `…posStateWithoutCart_flagOff_…` and a flag-on positive control |
| `ContactsDB.load(ADD_GUEST)` (via `BaseEmail` inside the `ContentsSuppliedEmail` that `sendMemberEmail` builds) | only reachable from `sendGuestPassEmailToMember`, which first reads `memberDao` and `clubDao` | never reached | the `never()` assertions above (javadoc in the test explains the reasoning) |
| `PointOfSaleDaoImpl.anySaleItemIsGuestPass` (~1046), `transactionContainsGuestPassItem` | callers gated as above | — | covered by the callers' tests |
| `sales/...PointOfSaleDB.handlePosTransactionCompleted` (~522), `sales3/...PointOfSaleDB` (~278) | `guestDayPassEnabled(state)` → session club; `sendGuestPassSaleEmailAfterCommit` | email never requested; `publishPosTransactionCompletedEvent` runs with the same return value | PK's after-commit tests + new `handlePosTransactionCompleted_flagOff_skipsTheEmailAndStillPublishes` / `…flagOn_…` in both `PointOfSaleDBGuestEmailTest` classes |
| Call sites `EAEApi` ×2, `POSApi` ×2, `PosPayPageCheckoutCompleteService`, `ElectronicAgreementDB` (+ three internal callers) | pass-through | unchanged | audit — all still call `handlePosTransactionCompleted` |
| `JdbcMemberDao.getGuestEmailInformation` | existing columns | not gated (no new column) | audit — noted |
| `sql/*.sql` | — | G9 (`ALTER TABLE … ADD (… DEFAULT …)` without the full-table UPDATE) already done by PK in `77f12719` | no change in this PR |

## Gaps filled

1. `dtWar/src/main/resources/launchdarkly-local.yml`: `MO_guest_day_pass_DT-21555: false` (was absent; a local run would have evaluated the default).
2. `GuestDayPassFeatureFlag.isOn`: a whitespace-only club number now returns `false` before `FeatureService` is consulted (`StringSupport.safeEmpty` is a null-safe `length()`, it does not trim). One-line change inside PK's guard; structure unchanged.
3. `GuestDayPassFeatureFlagTest`: key literal `"MO_guest_day_pass_DT-21555"` and context kind `"club"` pinned (no `LDFeatureFlagConstants` test exists in this repo); whitespace test added.
4. `ProspectServiceTransactionsImpl`: duplicate import of `GuestDayPassFeatureFlag` removed (Sonar S1128); the remaining import moved to its alphabetical position.
5. `CatalogItemsDB`: the catalog INSERT / UPDATE expressions moved verbatim into package-private `catalogItemInsertSql(boolean)` / `catalogItemUpdateSql(boolean)` so they can be golden-tested without a `DbConnection` and a session. String literals are byte-identical to PK's; only the wrapper changed.

## Accepted deviations from `main` (flag off)

1. `CatalogItemsDB.saveCatalogItem` INSERT: the values list is generated (`nCopies(60, "?")`) rather than hand-written, so it differs from `main` by whitespace only (`main` has a double space and a trailing space inside `values (...)`). 60 placeholders either way; column list byte-equal.
2. `EditClubOnlineDaoImpl.load`: `select SPL_PROSPECT_TERMS, SPL_ABC_ID from serviceProviderLocations where spl_id = :clubId ` versus `main`'s `select SPL_PROSPECT_TERMS from serviceProviderLocations where spl_id = :clubId ` (which used `String.class`). `SPL_ABC_ID` is an existing column and is how the flag is evaluated for the edited club.
3. `CatalogItemDaoImpl` and `EditClubOnlineDaoImpl.saveProspectContent`: one extra club-number lookup on existing columns runs in both flag states (needed to evaluate a club-context flag where no session is available).

## Pending

- Before/after screenshots of the catalog item page and the Edit Club → Online page with the flag off and on: cannot be taken on the authoring machine (no M&O runtime). Chancy / QA.
- CI: run 1 (`ee71e15b`) compiled everything and failed 7 new tests at `mock( PointOfSaleState.class )` (the inline mock maker cannot retransform that class); run 2 (`3f683a8a`, subclass mock maker) regressed the suite (230 failures in unrelated classes — Mockito 4.11 cannot mix mock makers under `-ea`); run 3 (`1c5755b2`) **pass**, 1615 / 0 / 0. Reviewer note: do not `mock()` either `PointOfSaleState`; the tests show the stub-subclass + objenesis pattern, created inside a stubbed `StaticSpringApplicationContext` because the sales3 class initialiser reads `EnvironmentProperties`.
- LaunchDarkly key creation (`MO_guest_day_pass_DT-21555`, boolean, club context, default off, dev + prod) is a PLATFORM / Chancy / PK handoff; nothing in this PR assumes it exists.

## Not in this PR

No change to `sql/`, to the flag key, to the helper's structure or to any `main`-path statement; no production flag flipped; no credential or header literal anywhere.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
