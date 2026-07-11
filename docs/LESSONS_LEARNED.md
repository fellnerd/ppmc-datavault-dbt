# Lessons Learned - Data Vault 2.1 mit dbt auf Azure

> **Letzte Aktualisierung:** 2026-01-11  
> **DV 2.1 Compliance:** ~85% (nach Optimierung)

## Projektkontext
PoC für eine virtualisierte Data Vault 2.1 Architektur als wiederverwendbares SaaS-Template. Das Projekt wurde durch eine umfassende DV 2.1 Analyse optimiert.

---

## Entscheidungen & Begründungen

### 1. dbt statt Stored Procedures
**Entscheidung:** dbt Core mit automate-dv Package statt T-SQL Stored Procedures

**Begründung:**
- Versionskontrolle (Git) nativ integriert
- Wiederverwendbare Macros für verschiedene Kunden
- Lineage und Dokumentation automatisch
- Community-Support und Best Practices (automate-dv)

### 2. Hybrid: Raw Vault physisch, Business Vault virtuell
**Entscheidung:** Raw Vault als echte Tabellen, Business Vault als Views

**Begründung:**
- Raw Vault benötigt Insert-Only Performance
- Business Vault ist nur berechnete Sichten
- Kosteneinsparung bei Azure SQL

### 3. SHA2_256 als Hash-Algorithmus
**Entscheidung:** SHA2_256 → CHAR(64) für alle Hash Keys

**Begründung:**
- Industriestandard für Data Vault
- Native Unterstützung in SQL Server (HASHBYTES)
- Keine Kollisionsgefahr bei erwarteten Datenmengen
- 64 Zeichen als feste Länge gut handhabbar

### 4. Linux VM für dbt
**Entscheidung:** dbt auf Linux VM statt Mac/Windows

**Begründung:**
- ODBC-Treiber stabiler unter Linux
- Einfachere Deployment-Vorbereitung für Container
- VS Code Remote SSH ermöglicht komfortable Entwicklung

### 5. Unified Hub Pattern statt 3 separate Hubs
**Entscheidung:** Ein `hub_company` mit `link_company_role` statt `hub_company_client`, `hub_company_contractor`, `hub_company_supplier`

**Begründung:**
- Identische Attribute in allen 3 Quellen (>90% Überlappung)
- Weniger Redundanz, einfachere Wartung
- Role als Link ermöglicht zukünftige Multi-Role-Unternehmen
- `object_id` ist NICHT global unique → Composite Key `object_id + source_table`

### 6. Hash-Separator '^^' statt '||'
> ⚠️ **Revidiert (2026-07-12):** Mit der Umstellung auf durchgängiges automate_dv-Hashing (`hash_override.sql` mit `cast_binary`/`type_string`-Overrides) gilt der automate_dv-Standard **`concat_string: '||'`** samt NULL-Placeholder-Logik — bewährt im federführenden EWB-Projekt. Manuelle '^^'-Hashes in Bestands-Beispielen bleiben in sich konsistent; Berechnungswege innerhalb einer Entity nie mischen.

**Ursprüngliche Entscheidung:** `'^^'` als Trennzeichen für Composite Hash Keys

**Begründung (damals):**
- DV 2.1 Best Practice (selten in natürlichen Daten)
- `'||'` kann in SQL-Strings vorkommen (Oracle Concat-Operator)
- Konsistenz mit Scalefree Standards

### 7. dss_is_current + dss_end_date in Satellites
**Entscheidung:** Current-Flag und End-Dating in allen Satellites

**Begründung:**
- Effiziente Abfrage des aktuellen Stands ohne ROW_NUMBER()
- dss_end_date ermöglicht historische Point-in-Time Abfragen
- Post-Hook Macro hält Flag automatisch aktuell

---

## Probleme & Lösungen

### Problem 1: automate-dv Hash Macros inkompatibel
**Symptom:** Fehler bei Verwendung von automate-dv hash() Macro

**Ursache:** automate-dv optimiert für Snowflake/BigQuery, SQL Server anders

**Lösung:** Eigene Hash-Logik im Staging Model:
```sql
CONVERT(CHAR(64), HASHBYTES('SHA2_256', 
    ISNULL(CAST(column AS NVARCHAR(MAX)), '')
), 2) AS hk_entity
```

### Problem 2: Columnstore Index nicht verfügbar
**Symptom:** `CREATE TABLE failed because the following SET options have incorrect settings: 'ANSI_NULLS'`

**Ursache:** Azure SQL Basic Tier unterstützt keine Columnstore Indexes

**Lösung:** In dbt_project.yml und Model-Config:
```yaml
+as_columnstore: false
```

### Problem 3: Schema-Prefix unerwünscht
**Symptom:** Schemas wurden als `dv_stg` statt `stg` erstellt

**Ursache:** dbt-sqlserver fügt Target-Schema als Prefix hinzu

