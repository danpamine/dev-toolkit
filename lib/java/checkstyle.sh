#!/usr/bin/env bash
# ==============================================================================
# checkstyle.sh - Verificação Incremental de Estilo de Código (Checkstyle)
# ==============================================================================

step_checkstyle() {
    local label="$1"
    local desc="$2"

    local checkstyle_config="$TOOLKIT_ROOT/config/java/checkstyle.xml"
    if [[ ! -f "$checkstyle_config" ]]; then
        log_step "$label" "$desc" "PULADO" "checkstyle.xml ausente"
        summary_add "$desc" "SKIP" "Configuração ausente"
        return 0
    fi

    local changed_java=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && changed_java+=("$file")
    done < <(git diff --cached --name-only --diff-filter=ACMR -- "*.java" 2>/dev/null)

    if [[ ${#changed_java[@]} -eq 0 ]]; then
        local parent_info best_merge_base
        parent_info="$(git_diff_find_parent_branch)"
        best_merge_base="${parent_info%% *}"
        if [[ -n "$best_merge_base" ]]; then
            while IFS= read -r file; do
                [[ -n "$file" ]] && changed_java+=("$file")
            done < <(git diff --name-only --diff-filter=ACMR "$best_merge_base" -- "*.java" 2>/dev/null)
        fi
    fi

    if [[ ${#changed_java[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo Java alterado"
        summary_add "$desc" "OK" "Sem alterações"
        return 0
    fi

    local includes=""
    for file in "${changed_java[@]}"; do
        local pattern=""
        if [[ "$file" == src/main/java/* ]]; then
            pattern="${file#src/main/java/}"
        elif [[ "$file" == src/test/java/* ]]; then
            pattern="${file#src/test/java/}"
        else
            continue
        fi
        [[ -n "$includes" ]] && includes+=","
        includes+="$pattern"
    done

    if [[ -z "$includes" ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo de código Java verificado"
        summary_add "$desc" "OK" "Sem arquivos em src/"
        return 0
    fi

    local hash
    hash="$(printf '%s' "${changed_java[@]}" | sha256sum | awk '{print $1}')"
    if cache_is_valid "checkstyle" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Executando Checkstyle" mvn checkstyle:check \
        -Dcheckstyle.config.location="$checkstyle_config" \
        -Dcheckstyle.includes="$includes" \
        -Dcheckstyle.failOnViolation=true -q

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        cache_save "checkstyle" "$hash"
        log_step "$label" "$desc" "OK" "${#changed_java[@]} arquivo(s)"
        summary_add "$desc" "OK" "${#changed_java[@]} arquivo(s)"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Violações do Checkstyle detectadas"
        log_show_last 25
    fi
    return $exit_code
}
