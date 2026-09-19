# Dev Toolkit

Git hooks que aplicam qualidade, segurança e verificações de dependências em projetos **Java** e **Angular**, sem alterar nenhum arquivo do projeto.

## Por que usar

O Dev Toolkit existe para que o desenvolvedor entregue qualidade de forma consistente, independentemente de os projetos corporativos em que atua implementarem ou não essas verificações. Hooks, linters e scanners configurados repositório por repositório dependem de permissões, aprovações e manutenção em cada projeto, e frequentemente simplesmente não existem lá. Aqui o padrão fica em um único lugar, sob controle do dev, e chega a cada máquina pelo self-update no próximo commit.

---

## Dicionário de Siglas: O que são e por que validar?

Entender o propósito de cada tipo de validação ajuda a identificar rapidamente o que corrigir quando o hook apontar uma falha:

* **SAST (Static Application Security Testing)**:
  * *O que é*: Teste estático de segurança aplicado diretamente ao código-fonte que você escreve (arquivos `.java` e `.ts`).
  * *Por que validar*: Identifica falhas lógicas e riscos de invasão (como SQL Injection, Cross-Site Scripting (XSS), uso de funções perigosas como `eval`, segredos em texto puro e desserialização insegura) sem precisar compilar ou rodar o sistema.
* **SCA (Software Composition Analysis)**:
  * *O que é*: Análise de segurança das dependências de terceiros declaradas nos manifestos (`pom.xml`, `package-lock.json`).
  * *Por que validar*: Mais de 80% do código de uma aplicação moderna vem de bibliotecas open-source. O SCA vasculha se alguma biblioteca que você importou possui falhas de segurança conhecidas e bloqueia aquelas que já contam com versão corrigida (patch disponível).
* **SBOM (Software Bill of Materials)**:
  * *O que é*: A "lista formal de ingredientes" de software, mapeando o inventário exato de pacotes, versões, licenças e hashes em formato padrão de mercado (CycloneDX ou SPDX).
  * *Por que validar*: Permite rastreabilidade instantânea. Se uma vulnerabilidade crítica de dia-zero surgir no ecossistema, o SBOM permite saber imediatamente se qualquer projeto da empresa está exposto.
* **AST (Abstract Syntax Tree)**:
  * *O que é*: A árvore de sintaxe abstrata do código-fonte. O analisador decompõe seu código em uma estrutura gramatical em vez de tratá-lo como mero texto ou Regex.
  * *Por que validar*: Ferramentas baseadas em AST (como `ast-grep`) executam em milissegundos e detectam com precisão cirúrgica comandos proibidos de depuração (`debugger;`, `console.log`, chamadas diretas a prints de sistema) e anti-patterns sem gerar falsos positivos.
* **CVE (Common Vulnerabilities and Exposures)**:
  * *O que é*: O identificador público mundial de uma vulnerabilidade conhecida (ex: `CVE-2024-12345`).
  * *Por que validar*: Permite checar a severidade da falha e confirmar se o patch publicado resolve a vulnerabilidade apontada pelo scanner.
* **TTL (Time-To-Live)**:
  * *O que é*: O tempo de vida útil do cache local. No Dev Toolkit, o TTL é configurado estritamente para **3 horas** (10800 segundos).
  * *Por que usar*: Scanners de CVEs consultam bases externas que são atualizadas várias vezes ao dia. O cache evita reexecuções demoradas a cada commit consecutivo, mas expira a cada 3 horas para garantir que novas vulnerabilidades catalogadas no dia sejam detectadas antes do push.
* **DAG (Directed Acyclic Graph)**:
  * *O que é*: Grafo direcionado acíclico de dependências. É o algoritmo do motor interno do Dev Toolkit.
  * *Por que usar*: Permite disparar checagens leves em paralelo e só aguardar compilação ou build para as etapas que dependem estritamente dos binários gerados.

---

