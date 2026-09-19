#!/usr/bin/env bash
# ==============================================================================
# test.sh - Execução dos Testes Unitários Angular
# ==============================================================================

step_angular_test() {
    local label="$1"
    local desc="$2"

    if [[ ! -f "package.json" ]]; then
        log_step "$label" "$desc" "PULADO" "package.json ausente"
        summary_add "$desc" "SKIP" "Sem package.json"
        return 0
    fi

    # Checa se há script de teste válido
    local has_script
    has_script=$(node -p "
        try {
            const pkg = require('./package.json');
            const s = pkg.scripts && pkg.scripts.test;
            (s && !s.includes('no test specified')) ? 'true' : 'false';
        } catch(e) { 'false'; }
    " 2>/dev/null)

    if [[ "$has_script" != "true" ]]; then
        log_step "$label" "$desc" "PULADO" "Script 'test' ausente no package.json"
        summary_add "$desc" "SKIP" "Nenhum script de teste mapeado"
        return 0
    fi

    local hash
    hash=$( (sha256sum package.json 2>/dev/null; find src -type f \( -name "*.spec.ts" -o -name "*.ts" \) -exec sha256sum {} + 2>/dev/null | sort) | sha256sum | awk '{print $1}')

    if cache_is_valid "angular-test" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Executando suite de testes unitários"
    run_angular_test
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "angular-test" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Corrija falhas nos testes unitários"
        log_show_last 30
    fi
    return $exit_code
}
