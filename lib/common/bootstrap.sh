#!/usr/bin/env bash
# ==============================================================================
# bootstrap.sh - Gerenciamento Dinâmico de Ferramentas e Python Latest Stable
# ==============================================================================

_BOOTSTRAP_DONE=0

_bootstrap_get_installed_version() {
    local target_bin="$1"
    local version_file="${target_bin}.version"
    if [[ -f "$version_file" ]]; then
        cat "$version_file" 2>/dev/null | tr -d '\r\n'
    else
        echo ""
    fi
}

_bootstrap_download_latest() {
    local repo="$1"
    local asset_pattern="$2"
    local dest_path="$3"
    local friendly_name="$4"

    local current_tag
    current_tag="$(_bootstrap_get_installed_version "$dest_path")"

    local auth_header=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth_header=("-H" "Authorization: Bearer $GITHUB_TOKEN")
    elif [[ -n "${GH_TOKEN:-}" ]]; then
        auth_header=("-H" "Authorization: Bearer $GH_TOKEN")
    fi

    local version_tag=""
    local download_url=""

    # 1. API oficial do GitHub
    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local release_info
    release_info="$(curl -sL --ssl-no-revoke --connect-timeout 4 --max-time 8 "${auth_header[@]}" "$api_url" 2>/dev/null)"

    if [[ -n "$release_info" ]] && ! echo "$release_info" | grep -q '"message":'; then
        version_tag="$(echo "$release_info" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
        download_url="$(echo "$release_info" | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -iE "$asset_pattern" | head -1 | sed -E 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    fi

    # 2. Scraper web de contingência (imune a Rate Limit)
    if [[ -z "$download_url" ]]; then
        local effective_url
        effective_url="$(curl -sIL --ssl-no-revoke --connect-timeout 4 --max-time 8 -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest" 2>/dev/null)"
        local web_tag="${effective_url##*/}"
        web_tag="$(echo "$web_tag" | tr -d '\r\n')"

        if [[ -n "$web_tag" && "$web_tag" != "latest" ]]; then
            version_tag="$web_tag"
            local asset_path
            asset_path="$(curl -sL --ssl-no-revoke --connect-timeout 4 --max-time 10 "https://github.com/${repo}/releases/expanded_assets/${web_tag}" 2>/dev/null | grep -oE "href=\"/${repo}/releases/download/${web_tag}/[^\"]+\"" | grep -iE "$asset_pattern" | head -1 | sed 's/href="//;s/"//')"
            [[ -n "$asset_path" ]] && download_url="https://github.com${asset_path}"
        fi
    fi

    # Fallback para Google Java Format
    if [[ -z "$download_url" && "$repo" == "google/google-java-format" && -n "$version_tag" ]]; then
        local clean_tag="${version_tag#v}"
        download_url="https://github.com/google/google-java-format/releases/download/${version_tag}/google-java-format-${clean_tag}-all-deps.jar"
    fi

    if [[ -f "$dest_path" ]]; then
        if [[ -z "$version_tag" || "$current_tag" == "$version_tag" ]]; then
            printf "${_C_SUCCESS}[BOOTSTRAP]${_C_RESET} %s %s: OK (atualizado)\n" "$friendly_name" "${current_tag:-local}"
            return 0
        fi
    fi

    if [[ -z "$download_url" ]]; then
        if [[ -f "$dest_path" ]]; then
            printf "${_C_SUCCESS}[BOOTSTRAP]${_C_RESET} %s %s: OK (usando versão local)\n" "$friendly_name" "${current_tag:-instalado}"
            return 0
        fi
        printf "${_C_ERROR}[BOOTSTRAP] Não foi possível obter download de %s (Rate Limit de rede)${_C_RESET}\n" "$friendly_name"
        return 1
    fi

    printf "${_C_INFO}[BOOTSTRAP]${_C_RESET} Baixando/Atualizando %s (%s)...\n" "$friendly_name" "$version_tag"
    local tmp_dir
    tmp_dir="$(mktemp -d 2>/dev/null || echo "/tmp/bt_${RANDOM}")"
    mkdir -p "$tmp_dir"
    local tmp_file="${tmp_dir}/pkg"

    if ! curl -sL --ssl-no-revoke --connect-timeout 10 --max-time 90 "$download_url" -o "$tmp_file" 2>/dev/null; then
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
        echo "$version_tag" > "${dest_path}.version" 2>/dev/null || true
        local win_path
        win_path="$(cygpath -w "$dest_path" 2>/dev/null || echo "$dest_path")"
        powershell -Command "Unblock-File -LiteralPath '$win_path'" 2>/dev/null || true
        printf "${_C_SUCCESS}[BOOTSTRAP]${_C_RESET} %s atualizado com sucesso (%s)\n" "$friendly_name" "$version_tag"
        return 0
    fi
    return 1
}

