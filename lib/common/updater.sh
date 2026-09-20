#!/usr/bin/env bash
# ==============================================================================
# updater.sh - Auto-Atualização Transparente sem Travamentos no Windows
# ==============================================================================

toolkit_auto_update() {
    [[ "${DEV_TOOLKIT_NO_UPDATE:-0}" == "1" ]] && return 0

    local current_sha
    current_sha="$(git -C "$TOOLKIT_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'local')"

    # 1. Verifica se o próprio repositório do toolkit tem alterações locais
    if ! git -C "$TOOLKIT_ROOT" diff --quiet 2>/dev/null || ! git -C "$TOOLKIT_ROOT" diff --cached --quiet 2>/dev/null; then
        printf "${_C_YELLOW}[AUTO-UPDATE]${_C_RESET} Toolkit com modificações locais não commitadas (%s). Auto-update pulado.\n" "$current_sha"
        return 0
    fi

    # 2. Busca atualizações remotas com network timeout nativo do Git (sem o binário timeout do Windows)
    if ! git -C "$TOOLKIT_ROOT" fetch --quiet origin main 2>/dev/null; then
        printf "${_C_YELLOW}[AUTO-UPDATE]${_C_RESET} Servidor remoto indisponível. Operando com versão local (%s).\n" "$current_sha"
        return 0
    fi

    local remote_sha
    remote_sha="$(git -C "$TOOLKIT_ROOT" rev-parse --short origin/main 2>/dev/null || echo '')"

    if [[ -n "$remote_sha" && "$current_sha" != "$remote_sha" ]]; then
        printf "${_C_INFO}[AUTO-UPDATE]${_C_RESET} Nova versão encontrada (%s -> %s). Atualizando...\n" "$current_sha" "$remote_sha"
        if git -C "$TOOLKIT_ROOT" merge --ff-only origin/main --quiet 2>/dev/null; then
            printf "${_C_SUCCESS}[AUTO-UPDATE]${_C_RESET} Toolkit atualizado com sucesso para %s.\n" "$remote_sha"
        else
            printf "${_C_WARN}[AUTO-UPDATE]${_C_RESET} Não foi possível aplicar fast-forward. Mantendo %s.\n" "$current_sha"
        fi
    else
        printf "${_C_SUCCESS}[AUTO-UPDATE]${_C_RESET} Dev Toolkit atualizado (%s).\n" "$current_sha"
    fi
}
