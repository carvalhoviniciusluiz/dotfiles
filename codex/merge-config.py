"""Garante as notificações do Codex em ~/.codex/config.toml ([tui]).

O Codex avisa pelo terminal (OSC 9, suportado pelo iTerm) quando termina uma
tarefa ou pede aprovação, só se a aba não estiver em foco. Não mexe no resto
do arquivo (MCPs, hooks do ai-memory, plugins do app do Codex).
"""
import pathlib
import re
import shutil
import time

path = pathlib.Path.home() / ".codex" / "config.toml"
path.parent.mkdir(parents=True, exist_ok=True)
text = path.read_text() if path.exists() else ""
if path.exists():
    shutil.copy(path, f"{path}.bak-{time.strftime('%Y%m%d-%H%M%S')}")

wanted = {
    "notifications": '["agent-turn-complete", "approval-requested"]',
    "notification_method": '"osc9"',
    "notification_condition": '"unfocused"',
}

match = re.search(r"^\[tui\]\n(.*?)(?=^\[|\Z)", text, flags=re.S | re.M)
if match:
    body = match.group(1)
    for key, value in wanted.items():
        line = f"{key} = {value}"
        if re.search(rf"^{key}\s*=", body, flags=re.M):
            body = re.sub(rf"^{key}\s*=.*$", line, body, flags=re.M)
        else:
            body = line + "\n" + body
    text = text[: match.start(1)] + body + text[match.end(1):]
else:
    block = "\n[tui]\n" + "".join(f"{k} = {v}\n" for k, v in wanted.items())
    text = text.rstrip("\n") + "\n" + block

path.write_text(text)
print(f"atualizado: {path}")
