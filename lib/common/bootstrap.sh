#!/usr/bin/env bash
# ==============================================================================
# bootstrap.sh - Gerenciamento Dinâmico de Ferramentas
# ==============================================================================

_BOOTSTRAP_DONE=0

_bootstrap_download_latest() {
    local repo="$1"
    local asset_pattern="$2"
    local dest_path="$3"
    local friendly_name="$4"

    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local release_info
    release_info="$(curl -sL --max-time 5 "$api_url" 2>/dev/null)"

    if [[ -z "$release_info" ]] || echo "$release_info" | grep -q '"message": "Not Found"'; then
        [[ -f "$dest_path" ]] && return 0
        printf "${_C_ERROR}[BOOTSTRAP] Erro ao consultar release de %s${_C_RESET}\n" "$friendly_name"
        return 1
    fi

    local version_tag
    version_tag="$(echo "$release_info" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

    local download_url
    download_url="$(echo "$release_info" | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -iE "$asset_pattern" | head -1 | sed -E 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

    if [[ -z "$download_url" ]]; then
        [[ -f "$dest_path" ]] && return 0
        printf "${_C_ERROR}[BOOTSTRAP] Asset compatível não encontrado para %s${_C_RESET}\n" "$friendly_name"
        return 1
    fi

    local version_file="${dest_path}.version"
    if [[ -f "$dest_path" && -f "$version_file" && "$(cat "$version_file")" == "$version_tag" ]]; then
        return 0
    fi

    printf "${_C_INFO}[BOOTSTRAP]${_C_RESET} Baixando %s (%s)...\n" "$friendly_name" "$version_tag"
    local tmp_dir
    tmp_dir="$(mktemp -d 2>/dev/null || echo "/tmp/bt_${RANDOM}")"
    mkdir -p "$tmp_dir"
    local tmp_file="${tmp_dir}/pkg"

    if ! curl -sL --max-time 60 "$download_url" -o "$tmp_file" 2>/dev/null; then
        rm -rf "$tmp_dir"
        [[ -f "$dest_path" ]] && return 0
        return 1
    fi

    mkdir -p "$(dirname "$dest_path")"
    case "$download_url" in
        *.zip)
            local extract_dir="${tmp_dir}/extracted"
            mkdir -p "$extract_dir"
            unzip -o -q "$tmp_file" -d "$extract_dir" 2>/dev/null
            local binary
            binary="$(find "$extract_dir" -type f \( -name "$(basename "$dest_path")" -o -name "*.exe" \) 2>/dev/null | head -1)"
            if [[ -n "$binary" ]]; then
                cp "$binary" "$dest_path"
                chmod +x "$dest_path"
            fi
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$tmp_file" -C "$tmp_dir" 2>/dev/null
            local binary
            binary="$(find "$tmp_dir" -type f \( -name "$(basename "$dest_path")" -o -name "*.exe" \) 2>/dev/null | head -1)"
            if [[ -n "$binary" ]]; then
                cp "$binary" "$dest_path"
                chmod +x "$dest_path"
            fi
            ;;
        *)
            cp "$tmp_file" "$dest_path"
            chmod +x "$dest_path"
            ;;
    esac

    rm -rf "$tmp_dir"
    if [[ -f "$dest_path" ]]; then
        echo "$version_tag" > "$version_file"
        return 0
    fi
    return 1
}

bootstrap_python_portable() {
    local py_exe="${DEV_TOOLKIT_PYTHON_DIR}/python.exe"
    local version_file="${DEV_TOOLKIT_PYTHON_DIR}/python.version"

    # Busca a versão estável mais recente disponível no repositório de binários oficial
    local latest_py_ver
    latest_py_ver="$(curl -sL --max-time 5 "https://www.python.org/ftp/python/" 2>/dev/null | grep -oE 'href="3\.[0-9]+\.[0-9]+/' | sed 's#href="##;s#/##' | sort -V | tail -n 1)"
    [[ -z "$latest_py_ver" ]] && latest_py_ver="3.12.9"

    if [[ -f "$py_exe" && -f "$version_file" && "$(cat "$version_file")" == "$latest_py_ver" ]]; then
        return 0
    fi

    printf "${_C_INFO}[BOOTSTRAP]${_C_RESET} Configurando Python Portátil Latest Stable (%s)...\n" "$latest_py_ver"
    mkdir -p "$DEV_TOOLKIT_PYTHON_DIR"
    local tmp_zip="/tmp/py_portable_$$.zip"
    local py_url="https://www.python.org/ftp/python/${latest_py_ver}/python-${latest_py_ver}-embed-amd64.zip"

    if curl -sL --max-time 60 "$py_url" -o "$tmp_zip" 2>/dev/null; then
        unzip -o -q "$tmp_zip" -d "$DEV_TOOLKIT_PYTHON_DIR" 2>/dev/null
        rm -f "$tmp_zip"

        local pth_file
        pth_file="$(find "$DEV_TOOLKIT_PYTHON_DIR" -maxdepth 1 -name "*._pth" 2>/dev/null | head -1)"
        if [[ -f "$pth_file" ]]; then
            sed -i 's/^#import site/import site/' "$pth_file"
            grep -q "^import site" "$pth_file" || echo "import site" >> "$pth_file"
        fi

        local get_pip="${DEV_TOOLKIT_PYTHON_DIR}/get-pip.py"
        curl -sL "https://bootstrap.pypa.io/get-pip.py" -o "$get_pip" 2>/dev/null
        "$py_exe" "$get_pip" --no-warn-script-location -q 2>/dev/null
        rm -f "$get_pip"

        "$py_exe" -m pip install semgrep --no-warn-script-location -q 2>/dev/null
        echo "$latest_py_ver" > "$version_file"
    fi
}

bootstrap_all() {
    [[ "$_BOOTSTRAP_DONE" -eq 1 ]] && return 0
    _BOOTSTRAP_DONE=1
    mkdir -p "$LOCAL_BIN" "$DEV_TOOLKIT_DEPENDENCIES_DIR"

    _bootstrap_download_latest "gitleaks/gitleaks" "windows.*(x64|x86_64).*\.zip" "$LOCAL_BIN/gitleaks.exe" "Gitleaks"
    _bootstrap_download_latest "aquasecurity/trivy" "windows.*64.*\.zip" "$LOCAL_BIN/trivy.exe" "Trivy SCA"
    _bootstrap_download_latest "google/google-java-format" "google-java-format.*all-deps\.jar" "$LOCAL_BIN/google-java-format.jar" "Google Java Format"
    _bootstrap_download_latest "anchore/syft" "windows.*(x86_64|amd64).*\.zip" "$LOCAL_BIN/syft.exe" "Syft SBOM"
    _bootstrap_download_latest "ast-grep/ast-grep" "x86_64-pc-windows-msvc\.zip" "$LOCAL_BIN/ast-grep.exe" "ast-grep"
    _bootstrap_download_latest "google/osv-scanner" "windows_amd64\.exe" "$LOCAL_BIN/osv-scanner.exe" "OSV Scanner"

    bootstrap_python_portable
}
