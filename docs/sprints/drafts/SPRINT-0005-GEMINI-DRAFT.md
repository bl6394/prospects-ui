# Sprint 0005: G1 — Guest-Pass Fields through the DataTrak Service Layer with Feature Flags

**Status:** Draft

## Overview

This sprint implements finding G1 from the DT-21555 handoff review: ensuring that the new `guest-pass` columns (added by the DBA scripts) are safely exposed through the DataTrak service layer to the BFF, with every read and write of the new columns hidden behind a strict, ordered LaunchDarkly feature flag. 

The scope spans three repositories:
1. **datatrak-service:** Adds the new fields (liability text, timezone, guest-pass flag, contract days, visits, item type) to the `/external/club/getClubDefaultExternal.spr` and `/external/pos/saleItems.spr` responses, tightly gated by a feature flag.
2. **datatrak:** Updates PR #6643 (`feat/NOJIRA-guest-pass-email`) so that its SQL and logic fall back to current behavior when the flag is off.
3. **online-join-bff:** Adapts the `DatatrakServiceCatalog` to consume the new response fields, verifies functionality with recorded fixtures, and toggles to the live DataTrak service in dev only after the flag is fully proven.

We will prove that when the flag is off, the queries and responses remain byte-identical to their current production state, ensuring a safe, revertible rollout.

## Use Cases

| ID | Behaviour and required result | Tasks |
|---|---|---|
| U1 | **Service Layer (Flag Off):** `getClubDefaultExternal.spr` and `saleItems.spr` execute their original SQL. `ClubDefaultExternal` and `SaleItemResponse` do not carry the new guest-pass fields. MICO functions normally. | Phase A |
| U2 | **Service Layer (Flag On):** `getClubDefaultExternal.spr` returns the new base64-encoded liability text and the IANA timezone. `saleItems.spr` returns the `guestPassOnline` flag, `contractDays`, `visits`, and `itemType`. | Phase A |
| U3 | **DataTrak M&O (Flag Off):** In PR #6643, `CatalogItemsDB`, `EditClubOnlineDaoImpl`, and `PointOfSaleDB` fall back to the pre-PR state. No SQL references `CGI_GUEST_PASS*`, `SAI_GUEST_PASS*`, or `SPLEX_PROSPECT_LIABILITY`. The `ADD_GUEST` email is not triggered. | Phase B |
| U4 | **BFF Consumption (Flag Off / Columns Absent):** `DatatrakServiceCatalog` falls back to its existing behavior. Unflagged items skip without error, preserving the BFF fail-closed stance. | Phase C |
| U5 | **BFF Consumption (Flag On):** `DatatrakServiceCatalog` maps the new fields successfully into the v4 contract. `STP_CATALOG_SOURCE=datatrak` handles the fields without falling back to synthetics. | Phase C |

## Architecture

### 1. DTO Strategy and Field Exposure
- **ClubDefaultExternal (datatrak-service):** Since the DTO lives in a shared middleware jar (`abcfinancial/middleware-internal-interface`), we avoid a cross-repo jar bump. Instead, we use a local wrapper or sibling JSON structure in `ClubExternalServiceImpl` / `ClubExternalController` (e.g., enriching the response dynamically) or subclass locally, to ensure the XML path for MICO doesn't break.
- **SaleItemWithDiscount (datatrak-service):** Exists locally in `com/abcfs/api/pos/`. We can safely add the fields (guest-pass flag, contract days, visits, item type). MICO ignores unknown JSON properties.
- **Timezone:** Extracted from `SERVICEPROVIDERLOCATIONS.TZL_ID` via `TIMEZONELOOKUP.TZL_ABC_CODE` using existing Java timezone parsing (`TimeZoneSupport.getTimezoneForClub`).

