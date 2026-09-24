#!/usr/bin/env bash
# Roda quando você FECHA o Claude Code (hook SessionEnd).
# Também pode ser rodado na mão a qualquer momento.

. "${BRAIN_DIR:-$HOME/claude-brain}/bin/cc-lib.sh"

# O Claude Code entrega os dados do evento pela entrada padrão. Rodando na mão,
# a entrada padrão é o teclado — ler dela deixaria o script parado esperando
# você digitar, parecendo travado.
if [ -t 0 ]; then ENTRADA=""; else ENTRADA="$(cat 2>/dev/null || true)"; fi
PASTA="$(printf '%s' "$ENTRADA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')"

# Você está saindo desta máquina. O que não estiver commitado e enviado não
# existe na outra, por mais completa que esteja a memória.
ESTADO="$("$BRAIN_DIR/bin/cc-git-estado.sh" "${PASTA:-$PWD}" fechando 2>/dev/null)"
[ -n "$ESTADO" ] && aviso "$ESTADO"

EU="$(maquina)"

# Libera o marcador desta máquina: ela não está mais com sessão aberta.
rm -f "$MARCADORES/$EU" 2>/dev/null

if [ "${AUTO_PUSH}" != "sim" ] && [ "${1:-}" != "--forcar" ]; then
  exit 0
fi

enviar "sync: $EU $(date '+%F %H:%M')"
exit 0
