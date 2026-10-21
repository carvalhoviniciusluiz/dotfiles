# dotfiles

Ambiente de desenvolvimento para trabalho com agentes de IA (Claude Code e Codex)
num Mac Apple Silicon (M1/M2…). Um `install.sh` recria tudo: ferramentas,
configurações, apps, fontes, terminal e integrações dos agentes.

## Instalar num Mac novo

```bash
xcode-select --install          # Command Line Tools (aceite a janela)
git clone https://github.com/carvalhoviniciusluiz/dotfiles.git ~/Development/dotfiles
cd ~/Development/dotfiles
./install.sh                    # pode rodar de novo quando quiser (idempotente)
```

O repositório é público: o `git clone` funciona sem login. O `install.sh` pede
o `gh auth login` no fim, para os agentes poderem usar o GitHub.

Opções:

| Opção            | O que faz                                                             |
| ---------------- | --------------------------------------------------------------------- |
| `--list`         | lista as etapas                                                       |
| `--only <etapa>` | roda uma etapa só (ex.: `--only links`)                               |
| `--with-bin`     | clona `carvalhoviniciusluiz/dotfiles-bin` em `~/bin`                  |
| `--macos-tweaks` | desliga no login: agente do Teams, Microsoft AutoUpdate, DockerHelper |

Arquivos que já existiam são movidos para `~/.dotfiles-backup/<data>/`.

## Depois do install.sh (manual)

1. **Terminal novo** (ou `exec zsh`).
2. **iTerm** → Ajustes → Perfis → selecione **Dotfiles** → _Outras ações… →
   Definir como padrão_ (o script faz isso sozinho se o iTerm estiver fechado).
3. **Codex**: abra, rode `/hooks` e escolha **Trust all** (hooks do ai-memory).
   Opcional: `codex mcp login context7`.
4. **Sublime Text**: abra uma vez; o Package Control instala os pacotes sozinho
   (Dracula, LSP, LSP-typescript, LSP-pyright, Terminus, A File Icon,
   SideBarEnhancements, EditorConfig, JsPrettier).
5. **Ajustes do Sistema**:
   - Privacidade e Segurança → **FileVault** (guarde a chave de recuperação)
   - Rede → **Firewall**
   - Siri e Spotlight → **Privacidade do Spotlight…** → `+` → ⌘⇧G →
     `~/.asdf` e `~/.local`
6. **Chrome** → Configurações → Desempenho → Economia de memória: **Máximo**.
7. Apps não instalados pelo script: **iTerm2**, **VS Code**, **Docker Desktop**
   (não deixar abrir no login), **Hopper** (opcional, para o REA). Depois de
   instalar o iTerm/VS Code: `./install.sh --only iterm` / `--only vscode`.

## O que é instalado

| Camada                                          | Itens                                                                                                                                                                                    |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Homebrew (mínimo)                               | `asdf`, `git`, `xz`, `zstd` — `Brewfile`                                                                                                                                                 |
| asdf (`tool-versions`)                          | Node 26, Python 3.14, Java Temurin 21, Rust, Lua, gh, ripgrep, fd, jq, uv, direnv, lefthook, gitleaks, shellcheck, delta, lazygit, just, fzf, starship, eza, bat, xh, dust, bottom (btm) |
| npm global                                      | pnpm, prettier, Codex CLI, ast-grep, ccusage, rea-agents                                                                                                                                 |
| uv tool                                         | Spec Kit (`specify`)                                                                                                                                                                     |
| Binários oficiais (`~/.local/opt`, com SHA-256) | watchexec, zoxide, tldr (tlrc), atuin, Ghidra 12.1.4 (+ natives mac_arm_64)                                                                                                              |
| Fontes                                          | Fira Code, FiraCode Nerd Font Mono                                                                                                                                                       |
| Apps                                            | Sublime Text 4, Sublime Merge (assinatura verificada)                                                                                                                                    |
| Agentes                                         | Claude Code + Codex: skills /commit /pr /review-changes, MCPs ai-memory, rea, playwright, context7; notificações; `AGENTS.md` global com inventário                                      |
| zsh                                             | autosuggestions, syntax-highlighting, histórico 50k, fzf, zoxide, starship, aliases                                                                                                      |
| Scripts (`~/.local/bin`)                        | `new-project`, `lefthook-init`, `agent-notify` + comandos para agentes: `ctx`, `check`, `bgrun`, `ports`, `dk`, `wt`, `ci-logs`, `sysload`, `agents-restore`                             |

Versões e checksums ficam em `versions.env`; atualize os dois juntos.

## Estrutura

```
home/            espelho de ~ (linkado: editar em ~ edita aqui)
skills/          /commit, /pr, /review-changes (linkados no Claude Code e no Codex)
docs/            ai-memory entre máquinas
apps/            iTerm2 (perfil dinâmico + Dracula), VS Code, Sublime Text/Merge
claude/          patch de ~/.claude/settings.json (permissões e hooks)
codex/           ajuste de ~/.codex/config.toml (notificações)
macos/tweaks.sh  serviços desligados no login
Brewfile, tool-versions, asdf-plugins.txt, versions.env
install.sh
```

## Depois de um travamento

`agents-restore` lista as conversas do Claude Code e do Codex com atividade nas
últimas 6 horas (id, pasta, assunto) e reabre as escolhidas, cada uma numa aba do
iTerm já retomando a conversa. Sessões ainda abertas aparecem como `[rodando]`
e não são duplicadas.

## Manter atualizado

Os arquivos de `home/` são links: mudanças feitas em `~/.zshrc`,
`~/.config/starship.toml`, `~/.codex/AGENTS.md` etc. já aparecem no `git status`
deste repositório. Ao instalar algo novo, registre aqui (`tool-versions`,
`versions.env`, `install.sh`) e commite:

```bash
cd ~/Development/dotfiles && gitleaks git --staged && git commit -am "..." && git push
```

**Nunca** coloque aqui tokens, chaves ou `.env`: o lefthook roda o gitleaks a
cada commit.
