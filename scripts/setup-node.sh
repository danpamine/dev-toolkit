#!/usr/bin/env bash
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_HOME="$(dirname "$SCRIPT_DIR")"
if [[ -t 1 ]]; then
    C_OK='\033[0;32m' C_INFO='\033[0;36m' C_WARN='\033[0;33m'
    C_ERR='\033[0;31m' C_RESET='\033[0m' C_BOLD='\033[1m'
else
    C_OK='' C_INFO='' C_WARN='' C_ERR='' C_RESET='' C_BOLD=''
fi
NVS_HOME="$HOME/.nvs"
BASHRC="$HOME/.bashrc"
LOCAL_BIN="$HOME/.local/bin"
echo ""
echo -e "${C_BOLD}  Setup: NVS + Node.js LTS + pnpm${C_RESET}"
echo ""
# ── 0. Rede corporativa ──
git config --global http.sslBackend schannel 2>/dev/null || true
export CURL_SSL_NO_REVOKE=1
# ── 1. NVS ──
echo -e "${C_INFO}[1/7]${C_RESET} NVS..."
if [[ -f "$NVS_HOME/nvs.sh" ]] && . "$NVS_HOME/nvs.sh" 2>/dev/null && nvs --version &>/dev/null; then
    echo -e "${C_OK}[OK]${C_RESET} NVS já existe ($(nvs --version 2>/dev/null || echo '?'))"
else
    echo -e "${C_WARN}[INFO]${C_RESET} NVS ausente ou corrompido, clonando..."
    rm -rf "$NVS_HOME"
    git clone https://github.com/jasongin/nvs "$NVS_HOME"
    echo -e "${C_OK}[OK]${C_RESET} NVS clonado"
fi
# ── 2. .bashrc (idempotente) ──
echo ""
echo -e "${C_INFO}[2/7]${C_RESET} .bashrc..."
# Garante .bash_profile → .bashrc
if [[ ! -f "$HOME/.bash_profile" ]]; then
    echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > "$HOME/.bash_profile"
fi
# Remove bloco NVS antigo (qualquer versão)
sed -i '/# >>> NVS >>>/,/# <<< NVS <<</d' "$BASHRC" 2>/dev/null || true
sed -i '/^# NVS — Node Version Switcher$/d' "$BASHRC" 2>/dev/null || true
sed -i '/^export NVS_HOME/d' "$BASHRC" 2>/dev/null || true
sed -i '/^\[ -s "\$NVS_HOME\/nvs\.sh" \]/d' "$BASHRC" 2>/dev/null || true
sed -i '/^# ~\/\.local\/bin no PATH/d' "$BASHRC" 2>/dev/null || true
sed -i '/^export PATH="\$HOME\/\.local\/bin:\$PATH"/d' "$BASHRC" 2>/dev/null || true
sed -i '/function setupNvs/,/^setupNvs$/d' "$BASHRC" 2>/dev/null || true
sed -i '/^setupNvs$/d' "$BASHRC" 2>/dev/null || true
sed -i '/NVS_PATH_PRECEDENCE/d' "$BASHRC" 2>/dev/null || true
sed -i '/_nvs_node_path/d' "$BASHRC" 2>/dev/null || true
# Adiciona bloco limpo
cat >> "$BASHRC" << 'EOF'
# >>> NVS >>>
export NVS_HOME="$HOME/.nvs"
[ -s "$NVS_HOME/nvs.sh" ] && . "$NVS_HOME/nvs.sh"
export PATH="$HOME/.local/bin:$PATH"
# <<< NVS <<<
EOF
echo -e "${C_OK}[OK]${C_RESET} .bashrc configurado"
# ── 3. Source nvs.sh ──
echo ""
echo -e "${C_INFO}[3/7]${C_RESET} Carregando NVS..."
export NVS_HOME="$NVS_HOME"
set +u
. "$NVS_HOME/nvs.sh"
set -u
echo -e "${C_OK}[OK]${C_RESET} NVS carregado"
# ── 4. Node LTS ──
echo ""
echo -e "${C_INFO}[4/7]${C_RESET} Node.js LTS..."
CURRENT_NODE=$(node --version 2>/dev/null || echo "")
if [[ "$CURRENT_NODE" =~ ^v(2[2-9]|[3-9][0-9]) ]]; then
    echo -e "${C_OK}[OK]${C_RESET} Node.js $CURRENT_NODE já ativo"
