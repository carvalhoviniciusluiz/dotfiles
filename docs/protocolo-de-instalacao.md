# Protocolo de instalação

Como pôr, atualizar e tirar programas desta máquina sem bagunçar o sistema.
Vale para todo agente (Claude Code, Codex) e todo TL de todo projeto. Por
decisão do usuário, há **um responsável** por qualquer instalação,
atualização ou remoção: o **agente instalador**, uma sessão chamada
`INSTALADOR_MACOS`. Ele não fica ativo o tempo todo, e este protocolo diz
como chamá-lo, o que fazer enquanto ele não responde e como outra sessão
assume o papel.

Documentos ligados: "Organização" e "Regras de instalação" no `AGENTS.md`
global (onde cada coisa fica) e `docs/protocolo-de-atualizacao.md` (como
atualizar).

## 1. Quando chamar o instalador

**Precisa do instalador** tudo o que fica fora da pasta de trabalho do
projeto ou muda a máquina:

- instalar, atualizar ou remover programa, app, CLI, biblioteca de sistema,
  linguagem (`asdf`), pacote global (`npm -g`, `uv tool`, `pip`, `cargo
install`, `go install`), fonte ou extensão;
- baixar um binário para usar depois, compilar algo para deixar instalado;
- registrar ou mudar MCP, skill, hook, LaunchAgent, serviço, crontab, item
  de login, permissão de privacidade;
- criar ou mudar atalho, alias, `PATH`, `.zshrc`, `~/.config`, links em
  `~/.local/bin`, o dotfiles, o `AGENTS.md` global;
- helpers e ferramentas de desenvolvimento de um projeto que vão morar fora
  do repositório (`~/.local/share/dev/<projeto>/`). O instalador diz onde e
  como, e o TL executa;
- contêineres, volumes e imagens Docker que ficam depois do trabalho.

**Não precisa** (o projeto controla):

- dependências do gerenciador de pacotes do projeto, dentro dele
  (`node_modules`, `.venv`, `.build/`, `target/`, lockfiles);
- builds e artefatos dentro do repositório ou da worktree;
- temporários no scratchpad da sessão ou em `${TMPDIR}`, apagados ao fim;
- rodar um programa que já está instalado.

Na dúvida, pergunte ao instalador.

## 2. Como chamar

1. **Procure a sessão:** `ListAgents`. Se `INSTALADOR_MACOS` aparecer, mande
   a ficha (seção 3) com `SendMessage` (`to: "INSTALADOR_MACOS"`) e **espere
   a resposta** antes de instalar. Pode seguir com outras tarefas enquanto
   isso.
2. **Se ele não aparecer**, ou não responder:
   - grave a ficha na fila: `~/.local/share/instalador/fila/AAAA-MM-DD-<projeto>-<item>.md`;
   - avise o usuário, com esta mensagem:

     > Preciso do agente instalador para: `<resumo>`. A ficha está em
     > `~/.local/share/instalador/fila/<arquivo>`. Para ativá-lo:
     > `agents-restore --list` e retome a sessão `INSTALADOR_MACOS`, ou abra
     > uma sessão nova (Claude Code, na pasta `~/Development/dotfiles`) com
     > o prompt de ativação da seção 6.

   - siga com o que não depende da instalação. **Nunca** reabra sessões por
     conta própria nem contorne o pedido instalando em outro lugar.
3. **Emergência:** só se o usuário mandar, naquele momento, que você mesmo
   instale. Nesse caso:
   - siga este protocolo e o de atualização;
   - instale só no lugar certo da tabela "Organização";
   - grave uma ficha na fila com `situação: feito sem o instalador`, para
     ele revisar e registrar.

## 3. Ficha do pedido

```markdown
# Pedido: <instalar | atualizar | remover> <nome>

- pedido por: <nome da sessão> (<projeto>), em <data>
- o que é e para que serve: ...
- projeto(s) que usam: ... (ou "todos")
- origem: <site/repositório oficial>, versão <x>, licença <...>
- verificação: <SHA-256 publicado / assinatura / commit da tag>
- alternativa sem instalar (dentro do projeto, ferramenta que já existe): ...
- onde pretende pôr: ... | o que muda no sistema (PATH, serviço, MCP...): ...
- como remover: ...
- urgência: <bloqueia o trabalho? até quando?>
- situação: aberto
```

