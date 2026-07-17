# Checkliste: OAuth Device-Code-Flow — Beweis-Test im ppmc-Tenant

> Zweck: In unserem eigenen Tenant (ppmcag.com) sauber nachweisen, dass der Qlik-OAuth-Login zu Azure SQL fehlerfrei durchläuft. Bricht er beim Kunden ab, ist es damit belegbar eine Tenant-Policy-Frage (Conditional Access) beim Kunden — nicht eine Qlik- oder Konfigurationslimitierung.

## Voraussetzungen (bereits erledigt, 2026-07-13)

- [x] App-Registrierung `qlik-synapse-prod` angelegt (AppId `f94334dc-ed28-453e-9b31-37b98326cf09`)
- [x] Redirect-URI `https://connector.qlik.com/auth/oauth/v2.htm` gesetzt
- [x] API-Berechtigung `app_impersonation` auf Azure SQL Database, Admin-Consent erteilt
- [x] Manifest `requestedAccessTokenVersion: 2` gesetzt
- [x] Manifest `groupMembershipClaims: SecurityGroup` gesetzt
- [x] Client Secret erzeugt
- [x] Legacy Token-Lifetime-Policies geprüft — keine im Tenant, keine auf der App (sauber)
- [x] Entra-Gruppen `sg-ppmc-datavault-ro/-rw/-owner` angelegt und in `datavault-dev` als External Provider User registriert
- [x] AAD-Admin auf `ppmcag-datavault` korrekt gesetzt (`sg-ppmc-datavault-owner`)

## Offen — noch zu prüfen

- [ ] Conditional-Access-Policies im ppmc-Tenant selbst verifizieren (Entra ID → Security → Conditional Access → Policies) — insbesondere "Authentication flows" (Device code: Configure Yes/No) und "Session controls → Sign-in frequency". **Blocker:** Daniels aktueller `az`-Login hat dafür keine ausreichende Rolle (Security Reader/Conditional Access Administrator/Global Reader nötig, ggf. PIM-Aktivierung erforderlich) — offener Punkt aus der Session vom 2026-07-13.

## Testablauf

1. Qlik-Sense-App öffnen → Dateneditor → Datenverbindungen → bestehende `Azure SQL Database`-Verbindung (OAuth) auswählen oder neu erstellen.
2. Auf **„Authenticate"** klicken.
3. **Startzeit notieren** (Uhrzeit, auf die Sekunde).
4. Microsoft-Login-Seite: Konto auswählen, ggf. MFA bestätigen.
5. Auf der `connector.qlik.com`-Seite erscheint der **Authentication Code** — **Zeitpunkt notieren**, an dem der Code angezeigt wird.
6. Code kopieren, zurück zum Qlik-Verbindungsdialog wechseln, in das **„Verify"-Feld** einfügen, **Verify** klicken.
7. **Endzeit notieren**, sobald „Authenticated succesfully" angezeigt wird.
8. **Verstrichene Zeit berechnen** (Endzeit − Startzeit).

## Erwartungswert

- Der Code selbst ist laut Entra-ID-Standard **~15 Minuten (900s)** gültig (`expires_in`) — das ist eine Microsoft-Vorgabe, kein Qlik-Verhalten.
- Läuft der komplette Ablauf (Schritt 2–7) **ohne Abbruch** durch, unabhängig davon ob es 30 Sekunden oder mehrere Minuten dauert, ist das der Beweis: **kein Conditional-Access-Block** in einem "sauberen" Tenant.

## Wenn's beim Kunden abbricht — präzise Frage an den IT-Dienstleister

> „Ist bei euch unter Conditional Access eine Policy aktiv, die
> (a) **Authentication flows → Device code flow** blockt, oder
> (b) eine kurze **Sign-in Frequency / Session Lifetime** erzwingt,
> die eine Re-Authentifizierung mitten im Device-Code-Verify-Vorgang auslöst?"

Das ist präziser als „es geht nicht" — beide Policies landen unter **Entra ID → Security → Conditional Access → Policies**.

## Zusätzlich, falls CA nicht die Ursache ist

- [ ] Prüfen, ob beim Kunden alte **Token Lifetime Policies** (legacy, nur per Graph/PowerShell sichtbar, nicht im Portal) auf der dortigen App-Registrierung hängen — bekannte zweite Quelle für ungewöhnlich kurze Token-Laufzeiten.

## Quellen

- [Authentication flows as a condition in Conditional Access policy](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-condition-filters-for-devices)
- [Conditional Access adaptive session lifetime policies](https://learn.microsoft.com/en-us/entra/identity/conditional-access/howto-conditional-access-session-lifetime)
- [Block authentication flows with Conditional Access policy](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-block-authentication-flows)
- [Microsoft Entra authentication & authorization error codes](https://learn.microsoft.com/en-us/entra/identity-platform/reference-error-codes)
