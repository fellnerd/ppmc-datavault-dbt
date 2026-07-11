# DV 2.1 Voll-Templates (automate_dv auf SQL Server)

Platzhalter: `<entity>`, `<source>`, `<staging_model>`, `<business_key>` ersetzen. Header-Kommentar mit Zweck, Quelle, BK und Versionshistorie ist Pflicht — er ist die einzige Doku direkt am Modell.

## Hub

```sql
{#
    Hub: hub_<entity>
    Source: <staging_model>
    Business Keys: <business_key>
    Version: <YYYY-MM-DD> V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_<entity>') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_<entity>"
src_nk: "<business_key>"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.hub(src_pk=metadata_dict["src_pk"],
                   src_nk=metadata_dict["src_nk"],
                   src_ldts=metadata_dict["src_ldts"],
                   src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
```

**Multi-Source-Hub:** `source_model` als Liste; der Business Key muss in allen Staging-Views gleich heißen und gleich normalisiert sein (Typ-Cast! `DECIMAL → BIGINT → NVARCHAR` vor dem Hashen, sonst `HASH("44402.00") ≠ HASH("44402")`).

```yaml
source_model:
  - "<staging_model_a>"
  - "<staging_model_b>"
```

## Satellite

```sql
{#
    Satellite: sat_<entity>__<source>
    Parent Hub: hub_<entity>
    Source: <staging_model>
    Payload: <kurzbeschreibung>
    Version: <YYYY-MM-DD> V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=[
        "{{ create_hash_index('hk_<entity>') }}",
        "{{ update_satellite_current_flag('hk_<entity>', 'dss_load_date') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_<entity>"
src_hashdiff:
  source_column: "hd_<entity>"
  alias: "hashdiff"
src_payload:
  - SPALTE_1
  - SPALTE_2
src_eff: "dss_start_date"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.sat(src_pk=metadata_dict["src_pk"],
                   src_hashdiff=metadata_dict["src_hashdiff"],
                   src_payload=metadata_dict["src_payload"],
                   src_eff=metadata_dict["src_eff"],
                   src_ldts=metadata_dict["src_ldts"],
                   src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
```

Stolperfallen: `alias: "hashdiff"` ist Pflicht (nicht der `hd_*`-Name); beide post_hooks nötig; Payload-Spalten müssen exakt den `hashdiff_columns` der Staging-View entsprechen (sonst Dauer-Delta bei jedem Load).

## Multi-Active Satellite

Wie Satellite, zusätzlich Child Dependent Key und `_ma`-Naming (`sat_<entity>_ma__<source>`, Hash Diff `hd_<entity>_ma`):

```yaml
src_cdk:
  - "<unterscheidende_spalte>"
```

## Link

```sql
{#
    Link: link_<e1>_<e2>
    Source: <staging_model>
    Foreign Keys: hk_<e1>, hk_<e2>
    Version: <YYYY-MM-DD> V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_link_<e1>_<e2>') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_link_<e1>_<e2>"
src_fk:
  - "hk_<e1>"
  - "hk_<e2>"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.link(src_pk=metadata_dict["src_pk"],
                    src_fk=metadata_dict["src_fk"],
                    src_ldts=metadata_dict["src_ldts"],
                    src_source=metadata_dict["src_source"],
                    source_model=metadata_dict["source_model"]) }}
```

Link-Hash-Key wird in der **Staging-View** berechnet (via `hashed_columns` im stage()-Block):

```yaml
hashed_columns:
  hk_link_<e1>_<e2>:
    - "<bk_e1>"
    - "<bk_e2>"
```

## Transaction Link (Non-Historized, `_tl`)

Für unveränderliche Events (Transaktionen, Messwerte, Logs). Unterschiede zum regulären Link:

| Merkmal | Regulärer Link | Transaction Link |
|---------|---------------|------------------|
| Naming | `link_<e1>_<e2>` | `link_<entity>_tl` |
| Hash Key | Hash(FKs) | Hash(**event_id**, FKs) |
| incremental_strategy | (Default) | `append` |
| Zugehöriger Sat | Eff-Sat / DC-Sat | Transaction Sat: **kein** Hash Diff, **kein** current_flag-Hook |

```sql
{{ config(
    materialized='incremental',
    as_columnstore=false,
    incremental_strategy='append',
    post_hook=["{{ create_hash_index('hk_link_<entity>_tl') }}"]
) }}
```
(Macro-Aufruf wie beim regulären Link.)

## Dependent Child Satellite

Entity ohne eigenen BK (z. B. Belegpositionen): Satellite am Link, Link hat nur einen FK (Parent-Hub), Hash Key = `Hash(FK ^^ DCK1 ^^ DCK2)` — die Dependent Child Keys gehören in den Staging-`hashed_columns`-Block.

## Reference Table

Stabile Lookups (Status, Arten, Länder) — **kein Hub**. Als View materialisieren:

```sql
{{ config(materialized='view') }}

SELECT
    <key_spalte>,
    <bezeichnung>,
    dss_record_source,
    dss_load_date
FROM {{ ref('<staging_model>') }}
```

## Schema-YAML (je Vault-Ordner `_<ordner>__models.yml`)

```yaml
version: 2

models:
  - name: hub_<entity>
    description: "Hub for <entity>"
    columns:
      - name: hk_<entity>
        data_type: "CHAR(64)"
        description: "Hash Key"
        data_tests: [not_null, unique]
      - name: <business_key>
        description: "Business Key"
        data_tests: [not_null]
      - name: dss_load_date
        data_type: "DATETIME2(6)"
      - name: dss_record_source
        data_type: "VARCHAR(50)"
```

Satellites: `hk_*` und `hashdiff` mit `not_null` testen; `unique` gilt dort **nicht** (Historie!). Links: `hk_link_*` `not_null` + `unique`, FKs `not_null`.
