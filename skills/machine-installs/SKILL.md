---
name: machine-installs
description: Required before installing, updating or removing anything on this Mac outside the project's own dependency folders — apps, CLIs, binaries, language versions (asdf), global packages (npm -g, uv tool, pip, cargo install, brew), MCP servers, skills, hooks, LaunchAgents, services, Docker volumes left behind, aliases, PATH or ~/.zshrc changes, links in ~/.local/bin, the dotfiles or the global AGENTS.md — and before placing a project's helper or tool outside its repository. Routes the request to the machine's installer agent (INSTALADOR_MACOS) and tells you what to do while it answers.
---

# Installs, updates and removals on this Mac

The user made one agent responsible for every install, update and removal on
this machine: the session **`INSTALADOR_MACOS`**. You do not install things
yourself. Full rules (Portuguese):

- `~/Development/dotfiles/docs/protocolo-de-instalacao.md`: who, when, how
  to ask, request template, removal, activation prompt, handoff.
- `~/Development/dotfiles/docs/protocolo-de-atualizacao.md`: how updates are
  done safely (`updates-check`).
- `~/.codex/AGENTS.md`, sections "Regras de instalação" and "Organização":
  where each kind of thing lives (global vs project).

## Does this need the installer?

- **Yes:** anything that stays on the machine outside the project's working
  folder, or changes the system. That covers programs, language versions,
  global packages, MCP/skill/hook/service registrations, aliases, PATH,
  `~/.config`, `~/.local/bin`, the dotfiles, and project helpers living
  outside the repo.
- **No:** the project's own dependency manager inside the repo
  (`node_modules`, `.venv`, `.build/`, `target/`, lockfiles), build artifacts
  in the repo or worktree, and temporary files in the session scratchpad.
- Unsure: ask the installer.

## Steps

1. Run `ListAgents`. If `INSTALADOR_MACOS` is listed, send it the request
   below with `SendMessage` and **wait for its answer** before installing.
   You may continue with work that does not depend on it.
2. If it is not listed or does not answer:
   - write the request to
     `~/.local/share/instalador/fila/YYYY-MM-DD-<project>-<item>.md`;
   - tell the user, in Portuguese: "Preciso do agente instalador para:
     <resumo>. Ficha em <path>. Para ativá-lo: `agents-restore --list` e
     retome a sessão INSTALADOR_MACOS, ou abra uma sessão nova com o prompt
     de ativação de `docs/protocolo-de-instalacao.md` (seção 6)."
   - Never reopen sessions yourself, and never work around the request by
     installing somewhere else.
3. Emergency: only when the user, at that moment, tells you to install it
   yourself. Follow both protocols, use only the locations of the
   "Organização" table, and file a request marked
   `situação: feito sem o instalador` so the installer can review it.

## Request template

```markdown
# Pedido: <instalar | atualizar | remover> <nome>

- pedido por: <session name> (<project>), em <date>
- o que é e para que serve: ...
- projeto(s) que usam: ... (ou "todos")
- origem: <official site/repo>, versão <x>, licença <...>
- verificação: <published SHA-256 / signature / tag commit>
- alternativa sem instalar: ...
- onde pretende pôr: ... | o que muda no sistema: ...
- como remover: ...
- urgência: ...
- situação: aberto
```
