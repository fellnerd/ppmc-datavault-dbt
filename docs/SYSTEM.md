# Data Vault 2.1 - Systemdokumentation

> **Projekt:** Virtual Data Vault 2.1 auf Azure  
> **Version:** 2.0.0  
> **Stand:** 2025-12-27  
> **DV 2.1 Compliance:** ~85%  
> **Maintainer:** Dimetrics Team

---

## 1. Übersicht

Dieses Projekt implementiert eine virtualisierte **Data Vault 2.1** Architektur als wiederverwendbares SaaS-Template. Jeder Mandant erhält eine isolierte Produktionsdatenbank, während die Entwicklung zentral in einer Shared Dev-Datenbank erfolgt.

### 1.1 Architektur-Diagramm

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              QUELLSYSTEME                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  <source_system> (z.B. PostgreSQL, SQL Server, REST API)                    │
│  └── public.<entity_1>                                                      │
│  └── public.<entity_2>                                                      │
│  └── public.<entity_3>                                                      │
│  └── public.<entity_4>                                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ Synapse Pipeline (Full/Delta Load)
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AZURE DATA LAKE STORAGE GEN2                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  Storage Account: <your-datalake-account>                                   │
│  Container: stage-fs                                                        │
│  └── <concept>/postgres/public.<entity_1>.parquet                          │
│  └── <concept>/postgres/public.<entity_2>.parquet                          │
│  └── <concept>/postgres/public.<entity_3>.parquet                          │
│  └── <concept>/postgres/public.<entity_4>.parquet                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ PolyBase External Tables
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AZURE SQL DATABASE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  Server: your-sql-server.database.windows.net                              │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │ Vault (Dev)     │  │ Vault_<Tenant1> │  │ Vault_<Tenant2> │             │
│  │ Shared Dev DB   │  │ Produktion      │  │ Produktion      │             │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤             │
│  │ [stg] Schema    │  │ [stg] Schema    │  │ [stg] Schema    │             │
│  │  └ ext_*        │  │  └ ext_*        │  │  └ ext_*        │             │
│  │  └ stg_*        │  │  └ stg_*        │  │  └ stg_*        │             │
│  │ [vault] Schema  │  │ [vault] Schema  │  │ [vault] Schema  │             │
│  │  └ hub_*        │  │  └ hub_*        │  │  └ hub_*        │             │
│  │  └ sat_*        │  │  └ sat_*        │  │  └ sat_*        │             │
│  │  └ link_*       │  │  └ link_*       │  │  └ link_*       │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ dbt Core (Transformation)
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DBT PROJEKT                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  VM: <your-vm-ip> (Linux)                                                   │
│  Projekt: datavault-dbt                                                     │
│  Packages: automate_dv, dbt_external_tables, dbt_utils                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Komponenten

### 2.1 Azure Ressourcen

| Ressource | Name | Zweck |
|-----------|------|-------|
| SQL Server | `your-sql-server` | Hosting aller Vault-Datenbanken |
| SQL Database | `Vault` | Shared Development |
| SQL Database | `Vault_<Tenant>` | Produktion Mandant `<Tenant>` |
| Storage Account | `<your-datalake-account>` | ADLS Gen2 für Parquet-Dateien |
| Container | `stage-fs` | Staging-Bereich für Quelldaten |

### 2.2 Datenbank-Schemas

| Schema | Inhalt | Beschreibung |
|--------|--------|--------------|
| `stg` | ext_<concept>_<entity>, <concept>_<entity> | Rohdaten aus ADLS + Hash-Berechnung (Concept = Quellsystem) |
| `vault` | Hubs, Satellites, Links | Data Vault 2.1 Objekte |
| `dv` | (Default) | Nicht verwendet |

### 2.3 dbt Packages

| Package | Version | Zweck |
|---------|---------|-------|
| `automate_dv` | 0.10.2 | Data Vault Macros (Hubs, Sats, Links) |
| `dbt_external_tables` | 0.11.0 | Deklarative External Table Verwaltung |
| `dbt_utils` | 1.3.3 | Allgemeine Utility Macros |

---

## 3. Datenmodell

### 3.1 Data Vault Objekte

#### Hubs (Business Keys)
| Hub | Business Key | Records | Beschreibung |
|-----|--------------|---------|---------------|
| `hub_company` | `object_id + source_table` | 22.457 | Alle Unternehmen (Client/Contractor/Supplier) |
| `hub_country` | `object_id` | 242 | Länder |

