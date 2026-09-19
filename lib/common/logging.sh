#!/usr/bin/env bash
# ==============================================================================
# logging.sh - Output Visual de Terminal e Captura Volátil de Execução
# ==============================================================================

if [[ -t 1 ]]; then
    _C_RESET=$'\033[0m'
    _C_GREEN=$'\033[0;32m'
    _C_YELLOW=$'\033[0;33m'
    _C_RED=$'\033[0;31m'
    _C_CYAN=$'\033[0;36m'
    _C_WHITE=$'\033[0;37m'
    _C_BOLD=$'\033[1m'
    _C_BCYAN=$'\033[1;36m'
    _C_BYELLOW=$'\033[1;33m'
    _C_INFO=$'\033[1;36m'
    _C_ERROR=$'\033[0;31m'
    _C_SUCCESS=$'\033[0;32m'
else
    _C_RESET=""
    _C_GREEN=""
    _C_YELLOW=""
    _C_RED=""
    _C_CYAN=""
    _C_WHITE=""
    _C_BOLD=""
    _C_BCYAN=""
    _C_BYELLOW=""
    _C_INFO=""
    _C_ERROR=""
    _C_SUCCESS=""
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
        OK)          status_tag="[ OK ]";    color="$_C_GREEN"  ;;
        FAIL)        status_tag="[FALHA]";   color="$_C_RED"    ;;
        SKIP|PULADO) status_tag="[PULADO]";  color="$_C_YELLOW" ;;
        *)           status_tag="[${status}]"; color="$_C_YELLOW" ;;
    esac

    local detail_str=""
    [[ -n "$detail" ]] && detail_str=" ${_C_WHITE}(${detail})${_C_RESET}"

    local line="[${step_label}] ${description}..."
    local target_col=65
    local pad_len=$((target_col - ${#line}))
    [[ $pad_len -lt 2 ]] && pad_len=2
    local padding
    padding=$(printf '%*s' "$pad_len" '')

    printf "%s%s%s%s%s%s\n" "$line" "$padding" "$color" "$status_tag" "${_C_RESET}" "$detail_str"
}

log_step_header() {
    local step_label="$1"
    local description="$2"
    _LOG_STEP_START=$(date +%s)
    _LOG_CURRENT_LABEL="$step_label"
    printf "[%s] %s\n" "$step_label" "$description"
}

log_substep() {
    local description="$1"
    shift
    local cmd_line="$*"
    local tmp_output
    tmp_output=$(mktemp 2>/dev/null || echo "/tmp/substep-$$.out")

    "$@" > "$tmp_output" 2>&1 &
    local pid=$!
    local exit_code=0

    if [[ -t 1 ]]; then
        local spinner_chars='|/-\'
        local i=0
        local start_time
        start_time=$(date +%s)
        while kill -0 "$pid" 2>/dev/null; do
            local elapsed=$(( $(date +%s) - start_time ))
            printf "\r  ${_C_BYELLOW}%s... %s [%ds]${_C_RESET}" "$description" "${spinner_chars:i%4:1}" "$elapsed"
            sleep 0.15
            i=$((i + 1))
        done
        wait "$pid" 2>/dev/null
        exit_code=$?
        printf '\r'
        printf '%*s' 80 ''
        printf '\r'
    else
        printf "  %s...\n" "$description"
        wait "$pid" 2>/dev/null
        exit_code=$?
    fi

    local cmd_output
    cmd_output=$(cat "$tmp_output" 2>/dev/null)
    rm -f "$tmp_output" 2>/dev/null
    _LOG_LAST_OUTPUT="$cmd_output"

    local sub_status_tag sub_color
    if [[ $exit_code -eq 0 ]]; then
        sub_status_tag="[ OK ]"
        sub_color="$_C_GREEN"
    else
        sub_status_tag="[FALHA]"
        sub_color="$_C_RED"
    fi

    local sub_line="  ${description}..."
    local sub_target=55
    local sub_pad=$((sub_target - ${#sub_line}))
    [[ $sub_pad -lt 2 ]] && sub_pad=2
    local sub_padding
    sub_padding=$(printf '%*s' "$sub_pad" '')

    printf "%s%s%s%s%s\n" "$sub_line" "$sub_padding" "$sub_color" "$sub_status_tag" "$_C_RESET"
    return $exit_code
}

log_show_last() {
    local lines="${1:-25}"
    if [[ -n "$_LOG_LAST_OUTPUT" ]]; then
        printf "\n${_C_WHITE}--- Detalhes da Execução ---${_C_RESET}\n"
        echo "$_LOG_LAST_OUTPUT" | tail -n "$lines" | sed 's/^/  /'
        printf "\n"
    fi
}

log_finish() {
    :
}
