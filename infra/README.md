# Azure infrastructure for datavault

Bicep templates + a GitHub Actions workflow to provision the Azure SQL Server,
up to three databases (prod/dev/test), and the storage account + RBAC needed
for managed-identity-based external data sources.

## What gets created

- **SQL Server** (`sqlServerName`) with one system-assigned managed identity,
  an AAD admin group, and a secondary SQL auth login (both work side by side).
- **Databases** — `datavault`, `datavault-dev`,
  `datavault-test` — each individually toggleable, all serverless
  General Purpose with auto-pause.
- **Firewall** — only the "Allow Azure Services" rule (0.0.0.0/0.0.0.0) by
  default. A fully-open rule (0.0.0.0-255.255.255.255) is available but
  opt-in only (`allow_all_ips_firewall`) — **not recommended**.
- **Storage account** — either a new one (ADLS Gen2 + a `stage-fs`
  container) or a reference to an existing one, your choice per deployment.
- **RBAC** — grants the SQL Server's managed identity `Storage Blob Data
  Contributor` (or Reader) on the storage account, so `CREATE EXTERNAL DATA
  SOURCE ... CREDENTIAL = [managed_identity]` actually works.

After the Bicep deployment, the workflow also runs
[`../scripts/setup_external_source.sql`](../scripts/setup_external_source.sql)
against each deployed database — this creates the master key, the
`managed_identity` database-scoped credential, the `ParquetFormat` external
file format, and the `StageFileSystem` external data source (matching the
names expected by `models/staging/sources.yml`).

This post-deploy step authenticates with the **SQL admin login** created by
the Bicep deployment (`sql_admin_login` + the `SQL_ADMIN_PASSWORD` secret) —
the deploying service principal does **not** need to be a member of the AAD
admin group. It reaches the server through the "Allow Azure Services"
firewall rule, which GitHub-hosted runners (running in Azure) pass through.

## Prerequisites

0. **Resource providers are registered on the subscription** (one-time per
   subscription; a fresh subscription fails with `MissingSubscriptionRegistration`
   otherwise). The service principal cannot do this itself — it is only
   RG-scoped. Run once as a subscription admin:

   ```bash
   az provider register --namespace Microsoft.Sql
   az provider register --namespace Microsoft.Storage
   # check: az provider show -n Microsoft.Sql --query registrationState
   ```

1. **An Azure AD group already exists** to use as the SQL Server's AAD admin
   — this template does not create AAD groups. You'll need its display name
   and object ID.
2. **The target resource group already exists.** The workflow deploys *into*
   a resource group (`az deployment group create`); it does not create one.
3. **The deploying service principal has enough rights**, specifically:
   - Rights to create SQL servers/databases and storage accounts (e.g.
     `Contributor`).
   - `Microsoft.Authorization/roleAssignments/write` on the storage account
     to grant the RBAC role — this is **stricter than `Contributor`** and
     commonly the cause of a failed deployment if missing. You need e.g.
     `User Access Administrator` or `Owner` on the storage account (or its
     resource group).

## Required GitHub secrets

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | Service principal used by `azure/login` |
| `AZURE_CLIENT_SECRET` | ditto |
| `AZURE_TENANT_ID` | ditto |
| `AZURE_SUBSCRIPTION_ID` | ditto |
| `SQL_ADMIN_PASSWORD` | Password for the secondary SQL admin login (`sqlAdminLogin`) |

## How to trigger

GitHub -> Actions -> **Deploy Azure Infrastructure** -> "Run workflow", then
fill in: resource group, AAD admin group name/object ID, which of the three
databases to deploy (three separate checkboxes — GitHub Actions has no true
multi-select, so each database is its own toggle), and whether to create a
new storage account or use an existing one.

**Recommended first run:** tick `what_if_only` to preview the changes
(`az deployment group what-if`) before actually applying them.

## After deployment

Run `dbt run-operation stage_external_sources` (from CI or locally) to
actually create the external tables declared in `models/staging/sources.yml`
— the infra workflow only sets up the data source/credential/file format,
not the tables themselves.

## Known rough edges

- **RBAC propagation delay:** Azure role assignments can take a short time
  (usually seconds) to actually take effect. If the external-data-source
  setup step fails immediately after a fresh deployment with a permissions
  error, wait a bit and re-run the workflow — the script is idempotent.
- **Don't disable the "Allow Azure Services" firewall rule** if you use
  GitHub-hosted runners — the post-deploy SQL step (and dbt CI runs) reach
  the server through it. With a self-hosted runner you can replace it with
  a firewall rule for that runner's IP instead.
- **Don't enable Azure-AD-only authentication** on the server
  (`azureADOnlyAuthentication`) unless you also rework the post-deploy SQL
  step — it authenticates with the SQL admin login, which AAD-only mode
  disables.
- **Serverless auto-pause:** a paused database takes a moment to resume on
  first connection. The workflow uses a 60s login timeout to absorb this;
  ad-hoc local connections right after a long idle period may still need a
  retry.
- **Local validation:** `az bicep build --file main.bicep` for a syntax
  check, `az deployment group validate` / `az deployment group what-if`
  against a real (test) resource group before a real deploy.
- **MFA policy vs. local CLI:** Azure now enforces MFA for *user accounts*
  on resource writes — a plain `az login` session may get
  `RequestDisallowedByAzure ... MFA` errors when creating resource groups
  or deploying locally. Re-login interactively with MFA if that happens.
  The GitHub Actions workflow is unaffected: it authenticates as a service
  principal, and the MFA requirement does not apply to workload identities.
