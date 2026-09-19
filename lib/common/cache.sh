#!/usr/bin/env bash
# ==============================================================================
# cache.sh - Cache SHA-256 com TTL e Caminho Configurável
# ==============================================================================

_CACHE_BASE="${DEV_TOOLKIT_CACHE_DIR:-/tmp/cicd_cache}"
_CACHE_BASE="${_CACHE_BASE%$'\r'}"
_CACHE_REPO_DIR=""
_CACHE_REPO_NAME=""

cache_init() {
    local repo_name="${1%$'\r'}"
    _CACHE_REPO_NAME="$repo_name"
    _CACHE_REPO_DIR="${_CACHE_BASE}/${repo_name}"
    mkdir -p "$_CACHE_REPO_DIR"
}

cache_compute_hash() {
    local scope_key="${1%$'\r'}"
    shift
    local files=("$@")
    local combined_hash=""
    local f
    for f in "${files[@]}"; do
        if [[ -f "$f" ]]; then
            combined_hash+="$(sha256sum "$f" | awk '{print $1}')"
        elif [[ -d "$f" ]]; then
            while IFS= read -r -d '' subfile; do
                combined_hash+="$(sha256sum "$subfile" | awk '{print $1}')"
            done < <(find "$f" -type f -print0 2>/dev/null | sort -z)
        fi
    done
    echo -n "$combined_hash" | sha256sum | awk '{print $1}'
}

cache_is_valid() {
    [[ "${DEV_TOOLKIT_NO_CACHE:-0}" == "1" ]] && return 1
    local scope_key="${1%$'\r'}"
    local current_hash="${2%$'\r'}"
    local ttl_seconds="${3:-0}"
    ttl_seconds="${ttl_seconds%$'\r'}"

    local hash_file="${_CACHE_REPO_DIR}/${scope_key}.sha256"
    local done_file="${_CACHE_REPO_DIR}/${scope_key}.done"

    [[ -f "$hash_file" && -f "$done_file" ]] || return 1

    local stored_hash
    stored_hash="$(cat "$hash_file" 2>/dev/null)"
    stored_hash="${stored_hash%$'\r'}"
    [[ "$stored_hash" == "$current_hash" ]] || return 1

    if [[ $ttl_seconds -gt 0 ]]; then
        local now done_mtime age
        now=$(date +%s)
        done_mtime=$(stat -c %Y "$done_file" 2>/dev/null || stat -f %m "$done_file" 2>/dev/null || echo 0)
        done_mtime="${done_mtime%$'\r'}"
        age=$(( now - done_mtime ))
        if [[ $age -ge $ttl_seconds ]]; then
            return 1
        fi
    fi
    return 0
}

cache_save() {
    local scope_key="${1%$'\r'}"
    local current_hash="${2%$'\r'}"
    local hash_file="${_CACHE_REPO_DIR}/${scope_key}.sha256"
    local done_file="${_CACHE_REPO_DIR}/${scope_key}.done"
    echo "$current_hash" > "$hash_file"
    touch "$done_file"
}

cache_invalidate() {
    local scope_key="${1:-}"
    scope_key="${scope_key%$'\r'}"
    if [[ -n "$scope_key" ]]; then
        rm -f "${_CACHE_REPO_DIR}/${scope_key}.sha256" "${_CACHE_REPO_DIR}/${scope_key}.done"
    else
        rm -rf "${_CACHE_REPO_DIR:?}/"*
    fi
}

cache_clean_all() {
    rm -rf "${_CACHE_BASE:?}/"*
}
