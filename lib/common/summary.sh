#!/usr/bin/env bash
# ==============================================================================
# summary.sh - Resumo Executivo da Validação
# ==============================================================================

if [[ -t 1 ]]; then
    _SU_OK=$'\033[0;32m'
    _SU_FAIL=$'\033[0;31m'
    _SU_SKIP=$'\033[0;33m'
    _SU_RESET=$'\033[0m'
    _SU_DIM=$'\033[2m'
    _SU_BOLD=$'\033[1m'
    _SU_CYAN=$'\033[0;36m'
    _SU_WHITE=$'\033[0;37m'
    _SU_SUCCESS=$'\033[1;32m'
    _SU_ERROR=$'\033[1;31m'
else
    _SU_OK=""
    _SU_FAIL=""
    _SU_SKIP=""
    _SU_RESET=""
    _SU_DIM=""
    _SU_BOLD=""
    _SU_CYAN=""
    _SU_WHITE=""
    _SU_SUCCESS=""
    _SU_ERROR=""
fi

declare -a _SU_STEPS=()
declare -a _SU_STATUSES=()
declare -a _SU_DETAILS=()
declare -a _SU_ACTIONS=()
declare -a _SU_TIMES=()
_SU_TOTAL=0

summary_reset() {
    _SU_STEPS=()
    _SU_STATUSES=()
    _SU_DETAILS=()
    _SU_ACTIONS=()
    _SU_TIMES=()
    _SU_TOTAL=0
}

summary_add() {
    local step="$1"
    local status="$2"
    local detail="${3:-}"
    local action="${4:-}"
    local time="${5:-${_LOG_LAST_STEP_TIME:-0}}"

    _SU_STEPS[$_SU_TOTAL]="$step"
    _SU_STATUSES[$_SU_TOTAL]="$status"
    _SU_DETAILS[$_SU_TOTAL]="$detail"
    _SU_ACTIONS[$_SU_TOTAL]="$action"
    _SU_TIMES[$_SU_TOTAL]="$time"
    _SU_TOTAL=$((_SU_TOTAL + 1))
}

summary_print() {
    local title="${1:-RESUMO DA VALIDAÇÃO}"
    local success_msg="${2:-O projeto atende aos critérios para abertura de PR!}"
    local fail_msg="${3:-O projeto NÃO atende aos critérios para abertura de PR.}"
    local has_fail=false

    local i
    for ((i = 0; i < _SU_TOTAL; i++)); do
        if [[ "${_SU_STATUSES[$i]}" == "FAIL" ]]; then
            has_fail=true
            break
        fi
    done

    printf "\n"
    printf "${_SU_CYAN}==================================================${_SU_RESET}\n"
    printf "${_SU_CYAN}  %-48s${_SU_RESET}\n" "$title"
    printf "${_SU_CYAN}==================================================${_SU_RESET}\n\n"

    for ((i = 0; i < _SU_TOTAL; i++)); do
        local step="${_SU_STEPS[$i]}"
        local status="${_SU_STATUSES[$i]}"
        local detail="${_SU_DETAILS[$i]}"
        local time="${_SU_TIMES[$i]}"
        local status_label color

        case "$status" in
            OK)   status_label="[ OK ]";    color="$_SU_OK"   ;;
            FAIL) status_label="[FALHA]";   color="$_SU_FAIL"  ;;
            SKIP) status_label="[PULADO]";  color="$_SU_SKIP"  ;;
            *)    status_label="[ ??? ]";   color=""           ;;
        esac

        local pad_len=$((36 - ${#step}))
        [[ $pad_len -lt 1 ]] && pad_len=1
        local padding
        padding=$(printf '%*s' "$pad_len" '')

        printf "  %s%s: %s%s%s" "$step" "$padding" "$color" "$status_label" "$_SU_RESET"
        if [[ -n "$detail" ]]; then
            printf " ${_SU_WHITE}(%s)${_SU_RESET}" "$detail"
        fi
        if [[ -n "$time" && "$time" -gt 0 ]]; then
            printf " ${_SU_DIM}%ss${_SU_RESET}" "$time"
        fi
        printf "\n"
    done

    printf "\n"
    if [[ "$has_fail" == true ]]; then
        printf "${_SU_ERROR}[ FALHA ]${_SU_RESET} %s\n\n" "$fail_msg"
        local has_actions=false
        for ((i = 0; i < _SU_TOTAL; i++)); do
            if [[ "${_SU_STATUSES[$i]}" == "FAIL" && -n "${_SU_ACTIONS[$i]}" ]]; then
                if [[ "$has_actions" == false ]]; then
                    printf "${_SU_BOLD}Ações recomendadas:${_SU_RESET}\n"
                    has_actions=true
                fi
                printf "  ${_SU_FAIL}•${_SU_RESET} %s: %s\n" "${_SU_STEPS[$i]}" "${_SU_ACTIONS[$i]}"
            fi
        done
    else
        printf "${_SU_SUCCESS}[ SUCESSO ]${_SU_RESET} %s\n" "$success_msg"
    fi

    local total_time=0
    if [[ -n "${_LOG_GLOBAL_START:-}" && "$_LOG_GLOBAL_START" -gt 0 ]]; then
        total_time=$(( $(date +%s) - _LOG_GLOBAL_START ))
    fi
    printf "\n  ${_SU_BOLD}Tempo total: ${total_time}s${_SU_RESET}\n"
    printf "${_SU_CYAN}==================================================${_SU_RESET}\n\n"
}

summary_has_failures() {
    local i
    for ((i = 0; i < _SU_TOTAL; i++)); do
        if [[ "${_SU_STATUSES[$i]}" == "FAIL" ]]; then
            return 0
        fi
    done
    return 1
}
