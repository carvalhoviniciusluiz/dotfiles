# {{PROJECT}}

Instruções para agentes de código neste repositório (lidas pelo Codex e, via
`CLAUDE.md` → `AGENTS.md`, pelo Claude Code). Complementam as regras globais em
`~/.codex/AGENTS.md`; em caso de conflito, este arquivo vence.

## Visão geral

<!-- O que o projeto faz, para quem, e a stack principal. -->

## Comandos

Use as receitas do `justfile` (rode `just` para listar):

- `just dev` — ambiente de desenvolvimento
- `just test` — testes
- `just lint` — lint
- `just fmt` — formatação

## Estrutura

<!-- Pastas principais e o que vive em cada uma. -->

## Convenções

<!-- Padrões de código, nomes, testes, commits (ex.: Conventional Commits). -->

## Não faça

- Não commitar `.env`/`.envrc` (use `.envrc.example`).
- Não alterar arquivos gerados ou de lock manualmente.
