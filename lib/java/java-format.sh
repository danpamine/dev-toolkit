#!/usr/bin/env bash
# ==============================================================================
# java-format.sh - Formatação Incremental via google-java-format
# ==============================================================================

step_java_format() {
    local label="$1"
    local desc="$2"

    local gjf_jar="$LOCAL_BIN/google-java-format.jar"
    if [[ ! -f "$gjf_jar" ]]; then
        log_step "$label" "$desc" "PULADO" "Formatador JAR ausente"
        summary_add "$desc" "SKIP" "google-java-format.jar ausente"
        return 0
    fi

    local staged_java=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && staged_java+=("$file")
    done < <(git diff --cached --name-only --diff-filter=ACMR -- "*.java" 2>/dev/null)

    if [[ ${#staged_java[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo Java alterado"
        summary_add "$desc" "OK" "Sem alterações"
        return 0
    fi

    log_step_header "$label" "$desc"

    local new_files=()
    local modified_files=()
    for file in "${staged_java[@]}"; do
        if git diff --cached --name-only --diff-filter=A -- "$file" 2>/dev/null | grep -q .; then
            new_files+=("$file")
        else
            modified_files+=("$file")
        fi
    done

    local formatted_files=()
    local exit_code=0

    # Arquivos novos: formatação total em lote
    if [[ ${#new_files[@]} -gt 0 ]]; then
        log_substep "Formatando ${#new_files[@]} arquivo(s) novo(s)" \
            java -jar "$gjf_jar" --replace "${new_files[@]}"
        if [[ $? -eq 0 ]]; then
            formatted_files+=("${new_files[@]}")
        else
            exit_code=1
        fi
    fi

    # Arquivos modificados: formatação incremental nos hunks
    local hunk_re='@@ -[0-9]+(,[0-9]+)? [+]([0-9]+)(,([0-9]+))? @@'
    for file in "${modified_files[@]}"; do
        local ranges_str=""
        while IFS= read -r hunk; do
            if [[ "$hunk" =~ $hunk_re ]]; then
                local n_start="${BASH_REMATCH[2]}"
                local n_count="${BASH_REMATCH[4]:-1}"
                if [[ "$n_count" -gt 0 ]]; then
                    local n_end=$((n_start + n_count - 1))
                    [[ -n "$ranges_str" ]] && ranges_str+=","
                    ranges_str+="${n_start}:${n_end}"
                fi
            fi
        done < <(git diff --cached --unified=0 -- "$file" 2>/dev/null | grep '^@@')

        [[ -z "$ranges_str" ]] && continue

        log_substep "Incremental: $file" java -jar "$gjf_jar" --replace --lines="$ranges_str" "$file"
        if [[ $? -eq 0 ]]; then
            formatted_files+=("$file")
        else
            exit_code=1
        fi
    done

    if [[ ${#formatted_files[@]} -gt 0 ]]; then
        git add "${formatted_files[@]}" 2>/dev/null
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "${#formatted_files[@]} arquivo(s) formatado(s)"
        summary_add "$desc" "OK" "${#formatted_files[@]} arquivo(s)"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Erro de sintaxe nos arquivos Java"
        log_show_last 20
    fi
    return $exit_code
}
