#!/usr/bin/env bash
# ==============================================================================
# bootstrap.sh (Angular) - Inicialização do ambiente Node/PNPM
# ==============================================================================

_ANGULAR_BOOTSTRAP_DONE=0

bootstrap_angular() {
    [[ "$_ANGULAR_BOOTSTRAP_DONE" -eq 1 ]] && return 0
    _ANGULAR_BOOTSTRAP_DONE=1

    if ! command -v npx &>/dev/null; then
        printf "${_C_ERROR}[BOOTSTRAP-NG]${_C_RESET} npx não encontrado no PATH\n"
        return 1
    fi

    local npmrc_path="${TOOLKIT_ROOT}/config/angular/.npmrc"
    local store_path="${DEV_TOOLKIT_STORE_DIR:-${TOOLKIT_ROOT}/dependencies/pnpm-store}"

    if [[ -f "$npmrc_path" ]]; then
        export NPM_CONFIG_USERCONFIG="$npmrc_path"
        unset NPM_CONFIG_GLOBALCONFIG
        export pnpm_config_userconfig="$npmrc_path"
        export pnpm_config_store_dir="$store_path"
    fi

    return 0
}
