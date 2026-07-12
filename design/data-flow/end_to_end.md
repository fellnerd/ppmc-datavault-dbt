# End-to-End Datenfluss

## Gesamtarchitektur

```mermaid
flowchart TB
    subgraph Sources["🗄️ Quellsysteme"]
        SAUTER[(Sauter Labor-DB<br/>Primärdaten: Rezepturen)]
        EPD[(EPD-Register<br/>millieudatabase.nl, geplant)]
        SEED[["ref_role Seed<br/>(Starter-Beispiel)"]]
    end

    subgraph Integration["⚙️ Azure Integration"]
        ADF[Azure Data Factory]
        ADLS[("ADLS Gen2<br/>Parquet Files")]
    end

    subgraph Staging["📥 Staging Layer (schema stg)"]
        EXT["External Tables<br/>stg.ext_sauter_test_*"]
        STG["Staging Views<br/>stg.stg_sauter_*, stg.stg_role"]
    end

    subgraph RawVault["🏛️ Raw Vault"]
        HUBS_C["vault.hub_role"]
        SATS_C["vault.sat_role"]
        HUBS_S["vault_sauter.hub_* (geplant)"]
        LINKS_S["vault_sauter.link_* (geplant)"]
        SATS_S["vault_sauter.sat_* (geplant)"]
    end

    subgraph BusinessVault["📊 Business Vault (geplant)"]
        EFFSAT["Eff-Sat: Material-Matching<br/>Komponente ↔ EPD"]
    end

    subgraph Mart["📈 Mart"]
        DIMDATE["mart._common.dim_date<br/>(generiert, quellunabhängig)"]
    end

    SAUTER -->|DB-Connector| ADF
    EPD -.->|REST API, geplant| ADF
    ADF --> ADLS
    ADLS --> EXT
    EXT --> STG

    SEED --> STG

    STG -->|stg_role| HUBS_C
    STG -->|stg_role| SATS_C
    STG -.->|stg_sauter_*, geplant| HUBS_S
    STG -.->|stg_sauter_*, geplant| LINKS_S
    STG -.->|stg_sauter_*, geplant| SATS_S

    LINKS_S -.-> EFFSAT
```

## Schicht-Details

### 1. Quellsysteme → ADLS

| Quelle | Ziel-Pfad | Status |
|--------|-----------|--------|
| Sauter Labor-DB | `sauter-test/*.parquet` | ✅ angebunden (267 External Tables) |
| EPD-Register (millieudatabase.nl) | `epd/*.parquet` | ⏳ geplant (Phase 2) |

Details: [design/staging/source_mapping.md](../staging/source_mapping.md)

### 2. Staging → Raw Vault (implementiert: Starter-Beispiel)

```mermaid
flowchart LR
    SEED[["ref_role (seed)"]]
    STG["stg_role<br/>(hk_role, hd_role, dss_*)"]
    HUB["hub_role"]
    SAT["sat_role"]

    SEED -->|automate_dv.stage| STG
    STG -->|hk_role, role_code, dss_*| HUB
    STG -->|hk_role, hd_role, role_name, role_description| SAT
```

### 3. Staging → Raw Vault (geplant: Sauter)

Siehe [design/raw-vault/sauter/er-diagram.mmd](../raw-vault/sauter/er-diagram.mmd) für das vollständige Zielmodell (Hubs `hub_werk`, `hub_rezept`, `hub_rezeptbasis`, `hub_komponente`, `hub_lieferantenwerk`; Links inkl. `link_rezept_komponente` mit `sat_stoffraum` als Mengenbasis für `GWP_m³ = Σ (Mengeᵢ × GWPᵢ)`).

## dbt DAG (aktueller Stand)

```mermaid
flowchart LR
    subgraph Staging
        stg_role
    end

    subgraph RawVault["Raw Vault (_common)"]
        hub_role
        sat_role
    end

    subgraph Mart
        dim_date
    end

    stg_role --> hub_role
    stg_role --> sat_role
```

`dim_date` ist eine generierte, quellunabhängige Datumsdimension (2020–2035) ohne Upstream-Abhängigkeit im DAG.
