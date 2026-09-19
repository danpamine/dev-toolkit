#!/usr/bin/env bash
# ==============================================================================
# version-check.sh - Validação de Incremento de Versão (Angular)
# ==============================================================================

step_version_check() {
    local label="$1"
    local desc="$2"

    log_step_header "$label" "$desc"
    if [[ ! -f "package.json" ]]; then
        log_step "$label" "$desc" "FAIL" "package.json não encontrado"
        summary_add "$desc" "FAIL" "package.json ausente"
        return 1
    fi

    local project_version
    project_version="$(node -p "require('./package.json').version" 2>/dev/null)"
    if [[ -z "$project_version" ]]; then
        log_step "$label" "$desc" "FAIL" "Versão não informada no package.json"
        summary_add "$desc" "FAIL" "Campo 'version' obrigatório"
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
    local base_json
    base_json="$(git show "${best_merge_base}:package.json" 2>/dev/null)"
    if [[ -n "$base_json" ]]; then
        base_version="$(node -e "console.log(JSON.parse(process.argv[1]).version || '')" "$base_json" 2>/dev/null)"
    fi

    if [[ -z "$base_version" ]]; then
        log_step "$label" "$desc" "OK" "Base sem package.json comparável"
        summary_add "$desc" "OK" "Base sem package.json"
        return 0
    fi

    if [[ "$project_version" == "$base_version" ]]; then
        log_step "$label" "$desc" "FAIL" "Versão não incrementada (${project_version})"
        summary_add "$desc" "FAIL" "Incremente a versão no package.json (atual: ${project_version}, base: ${base_version})"
        return 1
    fi

    local higher
    higher="$(printf '%s\n%s\n' "$base_version" "$project_version" | sort -V | tail -n 1)"
    if [[ "$higher" != "$project_version" ]]; then
        log_step "$label" "$desc" "FAIL" "Versão local inferior à base (${project_version} < ${base_version})"
        summary_add "$desc" "FAIL" "Versão local (${project_version}) inferior à remota (${base_version})"
        return 1
    fi

    log_step "$label" "$desc" "OK" "${base_version} -> ${project_version}"
    summary_add "$desc" "OK" "${base_version} -> ${project_version}"
    return 0
}
