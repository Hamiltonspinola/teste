#!/usr/bin/env bash
# =============================================================================
# Instala a memória compartilhada do Claude Code nesta máquina.
# Rode uma vez no notebook e uma vez no computador.
#
#   git clone <url-do-repositorio-privado> ~/claude-brain
#   ~/claude-brain/bootstrap.sh
#
# Não apaga nada: o que já existe é movido para ~/.claude/backup-claude-brain/
# =============================================================================
set -euo pipefail

BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BRAIN_DIR/config.sh"

CLAUDE_HOME="$HOME/.claude"
BACKUP="$CLAUDE_HOME/backup-claude-brain-$(date +%Y%m%d-%H%M%S)"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  \033[34m·\033[0m %s\n' "$*"; }
erro() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

echo
echo "Instalando a memória compartilhada do Claude Code"
echo "-------------------------------------------------"

# --- Verificações antes de mexer em qualquer coisa --------------------------

if [ "$BRAIN_DIR" != "$HOME/claude-brain" ]; then
  erro "este repositório precisa estar clonado em ~/claude-brain"
  erro "está em: $BRAIN_DIR"
  erro "As duas máquinas usam o mesmo caminho — é o que faz a sincronização casar."
  exit 1
fi

command -v git >/dev/null || { erro "git não encontrado"; exit 1; }

if [ "$SINCRONIZAR" = "tudo" ]; then
  echo
  echo "  ATENÇÃO — você escolheu sincronizar o histórico das conversas."
  echo "  O histórico guarda tudo que passou pela tela: conteúdo de arquivo"
  echo "  lido, saída de comando, texto colado. Se alguma sessão leu um"
  echo "  arquivo de senha, ele vai junto para o repositório."
  echo
  echo "  Use SOMENTE com repositório privado."
  echo
  printf "  O repositório é privado? [s/N] "
  read -r resp
  case "$resp" in
    s|S|sim|SIM) ;;
    *) erro "instalação cancelada. Torne o repositório privado ou use SINCRONIZAR=\"memoria\"."; exit 1 ;;
  esac
fi

mkdir -p "$CLAUDE_HOME" "$BRAIN_DIR/memory" "$BRAIN_DIR/historico" "$BRAIN_DIR/claude/rules"

# --- Move o que existe e liga o que é compartilhado -------------------------

# $1 = caminho em ~/.claude   $2 = destino dentro do repositório
ligar() {
  local alvo="$1" origem="$2"
  if [ -L "$alvo" ]; then
    rm -f "$alvo"
  elif [ -e "$alvo" ]; then
    mkdir -p "$BACKUP"
    # Se o repositório ainda está vazio nesse ponto, aproveita o conteúdo atual.
    if [ ! -s "$origem" ] && [ -f "$alvo" ]; then
      cp "$alvo" "$origem"
      info "aproveitei o seu $(basename "$alvo") atual"
    elif [ -d "$alvo" ] && [ -z "$(ls -A "$origem" 2>/dev/null)" ]; then
      cp -a "$alvo/." "$origem/" 2>/dev/null || true
      info "aproveitei o conteúdo atual de $(basename "$alvo")/"
    fi
    mv "$alvo" "$BACKUP/"
    info "o antigo $(basename "$alvo") foi guardado em $BACKUP/"
  fi
  ln -s "$origem" "$alvo"
  ok "$(basename "$alvo") ligado ao repositório"
}

echo
echo "Configuração pessoal:"
[ -f "$BRAIN_DIR/claude/CLAUDE.md" ]     || : > "$BRAIN_DIR/claude/CLAUDE.md"
[ -f "$BRAIN_DIR/claude/settings.json" ] || echo '{}' > "$BRAIN_DIR/claude/settings.json"
ligar "$CLAUDE_HOME/CLAUDE.md"     "$BRAIN_DIR/claude/CLAUDE.md"
ligar "$CLAUDE_HOME/settings.json" "$BRAIN_DIR/claude/settings.json"
ligar "$CLAUDE_HOME/rules"         "$BRAIN_DIR/claude/rules"

echo
echo "Memória:"
ok "as anotações do Claude vão para $BRAIN_DIR/memory (via autoMemoryDirectory)"

echo
echo "Histórico das conversas:"
if [ "$SINCRONIZAR" = "tudo" ]; then
  ligar "$CLAUDE_HOME/projects" "$BRAIN_DIR/historico"
  ok "as conversas passam a ser compartilhadas entre as duas máquinas"
else
  info "modo \"memoria\": as conversas ficam locais nesta máquina"
fi

# --- Prazo de retenção ------------------------------------------------------

echo
echo "Prazo de retenção:"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$BRAIN_DIR/claude/settings.json" "$RETENCAO_DIAS" <<'PY'
import json, sys
caminho, dias = sys.argv[1], int(sys.argv[2])
with open(caminho) as f:
    dados = json.load(f)
dados["cleanupPeriodDays"] = dias
dados.setdefault("autoMemoryDirectory", "~/claude-brain/memory")
with open(caminho, "w") as f:
    json.dump(dados, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  ok "conversas guardadas por $RETENCAO_DIAS dias (o padrão do Claude Code é 30)"
else
  info "python3 não encontrado — confira cleanupPeriodDays em claude/settings.json"
fi

# --- Fecho ------------------------------------------------------------------

git -C "$BRAIN_DIR" config --local core.fileMode false 2>/dev/null || true
chmod +x "$BRAIN_DIR"/bin/*.sh 2>/dev/null || true

echo
echo "-------------------------------------------------"
ok "pronto nesta máquina."
echo
echo "  A partir de agora, ao ABRIR o Claude Code ele busca o que veio da outra"
echo "  máquina, e ao FECHAR ele envia o que você fez aqui. Sem você fazer nada."
echo
echo "  Para sincronizar na hora, sem fechar:  $BRAIN_DIR/bin/cc-sync-push.sh --forcar"
echo
if [ -d "${BACKUP:-}" ]; then
  echo "  Sua configuração antiga está em: $BACKUP"
  echo "  Confira que está tudo certo antes de apagar essa pasta."
  echo
fi
echo "  Falta fazer uma vez, na outra máquina: clonar em ~/claude-brain e rodar este script."
echo "  E manter os projetos NO MESMO CAMINHO nas duas — senão o histórico"
echo "  antigo existe, mas não aparece na lista para reabrir."
echo
