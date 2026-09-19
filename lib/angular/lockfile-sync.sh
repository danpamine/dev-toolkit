#!/usr/bin/env bash
#
# 03-lockfile-sync.sh — Sincroniza package-lock.json e bloqueia artefatos do PNPM
#
step_lockfile_sync() {
    local label="ETAPA 3/4"
    local desc="Sincronizando package-lock.json e removendo artefatos do PNPM"

    if [[ ! -f "package.json" ]]; then
        log_step "$label" "$desc" "FAIL" "package.json não encontrado"
        summary_add "Lockfile Sync" "FAIL" "" "package.json ausente"
        return 1
    fi

    if ! command -v npm &>/dev/null; then
        log_step "$label" "$desc" "FAIL" "npm não encontrado no PATH"
        summary_add "Lockfile Sync" "FAIL" "" "Node.js/npm necessário"
        return 1
    fi

    # Trava Ativa: Remove qualquer artefato local do PNPM caso tenha sido adicionado ao staging
    if git diff --cached --name-only 2>/dev/null | grep -qE '^pnpm-.*\.yaml$|^pnpm-debug\.log'; then
        git reset HEAD pnpm-*.yaml pnpm-debug.log* &>/dev/null || true
    fi

    local hash
    hash="$(sha256sum package.json 2>/dev/null | awk '{print $1}')"
    if cache_is_valid "lockfile-sync" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "Lockfile Sync" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"

    local lockfile_before=""
    if [[ -f "package-lock.json" ]]; then
        lockfile_before="$(sha256sum package-lock.json 2>/dev/null | awk '{print $1}')"
    fi

    log_substep "Resolvendo dependências (--package-lock-only)" npm install --package-lock-only --legacy-peer-deps

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_step "$label" "$desc" "FAIL" "npm install falhou"
        summary_add "Lockfile Sync" "FAIL" "" "Corrija conflitos de dependência no package.json"
        log_show_last 20
        return 1
    fi

    local lockfile_after=""
    if [[ -f "package-lock.json" ]]; then
        lockfile_after="$(sha256sum package-lock.json 2>/dev/null | awk '{print $1}')"
    fi

    if [[ "$lockfile_before" != "$lockfile_after" ]]; then
        git add package-lock.json 2>/dev/null
        log_step "$label" "$desc" "OK" "package-lock.json atualizado e staged"
        summary_add "Lockfile Sync" "OK" "Lockfile atualizado"
    else
        log_step "$label" "$desc" "OK" "Lockfile já sincronizado"
        summary_add "Lockfile Sync" "OK" "Sincronizado"
    fi

    cache_save "lockfile-sync" "$hash"
    return 0
}
