#!/usr/bin/env bash
# Roda quando você ABRE o Claude Code (hook SessionStart).
# Traz a memória e as conversas que a outra máquina deixou.

. "${BRAIN_DIR:-$HOME/claude-brain}/bin/cc-lib.sh"

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

exit 0
