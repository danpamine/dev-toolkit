#!/usr/bin/env bash
# ==============================================================================
# semgrep.sh - SAST Semântico via Python Portátil
# ==============================================================================

step_semgrep_sast() {
    local label="$1"
    local desc="$2"

    local py_exe="${TOOLKIT_ROOT}/dependencies/python/python.exe"
    if [[ ! -f "$py_exe" ]]; then
        log_step "$label" "$desc" "PULADO" "Python Portátil não inicializado"
        summary_add "$desc" "SKIP" "Ambiente Python ausente"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Executando Semgrep (auto security rules)" \
        "$py_exe" -m semgrep scan --config auto --error --quiet

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Vulnerabilidades semânticas detectadas pelo Semgrep"
        log_show_last 30
    fi
    return $exit_code
}