_bootstrap_resolve_latest_python_stable() {
    local live_url
    live_url="$(curl -sL --ssl-no-revoke --connect-timeout 4 --max-time 8 "https://www.python.org/downloads/windows/" 2>/dev/null | grep -oE 'https://www.python.org/ftp/python/3\.[0-9]+\.[0-9]+/python-[0-9\.]+-embed-amd64\.zip' | head -1)"

    if [[ -z "$live_url" ]]; then
        local latest_ver
        latest_ver="$(curl -sL --ssl-no-revoke --connect-timeout 4 --max-time 8 "https://www.python.org/ftp/python/" 2>/dev/null | grep -oE 'href="3\.[0-9]+\.[0-9]+/' | sed 's#href="##;s#/##' | sort -V | tail -1)"
        if [[ -n "$latest_ver" ]]; then
            live_url="https://www.python.org/ftp/python/${latest_ver}/python-${latest_ver}-embed-amd64.zip"
        fi
    fi

    echo "$live_url"
}

bootstrap_python_portable() {
    local py_dir="${DEV_TOOLKIT_PYTHON_DIR:-${TOOLKIT_ROOT}/dependencies/python}"
    local py_exe="${py_dir}/python.exe"
    local semgrep_exe="${py_dir}/Scripts/semgrep.exe"

    local py_url
    py_url="$(_bootstrap_resolve_latest_python_stable)"
    local latest_py_ver
    latest_py_ver="$(echo "$py_url" | grep -oE '3\.[0-9]+\.[0-9]+' | head -1)"

    local current_py_ver=""
    if [[ -f "$py_exe" ]]; then
        current_py_ver="$("$py_exe" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null || echo '')"
    fi

    # Se já é a versão mais recente e o semgrep existe, encerra em 0s
    if [[ -n "$current_py_ver" && "$current_py_ver" == "$latest_py_ver" && -f "$semgrep_exe" ]]; then
        local s_ver
        s_ver="$("$semgrep_exe" --version 2>/dev/null | head -1 | tr -d '\r\n')"
        printf "${_C_SUCCESS}[BOOTSTRAP]${_C_RESET} Python Portátil v%s (Semgrep %s): OK (atualizado)\n" "$current_py_ver" "${s_ver:-ativo}"
        return 0
    fi

    # Se há versão estável mais nova na PSF, remove o diretório antigo e atualiza
    if [[ -n "$current_py_ver" && -n "$latest_py_ver" && "$current_py_ver" != "$latest_py_ver" ]]; then
        printf "${_C_INFO}[BOOTSTRAP]${_C_RESET} Nova versão estável do Python (%s -> %s). Atualizando...\n" "$current_py_ver" "$latest_py_ver"
        rm -rf "$py_dir"
    elif [[ -z "$current_py_ver" ]]; then
        printf "${_C_INFO}[BOOTSTRAP]${_C_RESET} Baixando Python Portátil Latest Stable (%s)...\n" "$latest_py_ver"
    fi

    mkdir -p "$py_dir"
    local tmp_zip="/tmp/py_portable_$$.zip"

    if ! curl -sL --ssl-no-revoke --connect-timeout 8 --max-time 60 "$py_url" -o "$tmp_zip" 2>/dev/null; then
        printf "${_C_WARN}[BOOTSTRAP] Falha no download do Python portátil. Mantendo ambiente atual.${_C_RESET}\n"
        rm -f "$tmp_zip" 2>/dev/null
        return 0
    fi

    unzip -o -q "$tmp_zip" -d "$py_dir" 2>/dev/null
    rm -f "$tmp_zip" 2>/dev/null

    local pth_file
    pth_file="$(find "$py_dir" -maxdepth 1 -name "*._pth" 2>/dev/null | head -1)"
    if [[ -f "$pth_file" ]]; then
        sed -i 's/^#import site/import site/' "$pth_file"
        grep -q "^import site" "$pth_file" || echo "import site" >> "$pth_file"
        grep -q "Lib/site-packages" "$pth_file" || echo "Lib/site-packages" >> "$pth_file"
    fi

    local win_py_dir
    win_py_dir="$(cygpath -w "$py_dir" 2>/dev/null || echo "$py_dir")"
    powershell -Command "Get-ChildItem -LiteralPath '$win_py_dir' -Recurse | Unblock-File" 2>/dev/null || true

    local get_pip="${py_dir}/get-pip.py"
    if curl -sL --ssl-no-revoke --connect-timeout 8 --max-time 30 "https://bootstrap.pypa.io/get-pip.py" -o "$get_pip" 2>/dev/null; then
        "$py_exe" "$get_pip" --no-warn-script-location --no-setuptools --no-wheel -q 2>/dev/null || true
        rm -f "$get_pip" 2>/dev/null

        "$py_exe" -m pip install semgrep \
            --trusted-host pypi.org \
            --trusted-host files.pythonhosted.org \
            --trusted-host pypi.python.org \
            --timeout 25 \
            --retries 1 \
            --no-warn-script-location -q 2>/dev/null || true
    fi

    if [[ -f "$semgrep_exe" ]]; then
        local real_py_ver real_semgrep_ver
        real_py_ver="$("$py_exe" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null || echo "$latest_py_ver")"
        real_semgrep_ver="$("$semgrep_exe" --version 2>/dev/null | head -1 | tr -d '\r\n')"
        printf "${_C_SUCCESS}[BOOTSTRAP]${_C_RESET} Python Portátil v%s (Semgrep %s): OK (instalado)\n" "$real_py_ver" "$real_semgrep_ver"
    else
        printf "${_C_WARN}[BOOTSTRAP]${_C_RESET} Semgrep não pôde ser instalado (bloqueio de rede). Etapa Semgrep será pulada.\n"
    fi
}

