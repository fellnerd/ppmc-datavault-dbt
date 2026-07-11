---
name: dv-marts
description: Erstellt Information-Mart-Objekte (Star Schema) auf dem Raw Vault — Dimensionen und Faktentabellen mit deterministischen Surrogate Keys, NULL-Fallbacks und BI-tauglichen Konventionen (Power BI/Qlik/Tableau). Immer verwenden bei "Dimension erstellen", "Faktentabelle", "Mart bauen", "Star Schema", "Reporting-View", "dim_" oder "fakt_"-Objekten oder wenn Vault-Daten für BI-Tools aufbereitet werden sollen.
---

# Information Marts auf Data Vault (Star Schema)

Marts sind die BI-Schicht über dem Raw Vault: Kimball-Star-Schema, idealerweise als Views (Business Vault virtuell). Der Vault bleibt die einzige Wahrheit — Marts enthalten keine eigene Historisierungslogik, sondern lesen den aktuellen Stand (`dss_is_current = 'Y'`) oder gezielt Historie über PIT-Tabellen.

## Surrogate-Key-Pattern

Alle Dimension Keys über das projektweite `surrogate_key()`-Macro — deterministisch, view-kompatibel, BI-freundlich:

```sql
{{ surrogate_key('business_key_column') }} AS <dim>_key
-- erzeugt: ABS(CONVERT(BIGINT, HASHBYTES('MD5', CAST(col AS NVARCHAR(MAX)))))
```

Fakten-FKs verwenden **denselben** `surrogate_key()`-Aufruf auf derselben Spalte — nur so matchen die Joins. Nie `ROW_NUMBER()` oder Identity-Spalten (nicht deterministisch über Rebuilds).

## Pflichtspalten

### Dimension (`dim_<name>`)

| Spalte | Typ | Regel |
|--------|-----|-------|
| `<dim>_key` | BIGINT | Surrogate Key (PK) via `surrogate_key()` |
| `<dim>_id` | NVARCHAR(255) | Technische ID aus dem Vorsystem |
| `<dim>_code` | NVARCHAR(255) | Sprechender Business-Schlüssel; Fallback = ID |
| `<dim>_name` | NVARCHAR(255) | Bezeichnung; Fallback = CODE, sonst 'UNKNOWN' |
| `dss_load_date` / `dss_record_source` | — | aus dem Vault durchreichen |

NULL-Behandlung: `ISNULL(code, CAST(id AS NVARCHAR(255)))`, `ISNULL(name, ISNULL(code, 'UNKNOWN'))` — BI-Tools brechen sonst bei NULL-Membern.

### Faktentabelle (`fakt_<name>`)

- Dimensions-Keys: `{{ surrogate_key('fk_spalte') }} AS <dim>_key`
- Measures (Beträge, Mengen) mit explizitem Typ-Cast
- Degenerate Dimensions (Belegnummern etc.) direkt in der Faktentabelle
- `dss_load_date`, `dss_record_source`

## Aufbau-Muster

```sql
{{ config(materialized='table', as_columnstore=false) }}

WITH hub AS (
    SELECT hk_<entity>, <bk> FROM {{ ref('hub_<entity>') }}
),
sat_current AS (
    SELECT * FROM {{ ref('sat_<entity>__<source>') }}
    WHERE dss_is_current = 'Y'
)
SELECT
    {{ surrogate_key('h.<bk>') }}                    AS <dim>_key,
    CAST(h.<bk> AS NVARCHAR(255))                    AS <dim>_id,
    ISNULL(s.code, CAST(h.<bk> AS NVARCHAR(255)))    AS <dim>_code,
    ISNULL(s.name, ISNULL(s.code, 'UNKNOWN'))        AS <dim>_name,
    s.dss_load_date,
    s.dss_record_source
FROM hub h
LEFT JOIN sat_current s ON s.hk_<entity> = h.hk_<entity>
```

Fakten joinen über Links: Link liefert die FK-Hash-Keys, Hubs liefern die BKs für die Surrogate-Key-Berechnung, Link-/Transaction-Sats liefern die Measures.

## Checkliste vor Fertigmeldung

1. `dim_date` (Datums-Dimension) referenziert statt eigene Datumslogik?
2. Jede Dimension hat einen 'UNKNOWN'-tauglichen Fallback (LEFT JOINs in Fakten dürfen keine verlorenen Zeilen erzeugen)?
3. Schema-YAML mit Tests: `<dim>_key` not_null + unique (Dimension), FK-Keys not_null (Fakt)
4. ER-Diagramm des Marts aktualisiert (Skill `dv-design-sync`)
5. Grain der Faktentabelle im Header-Kommentar dokumentiert