## 4. O que o instalador faz

1. Lê a ficha e decide:
   - **global**: serve a todos os projetos. Instala com o sim do usuário e
     registra no dotfiles (`versions.env` com SHA-256, `install.sh`,
     Inventário do `AGENTS.md`);
   - **do projeto**: diz onde e como instalar ou compilar (pasta ignorada
     no repositório ou `~/.local/share/dev/<projeto>/`, `PATH` pelo
     `.envrc`, receitas de instalação e remoção documentadas no `AGENTS.md`
     do projeto). O TL executa, e o instalador confere depois;
   - **recusado**: quando já existe ferramenta equivalente, a origem não
     tem procedência, pesa demais para 8 GB ou vai contra o macOS 14. Diz o
     motivo e a alternativa.
2. Para instalar: procedência (SHA-256, assinatura), compatibilidade com o
   macOS 14, memória (`sysload`), uma coisa pesada por vez, versões antigas
   de linguagem e caches intocados.
3. Para atualizar: `docs/protocolo-de-atualizacao.md`.
4. Para remover (seção 5).
5. Responde ao pedinte (`SendMessage`), atualiza a ficha (`situação:
feito | instruído | recusado`, com a data), move-a para
   `fila/feitos/` e anota no registro (seção 7).

## 5. Remoção

1. Quem depende? Veja projetos (`.tool-versions`), outros programas
   (`uv tool`, globais do npm, MCPs, skills), nossos utilitários e
   configurações que citam o caminho.
2. Pare o programa e os serviços dele.
3. Tire tudo:
   - o app e os links em `~/.local/bin`;
   - a pasta em `~/.local/opt`;
   - em `~/Library`: Application Support, Caches, Preferences
     (`defaults delete <id>`), Saved Application State, Logs,
     LaunchAgents, HTTPStorages;
   - `~/.config`, `~/.local/share` e `~/.cache`;
   - MCP, skill, hooks;
   - permissões (`tccutil reset All <bundle-id>`);
   - registro no LaunchServices (`lsregister -u`);
   - itens do Keychain do app.
4. **Mova para a Lixeira**, não apague de vez: quem esvazia é o usuário.
   Linguagens e caches só saem com pedido explícito e conferência de
   dependentes.
5. Atualize o dotfiles, o Inventário e o registro. Confira com `mdfind
-name <nome>` que não sobrou nada fora da Lixeira.

## 6. Prompt de ativação (para o usuário)

Para retomar o instalador: `agents-restore --list` e retome a sessão
`INSTALADOR_MACOS`. Para criar um sucessor, abra o Claude Code em
`~/Development/dotfiles`, dê à sessão o nome `INSTALADOR_MACOS` e envie:

```text
Você é o agente instalador desta máquina (INSTALADOR_MACOS). Toda instalação,
atualização e remoção passa por você. Antes de qualquer coisa leia:
1. ~/.codex/AGENTS.md (seções "Regras de instalação" e "Organização");
2. ~/Development/dotfiles/docs/protocolo-de-instalacao.md e
   docs/protocolo-de-atualizacao.md;
3. ~/.local/share/instalador/HANDOFF.md (estado e pendências do instalador
   anterior) e ~/.local/share/instalador/registro.md;
4. os pedidos em ~/.local/share/instalador/fila/.
Depois me diga o estado, as pendências e a ordem em que vai tratar a fila.
```

## 7. Estado do instalador (só nesta máquina)

Em `~/.local/share/instalador/`, fora do dotfiles porque cita projetos
privados:

| Arquivo       | Conteúdo                                                                                      |
| ------------- | --------------------------------------------------------------------------------------------- |
| `HANDOFF.md`  | Estado atual, pendências, decisões tomadas e esperando o usuário, avisos para o sucessor      |
| `registro.md` | O que está instalado fora do padrão do dotfiles: o quê, onde, para qual projeto, como remover |
| `fila/`       | Pedidos abertos (um arquivo por pedido); `fila/feitos/` guarda os tratados                    |

O instalador atualiza o `HANDOFF.md` ao fim de cada bloco de trabalho e antes
de encerrar a sessão. Pode também deixar um handoff no ai-memory, se o
usuário usar.
