#!/usr/bin/env bash
# Roda quando você ABRE o Claude Code (hook SessionStart).
# Traz a memória e as conversas que a outra máquina deixou.

. "${BRAIN_DIR:-$HOME/claude-brain}/bin/cc-lib.sh"

# O Claude Code entrega os dados do evento por stdin. Guardamos para saber em
# que pasta a sessão abriu.
ENTRADA="$(cat 2>/dev/null || true)"
PASTA="$(printf '%s' "$ENTRADA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')"

baixar

if [ "$AVISAR_SESSAO_DUPLA" = "sim" ]; then
  mkdir -p "$MARCADORES"
  EU="$(maquina)"
  AGORA="$(date +%s)"

  # Antes de me marcar: alguma OUTRA máquina se marcou ativa nas últimas 8h?
  LIMITE=$(( AGORA - 28800 ))
  for m in "$MARCADORES"/*; do
    [ -e "$m" ] || continue
    nome="$(basename "$m")"
    [ "$nome" = "$EU" ] && continue
    linha="$(cat "$m" 2>/dev/null || echo '0 ?')"
    quando="${linha%% *}"; outra="${linha#* }"
    case "$quando" in ''|*[!0-9]*) continue ;; esac
    if [ "$quando" -gt "$LIMITE" ]; then
      aviso "a máquina '$outra' está com o Claude aberto."
      aviso "Não continue a MESMA conversa nas duas ao mesmo tempo — uma sobrescreve a outra."
    fi
  done

  # Agora me marco e AVISO a outra máquina (senão ela nunca fica sabendo).
  echo "$AGORA $(apelido)" > "$MARCADORES/$EU"
  enviar "sessão aberta em $(apelido)" >/dev/null 2>&1 || true
fi

# Estado do repositório de trabalho, entregue ao Claude como contexto: é ele
# quem vai te avisar que falta um git pull antes de mexer no código.
ESTADO="$("$BRAIN_DIR/bin/cc-git-estado.sh" "${PASTA:-$PWD}" abrindo 2>/dev/null)"
if [ -n "$ESTADO" ] && command -v python3 >/dev/null 2>&1; then
  ESTADO="$ESTADO" python3 - <<'PY'
import json, os

texto = (
    "AVISO DE SINCRONIZAÇÃO: " + os.environ["ESTADO"].strip() + " "
    "O código deste projeto não viaja pela memória compartilhada — só por git. "
    "Avise o usuário disso antes de alterar qualquer arquivo aqui."
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": texto,
}}))
PY
fi

exit 0
