#!/usr/bin/env bash
# ==============================================================================
# commands.sh - Desacoplamento, Scripts e Resolução Dinâmica de Ferramentas
# ==============================================================================

maven_resolve_plugin_version() {
    local group_path="$1"
    local artifact="$2"
    local env_override="${3:-}"
    local local_bin="${LOCAL_BIN:-$HOME/.local/bin}"
    local version_file="${local_bin}/${artifact}.version"
    local m2_dir="${HOME}/.m2/repository/${group_path}/${artifact}"

    # 1. Override explícito via variável de ambiente (se o time quiser travar uma versão)
    if [[ -n "$env_override" ]]; then
        echo "$env_override"
        return 0
    fi

    # 2. Consulta a versão mais recente diretamente nos metadados do Maven Central
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

    local current_version=""
    [[ -f "$version_file" ]] && current_version="$(cat "$version_file" 2>/dev/null | tr -d '\r\n ')"

    # 3. Se identificou a versão mais recente na rede
    if [[ -n "$live_version" ]]; then
        # Se a versão local baixada for antiga, exclui do repositório local (~/.m2)
        if [[ -n "$current_version" && "$current_version" != "$live_version" ]]; then
            if [[ -d "${m2_dir}/${current_version}" ]]; then
                rm -rf "${m2_dir}/${current_version}" 2>/dev/null || true
            fi
        fi

        # Pré-baixa a versão mais recente para o cache local do Maven
        local group_id="${group_path//\//.}"
        mvn dependency:get -Dartifact="${group_id}:${artifact}:${live_version}" -q 2>/dev/null || true

        mkdir -p "$local_bin" 2>/dev/null || true
        echo "$live_version" > "$version_file" 2>/dev/null || true
        echo "$live_version"
        return 0
    fi

    # 4. Contingência Offline: se sem rede, usa a versão já baixada anteriormente
    if [[ -n "$current_version" && -d "${m2_dir}/${current_version}" ]]; then
        echo "$current_version"
        return 0
    fi

    # 5. Contingência Offline secundária: detecta última versão presente fisicamente no ~/.m2
    if [[ -d "$m2_dir" ]]; then
        local installed_version
        installed_version="$(find "$m2_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort -V | tail -1)"
        if [[ -n "$installed_version" ]]; then
            mkdir -p "$local_bin" 2>/dev/null || true
            echo "$installed_version" > "$version_file" 2>/dev/null || true
            echo "$installed_version"
            return 0
        fi
    fi

    echo ""
    return 1
}

run_java_build() {
    local default_cmd="mvn test-compile -q"
    local cmd="${JAVA_BUILD_CMD:-$default_cmd}"
    eval "$cmd"
}

run_java_verify() {
    if [[ -n "${JAVA_VERIFY_CMD:-}" ]]; then
        eval "$JAVA_VERIFY_CMD"
        return $?
    fi

    local has_test_files
    has_test_files=$(find src/test/java -type f -name "*.java" 2>/dev/null | head -1)

    if [[ -z "$has_test_files" ]]; then
        return 0
    fi

    local default_cmd="mvn test jacoco:report -q"
    eval "$default_cmd"
}

run_angular_build() {
    local default_cmd="npx ng build --configuration production"
    local cmd="${ANGULAR_BUILD_CMD:-$default_cmd}"
    eval "$cmd"
}

run_angular_test() {
    if [[ -n "${ANGULAR_TEST_CMD:-}" ]]; then
        eval "$ANGULAR_TEST_CMD"
        return $?
    fi

    local test_script
    test_script=$(node -p "
        try {
            const pkg = require('./package.json');
            pkg.scripts && pkg.scripts.test ? pkg.scripts.test : '';
        } catch(e) { ''; }
    " 2>/dev/null)

    if [[ -z "$test_script" || "$test_script" =~ "no test specified" ]]; then
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
            return 0
        fi
    fi

    local has_test_files
    has_test_files=$(find . -maxdepth 5 -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.git/*" -type f \( -name "*.spec.ts" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.test.js" \) 2>/dev/null | head -1)

    if [[ -z "$has_test_files" ]]; then
        return 0
    fi

    if command -v pnpm &>/dev/null; then
        CI=true pnpm test
    else
        CI=true npm test
    fi
}
