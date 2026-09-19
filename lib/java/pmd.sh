#!/usr/bin/env bash
# ==============================================================================
# pmd.sh - Análise Estática de Qualidade (PMD)
# ==============================================================================

step_pmd() {
    local label="$1"
    local desc="$2"

    local parent_info best_merge_base
    parent_info="$(git_diff_find_parent_branch)"
    best_merge_base="${parent_info%% *}"

    local changed_files=()
    if [[ -n "$best_merge_base" ]]; then
        while IFS= read -r file; do
            [[ -n "$file" ]] && changed_files+=("$file")
        done < <(git diff --name-only --diff-filter=ACMR "$best_merge_base" -- "*.java" 2>/dev/null)
    fi

    if [[ -n "$best_merge_base" && ${#changed_files[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo Java alterado na branch"
        summary_add "$desc" "OK" "Sem alterações"
        return 0
    fi

    local includes=""
    for file in "${changed_files[@]}"; do
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
        log_step "$label" "$desc" "OK" "Nenhum arquivo Java verificado"
        summary_add "$desc" "OK" "Sem arquivos em src/"
        return 0
    fi

    local hash
    hash="$(printf '%s' "${changed_files[@]}" | sha256sum | awk '{print $1}')"
    if cache_is_valid "pmd" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Executando PMD nos arquivos alterados" mvn org.apache.maven.plugins:maven-pmd-plugin:RELEASE:check \
        -Dincludes="$includes" \
        -Dpmd.failOnViolation=true -q

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        cache_save "pmd" "$hash"
        log_step "$label" "$desc" "OK" "${#changed_files[@]} arquivo(s)"
        summary_add "$desc" "OK" "${#changed_files[@]} arquivo(s)"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Violações de qualidade apontadas pelo PMD"
        log_show_last 25
    fi
    return $exit_code
}
