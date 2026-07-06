# datavault - Data Vault 2.1 dbt Project

> Generated from [datavault-dbt-boilerplate](https://github.com/fellnerd/datavault-dbt-boilerplate) via [Copier](https://copier.readthedocs.io/). Data Vault 2.1 on SQL Server / Azure SQL with dbt Core.

## Overview

This project implements a virtualized Data Vault 2.1 architecture. Source
data flows through External Tables into staging views and is then modeled as
Hubs, Satellites, and Links.

### Architecture

```
Source System -> External Table -> Staging View -> Hub/Sat/Link
                  (stg.ext_*)     (stg.stg_*)    (vault.*)
```

### Environments

| Target | Database | Usage |
|--------|----------|-------|
| `dev` | datavault-dev | Development |
| `test` | datavault-test | Testing |
| `prod` | datavault | Production |

---

## Installation

### Prerequisites

- **Python 3.10+**
- **ODBC Driver 18 for SQL Server**
- **Azure CLI** (required for infra deployment, and for CLI authentication)- **Git**

### 1. Clone the repository

```bash
git clone https://github.com/fellnerd/datavault.git
```

### 2. Create a Python virtual environment

```bash
cd datavault
python3 -m venv .venv
source .venv/bin/activate
```

### 3. Install dbt and dependencies

```bash
pip install --upgrade pip
pip install dbt-core dbt-sqlserver
```

### 4. Install dbt packages

```bash
dbt deps
```

---

## Configure the database connection

The dbt connection is configured via `~/.dbt/profiles.yml` (not part of this
repository!). A ready-to-copy example ships as [`profiles.yml.example`](profiles.yml.example).

```bash
mkdir -p ~/.dbt
cp profiles.yml.example ~/.dbt/profiles.yml
# fill in <SQL_USER> / <SQL_PASSWORD>, or switch to `authentication: cli`
```

### Alternative: Azure CLI authentication (recommended)

```bash
az login
```

then set `authentication: cli` in the relevant target (already the default
for `dev`/`test` in `profiles.yml.example`).

### Required information

| Parameter | Description | Example |
|-----------|--------------|---------|
| `server` | Azure SQL Server FQDN | `ppmcag-datavault.database.windows.net` |
| `database` | Target database | `datavault-dev` |
| `user` | SQL admin user | `sqladmin` |
| `password` | SQL password | (ask your admin) |

### Test the connection

```bash
source .venv/bin/activate
dbt debug
```

Expected output:
```
Connection test: [OK connection ok]
```

If this is a brand-new database, first create the schemas with
[`scripts/setup_schemas.sql`](scripts/setup_schemas.sql) (see `scripts/README.md`).

---

## Usage

### Basic commands

```bash
# Activate environment
source .venv/bin/activate

# Build all models (development)
dbt run

# Single model
dbt run --select hub_customer

# Model with dependencies
dbt run --select +sat_customer+

# Production
dbt run --target prod

# Run tests
dbt test

# Refresh external tables
dbt run-operation stage_external_sources

# Compile SQL without running
dbt compile --select model_name
```

### Full refresh

```bash
# Rebuild all models (loses satellite history!)
dbt run --full-refresh

# Recreate external tables
dbt run-operation stage_external_sources --vars '{"ext_full_refresh": true}'
```

---

## Project structure

```
datavault/
├── dbt_project.yml          # Project configuration
├── packages.yml              # dbt packages (automate_dv, etc.)
├── profiles.yml.example      # Example connection profile
├── models/
│   ├── staging/               # External Tables & Staging Views
│   │   ├── sources.yml        # External table definitions
│   │   └── stg_*.sql          # Staging views with hash calculation
│   ├── raw_vault/
│   │   └── _common/
│   │       ├── hubs/          # Hub tables
│   │       ├── satellites/    # Satellite tables
│   │       └── links/         # Link tables
│   ├── business_vault/
│   └── mart/
├── macros/                   # Custom macros
├── seeds/                    # Reference data (CSV)
├── scripts/                  # Utility SQL scripts (e.g. setup_schemas.sql, setup_external_source.sql)
├── infra/                     # Bicep templates + deploy workflow (see infra/README.md)
├── design/                   # Design templates (hub/link/PIT/bridge)
└── docs/                     # Documentation
```

---

## Documentation

| Document | Description |
|----------|--------------|
| [docs/DEVELOPER.md](docs/DEVELOPER.md) | Detailed developer guide |
| [docs/CLAUDE.md](docs/CLAUDE.md) | AI assistant context |
| [docs/LESSONS_LEARNED.md](docs/LESSONS_LEARNED.md) | Troubleshooting & decisions |

---

## Important notes

### Azure SQL Basic Tier limitations

- **No columnstore index** -> always set `as_columnstore: false`
- **Incremental strategy:** use `append`

### Hash calculation

Uses native SQL Server functions (not automate_dv macros):

```sql
CONVERT(CHAR(64), HASHBYTES('SHA2_256',
    ISNULL(CAST(column AS NVARCHAR(MAX)), '')
), 2)
```

### Common issues

| Problem | Solution |
|---------|----------|
| Schema is created as `dv_stg` instead of `stg` | check the `generate_schema_name` macro |
| External table error | run `dbt run-operation stage_external_sources` |
| Cross-database error | use `{{ target.database }}` instead of a hardcoded database name |

---
## Deploying infrastructure

Azure infrastructure (SQL Server, the `datavault`/`datavault-dev`/`datavault-test`
databases, storage account, and the RBAC needed for managed-identity-based
external data sources) is provisioned via Bicep, triggered through the
**Deploy Azure Infrastructure** GitHub Actions workflow. Prerequisites:
an existing Azure AD admin group, an existing resource group, and 5 GitHub
secrets (`AZURE_CLIENT_ID`/`AZURE_CLIENT_SECRET`/`AZURE_TENANT_ID`/
`AZURE_SUBSCRIPTION_ID`/`SQL_ADMIN_PASSWORD`). See [`infra/README.md`](infra/README.md)
for full details and how to trigger it.

---
## Updating from the template

This project was scaffolded with [Copier](https://copier.readthedocs.io/).
To pull in later improvements to the boilerplate (new macros, CI fixes, doc
updates):

```bash
pipx install copier   # once
copier update
```

Copier reapplies your original answers and merges upstream changes, adding
conflict markers where you've customized files.

---

## Links

- **GitHub:** [fellnerd/datavault](https://github.com/fellnerd/datavault)
- **Boilerplate:** [fellnerd/datavault-dbt-boilerplate](https://github.com/fellnerd/datavault-dbt-boilerplate)
- **dbt Docs:** [docs.getdbt.com](https://docs.getdbt.com)
- **automate_dv:** [automate-dv.readthedocs.io](https://automate-dv.readthedocs.io)

---

## License

ppmc ag - All rights reserved.
