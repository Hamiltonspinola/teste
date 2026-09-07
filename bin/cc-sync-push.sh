#!/usr/bin/env bash
# Roda quando você FECHA o Claude Code (hook SessionEnd).
# Também pode ser rodado na mão a qualquer momento.

. "${BRAIN_DIR:-$HOME/claude-brain}/bin/cc-lib.sh"

EU="$(maquina)"

# Libera o marcador desta máquina: ela não está mais com sessão aberta.
rm -f "$MARCADORES/$EU" 2>/dev/null

if [ "${AUTO_PUSH}" != "sim" ] && [ "${1:-}" != "--forcar" ]; then
  exit 0
fi

enviar "sync: $EU $(date '+%F %H:%M')"
exit 0
