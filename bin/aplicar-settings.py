#!/usr/bin/env python3
"""
Garante que o settings.json compartilhado tenha o que a sincronização precisa,
sem apagar nada que já seja seu.

Se qualquer uma das três chaves abaixo sumir — por exemplo ao aproveitar um
settings.json que você já tinha na máquina — a sincronização para de acontecer
sem dar erro nenhum. Por isso elas são reaplicadas em toda instalação.
"""
import json
import sys

GANCHOS = {
    "SessionStart": ('"$HOME/claude-brain/bin/cc-sync-pull.sh"', 60),
    "SessionEnd":   ('"$HOME/claude-brain/bin/cc-sync-push.sh"', 120),
}


def carregar(caminho):
    try:
        with open(caminho) as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        return {}
    return cfg if isinstance(cfg, dict) else {}


def registrar_gancho(hooks, evento, comando, timeout):
    grupos = hooks.get(evento)
    if not isinstance(grupos, list):
        grupos = []
    ja_registrado = any(
        comando in str(h.get("command", ""))
        for grupo in grupos if isinstance(grupo, dict)
        for h in (grupo.get("hooks") or []) if isinstance(h, dict)
    )
    if not ja_registrado:
        grupos.append({"hooks": [
            {"type": "command", "command": comando, "timeout": timeout}
        ]})
    hooks[evento] = grupos


def main():
    caminho, dias = sys.argv[1], int(sys.argv[2])
    cfg = carregar(caminho)

    cfg["cleanupPeriodDays"] = dias
    cfg["autoMemoryDirectory"] = "~/claude-brain/memory"

    hooks = cfg.get("hooks")
    if not isinstance(hooks, dict):
        hooks = {}
    for evento, (comando, timeout) in GANCHOS.items():
        registrar_gancho(hooks, evento, comando, timeout)
    cfg["hooks"] = hooks

    with open(caminho, "w") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