bootstrap_all() {
    [[ "$_BOOTSTRAP_DONE" -eq 1 ]] && return 0
    _BOOTSTRAP_DONE=1

    local local_bin="${LOCAL_BIN:-$HOME/.local/bin}"
    local deps_dir="${DEV_TOOLKIT_DEPENDENCIES_DIR:-${TOOLKIT_ROOT}/dependencies}"
    mkdir -p "$local_bin" "$deps_dir"

    _bootstrap_download_latest "gitleaks/gitleaks" "windows.*(x64|x86_64).*\.zip" "$local_bin/gitleaks.exe" "Gitleaks"
    _bootstrap_download_latest "aquasecurity/trivy" "windows.*64.*\.zip" "$local_bin/trivy.exe" "Trivy SCA"
    _bootstrap_download_latest "google/google-java-format" "google-java-format.*all-deps\.jar" "$local_bin/google-java-format.jar" "Google Java Format"
    _bootstrap_download_latest "anchore/syft" "windows.*(x86_64|amd64).*\.zip" "$local_bin/syft.exe" "Syft SBOM"
    _bootstrap_download_latest "ast-grep/ast-grep" "x86_64-pc-windows-msvc\.zip" "$local_bin/ast-grep.exe" "ast-grep"
    _bootstrap_download_latest "google/osv-scanner" "windows_amd64\.exe" "$local_bin/osv-scanner.exe" "OSV Scanner"

    bootstrap_python_portable
}
