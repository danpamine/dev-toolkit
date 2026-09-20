#!/usr/bin/env bash
# ==============================================================================
# run-tests.sh - Testes Unitários e de Integração do Dev Toolkit
# ==============================================================================

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(dirname "$TEST_DIR")"
SANDBOX="/tmp/dev_toolkit_tests_$$"

C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_RESET='\033[0m'
_PASSED=0
_FAILED=0

assert() {
    local expected="$1"
    local actual="$2"
    local desc="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf "  ${C_GREEN}[PASS]${C_RESET} %s\n" "$desc"
        ((_PASSED++))
    else
        printf "  ${C_RED}[FAIL]${C_RESET} %s (Esperado: '%s', Obtido: '%s')\n" "$desc" "$expected" "$actual"
        ((_FAILED++))
    fi
}

setup() {
    rm -rf "$SANDBOX"
    mkdir -p "$SANDBOX"
    cd "$SANDBOX" || exit 1
    git init --quiet -b main
    git config user.name "Toolkit Tester"
    git config user.email "tester@toolkit.corp"
}

teardown() {
    cd "$TOOLKIT_ROOT" || exit 1
    rm -rf "$SANDBOX"
}

test_cache_ttl() {
    printf "\n--- Teste 1: Validação do Cache e TTL de 3 horas ---\n"
    source "$TOOLKIT_ROOT/lib/common/cache.sh"
    cache_init "repo_test"

    echo "payload" > dummy.txt
    local h
    h=$(sha256sum dummy.txt | awk '{print $1}')
    cache_save "scope_a" "$h"

    assert "0" "$(cache_is_valid "scope_a" "$h" 10800; echo $?)" "Cache com menos de 3h deve ser válido"

    local done_f="${_CACHE_REPO_DIR}/scope_a.done"
    touch -d "4 hours ago" "$done_f" 2>/dev/null || touch -t 202001010000 "$done_f"
    assert "1" "$(cache_is_valid "scope_a" "$h" 10800; echo $?)" "Cache expirado após 3h deve retornar 1"
}

test_toggles() {
    printf "\n--- Teste 2: Feature Toggles e Reenumeração Dinâmica ---\n"
    source "$TOOLKIT_ROOT/lib/common/logging.sh"
    source "$TOOLKIT_ROOT/lib/common/summary.sh"
    source "$TOOLKIT_ROOT/lib/common/engine.sh"

    mock_ok() { return 0; }
    export FEATURE_TEST_ONE=1
    export FEATURE_TEST_TWO=0

    engine_reset
    engine_register "step1" "Etapa Ativa" mock_ok "FEATURE_TEST_ONE"
    engine_register "step2" "Etapa Inativa" mock_ok "FEATURE_TEST_TWO"

    assert "0" "$(engine_is_enabled "FEATURE_TEST_ONE"; echo $?)" "Toggle Ativo deve retornar 0"
    assert "1" "$(engine_is_enabled "FEATURE_TEST_TWO"; echo $?)" "Toggle Inativo deve retornar 1"
}

test_angular_test_resolution() {
    printf "\n--- Teste 3: Resolução de Teste Angular & Java (Sem arquivos de teste) ---\n"
    source "$TOOLKIT_ROOT/lib/common/commands.sh"

    echo '{"name": "mock-app"}' > package.json
    run_angular_test
    assert "0" "$?" "Deve finalizar com sucesso se não houver script no package.json"

    echo '{"name": "mock-app", "scripts": {"test": "exit 1"}}' > package.json
    mkdir -p src
    run_angular_test
    assert "0" "$?" "Deve finalizar com sucesso se script existir mas não houver arquivos físicos"

    run_java_verify
    assert "0" "$?" "Deve finalizar com sucesso em Java se não houver arquivos em src/test/java"
}

