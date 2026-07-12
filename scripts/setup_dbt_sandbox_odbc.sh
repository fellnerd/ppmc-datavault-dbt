#!/usr/bin/env bash
# Richtet den ODBC Driver 18 for SQL Server + dbt-sqlserver in einer
# root-losen Linux-Sandbox ein (z.B. Claude-Cowork-Sandbox), damit
# `dbt run-operation` / `dbt debug` gegen die Azure-SQL-DB laufen.
#
# Notwendig, weil die Sandbox pro Session frisch ist und kein `apt-get
# install` mit Root erlaubt. Der Treiber wird stattdessen als .deb
# heruntergeladen und mit `dpkg-deb -x` (kein Root nötig) nach
# $ODBC_ROOT entpackt.
#
# Verwendung:
#   source scripts/setup_dbt_sandbox_odbc.sh
# (mit `source`, damit die exportierten ENV-Variablen in der aktuellen
#  Shell erhalten bleiben — sonst gehen sie beim Skriptende verloren)
#
# Danach funktionieren z.B.:
#   dbt debug --target dev
#   dbt run-operation run_sql --args '{"sql": "SELECT TOP 5 * FROM stg.ext_sauter_test_firma_kunden"}' --target dev
#
# Voraussetzung: profiles.yml liegt unter $DBT_PROFILES_DIR (Default: /tmp/dbtprofile).

set -euo pipefail

ODBC_ROOT="${ODBC_ROOT:-/tmp/odbcroot}"
DEBS_DIR="${DEBS_DIR:-/tmp/odbc_debs}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-/tmp/dbtprofile}"

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in
  arm64|aarch64) DEB_ARCH="arm64" ;;
  amd64|x86_64)  DEB_ARCH="amd64" ;;
  *) echo "Unbekannte Architektur: $ARCH" >&2; exit 1 ;;
esac

MSODBCSQL_VERSION="${MSODBCSQL_VERSION:-18.6.2.1-1}"
MSODBCSQL_URL="https://packages.microsoft.com/ubuntu/22.04/prod/pool/main/m/msodbcsql18/msodbcsql18_${MSODBCSQL_VERSION}_${DEB_ARCH}.deb"

if [ -f "$ODBC_ROOT/.setup_complete" ]; then
  echo "[setup_dbt_sandbox_odbc] Bereits eingerichtet unter $ODBC_ROOT — überspringe Download/Extract."
else
  echo "[setup_dbt_sandbox_odbc] Richte ODBC Driver 18 ($DEB_ARCH) unter $ODBC_ROOT ein..."
  mkdir -p "$ODBC_ROOT" "$DEBS_DIR"

  # In Subshell isoliert (Skript wird per `source` eingebunden — ein `cd`
  # hier würde sonst auch das Arbeitsverzeichnis der aufrufenden Shell ändern).
  (
    cd "$DEBS_DIR"
    # unixODBC (Treiber-Manager) — Ubuntu-Paketspiegel, keine Root-Rechte nötig dank dpkg-deb -x
    apt-get download unixodbc unixodbc-common libodbc2 libodbcinst2 odbcinst 2>&1 | tail -5
    # Microsoft ODBC Driver 18 for SQL Server
    curl -fsSL -o msodbcsql18.deb "$MSODBCSQL_URL"
    for f in *.deb; do
      dpkg-deb -x "$f" "$ODBC_ROOT"
    done
  )

  # Nur reguläre Dateien (-type f), keine Symlinks: das .deb enthält unter
  # /usr/lib64/libmsodbcsql-18.so einen Symlink mit *absolutem* Zielpfad
  # (/opt/microsoft/...), der außerhalb von $ODBC_ROOT ins Leere zeigt.
  # Die echte, versionierte .so liegt unter opt/microsoft/msodbcsql18/lib64/.
  DRIVER_SO="$(find "$ODBC_ROOT/opt/microsoft" -type f -iname 'libmsodbcsql-18*.so*' | head -1)"
  if [ -z "$DRIVER_SO" ]; then
    echo "[setup_dbt_sandbox_odbc] FEHLER: Treiber-.so nicht gefunden nach Extraktion." >&2
    exit 1
  fi

  mkdir -p "$ODBC_ROOT/etc"
  cat > "$ODBC_ROOT/etc/odbcinst.ini" << EOF
[ODBC Driver 18 for SQL Server]
Description=Microsoft ODBC Driver 18 for SQL Server
Driver=$DRIVER_SO
UsageCount=1
EOF

  touch "$ODBC_ROOT/.setup_complete"
  echo "[setup_dbt_sandbox_odbc] Treiber-.so: $DRIVER_SO"
fi

# ODBC-Runtime-Libs (unixODBC) je nach Architektur im passenden Unterordner
ODBC_LIB_DIR="$(find "$ODBC_ROOT/usr/lib" -maxdepth 1 -type d -iname '*linux-gnu*' | head -1)"
DRIVER_LIB_DIR="$(dirname "$(find "$ODBC_ROOT/opt/microsoft" -type f -iname 'libmsodbcsql-18*.so*' | head -1)")"

export ODBCSYSINI="$ODBC_ROOT/etc"
export ODBCINI="$ODBC_ROOT/etc/odbc.ini"
export LD_LIBRARY_PATH="$ODBC_LIB_DIR:$DRIVER_LIB_DIR:${LD_LIBRARY_PATH:-}"
export PATH="$ODBC_ROOT/usr/bin:$PATH"

# Python-Pakete (User-Space, kein Root nötig)
pip3 install --break-system-packages -q dbt-sqlserver pyodbc 2>&1 | tail -5 || true
export PATH="$PATH:$HOME/.local/bin"

echo "[setup_dbt_sandbox_odbc] Fertig. Registrierte Treiber:"
odbcinst -q -d || true

echo ""
echo "[setup_dbt_sandbox_odbc] Nächster Schritt: profiles.yml nach \$DBT_PROFILES_DIR ($DBT_PROFILES_DIR) legen, dann:"
echo "  dbt debug --target dev"
