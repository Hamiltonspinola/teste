#!/usr/bin/env bash
# Descreve, em uma frase, o estado do repositório de trabalho.
#
# O código NÃO viaja pelo claude-brain — ele viaja por git, no repositório do
# próprio projeto. Este script existe para você não descobrir isso tarde demais:
# ao abrir, avisa se falta trazer o que a outra máquina enviou; ao fechar, se
# você está saindo com trabalho que não saiu daqui.
#
# Uso: cc-git-estado.sh <diretório> [abrindo|fechando]
# Sai em silêncio quando não há nada a dizer.

set -uo pipefail

DIR="${1:-}"
MOMENTO="${2:-abrindo}"
[ -n "$DIR" ] && [ -d "$DIR" ] || exit 0

r() { git -C "$DIR" "$@" 2>/dev/null; }

# Não é repositório git, ou é o próprio claude-brain: nada a dizer.
r rev-parse --is-inside-work-tree >/dev/null || exit 0
RAIZ="$(r rev-parse --show-toplevel)"
[ "$RAIZ" = "${BRAIN_DIR:-$HOME/claude-brain}" ] && exit 0

SUJO=0
[ -n "$(r status --porcelain)" ] && SUJO=1

ATRAS=0; FRENTE=0
if r rev-parse --abbrev-ref '@{u}' >/dev/null; then
  if [ "$MOMENTO" = "abrindo" ]; then
    # Consulta o servidor sem nunca pedir senha nem travar esperando você.
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" \
      timeout 10 git -C "$DIR" fetch -q >/dev/null 2>&1
  fi
  ATRAS="$(r rev-list --count 'HEAD..@{u}' || echo 0)"
  FRENTE="$(r rev-list --count '@{u}..HEAD' || echo 0)"
fi

RAMA="$(r rev-parse --abbrev-ref HEAD)"
PARTES=()
[ "${ATRAS:-0}"  -gt 0 ] 2>/dev/null && PARTES+=("$ATRAS commit(s) no servidor que não estão aqui — precisa de git pull")
[ "${FRENTE:-0}" -gt 0 ] 2>/dev/null && PARTES+=("$FRENTE commit(s) aqui que não foram enviados — precisa de git push")
[ "$SUJO" -eq 1 ] && PARTES+=("alterações não commitadas")

[ ${#PARTES[@]} -eq 0 ] && exit 0

printf 'Projeto %s (rama %s): ' "$(basename "$RAIZ")" "$RAMA"
printf '%s' "${PARTES[0]}"
for ((i = 1; i < ${#PARTES[@]}; i++)); do printf '; %s' "${PARTES[$i]}"; done
printf '.\n'
