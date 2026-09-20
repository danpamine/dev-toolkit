#!/usr/bin/env bash
# ==============================================================================
# env.sh - Carregamento Hierárquico de Configurações e Diretórios Customizados
# ==============================================================================

env_load() {
    local toolkit_root="${TOOLKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    # 1. Configurações globais de caminhos (LOCAL_BIN, PYTHON_DIR, CACHE_DIR)
    if [[ -f "$toolkit_root/env/.env.user" ]]; then
        source "$toolkit_root/env/.env.user"
    fi

    # 2. Stack Java: carrega definições e branch base específicas de Java
    if [[ -f "pom.xml" ]]; then
        [[ -f "$toolkit_root/env/java/global.env" ]] && source "$toolkit_root/env/java/global.env"
        [[ -f "$toolkit_root/env/java/.env.user" ]] && source "$toolkit_root/env/java/.env.user"
    fi

    # 3. Stack Angular: carrega definições, store do pnpm e branch base específicas de Angular
    if [[ -f "angular.json" ]]; then
        [[ -f "$toolkit_root/env/angular/global.env" ]] && source "$toolkit_root/env/angular/global.env"
        [[ -f "$toolkit_root/env/angular/.env.user" ]] && source "$toolkit_root/env/angular/.env.user"
    fi

    # 4. Overrides locais do repositório atual (se houver)
    if [[ -f ".env.local" ]]; then
        source ".env.local"
    fi

    # Garante que o diretório customizado de binários esteja sempre no PATH
    export LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
    export PATH="$LOCAL_BIN:$PATH"
}
