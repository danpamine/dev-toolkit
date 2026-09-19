#!/usr/bin/env bash
# ==============================================================================
# gitleaks.sh - Varredura de Segredos com Gitleaks
# ==============================================================================

step_gitleaks_commit() {
    local label="$1"
    local desc="$2"

    local gitleaks_bin="gitleaks"
    [[ -f "$LOCAL_BIN/gitleaks.exe" ]] && gitleaks_bin="$LOCAL_BIN/gitleaks.exe"

    if ! command -v "$gitleaks_bin" &>/dev/null; then
        log_step "$label" "$desc" "PULADO" "Gitleaks ausente"
        summary_add "$desc" "SKIP" "Gitleaks não instalado"
        return 0
    fi

    local hash
    hash="$(git diff --cached 2>/dev/null | sha256sum | awk '{print $1}')"
    [[ -z "$hash" ]] && hash="$(git rev-parse HEAD 2>/dev/null | sha256sum | awk '{print $1}')"

    if cache_is_valid "gitleaks" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Analisando credenciais staged" "$gitleaks_bin" git --pre-commit --verbose
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "gitleaks" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Remova credenciais expostas identificadas pelo Gitleaks"
        log_show_last 25
    fi
    return $exit_code
}

step_gitleaks_full() {
    local gitleaks_bin="gitleaks"
    [[ -f "$LOCAL_BIN/gitleaks.exe" ]] && gitleaks_bin="$LOCAL_BIN/gitleaks.exe"

    if command -v "$gitleaks_bin" &>/dev/null; then
        printf "${_C_INFO}[GITLEAKS]${_C_RESET} Executando varredura integral de segredos (Full Scan)...\n"
        "$gitleaks_bin" detect --verbose --no-git=false
        return $?
    fi
    return 0
}
