#!/usr/bin/env bash
# ==============================================================================
# ast-grep.sh - Linter Estrutural de AST Incremental
# ==============================================================================

step_ast_grep() {
    local label="$1"
    local desc="$2"

    local rules_file=""
    local filter_pattern=""
    if [[ -f "pom.xml" ]]; then
        rules_file="$TOOLKIT_ROOT/config/java/ast-grep-rules.yml"
        filter_pattern="*.java"
    elif [[ -f "angular.json" ]]; then
        rules_file="$TOOLKIT_ROOT/config/angular/ast-grep-rules.yml"
        filter_pattern="*.ts"
    fi

    if [[ ! -f "$rules_file" ]]; then
        log_step "$label" "$desc" "PULADO" "Regras AST não encontradas"
        summary_add "$desc" "SKIP" "Regras ausentes"
        return 0
    fi

    local ast_cmd=""
    if [[ -f "$LOCAL_BIN/ast-grep.exe" ]]; then
        ast_cmd="$LOCAL_BIN/ast-grep.exe"
    elif command -v ast-grep &>/dev/null; then
        ast_cmd="ast-grep"
    elif command -v npx &>/dev/null; then
        ast_cmd="npx --yes @ast-grep/cli"
    fi

    if [[ -z "$ast_cmd" ]]; then
        log_step "$label" "$desc" "PULADO" "ast-grep não disponível"
        summary_add "$desc" "SKIP" "Binário e npx ausentes"
        return 0
    fi

    local changed_files=()
    while IFS= read -r f; do
        [[ -n "$f" && -f "$f" ]] && changed_files+=("$f")
    done < <(git_diff_target_files "$filter_pattern" 2>/dev/null)

    if [[ ${#changed_files[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo relevante alterado"
        summary_add "$desc" "OK" "Sem alterações"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Inspecionando ${#changed_files[@]} arquivo(s) alterado(s)" \
        $ast_cmd scan --rule "$rules_file" "${changed_files[@]}"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "${#changed_files[@]} arquivo(s)"
        summary_add "$desc" "OK" "${#changed_files[@]} arquivo(s)"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Desvios estruturais identificados pelo ast-grep"
        log_show_last
    fi
    return $exit_code
}
