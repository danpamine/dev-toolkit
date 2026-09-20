#!/usr/bin/env bash
# ==============================================================================
# commands.sh - Desacoplamento e Customização de Scripts de Execução
# ==============================================================================

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