else
    echo -e "${C_INFO}[INFO]${C_RESET} Node atual: ${CURRENT_NODE:-nenhum}. Instalando LTS..."
    nvs add lts
    nvs use lts
    nvs link lts
    CURRENT_NODE=$(node --version 2>/dev/null || echo "")
    if [[ ! "$CURRENT_NODE" =~ ^v(2[2-9]|[3-9][0-9]) ]]; then
        echo -e "${C_ERR}[ERRO]${C_RESET} Node.js LTS não ativado (ainda: ${CURRENT_NODE:-vazio})"
        echo "  PATH atual:"
        echo "$PATH" | tr ':' '\n' | head -10
        exit 1
    fi
    echo -e "${C_OK}[OK]${C_RESET} Node.js: $CURRENT_NODE"
fi
NPM_VERSION=$(npm --version 2>/dev/null || echo "")
echo -e "${C_OK}[OK]${C_RESET} npm: $NPM_VERSION"
# ── 5. pnpm via corepack ──
echo ""
echo -e "${C_INFO}[5/7]${C_RESET} pnpm via corepack..."
mkdir -p "$LOCAL_BIN"
corepack enable --install-directory "$LOCAL_BIN"
corepack prepare pnpm@latest --activate
PNPM_VERSION=$(pnpm --version 2>/dev/null || echo "")
if [[ -z "$PNPM_VERSION" ]]; then
    echo -e "${C_WARN}[WARN]${C_RESET} pnpm não disponível, criando wrapper..."
    cat > "$LOCAL_BIN/pnpm" << 'WRAPPER'
#!/usr/bin/env bash
exec corepack pnpm "$@"
WRAPPER
    chmod +x "$LOCAL_BIN/pnpm"
    PNPM_VERSION=$(pnpm --version 2>/dev/null || echo "")
fi
if [[ -n "$PNPM_VERSION" ]]; then
    echo -e "${C_OK}[OK]${C_RESET} pnpm: $PNPM_VERSION"
else
    echo -e "${C_ERR}[ERRO]${C_RESET} pnpm não pôde ser ativado"
    exit 1
fi
# ── 6. Store global + .npmrc + pnpm-workspace.yaml ──
echo ""
echo -e "${C_INFO}[6/7]${C_RESET} Store global..."
STORE_DIR="$TOOLKIT_HOME/dependencies/pnpm-store"
mkdir -p "$STORE_DIR"
pnpm config set store-dir "$STORE_DIR" 2>/dev/null || true
# Força hard links no Windows (MINGW64/Git Bash não detecta automaticamente)
pnpm config set package-import-method hardlink 2>/dev/null || true
NPMRC="$TOOLKIT_HOME/config/angular/.npmrc"
cat > "$NPMRC" << EOF
# .npmrc - dev-toolkit Angular (global para todos os projetos)
registry=https://registry.npmjs.org/
strict-ssl=true
fund=false
audit-level=moderate
store-dir=$STORE_DIR
node-linker=hoisted
lockfile=true
package-import-method=hardlink
EOF
# Gera pnpm-workspace.yaml global com allowBuilds explícito
WORKSPACE_FILE="$TOOLKIT_HOME/config/angular/pnpm-workspace.yaml"
cat > "$WORKSPACE_FILE" << 'EOF'
# pnpm-workspace.yaml - dev-toolkit Angular (global para todos os projetos)
# Aprova builds de pacotes nativos necessários para Angular CLI
allowBuilds:
  '@parcel/watcher': true
  esbuild: true
  lmdb: true
  msgpackr-extract: true
EOF
echo -e "${C_OK}[OK]${C_RESET} Store: $STORE_DIR"
echo -e "${C_OK}[OK]${C_RESET} node-linker: hoisted"
echo -e "${C_OK}[OK]${C_RESET} lockfile: true"
echo -e "${C_OK}[OK]${C_RESET} package-import-method: hardlink"
echo -e "${C_OK}[OK]${C_RESET} allowBuilds: pnpm-workspace.yaml"
# ── 7. Resumo ──
echo ""
echo -e "${C_BOLD}  Setup completo${C_RESET}"
echo "  Node.js:  $CURRENT_NODE (via NVS)"
echo "  npm:      $NPM_VERSION"
echo "  pnpm:     $PNPM_VERSION"
echo "  Store:    $STORE_DIR"
echo ""
