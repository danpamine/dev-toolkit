#!/usr/bin/env bash
# ==============================================================================
# build.sh - Compilação de Produção Angular
# ==============================================================================

step_angular_build() {
    local label="$1"
    local desc="$2"

    if [[ ! -d "node_modules" ]]; then
        log_step "$label" "$desc" "FAIL" "node_modules ausente"
        summary_add "$desc" "FAIL" "Execute pnpm install antes de compilar"
        return 1
    fi

    local hash
    hash="$( (sha256sum angular.json package.json 2>/dev/null; find src -type f -name "*.ts" -exec sha256sum {} + 2>/dev/null | sort) | sha256sum | awk '{print $1}')"

    if cache_is_valid "angular-build" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Compilando aplicação Angular" run_angular_build
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "angular-build" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Erros de compilação detectados"
        log_show_last 25
    fi
    return $exit_code
}
