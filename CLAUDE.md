# Memory & Project Context

> Working memory for the `ppmc-datavault-dbt` project. See `docs/` for details.
> Respond in the language the user writes in (Projektsprache: Deutsch).

## Me

Daniel Fellner, MSc, developer/owner of the `datavault` project, part of **ppmc ag**.

## Projekt

**PPMC Data & BI Plattform** („BMI – Architektur 2.0") — Datalakehouse nach **Data Vault 2.0/2.1** auf Azure SQL mit dbt Core. Fachziel: **GWP-Rechner für Transportbeton** — Treibhausgas-Bilanz je m³ Beton (Module A1–A3 nach EN 15804/ISO 14067), gemeinsam mit Sauter GmbH (Primärdaten) und ASCEM (Fachpartner). Details: [docs/ARCHITEKTUR_BMI.md](docs/ARCHITEKTUR_BMI.md)

**Datenfluss:** Quellsystem → ADF → Blob Storage (Parquet) → External Table (`stg.ext_*`) → Staging View (`stg.stg_*`) → Hub/Sat/Link (`vault_*`) → Marts (`mart_*`)

**GWP-Grundformel:** `GWP_m³ = Σ (Mengeᵢ × GWPᵢ)` — Mengen aus Sauter-Rezepturen (`stoffraum_komponenten`), GWP-Werte aus EPD-Registern (zuerst millieudatabase.nl) via Material-Matching.

## Aktueller Stand (2026-07-11)

- **267 Sauter External Tables** angebunden (`stg.ext_sauter_test_*`, Landing Zone `sauter-test/`) — definiert in `models/staging/sources.yml`
- **ER-Modell validiert:** 18/18 Kernpfad-Tabellen bestätigt → [docs/ER_VALIDIERUNG_SAUTER.md](docs/ER_VALIDIERUNG_SAUTER.md); offene Fachbereichsfragen dort unten
- Raw Vault: nur Starter-Beispiel (`stg_role → hub_role → sat_role`) — Sauter-Modellierung steht aus, Zielentwurf: [design/raw-vault/sauter/overview.md](design/raw-vault/sauter/overview.md)
- Aufgaben & Phasen: [TASKS.md](TASKS.md)

## Quellsysteme

| Quelle | Was | Status |
|--------|-----|--------|
| **Sauter** (Labor-DB) | Primärdaten: Rezepturen, Komponenten, Werke, Preise, Lieferscheine | External Tables ✅, Vault ausstehend |
| **EPD-Register** | Sekundärdaten: GWP-Werte (millieudatabase.nl → ÖKOBAUDAT, baubook) | geplant (Phase 2) |

Quellmodell & Fallstricke (ZEMENTARTENID-Join, KOMPOTYP-Diskriminator, LABORID-Mandantenschlüssel): [docs/QUELLSYSTEM_SAUTER.md](docs/QUELLSYSTEM_SAUTER.md)

## Commands

```bash
source .venv/bin/activate
dbt parse                                   # schnelle Validierung ohne DB
dbt run --select <model> --target dev       # einzelnes Modell
dbt build --select <model>+ --target dev    # Modell + Downstream inkl. Tests
dbt run-operation stage_external_sources    # External Tables anlegen/aktualisieren
.venv/bin/python scripts/validate_er_sources.py   # ER-Modell vs. sources.yml (Skill: validate-er)
```

## Terms (Glossary)

| Term | Meaning |
|------|---------|
| **DV 2.1** | Data Vault 2.1 (methodology) |
| **Hub / Sat / Link** | Business Key / Attributes+History / Relationship |
| **PIT** | Point-in-Time table (history snapshots) |
| **hk / hd** | Hash Key / Hash Diff (change detection) |
| **dss_*** | DV metadata: dss_load_date, dss_record_source, dss_is_current, dss_end_date |
| **BK** | Business Key |
| **GWP** | Global Warming Potential (kg CO₂-Äq.) — das Zielmaß des Rechners |
| **EPD** | Environmental Product Declaration (Umweltproduktdeklaration) |
| **PCR** | Product Category Rules (hier: Transportbeton, 2024) |
| **A1–A3** | Lebenszyklusmodule: Rohstoffe / Transport / Herstellung |
| **KOMPOTYP** | Sauter-Diskriminator: 0 Zuschlag, 1 Bindemittel, 2 Zusatzmittel, 3 Wasser, 6 Füller (Liste unvollständig!) |
| **NMD** | Nationale Milieudatabase (millieudatabase.nl) |

## Environments

| Target | Database | Usage |
|--------|----------|-------|
| `dev` | datavault-dev | Development |
| `test` | datavault-test | Testing |
| `prod` | datavault | Production |

## Conventions

- **Naming:** `hub_<entity>`, `sat_<entity>[__<quelle>]`, `link_<e1>_<e2>`, `stg_<entity>`, mart views `v_<name>`
- **Schemas:** `stg.*` (Staging), `vault.*` / `vault_<source>` (Raw Vault: `vault_sauter`, `vault_epd`), `mart_*` (Business Views)
- **Hash:** SHA → `CHAR(64)` via `HASHBYTES()`; composite separator `'^^'`
- **Raw Vault physical, Business Vault virtual** (views)
- **Azure SQL Basic Tier:** no columnstore (`+as_columnstore: false`), incremental `append`
- **Model-First:** erst Design in `design/` (Mermaid), dann dbt-Implementierung; Diagramme aktuell halten

## Working rules

- **Always ask** before creating DV objects (offer numbered options).
- **Confirm destructive actions:** `dbt run --full-refresh` (loses history!), deleting models, ALTER/DROP. Der PreToolUse-Hook des dv-toolkit-Plugins erzwingt die Bestätigung zusätzlich.
- **Never** `--full-refresh` on historized satellites.
- **DB tools read-only** — writes only via dbt commands.
- Details: [docs/CLAUDE.md](docs/CLAUDE.md), [docs/DEVELOPER.md](docs/DEVELOPER.md)

## Claude-Code-Komponenten (dbt/DV-2.1, generisch)

Die generischen DV-Komponenten kommen aus dem Plugin **`dv-toolkit@datavault-dbt`** (Marketplace = Boilerplate-Repo `fellnerd/datavault-dbt-boilerplate`, in `.claude/settings.json` registriert):

| Komponente | Zweck |
|-----------|-------|
| Skills `dv-patterns`, `dv-staging`, `dv-marts`, `dv-design-sync` | DV-2.1-Patterns/Templates, stage()-Workflow, Star-Schema-Marts, Mermaid-Design-Sync |
| Agents `vault-architect`, `staging-engineer`, `mart-architect`, `db-monitor` | Staging→Vault-Entwurf, Quellanbindung, Marts, Read-only-DB-Statusabgleich |
| Hooks `dv_lint.py` (PostToolUse), `dv_guard.py` (PreToolUse) | Deterministischer DV-Lint auf models/+design/; `--full-refresh` erfordert User-Bestätigung |

Plugin-Updates: `/plugin marketplace update datavault-dbt`. Projektspezifisch bleibt nur Skill `validate-er` (Sauter-ER-Modell gegen sources.yml). Daneben existieren die `datavault:*` Plugin-Skills (`create-hub`, `db-query`, …) — bei Überschneidung die dv-toolkit-Komponenten bevorzugen, sie tragen die Projektkonventionen.

## Infrastructure

| Resource | Value |
|----------|-------|
| SQL Server | ppmcag-datavault.database.windows.net |
| GitHub | `fellnerd/ppmc-datavault-dbt` |

## Preferences

- Concise and direct; avoid unnecessary explanations.
