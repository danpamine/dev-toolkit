#!/usr/bin/env bash
# ==============================================================================
# osv-scanner.sh - SCA Rápido via Google OSV Database
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
    [[ -f "pom.xml" ]] && target_file="pom.xml"
    [[ -f "package-lock.json" ]] && target_file="package-lock.json"

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
    log_substep "Varrendo vulnerabilidades OSV ($target_file)" "$bin" scan --lockfile="$target_file"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "osv-scanner" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Vulnerabilidades identificadas pelo OSV-Scanner"
        log_show_last 25
    fi
    return $exit_code
}