#### Satellites (Attribute)
| Satellite | Parent Hub | Records | Beschreibung |
|-----------|------------|---------|---------------|
| `sat_company` | `hub_company` | 22.457 | Gemeinsame Attribute aller Unternehmen |
| `sat_company_client_ext` | `hub_company` | ~7.500 | Client-spezifische Attribute (Freistellungsbescheinigung) |
| `sat_country` | `hub_country` | 242 | Länder-Attribute |

#### Links (Beziehungen)
| Link | Verbindet | Records | Beschreibung |
|------|-----------|---------|---------------|
| `link_company_role` | `hub_company` ↔ `ref_role` | 22.457 | Rolle eines Unternehmens |
| `link_company_country` | `hub_company` ↔ `hub_country` | 22.457 | Unternehmensstandort |

#### Business Vault Objekte
| Objekt | Typ | Beschreibung |
|--------|-----|---------------|
| `pit_company` | Table | Point-in-Time für sat_company |
| `eff_sat_company_country` | Incremental | Effectivity Satellite für link_company_country |

#### Reference Data
| Tabelle | Records | Beschreibung |
|---------|---------|---------------|
| `ref_role` | 3 | CLIENT, CONTRACTOR, SUPPLIER |

### 3.2 Hash-Berechnung

- **Algorithmus:** SHA2_256
- **Format:** CHAR(64), Hex-String (uppercase)
- **Hash Key:** `hk_<entity>` - Business Key Hash
- **Hash Diff:** `hd_<entity>` - Attribut-Hash für Change Detection

```sql
-- Hash-Berechnung (SQL Server)
CONVERT(CHAR(64), HASHBYTES('SHA2_256', 
    ISNULL(CAST(column AS NVARCHAR(MAX)), '')
), 2)
```

### 3.3 Metadata-Spalten

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `dss_load_date` | DATETIME2 | Zeitpunkt des Ladens in Vault |
| `dss_record_source` | NVARCHAR | Quellsystem-Identifikation |
| `dss_run_id` | NVARCHAR | Pipeline Run ID |

---

## 4. Umgebungen & Targets

### 4.1 Multi-Mandanten-Architektur

```
┌─────────────────────────────────────────────────────┐
│              Git Repo: datavault-dbt                │
│              (Ein Projekt für alle Mandanten)       │
├─────────────────────────────────────────────────────┤
│  Target: dev      │  Target: <tenant1>  │  Target: <tenant2>  │
└────────┬──────────┴──────────┬───────────┴──────┬───┘
         ▼                     ▼                  ▼
   ┌──────────┐         ┌───────────────┐   ┌─────────────┐
   │  Vault   │         │Vault_<Tenant1>│   │Vault_<Tenant2>│
   │  (Dev)   │         │   (Prod)       │  │ (Prod)       │
   └──────────┘         └───────────────┘   └─────────────┘
```

### 4.2 Target-Konfiguration

| Target | Datenbank | Verwendung |
|--------|-----------|------------|
| `dev` | Vault | Shared Development (Default) |
| `<tenant1>` | Vault_<Tenant1> | Produktion Mandant `<Tenant1>` |
| `<tenant2>` | Vault_<Tenant2> | Produktion Mandant `<Tenant2>` |

---

## 5. Dateistruktur

```
datavault-dbt/
├── dbt_project.yml          # Projektkonfiguration
├── packages.yml             # Package-Abhängigkeiten
├── package-lock.yml         # Lock-File
├── macros/
│   ├── generate_schema_name.sql  # Custom Schema Naming
│   └── hash_override.sql         # Hash-Macro Override
├── models/
│   ├── schema.yml           # Tests & Dokumentation
│   ├── staging/
│   │   ├── sources.yml      # External Tables Definition
│   │   └── stg_company_client.sql
│   └── raw_vault/
│       ├── hubs/
│       │   └── hub_company_client.sql
│       ├── satellites/
│       │   └── sat_company_client.sql
│       └── links/           # (TODO)
├── scripts/
│   └── setup_<tenant>_prod.sql  # Setup-Script (veraltet)
├── docs/
│   ├── SYSTEM.md            # Diese Datei
│   └── USER.md              # Benutzer-Dokumentation
└── LESSONS_LEARNED.md       # Erfahrungen & Troubleshooting
```

---

## 6. Konfiguration

### 6.1 dbt_project.yml

```yaml
name: 'datavault'
profile: 'datavault'

vars:
  hash: 'SHA'
  load_date: 'dss_load_date'
  record_source: 'dss_record_source'

models:
  datavault:
    staging:
      +schema: stg
      +materialized: view
    raw_vault:
      hubs:
        +schema: vault
        +materialized: incremental
        +incremental_strategy: append
        +as_columnstore: false
      satellites:
        +schema: vault
        +materialized: incremental
        +incremental_strategy: append
        +as_columnstore: false
      links:
        +schema: vault
        +materialized: incremental
        +incremental_strategy: append
        +as_columnstore: false
```