### 2. Feature Flag Granularity
- **Flag Key:** `datatrak-DT-21555-guest-pass` (shared across both `datatrak` and `datatrak-service` to avoid dual-flag synchronization issues). It will use a **club context**.
- **Default State:** `false` across all environments. Local overrides configured in `launchdarkly-local.yml` and `featureflag-local.yml`.

### 3. DataTrak PR #6643 Flag-Gating
- Modify Chancy's PR branch by wrapping every new read/write of `CGI_GUEST_PASS*`, `SAI_GUEST_PASS*`, and `SPLEX_PROSPECT_LIABILITY` with `FeatureService.computeBooleanFeature`.
- If off, fallback to legacy queries. For UI/M&O pages, the fields are hidden. The POS webhook bypasses the guest email entirely.

### 4. BFF Adapter Update
- `DatatrakServiceCatalog` updated to read the new fields instead of synthesizing them.
- A matrix of tests covering {columns absent, flag off, flag on} x {club defaults, sale items} using recorded `.json` responses.

## Implementation Plan

### Phase A: DataTrak Service Layer & DTOs (datatrak-service)
| # | Task | Files | Done when |
|---|---|---|---|
| A1 | Add `datatrak-DT-21555-guest-pass` to `LDFeatureFlagConstants.java` and YAMLs. | `LDFeatureFlagConstants.java`, `launchdarkly-local.yml`, `featureflag-local.yml` | Flag accessible in local/test. |
| A2 | Update `DtManagedClubSql.GET_CLUB_DEFAULT_EXTERNAL` via a flag-gated conditional, joining `spl_extensions` and mapping `TZL_ABC_CODE` + liability. Implement local DTO sibling mapping in controller. | `DtManagedClubDaoImpl.java`, `DtManagedClubSql.java`, `ClubExternalController.java` | Unit tests prove flag off is byte-identical, flag on adds fields. |
| A3 | Update `PointOfSaleSql.GET_ONLINE_SALE_ITEMS` conditionally. Add new columns to `SaleItemWithDiscount` and `DiscountOnlineSaleItemMapper`. | `PointOfSaleSql.java`, `JdbcPointOfSaleDao.java`, `SaleItemWithDiscount.java`, `POSController.java` | Flag on returns items; tests pass. |
| A4 | Add test files to `dtWar/build.gradle` `include` list. Run Sonar/JaCoCo locally. | `build.gradle`, `...Test.java` | `gradle test` green. |

### Phase B: DataTrak M&O Flag-Gating (datatrak PR #6643)
| # | Task | Files | Done when |
|---|---|---|---|
| B1 | Pull branch `feat/NOJIRA-guest-pass-email`. Add `FeatureService` gates to all 17 modified files (e.g. `CatalogItemsDB`, `EditClubOnlineDaoImpl`). | 17 PR files, `sql/*.sql` (hygiene) | PR branch compiles. |
| B2 | Ensure SQL falls back seamlessly to schemas without new columns when flag is off. H2 schema handles both states. | `CatalogItemDaoImpl.java`, `JdbcClubDao.java` | H2 tests run successfully on both states. |
| B3 | Submit stacked follow-up PR or commit to Chancy's branch (pending agreement). | — | PR submitted and linked. |

### Phase C: BFF Alignment (online-join-bff)
| # | Task | Files | Done when |
|---|---|---|---|
| C1 | Align `DatatrakServiceCatalog` to consume the finalized names confirmed in Phase A. | `datatrakServiceCatalog.ts`, `fixtures/datatrak/*` | Mappings updated. |
| C2 | Create recorded fixture matrix: {absent, off, on} states. Update tests. | `__tests__/datatrakServiceCatalog.test.ts` | Tests prove fail-closed and correct parsing. |
| C3 | Update Dev helm config for switchover only when dev DT flag is confirmed on. | `helm-configs/online-join-bff/dev.yaml` | `STP_CATALOG_SOURCE=datatrak` staged for dev. |

