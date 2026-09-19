#!/usr/bin/env bash
# ==============================================================================
# version-check.sh - Validação de Incremento de Versão (Java)
# ==============================================================================

step_version_check() {
    local label="$1"
    local desc="$2"

    log_step_header "$label" "$desc"
    local project_version
    project_version="$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout 2>/dev/null)"

    if [[ -z "$project_version" ]]; then
        log_step "$label" "$desc" "FAIL" "Falha ao ler versão do pom.xml"
        summary_add "$desc" "FAIL" "pom.xml com formato inválido"
        return 1
    fi

    local parent_info best_merge_base
    parent_info="$(git_diff_find_parent_branch)"
    best_merge_base="${parent_info%% *}"

    if [[ -z "$best_merge_base" ]]; then
        log_step "$label" "$desc" "OK" "Sem branch remota para comparação"
        summary_add "$desc" "OK" "Sem branch remota"
        return 0
    fi

    local base_version=""
    local tmp_base_pom="/tmp/pom_base_$$.xml"
    git show "${best_merge_base}:pom.xml" > "$tmp_base_pom" 2>/dev/null

    if [[ -s "$tmp_base_pom" ]]; then
        base_version="$(mvn help:evaluate -Dexpression=project.version -f "$tmp_base_pom" -q -DforceStdout 2>/dev/null)"
        rm -f "$tmp_base_pom"
    fi

    if [[ -z "$base_version" ]]; then
        log_step "$label" "$desc" "OK" "Base sem pom.xml comparável"
        summary_add "$desc" "OK" "Base sem pom.xml"
        return 0
    fi

    if [[ "$project_version" == "$base_version" ]]; then
        log_step "$label" "$desc" "FAIL" "Versão não incrementada (${project_version})"
        summary_add "$desc" "FAIL" "Incremente a versão no pom.xml (atual: ${project_version}, base: ${base_version})"
        return 1
    fi

    local higher
    higher="$(printf '%s\n%s\n' "$base_version" "$project_version" | sort -V | tail -n 1)"
    if [[ "$higher" != "$project_version" ]]; then
        log_step "$label" "$desc" "FAIL" "Versão local inferior à base (${project_version} < ${base_version})"
        summary_add "$desc" "FAIL" "Versão local (${project_version}) inferior à base (${base_version})"
        return 1
    fi

    log_step "$label" "$desc" "OK" "${base_version} -> ${project_version}"
    summary_add "$desc" "OK" "${base_version} -> ${project_version}"
    return 0
}
