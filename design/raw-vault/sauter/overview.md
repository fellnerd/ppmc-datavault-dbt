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

## Offene Modellierungsfragen (vor Implementierung klären)

1. Ist REZEPTID über FIRMENID hinweg eindeutig oder gehört WERKID in den BK?
2. Granularität annahme_basis: 1 REZEPTSORTE → n REZEPTIDs über Zeit? (Eff-Sat am Link?) `rezept_werkzuweisung` als Alternative prüfen.
3. KOMPOTYP-IDs für kompo_farbe/fasern/zusatzstoff_firma (siehe Validierung).
4. Führende Preistabelle: kompo_preise vs. stoffraum_preise vs. rezept_preise.
5. Soll- (stoffraum_komponenten) vs. Ist-Bilanzierung (import_lieferscheine mit Ist-Mengen) als Mengenbasis.
6. Energie-/Transportdaten für Module A2/A3 — Quelle im Sauter-Bestand identifizieren.
