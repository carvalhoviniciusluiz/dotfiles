# Ambiente desta máquina

Instruções globais para agentes de código neste computador (lidas pelo Codex e,
via `~/.claude/CLAUDE.md`, pelo Claude Code). As regras de cada repositório
(AGENTS.md / CLAUDE.md do projeto) têm prioridade sobre este arquivo.

## Idioma

- Responda ao usuário em português do Brasil.
- Ao orientar o usuário em menus de apps (iTerm, Ajustes do Sistema, Chrome),
  use os nomes em português que aparecem na tela.
- Código, nomes de identificadores e mensagens de commit seguem o padrão do
  repositório; sem padrão definido, use inglês.

## Máquina

- MacBook M1 (arm64), macOS 14 (Sonoma; o usuário não quer atualizar para o 15+),
  **8 GB de RAM**. Evite processos pesados em paralelo (vários dev servers,
  builds e contêineres ao mesmo tempo) e encerre o que iniciar quando terminar.
- Homebrew não tem bottles para macOS 14 e compila tudo do código-fonte. **Não
  use `brew install`** sem perguntar; prefira asdf, binários oficiais ou npm/uv.

## Regras de instalação

- Ordem de preferência: `asdf plugin add` + `asdf install` → binário oficial do
  GitHub em `~/.local/opt/<nome>-<versão>` com link em `~/.local/bin` (conferir
  SHA-256) → `npm i -g` / `uv tool install` → brew (só com permissão).
- Depois de `npm install -g`, rode `asdf reshim nodejs`.
- **Ao instalar ou remover uma ferramenta, atualize o Inventário abaixo.**

## Dotfiles (backup e reprodução desta máquina)

- Repositório: `~/Development/dotfiles` (GitHub público `carvalhoviniciusluiz/dotfiles`; sem segredos).
  `install.sh` recria tudo num Mac Apple Silicon novo (`--list` mostra as etapas).
- Os arquivos em `home/` estão **linkados** em `~` (ex.: `~/.zshrc`,
  `~/.config/starship.toml`, este `AGENTS.md`): editar o arquivo em `~` já edita
  o repositório.
- **Ao instalar uma ferramenta ou mudar uma configuração, reflita no dotfiles**:
  versões em `tool-versions`/`versions.env` (com SHA-256), plugins em
  `asdf-plugins.txt`, passos no `install.sh`. Não commite nem faça push sem
  pedido do usuário; rode `gitleaks git --staged` antes.

## Comandos para agentes (use-os)

Scripts em `~/.local/bin` feitos para agentes: sem perguntas interativas, saída
curta, código de saída 0 = ok. Rode `<comando> --help` para detalhes.

| Situação                        | Comando                                                                                                                                                                                         |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Começar a trabalhar num projeto | `ctx` — stack, gerenciador de pacotes, comandos (justfile/scripts), versões, regras (AGENTS.md), CI, estado do Git. **Rode antes de explorar arquivos.**                                        |
| Validar mudanças                | `check` (lint + tipos + testes, detectados ou `just check`); `check --fast` pula testes; `--only lint\|types\|test`. **Rode antes de dizer que terminou.**                                      |
| Subir servidor/watcher          | `bgrun start <nome> --wait-port <porta> -- <comando>` (nunca rode servidores em primeiro plano). `bgrun logs <nome>`, `bgrun list`. **Ao terminar: `bgrun stop <nome>`** (ou `bgrun stop-all`). |
| "Porta em uso"                  | `ports <porta>` mostra quem usa; `ports free <porta>` encerra (só processos do usuário).                                                                                                        |
| Precisa de Docker               | `dk up` (abre e espera ficar pronto); `dk down` ao terminar; `dk status`. O Docker **não** sobe sozinho.                                                                                        |
| Trabalho paralelo/isolado       | `wt new <branch> [--from base] [--env]` cria `../<repo>.worktrees/<branch>`; `wt list`; `wt rm <branch>`.                                                                                       |
| CI falhou                       | `ci-logs` (última execução da branch: jobs e trecho do log que falhou).                                                                                                                         |
| Antes de iniciar algo pesado    | `sysload` (memória livre, swap, maiores consumidores); saída 1 = memória sob pressão → não inicie mais nada.                                                                                    |
| Avisar o usuário                | `agent-notify "<título>" "<mensagem>"` (notificação do macOS).                                                                                                                                  |

Skills do usuário (Claude Code e Codex): `/commit`, `/pr` (só quando o usuário
chamar; sempre pedem confirmação) e `/review-changes` (revisão das mudanças locais).