**Lösung:** Custom Macro in `macros/generate_schema_name.sql`:
```sql
{% macro generate_schema_name(custom_schema_name, node) %}
    {{ custom_schema_name | trim }}
{% endmacro %}
```

### Problem 4: profiles.yml im Repo
**Symptom:** Sicherheitsrisiko durch Credentials im Git

**Lösung:** 
- profiles.yml im Projekt-Root (gitignored) oder in ~/.dbt/ (außerhalb Repo)
- .gitignore mit `profiles.yml`
- Azure CLI Authentication (keine Passwörter)

### Problem 5: ROW_NUMBER() Performance bei is_current
**Symptom:** Langsame Abfragen bei großen Satellites mit ROW_NUMBER() für Current-Ermittlung

**Lösung:** 
- Physisches `dss_is_current` Flag (CHAR(1): 'Y'/'N')
- Post-Hook Macro `update_satellite_current_flag()` setzt alte Records auf 'N'
- `dss_end_date` für historische Abfragen ohne Window Functions

### Problem 6: object_id nicht global unique
**Symptom:** Duplikate in `hub_company` wenn nur `object_id` als Business Key

**Ursache:** `object_id` ist nur innerhalb einer Quelltabelle unique, nicht systemübergreifend

**Lösung:** Composite Key aus `object_id + source_table`:
```sql
HASHBYTES('SHA2_256', CONCAT(object_id, '^^', source_table))
```

### Problem 7: Schema-Änderungen bei Incremental Models
**Symptom:** Neue Spalten im Model erscheinen nicht in der DB-Tabelle

**Ursache:** dbt fügt bei `incremental` Models standardmäßig **keine neuen Spalten** hinzu

**Lösung:** In `dbt_project.yml`:
```yaml
models:
  datavault:
    raw_vault:
      satellites:
        +on_schema_change: append_new_columns
```

**Wichtig:** 
- `append_new_columns` fügt neue Spalten hinzu (bestehende Zeilen haben NULL)
- `sync_all_columns` würde auch Spalten entfernen (gefährlich!)
- `fail` (default) bricht ab, wenn Schema abweicht
- **Nie** `--full-refresh` bei historisierten Data Vault Tabellen!

---

## Best Practices (gelernt)

### dbt Projektstruktur
```
models/
  staging/           # Views mit Hash-Berechnung
  raw_vault/
    hubs/            # Business Key + Metadata
    satellites/      # Attribute + Hash Diff
    links/           # Beziehungen
  business_vault/    # PITs, Bridges (virtuell)
```

### Staging Pattern
1. External Table als Source (`stg.ext_<concept>_<entity>`)
2. Staging View berechnet alle Hash Keys (`stg.<concept>_<entity>`)
3. Hash Key = Business Key Hash
4. Hash Diff = Alle Attribute Hash (für Change Detection)

### Satellite Change Detection
```sql
LEFT JOIN ON hk AND NOT EXISTS (sat mit gleichem hd)
```
Statt: Timestamp-basierter Vergleich

### Data Vault 2.1 Compliance Checkliste

| Feature | Status | Implementierung |
|---------|--------|----------------|
| Hash Keys (SHA2_256) | ✅ | `HASHBYTES()` mit CHAR(64) |
| Hash Diff für Change Detection | ✅ | `hd_*` Spalten in Satellites |
| Hash Separator | ✅ | automate_dv `concat_string: '||'` (revidiert, s. Entscheidung 6); Beispiel-Altbestand '^^' |
| dss_load_date Metadata | ✅ | Alle Vault-Objekte |
| dss_record_source | ✅ | Quellsystem-Tracking |
| dss_is_current Flag | ✅ | Satellites mit Post-Hook |
| dss_end_date | ✅ | Validity Periods |
| Ghost Records | ✅ | Macro erstellt (manuell ausführen) |
| PIT Tables | ✅ | pit_company für History |
| Effectivity Satellites | ✅ | eff_sat_company_country |
| Zero Key (0x00...) | ✅ | Macro vorhanden |
| Error Key (0xFF...) | ✅ | Macro vorhanden |

### Wiederverwendbare Macros

| Macro | Datei | Zweck |
|-------|-------|-------|
| `generate_schema_name` | macros/generate_schema_name.sql | Schema ohne Prefix |
| `update_satellite_current_flag` | macros/satellite_current_flag.sql | dss_is_current Post-Hook |
| `update_effectivity_end_dates` | macros/satellite_current_flag.sql | Effectivity Sat End-Dating |
| `zero_key` | macros/ghost_records.sql | 64x '0' für NULL BKs |
| `error_key` | macros/ghost_records.sql | 64x 'F' für Fehler |
| `insert_ghost_records` | macros/ghost_records.sql | Ghost Records in Hubs |

---

## Nächste Schritte

