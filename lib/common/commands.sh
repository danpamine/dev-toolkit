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
    local default_cmd="mvn test jacoco:report -q"
    local cmd="${JAVA_VERIFY_CMD:-$default_cmd}"
    eval "$cmd"
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

    # Garante execução não interativa via CI=true
    if command -v pnpm &>/dev/null; then
        CI=true pnpm test -- --watch=false
    else
        CI=true npm test -- --watch=false
    fi
}
