# Guest Pass Email Database Handoff

## Summary

This feature adds guest-pass configuration to product catalog items, adds
club-configurable prospect liability language, and introduces the `Add Guest`
email type. No new database tables are required.

The repository contains three deployment scripts. Run them in the order shown
below:

1. `sql/project-prospect-liability-language.sql`
2. `sql/project-guest-pass-catalog-item.sql`
3. `sql/project-add-guest-email-type.sql`

Oracle DDL commits implicitly. Apply these scripts through the database team's
normal controlled deployment process and take the usual backup or restore-point
precautions before execution.

## New columns

### `SPL_EXTENSIONS`

| Column | Type | Nullable | Default | Purpose |
| --- | --- | --- | --- | --- |
| `SPLEX_PROSPECT_LIABILITY` | `VARCHAR2(4000)` | Yes | None | Club-editable liability language included in the Add Guest email. |

### `CATALOGITEMS`

| Column | Type | Nullable | Default | Initial value | Purpose |
| --- | --- | --- | --- | --- | --- |
| `CGI_GUEST_PASS` | `CHAR(1)` | Yes | `'0'` | `'0'` | Identifies a product catalog item as a guest-pass item. |
| `CGI_GUEST_PASS_VISITS` | `NUMBER(3,0)` | Yes | `0` | `0` | Number of visits associated with the guest-pass product. |
| `CGI_GUEST_PASS_CONTRACT_DAYS` | `NUMBER(3,0)` | Yes | `0` | `0` | Contract duration associated with the guest-pass product. |

`CGI_GUEST_PASS` uses the existing Datatrak boolean convention: `'1'` is true
and `'0'` is false. Visits and contract days are limited by the application to
values from 1 through 100 when the item is marked as a guest pass.

### `SALEITEMS`

| Column | Type | Nullable | Default | Initial value | Purpose |
| --- | --- | --- | --- | --- | --- |
| `SAI_GUEST_PASS` | `CHAR(1)` | Yes | `'0'` | `'0'` | Deployed club-item copy of the guest-pass indicator. |
| `SAI_GUEST_PASS_VISITS` | `NUMBER(3,0)` | Yes | `0` | `0` | Deployed club-item copy of allowed visits. |
| `SAI_GUEST_PASS_CONTRACT_DAYS` | `NUMBER(3,0)` | Yes | `0` | `0` | Deployed club-item copy of contract days. |

The application synchronizes these three values from `CATALOGITEMS` whenever a
catalog item is deployed or its deployed sale item is refreshed. Completed POS
sales use `SAI_GUEST_PASS = '1'` to decide whether to send the Add Guest email.

## New email-template data

No columns are added for the email type. The script
`sql/project-add-guest-email-type.sql` creates configuration data in the
existing email tables:

### `CONTACTTEMPLATE`

- ABC code: `ADD_GUEST`
- Name: `Add Guest`
- Default subject: `Your Club Pass`
- Active: `'1'`
- Billing code: `030`
- Template ID: `7E2E04A6D4B74A56833F90EEC929A1B2`
- Channel, preheader, sender, processing rules, and base template are copied
  from the existing `ADD_PROSPECT` template.

The billing code must remain unique under `CTEM_UNIQUE_BILLING`. Confirm that
`030` is available in each target environment before deployment. If it is
already assigned, coordinate a different unused code and update the script
before execution.

### `CONTACTTEMPLATELOCATION`

One Add Guest location row is created for every location that currently has an
`ADD_PROSPECT` location row. Each new row:

- receives a new `SYS_GUID()` identifier;
- retains the source location's active state, header, footer, and preheader;
- defaults its subject to `Your Club Pass`; and
- remains editable through the existing Email Types settings UI.

The `CONTACTTEMPLATE` insertion is guarded by a `MERGE`, and location rows are
guarded by `NOT EXISTS`, so the email-data script can be rerun safely.

## Deployment verification

Run these checks after applying all scripts:

```sql
SELECT column_name, data_type, data_length, data_precision, data_scale,
       nullable, data_default
FROM user_tab_columns
WHERE table_name IN (
    'SPL_EXTENSIONS',
    'CATALOGITEMS',
    'SALEITEMS'
)
AND column_name IN (
    'SPLEX_PROSPECT_LIABILITY',
    'CGI_GUEST_PASS',
    'CGI_GUEST_PASS_VISITS',
    'CGI_GUEST_PASS_CONTRACT_DAYS',
    'SAI_GUEST_PASS',
    'SAI_GUEST_PASS_VISITS',
    'SAI_GUEST_PASS_CONTRACT_DAYS'
)
ORDER BY table_name, column_id;
```

Expected result: seven rows.

```sql
SELECT ctem_id, ctem_name, ctem_abc_code, ctem_active,
       ctem_subject, ctem_billing_code
FROM contactTemplate
WHERE ctem_abc_code = 'ADD_GUEST';
```

Expected result: one active `ADD_GUEST` row with subject `Your Club Pass`.

```sql
SELECT COUNT(*) AS add_guest_location_count
FROM contactTemplateLocation location
JOIN contactTemplate template
  ON template.ctem_id = location.ctem_id
WHERE template.ctem_abc_code = 'ADD_GUEST';
```

Expected result: one row per location configured for `ADD_PROSPECT`.

```sql
SELECT COUNT(*) AS unexpected_catalog_values
FROM catalogItems
WHERE NVL(cgi_guest_pass, '0') NOT IN ('0', '1')
   OR NVL(cgi_guest_pass_visits, 0) NOT BETWEEN 0 AND 100
   OR NVL(cgi_guest_pass_contract_days, 0) NOT BETWEEN 0 AND 100;
```

Expected result: `0`.

## Rollback

Coordinate rollback with the application deployment because code using these
columns cannot run after the columns are removed.

```sql
DELETE FROM contactTemplateLocation
WHERE ctem_id = (
    SELECT ctem_id
    FROM contactTemplate
    WHERE ctem_abc_code = 'ADD_GUEST'
);

DELETE FROM contactTemplate
WHERE ctem_abc_code = 'ADD_GUEST';

ALTER TABLE saleItems DROP COLUMN SAI_GUEST_PASS_CONTRACT_DAYS;
ALTER TABLE saleItems DROP COLUMN SAI_GUEST_PASS_VISITS;
ALTER TABLE saleItems DROP COLUMN SAI_GUEST_PASS;

ALTER TABLE catalogItems DROP COLUMN CGI_GUEST_PASS_CONTRACT_DAYS;
ALTER TABLE catalogItems DROP COLUMN CGI_GUEST_PASS_VISITS;
ALTER TABLE catalogItems DROP COLUMN CGI_GUEST_PASS;

ALTER TABLE spl_extensions DROP COLUMN SPLEX_PROSPECT_LIABILITY;
```

Commit the two deletes before running the DDL if the deployment tooling does
not manage transaction boundaries automatically.
