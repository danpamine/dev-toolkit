#!/usr/bin/env bash
# ==============================================================================
# maven-verify.sh - Compilação, Testes e Cobertura JaCoCo (Java)
# ==============================================================================

step_maven_verify() {
    local label="$1"
    local desc="$2"

    # Checa se existem arquivos físicos de teste em src/test/java
    local has_test_files
    has_test_files=$(find src/test/java -type f -name "*.java" 2>/dev/null | head -1)

    if [[ -z "$has_test_files" ]]; then
        log_step "$label" "$desc" "OK" "Sem testes no projeto"
        summary_add "$desc" "OK" "Sem testes no projeto"
        return 0
    fi

    local hash
    hash="$( (sha256sum pom.xml 2>/dev/null; find src -type f -exec sha256sum {} + 2>/dev/null | sort) | sha256sum | awk '{print $1}')"

    if cache_is_valid "build" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Executando testes unitários e JaCoCo" run_java_verify
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "build" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Corrija falhas de testes ou cobertura mínima"
        log_show_last
    fi
    return $exit_code
}
