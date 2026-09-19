// eslint.config.dev-toolkit.mjs — Fallback ESLint flat config para projetos Angular sem config própria
// Este arquivo é copiado temporariamente para a RAIZ do projeto pelo dev-toolkit,
// para que os imports resolvam do node_modules do projeto.
// Se o projeto tem seu próprio eslint.config.js/mjs, ele é usado no lugar deste.
import { createRequire } from 'node:module';

const req = createRequire(process.argv[1] || import.meta.url);

const js = req('@eslint/js');
const tseslint = req('typescript-eslint');

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-empty-function': ['error', { allow: ['constructors', 'arrowFunctions'] }],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'no-debugger': 'error',
      'no-alert': 'error',
      'no-eval': 'error',
      'no-implied-eval': 'error',
      'no-new-wrappers': 'error',
      'no-throw-literal': 'error',
      'no-extra-semi': 'error',
      'no-unreachable': 'error',
      'no-unused-private-class-members': 'error',
      'prefer-const': 'error',
      semi: ['error', 'always'],
      quotes: ['error', 'single'],
      indent: ['error', 2],
      'comma-dangle': 'off',
      'eol-last': ['error', 'always'],
      'no-trailing-spaces': 'error',
      'no-multiple-empty-lines': ['error', { max: 1, maxEOF: 1, maxBOF: 0 }]
    }
  },
  {
    ignores: ['**/node_modules/**', '**/dist/**', '**/.angular/**', '**/coverage/**']
  }
);
