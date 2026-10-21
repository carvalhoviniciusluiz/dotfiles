"""Mescla settings.patch.json em ~/.claude/settings.json sem apagar o que existe.

- chaves simples: o patch define o valor;
- permissions.*: listas são unidas sem duplicar;
- hooks.<evento>: entradas do patch são adicionadas se o comando ainda não existir
  (os hooks do ai-memory, criados pelo `ai-memory setup`, são preservados).
"""
import json
import pathlib
import shutil
import sys
import time

home = str(pathlib.Path.home())
patch = json.loads(pathlib.Path(sys.argv[1]).read_text().replace("{{HOME}}", home))
target = pathlib.Path(home) / ".claude" / "settings.json"
target.parent.mkdir(parents=True, exist_ok=True)
current = json.loads(target.read_text()) if target.exists() else {}
if target.exists():
    shutil.copy(target, f"{target}.bak-{time.strftime('%Y%m%d-%H%M%S')}")

for key, value in patch.items():
    if key == "permissions":
        perms = current.setdefault("permissions", {})
        for kind, rules in value.items():
            merged = perms.setdefault(kind, [])
            merged.extend(r for r in rules if r not in merged)
    elif key == "hooks":
        hooks = current.setdefault("hooks", {})
        for event, entries in value.items():
            existing = hooks.setdefault(event, [])
            commands = {h.get("command") for e in existing for h in e.get("hooks", [])}
            for entry in entries:
                if not any(h.get("command") in commands for h in entry.get("hooks", [])):
                    existing.append(entry)
    else:
        current[key] = value

target.write_text(json.dumps(current, indent=2, ensure_ascii=False) + "\n")
print(f"atualizado: {target}")
