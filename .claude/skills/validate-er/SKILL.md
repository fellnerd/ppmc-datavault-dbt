---
name: validate-er
description: Validiert das Sauter-ER-Modell gegen die External Tables in sources.yml. Nutzen wenn das ER-Diagramm aktualisiert wurde, neue External Tables generiert wurden oder vor der Modellierung neuer Vault-Objekte geprüft werden soll, ob Quelle und Design übereinstimmen.
---

# ER-Validierung Sauter

Prüft das dokumentierte ER-Modell gegen die tatsächlich angebundenen External Tables.

## Ablauf

1. Skript ausführen:
   ```bash
   .venv/bin/python scripts/validate_er_sources.py
   ```
   (`--markdown` für eine Tabelle, die direkt in Doku eingefügt werden kann.)

2. Ergebnis interpretieren:
   - **FEHLT** — External Table existiert nicht → Landing Zone / `sources.yml`-Generierung prüfen
   - **ABWEICHUNG** — im ER dokumentierte Spalte fehlt in der Quelle → ER-Diagramm oder Parquet-Export prüfen
   - **Zusätzliche Spalten** — normal (ER ist bewusster Ausschnitt); GWP-relevante Kandidaten (DICHTE, *MENGE) ggf. in die Sat-Spaltenauswahl aufnehmen

3. Bei Änderungen am ER-Diagramm: das erwartete Modell in `scripts/validate_er_sources.py` (`ER_MODEL` dict) nachziehen **und** [docs/QUELLSYSTEM_SAUTER.md](../../../docs/QUELLSYSTEM_SAUTER.md) aktualisieren.

4. Ergebnis in [docs/ER_VALIDIERUNG_SAUTER.md](../../../docs/ER_VALIDIERUNG_SAUTER.md) dokumentieren (Datum aktualisieren).

## Kontext

- Das ER-Diagramm „ER_Sauter" dokumentiert nur den join-relevanten Kernpfad (~18 von 267 Tabellen).
- Offene Fachbereichsfragen stehen in docs/ER_VALIDIERUNG_SAUTER.md unten — vor Hub-Modellierung klären.
