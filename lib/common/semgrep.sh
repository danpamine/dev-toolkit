#!/usr/bin/env bash
# ==============================================================================
# semgrep.sh - SAST Semântico
# ==============================================================================

step_semgrep_sast() {
    local label="$1"
    local desc="$2"

    local py_dir="${DEV_TOOLKIT_PYTHON_DIR:-${TOOLKIT_ROOT}/dependencies/python}"
    local semgrep_bin=""

    if [[ -f "${py_dir}/Scripts/semgrep.exe" ]]; then
        semgrep_bin="${py_dir}/Scripts/semgrep.exe"
    elif command -v semgrep &>/dev/null; then
        semgrep_bin="semgrep"
    fi

    if [[ -z "$semgrep_bin" ]] || ! "$semgrep_bin" --version &>/dev/null; then
        log_step "$label" "$desc" "PULADO" "Semgrep não disponível"
        summary_add "$desc" "SKIP" "Semgrep ausente ou bloqueado na rede"
        return 0
    fi

    # Filtra apenas arquivos modificados suportados pelo Semgrep
    local changed_files=()
    while IFS= read -r f; do
        [[ -n "$f" && -f "$f" ]] && changed_files+=("$f")
    done < <(git_diff_target_files "*.java" "*.ts" "*.js" 2>/dev/null)

    if [[ ${#changed_files[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo relevante alterado"
        summary_add "$desc" "OK" "Sem alterações"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Analisando ${#changed_files[@]} arquivo(s) modificado(s)" \
        "$semgrep_bin" scan --config auto --error --quiet "${changed_files[@]}"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "${#changed_files[@]} arquivo(s)"
        summary_add "$desc" "OK" "${#changed_files[@]} arquivo(s)"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Vulnerabilidades semânticas detectadas pelo Semgrep"
        log_show_last
    fi
    return $exit_code
}
