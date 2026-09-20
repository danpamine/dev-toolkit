#!/usr/bin/env bash
# ==============================================================================
# setup-node.sh - NVS + Node.js LTS + pnpm + Store Customizada
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(dirname "$SCRIPT_DIR")"

# Carrega preferências do usuário se existirem
[[ -f "$TOOLKIT_ROOT/env/.env.user" ]] && source "$TOOLKIT_ROOT/env/.env.user"
[[ -f "$TOOLKIT_ROOT/env/angular/.env.user" ]] && source "$TOOLKIT_ROOT/env/angular/.env.user"

echo ""
echo "  Setup: NVS + Node.js LTS + pnpm"
echo ""

# 1. NVS
echo "[1/7] NVS..."
export NVS_HOME="${NVS_HOME:-$HOME/.nvs}"
if [ ! -d "$NVS_HOME" ]; then
    echo "Clonando NVS..."
    git clone --depth 1 https://github.com/jasongin/nvs "$NVS_HOME"
    echo "[OK] NVS instalado em $NVS_HOME"
else
    echo "[OK] NVS já existe ($([ -f "$NVS_HOME/package.json" ] && grep '"version"' "$NVS_HOME/package.json" | head -1 | sed -E 's/.*"version": "([^"]+)".*/\1/' || echo 'instalado'))"
fi

# 2. .bashrc
echo ""
echo "[2/7] .bashrc..."
BASHRC="$HOME/.bashrc"
if ! grep -q 'NVS_HOME' "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# NVS (Node Version Switcher)
export NVS_HOME="$HOME/.nvs"
[ -s "$NVS_HOME/nvs.sh" ] && . "$NVS_HOME/nvs.sh"
EOF
    echo "[OK] NVS adicionado ao $BASHRC"
else
    echo "[OK] .bashrc configurado"
fi

# 3. Carregar NVS na sessão atual
echo ""
echo "[3/7] Carregando NVS..."
export NVS_HOME="$HOME/.nvs"
[ -s "$NVS_HOME/nvs.sh" ] && . "$NVS_HOME/nvs.sh"
echo "[OK] NVS carregado"

# 4. Node.js LTS
echo ""
echo "[4/7] Node.js LTS..."
CURRENT_NODE=$(node -v 2>/dev/null || echo "")
if [ -z "$CURRENT_NODE" ]; then
    echo "Instalando Node.js LTS..."
    nvs add lts
    nvs use lts
    nvs link lts
    echo "[OK] Node.js $(node -v) instalado"
else
    echo "[OK] Node.js $CURRENT_NODE já ativo"
fi
echo "[OK] npm: $(npm -v 2>/dev/null || echo 'N/A')"

# 5. pnpm via corepack
echo ""
echo "[5/7] pnpm via corepack..."
corepack enable 2>/dev/null || true
corepack prepare pnpm@latest --activate 2>/dev/null || true
echo "[OK] pnpm: $(pnpm -v 2>/dev/null || echo 'N/A')"

# 6. Store global configurada pelo desenvolvedor
echo ""
echo "[6/7] Store global..."
STORE_DIR="${DEV_TOOLKIT_STORE_DIR:-${TOOLKIT_ROOT}/dependencies/pnpm-store}"
mkdir -p "$STORE_DIR"
pnpm config set store-dir "$STORE_DIR" --global 2>/dev/null || true
pnpm config set node-linker hoisted --global 2>/dev/null || true
pnpm config set lockfile true --global 2>/dev/null || true
pnpm config set package-import-method hardlink --global 2>/dev/null || true

echo "[OK] Store: $STORE_DIR"
echo "[OK] node-linker: hoisted"
echo "[OK] lockfile: true"
echo "[OK] package-import-method: hardlink"

# 7. Resumo
echo ""
echo "  Setup completo"
echo "  Node.js:  $(node -v 2>/dev/null || echo 'N/A') (via NVS)"
echo "  npm:      $(npm -v 2>/dev/null || echo 'N/A')"
echo "  pnpm:     $(pnpm -v 2>/dev/null || echo 'N/A')"
echo "  Store:    $STORE_DIR"
echo ""