1. ✅ ~~**Link-Tables** - Verbindung company zu countries~~ → `link_company_country`, `link_company_role`
2. ⏳ **Incremental Test** - Delta-Load mit Synapse Pipeline validieren
3. ✅ ~~**CI/CD** - Azure DevOps Pipeline für dbt run~~ → GitHub Actions implementiert
4. ✅ ~~**Weitere Entities** - contractor, supplier~~ → Unified in `hub_company`
5. ✅ ~~**Business Vault** - PIT Views~~ → `pit_company` erstellt
6. ⏳ **Bridge Tables** - Für komplexe Mart-Queries (wenn Performance-Bedarf)
7. ⏳ **Package Migration** - automate_dv → datavault4dbt evaluieren
8. ✅ ~~**Ghost Records einfügen**~~ - `dbt run-operation insert_ghost_records` ✓

---

## CI/CD Pipeline (GitHub Actions)

### Implementierte Workflows (2025-12-27)

| Workflow | Datei | Trigger | Funktion |
|----------|-------|---------|----------|
| **CI** | `.github/workflows/ci.yml` | PR nach main/dev + Path Filter | dbt compile + dbt test |
| **Deploy Dev** | `.github/workflows/deploy-dev.yml` | Push auf main + manual | dbt run → Vault DB |
| **Deploy Prod** | `.github/workflows/deploy-prod.yml` | Tag v* + manual + Approval | dbt run → Vault_<Tenant> |
| **Docs** | `.github/workflows/docs.yml` | Push auf main + manual | dbt docs → GitHub Pages |

### Path Filter Konfiguration
Workflows werden **nur** bei Änderungen an folgenden Pfaden getriggert:
- `models/**`, `macros/**`, `seeds/**`, `snapshots/**`, `tests/**`
- `dbt_project.yml`, `packages.yml`

**Kein Trigger bei:** `docs/**`, `*.md`, `.github/instructions/**`, `.github/prompts/**`

### Wichtige Ressourcen

| Ressource | Wert |
|-----------|------|
| **Service Principal** | `sp-github-datavault-dbt` |
| **Self-hosted Runner** | `dbt-runner-vm` auf VM `<your-vm-ip>` |
| **GitHub Secrets** | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` |
| **GitHub Pages** | https://\<your-org\>.github.io/datavault-dbt/ |
| **Environments** | `development`, `production` (mit Approval) |

### CI/CD Lessons Learned

1. **Profile-Name muss übereinstimmen:** `profiles.yml` Profile-Name muss mit `dbt_project.yml` → `profile:` übereinstimmen (`datavault`, nicht `datavault_<tenant>`)

2. **DBT_PROFILES_DIR beachten:** Wenn `DBT_PROFILES_DIR` gesetzt ist, muss `profiles.yml` dort erstellt werden, nicht in `~/.dbt/`

3. **GitHub Pages vorher aktivieren:** Docs-Workflow schlägt fehl, wenn GitHub Pages nicht aktiviert ist

4. **Seeds in Prod:** `ref_role` Seed existiert nur in Dev - bei Prod-Deployment müssen Seeds mit `dbt seed --target <tenant>` geladen werden

5. **Runner Version:** Aktuelle Runner-Version dynamisch ermitteln statt hardcoden

---

## Technische Referenz

### Verbindungsdaten
- **Server:** your-sql-server.database.windows.net
- **Database:** DataVault
- **Auth:** Azure CLI (az login)

### VM Zugang
```bash
ssh your-vm-alias  # Alias in ~/.ssh/config
cd ~/projects/datavault-dbt
source .venv/bin/activate
```

### GitHub Actions Runner
```bash
# Runner Service Status prüfen
sudo systemctl status actions.runner.<your-org>-datavault-dbt.dbt-runner-vm

# Runner neu starten
sudo systemctl restart actions.runner.<your-org>-datavault-dbt.dbt-runner-vm

# Runner Logs
journalctl -u actions.runner.<your-org>-datavault-dbt.dbt-runner-vm -f
```

### Aktueller Stand

**Data Vault Objekte:**
| Objekt | Records | Status |
|--------|---------|--------|
| `hub_company` | 22.457 | ✅ |
| `hub_country` | 242 | ✅ |
| `sat_company` | 22.457 | ✅ |
| `sat_country` | 242 | ✅ |
| `sat_company_client_ext` | ~7.500 | ✅ |
| `link_company_role` | 22.457 | ✅ |
| `link_company_country` | 22.457 | ✅ |
| `eff_sat_company_country` | 22.457 | ✅ |
| `pit_company` | ~900k | ✅ |
| `ref_role` | 3 | ✅ |

**Tests:** 39/39 bestanden

**DV 2.1 Optimierungen (2025-12-27):**
- ✅ Ghost Records Macro erstellt
- ✅ dss_is_current + dss_end_date in allen Satellites
- ✅ PIT-Tabelle für sat_company
- ✅ Effectivity Satellite für link_company_country
- ✅ Hash-Berechnung auf automate_dv standardisiert (concat_string '||'; revidiert, s. Entscheidung 6)
