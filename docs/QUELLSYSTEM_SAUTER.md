# Quellsystem Sauter — ER-Modell (Primärdaten)

> Quelle: ER-Diagramm „ER_Sauter" (Arbeitsstand). Beschreibt den **operativen Kernpfad** des Sauter-Labormodells für die GWP-Berechnung.
> **Validierungsstatus:** 18/18 Tabellen gegen die External Tables bestätigt → [ER_VALIDIERUNG_SAUTER.md](ER_VALIDIERUNG_SAUTER.md)
> Physisch angebunden sind **267 Tabellen** als `stg.ext_sauter_test_*` (siehe `models/staging/sources.yml`) — das ER dokumentiert davon den join-relevanten Ausschnitt.

## ⚠️ Revision durch Fachgespräch (2026-07-14)

Das Fachgespräch mit Sauter hat den Kernpfad **verändert** (Details: [ER_VALIDIERUNG_SAUTER.md](ER_VALIDIERUNG_SAUTER.md) §4/§5):

```
Rezeptstamm (Soll):   STOFFRAUM_BASISDATEN (Kopf; LABORID+FIRMENID+REZEPTID)
                        └─→ STOFFRAUM_KOMPONENTEN (Positionen; KOMPOTYP+KOMPOID → KOMPO_<TYP>_FIRMA)
Produktion (Ist):     IMPORT_LIEFERSCHEINE (Kopf: Kunde, Baustelle, Auftrag)
                        └─→ IMPORT_LIEFERSCHEIN_CHARGEN (WZWERT SOLL/IST, Wasserkorrektur, …)
                              └─→ IMPORT_LIEFERSCHEIN_DOSIERUNGEN (Mengen je Material — GWP-Kern für Ist)
                                    └─→ Komponente → EPD (je Zielland!)
```

- **`ANNAHME_BASIS` und der Pfad über `KOMMUNIKATION_EXTREZEPTBASIS`/REZEPTSORTE sind für den GWP-Rechner irrelevant** (Prüf-/Annahmekontext) — das untenstehende ER bleibt als historische Join-Pfad-Doku erhalten.
- **`KOMPO_KOMPONENTENVERBUND`: ignorieren** (leer; Firmen-Verbund/Phantom-Komponenten).
- Untere Import-Ebenen erben die Schlüssel der oberen (LABORID, FIRMENID, WERKID, LIEFERSCHEINNUMMER, IDENTID, TEILREZEPTID, CHARGE). **Ein Lieferschein ≠ ein Rezept** (TEILREZEPTID).

## Operativer Kernpfad laut ER-Diagramm (historisch, durch Revision überholt)

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

Offizielle KOMPOTYP-Konstanten aus dem Sauter-Quellcode (erhalten 2026-07-14) — **Achtung: Typ 6 heißt intern Flugasche, die Tabelle aber `KOMPO_FUELLER_FIRMA`**:

| KOMPOTYP | Konstante | Tabelle | Schlüssel | Arten-FK |
|----------|-----------|---------|-----------|----------|
| 0 | cBinGestein | `KOMPO_ZUSCHLAG_FIRMA` | LABORID, FIRMENID, ZUSCHLAGID | ZUSCHLAGARTENID → `STAMM_ZUSCHLAGARTEN` |
| 1 | cBinZement | `KOMPO_BINDEMITTEL_FIRMA` | LABORID, FIRMENID, BINDEMITTELID | BINDEMITTELARTENID → `STAMM_BINDEMITTELARTEN` (**Key dort: ZEMENTARTENID!**) |
| 2 | cBinZusatzmittel | `KOMPO_ZUSATZMITTEL_FIRMA` | LABORID, FIRMENID, ZUSATZMITTELID | ZUSATZMITTELARTENID → `STAMM_ZUSATZMITTELARTEN` |
| 3 | cBinWasser | `KOMPO_WASSER_FIRMA` | LABORID, FIRMENID, WASSERID | WASSERARTENID → `STAMM_WASSERARTEN` |
| 4 | cBinZusatzstoff | `KOMPO_ZUSATZSTOFF_FIRMA` | LABORID, FIRMENID, … | ZUSATZSTOFFART* → `STAMM_ZUSATZSTOFFARTEN` |
| 5 | cBinFarbe | `KOMPO_FARBE_FIRMA` | LABORID, FIRMENID, … | — |
| 6 | cBinFlugasche | `KOMPO_FUELLER_FIRMA` | LABORID, FIRMENID, FUELLERID | ZUSATZSTOFFARTID → `STAMM_ZUSATZSTOFFARTEN` |
| 7 | cBinFasern | `KOMPO_FASERN_FIRMA` | LABORID, FIRMENID, … | — |
| 100 | cBinUndefiniert | — | — | — |

