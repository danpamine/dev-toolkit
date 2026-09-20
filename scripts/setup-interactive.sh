#!/usr/bin/env bash
# ==============================================================================
# setup-interactive.sh - Assistente Interativo com Configuração Total de Caminhos
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_CYAN=$'\033[1;36m' C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m' C_WHITE=$'\033[0;37m' C_DIM=$'\033[2m'
else
    C_RESET="" C_BOLD="" C_CYAN="" C_GREEN="" C_YELLOW="" C_WHITE="" C_DIM=""
fi

normalize_path() {
    local raw="$1"
    raw="${raw/#\~/$HOME}"
    cygpath -u "$raw" 2>/dev/null || echo "$raw"
}

ask_toggle() {
    local name="$1"
    local default="${2:-1}"
    local prompt_val="S/n"
    [[ "$default" == "0" ]] && prompt_val="s/N"
    read -r -p "    Habilitar ${name}? [${prompt_val}]: " ans
    if [[ -z "$ans" ]]; then
        echo "$default"
    elif [[ "$ans" =~ ^[Ss]$ ]]; then
        echo "1"
    else
        echo "0"
    fi
}

clear 2>/dev/null || true
printf "${C_CYAN}======================================================================${C_RESET}\n"
printf "${C_CYAN}         ASSISTENTE DE CONFIGURAÇÃO INTERATIVA — DEV TOOLKIT         ${C_RESET}\n"
printf "${C_CYAN}======================================================================${C_RESET}\n\n"
printf "Configure seus diretórios, caminhos de dependências e regras por stack.\n"
printf "Preferências salvas localmente em ${C_DIM}env/<stack>/.env.user${C_RESET} (fora do Git).\n\n"

# ==============================================================================
# 1. ESCOLHA DE STACKS ATIVAS
# ==============================================================================
printf "${C_BOLD}[1/4] QUAIS STACKS VOCÊ UTILIZA NESTA MÁQUINA?${C_RESET}\n"
printf "  ${C_CYAN}1)${C_RESET} Java e Angular (Ambos)\n"
printf "  ${C_CYAN}2)${C_RESET} Apenas Java (pom.xml)\n"
printf "  ${C_CYAN}3)${C_RESET} Apenas Angular (angular.json)\n"
read -r -p "Selecione a opção [1]: " stack_choice
stack_choice="${stack_choice:-1}"

ENABLE_JAVA=0
ENABLE_ANGULAR=0

case "$stack_choice" in
    2) ENABLE_JAVA=1 ;;
    3) ENABLE_ANGULAR=1 ;;
    *) ENABLE_JAVA=1; ENABLE_ANGULAR=1 ;;
esac
printf "${C_GREEN}✓ Stack selecionada.${C_RESET}\n\n"

# ==============================================================================
# 2. DIRETÓRIOS DE PROJETOS E DEPENDÊNCIAS DO TOOLKIT
# ==============================================================================
printf "${C_BOLD}[2/4] DEFINIÇÃO DE DIRETÓRIOS E DEPENDÊNCIAS${C_RESET}\n"

# 2.1 Repositórios de Trabalho
default_proj_dir="$HOME/Development"
[[ -d "/c/Users/$USERNAME/Development" ]] && default_proj_dir="/c/Users/$USERNAME/Development"
printf "1. Onde estão localizados seus repositórios Git de trabalho?\n"
read -r -p "   Diretório dos Projetos [$default_proj_dir]: " in_proj_dir
PROJECTS_DIR=$(normalize_path "${in_proj_dir:-$default_proj_dir}")
printf "   ${C_GREEN}↳ Definido: %s${C_RESET}\n\n" "$PROJECTS_DIR"

# 2.2 Binários CLI
default_bin_dir="$HOME/.local/bin"
printf "2. Onde devem ser armazenados os binários das ferramentas (Gitleaks, Trivy, OSV, ast-grep, GJF)?\n"
read -r -p "   Diretório de Binários [$default_bin_dir]: " in_bin_dir
LOCAL_BIN_DIR=$(normalize_path "${in_bin_dir:-$default_bin_dir}")
printf "   ${C_GREEN}↳ Definido: %s${C_RESET}\n\n" "$LOCAL_BIN_DIR"

# 2.3 Python Portátil
default_py_dir="${TOOLKIT_ROOT}/dependencies/python"
printf "3. Onde deve ser instalado o Python Portátil e Semgrep?\n"
read -r -p "   Diretório do Python [$default_py_dir]: " in_py_dir
PYTHON_DIR=$(normalize_path "${in_py_dir:-$default_py_dir}")
printf "   ${C_GREEN}↳ Definido: %s${C_RESET}\n\n" "$PYTHON_DIR"

