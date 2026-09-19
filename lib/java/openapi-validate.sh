#!/usr/bin/env bash
# ==============================================================================
# openapi-validate.sh - Validação de Contratos OpenAPI / Swagger
# ==============================================================================

step_openapi_validate() {
    local label="$1"
    local desc="$2"

    local spec_files
    spec_files="$(find src/main/resources -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null)"

    if [[ -z "$spec_files" ]]; then
        log_step "$label" "$desc" "OK" "Nenhum contrato encontrado"
        summary_add "$desc" "OK" "Sem contratos"
        return 0
    fi

    local hash
    hash="$(sha256sum $spec_files 2>/dev/null | sort | sha256sum | awk '{print $1}')"
    if cache_is_valid "spec" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"
    local spec_failed=0

    for spec in $spec_files; do
        if grep -qE "openapi:|swagger:" "$spec" 2>/dev/null; then
            if command -v spectral &>/dev/null; then
                log_substep "Validando $(basename "$spec")" spectral lint "$spec"
            else
                log_substep "Validando $(basename "$spec")" mvn io.swagger.codegen.v3:swagger-codegen-maven-plugin:RELEASE:generate \
                    -DinputSpec="$spec" -Dlanguage=openapi -Doutput=/tmp/swagger-val-$$ -q
                rm -rf /tmp/swagger-val-$$ 2>/dev/null
            fi
            if [[ $? -ne 0 ]]; then
                spec_failed=1
                break
            fi
        fi
    done

    if [[ $spec_failed -eq 0 ]]; then
        cache_save "spec" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
        return 0
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Erros de sintaxe nos contratos OpenAPI/Swagger"
        log_show_last 20
        return 1
    fi
}
