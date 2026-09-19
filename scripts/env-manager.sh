#!/usr/bin/env bash
# env-manager.sh — Gestão de variáveis globais (.env)
#
# Uso:
#   bash env-manager.sh list
#   bash env-manager.sh set <KEY> <VALUE>
#   bash env-manager.sh get <KEY>
#   bash env-manager.sh unset <KEY>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$TOOLKIT_ROOT/.env"

mkdir -p "$TOOLKIT_ROOT"
[[ ! -f "$ENV_FILE" ]] && touch "$ENV_FILE"

cmd="${1:-list}"
shift 2>/dev/null

case "$cmd" in
    list)
        if [[ ! -s "$ENV_FILE" ]]; then
            echo "Nenhuma variável definida."
            echo "Use: dev env-set <KEY> <VALUE>"
            exit 0
        fi
        printf "%-30s %s\n" "KEY" "VALUE"
        printf "%-30s %s\n" "------------------------------" "-----------------------------------"
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            # Remove aspas se houver
            value="${value%\"}"
            value="${value#\"}"
            printf "%-30s %s\n" "$key" "$value"
        done < "$ENV_FILE"
        ;;
    set)
        key="$1"
        value="$2"
        if [[ -z "$key" || -z "$value" ]]; then
            echo "Uso: dev env-set <KEY> <VALUE>"
            exit 1
        fi
        # Remove entrada existente
        sed -i "/^${key}=/d" "$ENV_FILE"
        # Adiciona nova entrada (valor sempre entre aspas para suportar espaços)
        echo "${key}=\"${value}\"" >> "$ENV_FILE"
        echo "[OK] ${key} definida"
        ;;
    get)
        key="$1"
        if [[ -z "$key" ]]; then
            echo "Uso: dev env-get <KEY>"
            exit 1
        fi
        value=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)
        value="${value%\"}"
        value="${value#\"}"
        if [[ -n "$value" ]]; then
            echo "$value"
        else
            echo "[INFO] Variável ${key} não encontrada"
            exit 1
        fi
        ;;
    unset)
        key="$1"
        if [[ -z "$key" ]]; then
            echo "Uso: dev env-unset <KEY>"
            exit 1
        fi
        if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
            sed -i "/^${key}=/d" "$ENV_FILE"
            echo "[OK] ${key} removida"
        else
            echo "[INFO] Variável ${key} não encontrada"
        fi
        ;;
    *)
        echo "Uso: dev env-{list|set|get|unset}"
        exit 1
        ;;
esac
