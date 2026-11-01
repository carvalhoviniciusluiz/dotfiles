# Confiança por projeto no Codex

O Codex pode marcar projetos específicos como confiáveis no `~/.codex/config.toml`.
É uma configuração **local de cada máquina**: o `install.sh` não distribui uma
lista de projetos confiáveis. Em outra máquina, revise os caminhos e confie
explicitamente só nos projetos conhecidos.

```toml
[projects."/Users/<usuario>/Development/<projeto>"]
trust_level = "trusted"
```

Os padrões globais de aprovação e sandbox continuam os mesmos; não adicione
permissões amplas nem copie regras de outras máquinas. Sessões já abertas podem
manter a política anterior: confira a sessão antes de considerar resolvido. Para
retomar uma sessão com uma política explícita:

```bash
codex resume --sandbox workspace-write --ask-for-approval on-request <id-da-sessao>
```

Encerre a instância anterior antes de retomar, para não duplicar agentes, e não
reabra sessões automaticamente (veja `agents-restore`).

Referência: https://learn.chatgpt.com/docs/agent-approvals-security

## Envio de mensagens entre agentes

O plugin `codex-app-tools` declara `send_message_to_thread` como ferramenta que
pede aprovação. Para um fluxo de coordenação entre agentes autorizado pelo
usuário, é possível liberar **somente essa ferramenta** no config do usuário,
sem editar o cache do plugin nem liberar criação, fork ou handoff de sessões:

```toml
[plugins."codex-app-tools@openai-bundled".mcp_servers.codex_app.tools.send_message_to_thread]
approval_mode = "approve"
```

O manifesto chama o servidor `codex_app`; numa sessão de terminal a ferramenta
pode aparecer como `codex_tui`. Teste numa sessão real antes de depender disso.
Não crie servidores fictícios nem altere o banco SQLite do Codex.

Referência: https://learn.chatgpt.com/docs/extend/mcp
