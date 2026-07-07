{%- set source_model = "stg_role" -%}
{%- set src_pk = "hk_role" -%}
{%- set src_nk = "role_code" -%}
{%- set src_ldts = "dss_load_date" -%}
{%- set src_source = "dss_record_source" -%}

{{ automate_dv.hub(src_pk=src_pk, src_nk=src_nk, src_ldts=src_ldts,
                    src_source=src_source, source_model=source_model) }}
