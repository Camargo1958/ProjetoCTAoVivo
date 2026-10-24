#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-DEFAULT}"
APP_NAME="minha-torre"
WAREHOUSE_ID="${DATABRICKS_WAREHOUSE_ID:-810afaae3be2f88c}"

APP_JSON="$(databricks apps get "$APP_NAME" --profile "$PROFILE" -o json)"
SERVICE_PRINCIPAL_CLIENT_ID="$(printf '%s\n' "$APP_JSON" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("service_principal_client_id") or data.get("servicePrincipalClientId") or "")')"

if [[ -z "$SERVICE_PRINCIPAL_CLIENT_ID" ]]; then
  echo "Não foi possível resolver o service principal do app $APP_NAME." >&2
  exit 1
fi

echo "Service principal: $SERVICE_PRINCIPAL_CLIENT_ID"

echo "Atribuindo acesso ao catálogo e schemas do lakehouse_vertice..."

grant() {
  databricks experimental aitools tools query \
    --profile "$PROFILE" \
    --warehouse "$WAREHOUSE_ID" \
    "GRANT $1 TO \`$SERVICE_PRINCIPAL_CLIENT_ID\`"
}

grant "USE CATALOG ON CATALOG lakehouse_vertice"
grant "USE SCHEMA ON SCHEMA lakehouse_vertice.silver"
grant "USE SCHEMA ON SCHEMA lakehouse_vertice.gold"
grant "SELECT ON SCHEMA lakehouse_vertice.silver"
grant "SELECT ON SCHEMA lakehouse_vertice.gold"

echo "Permissões concedidas."