### 6.2 Azure SQL Limitationen (Basic Tier)

- ❌ Columnstore Index nicht verfügbar → `+as_columnstore: false`
- ❌ Cross-Database Queries nicht möglich → Dynamische `{{ target.database }}`
- ✅ PolyBase External Tables unterstützt
- ✅ Managed Identity Authentication

---

## 7. Sicherheit

### 7.1 Authentifizierung

- **dbt → Azure SQL:** Azure CLI Authentication (`authentication: cli`)
- **External Tables → ADLS:** Managed Identity (`SynapseManagedIdentity`)

### 7.2 Netzwerk

- SQL Server Firewall: Azure Services + spezifische IPs
- ADLS: Private Endpoint (optional)

### 7.3 Secrets

- Keine Passwörter in profiles.yml
- profiles.yml liegt im Projekt-Root (gitignored) oder in `~/.dbt/`
- Azure CLI Token wird bei Bedarf geholt

---

## 8. Erweiterung

### 8.1 Neuen Mandanten hinzufügen

1. **Azure SQL Database erstellen:**
   ```bash
   az sql db create \
     --resource-group <your-resource-group> \
     --server <your-sql-server> \
     --name Vault_<Mandant> \
     --edition Basic
   ```

2. **Target in profiles.yml hinzufügen:**
   ```yaml
   <mandant>:
     type: sqlserver
     server: your-sql-server.database.windows.net
     database: Vault_<Mandant>
     # ... (wie andere Targets)
   ```

3. **Infrastruktur erstellen:**
   ```bash
   # Schemas, Credentials, Data Source, File Format
   dbt run-operation stage_external_sources --target <mandant>
   ```

4. **Data Vault deployen:**
   ```bash
   dbt run --target <mandant>
   ```

### 8.2 Neue Entity hinzufügen

1. **External Table in `sources.yml` definieren**
2. **Staging View erstellen:** `models/staging/stg_<entity>.sql`
3. **Hub erstellen:** `models/raw_vault/hubs/hub_<entity>.sql`
4. **Satellite erstellen:** `models/raw_vault/satellites/sat_<entity>.sql`
5. **Link erstellen (falls nötig):** `models/raw_vault/links/link_<entity>_<entity2>.sql`

---

## 9. Monitoring & Troubleshooting

### 9.1 Logs

- dbt Logs: `logs/dbt.log`
- Query Log: `logs/query_log.sql`
- Target Artefakte: `target/`

### 9.2 Häufige Fehler

| Fehler | Ursache | Lösung |
|--------|---------|--------|
| `Cross-database reference not supported` | Hardcoded Database | `{{ target.database }}` verwenden |
| `Columnstore not supported` | Basic Tier | `+as_columnstore: false` |
| `External table error` | Falscher Data Source Type | Ohne `TYPE` erstellen |

---

## 10. CI/CD Pipeline (GitHub Actions)

### 10.1 Architektur

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB ACTIONS CI/CD                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   CI.yml    │    │deploy-dev.yml│   │deploy-prod.yml│  │  docs.yml   │ │
│  │  (PR Check) │    │ (Auto Dev)  │    │(Manual Prod)│    │(GitHub Pages)│ │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘ │
│         │                  │                  │                  │        │
│         ▼                  ▼                  ▼                  ▼        │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │                    Self-hosted Runner: dbt-runner-vm                 │ │
│  │                    VM: <your-vm-ip> (Linux)                          │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                    │                                      │
│                                    ▼                                      │
│         ┌──────────────────────────────────────────────────┐             │
│         │  Azure SQL: your-sql-server                     │             │
│         │  Dev:  Vault  │  Prod: Vault_<Tenant>            │             │
│         └──────────────────────────────────────────────────┘             │
└────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Workflows

| Workflow | Trigger | Ziel-DB | Approval |
|----------|---------|---------|----------|
| `ci.yml` | PR → main/dev | Vault (test-only) | Nein |
| `deploy-dev.yml` | Push main / Manual | Vault | Nein |
| `deploy-prod.yml` | Tag v* / Manual | Vault_<Tenant> | Ja |
| `docs.yml` | Push main / Manual | GitHub Pages | Nein |

### 10.3 Authentifizierung

