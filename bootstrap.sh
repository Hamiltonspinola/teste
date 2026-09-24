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

# Um diretório só com .gitkeep está vazio para os nossos fins. Sem isso, o
# histórico que já existe nesta máquina seria arquivado em vez de aproveitado.
tem_conteudo() {
  [ -d "$1" ] || return 1
  [ -n "$(find "$1" -mindepth 1 ! -name '.gitkeep' -print -quit 2>/dev/null)" ]
}

# Cópia intocada dos arquivos que vieram no repositório. Serve para saber se o
# que está lá ainda é o modelo de fábrica ou já é conteúdo seu, vindo da outra
# máquina.
MODELOS="$BRAIN_DIR/.modelos"

eh_modelo_de_fabrica() {
  local arquivo="$1" nome
  nome="$(basename "$arquivo")"
  [ -f "$MODELOS/$nome" ] && cmp -s "$arquivo" "$MODELOS/$nome"
}

# Liga um caminho de ~/.claude ao repositório, aproveitando o que você já tem.
#   $1 = caminho em ~/.claude    $2 = destino dentro do repositório
ligar() {
  local alvo="$1" origem="$2"

  # Já está ligado de uma instalação anterior: só refaz o link.
  if [ -L "$alvo" ]; then
    rm -f "$alvo"
    ln -s "$origem" "$alvo"
    ok "$(basename "$alvo") ligado ao repositório"
    return
  fi

  if [ -f "$alvo" ]; then
    if eh_modelo_de_fabrica "$origem"; then
      # O repositório ainda tem só o modelo: o seu arquivo é o que vale.
      cp "$alvo" "$origem"
      info "aproveitei o seu $(basename "$alvo") atual"
    elif ! cmp -s "$alvo" "$origem"; then
      # Os dois têm conteúdo e são diferentes. Não escolho por você.
      mkdir -p "$BACKUP"
      cp "$alvo" "$BACKUP/$(basename "$alvo").seu"
      info "seu $(basename "$alvo") tinha conteúdo diferente do compartilhado."
      info "  guardei em $BACKUP/$(basename "$alvo").seu"
      info "  abra os dois e junte o que quiser manter."
      PENDENCIAS=$((PENDENCIAS + 1))
    fi
    mkdir -p "$BACKUP"; mv "$alvo" "$BACKUP/"

  elif [ -d "$alvo" ]; then
    if tem_conteudo "$alvo" && ! tem_conteudo "$origem"; then
      cp -a "$alvo/." "$origem/" 2>/dev/null || true
      info "aproveitei o que já existia em $(basename "$alvo")/"
    elif tem_conteudo "$alvo" && tem_conteudo "$origem"; then
      # Junta os dois lados: o que já está no repositório tem prioridade.
      cp -an "$alvo/." "$origem/" 2>/dev/null || true
      info "juntei o que existia em $(basename "$alvo")/ com o que veio da outra máquina"
    fi
    mkdir -p "$BACKUP"; mv "$alvo" "$BACKUP/"
  fi

  ln -s "$origem" "$alvo"
  ok "$(basename "$alvo") ligado ao repositório"
}