## Gerenciadores de pacotes

- JavaScript/TypeScript: **pnpm** (a não ser que o projeto já use npm, yarn ou
  bun, conforme o lockfile). Globais do pnpm em `~/Library/pnpm/bin`.
- Python: **uv** (`uv init`, `uv add`, `uv run`, `uv venv`, `uv tool install`).
  Não instale pacotes no Python global com pip.

## Inventário

Use esta seção para responder "o que temos para X?" sem vasculhar o sistema.

### Linguagens (asdf, `~/.tool-versions`)

| Linguagem | Versão          | Observação                                                                                                                                                                                                                                                            |
| --------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Node.js   | 26.12.0         | globais npm: pnpm, prettier, rea-agents, @openai/codex, @ast-grep/cli, ccusage                                                                                                                                                                                        |
| Python    | 3.14.8          | compilado com xz/zstd do brew (`lzma`, `compression.zstd` ok; sem `tkinter`). Para reinstalar: `CPPFLAGS="-I/opt/homebrew/opt/xz/include -I/opt/homebrew/opt/zstd/include" LDFLAGS="-L/opt/homebrew/opt/xz/lib -L/opt/homebrew/opt/zstd/lib" asdf install python <v>` |
| Java      | Temurin 21.0.12 | `JAVA_HOME` no `~/.zshrc`                                                                                                                                                                                                                                             |
| Rust      | 1.99.1          |                                                                                                                                                                                                                                                                       |
| Lua       | 5.5.1           |                                                                                                                                                                                                                                                                       |

### Ferramentas de linha de comando

| Para quê                             | Ferramenta                                                                                                                                                  | Origem                  |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| Buscar texto em código               | `rg` (ripgrep)                                                                                                                                              | asdf                    |
| Achar arquivos/pastas                | `fd`                                                                                                                                                        | asdf                    |
| Ler/filtrar JSON                     | `jq`                                                                                                                                                        | asdf                    |
| Busca/refatoração estrutural (AST)   | `ast-grep` / `sg` — prefira a regex em mudanças em massa                                                                                                    | npm                     |
| Comandos padronizados do projeto     | `just` — se houver `justfile`, use `just <receita>`                                                                                                         | asdf                    |
| Rodar algo a cada mudança de arquivo | `watchexec` (ex.: `watchexec -e ts -- pnpm test`)                                                                                                           | binário, `~/.local/opt` |
| Spec → plano → tarefas               | `specify` (GitHub Spec Kit)                                                                                                                                 | `uv tool`               |
| GitHub (PRs, issues, CI)             | `gh` (logado como `carvalhoviniciusluiz`, HTTPS)                                                                                                            | asdf                    |
| Python moderno                       | `uv`                                                                                                                                                        | asdf                    |
| Variáveis por projeto                | `direnv` (`.envrc`; nunca commitar segredos, use `.envrc.example`)                                                                                          | asdf                    |
| Hooks de commit                      | `lefthook` + `lefthook-init` (copia `~/.config/lefthook/lefthook.yml`: gitleaks, prettier, shellcheck)                                                      | asdf / `~/.local/bin`   |
| Detectar segredos                    | `gitleaks` (`gitleaks git --staged` antes de commitar)                                                                                                      | asdf                    |
| Lint de shell                        | `shellcheck`                                                                                                                                                | asdf                    |
| Formatar JS/TS/JSON/MD/YAML          | `prettier`                                                                                                                                                  | npm                     |
| Diffs do Git legíveis                | `delta` (pager do git, tema Dracula)                                                                                                                        | asdf                    |
| Interface Git no terminal            | `lazygit` (alias `lg`)                                                                                                                                      | asdf                    |
| Busca interativa                     | `fzf` (Ctrl+R histórico, Ctrl+T arquivos)                                                                                                                   | asdf                    |
| Pular para pastas frequentes         | `zoxide` (`z <parte>`, `zi`)                                                                                                                                | binário, `~/.local/opt` |
| Prompt                               | `starship` (`~/.config/starship.toml`)                                                                                                                      | asdf                    |
| `ls`/`cat` melhores                  | `eza` (`l`, `ll`, `la`, `lt`, com ícones), `bat`                                                                                                            | asdf                    |
| Exemplos práticos de comandos        | `tldr <comando>` (tlrc; páginas em português)                                                                                                               | binário, `~/.local/opt` |
| Criar projeto no padrão              | `new-project <nome> [pasta]` (git main, AGENTS.md + CLAUDE.md, justfile, lefthook, .editorconfig, .envrc.example; modelos em `~/.config/project-template/`) | `~/.local/bin`          |
| Notificação do macOS                 | `agent-notify <título> [msg]` (usado pelos hooks Stop/Notification do Claude Code)                                                                          | `~/.local/bin`          |
| Testar APIs HTTP                     | `xh` (ex.: `xh :3000/api/users`, `xh POST :3000/login email=a@b.c`)                                                                                         | asdf                    |
| Espaço em disco por pasta            | `dust [pasta]`                                                                                                                                              | asdf                    |
| Monitor de processos/memória         | `btm` (bottom; interativo, para o usuário) — agentes usem `sysload`                                                                                         | asdf                    |
| Histórico de comandos                | `atuin` (Ctrl+R; SQLite em `~/.atuin`; sincronização desligada)                                                                                             | binário, `~/.local/opt` |
| Custo de uso do Claude Code          | `ccusage daily` / `ccusage monthly`                                                                                                                         | npm                     |
| Git                                  | 2.56 do brew (`/opt/homebrew/bin/git`); 2.39 do Xcode em `/usr/bin/git`                                                                                     | brew                    |