### Phase D: Runbook and Rollout
| # | Task | Files | Done when |
|---|---|---|---|
| D1 | Draft deployment runbook specifying exact rollout sequence (Scripts -> Code flag off -> Flag on -> BFF switch -> Verification). | `docs/deploy/guest-pass-db-and-flags.md` | Runbook documented and assigned to owners. |

## Files Summary

| Repo | Paths | Action |
|---|---|---|
| datatrak-service | `dtWar/src/com/abcfs/club/external/dao/DtManagedClubSql.java`, `.../ClubExternalController.java`, `.../LDFeatureFlagConstants.java`, `.../pos/sql/PointOfSaleSql.java`, `.../api/pos/SaleItemWithDiscount.java`, `dtWar/build.gradle` | MODIFY: Gated SQL injection, DTO wrapper/additions, flag setup. |
| datatrak | PR #6643 files (`CatalogItemsDB`, `EditClubOnlineDaoImpl`, `PointOfSaleDB`, etc.), `sql/*.sql` | MODIFY: Add `FeatureService` gating around new columns. DB script hygiene (G9). |
| online-join-bff | `src/services/shortTermPass/adapters/platform/datatrakServiceCatalog.ts`, `__tests__/datatrakServiceCatalog.test.ts`, `fixtures/datatrak/*` | MODIFY: Update consumer mapping, matrix tests. |
| helm-configs | `online-join-bff/dev.yaml` | MODIFY: Stage catalog source switchover. |
| prospects-ui | `docs/deploy/guest-pass-db-and-flags.md` | NEW: Rollout runbook. |

## Definition of Done
| Gate | Owner | Passes when |
|---|---|---|
| V1 - Service Layer | BFF/DT | datatrak-service PR reviewable, exposes new fields gated by LD, tests prove byte-identical legacy execution. |
| V2 - M&O App | DT (Chancy) | PR #6643 flag-gated successfully. H2 tests cover both states. DB scripts updated for rerun guards. |
| V3 - BFF | BFF | Matrix tests green against recorded responses. Capability report reflects DT flag state. |
| V4 - Runbook | PRODUCT/QA | Rollout sequence written with verification and rollback queries, attached to pilot gate V-P1. |

*(Execution vocabulary: mock-proven locally, live read blocked pending DBA script execution and DT PR merge, production unexposed.)*

## Risks & Mitigations
- **R1:** XML MICO consumption breaks if `ClubDefaultExternal` is modified heavily. *Mitigation:* We use a sibling field or a `@JsonUnwrapped` wrapper and verify `FAIL_ON_UNKNOWN_PROPERTIES=false` on MICO's end. Avoid jar bumps.
- **R2:** M&O PR #6643 conflicts or delays. *Mitigation:* Stacked PR approach. H2 schema guarantees local development unblocked.
- **R3:** Timezone format mismatch. *Mitigation:* We pass `TZL_ABC_CODE` as-is, letting the BFF rely on Java's valid IANA lookup strings.

## Dependencies
- Chancy's `feat/NOJIRA-guest-pass-email` branch availability.
- Dev DataTrak host availability via VPN.
- PLATFORM for DataTrak credentials into `STP_DATATRAK_SERVICE_AUTH` in BFF.

## Open Questions
1. **Delivery into Chancy's PR:** Should we push directly to `feat/NOJIRA-guest-pass-email` or open a stacked PR? (Draft proposes stacked to avoid blocking his review).
2. **DTO strategy:** Subclassing `ClubDefaultExternal` locally vs adding a sibling element on the response. (Draft proposes sibling/wrapper to protect MICO XML).
3. **G2 (Member ID):** Should `memberId` become optional in `saleItems.spr` when the flag is on, or handled separately? (Draft proposes leaving G2 strictly parallel, avoiding scope creep if possible, or adjusting validation if strictly necessary).
4. **Timezone validation:** Does the BFF validate the returned IANA string strictly, or just pass it through? (Draft assumes fail-closed if unknown).
