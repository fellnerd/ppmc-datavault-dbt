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

> **Update 2026-07-14** — Fachgespräch mit Sauter geführt, Antworten unten eingearbeitet.
> Aussagen wurden gegen die tatsächlichen Spaltenlisten in `sources.yml` verifiziert (Transkripte per ChatGPT aufgezeichnet, Transkriptionsfehler möglich — kritische Aussagen datenseitig gegengeprüft).

1. **KOMPOTYP-IDs — vollständig beantwortet (E-Mail Sauter, 2026-07-14):** 0 Gestein, 1 Zement, 2 Zusatzmittel, 3 Wasser, 4 Zusatzstoff, 5 Farbe, **6 Flugasche** (Tabelle heißt irreführend `KOMPO_FUELLER_FIRMA`!), 7 Fasern, 100 Undefiniert. Vollständiges Mapping: [QUELLSYSTEM_SAUTER.md](QUELLSYSTEM_SAUTER.md). Als **Referenzdatentabelle/Seed** pflegen, nicht hartkodieren. Die „Füller ↔ Zusatzstoff"-Abgrenzung ist damit erklärt: Typ 4 und 6 teilen sich die ZUSATZSTOFFART*-Referenz. Typ 6 = Flugasche erklärt zudem den k-Wert 0.4 exakt an Typ 1/6 (§6).
2. **Rezeptstamm & Preise — beantwortet:** Rezeptstamm ist **`stoffraum_basisdaten`** (Kopf, Ebene Firma: LABORID+FIRMENID+REZEPTID — verifiziert ✅) + **`stoffraum_komponenten`** (Positionen) — „mit diesen zwei Tabellen haben wir gewonnen". **`annahme_basis` ist für den GWP-Rechner irrelevant** (Prüf-/Annahmekontext). Relevante Preistabellen sind nur `kompo_preise` (werksbezogen, Herstellkosten) und `stoffraum_preise` (rezeptbezogen: Verkaufs-/Sonder-/Rabattpreise, gültig-ab) — **für GWP nicht benötigt**, optional später für Margen-Analysen.
3. **Soll- vs. Ist-Bilanzierung — beantwortet: beides.** GWP soll auf drei Ebenen berechenbar sein: Rezeptbasis (Soll), Chargen- und Lieferschein-/Baustellenbasis (Ist). Für die Ist-Berechnung ist **`import_lieferschein_dosierungen`** die zentrale Tabelle (Mengen je Material und Charge). Hierarchie: **Lieferschein → Charge → Dosierung → Komponente → EPD**; die unteren Ebenen erben die Schlüssel der oberen (LABORID, FIRMENID, WERKID, LIEFERSCHEINNUMMER, IDENTID, TEILREZEPTID, CHARGE — verifiziert ✅). Achtung: **Ein Lieferschein ≠ ein Rezept** (TEILREZEPTID; mehrere Chargen/Fertigteilproduktion).
4. **`ANRECHNUNGSFAKTOR` — weiter offen.** Neuer Datenpunkt: Das Feld existiert auch in `import_lieferschein_dosierungen`, dort direkt neben `KOMPONENTEISTFLUGASCHE` — stützt die k-Wert-Hypothese (Anrechnung von Zusatzstoffen wie Flugasche), von Sauter aber noch nicht bestätigt.

### 5. Weitere Erkenntnisse aus dem Fachgespräch (2026-07-14)

