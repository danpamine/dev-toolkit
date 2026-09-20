#!/usr/bin/env bash
# ==============================================================================
# test.sh - Execução dos Testes Unitários Angular
# ==============================================================================

step_angular_test() {
    local label="$1"
    local desc="$2"

    if [[ ! -f "package.json" ]]; then
        log_step "$label" "$desc" "OK" "Sem package.json"
        summary_add "$desc" "OK" "Sem package.json"
        return 0
    fi

    local has_script
    has_script=$(node -p "
        try {
            const pkg = require('./package.json');
            const s = pkg.scripts && pkg.scripts.test;
            (s && !s.includes('no test specified')) ? 'true' : 'false';
        } catch(e) { 'false'; }
    " 2>/dev/null)

    if [[ "$has_script" != "true" ]]; then
        log_step "$label" "$desc" "OK" "Sem script de teste"
        summary_add "$desc" "OK" "Sem script de teste"
        return 0
    fi

    if [[ -f "angular.json" ]]; then
        local has_ng_test_target
        has_ng_test_target=$(node -e '
            try {
                const aj = require("./angular.json");
                const projects = Object.values(aj.projects || {});
                const hasTest = projects.some(p => (p.architect && p.architect.test) || (p.targets && p.targets.test));
                console.log(hasTest ? "true" : "false");
            } catch(e) { console.log("false"); }
        ' 2>/dev/null)

        if [[ "$has_ng_test_target" == "false" ]]; then
            log_step "$label" "$desc" "OK" "Sem target de teste no angular.json"
            summary_add "$desc" "OK" "Sem target de teste no angular.json"
            return 0
        fi
    fi

    local has_test_files
    has_test_files=$(find . -maxdepth 5 -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.git/*" -type f \( -name "*.spec.ts" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.test.js" \) 2>/dev/null | head -1)

    if [[ -z "$has_test_files" ]]; then
        log_step "$label" "$desc" "OK" "Sem testes no projeto"
        summary_add "$desc" "OK" "Sem testes no projeto"
        return 0
    fi

    local hash
    hash=$( (sha256sum package.json 2>/dev/null; find . -maxdepth 5 -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.git/*" -type f \( -name "*.spec.ts" -o -name "*.ts" \) -exec sha256sum {} + 2>/dev/null | sort) | sha256sum | awk '{print $1}')

    if cache_is_valid "angular-test" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Executando testes unitários (package.json)" run_angular_test
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "angular-test" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Corrija falhas nos testes unitários"
        log_show_last
    fi
    return $exit_code
}