# 2.4 Cache
default_cache_dir="/tmp/cicd_cache"
printf "4. Onde deve ser salvo o cache de execuções e TTL de 3 horas?\n"
read -r -p "   Diretório de Cache [$default_cache_dir]: " in_cache_dir
CACHE_DIR=$(normalize_path "${in_cache_dir:-$default_cache_dir}")
printf "   ${C_GREEN}↳ Definido: %s${C_RESET}\n\n" "$CACHE_DIR"

# 2.5 Angular Store e Node (somente se Angular ativo)
SETUP_NODE=0
PNPM_STORE_DIR=""
if [[ "$ENABLE_ANGULAR" -eq 1 ]]; then
    printf "5. Deseja configurar NVS + Node.js LTS + pnpm nesta máquina? [S/n]: "
    read -r input_node
    input_node="${input_node:-s}"
    [[ "$input_node" =~ ^[Ss]$ ]] && SETUP_NODE=1

    default_store_dir="${TOOLKIT_ROOT}/dependencies/pnpm-store"
    printf "6. Onde deve ficar a Store Global de pacotes do pnpm (pnpm-store)?\n"
    read -r -p "   Diretório do pnpm-store [$default_store_dir]: " in_store_dir
    PNPM_STORE_DIR=$(normalize_path "${in_store_dir:-$default_store_dir}")
    printf "   ${C_GREEN}↳ Definido: %s${C_RESET}\n\n" "$PNPM_STORE_DIR"
fi

# ==============================================================================
# 3. CONFIGURAÇÃO DA STACK JAVA
# ==============================================================================
if [[ "$ENABLE_JAVA" -eq 1 ]]; then
    printf "${C_BOLD}[3/4] CONFIGURAÇÃO JAVA (pom.xml)${C_RESET}\n"
    read -r -p "Branch Base de destino para Java [develop]: " java_base_in
    JAVA_BASE="${java_base_in:-develop}"
    printf "${C_GREEN}✓ Branch base Java: %s${C_RESET}\n\n" "$JAVA_BASE"

    printf "Escolha o perfil de validação Java:\n"
    printf "  ${C_CYAN}1)${C_RESET} Completo (SAST, SCA, Linters, Testes e Version Check)\n"
    printf "  ${C_CYAN}2)${C_RESET} Rápido (Sem SpotBugs e Trivy profundo)\n"
    printf "  ${C_CYAN}3)${C_RESET} Personalizado (Escolher ferramenta por ferramenta)\n"
    read -r -p "Perfil Java [1]: " java_prof
    java_prof="${java_prof:-1}"

    J_VERSION=1 J_GITLEAKS=1 J_SEMGREP=1 J_AST=1 J_OSV=1 J_TRIVY=1
    J_SPOTBUGS=1 J_PMD=1 J_CHECKSTYLE=1 J_FORMAT=1 J_OPENAPI=1 J_VERIFY=1

    case "$java_prof" in
        2)
            J_SPOTBUGS=0 J_TRIVY=0
            printf "${C_GREEN}✓ Perfil Java Rápido configurado.${C_RESET}\n\n"
            ;;
        3)
            printf "\n${C_DIM}Selecione as validações Java ativas:${C_RESET}\n"
            J_VERSION=$(ask_toggle "Validação de Incremento de Versão (pom.xml)" 1)
            J_GITLEAKS=$(ask_toggle "Gitleaks (Varredura de Segredos)" 1)
            J_SEMGREP=$(ask_toggle "Semgrep (SAST Semântico)" 1)
            J_AST=$(ask_toggle "ast-grep (Linter Estrutural)" 1)
            J_OSV=$(ask_toggle "Google OSV-Scanner (SCA Rápido)" 1)
            J_TRIVY=$(ask_toggle "Trivy (SCA Completo)" 1)
            J_SPOTBUGS=$(ask_toggle "SpotBugs + FindSecBugs (Java SAST)" 1)
            J_PMD=$(ask_toggle "PMD (Qualidade de Código)" 1)
            J_CHECKSTYLE=$(ask_toggle "Checkstyle (Regras de Estilo)" 1)
            J_FORMAT=$(ask_toggle "Google Java Format (Auto-formatação)" 1)
            J_OPENAPI=$(ask_toggle "OpenAPI Contract Validator" 1)
            J_VERIFY=$(ask_toggle "Maven Verify (Testes unitários e JaCoCo)" 1)
            printf "${C_GREEN}✓ Validações Java personalizadas salvas.${C_RESET}\n\n"
            ;;
        *)
            printf "${C_GREEN}✓ Perfil Java Completo configurado.${C_RESET}\n\n"
            ;;
    esac
