#!/usr/bin/env bash
# ==============================================================================
# prettier.sh - Formatação Incremental Prettier
# ==============================================================================

step_angular_prettier() {
    local label="$1"
    local desc="$2"

    local staged_files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && staged_files+=("$file")
    done < <(git diff --cached --name-only --diff-filter=ACMR -- "*.ts" "*.js" "*.css" "*.scss" "*.html" "*.json" 2>/dev/null)

    if [[ ${#staged_files[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo alterado"
        summary_add "$desc" "OK" "Sem alterações"
        return 0
    fi

    local hash
    hash="$(printf '%s' "${staged_files[@]}" | sha256sum | awk '{print $1}')"
    if cache_is_valid "prettier" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"

    local cfg_arg=""
    if [[ -f "$TOOLKIT_ROOT/config/angular/.prettierrc.json" ]]; then
        cfg_arg="--config $TOOLKIT_ROOT/config/angular/.prettierrc.json"
    fi

    log_substep "Formatando ${#staged_files[@]} arquivo(s)" npx --yes prettier --write $cfg_arg "${staged_files[@]}"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        git add "${staged_files[@]}" 2>/dev/null
        cache_save "prettier" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Erro na formatação Prettier"
        log_show_last 20
    fi
    return $exit_code
}
