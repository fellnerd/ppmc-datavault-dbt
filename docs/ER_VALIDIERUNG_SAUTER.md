# ER-Validierung: ER_Sauter vs. External Tables

> Ergebnis der Prüfung des ER-Diagramms „ER_Sauter" gegen die 267 in
> [models/staging/sources.yml](../models/staging/sources.yml) definierten External Tables
> (`ext_sauter_test_*`, Landing Zone `sauter-test/`).
> Re-Run: `.venv/bin/python scripts/validate_er_sources.py` · Stand: 2026-07-11

## Ergebnis: 18/18 Tabellen strukturell bestätigt ✅

Jede ER-Tabelle existiert als External Table, **alle im ER dokumentierten Spalten sind vorhanden** — inkl. des Sonderfalls `STAMM_BINDEMITTELARTEN.ZEMENTARTENID`. Das ER-Diagramm ist damit als Join-Pfad-Dokumentation valide.

| ER-Tabelle | External Table | Status | Fehlende ER-Spalten | Zusätzl. Spalten |
|---|---|---|---|---|
| STAMM_FIRMA_WERKE | `ext_sauter_test_stamm_firma_werke` | OK | — | 80 |
| IMPORT_LIEFERSCHEINE | `ext_sauter_test_import_lieferscheine` | OK | — | 102 |
| KOMMUNIKATION_EXTREZEPTBASIS | `ext_sauter_test_kommunikation_extrezeptbasis` | OK | — | 56 |
| ANNAHME_BASIS | `ext_sauter_test_annahme_basis` | OK | — | 20 |
| STOFFRAUM_KOMPONENTEN | `ext_sauter_test_stoffraum_komponenten` | OK | — | 11 |
| KOMPO_KOMPONENTENVERBUND | `ext_sauter_test_kompo_komponentenverbund` | OK | — | 0 |
| KOMPO_PREISE | `ext_sauter_test_kompo_preise` | OK | — | 0 |
| STAMM_LIEFERANTENWERK | `ext_sauter_test_stamm_lieferantenwerk` | OK | — | 18 |
| KOMPO_ZUSCHLAG_FIRMA | `ext_sauter_test_kompo_zuschlag_firma` | OK | — | 218 |
| KOMPO_BINDEMITTEL_FIRMA | `ext_sauter_test_kompo_bindemittel_firma` | OK | — | 168 |
| KOMPO_ZUSATZMITTEL_FIRMA | `ext_sauter_test_kompo_zusatzmittel_firma` | OK | — | 162 |
| KOMPO_WASSER_FIRMA | `ext_sauter_test_kompo_wasser_firma` | OK | — | 156 |
| KOMPO_FUELLER_FIRMA | `ext_sauter_test_kompo_fueller_firma` | OK | — | 158 |
| STAMM_ZUSCHLAGARTEN | `ext_sauter_test_stamm_zuschlagarten` | OK | — | 2 |
| STAMM_BINDEMITTELARTEN | `ext_sauter_test_stamm_bindemittelarten` | OK | — | 2 |
| STAMM_ZUSATZMITTELARTEN | `ext_sauter_test_stamm_zusatzmittelarten` | OK | — | 2 |
| STAMM_WASSERARTEN | `ext_sauter_test_stamm_wasserarten` | OK | — | 0 |
| STAMM_ZUSATZSTOFFARTEN | `ext_sauter_test_stamm_zusatzstoffarten` | OK | — | 3 |

## Erkenntnisse über das ER-Diagramm hinaus

### 1. Das ER ist ein bewusster Ausschnitt

Die Quellen liefern deutlich mehr Spalten als dokumentiert (z. B. `kompo_zuschlag_firma`: 227 statt 9). Für die Staging-Modellierung heißt das: **Spaltenauswahl je Modell aktiv treffen**, nicht blind alles hashen. GWP-relevante Zusatzspalten, die im ER fehlen, aber wichtig werden:

- `KOMPO_*_FIRMA`: **DICHTE**, SCHUETTDICHTE, EIGENFEUCHTE (Umrechnung Masse/Volumen für die funktionale Einheit 1 m³)
- `IMPORT_LIEFERSCHEINE`: **ZUSCHLAGMENGE, BINDEMITTELMENGE, FUELLERMENGE, ZUSATZMITTELMENGE, WASSERMENGE** — aggregierte Ist-Mengen je Lieferschein (Ist-Bilanzierung statt Soll-Rezeptur!)
- `ANNAHME_BASIS`: ANNAHMEID, DURCHFUEHRDATUM, DRUCKFESTIGKEIT_FCK — die Tabelle ist real eine Prüf-/Annahmetabelle, nicht nur eine Rezept-Brücke

### 2. Die KOMPOTYP-Liste ist unvollständig

Das ER kennt Typ 0/1/2/3/6 (Zuschlag/Bindemittel/Zusatzmittel/Wasser/Füller). Es existieren aber weitere `KOMPO_<typ>_FIRMA`-Tabellen: **`kompo_farbe_firma`, `kompo_fasern_firma`, `kompo_zusatzstoff_firma`** (je ~165–170 Spalten, gleiche Struktur). → Mit Sauter/Fachbereich klären, welche KOMPOTYP-IDs dahinterstehen und ob sie GWP-relevant sind (Fasern vermutlich ja).

### 3. Konkurrierende/ergänzende Tabellen zum Kernpfad

36 verwandte Tabellen liegen außerhalb des ER-Modells (vollständige Liste: Skript-Output). Klärungsbedarf vor der Hub-Modellierung:

| Tabelle | Frage |
|---------|-------|
| `stoffraum_basisdaten` (292 Sp.), `stoffraum_sorten`, `stoffraum_datenblatt` | Ist der Rezept-Stamm hier statt in `kommunikation_extrezeptbasis`? |
| `stoffraum_preise` (13 Sp.) vs. `kompo_preise` (6 Sp.) vs. `rezept_preise` | Welche Preistabelle ist führend? |
| `rezept_werkzuweisung` | Alternative/Ergänzung zur Werk-Rezept-Beziehung aus `annahme_basis`? |
| `kompo_*_hilfstabelle` (je 4 Sp.) | Bedeutung? (evtl. Lookup für Dosierung) |
| `import_lieferschein_chargen`, `_dosierungen` | Charge/Dosierung einzeln — Grain für Ist-Bilanzierung |

### 4. Offene Punkte für den Fachbereich (Sauter/ASCEM)

1. KOMPOTYP-IDs für Farbe/Fasern/Zusatzstoff bestätigen (und Abgrenzung Füller ↔ Zusatzstoff — beide nutzen ZUSATZSTOFFART*)
2. Führende Quelle für Rezeptstamm und Preise festlegen (stoffraum_* vs. kommunikation_* vs. kompo_*)
3. Soll- vs. Ist-Bilanzierung: Rezeptur (`stoffraum_komponenten`) oder Lieferschein-Mengen (`import_lieferscheine`) als Mengenbasis für den GWP-Rechner?
4. Bedeutung `ANRECHNUNGSFAKTOR` in `stoffraum_komponenten` für die GWP-Formel klären (k-Wert-Anrechnung?)
