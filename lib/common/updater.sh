#!/usr/bin/env bash
# ==============================================================================
# updater.sh - Atualização automática do Toolkit a cada execução
# ==============================================================================

toolkit_auto_update() {
    [[ "${DEV_TOOLKIT_NO_UPDATE:-0}" == "1" ]] && return 0

    local lock_file="/tmp/dev_toolkit_update.lock"
    # Previne concorrência se múltiplos hooks rodarem simultaneamente
    if [[ -f "$lock_file" ]]; then
        local lock_age=$(( $(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || echo 0) ))
        [[ $lock_age -lt 60 ]] && return 0
    fi
    touch "$lock_file"

    (
        cd "$TOOLKIT_ROOT" || exit 0
        # Checa se o repositório está limpo para evitar conflitos locais
        if ! git diff --quiet || ! git diff --cached --quiet; then
            exit 0
        fi

        # Timeout estrito para checagem de rede corporativa
        timeout 3 git fetch origin main --quiet 2>/dev/null
        local local_sha remote_sha
        local_sha=$(git rev-parse HEAD 2>/dev/null)
        remote_sha=$(git rev-parse origin/main 2>/dev/null)

        if [[ -n "$remote_sha" && "$local_sha" != "$remote_sha" ]]; then
            printf "${_C_INFO}[TOOLKIT]${_C_RESET} Atualizando Dev Toolkit para a versão mais recente...\n"
            git merge --ff-only origin/main --quiet 2>/dev/null
        fi
    )
    rm -f "$lock_file"
}
