{#
    Hub: hub_role
    Source: stg_role (Seed-basiertes Starter-Beispiel)
    Business Key: role_code
#}

{{ config(
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_role') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "stg_role"
src_pk: "hk_role"
src_nk: "role_code"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.hub(src_pk=metadata_dict["src_pk"], src_nk=metadata_dict["src_nk"],
                   src_ldts=metadata_dict["src_ldts"], src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
