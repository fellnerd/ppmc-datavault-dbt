{%- set source_model = "stg_role" -%}
{%- set src_pk = "hk_role" -%}
{%- set src_hashdiff = "hd_role" -%}
{%- set src_payload = ["role_name", "role_description"] -%}
{%- set src_ldts = "dss_load_date" -%}
{%- set src_source = "dss_record_source" -%}

{{ automate_dv.sat(src_pk=src_pk, src_hashdiff=src_hashdiff, src_payload=src_payload,
                    src_ldts=src_ldts, src_source=src_source, source_model=source_model) }}
