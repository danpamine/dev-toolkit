#!/usr/bin/env bash
# ==============================================================================
# ast-grep.sh - Linter de AST
# ==============================================================================

step_ast_grep() {
    local label="$1"
    local desc="$2"

    local bin="ast-grep"
    [[ -f "$LOCAL_BIN/ast-grep.exe" ]] && bin="$LOCAL_BIN/ast-grep.exe"

    if ! command -v "$bin" &>/dev/null; then
        log_step "$label" "$desc" "PULADO" "ast-grep ausente"
        summary_add "$desc" "SKIP" "ast-grep não instalado"
        return 0
    fi

    log_step_header "$label" "$desc"
    # Exemplo: Bloquear System.out.println em produção ou debugger residual
    log_substep "Verificando regras AST" "$bin" scan --inline-rules 'id: no-debugger, language: typescript, rule: {pattern: debugger}'
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Desvios estruturais detectados pelo ast-grep"
        log_show_last 20
    fi
    return $exit_code
}
