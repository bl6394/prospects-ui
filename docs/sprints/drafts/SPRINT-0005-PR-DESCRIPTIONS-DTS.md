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
