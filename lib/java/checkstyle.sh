#!/usr/bin/env bash
# ==============================================================================
# checkstyle.sh - Verificação de Regras de Estilo Java (Latest Stable)
# ==============================================================================

if ! declare -f git_diff_target_files &>/dev/null; then
    _SCRIPT_D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _TK_R="${TOOLKIT_ROOT:-$(cd "$_SCRIPT_D/../.." && pwd)}"
    if [[ -f "$_TK_R/lib/common/git-diff.sh" ]]; then
        source "$_TK_R/lib/common/git-diff.sh"
    fi
fi

if ! declare -f maven_resolve_plugin_version &>/dev/null; then
    _SCRIPT_D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _TK_R="${TOOLKIT_ROOT:-$(cd "$_SCRIPT_D/../.." && pwd)}"
    if [[ -f "$_TK_R/lib/common/commands.sh" ]]; then
        source "$_TK_R/lib/common/commands.sh"
    fi
fi

step_checkstyle() {
    local label="$1"
    local desc="$2"

    if [[ ! -f "pom.xml" ]]; then
        log_step "$label" "$desc" "PULADO" "pom.xml ausente"
        summary_add "$desc" "SKIP" "Sem pom.xml"
        return 0
    fi

    local cfg="$TOOLKIT_ROOT/config/java/checkstyle.xml"
    if [[ ! -f "$cfg" ]]; then
        log_step "$label" "$desc" "PULADO" "checkstyle.xml ausente"
        summary_add "$desc" "SKIP" "Configuração ausente"
        return 0
    fi

    # 1. Filtra apenas arquivos Java alterados
    local changed_java_files=()
    while IFS= read -r f; do
        [[ -n "$f" && -f "$f" ]] && changed_java_files+=("$f")
    done < <(git_diff_target_files "*.java" 2>/dev/null)

    if [[ ${#changed_java_files[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Sem arquivos Java alterados"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Sem alterações" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "OK" "Sem alterações"
        return 0
    fi

    # 2. Validação de Cache
    local hash
    hash=$( (sha256sum "$cfg" 2>/dev/null; sha256sum "${changed_java_files[@]}" 2>/dev/null) | sha256sum | awk '{print $1}')

    if cache_is_valid "checkstyle" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Cache" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    # 3. Resolução dinâmica de versão do Checkstyle Plugin (Zero hardcoded)
    local checkstyle_ver
    checkstyle_ver="$(maven_resolve_plugin_version "org/apache/maven/plugins" "maven-checkstyle-plugin" "${CHECKSTYLE_PLUGIN_VERSION:-}")"

    if [[ -z "$checkstyle_ver" ]]; then
        log_step "$label" "$desc" "FAIL" "Não foi possível resolver versão do Checkstyle"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Falha na resolução de versão" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "Conecte-se à rede para baixar a versão mais recente do Checkstyle"
        return 1
    fi

    local includes_pattern
    includes_pattern=$(printf '%s,' "${changed_java_files[@]}" | sed 's/,$//')

    log_step_header "$label" "$desc"
    log_substep "Verificando estilo (Checkstyle v${checkstyle_ver}, ${#changed_java_files[@]} arquivo(s))" \
        mvn org.apache.maven.plugins:maven-checkstyle-plugin:"${checkstyle_ver}":check \
            -Dcheckstyle.config.location="$cfg" \
            -Dcheckstyle.includes="$includes_pattern" \
            -Dcheckstyle.consoleOutput=true \
            -Dcheckstyle.failsOnError=true -q
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "checkstyle" "$hash"
        local detail_msg="${#changed_java_files[@]} arquivo(s)"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "$detail_msg" > "$_CURRENT_ENGINE_DETAIL_FILE"
        log_step "$label" "$desc" "OK" "$detail_msg"
        summary_add "$desc" "OK" "$detail_msg"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Desvios de estilo detectados pelo Checkstyle"
        log_show_last
    fi
    return $exit_code
}
