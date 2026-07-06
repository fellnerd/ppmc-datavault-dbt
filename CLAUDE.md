# Memory & Project Context

> Working memory for the `datavault` project. See `docs/` for details.
> Respond in the language the user writes in.

## Me

Daniel Fellner, MSc, developer/owner of the `datavault` project, part of **ppmc ag**.

## Project

**datavault** — Virtualized **Data Vault 2.1** architecture on
Azure SQL / SQL Server with dbt Core.

**Data flow:** Source system -> External Table (`stg.ext_*`) -> Staging View (`stg.stg_*`) -> Hub/Sat/Link (`vault.*`)

## People

| Who | Role |
|-----|------|
| **Daniel Fellner, MSc** | Developer/owner |
| **ppmc ag** | Maintainer of the project |

## Terms (Glossary)

| Term | Meaning |
|------|---------|
| **DV 2.1** | Data Vault 2.1 (methodology) |
| **Hub / Sat / Link** | Business Key / Attributes+History / Relationship |
| **PIT** | Point-in-Time table (history snapshots) |
| **hk / hd** | Hash Key / Hash Diff (change detection) |
| **dss_*** | DV metadata: dss_load_date, dss_record_source, dss_is_current, dss_end_date |
| **BK** | Business Key |
| **PSA** | Persistent Staging Area (optional cache layer) |

## Environments

| Target | Database | Usage |
|--------|----------|-------|
| `dev` | datavault-dev | Development |
| `test` | datavault-test | Testing |
| `prod` | datavault | Production |

## Conventions

- **Naming:** `hub_<entity>`, `sat_<entity>`, `link_<e1>_<e2>`, `stg_<entity>`, mart views `v_<name>`
- **Schemas:** `stg.*` (Staging), `vault.*` / `vault_<source>` (Raw Vault), `mart_*` (Business Views)
- **Hash:** SHA -> `CHAR(64)` via `HASHBYTES()`; composite separator `'^^'`
- **Raw Vault physical, Business Vault virtual** (views)
- **Azure SQL Basic Tier:** no columnstore (`+as_columnstore: false`), incremental `append`

## Working rules

- **Always ask** before creating DV objects (offer numbered options).
- **Confirm destructive actions:** `dbt run --full-refresh` (loses history!), deleting models, ALTER/DROP.
- **Never** `--full-refresh` on historized satellites.
- **DB tools read-only** — writes only via dbt commands.
- Details: [docs/CLAUDE.md](docs/CLAUDE.md), [docs/DEVELOPER.md](docs/DEVELOPER.md)

## Infrastructure

| Resource | Value |
|----------|-------|
| SQL Server | ppmcag-datavault.database.windows.net |
| GitHub | `fellnerd/datavault` |

## Preferences

- Concise and direct; avoid unnecessary explanations.