- **`kompo_komponentenverbund`: irrelevant → ignorieren.** Aktuell leer; dient der firmenübergreifenden Komponentenverwaltung und „Phantom-Komponenten" (BE/NL: ausgewiesener Zement ≠ dosierte Rohstoffe; in DE nicht zulässig). Damit ist das vermutete Doppelzählungsrisiko vom Tisch.
- **Mengenlogik `stoffraum_komponenten`:** `MENGE_ANTEIL` trägt je nach Komponententyp **absolute kg** (z. B. 320 kg Zement; `MASSE` dann leer) **oder Prozent** (z. B. Wasser 100 %, Fließmittel % vom Zementgehalt) — die berechnete Masse steht dann in `MASSE`. Werte `-1` bedeuten „nicht verwendet / wird berechnet". → Im Business Vault eine Spalte „effektive Menge" ableiten; Logik je Typ mit Testrezept validieren (empfohlenes Vorgehen: 2 Gesteine → +Zement → +Fließmittel → +Wasser).
- **Keine eigene Stoffraumberechnung nötig** — so die Aussage im Gespräch. *Die Datenprüfung (§6) relativiert das:* nur für Gestein (Typ 0) ist die berechnete MASSE persistiert; für %-Typen (Wasser, Zusatzmittel, Füller) muss die effektive Masse im Business Vault abgeleitet werden.
- **Lieferschein-Familie** (alle in `sources.yml` vorhanden ✅): `import_lieferscheine` (Kopf/„Deckel": Kunde, Baustelle, Fahrzeug, Auftrag, Rezeptdaten) → `import_lieferschein_chargen` (WZWERTSOLL/WZWERTIST, Wasserkorrektur, Temperaturen, Mischzeiten) → `import_lieferschein_dosierungen` (je Material; KOMPOTYP, SOLLMENGE, SOLLMENGE_REZEPT_*, FEUCHTE_*) → `import_lieferschein_events` (Ereignis-Doku); `import_lieferschein_pruefungen` für V1 nicht nötig.
- **EPD international:** Eine Komponente kann je Zielland unterschiedliche EPDs haben (DE/FR/BE/NL, in NL zusätzlich NKI) → Zuordnung **Komponente × Land × EPD** im Modell vorsehen.
- **Scope V1** (Workshop-Konsens): Organisation (Labor/Firma/Werk), Komponenten, Rezepte, Lieferscheine, Chargen, Dosierungen, Events, Referenzdaten, EPD-Anbindung, GWP-Berechnung. Optional/später: Preise, Kalkulation, Prüfungen.
- Die gelieferten Tabellen sind „Stand der Technik" — Arbeitsgrundlage bestätigt; Umsetzungsreihenfolge: **Komponenten → Rezepte → Vault-Entwurf → GWP-Berechnung → EPD-Anbindung**.

### 6. Datenprüfung gegen die dev-Datenbank (2026-07-14, read-only)

Alle Gesprächsaussagen wurden zusätzlich gegen die tatsächlichen Daten in `stg.ext_sauter_test_*` geprüft (Testdatenstand):

| Prüfung | Ergebnis |
|---|---|
| `kompo_komponentenverbund` leer? | ✅ 0 Zeilen — „ignorieren" bestätigt |
| `annahme_basis` irrelevant? | ✅ plausibel — nur 1 Zeile im Testbestand |
| BK `stoffraum_basisdaten` (LABORID+FIRMENID+REZEPTID) | ✅ eindeutig (26/26; schwache Evidenz, nach nächstem Load erneut prüfen) |
| KOMPOTYP-Wertebereich | ⚠️ beobachtet **0–6** (nicht 0–7); **4 und 5 nur in Dosierungen**, nicht im Stoffraum; 7 unbelegt |
| Mengenlogik | ⚠️ präzisiert: **Typ 0 (Gestein): MENGE_ANTEIL = −1, berechnete MASSE/VOLUMEN gefüllt. Typ 1/2/3/6: MENGE_ANTEIL trägt kg bzw. %, MASSE ist NULL** — die berechnete Masse wird für diese Typen *nicht* persistiert → für %-Typen (Wasser 100 %, Zusatzmittel % v. Zement, Füller) ist doch eine Ableitung im Business Vault nötig! „−1" als Sonderwert existiert nur in MENGE_ANTEIL; „nicht verwendet" bei MASSE ist NULL. |
| Ist-Menge in `_dosierungen` | **Hypothese:** `GESTEINMENGE` = Ist-Menge (bei *allen* KOMPOTYPen befüllt — Name täuscht); `SOLLMENGE_REZEPT_MASSE` = Rezept-Soll (trocken); `SOLLMENGE` = feuchtekorrigiertes Soll (`+ FEUCHTE_MASSE`, additiv exakt nachvollziehbar). Abweichungsmuster (Wiegetoleranz bei Gestein) passt. **→ Von Sauter bestätigen lassen!** |
| `ANRECHNUNGSFAKTOR` | 🔥 nur 3 Werte: **0.0 / 0.4 / 1.0**; 0.4 und 1.0 ausschließlich bei KOMPOTYP 1 und 6 — 0.4 ist der typische **Flugasche-k-Wert (EN 206)**, 1.0 voll anrechenbares Bindemittel → k-Wert-Hypothese stark gestützt |
| `KOMPONENTEISTFLUGASCHE` | ⚠️ Anomalie: Flag (696×) nicht deckungsgleich mit Faktor 0.4; kommt auch bei KOMPOTYP 3 (Wasser, 233×) vor → mit Sauter klären |
| Leere Tabellen | ⚠️ `import_lieferschein_events`: 0 Zeilen — fachlich leer oder ADF-Extraktionslücke? |
