#!/usr/bin/env bash
# ==============================================================================
# git-diff.sh - Detecção de Branch Pai e Arquivos Alterados
# ==============================================================================

git_diff_find_parent_branch() {
    local current_branch best_merge_base="" best_parent="" min_distance=999999
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    while IFS= read -r rbranch; do
        rbranch="$(echo "$rbranch" | xargs)"
        [[ -z "$rbranch" ]] && continue
        local mb
        mb="$(git merge-base HEAD "$rbranch" 2>/dev/null)"
        [[ -z "$mb" ]] && continue
        local distance
        distance="$(git rev-list --count "${mb}..HEAD" 2>/dev/null || echo 999999)"
        if [[ "$distance" -lt "$min_distance" ]]; then
            min_distance=$distance
            best_merge_base="$mb"
            best_parent="$rbranch"
        fi
    done < <(git branch -r 2>/dev/null | grep -v "HEAD" | grep -v "/${current_branch}$")

    if [[ -n "$best_merge_base" ]]; then
        echo "${best_merge_base} ${best_parent}"
    fi
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
    if [[ $# -gt 0 ]]; then
        git diff --name-only --diff-filter=ACMR "${parent_sha}" -- "$@" 2>/dev/null
    else
        git diff --name-only --diff-filter=ACMR "${parent_sha}" 2>/dev/null
    fi
}

git_diff_parent_sha() {
    local parent_info
    parent_info="$(git_diff_find_parent_branch)"
    echo "${parent_info%% *}"
}

git_diff_has_staged_files() {
    local files
    files="$(git_diff_staged_files "$@")"
    [[ -n "$files" ]]
}

git_diff_has_branch_changes() {
    local files
    files="$(git_diff_branch_files "$@")"
    [[ -n "$files" ]]
}
