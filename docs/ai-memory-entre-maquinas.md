# ai-memory entre o M1 e o M2

Por padrão, cada Mac tem o próprio servidor do ai-memory (instalado pelo
`install.sh`, ouvindo só em `127.0.0.1:49374`). As memórias de um não aparecem
no outro. Para compartilhar, um único servidor precisa atender os dois.

Referência: `docs/install.md` do ai-memory, seção "Server on a different machine".

## Opções

| Opção                             | Como                                                         | Prós                                   | Contras                                                                                                                           |
| --------------------------------- | ------------------------------------------------------------ | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **A. Cada Mac com o seu** (atual) | nada a fazer                                                 | simples, offline, nada exposto na rede | memórias separadas                                                                                                                |
| **B. Um Mac é o servidor**        | o M1 (ou o M2) escuta na rede local; o outro aponta para ele | sem custo, memória única               | só funciona com o servidor ligado, acordado e na mesma rede; precisa de token + `ALLOWED_HOSTS`; tráfego sem HTTPS dentro de casa |
| **C. Servidor sempre ligado**     | homelab/VPS com Docker + HTTPS (Caddy ou Cloudflare Tunnel)  | funciona de qualquer lugar             | precisa de uma máquina extra; mais configuração                                                                                   |

Recomendação: **A** até sentir falta; depois **C** se houver uma máquina sempre
ligada. A **B** serve para testar, mas notebooks dormem.

## Opção B (resumo)

No Mac servidor, o serviço precisa escutar na rede (não só em 127.0.0.1) e
restringir os hosts aceitos; o token já existe em
`~/Library/Application Support/ai-memory/auth-tokens/default`.

No outro Mac, sem instalar serviço próprio:

```bash
export AI_MEMORY_SERVER_URL="http://<ip-do-servidor>:49374"
export AI_MEMORY_AUTH_TOKEN="<token do servidor>"   # nunca coloque no dotfiles
ai-memory setup --yes --no-service --agent claude-code --agent codex
```

Guarde o token num gerenciador de senhas ou no Keychain, **não** no
`.zshrc` nem neste repositório.

## Opção C (resumo)

Use o `docker run` / compose com TLS descritos no README do ai-memory
(`AI_MEMORY_AUTH_TOKEN`, `AI_MEMORY_ALLOWED_HOSTS`, proxy HTTPS) e aponte os
dois Macs como na opção B, com `https://`.