## Princípios de Projeto

* **Invasão Zero aos Projetos**: Nenhuma linha de código, arquivo de configuração (`.eslintrc`, `tsconfig`, etc.) ou dependência é adicionada aos repositórios dos projetos.
* **Ambiente Restrito**: Projetado para Windows corporativo via Git Bash, operando no espaço de usuário sem privilégios de Administrador.
* **Execução Assíncrona & Paralela**: As ferramentas rodam em paralelo conforme suas dependências, reduzindo expressivamente o tempo de espera no terminal.
* **Buffer Isolado de Logs**: Em caso de falhas concorrentes de múltiplos testes ou scanners, os relatórios são organizados sequencialmente ao final da esteira, evitando mensagens sobrepostas ou truncadas.
* **Self-Update Transparente**: O Dev Toolkit sincroniza com seu repositório oficial a cada execução de qualquer fluxo Git e gerencia binários CLI atualizados em background.

---

## Pré-requisitos

* **Sistema Operacional**: Windows 10/11 ou Linux.
* **Terminal**: Git Bash (MSYS2).
* **Git**: `git` configurado e acessível no terminal.
* **Java** (para projetos Java): JDK 17+ e Apache Maven (`mvn`) no `PATH`.

---

## Instalação Passo a Passo

Abra o terminal **Git Bash** e siga os passos abaixo:

### 1. Clonar o Dev Toolkit
Clone o repositório em uma pasta local permanente no seu diretório de usuário (ex: `~/dev-toolkit`):

    git clone https://github.com/danpamine/dev-toolkit.git "$HOME/dev-toolkit"
    cd "$HOME/dev-toolkit"

### 2. Configurar o Shell e Utilitários
Execute o configurador de ambiente. Ele registrará o comando global `dev` no seu `.bashrc` e aplicará exclusões de arquivos temporários no seu Git global:

    bash scripts/setup-bashrc.sh
    source ~/.bashrc

Se for atuar em projetos **Angular**, instale o ecossistema Node.js LTS e PNPM corporativo sem precisar de privilégios de administrador:

    dev setup-node
    source ~/.bashrc

### 3. Ativar os Hooks nos Repositórios
Navegue até a pasta raiz onde ficam seus repositórios de trabalho e ative os Git Hooks locais:

    dev hooks-install /c/Users/$USERNAME/Development

> O comando acima apenas configura o `git config core.hooksPath` apontando para o seu Dev Toolkit local. Nenhum arquivo dos projetos é modificado e nada é enviado ao repositório remoto.

---

## Fluxos de Validação Automatizados

| Evento Git | Escopo de Validação | Ferramentas Ativas |
| :--- | :--- | :--- |
| **`git commit`** | Arquivos em Staging (Incremental) | • **Gitleaks**: Busca credenciais e tokens em staged diff.<br>• **Formatadores**: Google Java Format incremental para Java / Prettier para Angular.<br>• **Linters**: Checkstyle e ast-grep para Java / ESLint Security e ast-grep para Angular.<br>• **Lockfile Sync**: Sincronização do `package-lock.json` mantendo PNPM isolado. |
| **`git push`** | Branch vs Branch Pai Remota | • **Version Check**: Validação semântica de incremento de versão (`pom.xml` ou `package.json`).<br>• **SCA**: Trivy + Syft e OSV-Scanner (aponta todas as vulnerabilidades com patch mapeado).<br>• **SAST**: Semgrep OSS (regras semânticas) + SpotBugs/FindSecBugs (Java).<br>• **Qualidade & Contratos**: OpenAPI/Swagger linter e PMD.<br>• **Build & Testes**: `mvn test jacoco:report` ou testes do `package.json`. |
| **`git pull`** | Todo o Repositório | • **Gitleaks Full Scan**: Inspeciona a integridade total do código após o merge para barrar segredos recém-puxados do remoto. |

---

## Utilitário CLI `dev`

