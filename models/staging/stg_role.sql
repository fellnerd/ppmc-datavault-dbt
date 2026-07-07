-- Test integration: proves the staging -> hub -> satellite pattern works
-- end-to-end against the deployed infra (hash calc, automate_dv macros,
-- vault schema). Sourced from the ref_role seed since no external source
-- is wired up yet.

WITH source_data AS (
    SELECT
        role_code,
        role_name,
        role_description
    FROM {{ ref('ref_role') }}
),

hashed AS (
    SELECT
        CONVERT(CHAR(64), HASHBYTES('SHA2_256',
            ISNULL(CAST(role_code AS NVARCHAR(MAX)), '')
        ), 2) AS hk_role,
        CONVERT(CHAR(64), HASHBYTES('SHA2_256',
            ISNULL(CAST(role_code AS NVARCHAR(MAX)), '') + '^^' +
            ISNULL(CAST(role_name AS NVARCHAR(MAX)), '') + '^^' +
            ISNULL(CAST(role_description AS NVARCHAR(MAX)), '')
        ), 2) AS hd_role,
        role_code,
        role_name,
        role_description,
        CAST(GETDATE() AS DATETIME2) AS dss_load_date,
        CAST('seed/ref_role' AS VARCHAR(100)) AS dss_record_source
    FROM source_data
)

SELECT * FROM hashed
