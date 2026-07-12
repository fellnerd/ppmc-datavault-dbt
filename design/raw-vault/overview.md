# Raw Vault - Gesamtübersicht

Vault-Objekte sind nach Konzept organisiert (Schema-Konvention siehe [design/README.md](../README.md)). Jedes Konzept hat sein eigenes ER-Diagramm; diese Seite fasst nur den Implementierungsstand zusammen.

## Konzepte

| Konzept | Schema | Status | Design |
|---------|--------|--------|--------|
| `_common` | `vault` | ✅ Implementiert (Starter-Beispiel) | [er-diagram.mmd](_common/er-diagram.mmd) |
| `sauter` | `vault_sauter` | ⏳ Entwurf — Zielmodell vor Implementierung (Phase 2 / Prototyp) | [sauter/overview.md](sauter/overview.md), [sauter/er-diagram.mmd](sauter/er-diagram.mmd) |
| `_integrated` | `vault` | — noch keine integrierten Objekte | [_integrated/overview.md](_integrated/overview.md) |

## Implementierungsstatus

| Objekt | Konzept | Status | dbt Model |
|--------|---------|--------|-----------|
| `hub_role` | `_common` | ✅ | `models/raw_vault/_common/hubs/hub_role.sql` |
| `sat_role` | `_common` | ✅ | `models/raw_vault/_common/satellites/sat_role.sql` |
| `hub_werk`, `hub_rezept`, `hub_rezeptbasis`, `hub_komponente`, `hub_lieferantenwerk`, `hub_epd_material` | `sauter` | ⏳ geplant | siehe [sauter/overview.md](sauter/overview.md) |

`hub_role`/`sat_role` sind ein seed-basiertes Starter-Beispiel (Quelle: `ref_role`), das die Pipeline `stg → hub → sat` end-to-end beweist (Hash-/Hashdiff-Berechnung über `automate_dv`) — nicht Teil des fachlichen Sauter-Modells für den GWP-Rechner. Das eigentliche Fachmodell steht in `sauter/` und ist noch nicht implementiert.