O Dev Toolkit disponibiliza o utilitário `dev` diretamente no terminal:

    dev install        Instala dependências do projeto (mvn install | pnpm install)
    dev run            Inicia a aplicação com profiles locais configurados
    dev test           Executa a suíte de testes unitários do projeto
    dev lint           Roda manualmente as verificações do pre-commit
    dev format         Formata o código fonte (Google Java Format / Prettier)
    dev build          Compila o projeto (mvn package | ng build)
    dev verify         Validação completa do projeto (Gitleaks Full + Pre-Commit + Pre-Push)
    dev hooks-install  Ativa os Git Hooks na pasta atual ou caminho informado
    dev hooks-remove   Remove os Git Hooks dos repositórios
    dev clean          Limpa logs temporários e cache local
    dev setup-node     Instala/Atualiza NVS, Node LTS e PNPM corporativo

---

## Feature Toggles e Customizações

Todas as ferramentas vêm ativadas por padrão (`1`). Caso seja necessário desativar temporariamente alguma validação ou customizar comandos:

> **ATENÇÃO:** Nunca edite os arquivos `global.env` na pasta do toolkit. Eles são versionados e qualquer edição direta neles causará conflito e bloqueará o processo de auto-update automático via Git.

### Como customizar ou desativar ferramentas
Utilize a CLI oficial do toolkit, que grava as configurações em arquivo `.env` na raiz do Dev Toolkit (ignorado pelo Git):

    # Desativa uma etapa de forma persistente no seu ambiente
    dev env-set FEATURE_CHECKSTYLE 0
    dev env-set FEATURE_SPOTBUGS 0

    # Desativa apenas para um único commit no terminal atual
    FEATURE_CHECKSTYLE=0 git commit -m "feat: ajuste pontual"

    # Customiza o script de compilação ou teste do projeto
    dev env-set ANGULAR_BUILD_CMD "pnpm run build:custom"
    dev env-set JAVA_TEST_CMD "mvn test -Dtest=SmokeTest"

### Chaves de Toggles Disponíveis

* `FEATURE_GITLEAKS` (Detecção de segredos em staging)
* `FEATURE_GITLEAKS_PULL` (Detecção de segredos pós-pull)
* `FEATURE_JAVA_FORMAT` (Google Java Format)
* `FEATURE_CHECKSTYLE` (Regras de estilo Checkstyle)
* `FEATURE_PRETTIER` (Formatação Prettier Angular)
* `FEATURE_ESLINT` (Linter de segurança ESLint)
* `FEATURE_AST_GREP` (Linter estrutural AST)
* `FEATURE_LOCKFILE` (Sincronização de package-lock)
* `FEATURE_VERSION_CHECK` (Incremento semântico de versão)
* `FEATURE_SCA` (Trivy SCA + Syft SBOM)
* `FEATURE_OSV` (Google OSV-Scanner)
* `FEATURE_PMD` (Qualidade de código Java)
* `FEATURE_OPENAPI` (Validação de contratos Swagger/OpenAPI)
* `FEATURE_SPOTBUGS` (SpotBugs + FindSecBugs)
* `FEATURE_SEMGREP` (SAST Semgrep)
* `FEATURE_BUILD` (ng build)
* `FEATURE_TEST` (Testes unitários Angular via package.json)
* `FEATURE_MAVEN_VERIFY` (Testes Maven e JaCoCo)

---

## Cache e Logs de Execução

* **Cache Inteligente**: As validações calculam hashes SHA-256 dos arquivos relevantes. Scanners pesados (Trivy e OSV) respeitam o TTL de **3 horas** (10800s). Para ignorar o cache manualmente:

      DEV_TOOLKIT_NO_CACHE=1 git push

* Visualização de Falhas: Quando uma ou mais verificações falham, seus logs completos são impressos de forma destacada no terminal. Zero arquivos residuais permanecem no computador.