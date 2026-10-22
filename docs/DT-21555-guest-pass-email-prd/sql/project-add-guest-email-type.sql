MERGE INTO contactTemplate target
USING (
    SELECT chan_id,
           ctem_always_send,
           ctem_preheader,
           ctem_billing_code,
           ctpr_id,
           cse_id,
           ctem_template
    FROM contactTemplate
    WHERE ctem_abc_code = 'ADD_PROSPECT'
) source
ON (target.ctem_abc_code = 'ADD_GUEST')
WHEN MATCHED THEN
    UPDATE SET target.ctem_subject = 'Your Club Pass'
WHEN NOT MATCHED THEN
    INSERT (
        ctem_id,
        ctem_name,
        ctem_active,
        ctem_abc_code,
        chan_id,
        ctem_always_send,
        ctem_subject,
        ctem_preheader,
        ctem_billing_code,
        ctpr_id,
        cse_id,
        ctem_template
    )
    VALUES (
        '7E2E04A6D4B74A56833F90EEC929A1B2',
        'Add Guest',
        '1',
        'ADD_GUEST',
        source.chan_id,
        source.ctem_always_send,
        'Your Club Pass',
        source.ctem_preheader,
        '030',
        source.ctpr_id,
        source.cse_id,
        source.ctem_template
    );

INSERT INTO contactTemplateLocation (
    vpd_id,
    ctemloc_id,
    ctemloc_created,
    ctemloc_modified,
    ctemloc_active,
    ctemloc_header,
    ctemloc_footer,
    spl_id,
    ctem_id,
    ctemloc_subject,
    ctemloc_preheader
)
SELECT prospectLocation.vpd_id,
       sys_guid(),
       current_timestamp,
       current_timestamp,
       prospectLocation.ctemloc_active,
       prospectLocation.ctemloc_header,
       prospectLocation.ctemloc_footer,
       prospectLocation.spl_id,
       guestTemplate.ctem_id,
       'Your Club Pass',
       prospectLocation.ctemloc_preheader
FROM contactTemplateLocation prospectLocation
JOIN contactTemplate prospectTemplate
  ON prospectTemplate.ctem_id = prospectLocation.ctem_id
 AND prospectTemplate.ctem_abc_code = 'ADD_PROSPECT'
JOIN contactTemplate guestTemplate
  ON guestTemplate.ctem_abc_code = 'ADD_GUEST'
WHERE NOT EXISTS (
    SELECT 1
    FROM contactTemplateLocation guestLocation
    WHERE guestLocation.spl_id = prospectLocation.spl_id
      AND guestLocation.ctem_id = guestTemplate.ctem_id
);

UPDATE contactTemplateLocation guestLocation
SET guestLocation.ctemloc_subject = 'Your Club Pass'
WHERE guestLocation.ctemloc_subject = 'Thank You'
  AND guestLocation.ctem_id IN (
      SELECT ctem_id
      FROM contactTemplate
      WHERE ctem_abc_code = 'ADD_GUEST'
  );
