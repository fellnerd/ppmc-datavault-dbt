# scripts/

Utility SQL scripts that support setup and operations for this project.

- `setup_schemas.sql` — creates the empty staging/vault/mart schemas in a
  fresh target database, so `dbt debug` and the first `dbt run` work without
  manual setup.

Add customer- or environment-specific setup scripts here as needed; they are
not tracked upstream in the boilerplate template.
