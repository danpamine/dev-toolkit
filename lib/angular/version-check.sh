#!/usr/bin/env bash
# ==============================================================================
# version-check.sh - Validação Estrita de Incremento de Versão no package.json
# ==============================================================================

if ! declare -f git_diff_resolve_base_ref &>/dev/null; then
    _SCRIPT_D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _TK_R="${TOOLKIT_ROOT:-$(cd "$_SCRIPT_D/../.." && pwd)}"
    if [[ -f "$_TK_R/lib/common/git-diff.sh" ]]; then
        source "$_TK_R/lib/common/git-diff.sh"
    fi
fi

step_version_check() {
    local label="$1"
    local desc="$2"

    log_step_header "$label" "$desc"

    if [[ ! -f "package.json" ]]; then
        log_step "$label" "$desc" "FAIL" "package.json ausente"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "package.json ausente" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "package.json ausente" "package.json não encontrado no diretório atual"
        return 1
    fi

    # 1. Extração da versão atual
    local project_version
    project_version="$(node -p "require('./package.json').version" 2>/dev/null)"

    if [[ -z "$project_version" ]]; then
        log_step "$label" "$desc" "FAIL" "Campo 'version' ausente no package.json"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Campo 'version' ausente" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "package.json sem versão" "Campo 'version' obrigatório no package.json"
        return 1
    fi

    # 2. Localização da branch base remota
    local base_ref
    base_ref="$(git_diff_resolve_base_ref)"

    if [[ -z "$base_ref" ]]; then
        local target_name="${BASE_BRANCH:-develop}"
        log_step "$label" "$desc" "FAIL" "Branch base '${target_name}' não encontrada"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "Base não encontrada" > "$_CURRENT_ENGINE_DETAIL_FILE"
        printf "  [ERRO] Branch base remota não encontrada (esperada: '%s').\n" "$target_name"
        printf "  Execute 'git fetch origin %s' ou configure com 'dev base <nome>'.\n\n" "$target_name"
        summary_add "$desc" "FAIL" "Base '${target_name}' ausente" "Execute 'git fetch origin' ou 'dev base <branch>'"
        return 1
    fi

    # 3. Extração da versão da branch base diretamente via Git
    local repo_prefix
    repo_prefix="$(git rev-parse --show-prefix 2>/dev/null)"
    local pkg_git_path="${repo_prefix}package.json"

    local base_version
    base_version=$(git show "${base_ref}:${pkg_git_path}" 2>/dev/null | node -e '
        const fs = require("fs");
        try {
            const pkg = JSON.parse(fs.readFileSync(0, "utf8"));
            if (pkg && pkg.version) { console.log(pkg.version.trim()); process.exit(0); }
        } catch(e) {}
        process.exit(1);
    ' 2>/dev/null)

    if [[ -z "$base_version" ]]; then
        log_step "$label" "$desc" "FAIL" "package.json ausente na base ${base_ref}"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "package.json ausente na base" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "package.json ausente na base" "Verifique o package.json em ${base_ref}"
        return 1
    fi

    # 4. Comparador SemVer
    local comp_result
    comp_result=$(node -e '
        function parseVer(v) {
            if (!v) return { parts: [], isSnapshot: false };
            v = v.replace(/^v/, "").trim();
            const isSnapshot = /[-.]snapshot$/i.test(v);
            const clean = v.replace(/[-.]snapshot$/i, "");
            const parts = clean.split(/[.-]/).map(p => {
                const n = parseInt(p, 10);
                return isNaN(n) ? p : n;
            });
            return { parts, isSnapshot };
        }

        const pCurrent = parseVer(process.argv[1]);
        const pBase = parseVer(process.argv[2]);
        const len = Math.max(pCurrent.parts.length, pBase.parts.length);
        let diff = 0;

        for (let i = 0; i < len; i++) {
            const a = pCurrent.parts[i] !== undefined ? pCurrent.parts[i] : 0;
            const b = pBase.parts[i] !== undefined ? pBase.parts[i] : 0;
            if (typeof a === "number" && typeof b === "number") {
                if (a !== b) { diff = a - b; break; }
            } else {
                const sa = String(a);
                const sb = String(b);
                if (sa !== sb) { diff = sa.localeCompare(sb); break; }
            }
        }

        if (diff === 0) {
            if (!pCurrent.isSnapshot && pBase.isSnapshot) diff = 1;
            else if (pCurrent.isSnapshot && !pBase.isSnapshot) diff = -1;
        }

        if (diff > 0) console.log("GREATER");
        else if (diff < 0) console.log("LOWER");
        else console.log("EQUAL");
    ' "$project_version" "$base_version" 2>/dev/null)

    # 5. Avaliação do incremento
    if [[ "$comp_result" == "EQUAL" ]]; then
        local detail_msg="base: ${base_version} == atual: ${project_version} em ${base_ref}"
        log_step "$label" "$desc" "FAIL" "$detail_msg"
        printf "  [ERRO] Versão não incrementada em relação à branch base!\n"
        printf "  Branch atual: %s\n" "$project_version"
        printf "  Branch base (%s): %s\n" "$base_ref" "$base_version"
        printf "  Ação: Incremente a versão no package.json antes de abrir o PR.\n\n"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "$detail_msg" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "$detail_msg" "Incremente a versão no package.json (atual: ${project_version}, base [${base_ref}]: ${base_version})"
        return 1
    elif [[ "$comp_result" == "LOWER" ]]; then
        local detail_msg="base: ${base_version} > atual: ${project_version} em ${base_ref}"
        log_step "$label" "$desc" "FAIL" "$detail_msg"
        printf "  [ERRO] Versão local inferior à versão da branch base!\n"
        printf "  Branch atual: %s\n" "$project_version"
        printf "  Branch base (%s): %s\n" "$base_ref" "$base_version"
        printf "  Ação: Ajuste a versão para um valor superior ao da branch base.\n\n"
        [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "$detail_msg" > "$_CURRENT_ENGINE_DETAIL_FILE"
        summary_add "$desc" "FAIL" "$detail_msg" "Versão local (${project_version}) é inferior à base [${base_ref}] (${base_version})"
        return 1
    fi

    local ok_msg="${base_version} -> ${project_version} em ${base_ref}"
    log_step "$label" "$desc" "OK" "$ok_msg"
    [[ -n "${_CURRENT_ENGINE_DETAIL_FILE:-}" ]] && echo "$ok_msg" > "$_CURRENT_ENGINE_DETAIL_FILE"
    summary_add "$desc" "OK" "$ok_msg"
    return 0
}
