#!/usr/bin/env bash
# ==============================================================================
# logging.sh - Output Visual de Terminal
# ==============================================================================

stty -ixon 2>/dev/null || true

if [[ -t 1 ]]; then
    _C_RESET=$'\033[0m'
    _C_GREEN=$'\033[0;32m'
    _C_YELLOW=$'\033[0;33m'
    _C_RED=$'\033[0;31m'
    _C_CYAN=$'\033[0;36m'
    _C_PURPLE=$'\033[1;35m'
    _C_WHITE=$'\033[0;37m'
    _C_BOLD=$'\033[1m'
    _C_BCYAN=$'\033[1;36m'
    _C_BYELLOW=$'\033[1;33m'
    _C_INFO=$'\033[1;36m'
    _C_ERROR=$'\033[0;31m'
    _C_SUCCESS=$'\033[0;32m'
    _C_DIM=$'\033[2m'
else
    _C_RESET="" _C_GREEN="" _C_YELLOW="" _C_RED="" _C_CYAN="" _C_PURPLE=""
    _C_WHITE="" _C_BOLD="" _C_BCYAN="" _C_BYELLOW="" _C_INFO="" _C_ERROR=""
    _C_SUCCESS="" _C_DIM=""
fi

_LOG_GLOBAL_START=0
_LOG_STEP_START=0
_LOG_LAST_STEP_TIME=0
_LOG_LAST_OUTPUT=""
_LOG_CURRENT_LABEL=""

log_init() {
    local repo_name="$1"
    local hook_name="$2"

    _LOG_GLOBAL_START=$(date +%s)
    _LOG_STEP_START=0
    _LOG_CURRENT_LABEL=""
    _LOG_LAST_OUTPUT=""

    printf "\n"
    printf "${_C_BCYAN}==================================================${_C_RESET}\n"
    printf "${_C_BCYAN}  %-48s${_C_RESET}\n" "${hook_name} — ${repo_name}"
    printf "${_C_BCYAN}==================================================${_C_RESET}\n\n"
}

log_step() {
    local step_label="$1"
    local description="$2"
    local status="$3"
    local detail="${4:-}"
    local step_time=0

    if [[ $_LOG_STEP_START -gt 0 ]]; then
        step_time=$(( $(date +%s) - _LOG_STEP_START ))
        _LOG_STEP_START=0
    fi
    _LOG_LAST_STEP_TIME=$step_time

    if [[ $step_time -gt 0 ]]; then
        if [[ -n "$detail" ]]; then
            detail="${detail}, ${step_time}s"
        else
            detail="${step_time}s"
        fi
    fi

    local status_tag color
    case "$status" in
        OK)          status_tag="[ OK ]";        color="$_C_GREEN"  ;;
        FAIL)        status_tag="[FALHA]";       color="$_C_RED"    ;;
        SKIP|PULADO) status_tag="[PULADO]";      color="$_C_YELLOW" ;;
        BLOCKED)     status_tag="[BLOQUEADO]";   color="$_C_PURPLE" ;;
        *)           status_tag="[${status}]";   color="$_C_YELLOW" ;;
    esac

    local detail_str=""
    if [[ -n "$detail" ]]; then
        if [[ "$detail" =~ Cache ]]; then
            detail_str=" ${_C_GREEN}(${detail})${_C_RESET}"
        elif [[ "$status" == "BLOCKED" ]]; then
            detail_str=" ${_C_PURPLE}(${detail})${_C_RESET}"
        else
            detail_str=" ${_C_WHITE}(${detail})${_C_RESET}"
        fi
    fi

    local line="[${step_label}] ${description}..."
    local target_col=62
    local pad_len=$((target_col - ${#line}))
    [[ $pad_len -lt 2 ]] && pad_len=2
    local padding
    padding=$(printf '%*s' "$pad_len" '')

    printf "%s%s%s%-13s%s%s\n" "$line" "$padding" "$color" "$status_tag" "${_C_RESET}" "$detail_str"
}

log_step_header() {
    local step_label="$1"
    local description="$2"
    _LOG_STEP_START=$(date +%s)
    _LOG_CURRENT_LABEL="$step_label"
}

log_substep() {
    local description="$1"
    shift

    if [[ -n "${_CURRENT_ENGINE_SUBSTEP_FILE:-}" ]]; then
        echo "$description" > "$_CURRENT_ENGINE_SUBSTEP_FILE" 2>/dev/null || true
    fi

    local tmp_output
    tmp_output=$(mktemp 2>/dev/null || echo "/tmp/substep-$$.out")

    "$@" > "$tmp_output" 2>&1
    local exit_code=$?

    local cmd_output
    cmd_output=$(cat "$tmp_output" 2>/dev/null)
    rm -f "$tmp_output" 2>/dev/null
    _LOG_LAST_OUTPUT="$cmd_output"

    return $exit_code
}

log_show_last() {
    if [[ -n "$_LOG_LAST_OUTPUT" ]]; then
        printf "\n${_C_WHITE}--- Detalhes da Execução ---${_C_RESET}\n"
        echo "$_LOG_LAST_OUTPUT" | tr -d '\000-\010\013\014\016-\032\034-\037' | sed 's/^/  /'
        printf "\n"
    fi
}

log_finish() {
    :
}
