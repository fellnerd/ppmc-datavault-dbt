---
name: dv-staging
description: Erstellt Data-Vault-Staging-Views mit dem automate_dv.stage()-Macro auf SQL Server/Azure SQL — von der External Table über sources.yml bis zur fertigen Hash-berechnenden View. Immer verwenden bei "Staging erstellen", "Quelle anbinden", "External Table einbinden", "stage() View", neuen Parquet-Dateien oder wenn eine Quelltabelle für Hub/Satellite/Link vorbereitet werden muss.
---

# DV Staging mit automate_dv.stage()

Staging-Views sind die einzige Stelle, an der Hash Keys und Hash Diffs berechnet werden — Fehler hier (falscher Typ-Cast, vergessene Spalte im Hashdiff) pflanzen sich in den gesamten Vault fort und sind nachträglich teuer zu korrigieren. Deshalb: Pattern exakt einhalten, keine Custom-SQL-Staging-Views.

## Workflow

### 1. Quellschema ermitteln

```bash
# Parquet-Schema aus der Landing Zone (Macro im Projekt):
dbt run-operation get_parquet_schema --args '{"file_path": "<pfad/datei.parquet>"}' --target dev
# Oder vorhandene External Table auf der DB prüfen:
dbt run-operation run_sql --args '{"sql": "SELECT c.name, t.name AS type_name, c.precision, c.scale FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID('"'"'[stg].[ext_<tabelle>]'"'"') ORDER BY c.column_id"}' --target dev
```

### 2. Typen prüfen (bekannte Fallen)

- `DECIMAL(38,10)` aus Schema-Inferenz → real meist `DECIMAL(38,18)` (Parquet-Numeric-Scale)
- Binärdaten, die als `NVARCHAR(4000)` erkannt wurden → `VARBINARY(8000)`; **Binärspalten nie in den Hashdiff!**
- Business Keys typstabil normalisieren: `CAST(CAST(col AS BIGINT) AS NVARCHAR(MAX))` — sonst matchen Multi-Source-Hashes nicht

### 3. sources.yml ergänzen

External Table unter dem `staging`-Source eintragen (Muster vorhandener Einträge übernehmen; `external.location`, `file_format`, `data_source` für `dbt run-operation stage_external_sources`).

### 4. Staging View schreiben

Aufbau (vollständiges kommentiertes Beispiel: [references/stage-template.md](references/stage-template.md)):

```sql
{%- set yaml_metadata -%}
source_model:
  staging: "ext_<quelle>_<tabelle>"

derived_columns:
  dss_record_source: "!<quellsystem>"
  dss_load_date: "COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())"
  dss_create_datetime: "GETDATE()"
  <bk_normalisiert>: "CAST(CAST(<BK> AS BIGINT) AS NVARCHAR(MAX))"
  _escape:
    source_column:
      - "PLAN"
      - "LEVEL"
    escape: true

hashed_columns:
  hk_<entity>: "<bk>"
  hk_link_<e1>_<e2>:
    - "<bk_e1>"
    - "<bk_e2>"
  hd_<entity>:
    is_hashdiff: true
    columns:
      - "SPALTE_1"
      - "SPALTE_2"
{%- endset -%}

{% set metadata = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata['source_model'],
                     derived_columns=metadata['derived_columns'],
                     hashed_columns=metadata['hashed_columns']) }}
```

### 5. Dokumentieren & validieren

1. Eintrag in `_staging__models.yml`: Beschreibung, Business Key, Tests (`hk_*` not_null/unique, BK not_null)
2. `dbt parse` → `dbt run --select <staging_model> --target dev` → Stichprobe via `run_sql`

## SQL-Server-Regeln

- **Reserved Keywords escapen** (`[PLAN]`, `[LEVEL]`, `[KEY]`, `[STATUS]`, `[TYPE]`, `[ORDER]`, `[GROUP]`, `[INDEX]`, …) — im stage()-Block über `_escape`-derived-column, nie über manuelle Aliase
- Hash-Format: `CONVERT(CHAR(64), HASHBYTES('SHA2_256', …), 2)` — kommt aus `hash_override.sql` (NVARCHAR-Variante, Unicode-safe); nie manuell hashen
- `TRY_CAST` statt `CAST` für fehlertolerante Konvertierung
- Hash-Vars (`concat_string`, `null_placeholder_string`, `hash_content_casing`) stehen in `dbt_project.yml` — nicht im Modell überschreiben

## Entscheidungshilfe: Welche Hashes braucht die View?

| Ziel-Objekt | hashed_columns |
|-------------|----------------|
| Hub | `hk_<entity>` aus BK |
| Satellite | zusätzlich `hd_<entity>` (is_hashdiff, Payload-Spalten) |
| Link | `hk_link_…` aus allen beteiligten BKs + je Hub ein `hk_<entity>` |
| Multi-Satellite-Split | mehrere `hd_*` (z. B. `hd_person_stamm`, `hd_person_kontakt`) |
| Reference Table | keine — schlanke View ohne stage() reicht |
