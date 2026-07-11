# Staging-View Voll-Template (automate_dv.stage)

Vollständig kommentiertes Muster. Header-Kommentar dokumentiert Quelle, BK, Hash Keys und Satellite-Splits — das ist die Referenz für den Vault-Architekten.

```sql
/*
 * Staging Model: <quelle>_<tabelle>
 *
 * Source: ext_<quelle>_<tabelle> (<Quellsystem-Notation>)
 * Business Key: <BK> (Normalisierung dokumentieren, z. B. DECIMAL → BIGINT-String)
 * Hash Key: hk_<entity>
 * Links: hk_link_<e1>_<e2> (<bk_e1>, <bk_e2>)
 * Hash Diffs: hd_<entity> (Payload), ggf. Splits: hd_<entity>_stamm, hd_<entity>_kontakt
 *
 * Uses automate_dv.stage() macro for standardized staging.
 */

{%- set yaml_metadata -%}
source_model:
  staging: "ext_<quelle>_<tabelle>"

derived_columns:
  # Pflicht-Metadaten
  dss_record_source: "!<quellsystem>"          # '!' = Literal-String
  dss_load_date: "COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())"
  dss_create_datetime: "GETDATE()"

  # BK-Normalisierung für Cross-Source-Kompatibilität:
  # HASH("44402") muss quellenübergreifend gleich sein — Typ vereinheitlichen!
  <bk_lower>: "CAST(CAST(<BK> AS BIGINT) AS NVARCHAR(MAX))"

  # Menschenlesbarer Business Key (Debugging/Audit)
  dss_business_key: "CONCAT_WS('||', ISNULL(LTRIM(RTRIM(CAST(<BK> AS NVARCHAR(MAX)))), '-1'))"

  # Reserved Keywords / Sonderzeichen-Spalten escapen (KEINE manuellen Aliase)
  _escape:
    source_column:
      - "PLAN"
      - "timestamp_landing-zone"
    escape: true

hashed_columns:
  hk_<entity>: "<bk_lower>"

  hk_link_<e1>_<e2>:
    - "<bk_e1>"
    - "<bk_e2>"

  hd_<entity>:
    is_hashdiff: true
    columns:            # exakt die Payload des späteren Satellites — nicht mehr, nicht weniger
      - "SPALTE_1"
      - "SPALTE_2"
{%- endset -%}

{% set metadata = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata['source_model'],
                     derived_columns=metadata['derived_columns'],
                     hashed_columns=metadata['hashed_columns']) }}
```

## Varianten

**Reference-Table-Quelle** (kein Hashing nötig) — schlanke View:

```sql
WITH source AS (
    SELECT * FROM {{ source('staging', 'ext_<quelle>_<tabelle>') }}
)
SELECT
    <key>                                                       AS <key_lower>,
    <bezeichnung>                                               AS bezeichnung,
    COALESCE(dss_record_source, '<quellsystem>')                AS dss_record_source,
    COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())   AS dss_load_date
FROM source
```

**JSON-Quelle** (OPENJSON via CROSS APPLY):

```sql
SELECT j.*, '<quellsystem>' AS dss_record_source, GETDATE() AS dss_load_date
FROM {{ source('staging', 'ext_<quelle>_json') }} AS r
CROSS APPLY OPENJSON(r.jsonline) WITH (
    FELD_1 NVARCHAR(100)  '$."Feld-1"',
    FELD_2 NVARCHAR(1000) '$.feld2'
) AS j
WHERE j.FELD_1 IS NOT NULL
```

## sources.yml-Eintrag (External Table, dbt_external_tables)

```yaml
- name: "ext_<quelle>_<tabelle>"
  description: "Auto-generated from <DATEI>.parquet"
  external:
    location: "<container-pfad>/<DATEI>.parquet"
    file_format: "ParquetFormat"
    data_source: "StageFileSystem"
  columns:
    - name: "<SPALTE>"
      data_type: "<TYP>"
```

Anlegen/Aktualisieren: `dbt run-operation stage_external_sources` (selektiv: `--args '{"select": "ext_<name>"}'` via `stage_external_sources_selective`).
