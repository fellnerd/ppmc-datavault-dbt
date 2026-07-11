/*
 * Staging Model: stg_role
 *
 * Test integration: proves the staging -> hub -> satellite pattern works
 * end-to-end against the deployed infra (hash calc via automate_dv,
 * vault schema). Sourced from the ref_role seed since no external source
 * is wired up yet.
 *
 * Business Key: role_code | Hash Key: hk_role | Hash Diff: hd_role
 * Hashing zentral über automate_dv (hash_override.sql, concat_string '||').
 */

{%- set yaml_metadata -%}
source_model: "ref_role"

derived_columns:
  dss_record_source: "!seed/ref_role"
  dss_load_date: "CAST(GETDATE() AS DATETIME2)"

hashed_columns:
  hk_role: "role_code"
  hd_role:
    is_hashdiff: true
    columns:
      - "role_name"
      - "role_description"
{%- endset -%}

{% set metadata = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata['source_model'],
                     derived_columns=metadata['derived_columns'],
                     hashed_columns=metadata['hashed_columns']) }}
