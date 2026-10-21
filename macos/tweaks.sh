#!/usr/bin/env bash
# Ajustes de desempenho do macOS (opcionais, reversíveis).
# Desliga serviços que carregavam no login sem necessidade.
# Para desfazer: launchctl enable gui/$(id -u)/<serviço>
set -uo pipefail

uid="$(id -u)"
services=(
  com.microsoft.teams2.agent   # agente do Teams (abrir o Teams só quando precisar)
  com.microsoft.update.agent   # Microsoft AutoUpdate (atualizar pelo menu Ajuda do Office)
  com.docker.helper            # DockerHelper (Docker só sobe quando aberto manualmente)
)

for s in "${services[@]}"; do
  launchctl disable "gui/$uid/$s" 2>/dev/null && echo "desativado: $s"
  launchctl bootout "gui/$uid/$s" 2>/dev/null || true
done

# Docker Desktop: não abrir no login
docker_settings="$HOME/Library/Group Containers/group.com.docker/settings-store.json"
if [[ -f "$docker_settings" ]]; then
  /usr/bin/python3 -I - "$docker_settings" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["AutoStart"] = False
json.dump(d, open(p, "w"), indent=2)
print("Docker Desktop: AutoStart desligado")
PY
fi
