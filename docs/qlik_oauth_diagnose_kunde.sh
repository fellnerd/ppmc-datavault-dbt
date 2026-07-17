#!/bin/bash
# Diagnose-Skript: Qlik OAuth <-> Azure SQL Verbindung
# Rein lesend (read-only) - aendert nichts an der Konfiguration.
# Bitte die Variablen unten ausfuellen und dann das ganze Skript ausfuehren.
# Die komplette Ausgabe bitte kopieren und zurueckschicken.

# ============ BITTE AUSFUELLEN ============
CLIENT_ID=""          # Application (client) ID der App-Registrierung, z.B. f94334dc-...
RESOURCE_GROUP=""     # Resource Group des SQL Servers, z.B. rg-datavault-001
SQL_SERVER_NAME=""    # Name des SQL Servers ohne .database.windows.net, z.B. ppmcag-datavault
SUBSCRIPTION_ID=""    # Optional: nur ausfuellen, falls mehrere Subscriptions im Tenant vorhanden sind
# ===========================================

set -e

if [ -n "$SUBSCRIPTION_ID" ]; then
  az account set --subscription "$SUBSCRIPTION_ID"
fi

echo "=================================================="
echo "0. Aktuell angemeldetes Konto / Tenant"
echo "=================================================="
az account show --query "{user:user.name, tenantId:tenantId, tenantDomain:tenantDefaultDomain}" -o json

APP_OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query "id" -o tsv)
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query "id" -o tsv 2>/dev/null || echo "NICHT_GEFUNDEN")

echo ""
echo "App Object ID: $APP_OBJECT_ID"
echo "Service Principal Object ID: $SP_OBJECT_ID"

echo ""
echo "=================================================="
echo "1. App-Registrierung: Grunddaten (Redirect URI, Manifest)"
echo "=================================================="
az ad app show --id "$CLIENT_ID" --query "{name:displayName, redirectUris:web.redirectUris, tokenVersion:api.requestedAccessTokenVersion, groupClaims:groupMembershipClaims}" -o json

echo ""
echo "=================================================="
echo "2. API-Berechtigungen (Application=Role vs. Delegated=Scope)"
echo "=================================================="
az ad app permission list --id "$CLIENT_ID" -o json

echo ""
echo "=================================================="
echo "3. Application-Consent (appRoleAssignments) - fuer 'Role'-Typ Berechtigungen"
echo "=================================================="
if [ "$SP_OBJECT_ID" != "NICHT_GEFUNDEN" ]; then
  az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" -o json
else
  echo "Service Principal existiert nicht (siehe oben) - kein Application-Consent moeglich."
fi

echo ""
echo "=================================================="
echo "4. Delegierter Consent (oauth2PermissionGrants) - fuer 'Scope'-Typ Berechtigungen"
echo "=================================================="
if [ "$SP_OBJECT_ID" != "NICHT_GEFUNDEN" ]; then
  az rest --method GET --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '$SP_OBJECT_ID'" -o json
else
  echo "Service Principal existiert nicht - kein delegierter Consent moeglich."
fi

echo ""
echo "=================================================="
echo "5. Legacy Token Lifetime Policies (tenant-weit)"
echo "=================================================="
az rest --method GET --url "https://graph.microsoft.com/v1.0/policies/tokenLifetimePolicies" -o json

echo ""
echo "=================================================="
echo "6. Legacy Token Lifetime Policies (auf dieser App)"
echo "=================================================="
az rest --method GET --url "https://graph.microsoft.com/v1.0/applications/$APP_OBJECT_ID/tokenLifetimePolicies" -o json

echo ""
echo "=================================================="
echo "7. Conditional Access Policies (braucht ggf. zusaetzliche Rolle)"
echo "=================================================="
az rest --method GET --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" --query "value[].{name:displayName, state:state}" -o table \
  || echo "FEHLER: Fehlende Berechtigung (Security Reader / Conditional Access Administrator / Global Reader noetig). Bitte manuell im Portal pruefen: Entra ID -> Security -> Conditional Access -> Policies"

echo ""
echo "=================================================="
echo "8. AAD-Admin auf dem SQL Server"
echo "=================================================="
az sql server ad-admin list --resource-group "$RESOURCE_GROUP" --server "$SQL_SERVER_NAME" -o json

echo ""
echo "=================================================="
echo "FERTIG. Bitte die komplette Ausgabe (von oben bis hier) kopieren und zurueckschicken."
echo "=================================================="
