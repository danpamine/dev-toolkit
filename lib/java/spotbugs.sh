#!/usr/bin/env bash
# ==============================================================================
# spotbugs.sh - Análise SAST Incremental com SpotBugs + FindSecBugs (Latest Stable)
# ==============================================================================

if ! declare -f git_diff_target_files &>/dev/null; then
    _SCRIPT_D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _TK_R="${TOOLKIT_ROOT:-$(cd "$_SCRIPT_D/../.." && pwd)}"
    if [[ -f "$_TK_R/lib/common/git-diff.sh" ]]; then
        source "$_TK_R/lib/common/git-diff.sh"
    fi
fi

_spotbugs_resolve_version() {
    local group_path="$1"
    local artifact="$2"
    local env_override="$3"
    local version_file="${LOCAL_BIN:-$HOME/.local/bin}/${artifact}.version"

    if [[ -n "$env_override" ]]; then
        echo "$env_override"
        return 0
    fi

    local live_version=""
    local url="https://repo1.maven.org/maven2/${group_path}/${artifact}/maven-metadata.xml"
    local meta_xml
    meta_xml="$(curl -sL --ssl-no-revoke --connect-timeout 4 --max-time 8 "$url" 2>/dev/null)"

    if [[ -n "$meta_xml" ]]; then
        live_version="$(echo "$meta_xml" | grep -oE '<release>[^<]+' | head -1 | sed 's/<release>//' | tr -d '\r\n ')"
        if [[ -z "$live_version" ]]; then
            live_version="$(echo "$meta_xml" | grep -oE '<latest>[^<]+' | head -1 | sed 's/<latest>//' | tr -d '\r\n ')"
        fi
    fi

    if [[ -n "$live_version" ]]; then
        mkdir -p "$(dirname "$version_file")" 2>/dev/null || true
        echo "$live_version" > "$version_file" 2>/dev/null || true
        echo "$live_version"
        return 0
    fi

    if [[ -f "$version_file" ]]; then
        cat "$version_file" 2>/dev/null | tr -d '\r\n '
        return 0
    fi

    if [[ "$artifact" == "spotbugs-maven-plugin" ]]; then
        echo "4.8.6.6"
    else
        echo "1.13.0"
    fi
}

step_spotbugs() {
    local label="$1"
    local desc="$2"

    if [[ ! -f "pom.xml" ]]; then
        log_step "$label" "$desc" "PULADO" "pom.xml ausente"
        summary_add "$desc" "SKIP" "Sem pom.xml"
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

    # 2. Extrai classes de produção (ignora src/test/)
    local target_classes=()
    for f in "${changed_java_files[@]}"; do
        if [[ "$f" =~ (^|/)src/test/ ]]; then
            continue
        fi

        local cls
        cls=$(basename "$f" .java)
        [[ "$cls" == "package-info" || "$cls" == "module-info" ]] && continue

        local pkg
        pkg=$(grep -E '^[[:space:]]*package[[:space:]]+' "$f" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*package[[:space:]]+([^;]+);.*/\1/' | tr -d '\r\n ')

        local fqcn="$cls"
        [[ -n "$pkg" ]] && fqcn="${pkg}.${cls}"
        target_classes+=("$fqcn")
    done

    if [[ ${#target_classes[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Sem classes de produção alteradas"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Sem alterações em src/main" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "OK" "Sem alterações em src/main"
        return 0
    fi

    local unique_classes=()
    while IFS= read -r c; do
        [[ -n "$c" ]] && unique_classes+=("$c")
    done < <(printf '%s\n' "${target_classes[@]}" | sort -u)

    # 3. Cache
    local hash
    hash=$( (sha256sum pom.xml 2>/dev/null; sha256sum "${changed_java_files[@]}" 2>/dev/null) | sha256sum | awk '{print $1}')

    if cache_is_valid "spotbugs" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Cache" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    local class_filter
    class_filter=$(IFS=,; echo "${unique_classes[*]}")

    # 4. Resolução dinâmica das versões mais recentes no Maven Central
    local spotbugs_ver findsecbugs_ver
    spotbugs_ver="$(_spotbugs_resolve_version "com/github/spotbugs" "spotbugs-maven-plugin" "${SPOTBUGS_PLUGIN_VERSION:-}")"
    findsecbugs_ver="$(_spotbugs_resolve_version "com/h3xstream/findsecbugs" "findsecbugs-plugin" "${FINDSECBUGS_PLUGIN_VERSION:-}")"

    log_step_header "$label" "$desc"

    # 5. Compilação estrita das classes modificadas
    log_substep "Compilando classes para análise SAST" mvn test-compile -q -DskipTests
    local compile_exit=$?
    if [[ $compile_exit -ne 0 ]]; then
        log_step "$label" "$desc" "FAIL" "Falha na compilação"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Falha na compilação" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "Falha ao compilar classes para SpotBugs"
        log_show_last
        return $compile_exit
    fi

    # 6. Execução estrita do SpotBugs + FindSecBugs apenas nas classes modificadas
    log_substep "Executando SpotBugs v${spotbugs_ver} + FindSecBugs v${findsecbugs_ver} (${#unique_classes[@]} classe(s))" \
        mvn com.github.spotbugs:spotbugs-maven-plugin:"${spotbugs_ver}":check \
            -Dspotbugs.effort=max \
            -Dspotbugs.threshold=medium \
            -Dspotbugs.failOnError=true \
            -Dspotbugs.plugins=com.h3xstream.findsecbugs:findsecbugs-plugin:"${findsecbugs_ver}" \
            -Dspotbugs.onlyAnalyze="$class_filter" \
            -DonlyAnalyze="$class_filter" -q
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cache_save "spotbugs" "$hash"
        local detail_msg="${#unique_classes[@]} classe(s)"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "$detail_msg" > "$_CURRENT_ENGINE_DETAIL_FILE"
        log_step "$label" "$desc" "OK" "$detail_msg"
        summary_add "$desc" "OK" "$detail_msg"
    else
        local detail_msg="Vulnerabilidades em ${#unique_classes[@]} classe(s)"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "$detail_msg" > "$_CURRENT_ENGINE_DETAIL_FILE"
        log_step "$label" "$desc" "FAIL" "$detail_msg"
        summary_add "$desc" "FAIL" "Vulnerabilidades SAST detectadas pelo SpotBugs"
        log_show_last
    fi
    return $exit_code
}
