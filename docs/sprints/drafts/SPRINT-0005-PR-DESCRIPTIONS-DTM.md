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