Em shells de agentes (sem TTY ou com `CLAUDECODE`), `ls` e `cat` são os
originais do sistema; os aliases `eza`/`bat` só valem no terminal do usuário.

### Agentes, MCP e engenharia reversa

| Item                     | Situação                                                                                                                                     |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude Code              | MCPs: ai-memory, rea (pede aprovação: `ask`), playwright, context7; hooks Stop/Notification → `agent-notify`                                 |
| Codex CLI 0.163          | MCPs: ai-memory, rea, playwright, context7 (OAuth); notificações `[tui]` via OSC 9 quando a aba não está em foco                             |
| ai-memory 3.1.1          | memória compartilhada entre Claude e Codex; serviço LaunchAgent, web em http://127.0.0.1:49374/web                                           |
| REA (`rea-agents@6.7.0`) | engenharia reversa via MCP; Ghidra 12.1.4 em `~/.local/opt/ghidra_12.1.4_PUBLIC` (natives mac_arm_64 compilados), Hopper em `~/Applications` |

### Apps e editores

| App            | CLI      | Observação                                                                                                                                                                                           |
| -------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| iTerm2         | —        | Dracula, FiraCode Nerd Font Mono, "Edição de texto natural" (⌥⌫ apaga palavra); janela Hotkey com ⌃\` (perfil Hotkey); sem integração de shell (o usuário não quer a barra de comando nem as marcas) |
| VS Code        | `code`   | Dracula, Fira Code                                                                                                                                                                                   |
| Sublime Text 4 | `subl`   | Dracula, Fira Code, LSP (TS/Python), Terminus, JsPrettier                                                                                                                                            |
| Sublime Merge  | `smerge` | cliente Git gráfico                                                                                                                                                                                  |
| Docker Desktop | `docker` | **não inicia com o sistema**; use `dk up` / `dk down`                                                                                                                                                |

Serviços desligados no login (desempenho, `macos/tweaks.sh`): agente do Teams,
Microsoft AutoUpdate, DockerHelper. Spotlight ignora `~/.asdf` e `~/.local`.

### Terminal (zsh, `~/.zshrc`)

- Sugestões do histórico (zsh-autosuggestions), destaque de sintaxe
  (zsh-syntax-highlighting), ↑/↓ filtram histórico pelo que foi digitado,
  Tab com menu e sem diferenciar maiúsculas, histórico de 50.000 comandos.
- Plugins em `~/.local/share/zsh/plugins/`.
- Prompt starship em uma linha (` ~/pasta on  main❯`), símbolos Nerd Font.
- atuin (Ctrl+R), fzf (Ctrl+T), zoxide (`z`, `zi`), aliases Git (`gs`, `gl`, `gd`,
  `gds`, `gco`, `gsw`, `gp`, `lg`) e navegação (`..`, `...`, `dev`).

## Git e segurança

- Não faça commit, push, merge ou force-push sem pedido explícito.
- Nunca inclua segredos (tokens, senhas, chaves, `.env`) em commits; rode
  `gitleaks git --staged` antes de commitar quando houver dúvida.
- `.gitignore` global em `~/.config/git/ignore` (`.env*`, `.envrc`, chaves, `.DS_Store`).
- Endereços `git@github.com:` são convertidos para HTTPS (não há chave SSH).
- Em repositórios novos, a branch padrão é `main`.
