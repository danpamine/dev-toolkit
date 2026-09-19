#!/usr/bin/env bash
# ==============================================================================
# spotbugs.sh - SAST com SpotBugs e FindSecBugs
# ==============================================================================

step_spotbugs() {
    local label="$1"
    local desc="$2"

    local hash
    hash="$(find src/main/java -type f -name "*.java" -exec sha256sum {} + 2>/dev/null | sort | sha256sum | awk '{print $1}')"

    if cache_is_valid "sast" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Compilando classes para análise SAST" run_java_build
    local build_rc=$?

    if [[ $build_rc -ne 0 ]]; then
        log_step "$label" "$desc" "FAIL" "Falha na compilação"
        summary_add "$desc" "FAIL" "Erro ao compilar classes para o SpotBugs"
        return 1
    fi

    log_substep "Executando SpotBugs + FindSecBugs" \
        mvn com.github.spotbugs:spotbugs-maven-plugin:RELEASE:check \
        -Dspotbugs.plugins=com.h3xstream.findsecbugs:findsecbugs-plugin:RELEASE \
        -Dspotbugs.effort=Max \
        -Dspotbugs.threshold=Low \
        -Dspotbugs.failOnError=true -q

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        cache_save "sast" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Corrija vulnerabilidades apontadas pelo FindSecBugs"
        log_show_last 25
    fi
    return $exit_code
}