GWP-Einordnung: Typ 6 (Flugasche) erklärt den ANRECHNUNGSFAKTOR 0.4 (k-Wert EN 206, nur bei Typ 1/6 beobachtet). Typ 4/6 teilen sich die ZUSATZSTOFFART*-Referenz — das war die frühere „Füller ↔ Zusatzstoff"-Verwirrung.

### Preise & Lieferanten

| Tabelle | Schlüssel | Inhalt |
|---------|-----------|--------|
| `KOMPO_PREISE` | Join: LABORID, FIRMENID, WERKID, KOMPOTYP, KOMPOID | PREIS (werksspezifisch) — Abgrenzung zu `STOFFRAUM_PREISE`/`REZEPT_PREISE` offen |
| `STAMM_LIEFERANTENWERK` | Join: LABORID, LIEFERANTENID, LIEFERANTENWERKID | FIRMENNAME (+18 Adress-/Kontaktspalten) |

### Arten-Stammdaten (Referenztabellen)

`STAMM_ZUSCHLAGARTEN`, `STAMM_BINDEMITTELARTEN` (Key: **ZEMENTARTENID**), `STAMM_ZUSATZMITTELARTEN`, `STAMM_WASSERARTEN`, `STAMM_ZUSATZSTOFFARTEN` — jeweils LABORID + Arten-ID → BEZEICHNUNG.

## Sonderfälle & Fallstricke

1. **Bindemittel-Artlogik über `ZEMENTARTENID`:** `KOMPO_BINDEMITTEL_FIRMA.BINDEMITTELARTENID` joint auf `STAMM_BINDEMITTELARTEN.ZEMENTARTENID` (nicht namensgleich!). Validiert ✅
2. **KOMPOTYP ist der Diskriminator** über die Stammtabellen; offizielle Konstanten liegen vor (0–7 + 100 Undefiniert, Tabelle oben) → als Referenzdaten-Seed (`ref_kompotyp`) pflegen. **Typ 6 = Flugasche** (Tabelle heißt irreführend FUELLER).
3. **Mandantenschlüssel überall:** LABORID (+ meist FIRMENID) ist Teil jedes Schlüssels — muss in jeden Business Key.
4. **Mengenlogik `STOFFRAUM_KOMPONENTEN`:** `MENGE_ANTEIL` = absolute kg **oder** Prozent (typabhängig, z. B. Fließmittel % vom Zement); berechnete Masse steht in `MASSE`; `-1` = nicht verwendet/wird berechnet → „effektive Menge" im Business Vault ableiten.
5. ~~ANNAHME_BASIS als Brücke~~ **Überholt (2026-07-14):** `ANNAHME_BASIS` ist für den GWP-Rechner irrelevant; Rezeptstamm ist `STOFFRAUM_BASISDATEN`. `KOMPO_KOMPONENTENVERBUND` ignorieren. Ist-Bilanzierung läuft über die Lieferschein-Familie (`IMPORT_LIEFERSCHEIN_DOSIERUNGEN` als GWP-Kern).
