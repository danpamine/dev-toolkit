#!/usr/bin/env bash
# ==============================================================================
# eslint.sh - SAST Angular via ESLint sem poluição do repositório
# ==============================================================================

step_angular_eslint() {
    local label="$1"
    local desc="$2"

    local staged_ts=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && staged_ts+=("$file")
    done < <(git diff --cached --name-only --diff-filter=ACMR -- "*.ts" 2>/dev/null)

    if [[ ${#staged_ts[@]} -eq 0 ]]; then
        log_step "$label" "$desc" "OK" "Nenhum arquivo TypeScript alterado"
        summary_add "$desc" "OK" "Sem arquivos TS alterados"
        return 0
    fi

    if [[ ! -d "node_modules" ]]; then
        log_step "$label" "$desc" "FAIL" "node_modules ausente"
        summary_add "$desc" "FAIL" "Execute pnpm install"
        return 1
    fi

    local hash
    hash="$(printf '%s' "${staged_ts[@]}" | sha256sum | awk '{print $1}')"
    if cache_is_valid "eslint" "$hash"; then
        log_step "$label" "$desc" "OK" "Cache"
        summary_add "$desc" "OK" "Cache"
        return 0
    fi

    log_step_header "$label" "$desc"

    local tmp_cfg="eslint.dev-toolkit.$$.mjs"
    trap 'rm -f "$tmp_cfg" 2>/dev/null' EXIT INT TERM

    cat > "$tmp_cfg" << 'EOF'
import { createRequire } from 'node:module';
const req = createRequire(process.argv[1] || import.meta.url);
const js = req('@eslint/js');
const tseslint = req('typescript-eslint');

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      'no-eval': 'error',
      'no-implied-eval': 'error',
      'no-debugger': 'error',
      'no-console': ['warn', { allow: ['warn', 'error'] }]
    }
  }
);
EOF

    log_substep "Executando ESLint em ${#staged_ts[@]} arquivo(s)" \
        npx --yes --package=eslint --package=typescript-eslint --package=@eslint/js \
        eslint --config "$tmp_cfg" "${staged_ts[@]}"

    local exit_code=$?
    rm -f "$tmp_cfg" 2>/dev/null
    trap - EXIT INT TERM

    if [[ $exit_code -eq 0 ]]; then
        cache_save "eslint" "$hash"
        log_step "$label" "$desc" "OK"
        summary_add "$desc" "OK"
    else
        log_step "$label" "$desc" "FAIL"
        summary_add "$desc" "FAIL" "Resolva os apontamentos do ESLint"
        log_show_last 25
    fi
    return $exit_code
}
