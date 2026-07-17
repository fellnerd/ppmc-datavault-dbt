# Tasks

> Abgeleitet aus dem Projektplan „BMI – Architektur 2.0" (Stand 02.07.2026) und der ER-Validierung vom 2026-07-11.

## Phase 1 — Fachliche Abstimmung

- [ ] Workshops mit ASCEM: relevante PCR-Anforderungen festlegen
- [x] Offene Quellsystem-Fragen mit Sauter klären → [docs/ER_VALIDIERUNG_SAUTER.md](docs/ER_VALIDIERUNG_SAUTER.md) §4/§5 (Fachgespräch 2026-07-14):
  - [x] KOMPOTYP-IDs: offizielle Konstanten erhalten (0–7 + 100; **6 = Flugasche**, Tabelle KOMPO_FUELLER!) → ref_kompotyp-Seed
  - [x] Führende Preistabelle: kompo_preise + stoffraum_preise — für GWP nicht benötigt
  - [x] Rezeptstamm: **stoffraum_basisdaten** + stoffraum_komponenten; annahme_basis irrelevant
  - [x] Soll- vs. Ist-Bilanzierung: beides — Ist über import_lieferschein_dosierungen
  - [ ] Bedeutung ANRECHNUNGSFAKTOR für die GWP-Formel (k-Wert-Hypothese, unbestätigt)
- [ ] Zugang millieudatabase.nl (REST API) organisieren

## Phase 2 — Prototyp (PoC)

- [x] Sauter External Tables (267, Landing Zone `sauter-test/`)
- [x] ER-Modell gegen External Tables validieren (18/18 OK)
- [ ] Design-Review [design/raw-vault/sauter/overview.md](design/raw-vault/sauter/overview.md) mit Fachbereich
- [ ] Staging Views Kernpfad (`stg_sauter_*`) — Spaltenauswahl bewusst (DICHTE etc. mitnehmen)
- [ ] Kern-Hubs: hub_werk, hub_rezept, hub_rezeptbasis, hub_komponente (Multi-Source!), hub_lieferantenwerk
- [ ] Links + Sats: link_rezept_komponente + sat_stoffraum (Herzstück), sat_komponente_* je Typ
- [ ] Refs: ref_*arten Views + ref_kompotyp Seed
- [ ] EPD-Adapter millieudatabase.nl → hub_epd_material + sat_epd_material__nmd
- [ ] Material-Matching v1 (regelbasiert) → link_komponente_epd + Eff-Sat
- [ ] Mart: v_rezept_zusammensetzung, v_rezept_gwp (A1–A3) für typische Rezepturen
- [ ] Plausibilitätsprüfungen als dbt-Tests (Mengensummen, funktionale Einheit)

## Phase 3 — Erweiterung

- [ ] Weitere EPD-Quellen (ÖKOBAUDAT, baubook) als zusätzliche Record Sources/Sats
- [ ] Energie- & Transportdaten (Module A2/A3 vollständig)
- [ ] Ist-Bilanzierung über import_lieferscheine (+ _chargen, _dosierungen)
- [ ] Weitere europäische Länder

## Phase 4 — Betrieb & Go-to-market

- [ ] Normkonformitäts-Dokumentation (ISO 14067, EN 15804, PCR)
- [ ] Compliance-/Audit-Marts
- [ ] CI/CD & Betriebsübergabe
