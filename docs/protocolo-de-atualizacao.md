# Protocolo de atualização

Como atualizar os programas desta máquina sem quebrar o que já funciona. Quem
conduz é o agente instalador (sessão `INSTALADOR_MACOS`; veja "Regras de
instalação" no `AGENTS.md` global). Outro agente que precise de uma versão nova
pede a ele. O usuário aprova o que muda o comportamento dos programas e o
commit.

Princípios:

- **Nada some antes de o novo funcionar.** A versão nova entra ao lado da
  antiga. A antiga só sai depois do teste e, se for linguagem, não sai.
- **O `install.sh` faz a instalação.** Atualizar pelo dotfiles testa a
  reprodução da máquina ao mesmo tempo.
- **Uma coisa pesada por vez**, com prioridade baixa: a máquina tem 8 GB e
  outros agentes trabalhando.
- **Quem depende do programa fica sabendo antes.**

## 1. Levantamento

```sh
updates-check            # só o que mudou (saída 1 = há atualização)
updates-check --all      # tudo, inclusive o que está em dia
updates-check --only asdf|bin|npm|outros
```

Ele compara o `tool-versions` e o `versions.env` com a última versão publicada
de cada programa. Não instala nada.

- Linguagens (Node, Python, Java, Rust, Lua) aparecem como `linguagem` quando
  há correção **na mesma linha** (ex.: 3.14.8 → 3.14.10). Uma linha nova
  (3.15) aparece só como observação: mudar de linha é decisão do usuário.
- O que o `updates-check` não cobre e precisa ser olhado à mão:
  - o Claude Code, que se atualiza sozinho;
  - os apps instalados pelo site (iTerm, VS Code, Docker);
  - o Hopper;
  - as extensões do VS Code e do Sublime;
  - as ferramentas de cada projeto. Essas o TL do projeto confere com o
    instalador.

## 2. Triagem (para cada item)

| Pergunta                  | Como conferir                                                                                                                                  |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| O que mudou? Algo quebra? | Notas da versão (`gh release view <tag> -R <repo>`), seções "Breaking", "Upgrade notes", "Removed"                                             |
| Tipo de salto             | Correção (x.y.**z**), menor (x.**y**) ou maior (**x**). Maior e linha nova de linguagem: só com o sim do usuário                               |
| Funciona no macOS 14?     | `otool -l <binário> \| grep -A2 minos`; rodar `--version` da cópia baixada no scratchpad (ex.: o `vts-extract` pronto exige Metal do macOS 15) |
| Procedência               | SHA-256 publicado na release; `codesign --verify --strict` e, em app, `spctl -a`; commit da tag para código compilado                          |
| Licença mudou?            | Arquivo LICENSE e notas da versão                                                                                                              |
| Requisitos                | Versão mínima de Node, Java, macOS (ex.: rea-agents 6.8.0 exige Node ≥ 26.12.1)                                                                |
| Quem depende dele?        | Veja a lista abaixo                                                                                                                            |
| Custo                     | Download, compilação, memória, reinício de serviço                                                                                             |

**Dependências a procurar:**

- Projetos: `.tool-versions`, `.nvmrc`, `.node-version`, `.python-version`,
  `rust-toolchain*` em `~/Development`. O registro do instalador (`~/.local/share/instalador/registro.md`) lista os casos conhecidos.
- Ferramentas presas a uma versão de linguagem:
  - os `uv tool` usam o Python do asdf em que foram instalados (veja
    `readlink ~/.local/share/uv/tools/*/bin/python`);
  - os globais do npm vivem na pasta de cada versão do Node (`npm root -g`).
- Configurações que guardam caminho com versão:
  - `JAVA_HOME` no `~/.zshrc` e no `env` do MCP do REA;
  - `GHIDRA_INSTALL_DIR`;
  - links em `~/.local/bin`.
- Consumidores certificados: o REA é verificado com um Ghidra específico
  (hoje 12.1.4 + JDK 21). Ghidra novo só depois de o REA certificar.
- Nossos utilitários (`ctx`, `check`, `bgrun`, `ports`, `dk`, `wt`,
  `sysload`, `agents-restore`, `ci-logs`, `agent-notify`, `new-project`,
  `lefthook-init`, `updates-check`, `codex`) usam `jq`, `rg`, `fd`, `gh`,
  `git` e `asdf`. Se algum desses mudar de versão, rode os testes da etapa 5.
- Skills ligadas a uma versão: `reverse-engineer-anything` (REA) e
  `video-to-skill` (vts-extract).
- Agentes ativos (`ListAgents`) e investigações em andamento que usam a
  ferramenta.

**Decisão, registrada no histórico:**

- **atualizar**;
- **adiar**, com o motivo e a condição para voltar ao assunto;
- **bloquear**: não atualizar, com o motivo.

Adie por padrão:

- linha nova de linguagem;
- versão maior;
- versão que um consumidor ainda não certificou;
- versão que quebra algo em uso por um agente no meio de uma investigação.
  Nesse caso, avise o agente e atualize quando ele liberar.

## 3. Preparação

1. `sysload`: com memória sob pressão (saída 1), não comece compilação.
2. Confira se algum agente está usando o programa ou segura o slot de um
   projeto. Se estiver, combine o horário.
3. Faça backup do que a reinstalação reescreve: `~/.claude.json`,
   `~/.codex/config.toml` e a pasta de dados do programa em
   `~/Library/Application Support`.
4. Anote as **configurações manuais** que o `install.sh` não recria. Remover
   e registrar um MCP de novo as apaga. Exemplos:
   - aprovações por ferramenta do REA no Codex;
   - `env` extras de um MCP;
   - ajustes feitos pelo app.

   Ou leve a configuração para o `install.sh`, ou anote para refazer.

## 4. Instalação segura

1. Atualize primeiro o dotfiles: versão e SHA-256 no `versions.env`, versão
   no `tool-versions`, URL no `install.sh` se o nome do arquivo mudou. Depois
   rode a etapa: `./install.sh --only <etapa>`. Se a etapa só instala quando
   o programa falta, ajuste-a para comparar a versão.
2. **Linguagens:** `asdf install <ling> <nova>` ao lado da antiga. Nunca rode
   `asdf uninstall` nem limpe caches (`~/.npm`, `~/.cache/uv`, `~/.cargo`,
   pip, `~/.asdf/installs/*`) sem o usuário. Troque a versão global só depois
   do teste:
   - em Node, reinstale os globais na versão nova (`./install.sh --only
npm`);
   - em Java, atualize o `JAVA_HOME` (`.zshrc`) e registre os MCPs de novo
     (`--only claude`, `--only codex`);
   - em Python, os `uv tool` continuam no Python antigo até serem
     reinstalados (`--only uv`).
3. **Binários:** cada versão tem a própria pasta em
   `~/.local/opt/<nome>-<versão>`, e o link em `~/.local/bin` muda de uma vez
   para a nova.
4. **Compilação do código-fonte:** `nice -n 19` e no máximo `-j 2`, em
   segundo plano, uma de cada vez. Nunca junto com Ghidra, outra compilação ou
   um build de projeto.
5. **Serviços** (ex.: ai-memory): instale, reinicie
   (`launchctl kickstart -k gui/$(id -u)/<rótulo>`) e espere as migrações do
   banco terminarem (log em `~/Library/Logs/<serviço>`). Confira que o
   servidor e o cliente mostram a mesma versão. Os agentes perdem a conexão
   por alguns segundos.
6. **Apps:** só troque com o app fechado. O antigo vai para a Lixeira. Os
   dados e as licenças ficam em `~/Library` e não são tocados.
7. **MCPs:** a versão fica no `versions.env`. Remover e registrar de novo
   apaga as aprovações por ferramenta do Codex (veja a etapa 3). Sessões
   abertas continuam com o servidor antigo até reiniciar.

## 5. Verificação

- `--version` de cada item atualizado e `updates-check --only <seção>`.
- Teste rápido de uso real, no scratchpad:

| Programa       | Teste                                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------- |
| vts-extract    | vídeo sintético (`ffmpeg -f lavfi testsrc` + `sine`) → `vts-extract extract` gera `timeline.json` |
| ipsw           | `ipsw dyld symaddr <cache> _NSLog --image Foundation`                                             |
| macmon / iSMC  | `macmon pipe -s 1`, `iSMC temp -o json`                                                           |
| craft-anything | `doctor` (healthy) e `--deep triage /bin/ls`                                                      |
| mdm            | `mdm --json get https://example.com/ -o <scratchpad>/`                                            |
| REA            | `rea doctor --json` (só os itens opcionais podem falhar)                                          |
| ai-memory      | `ai-memory status` (server = client), web em http://127.0.0.1:49374/web responde 401              |
| Python         | `python -c "import lzma, compression.zstd, ssl, sqlite3"`                                         |
| Node e globais | `node --version`, `npm root -g` na versão nova, `--version` de cada global                        |
| Java           | `java -version`; `rea doctor` acha o Ghidra com o `JAVA_HOME` novo                                |

- Diagnósticos: `craft-anything-cli doctor`, `rea doctor`, `vts-extract
check`, `agent-desktop status`.
- MCPs: `claude mcp list` (todos conectados) e `codex mcp list`, conferindo
  versões e `env`.
- Nossos utilitários: `for s in ctx check bgrun ports dk wt sysload
agents-restore ci-logs updates-check; do $s --help >/dev/null || echo
"FALHOU $s"; done`.
- Um terminal novo abre sem erro (`zsh -ic exit`).

## 6. Limpeza

- Versões antigas de **ferramentas** (`~/.local/opt/<nome>-<antiga>`, apps,
  binários compilados) vão para a Lixeira, numa pasta com data. Quem esvazia
  é o usuário.
- Versões antigas de **linguagens** e **caches** ficam. Remover exige pedido
  do usuário e a conferência de dependentes da etapa 2.
- Temporários do scratchpad: apague.

## 7. Comunicação

- Mudança incompatível: avise cada agente que usa a ferramenta (SendMessage)
  com o que muda e como se adaptar. Exemplo: "`analyze_function` agora
  devolve resumo; peça `detail: \"complete\"`".
- Reinício de serviço: avise que as conexões caem por alguns segundos.
- Ao usuário: o que foi atualizado, o que foi adiado e por quê, e o que ele
  precisa fazer, como reiniciar sessões ou refazer aprovações.

## 8. Volta atrás (rollback)

- Linguagem: a versão antiga continua instalada. Volte o `tool-versions`
  (`cp tool-versions ~/.tool-versions`) e, se preciso, o `JAVA_HOME` e os
  MCPs.
- Ferramenta: a pasta antiga está na Lixeira. Devolva-a para
  `~/.local/opt` e refaça o link, ou volte o `versions.env` (`git checkout
-- versions.env`) e rode a etapa do `install.sh`.
- npm: `./install.sh --only npm` com o `versions.env` anterior.
- Serviço com migração de banco: não há volta simples. Por isso o backup
  da pasta de dados na etapa 3.

## 9. Documentação e auditoria

1. `versions.env`, `tool-versions`, `install.sh`, o Inventário e as
   seções do `AGENTS.md` que citam versão, e o `README.md`.
2. Auditoria de coerência:
   - links de `home/`;
   - skills;
   - variáveis do `versions.env` sem uso;
   - versões fixadas × instaladas;
   - MCPs documentados × registrados;
   - nenhuma menção a projetos privados;
   - `bash -n`, `shellcheck`, `prettier --check` e `gitleaks git --staged`.
3. Uma linha no histórico abaixo.
4. Commit e push só com o pedido do usuário.

## Histórico

| Data       | Atualizado                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Adiado (motivo)                                                                                                                                                                                                               |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-10 | gh 2.103.3, fd 10.5.2, uv 0.13.7, lazygit 0.66.3, fzf 0.75.0, xh 0.26.3, dust 1.2.7, bottom 0.15.0; Node 26.13.0 (26.12.0 mantido); Java Temurin 21.0.13 (21.0.12 mantido); Python 3.14.10 (3.14.8 mantido para os `uv tool`); atuin 18.24.6, ipsw 3.1.745, macmon 0.11.0, Craft Anything 0.6.0; ai-memory 3.4.5 (migrações de banco); vts-extract 0.3.0 (compilado para macOS 14); Spec Kit v1.3.3; Sublime Merge 2136; pnpm 12.18.0, Codex 0.167.0, ast-grep 0.51.1, ccusage 20.0.49, agent-desktop 1.2.0, rea-agents 6.8.0, @playwright/mcp 0.0.85 | Ghidra 12.2 (REA certificado com 12.1.4; natives exigem compilação pesada); Python 3.15 e Java 25/27 (linha nova, decisão do usuário). Efeito colateral: registrar o REA de novo no Codex apagou as aprovações por ferramenta |