| Komponente | Methode | Details |
|------------|---------|---------|
| Azure CLI | Service Principal | `sp-github-datavault-dbt` |
| Azure SQL | Azure AD (CLI) | SQL Server AD Admin: dbadmin |
| GitHub | Secrets | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` |

### 10.4 GitHub Environments

| Environment | Schutz | Verwendung |
|-------------|--------|------------|
| `development` | Keine | Automatische Dev-Deployments |
| `production` | Required Reviewer | Manuelle Prod-Freigabe |

### 10.5 Runner-Service

```bash
# Status prüfen
sudo systemctl status actions.runner.<your-org>-datavault-dbt.dbt-runner-vm

# Neustart
sudo systemctl restart actions.runner.<your-org>-datavault-dbt.dbt-runner-vm

# Logs
journalctl -u actions.runner.<your-org>-datavault-dbt.dbt-runner-vm -f
```

---

## 11. Changelog

| Datum | Version | Änderung |
|-------|---------|----------|
| 2025-12-28 | 2.1.0 | **CI/CD Pipeline:** GitHub Actions mit Self-hosted Runner |
| 2025-12-28 | 2.1.0 | 4 Workflows (CI, Deploy-Dev, Deploy-Prod, Docs) |
| 2025-12-28 | 2.1.0 | GitHub Pages für dbt Docs |
| 2025-12-27 | 2.0.0 | **DV 2.1 Optimierung:** Ghost Records, PIT-Tabellen, Effectivity Satellites |
| 2025-12-27 | 2.0.0 | Unified Hub Pattern (hub_company statt 3 separate Hubs) |
| 2025-12-27 | 2.0.0 | dss_is_current + dss_end_date in allen Satellites |
| 2025-12-27 | 2.0.0 | Hash-Separator von '||' auf '^^' geändert |
| 2025-12-27 | 1.0.0 | Initial Release |
| 2025-12-27 | 1.0.0 | Multi-Mandanten-Architektur implementiert |
| 2025-12-27 | 1.0.0 | dbt-external-tables Package integriert |

---

## 12. Wiederverwendbare Macros

| Macro | Datei | Beschreibung |
|-------|-------|---------------|
| `generate_schema_name` | `macros/generate_schema_name.sql` | Schema ohne dbt-Prefix |
| `update_satellite_current_flag` | `macros/satellite_current_flag.sql` | Post-Hook für dss_is_current |
| `update_effectivity_end_dates` | `macros/satellite_current_flag.sql` | End-Dating für Effectivity Sats |
| `zero_key` | `macros/ghost_records.sql` | 64x '0' (NULL Business Keys) |
| `error_key` | `macros/ghost_records.sql` | 64x 'F' (Fehlerhafte Daten) |
| `insert_ghost_records` | `macros/ghost_records.sql` | Ghost Records in Hubs einfügen |

## 13. Reproduzierbarkeit

### Komplettes Deployment von Null

```bash
# 1. VM Setup
ssh user@<your-vm-ip>
cd ~/projects/datavault-dbt
source .venv/bin/activate

# 2. Azure Login
az login
az account set --subscription "<subscription-id>"

# 3. dbt Packages installieren
dbt deps

# 4. Verbindung testen
dbt debug

# 5. External Tables erstellen
dbt run-operation stage_external_sources

# 6. Reference Data laden
dbt seed

# 7. Alle Models bauen
dbt run --full-refresh

# 8. Ghost Records einfügen (optional)
dbt run-operation insert_ghost_records

# 9. Tests ausführen
dbt test
```

### Produktions-Deployment

```bash
# Mandant: <tenant>
dbt run-operation stage_external_sources --target <tenant>
dbt seed --target <tenant>
dbt run --target <tenant>
dbt test --target <tenant>
```

---

## 14. Weiterführende Dokumentation

| Dokument | Inhalt | Link |
|----------|--------|------|
| User-Dokumentation | Endanwender-Guide, FAQ | [USER.md](USER.md) |
| **Developer Guide** | **Anleitungen für Entwickler** | [DEVELOPER.md](DEVELOPER.md) |
| Model Architecture | Datenmodell, ERD | [MODEL_ARCHITECTURE.md](MODEL_ARCHITECTURE.md) |
| Lessons Learned | Entscheidungen, Troubleshooting | [LESSONS_LEARNED.md](../LESSONS_LEARNED.md) |
| **CI/CD Plan** | **Pipeline Implementation Plan** | [plan-githubActionsCiCd.prompt.md](../.github/prompts/plan-githubActionsCiCd.prompt.md) |
| **dbt Docs** | **Generierte Dokumentation** | [GitHub Pages](https://<your-org>.github.io/datavault-dbt/) |
