# Raw Vault Design: Sauter (Primärdaten)

> Zielmodell für Schema `vault_sauter` — Entwurf vor Phase 2 (Prototyp).
> Grundlage: [docs/QUELLSYSTEM_SAUTER.md](../../../docs/QUELLSYSTEM_SAUTER.md), validiert gegen die External Tables ([docs/ER_VALIDIERUNG_SAUTER.md](../../../docs/ER_VALIDIERUNG_SAUTER.md)).
> ERD: [er-diagram.mmd](er-diagram.mmd)

## Hubs

| Hub | Business Key (Composite) | Quelle(n) |
|-----|--------------------------|-----------|
| `hub_werk` | laborid ‖ firmenid ‖ werkid | stamm_firma_werke |
| `hub_rezept` | laborid ‖ firmenid ‖ rezeptid | annahme_basis / stoffraum_komponenten |
| `hub_rezeptbasis` | laborid ‖ firmenid ‖ werkid ‖ rezeptsorte | kommunikation_extrezeptbasis |
| `hub_komponente` | laborid ‖ firmenid ‖ kompotyp ‖ kompoid | kompo_*_firma (**Multi-Source**, KOMPOID aus ZUSCHLAGID/BINDEMITTELID/… aliasieren) |
| `hub_lieferantenwerk` | laborid ‖ lieferantenid ‖ lieferantenwerkid | stamm_lieferantenwerk |

Für die EPD-Seite (Sekundärdaten) folgt später `vault_epd`: `hub_epd_material` (BK: epd_quelle ‖ epd_id) + `sat_epd_material__nmd` (gwp_a1/a2/a3, Einheit, Version, Provenance).

## Links

| Link | Verbindet | Quelle | Kontext-Sat |
|------|-----------|--------|-------------|
| `link_rezeptbasis_rezept` | rezeptbasis ↔ rezept | annahme_basis | — |
| `link_rezept_komponente` | rezept ↔ komponente | stoffraum_komponenten | `sat_stoffraum` (dosierposition, menge_anteil, masse, volumen, feuchte, anrechnungsfaktor) |
| `link_werk_komponente_preis` | werk ↔ komponente | kompo_preise | `sat_preis` (preis) |
| `link_komponente_lieferantenwerk` | komponente ↔ lieferantenwerk | kompo_*_firma | — |
| `link_komponente_epd` | komponente ↔ epd_material | **Material-Matching** (Business Vault, regelbasiert) | Eff-Sat: Gültigkeit, Regel, Konfidenz |

`link_rezept_komponente` + `sat_stoffraum` ist das Herzstück: liefert Mengeᵢ für `GWP_m³ = Σ (Mengeᵢ × GWPᵢ)`; `link_komponente_epd` liefert GWPᵢ.

## Satellites

| Satellite | An | Attribute (Auswahl — Spaltenauswahl bewusst treffen, Quellen haben 165–227 Spalten!) |
|-----------|----|----|
| `sat_werk` | hub_werk | name, kuerzel, werktyp |
| `sat_rezeptbasis` | hub_rezeptbasis | expositionsklasse, festigkeitsklasse, konsistenz, groestkorn |
| `sat_komponente_zuschlag` | hub_komponente | bezeichnung, artikelnummer, zuschlagartenid, **dichte, schuettdichte, eigenfeuchte** |
| `sat_komponente_bindemittel` | hub_komponente | … + bindemittelartenid (**joint auf ZEMENTARTENID!**), dichte |
| `sat_komponente_zusatzmittel` | hub_komponente | … + zusatzmittelartenid, dichte |
| `sat_komponente_wasser` | hub_komponente | … + wasserartenid |
| `sat_komponente_fueller` | hub_komponente | … + zusatzstoffartid, dichte |
| `sat_lieferantenwerk` | hub_lieferantenwerk | firmenname |

Ein Satellite **pro Quelltabelle** am gemeinsamen `hub_komponente` (Split by source) — kein Über-Satellite.

## Reference Tables

`ref_zuschlagarten`, `ref_bindemittelarten` (Key: ZEMENTARTENID), `ref_zusatzmittelarten`, `ref_wasserarten`, `ref_zusatzstoffarten` aus `stamm_*arten`; `ref_kompotyp` als Seed (0 Zuschlag, 1 Bindemittel, 2 Zusatzmittel, 3 Wasser, 6 Füller — **erweitern nach Klärung Farbe/Fasern/Zusatzstoff**).

