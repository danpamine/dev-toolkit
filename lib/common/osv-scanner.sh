#!/usr/bin/env bash
# ==============================================================================
# osv-scanner.sh - SCA Rápido via Google OSV Database com suporte a pacotes privados
# ==============================================================================

step_osv_scanner() {
    local label="$1"
    local desc="$2"

    local bin="osv-scanner"
    [[ -f "$LOCAL_BIN/osv-scanner.exe" ]] && bin="$LOCAL_BIN/osv-scanner.exe"

    if ! command -v "$bin" &>/dev/null; then
        log_step "$label" "$desc" "PULADO" "osv-scanner ausente"
        summary_add "$desc" "SKIP" "osv-scanner não instalado"
        return 0
    fi

    local target_file=""
    local scan_flag=""
    if [[ -f "target/bom.json" ]]; then
        target_file="target/bom.json"
        scan_flag="--sbom"
    elif [[ -f "pom.xml" ]]; then
        target_file="pom.xml"
        scan_flag="--lockfile"
    elif [[ -f "package-lock.json" ]]; then
        target_file="package-lock.json"
        scan_flag="--lockfile"
    fi

    if [[ -z "$target_file" ]]; then
        log_step "$label" "$desc" "OK" "Sem manifesto compatível"
        summary_add "$desc" "OK" "Sem manifesto"
        return 0
    fi

    local hash
    hash="$(sha256sum "$target_file" 2>/dev/null | awk '{print $1}')"
    if cache_is_valid "osv-scanner" "$hash" 10800; then
        log_step "$label" "$desc" "OK" "Cache (3h)"
        summary_add "$desc" "OK" "Cache (3h)"
        return 0
    fi

    log_step_header "$label" "$desc"
    log_substep "Varrendo dependências OSV ($target_file)" "$bin" scan "$scan_flag=$target_file"
    local raw_output="$_LOG_LAST_OUTPUT"

    # Avaliação resiliente de vulnerabilidades reais vs falha em pacotes corporativos privados
    local exit_code=0
    if echo "$raw_output" | grep -qE "Total [1-9][0-9]* packages? affected"; then
        exit_code=1
    elif echo "$raw_output" | grep -q "Total 0 packages affected"; then
        exit_code=0
    else
        # Se houve falha de extração mas 0 vulnerabilidades mapeadas, aprova
        if echo "$raw_output" | grep -q "0 known vulnerabilities"; then
            exit_code=0
        else
            exit_code=1
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        cache_save "osv-scanner" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Vulnerabilidades identificadas pelo OSV-Scanner"
        log_show_last
    fi
    return $exit_code
}
