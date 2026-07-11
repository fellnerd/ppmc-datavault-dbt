{#
    Satellite: sat_role
    Parent Hub: hub_role
    Source: stg_role (Seed-basiertes Starter-Beispiel)
    Payload: role_name, role_description
#}

{{ config(
    as_columnstore=false,
    post_hook=[
        "{{ create_hash_index('hk_role') }}",
        "{{ update_satellite_current_flag(this, 'hk_role') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "stg_role"
src_pk: "hk_role"
src_hashdiff:
  source_column: "hd_role"
  alias: "hashdiff"
src_payload:
  - "role_name"
  - "role_description"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.sat(src_pk=metadata_dict["src_pk"], src_hashdiff=metadata_dict["src_hashdiff"],
                   src_payload=metadata_dict["src_payload"], src_ldts=metadata_dict["src_ldts"],
                   src_source=metadata_dict["src_source"], source_model=metadata_dict["source_model"]) }}