fi

# ==============================================================================
# 4. CONFIGURAÇÃO DA STACK ANGULAR
# ==============================================================================
if [[ "$ENABLE_ANGULAR" -eq 1 ]]; then
    printf "${C_BOLD}[4/4] CONFIGURAÇÃO ANGULAR (angular.json)${C_RESET}\n"
    read -r -p "Branch Base de destino para Angular [develop]: " ng_base_in
    NG_BASE="${ng_base_in:-develop}"
    printf "${C_GREEN}✓ Branch base Angular: %s${C_RESET}\n\n" "$NG_BASE"

    printf "Escolha o perfil de validação Angular:\n"
    printf "  ${C_CYAN}1)${C_RESET} Completo (ESLint, Prettier, SCA, Testes e Version Check)\n"
    printf "  ${C_CYAN}2)${C_RESET} Rápido (Sem Trivy profundo e Builds pesados)\n"
    printf "  ${C_CYAN}3)${C_RESET} Personalizado (Escolher ferramenta por ferramenta)\n"
    read -r -p "Perfil Angular [1]: " ng_prof
    ng_prof="${ng_prof:-1}"

    NG_VERSION=1 NG_GITLEAKS=1 NG_SEMGREP=1 NG_AST=1 NG_OSV=1 NG_TRIVY=1
    NG_PRETTIER=1 NG_LOCKFILE=1 NG_ESLINT=1 NG_BUILD=1 NG_TEST=1

    case "$ng_prof" in
        2)
            NG_TRIVY=0 NG_BUILD=0
            printf "${C_GREEN}✓ Perfil Angular Rápido configurado.${C_RESET}\n\n"
            ;;
        3)
            printf "\n${C_DIM}Selecione as validações Angular ativas:${C_RESET}\n"
            NG_VERSION=$(ask_toggle "Validação de Incremento de Versão (package.json)" 1)
            NG_GITLEAKS=$(ask_toggle "Gitleaks (Varredura de Segredos)" 1)
            NG_SEMGREP=$(ask_toggle "Semgrep (SAST Semântico)" 1)
            NG_AST=$(ask_toggle "ast-grep (Linter Estrutural)" 1)
            NG_OSV=$(ask_toggle "Google OSV-Scanner (SCA package-lock)" 1)
            NG_TRIVY=$(ask_toggle "Trivy (SCA Completo)" 1)
            NG_ESLINT=$(ask_toggle "ESLint (Regras e Boas Práticas)" 1)
            NG_PRETTIER=$(ask_toggle "Prettier (Auto-formatação)" 1)
            NG_LOCKFILE=$(ask_toggle "Sincronização de Lockfile" 1)
            NG_BUILD=$(ask_toggle "Build Angular (ng build)" 1)
            NG_TEST=$(ask_toggle "Testes Unitários (package.json)" 1)
            printf "${C_GREEN}✓ Validações Angular personalizadas salvas.${C_RESET}\n\n"
            ;;
        *)
            printf "${C_GREEN}✓ Perfil Angular Completo configurado.${C_RESET}\n\n"
            ;;
    esac
fi

# ==============================================================================
# GRAVAÇÃO DAS CONFIGURAÇÕES EM ENV/
# ==============================================================================
mkdir -p "${TOOLKIT_ROOT}/env/java" "${TOOLKIT_ROOT}/env/angular"

# 1. Caminhos Globais Comuns
COMMON_ENV_FILE="${TOOLKIT_ROOT}/env/.env.user"
cat > "$COMMON_ENV_FILE" << EOF
# Configurações Globais de Diretórios do Desenvolvedor (Não rastreado pelo Git)
export LOCAL_BIN="${LOCAL_BIN_DIR}"
export DEV_TOOLKIT_PYTHON_DIR="${PYTHON_DIR}"
export DEV_TOOLKIT_CACHE_DIR="${CACHE_DIR}"
EOF

# 2. Configurações Java
if [[ "$ENABLE_JAVA" -eq 1 ]]; then
    JAVA_ENV_FILE="${TOOLKIT_ROOT}/env/java/.env.user"
    cat > "$JAVA_ENV_FILE" << EOF
# Configurações do Desenvolvedor — Java (Não rastreado pelo Git)
export BASE_BRANCH="${JAVA_BASE}"

