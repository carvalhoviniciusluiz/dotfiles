# Protocolo de recuperação depois de uma parada abrupta

Para quando o trabalho dos agentes para sem aviso:

- o limite de uso acaba (5 horas ou semanal; erro `rate_limit`, HTTP 429);
- a API cai (`overloaded`, `server_error`);
- o Mac trava ou desliga;
- o iTerm fecha.

Vale para todo agente desta máquina. Cada projeto acrescenta a sua seção
(onde fica o ponto de retomada de cada papel), no AGENTS.md ou no manual do
coordenador do projeto.

Princípios:

- **Nada se dá por recuperado sem prova.** "Sem perda" só entra no log
  depois da conferência da seção 3, com o que foi conferido.
- **Conferir antes de agir.** A retomada começa lendo o estado, nunca
  refazendo às cegas. Refazer um passo que já tinha terminado duplica
  trabalho e dados.
- **Todo passo pode rodar de novo sem estrago.** Antes de criar, confira se
  já existe. Antes de editar, compare com a cópia de antes.
- **O ponto de retomada mora em arquivo, não na conversa.** Um subagente que
  morre não grava nada. O que não estiver em arquivo só existe no
  transcript dele.

## 1. O que o Claude Code faz sozinho (e o que não faz)

- **Sessão interativa** (aba do iTerm): quando o limite acaba, ela espera
  aberta e continua sozinha no reset ("continuing automatically at …";
  ajuste `autoContinueAtUsageLimit`).
  - Ela desiste depois de 3 continuações seguidas.
  - Se o Mac dormir mais de cerca de 30 minutos, ela pede Enter.
  - A espera se perde se a sessão for fechada, ou com `/resume`, `/clear`
    ou rewind.
- **Subagentes de fundo NÃO continuam.** Eles terminam como _failed_
  ("Agent terminated early due to an API error"). O agente que os
  despachou recebe o erro e decide: retomar com `SendMessage` para o id do
  subagente (o mesmo contexto) ou despachar de novo.
  - Os transcripts ficam 30 dias em
    `~/.claude/projects/<projeto>/<sessão>/subagents/`.
- **`claude -p`, sessões em segundo plano e Remote Control não esperam.**
  Elas param no erro.
- **Checkpoints e `/rewind` não desfazem** edições de subagentes nem o que
  foi feito por shell (banco, Docker, arquivos gerados). Para isso servem o
  Git, os snapshots e as cópias de antes.
- **Não use** scripts de "auto-resume" que relançam o `claude` sem ninguém
  olhando, nem `--dangerously-skip-permissions`. O recurso nativo já cobre
  a retomada, com as permissões valendo.

## 2. Saúde da cota: pausar em 90% e retomar depois do reset

Regra do usuário (2026-11-14):

- O agente e os subagentes trabalham normalmente até **90%** da cota.
- Em **90% ou mais**, o agente principal prepara a pausa: os subagentes
  param com segurança, e nada do que já está pronto se perde.
- Depois do reset, **todos voltam ao trabalho**, menos os que o usuário
  mandou manter pausados.

### 2.1 Onde ler a cota

A cota é da conta inteira, não de uma sessão. Há duas medidas, e vale a
**maior** delas:

- **janela de 5 horas:** `rate_limits.five_hour.used_percentage`, mais a
  hora em que zera (`resets_at`); é o "Sessão atual" da página de uso;
- **semana:** `rate_limits.seven_day.used_percentage`; é o "Esta semana".

O Claude Code só entrega esses números à barra de status. A barra grava os
números para os agentes com `agent-usage record`. Depois disso:

- `agent-usage status` mostra o uso; a saída é 0 (ok), 1 (≥ 70%),
  2 (≥ 90%: pausar) ou 3 (sem dado);
- o comando `/usage` mostra a mesma coisa ao usuário.

Uma janela que já virou conta como zero, mesmo antes de chegar dado novo.

### 2.2 Frequência da verificação

Quanto mais perto do teto, mais frequente. O hook `agent-usage hook` faz
isso sozinho a cada ferramenta usada (agente e subagentes). Ele só fala
quando chega a hora:

| Uso (maior das duas) | Aviso ao agente   | O que fazer                                          |
| -------------------- | ----------------- | ---------------------------------------------------- |
| < 50%                | nenhum            | trabalhar normalmente                                |
| 50–69%               | a cada 30 min     | trabalhar normalmente                                |
| 70–79%               | a cada 10 min     | passos curtos; estado de retomada a cada passo       |
| 80–89%               | a cada 3 min      | terminar o que começou; não abrir tarefa grande nova |
| ≥ 90%                | a cada ferramenta | **pausa segura agora** (2.3)                         |

Sem o hook (projeto sem a barra, Codex):

- o agente principal roda `agent-usage status` no mesmo ritmo, entre um
  passo e outro;
- a cada despacho de subagente;
- antes de qualquer tarefa longa.

### 2.3 A pausa segura (em 90% ou mais)

**Subagente**, ao receber o aviso de 90% (pelo hook ou pela mensagem do
agente principal):

1. termina **só o passo atual**;
2. grava o estado de retomada (seção 4);
3. responde `PAUSADO: <ponto exato>` e para.

**Agente principal** (coordenador, TL):

1. Não despacha nada novo.
2. Manda a pausa a cada subagente vivo (`SendMessage`) e espera cada
   `PAUSADO`. Os 10% que restam são para salvar, não para trabalhar.
3. Grava o **registro da pausa** no lugar de handoff do projeto. Cada
   subagente entra com uma linha: nome ou id, tarefa, ponto exato, o
   arquivo de estado e se é "manter pausado".
4. Faz um commit, se o projeto commita a cada aceite, e escreve a linha de
   pausa no log.
5. **Agenda a retomada.** Cria um lembrete de uma vez (`CronCreate`) para
   2 a 3 minutos depois de `resets_at`. A mensagem do lembrete é
   "RETOMADA PÓS-RESET: siga o protocolo-de-recuperacao.md §2.4". Se
   `CronCreate` não existir, quem retoma é a continuação automática do
   Claude Code ou o usuário.
6. Avisa o usuário:
   - `agent-notify` (o hook já manda uma vez por janela);
   - a resposta "PAUSADO COM SEGURANÇA — retomo às HH:MM", com a lista do
     registro.
7. Termina o turno e espera.

### 2.4 A retomada (depois do reset)

1. Confira que a janela virou: `agent-usage status` abaixo de 90%, ou a
   hora de `resets_at` já passou.
2. Leia o registro da pausa e faça a conferência curta da seção 3 (passos
   2 a 4) para as tarefas pausadas.
3. Retome **um subagente por vez**, pelo `SendMessage` ao mesmo id,
   apontando o ponto exato e o arquivo de estado. Uma rajada gasta a cota
   nova e pode dar novo 429.
4. **Exceções:** quem o usuário mandou manter pausado continua parado até
   ele liberar.
   - O usuário pode dizer isso a qualquer momento, antes ou durante a
     pausa.
   - O agente registra no registro da pausa e confirma.
5. Avise o usuário: "RETOMADO", com quem voltou e quem ficou pausado.

**Cota semanal em 90%:** a regra é a mesma, mas o reset pode estar a dias.
Avise o usuário com a data. Ele pode comprar créditos (`/usage-credits`) ou
esperar.

### 2.5 Mac acordado

O lembrete e a continuação automática só funcionam com o Claude Code
aberto e o Mac acordado. Se o Mac dormir mais de cerca de 30 minutos, a
continuação pede Enter. Para trabalho que espera o reset, o usuário pode
rodar `caffeinate -i` no terminal; quem decide é ele.

## 3. Recuperação: depois da parada

Quem faz é o **coordenador** (ou o agente principal) da sessão que parou,
no primeiro momento seguro. Não pare subagentes vivos para isso.

1. **Inventário.** Liste as tarefas que estavam em voo na hora da parada:
   - as mensagens "failed" na tela;
   - `/tasks`;
   - o fim do log;
   - o handoff.

   Para cada tarefa, anote o que existia antes do erro e o que foi feito
   depois da retomada.