# Desfaz o compartilhamento das conversas, devolvendo-as para esta máquina.
#
# Serve para quem instalou com SINCRONIZAR="tudo" e depois mudou de ideia: sem
# isso, ~/.claude/projects continuaria sendo um link para dentro do repositório
# e as conversas seguiriam sendo enviadas, apesar da configuração dizer o
# contrário.
desligar_historico() {
  local alvo="$CLAUDE_HOME/projects"

  if [ ! -L "$alvo" ]; then
    info "modo \"memoria\": as conversas ficam locais nesta máquina"
    return
  fi

  local destino
  destino="$(readlink -f "$alvo" 2>/dev/null || readlink "$alvo")"
  case "$destino" in
    "$BRAIN_DIR"/*) ;;
    *) info "modo \"memoria\": as conversas ficam locais nesta máquina"; return ;;
  esac

  # Traz as conversas de volta para o disco local, antes de cortar o vínculo.
  rm -f "$alvo"
  mkdir -p "$alvo"
  if [ -d "$destino" ]; then
    cp -a "$destino/." "$alvo/" 2>/dev/null || true
    find "$alvo" -name '.gitkeep' -delete 2>/dev/null || true
  fi
  ok "conversas devolvidas para $alvo, nesta máquina"

  # Tira as conversas do repositório, para não continuarem sendo enviadas.
  if [ -n "$(find "$destino" -mindepth 1 ! -name '.gitkeep' -print -quit 2>/dev/null)" ]; then
    find "$destino" -mindepth 1 ! -name '.gitkeep' -delete 2>/dev/null || true
    : > "$destino/.gitkeep"
    git -C "$BRAIN_DIR" add -A historico >/dev/null 2>&1 || true
    ok "conversas removidas do repositório (a memória continua sincronizando)"
    PENDENCIAS_HISTORICO=1
  fi
}

PENDENCIAS=0

echo
echo "Configuração pessoal:"
[ -f "$BRAIN_DIR/claude/CLAUDE.md" ]     || : > "$BRAIN_DIR/claude/CLAUDE.md"
[ -f "$BRAIN_DIR/claude/settings.json" ] || echo '{}' > "$BRAIN_DIR/claude/settings.json"
ligar "$CLAUDE_HOME/CLAUDE.md"     "$BRAIN_DIR/claude/CLAUDE.md"
ligar "$CLAUDE_HOME/settings.json" "$BRAIN_DIR/claude/settings.json"
ligar "$CLAUDE_HOME/rules"         "$BRAIN_DIR/claude/rules"

echo
echo "Memória:"
if [ "$SINCRONIZAR" = "tudo" ]; then
  ok "a memória de cada projeto viaja junto com as conversas dele, separada por projeto"
else
  ok "as anotações do Claude vão para $BRAIN_DIR/memory (via autoMemoryDirectory)"
fi

echo
echo "Histórico das conversas:"
if [ "$SINCRONIZAR" = "tudo" ]; then
  ligar "$CLAUDE_HOME/projects" "$BRAIN_DIR/historico"
  ok "as conversas passam a ser compartilhadas entre as duas máquinas"
else
  desligar_historico
fi

# --- Prazo de retenção ------------------------------------------------------

echo
echo "Sincronização automática e retenção:"
command -v python3 >/dev/null 2>&1 || {
  erro "python3 não encontrado — não consigo configurar a sincronização."
  erro "Instale o python3 e rode este script de novo."
  exit 1
}
python3 "$BRAIN_DIR/bin/aplicar-settings.py" "$BRAIN_DIR/claude/settings.json" "$RETENCAO_DIAS" "$SINCRONIZAR" || {
  erro "não consegui ajustar claude/settings.json"
  exit 1
}
ok "sincroniza ao abrir e ao fechar o Claude Code"
ok "conversas guardadas por $RETENCAO_DIAS dias (o padrão do Claude Code é 30)"

# --- Conferência: a instalação só vale se isto passar ----------------------

echo
echo "Conferindo:"
falhou=0
for arq in "$CLAUDE_HOME/CLAUDE.md" "$CLAUDE_HOME/settings.json"; do
  if [ -L "$arq" ] && [ -e "$arq" ]; then
    ok "$(basename "$arq") apontando para o repositório"
  else
    erro "$(basename "$arq") não ficou ligado"; falhou=1
  fi
done
for gancho in cc-sync-pull.sh cc-sync-push.sh; do
  if grep -q "$gancho" "$BRAIN_DIR/claude/settings.json"; then
    ok "gancho $gancho registrado"
  else
    erro "gancho $gancho NAO registrado - a sincronizacao nao vai rodar"; falhou=1
  fi
done
if [ "$SINCRONIZAR" = "tudo" ] && [ ! -L "$CLAUDE_HOME/projects" ]; then
  erro "conversas não ficaram ligadas"; falhou=1
fi
if [ "$falhou" -ne 0 ]; then
  echo
  erro "instalação incompleta — nada foi perdido, mas não vai sincronizar."
  exit 1
fi

# --- Fecho ------------------------------------------------------------------

# Alinha o nome da rama local com o da rama no servidor. Sem isso, o git recusa
# o envio automático quando os nomes diferem — e o erro parece falha de rede.
alinhar_rama() {
  local upstream rama_remota rama_local
  upstream="$(git -C "$BRAIN_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || return 0
  [ -n "$upstream" ] || return 0
  rama_remota="${upstream#*/}"
  rama_local="$(git -C "$BRAIN_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  [ "$rama_local" = "$rama_remota" ] && return 0
  git -C "$BRAIN_DIR" branch -M "$rama_remota" 2>/dev/null || return 0
  git -C "$BRAIN_DIR" branch --set-upstream-to="$upstream" "$rama_remota" >/dev/null 2>&1 || true
  info "rama local renomeada de '$rama_local' para '$rama_remota', igual à do servidor"
}
alinhar_rama

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
if [ "${PENDENCIAS_HISTORICO:-0}" -eq 1 ]; then
  echo "  As conversas saíram do repositório a partir de agora, mas os commits"
  echo "  antigos ainda as contêm. Para apagá-las de verdade, veja a seção"
  echo "  \"Tirar conversas já enviadas\" no README."
  echo
fi
if [ "${PENDENCIAS:-0}" -gt 0 ]; then
  echo "  ATENÇÃO: $PENDENCIAS arquivo(s) seu(s) tinham conteúdo próprio e não"
  echo "  foram sobrescritos nem descartados. Estão com o sufixo .seu no backup"
  echo "  abaixo, para você juntar o que quiser manter."
  echo
fi
if [ -d "${BACKUP:-}" ]; then
  echo "  Sua configuração antiga está em: $BACKUP"
  echo "  Confira que está tudo certo antes de apagar essa pasta."
  echo
fi
echo "  Falta fazer uma vez, na outra máquina: clonar em ~/claude-brain e rodar este script."
echo "  E manter os projetos NO MESMO CAMINHO nas duas — senão o histórico"
echo "  antigo existe, mas não aparece na lista para reabrir."
echo
