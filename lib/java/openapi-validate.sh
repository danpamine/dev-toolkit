#!/usr/bin/env bash
# ==============================================================================
# openapi-validate.sh - Validação de Contratos OpenAPI (Latest Stable)
# ==============================================================================

if ! declare -f maven_resolve_plugin_version &>/dev/null; then
    _SCRIPT_D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _TK_R="${TOOLKIT_ROOT:-$(cd "$_SCRIPT_D/../.." && pwd)}"
    if [[ -f "$_TK_R/lib/common/commands.sh" ]]; then
        source "$_TK_R/lib/common/commands.sh"
    fi
fi

step_openapi_validate() {
    local label="$1"
    local desc="$2"

    local spec_file=""
    for cand in "openapi.yaml" "openapi.yml" "openapi.json" "swagger.yaml" "swagger.yml" "swagger.json" \
                "src/main/resources/openapi.yaml" "src/main/resources/openapi.yml" "src/main/resources/openapi.json" \
                "src/main/resources/swagger.yaml" "src/main/resources/swagger.yml" "src/main/resources/swagger.json"; do
        if [[ -f "$cand" ]]; then
            spec_file="$cand"
            break
        fi
    done

    if [[ -z "$spec_file" ]]; then
        log_step "$label" "$desc" "OK" "Sem contratos OpenAPI"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Sem contratos OpenAPI" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "OK" "Sem contratos OpenAPI"
        return 0
    fi

    local hash
    hash=$(sha256sum "$spec_file" 2>/dev/null | awk '{print $1}')

    if cache_is_valid "openapi" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Cache" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    # Resolução dinâmica da versão mais recente no Maven Central (Zero hardcoded)
    local openapi_ver
    openapi_ver="$(maven_resolve_plugin_version "org/openapitools" "openapi-generator-cli" "${OPENAPI_GENERATOR_VERSION:-}")"

    if [[ -z "$openapi_ver" ]]; then
        log_step "$label" "$desc" "FAIL" "Não foi possível resolver versão do OpenAPI Generator"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Falha na resolução de versão" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "Conecte-se à rede para baixar a versão mais recente do OpenAPI Generator"
        return 1
    fi

    log_step_header "$label" "$desc"
    log_substep "Validando contrato ($spec_file via openapi-generator v${openapi_ver})" \
        mvn org.openapitools:openapi-generator-cli:"${openapi_ver}":validate \
            -DinputSpec="$spec_file" -q
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "openapi" "$hash"
        log_step "$label" "$desc" "OK" "$spec_file"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "$spec_file" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "OK" "$spec_file"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Contrato OpenAPI inválido ($spec_file)"
        log_show_last
    fi
    return $exit_code
}
