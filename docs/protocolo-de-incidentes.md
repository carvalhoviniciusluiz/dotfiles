# Protocolo de incidentes

Use este protocolo quando uma ação de um agente causar um dano que ninguém
pediu. Exemplos:

- um comando derrubou apps, sessões ou serviços;
- um arquivo, um dado ou uma configuração foi apagado ou mudado por engano;
- um segredo apareceu num lugar público;
- uma ferramenta instalada ou uma configuração quebrou outra coisa.

Uma parada por limite de uso ou um Mac travado **não** são incidentes deste
protocolo. Para eles, use o `protocolo-de-recuperacao.md`. Um incidente pode
pedir os dois protocolos: este primeiro, depois a recuperação.

Princípios:

- **Primeiro conter, depois entender.** Pare o que causou o dano antes de
  investigar.
- **Não religar nada sem o usuário.** O usuário decide quando os serviços,
  os apps e as sessões voltam.
- **Fatos com prova.** Cada afirmação do relatório traz a prova: um trecho
  exato do transcript, um horário, um commit ou a saída de um comando.
  Quando não houver prova, escreva "não sei".
- **Cada causa vira uma barreira.** Uma regra escrita é a barreira mínima.
  Quando possível, acrescente uma trava técnica (hook ou configuração): uma
  regra sozinha não segurou o caso de 2026-11-14.

## 1. Conter (nos primeiros minutos)

O agente que percebe o dano:

1. Para a tarefa ou o subagente que causou o dano. Use o `TaskStop` ou a
   mensagem ao subagente, nunca um comando que mate processos por nome.
2. Não repete o comando e não tenta "consertar" no escuro.
3. Para os serviços que ficaram pela metade, se a ordem do projeto mandar
   (por exemplo, os servidores de um estudo).
4. Avisa o usuário na hora (`agent-notify` e uma mensagem), com três
   linhas: o que aconteceu, o que foi atingido e o que já parou.

## 2. Avaliar o dano

1. **O que foi atingido:** apps, serviços, sessões de agentes, MCPs,
   arquivos e dados. Para cada item, registre a prova (`sysload`,
   `dk status`, `agents-restore --list`, `git status`).
2. **O que se perdeu:** siga o `protocolo-de-recuperacao.md` §3 em cada
   repositório e em cada base tocada. Quando um item não puder ser
   conferido (por exemplo, um banco desligado), escreva "não conferido" e o
   motivo.
3. **Sessões encerradas:** liste-as com `agents-restore --list`, que mostra
   o id e o nome. Não reabra nenhuma sessão: o usuário decide.

## 3. Registrar

Quem registra é o agente principal do projeto em que o incidente aconteceu
(coordenador ou TL). Se não houver projeto, registra o braço direito
(sessão `3a3a3d6b-f6dc-4825-b197-36cfbf0ac448`).

1. **Relatório** em `tasks/INC-<data>-<tema>/report.md` (ou no lugar de
   tarefas do projeto), com estas seções:
   1. resumo em 3 linhas;
   2. linha do tempo, minuto a minuto;
   3. quem: o agente, o tipo, o modelo, o brief e o modo de permissão;
   4. o comando ou a ação exata, copiada do transcript (com o caminho do
      `.jsonl`);
   5. por que a ação passou: permissão, hooks e regras existentes;
   6. o efeito, com as provas;
   7. o que se perdeu e o que não se perdeu;
   8. a causa técnica (o mecanismo exato do dano);
   9. a causa raiz em uma frase e os fatores que contribuíram;
   10. as ações: o que já foi feito e o que fica pendente, com o dono de
       cada uma.
2. **Uma linha no log** do projeto, com o caminho do relatório, e um commit.
3. **Uma lição** no sistema de aprendizado do projeto (por exemplo,
   `tools/learnings.py`), com a evidência.
4. **Uma regra** no brief modelo e no manual do projeto.
5. **No Claude Code:** o `SendFeedback` registra o caso para a Anthropic, se
   o defeito for do produto. O usuário aprova o envio.

## 4. Prevenir

Para cada causa e para cada fator do relatório:

1. Escreva a barreira: a regra, onde ela fica e quem a segue.
2. Avalie uma trava técnica: um hook `PreToolUse`, uma permissão `deny` ou
   uma configuração. A trava global fica no dotfiles
   (`claude/settings.patch.json` e `home/.local/bin/`). Ela só muda com o
   OK do usuário.
3. Teste a trava com um comando inofensivo e registre o teste.

**Travas que já existem:**

| Trava                                               | O que barra                                                                                                                                      | Desde      |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- |
| `agent-guard-kill` (hook `PreToolUse` Bash, global) | `pkill`, `killall` e `kill` sem um PID próprio (`0`, `-1`, grupo, `$(...)`, `\| xargs kill`)                                                     | 2026-11-14 |
| `agent-guard-rm` (hook `PreToolUse` Bash, global)   | `rm`, `rmdir`, `unlink` e `find -delete` fora do projeto atual (ou na raiz dele) e fora dos temporários do agente; alvo com variável ou `$(...)` | 2026-11-18 |

## 5. Revisar com o usuário

1. Mostre ao usuário o resumo, a causa raiz, as ações feitas e as
   pendentes.
2. O usuário decide o que volta a funcionar e quando: serviços, apps e
   sessões.
3. O usuário aprova as travas novas.
4. Feche o incidente com a linha "INCIDENTE FECHADO" no log, quando as
   ações tiverem dono e data.

## Incidentes registrados

| Data       | Tema                                                 | Onde                                                  | Causa raiz                                                                                                                                                                       |
| ---------- | ---------------------------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-14 | `pkill -f "cat"` derrubou apps, o Docker e 7 sessões | relatório do projeto (estudo, `INC-2026-11-14-pkill`) | um subagente em modo automático matou processos por nome; nenhuma regra nem trava proibia. No macOS, opções depois do padrão viram padrões, e `-f` casou "cat" em "Applications" |
