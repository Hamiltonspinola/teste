#!/usr/bin/env bash
# Escolhe quais conversas sincronizam entre as máquinas.
#
#   cc-conversas.sh                 lista os grupos, com tamanho e situação
#   cc-conversas.sh ignorar <nome>  para de sincronizar aquele grupo
#   cc-conversas.sh incluir <nome>  volta a sincronizar
#
# As conversas são agrupadas pela pasta em que a sessão foi aberta. O nome do
# grupo é o caminho dessa pasta com os separadores trocados por hífen — ilegível,
# por isso a listagem mostra o caminho de verdade, lido de dentro das conversas.
#
# Ignorar um grupo não apaga nada: os arquivos continuam nesta máquina, apenas
# param de viajar para a outra.

set -uo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/claude-brain}"
[ -f "$BRAIN_DIR/config.sh" ] && . "$BRAIN_DIR/config.sh"

HISTORICO="$BRAIN_DIR/historico"
IGNORADOS="$HISTORICO/.gitignore"

[ -d "$HISTORICO" ] || { echo "não encontrei $HISTORICO" >&2; exit 1; }

# Caminho real da pasta em que o grupo foi aberto, lido do primeiro registro de
# uma conversa. Mais confiável do que tentar decodificar o nome do grupo: o
# Claude Code troca tanto "/" quanto "-" pelo mesmo caractere, então o nome
# sozinho é ambíguo.
caminho_de() {
  local grupo="$1" f
  f="$(find "$HISTORICO/$grupo" -maxdepth 1 -name '*.jsonl' -print -quit 2>/dev/null)"
  [ -n "$f" ] || { printf '(sem conversas)'; return; }
  head -1 "$f" 2>/dev/null \
    | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//'
}

esta_ignorado() {
  [ -f "$IGNORADOS" ] && grep -qxF "/$1/" "$IGNORADOS"
}

listar() {
  printf '%-10s  %7s  %5s  %s\n' SITUAÇÃO TAMANHO CONV. PASTA
  printf '%-10s  %7s  %5s  %s\n' ---------- ------- ----- -----
  local d grupo tam n
  for d in "$HISTORICO"/*/; do
    [ -d "$d" ] || continue
    grupo="$(basename "$d")"
    tam="$(du -sh "$d" 2>/dev/null | cut -f1)"
    n="$(find "$d" -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l)"
    if esta_ignorado "$grupo"; then
      printf '%-10s  %7s  %5s  %s\n' ignorado "$tam" "$n" "$(caminho_de "$grupo")"
    else
      printf '%-10s  %7s  %5s  %s\n' sincroniza "$tam" "$n" "$(caminho_de "$grupo")"
    fi
    printf '%-10s  %7s  %5s  %s\n' '' '' '' "  $grupo"
  done
  echo
  echo "Para parar de sincronizar um grupo:  $0 ignorar <nome-do-grupo>"
  echo "Para voltar a sincronizar:           $0 incluir <nome-do-grupo>"
}

ignorar() {
  local grupo="$1"
  [ -d "$HISTORICO/$grupo" ] || { echo "não existe o grupo '$grupo'" >&2; exit 1; }
  esta_ignorado "$grupo" && { echo "'$grupo' já está ignorado."; exit 0; }

  if [ ! -f "$IGNORADOS" ]; then
    printf '%s\n' \
      '# Conversas que você escolheu não sincronizar.' \
      '# Os arquivos continuam nesta máquina; apenas param de viajar.' \
      '# Use bin/cc-conversas.sh para editar.' \
      '' > "$IGNORADOS"
  fi
  printf '/%s/\n' "$grupo" >> "$IGNORADOS"

  # Sem isto, arquivos já rastreados continuariam sendo enviados: o .gitignore
  # só vale para o que o git ainda não conhece.
  git -C "$BRAIN_DIR" rm -r --cached --quiet -- "historico/$grupo" >/dev/null 2>&1

  echo "'$grupo' não será mais sincronizado."
  echo "Os arquivos continuam em $HISTORICO/$grupo, intactos."
  echo
  echo "Os envios anteriores continuam no histórico do repositório. Para apagá-los"
  echo "de verdade, veja \"Tirar conversas já enviadas\" no README."
}

incluir() {
  local grupo="$1"
  esta_ignorado "$grupo" || { echo "'$grupo' já sincroniza."; exit 0; }
  grep -vxF "/$grupo/" "$IGNORADOS" > "$IGNORADOS.tmp" && mv "$IGNORADOS.tmp" "$IGNORADOS"
  echo "'$grupo' volta a sincronizar no próximo envio."
}

case "${1:-listar}" in
  listar|"")        listar ;;
  ignorar)          [ -n "${2:-}" ] || { echo "uso: $0 ignorar <nome-do-grupo>" >&2; exit 1; }; ignorar "$2" ;;
  incluir)          [ -n "${2:-}" ] || { echo "uso: $0 incluir <nome-do-grupo>" >&2; exit 1; }; incluir "$2" ;;
  *)                echo "uso: $0 [listar|ignorar <grupo>|incluir <grupo>]" >&2; exit 1 ;;
esac