2. **Arquivos.** Para cada tarefa:
   - nada cortado no meio: última linha completa, tabela fechada, arquivo
     legível;
   - nada faltando ou duplicado: contagem contra o brief;
   - nenhuma edição aplicada duas vezes: diff contra a cópia de antes ou o
     último snapshot.
3. **Efeitos fora dos arquivos.** Banco, contêineres, servidores (`bgrun
list`, `dk status`, `ports`) e dados de teste criados por quem morreu.
   Compare com a lista de sobras esperadas. O que não tem dono vai para a
   lista de limpeza, e nada se apaga sem cópia.
4. **Git.**
   - `git status` e `git log` em cada repositório e worktree tocados.
   - Cada arquivo não commitado tem que pertencer a uma tarefa viva ou
     retomável.
   - Locks esquecidos (`.git/index.lock`, travas próprias do projeto): só
     remova se forem seus e não houver processo vivo.
5. **Contagens.** Os números do log (linhas, regras, testes) batem com os
   arquivos.
6. **Veredito por tarefa**, numa linha cada:
   - **íntegra:** nada a fazer;
   - **retomável:** ponto de partida exato (arquivo e passo);
   - **perdida:** refazer a partir de onde;
   - **suja:** o que limpar antes.

   Grave num relatório da recuperação, no lugar de tarefas do projeto, e
   numa linha do log.

7. **Retomar** na ordem do veredito, um subagente por vez:
   - `SendMessage` ao subagente quando o contexto dele ainda serve;
   - novo despacho com o ponto de partida quando não serve.
8. **Avisar o usuário:** "RECUPERAÇÃO CONFERIDA", com o veredito de cada
   tarefa e o que ficou para ele decidir.

### O Mac travou (as abas sumiram)

Rode `agents-restore --list` e mostre a lista ao usuário. Só reabra quando
ele pedir. Cada sessão reaberta segue esta seção 3 antes de continuar.

## 4. Como deixar cada tarefa retomável (para quem escreve briefs)

Todo brief de subagente pede um **estado de retomada** curto, atualizado
**a cada passo**, num arquivo da pasta da tarefa (ex.: `state.md`), com:

- o que já terminou;
- o passo atual;
- os arquivos tocados;
- os efeitos fora dos arquivos (dados criados e ids);
- o próximo passo;
- como conferir.

Além disso:

- **Snapshot ou commit antes de editar em massa.** Cópia de antes dos
  arquivos tocados, para o diff da retomada.
- **Passos pequenos** com resultado gravado ao fim de cada um (uma tabela
  por sublote, um debrief por parte).
- **Dados de teste com marca e lista**, para saber o que limpar se a tarefa
  morrer no meio.

## 5. Registro

- Cada parada e recuperação entra no log do projeto com:
  - o horário;
  - o erro (tipo e ids das requisições, se houver);
  - as tarefas afetadas;
  - o veredito.
- Mudança neste protocolo passa pelo usuário. Ideias que surgirem numa
  recuperação vão para o lugar de "guardado para depois" do projeto.

## Fontes

- Claude Code:
  - [espera pelo reset do limite](https://code.claude.com/docs/en/interactive-mode#wait-for-a-usage-limit-to-reset);
  - [subagentes](https://code.claude.com/docs/en/sub-agents);
  - [hooks](https://code.claude.com/docs/en/hooks) (`StopFailure`,
    `Notification` `quota_auto_resume_*`);
  - [barra de status](https://code.claude.com/docs/en/statusline);
  - [checkpoints](https://code.claude.com/docs/en/checkpointing);
  - [erros](https://code.claude.com/docs/en/errors).
- [Limites da API da Anthropic](https://platform.claude.com/docs/en/api/rate-limits):
  `retry-after` e limite de rampa.
- Práticas de mercado:
  - execução durável ([Temporal](https://docs.temporal.io/workflows),
    [Restate](https://docs.restate.dev/concepts/durable_execution));
  - checkpoint por passo
    ([LangGraph](https://langchain-ai.github.io/langgraph/concepts/persistence/));
  - [chaves de idempotência](https://docs.stripe.com/api/idempotent_requests);
  - desligamento avisado
    ([Kubernetes](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination),
    [Slurm `--signal`](https://slurm.schedmd.com/sbatch.html)).
