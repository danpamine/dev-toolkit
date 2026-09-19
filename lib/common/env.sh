#!/usr/bin/env bash
# ==============================================================================
# env.sh - Resolução de Variáveis de Ambiente e Caminhos Configuráveis
# ==============================================================================

TOOLKIT_ROOT="${TOOLKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TOOLKIT_ROOT="${TOOLKIT_ROOT%$'\r'}"

# Resolução de diretórios configuráveis pelo desenvolvedor com sanitização de CRLF
export DEV_TOOLKIT_DEPENDENCIES_DIR="${DEV_TOOLKIT_DEPENDENCIES_DIR:-$TOOLKIT_ROOT/dependencies}"
DEV_TOOLKIT_DEPENDENCIES_DIR="${DEV_TOOLKIT_DEPENDENCIES_DIR%$'\r'}"

export LOCAL_BIN="${DEV_TOOLKIT_BIN_DIR:-${LOCAL_BIN:-$HOME/.local/bin}}"
LOCAL_BIN="${LOCAL_BIN%$'\r'}"

export DEV_TOOLKIT_PYTHON_DIR="${DEV_TOOLKIT_PYTHON_DIR:-$DEV_TOOLKIT_DEPENDENCIES_DIR/python}"
DEV_TOOLKIT_PYTHON_DIR="${DEV_TOOLKIT_PYTHON_DIR%$'\r'}"

export DEV_TOOLKIT_STORE_DIR="${DEV_TOOLKIT_STORE_DIR:-$DEV_TOOLKIT_DEPENDENCIES_DIR/pnpm-store}"
DEV_TOOLKIT_STORE_DIR="${DEV_TOOLKIT_STORE_DIR%$'\r'}"

export DEV_TOOLKIT_CACHE_DIR="${DEV_TOOLKIT_CACHE_DIR:-/tmp/cicd_cache}"
DEV_TOOLKIT_CACHE_DIR="${DEV_TOOLKIT_CACHE_DIR%$'\r'}"

export DEV_TOOLKIT_LOGS_DIR="${DEV_TOOLKIT_LOGS_DIR:-$TOOLKIT_ROOT/logs}"
DEV_TOOLKIT_LOGS_DIR="${DEV_TOOLKIT_LOGS_DIR%$'\r'}"

export PATH="$LOCAL_BIN:$DEV_TOOLKIT_PYTHON_DIR:$DEV_TOOLKIT_PYTHON_DIR/Scripts:$PATH"

env_load() {
    local repo_dir
    repo_dir="$(pwd)"
    local repo_name
    repo_name="$(basename "$repo_dir")"
    local tech=""

    if [[ -f "$repo_dir/pom.xml" ]]; then
        tech="java"
    elif [[ -f "$repo_dir/angular.json" ]]; then
        tech="angular"
    fi

    [[ -z "$tech" ]] && return 0

    local global_env="${TOOLKIT_ROOT}/env/${tech}/global.env"
    local specific_env="${TOOLKIT_ROOT}/env/${tech}/${repo_name}.env"

    set -a
    [[ -f "$global_env" ]] && . "$global_env"
    [[ -f "$specific_env" ]] && . "$specific_env"
    set +a
}