## ⚠️ Workshop-Input (2026-07-14) — Design-Review ausstehend

Das Fachgespräch mit Sauter ändert die Modellgrundlage ([docs/ER_VALIDIERUNG_SAUTER.md](../../../docs/ER_VALIDIERUNG_SAUTER.md) §4/§5). Vor der Implementierung dieses Entwurfs einarbeiten:

- **`hub_rezeptbasis` und der annahme_basis-Pfad entfallen** — Rezeptstamm ist `stoffraum_basisdaten` (BK: laborid ‖ firmenid ‖ rezeptid); `hub_rezept` speist sich daraus statt aus annahme_basis.
- **`link_rezeptbasis_rezept` entfällt**, ebenso die komponentenverbund-Überlegungen (Tabelle ignorieren).
- **Neue Objekte für die Ist-Seite** (Workshop-Hub-Liste): hub_kunde, hub_baustelle, hub_lieferschein, hub_charge + Links Lieferschein→Charge→Dosierung (Dosierung als Link/Transaktions-Link mit sat: sollmenge, feuchte, wasserkorrektur, …). Schlüsselvererbung: LABORID, FIRMENID, WERKID, LIEFERSCHEINNUMMER, IDENTID, TEILREZEPTID, CHARGE.
- **EPD je Zielland:** `link_komponente_epd` bekommt eine Land-Dimension (Komponente × Land × EPD).
- **`ref_kompotyp`** (Liste liegt vor, 2026-07-14): 0 Gestein, 1 Zement, 2 Zusatzmittel, 3 Wasser, 4 Zusatzstoff, 5 Farbe, **6 Flugasche** (Tabelle: kompo_fueller_firma!), 7 Fasern, 100 Undefiniert — als Seed anlegen.
- **Business-Vault-Regel „effektive Menge":** MENGE_ANTEIL (kg oder %, typabhängig) mit MASSE zusammenführen; `-1` = nicht verwendet/berechnet.
- **Preise (kompo_preise, stoffraum_preise) raus aus V1-Scope** — Modell offen halten (späterer eigener Hub/Sat, nichts Bestehendes ändern).

## Offene Modellierungsfragen (vor Implementierung klären)

1. Ist REZEPTID über FIRMENID hinweg eindeutig oder gehört WERKID in den BK? *(stoffraum_basisdaten hat kein WERKID — Ebene Firma; spricht für BK ohne WERKID)*
2. ~~Granularität annahme_basis~~ **erledigt: annahme_basis irrelevant (2026-07-14).**
3. ~~KOMPOTYP-IDs vollständige Liste~~ **erledigt: offizielle Konstanten erhalten (2026-07-14), siehe Workshop-Input oben.**
4. ~~Führende Preistabelle~~ **erledigt: kompo_preise + stoffraum_preise, beide für GWP nicht nötig (2026-07-14).**
5. ~~Soll- vs. Ist-Bilanzierung~~ **erledigt: beides — Soll aus stoffraum_*, Ist aus import_lieferschein_dosierungen (2026-07-14).**
6. Energie-/Transportdaten für Module A2/A3 — Quelle im Sauter-Bestand identifizieren.
7. Bedeutung ANRECHNUNGSFAKTOR — **k-Wert-Hypothese durch Daten stark gestützt** (nur 0.0/0.4/1.0; 0.4 = Flugasche-k-Wert EN 206, nur bei Typ 1/6) — finale Bestätigung durch Sauter offen.
8. Ist-Menge in `import_lieferschein_dosierungen`: **Datenprüfung 2026-07-14 → Hypothese: GESTEINMENGE = Ist** (bei allen Typen befüllt), SOLLMENGE = feuchtekorrigiertes Soll, SOLLMENGE_REZEPT_MASSE = Rezept-Soll — von Sauter bestätigen lassen.
9. KOMPONENTEISTFLUGASCHE-Anomalie: Flag auch bei Wasser-Zeilen (Typ 3) und nicht deckungsgleich mit Faktor 0.4 — mit Sauter klären.
10. ~~KOMPOTYP 4/5 klären~~ **erledigt: 4 = Zusatzstoff, 5 = Farbe (offizielle Konstanten); 7 = Fasern, im Testbestand schlicht nicht vorhanden.**
11. Effektive-Menge-Ableitung im Business Vault: MASSE ist nur bei Typ 0 persistiert; %-Typen (Wasser 100 %, Zusatzmittel % v. Zement, Füller) müssen berechnet werden.
