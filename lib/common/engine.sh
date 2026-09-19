#!/usr/bin/env bash
# ==============================================================================
# engine.sh - Orquestrador Assíncrono com Reenumeração e Logs Visíveis no Terminal
# ==============================================================================

declare -a _ENG_IDS=()
declare -a _ENG_DESCS=()
declare -a _ENG_FUNCS=()
declare -a _ENG_TOGGLES=()
declare -a _ENG_DEPS=()
declare -a _ENG_ACTIVE_INDICES=()

_ENG_TMP_DIR="/tmp/toolkit_engine_$$"

engine_reset() {
    _ENG_IDS=()
    _ENG_DESCS=()
    _ENG_FUNCS=()
    _ENG_TOGGLES=()
    _ENG_DEPS=()
    _ENG_ACTIVE_INDICES=()
    rm -rf "$_ENG_TMP_DIR"
    mkdir -p "$_ENG_TMP_DIR"
}

engine_register() {
    local id="$1"
    local desc="$2"
    local func="$3"
    local toggle_var="$4"
    local depends_on="${5:-}"

    _ENG_IDS+=("$id")
    _ENG_DESCS+=("$desc")
    _ENG_FUNCS+=("$func")
    _ENG_TOGGLES+=("$toggle_var")
    _ENG_DEPS+=("$depends_on")
}

engine_is_enabled() {
    local toggle_var="$1"
    [[ -z "$toggle_var" ]] && return 0
    local val="${!toggle_var:-1}"
    [[ "$val" == "1" || "$val" == "true" || "$val" == "yes" ]]
}

engine_run() {
    local suite_title="$1"
    local total_registered=${#_ENG_IDS[@]}

    _ENG_ACTIVE_INDICES=()
    for ((i=0; i<total_registered; i++)); do
        local toggle="${_ENG_TOGGLES[$i]}"
        if engine_is_enabled "$toggle"; then
            _ENG_ACTIVE_INDICES+=("$i")
        else
            summary_add "${_ENG_DESCS[$i]}" "SKIP" "Desativado via Feature Toggle"
        fi
    done

    local total_active=${#_ENG_ACTIVE_INDICES[@]}
    if [[ $total_active -eq 0 ]]; then
        printf "${_C_YELLOW}[INFO] Nenhuma validação habilitada.${_C_RESET}\n"
        return 0
    fi

    declare -A step_num_map=()
    declare -A step_state=()
    declare -A step_pids=()

    local seq=1
    for idx in "${_ENG_ACTIVE_INDICES[@]}"; do
        local id="${_ENG_IDS[$idx]}"
        step_num_map["$id"]="$seq"
        step_state["$id"]="PENDING"
        ((seq++))
    done

    local pending_count=$total_active

    while [[ $pending_count -gt 0 ]]; do
        for idx in "${_ENG_ACTIVE_INDICES[@]}"; do
            local id="${_ENG_IDS[$idx]}"
            local desc="${_ENG_DESCS[$idx]}"
            local func="${_ENG_FUNCS[$idx]}"
            local dep="${_ENG_DEPS[$idx]}"
            local s_num="${step_num_map[$id]}"
            local label="ETAPA ${s_num}/${total_active}"

            if [[ "${step_state[$id]}" == "PENDING" ]]; then
                if [[ -n "$dep" ]]; then
                    if [[ "${step_state[$dep]:-}" == "PENDING" || "${step_state[$dep]:-}" == "RUNNING" ]]; then
                        continue
                    elif [[ "${step_state[$dep]:-}" != "DONE_0" ]]; then
                        step_state["$id"]="SKIPPED_DEP"
                        summary_add "$desc" "SKIP" "Dependência (${dep}) falhou"
                        ((pending_count--))
                        continue
                    fi
                fi

                local out_file="${_ENG_TMP_DIR}/${id}.log"
                local meta_file="${_ENG_TMP_DIR}/${id}.meta"

                step_state["$id"]="RUNNING"
                (
                    start_t=$(date +%s)
                    "$func" "$label" "$desc" > "$out_file" 2>&1
                    code=$?
                    end_t=$(date +%s)
                    duration=$((end_t - start_t))
                    echo "${code}:${duration}" > "$meta_file"
                ) &
                step_pids["$id"]=$!
            fi
        done

        for idx in "${_ENG_ACTIVE_INDICES[@]}"; do
            local id="${_ENG_IDS[$idx]}"
            if [[ "${step_state[$id]}" == "RUNNING" ]]; then
                local pid="${step_pids[$id]}"
                if ! kill -0 "$pid" 2>/dev/null; then
                    wait "$pid" 2>/dev/null
                    local meta
                    meta=$(cat "${_ENG_TMP_DIR}/${id}.meta" 2>/dev/null || echo "1:0")
                    local exit_code="${meta%%:*}"
                    local duration="${meta##*:}"
                    step_state["$id"]="DONE_${exit_code}"
                    ((pending_count--))

                    local desc="${_ENG_DESCS[$idx]}"
                    local s_num="${step_num_map[$id]}"
                    local label="ETAPA ${s_num}/${total_active}"

                    if [[ "$exit_code" -eq 0 ]]; then
                        log_step "$label" "$desc" "OK" "${duration}s"
                        summary_add "$desc" "OK" "" "" "$duration"
                    else
                        log_step "$label" "$desc" "FAIL" "${duration}s"
                        summary_add "$desc" "FAIL" "Detalhes abaixo" "" "$duration"
                    fi
                fi
            fi
        done
        sleep 0.1
    done

    # Exibição direta e consolidada de logs de falhas no terminal
    local has_failures=0
    for idx in "${_ENG_ACTIVE_INDICES[@]}"; do
        local id="${_ENG_IDS[$idx]}"
        if [[ "${step_state[$id]}" =~ ^DONE_[1-9] ]]; then
            has_failures=1
            break
        fi
    done

    if [[ $has_failures -eq 1 ]]; then
        printf "\n${_C_RED}======================================================================${_C_RESET}\n"
        printf "${_C_RED}                     RELATÓRIO DE FALHAS NO TERMINAL                  ${_C_RESET}\n"
        printf "${_C_RED}======================================================================${_C_RESET}\n"

        for idx in "${_ENG_ACTIVE_INDICES[@]}"; do
            local id="${_ENG_IDS[$idx]}"
            local desc="${_ENG_DESCS[$idx]}"
            local state="${step_state[$id]}"
            local s_num="${step_num_map[$id]}"
            local log_path="${_ENG_TMP_DIR}/${id}.log"

            if [[ "$state" =~ ^DONE_[1-9] ]]; then
                local code="${state##DONE_}"
                printf "\n${_C_BYELLOW}[FALHA] ETAPA %s/%s: %s (Status de Saída: %s)${_C_RESET}\n" "$s_num" "$total_active" "$desc" "$code"
                printf "${_C_WHITE}----------------------------------------------------------------------${_C_RESET}\n"
                if [[ -s "$log_path" ]]; then
                    cat "$log_path"
                else
                    printf "  [Nenhuma saída registrada pelo comando]\n"
                fi
                printf "${_C_WHITE}----------------------------------------------------------------------${_C_RESET}\n"
            fi
        done
        printf "\n"
    fi

    # Limpeza imediata de arquivos temporários do ciclo
    rm -rf "$_ENG_TMP_DIR"
}