test_version_increments() {
    printf "\n--- Teste 4: Validação de Incremento Estrito vs. Branch Base Remota ---\n"
    source "$TOOLKIT_ROOT/lib/common/logging.sh"
    source "$TOOLKIT_ROOT/lib/common/summary.sh"
    source "$TOOLKIT_ROOT/lib/common/git-diff.sh"
    source "$TOOLKIT_ROOT/lib/java/version-check.sh"

    echo '<project><modelVersion>4.0.0</modelVersion><groupId>br.com.corp</groupId><artifactId>app</artifactId><version>1.0.0-SNAPSHOT</version></project>' > pom.xml
    git add pom.xml
    git commit -m "base commit" --quiet

    git checkout -b feature/minha-tarefa --quiet
    export BASE_BRANCH="main"

    # Caso A: Versão idêntica -> DEVE FALHAR (retornar 1)
    step_version_check "STEP" "Versão Pom" >/dev/null 2>&1
    assert "1" "$?" "Versão idêntica à base deve falhar (1.0.0-SNAPSHOT == 1.0.0-SNAPSHOT)"

    # Caso B: Versão inferior -> DEVE FALHAR (retornar 1)
    echo '<project><modelVersion>4.0.0</modelVersion><groupId>br.com.corp</groupId><artifactId>app</artifactId><version>0.9.0-SNAPSHOT</version></project>' > pom.xml
    step_version_check "STEP" "Versão Pom" >/dev/null 2>&1
    assert "1" "$?" "Versão regredida deve falhar (0.9.0-SNAPSHOT < 1.0.0-SNAPSHOT)"

    # Caso C: Versão incrementada -> DEVE PASSAR (retornar 0)
    echo '<project><modelVersion>4.0.0</modelVersion><groupId>br.com.corp</groupId><artifactId>app</artifactId><version>1.0.1-SNAPSHOT</version></project>' > pom.xml
    step_version_check "STEP" "Versão Pom" >/dev/null 2>&1
    assert "0" "$?" "Versão incrementada deve ser aprovada (1.0.0-SNAPSHOT -> 1.0.1-SNAPSHOT)"
}

test_async_failures() {
    printf "\n--- Teste 5: Isolamento de Logs em Falhas Concorrentes ---\n"
    source "$TOOLKIT_ROOT/lib/common/logging.sh"
    source "$TOOLKIT_ROOT/lib/common/summary.sh"
    source "$TOOLKIT_ROOT/lib/common/engine.sh"

    mock_fail_1() { echo "Erro critico 1"; return 1; }
    mock_fail_2() { echo "Erro critico 2"; return 1; }

    export TOGGLE_F1=1
    export TOGGLE_F2=1

    engine_reset
    engine_register "fail1" "Validação Falha 1" mock_fail_1 "TOGGLE_F1"
    engine_register "fail2" "Validação Falha 2" mock_fail_2 "TOGGLE_F2"

    local log_out="/tmp/async_out_$$.log"
    engine_run "TESTE FALHAS CONCORRENTES" > "$log_out" 2>&1
    summary_print "RESUMO TESTE" "OK" "FAIL" >> "$log_out" 2>&1

    local has_f1=0 has_f2=0
    grep -q "Erro critico 1" "$log_out" && has_f1=1
    grep -q "Erro critico 2" "$log_out" && has_f1=1
    rm -f "$log_out"

    assert "1" "$has_f1" "Log da falha 1 deve constar no relatório final"
    assert "1" "$has_f2" "Log da falha 2 deve constar no relatório final sem sobreposição"
}

test_spotbugs_incremental() {
    printf "\n--- Teste 6: SpotBugs Incremental (Ignora quando sem alterações Java) ---\n"
    source "$TOOLKIT_ROOT/lib/common/logging.sh"
    source "$TOOLKIT_ROOT/lib/common/summary.sh"
    source "$TOOLKIT_ROOT/lib/common/git-diff.sh"
    source "$TOOLKIT_ROOT/lib/java/spotbugs.sh"

    echo '<project></project>' > pom.xml
    step_spotbugs "STEP" "SpotBugs" >/dev/null 2>&1
    assert "0" "$?" "SpotBugs deve concluir com sucesso em 0s quando não houver arquivos Java alterados"
}

setup
test_cache_ttl
test_toggles
test_angular_test_resolution
test_version_increments
test_async_failures
test_spotbugs_incremental
teardown

printf "\n==================================================\n"
printf "Resultado: %d passaram, %d falharam.\n" "$_PASSED" "$_FAILED"
[[ $_FAILED -gt 0 ]] && exit 1
exit 0
