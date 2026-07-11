# Quellsystem Sauter — ER-Modell (Primärdaten)

> Quelle: ER-Diagramm „ER_Sauter" (Arbeitsstand). Beschreibt den **operativen Kernpfad** des Sauter-Labormodells für die GWP-Berechnung.
> **Validierungsstatus:** 18/18 Tabellen gegen die External Tables bestätigt → [ER_VALIDIERUNG_SAUTER.md](ER_VALIDIERUNG_SAUTER.md)
> Physisch angebunden sind **267 Tabellen** als `stg.ext_sauter_test_*` (siehe `models/staging/sources.yml`) — das ER dokumentiert davon den join-relevanten Ausschnitt.

## Operativer Kernpfad (belegt)

```
KOMMUNIKATION_EXTREZEPTBASIS ──(LABORID,FIRMENID,WERKID,REZEPTSORTE)──→ ANNAHME_BASIS
ANNAHME_BASIS.REZEPTID ────────────────────────────────────────────────→ STOFFRAUM_KOMPONENTEN
STOFFRAUM_KOMPONENTEN.(KOMPOTYP,KOMPOID) ──→ KOMPO_<TYP>_FIRMA (Stammdaten je Komponententyp)
(KOMPOTYP,KOMPOID,WERKID) ─────────────────→ KOMPO_PREISE
```

## Tabellen des Kernpfads

### Rezeptur-Pfad

| Tabelle | Schlüssel | Inhalt (ER-Ausschnitt) |
|---------|-----------|------------------------|
| `STAMM_FIRMA_WERKE` | PK: LABORID, FIRMENID, WERKID | Werke: NAME, KUERZEL, WERKTYP (+80 weitere Spalten) |
| `KOMMUNIKATION_EXTREZEPTBASIS` | PK: LFDNR; Kontext: LABORID, FIRMENID, WERKID, REZEPTSORTE | Extern kommunizierte Rezeptbasis: EXPOSITIONSKLASSE, FESTIGKEITSKLASSE, KONSISTENZ, GROESTKORN (+56) |
| `ANNAHME_BASIS` | Join: LABORID, FIRMENID, WERKID, REZEPTSORTE | Auflösung REZEPTSORTE → **REZEPTID**; real eine Prüf-/Annahmetabelle (ANNAHMEID, DRUCKFESTIGKEIT_FCK, …) |
| `STOFFRAUM_KOMPONENTEN` | Join: LABORID, FIRMENID, REZEPTID, KOMPOTYP, KOMPOID | **Rezeptur-Zusammensetzung**: DOSIERPOSITION, MENGE_ANTEIL, MASSE, VOLUMEN, FEUCHTE, ANRECHNUNGSFAKTOR |
| `KOMPO_KOMPONENTENVERBUND` | PK: LFDNR (vorläufig) | Komponente→Zielkomponente (KOMPOID → ZIELKOMPOID, ANTEIL) |
| `IMPORT_LIEFERSCHEINE` | PK: LFDNUMMER (peripher) | Lieferscheine: IDENTID, TEILREZEPTID, LSID — enthält zusätzlich **Ist-Mengen** je Stofftyp (ZUSCHLAGMENGE, BINDEMITTELMENGE, WASSERMENGE, …) |

### Komponenten-Stammdaten (je Typ eine Tabelle, gleiche Struktur)

Gemeinsame ER-Spalten: LIEFERANTENID, LIEFERANTENWERKID, BEZEICHNUNG, ARTIKELNUMMER, ARTIKELUNTERNUMMER + typspezifische Arten-ID. Real je ~165–227 Spalten, darunter GWP-relevant: **DICHTE, SCHUETTDICHTE, EIGENFEUCHTE**.

| KOMPOTYP | Tabelle | Schlüssel | Arten-FK |
|----------|---------|-----------|----------|
| 0 = Zuschlag | `KOMPO_ZUSCHLAG_FIRMA` | LABORID, FIRMENID, ZUSCHLAGID | ZUSCHLAGARTENID → `STAMM_ZUSCHLAGARTEN` |
| 1 = Bindemittel | `KOMPO_BINDEMITTEL_FIRMA` | LABORID, FIRMENID, BINDEMITTELID | BINDEMITTELARTENID → `STAMM_BINDEMITTELARTEN` (**Key dort: ZEMENTARTENID!**) |
| 2 = Zusatzmittel | `KOMPO_ZUSATZMITTEL_FIRMA` | LABORID, FIRMENID, ZUSATZMITTELID | ZUSATZMITTELARTENID → `STAMM_ZUSATZMITTELARTEN` |
| 3 = Wasser | `KOMPO_WASSER_FIRMA` | LABORID, FIRMENID, WASSERID | WASSERARTENID → `STAMM_WASSERARTEN` |
| 6 = Füller | `KOMPO_FUELLER_FIRMA` | LABORID, FIRMENID, FUELLERID | ZUSATZSTOFFARTID → `STAMM_ZUSATZSTOFFARTEN` |
| ? | `KOMPO_FARBE_FIRMA`, `KOMPO_FASERN_FIRMA`, `KOMPO_ZUSATZSTOFF_FIRMA` | — | **nicht im ER — KOMPOTYP-IDs mit Fachbereich klären!** |

### Preise & Lieferanten

| Tabelle | Schlüssel | Inhalt |
|---------|-----------|--------|
| `KOMPO_PREISE` | Join: LABORID, FIRMENID, WERKID, KOMPOTYP, KOMPOID | PREIS (werksspezifisch) — Abgrenzung zu `STOFFRAUM_PREISE`/`REZEPT_PREISE` offen |
| `STAMM_LIEFERANTENWERK` | Join: LABORID, LIEFERANTENID, LIEFERANTENWERKID | FIRMENNAME (+18 Adress-/Kontaktspalten) |

### Arten-Stammdaten (Referenztabellen)

`STAMM_ZUSCHLAGARTEN`, `STAMM_BINDEMITTELARTEN` (Key: **ZEMENTARTENID**), `STAMM_ZUSATZMITTELARTEN`, `STAMM_WASSERARTEN`, `STAMM_ZUSATZSTOFFARTEN` — jeweils LABORID + Arten-ID → BEZEICHNUNG.

## Sonderfälle & Fallstricke

1. **Bindemittel-Artlogik über `ZEMENTARTENID`:** `KOMPO_BINDEMITTEL_FIRMA.BINDEMITTELARTENID` joint auf `STAMM_BINDEMITTELARTEN.ZEMENTARTENID` (nicht namensgleich!). Validiert ✅
2. **KOMPOTYP ist der Diskriminator** über die Stammtabellen; Liste 0/1/2/3/6 laut Validierung **unvollständig** (Farbe/Fasern/Zusatzstoff existieren).
3. **Mandantenschlüssel überall:** LABORID (+ meist FIRMENID) ist Teil jedes Schlüssels — muss in jeden Business Key.
4. **ANNAHME_BASIS** ist die Brücke REZEPTSORTE → REZEPTID, im ER als „vorläufig" markiert; ggf. `REZEPT_WERKZUWEISUNG` als Alternative prüfen.
5. **`IMPORT_LIEFERSCHEINE` / `KOMPO_KOMPONENTENVERBUND`** sind als „peripher/vorläufig" markiert — nicht im ersten Wurf modellieren. Lieferscheine werden aber relevant, sobald **Ist-Chargen** statt Soll-Rezepturen bilanziert werden.
