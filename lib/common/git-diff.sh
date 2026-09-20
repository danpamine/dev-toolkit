#!/usr/bin/env bash
# ==============================================================================
# git-diff.sh - Resolução Determinística da Branch Base e Diffs
# ==============================================================================

git_diff_resolve_base_ref() {
    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

    local candidates=()
    if [[ -n "${BASE_BRANCH:-}" ]]; then
        candidates+=("origin/$BASE_BRANCH" "$BASE_BRANCH")
    fi

    local created_from
    created_from="$(git reflog show --format="%gs" "$current_branch" 2>/dev/null | grep -oE "Created from .*" | head -1 | sed 's/Created from //' | tr -d '\r\n ')"
    if [[ -n "$created_from" && "$created_from" != "$current_branch" && "$created_from" != "HEAD" ]]; then
        candidates+=("origin/$created_from" "$created_from")
    fi

    candidates+=("origin/develop" "develop" "origin/main" "main" "origin/master" "master")

    local cand
    for cand in "${candidates[@]}"; do
        [[ "$cand" == "$current_branch" || "$cand" == "origin/$current_branch" ]] && continue
        if git rev-parse --verify "$cand^{commit}" >/dev/null 2>&1; then
            echo "$cand"
            return 0
        fi
    done

    echo ""
    return 1
}

git_diff_find_parent_branch() {
    local base_ref
    base_ref="$(git_diff_resolve_base_ref)"

    if [[ -z "$base_ref" ]]; then
        if git rev-parse HEAD~1^{commit} >/dev/null 2>&1; then
            echo "$(git rev-parse HEAD~1) HEAD~1"
            return 0
        fi
        return 1
    fi

    local mb
    mb="$(git merge-base HEAD "$base_ref" 2>/dev/null)"
    [[ -z "$mb" ]] && mb="$(git rev-parse "$base_ref^{commit}" 2>/dev/null)"

    echo "${mb} ${base_ref}"
    return 0
}

git_diff_staged_files() {
    if [[ $# -gt 0 ]]; then
        git diff --cached --name-only --diff-filter=ACMR -- "$@" 2>/dev/null
    else
        git diff --cached --name-only --diff-filter=ACMR 2>/dev/null
    fi
}

git_diff_branch_files() {
    local parent_info parent_sha
    parent_info="$(git_diff_find_parent_branch)"
    parent_sha="${parent_info%% *}"
    if [[ -z "$parent_sha" ]]; then
        return 0
    fi

    # Curto-circuito: se a branch tem 0 commits à frente da base e a working tree está limpa, não há alterações
    local branch_commits
    branch_commits="$(git rev-list --count "${parent_sha}..HEAD" 2>/dev/null || echo 0)"
    if [[ "$branch_commits" -eq 0 ]] && git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
        return 0
    fi

    if [[ $# -gt 0 ]]; then
        git diff --name-only --diff-filter=ACMR "${parent_sha}" -- "$@" 2>/dev/null
    else
        git diff --name-only --diff-filter=ACMR "${parent_sha}" 2>/dev/null
    fi
}

git_diff_target_files() {
    local files=""
    if [[ "${_CURRENT_HOOK_ACTION:-}" == "pre-commit" ]]; then
        files="$(git_diff_staged_files "$@")"
    else
        files="$(git_diff_branch_files "$@")"
        if [[ -z "$files" ]]; then
            files="$(git_diff_staged_files "$@")"
        fi
    fi
    echo "$files"
}

git_diff_parent_sha() {
    local parent_info
    parent_info="$(git_diff_find_parent_branch)"
    echo "${parent_info%% *}"
}