export FEATURE_VERSION_CHECK=${J_VERSION}
export FEATURE_GITLEAKS=${J_GITLEAKS}
export FEATURE_GITLEAKS_PULL=${J_GITLEAKS}
export FEATURE_SEMGREP=${J_SEMGREP}
export FEATURE_AST_GREP=${J_AST}
export FEATURE_OSV=${J_OSV}
export FEATURE_SCA=${J_TRIVY}
export FEATURE_CHECKSTYLE=${J_CHECKSTYLE}
export FEATURE_JAVA_FORMAT=${J_FORMAT}
export FEATURE_PMD=${J_PMD}
export FEATURE_SPOTBUGS=${J_SPOTBUGS}
export FEATURE_OPENAPI=${J_OPENAPI}
export FEATURE_MAVEN_VERIFY=${J_VERIFY}
EOF
else
    rm -f "${TOOLKIT_ROOT}/env/java/.env.user" 2>/dev/null || true
fi

# 3. Configurações Angular
if [[ "$ENABLE_ANGULAR" -eq 1 ]]; then
    ANGULAR_ENV_FILE="${TOOLKIT_ROOT}/env/angular/.env.user"
    cat > "$ANGULAR_ENV_FILE" << EOF
# Configurações do Desenvolvedor — Angular (Não rastreado pelo Git)
export BASE_BRANCH="${NG_BASE}"
export DEV_TOOLKIT_STORE_DIR="${PNPM_STORE_DIR}"

export FEATURE_VERSION_CHECK=${NG_VERSION}
export FEATURE_GITLEAKS=${NG_GITLEAKS}
export FEATURE_GITLEAKS_PULL=${NG_GITLEAKS}
export FEATURE_SEMGREP=${NG_SEMGREP}
export FEATURE_AST_GREP=${NG_AST}
export FEATURE_OSV=${NG_OSV}
export FEATURE_SCA=${NG_TRIVY}
export FEATURE_PRETTIER=${NG_PRETTIER}
export FEATURE_LOCKFILE=${NG_LOCKFILE}
export FEATURE_ESLINT=${NG_ESLINT}
export FEATURE_BUILD=${NG_BUILD}
export FEATURE_TEST=${NG_TEST}
EOF
else
    rm -f "${TOOLKIT_ROOT}/env/angular/.env.user" 2>/dev/null || true
fi

# ==============================================================================
# APLICAÇÃO NO AMBIENTE
# ==============================================================================
printf "${C_CYAN}Aplicando configurações no sistema...${C_RESET}\n"

# Carrega variáveis geradas para o subshell atual
source "$COMMON_ENV_FILE" 2>/dev/null || true
[[ "$ENABLE_ANGULAR" -eq 1 ]] && source "${TOOLKIT_ROOT}/env/angular/.env.user" 2>/dev/null || true

# Atualiza ~/.bashrc
bash "$TOOLKIT_ROOT/scripts/setup-bashrc.sh"

# Configura Node se selecionado
if [[ "$SETUP_NODE" -eq 1 ]]; then
    printf "\n"
    bash "$TOOLKIT_ROOT/scripts/setup-node.sh"
fi

# Instala Git Hooks
if [[ -d "$PROJECTS_DIR" ]]; then
    printf "\n"
    bash "$TOOLKIT_ROOT/scripts/install-hooks.sh" "$PROJECTS_DIR"
fi

printf "\n${C_GREEN}======================================================================${C_RESET}\n"
printf "${C_GREEN}               CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!                   ${C_RESET}\n"
printf "${C_GREEN}======================================================================${C_RESET}\n\n"
printf "  • Binários:    %s\n" "$LOCAL_BIN_DIR"
printf "  • Python:      %s\n" "$PYTHON_DIR"
printf "  • Cache:       %s\n" "$CACHE_DIR"
[[ "$ENABLE_JAVA" -eq 1 ]] && printf "  • Java:        Base [${C_BOLD}%s${C_RESET}] em env/java/.env.user\n" "$JAVA_BASE"
if [[ "$ENABLE_ANGULAR" -eq 1 ]]; then
    printf "  • Angular:     Base [${C_BOLD}%s${C_RESET}] em env/angular/.env.user\n" "$NG_BASE"
    printf "  • pnpm-store:  %s\n" "$PNPM_STORE_DIR"
fi
printf "\nExecute para recarregar a sessão do terminal:\n"
printf "  ${C_CYAN}source ~/.bashrc${C_RESET}\n\n"
