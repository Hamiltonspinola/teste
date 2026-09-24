#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de sincronização.

set -uo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/claude-brain}"
[ -f "$BRAIN_DIR/config.sh" ] && . "$BRAIN_DIR/config.sh"

: "${SINCRONIZAR:=tudo}"
: "${RETENCAO_DIAS:=180}"
: "${AUTO_PUSH:=sim}"
: "${AVISAR_SESSAO_DUPLA:=sim}"

# Rodando como gancho, o git trabalha calado e o que ele disser vai para o log.
# Rodando na mão, você precisa ver o progresso na tela — um envio grande, como
# o primeiro, parece travado quando não mostra nada.
if [ -t 2 ]; then SILENCIO=""; else SILENCIO="-q"; fi

MARCADORES="$BRAIN_DIR/.sessoes-ativas"
LOG="$BRAIN_DIR/.sync.log"

log() { printf '%s | %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
aviso() { printf 'claude-brain: %s\n' "$*" >&2; }

# Identifica esta máquina por um id próprio, gerado uma vez na instalação e
# guardado só aqui (nunca vai para o repositório). Não usamos o hostname como
# identificador porque duas máquinas podem ter o mesmo nome — e aí o aviso de
# sessão dupla nunca dispararia.
maquina() {
  local arq="$BRAIN_DIR/.id-maquina"
  if [ ! -s "$arq" ]; then
    { openssl rand -hex 4 2>/dev/null || od -An -N4 -tx1 /dev/urandom | tr -d ' \n' || date +%s; } > "$arq"
  fi
  printf '%s' "$(cat "$arq")"
}

# Nome legível desta máquina, só para você reconhecer no aviso.
apelido() {
  local h
  h="$(hostname 2>/dev/null | tr -cd '[:alnum:]._-' | cut -c1-40)"
  printf '%s' "${h:-máquina-$(maquina)}"
}

# git só dentro do BRAIN_DIR, nunca no repositório em que você está trabalhando.
g() { git -C "$BRAIN_DIR" "$@"; }

# O progresso do git sai pelo stderr. Desviá-lo para o log sempre deixaria você
# olhando para uma tela parada durante um envio de vários minutos.
gop() {
  if [ -t 2 ]; then g "$@"; else g "$@" 2>>"$LOG"; fi
}

tem_remote() { g remote get-url origin >/dev/null 2>&1; }

# Para onde esta rama envia, no formato "origin main".
#
# Não dá para usar "git push" sem argumentos: quando o nome da rama local é
# diferente do nome da rama no servidor — o caso de quem clonou de um lugar e
# passou a enviar para outro — o git recusa em vez de enviar, e o erro parece
# falha de rede.
destino() {
  local upstream
  upstream="$(g rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || return 1
  [ -n "$upstream" ] || return 1
  printf '%s %s' "${upstream%%/*}" "${upstream#*/}"
}

# O git devolve caminhos relativos ao repositório; sem resolver para caminho
# absoluto, o teste falha e o repositório fica travado no meio de um rebase.
em_rebase() {
  local d
  d="$(g rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  [ -d "$d/rebase-merge" ] || [ -d "$d/rebase-apply" ]
}

# Sai de um rebase pela metade sem perder nada do que é seu.
destravar() {
  if em_rebase; then
    g rebase --abort >/dev/null 2>&1 || g rebase --quit >/dev/null 2>&1
  fi
  em_rebase && return 1 || return 0
}

# Envia o que está local. Nunca descarta trabalho: em caso de conflito,
# aborta, deixa tudo como está e avisa você.
enviar() {
  local msg="${1:-sync}"
  tem_remote || { log "sem remote configurado, nada a enviar"; return 0; }

  destravar || { aviso "repositório travado em $BRAIN_DIR. Rode: git -C $BRAIN_DIR rebase --abort"; return 1; }

  local remoto rama
  read -r remoto rama <<< "$(destino)"
  if [ -z "${rama:-}" ]; then
    aviso "esta cópia não sabe para onde enviar."
    aviso "Resolva uma vez com:  git -C $BRAIN_DIR push -u origin HEAD:main"
    log "sem upstream configurado"
    return 1
  fi

  # O GitHub recusa arquivo acima de 100 MB, e recusa DEPOIS de subir tudo.
  # Melhor descobrir aqui do que após dez minutos de upload.
  local grandes
  grandes="$(find "$BRAIN_DIR" -path "$BRAIN_DIR/.git" -prune -o -type f -size +95M -print 2>/dev/null | head -3)"
  if [ -n "$grandes" ]; then
    aviso "há arquivo(s) grandes demais para o GitHub (limite de 100 MB):"
    printf '  %s\n' $grandes >&2
    aviso "o envio vai falhar. Apague-os ou acrescente ao .gitignore antes de tentar."
    log "envio abortado: arquivo acima de 95 MB"
    return 1
  fi

  g add -A >/dev/null 2>&1
  g diff --cached --quiet 2>/dev/null || g commit -q -m "$msg" >/dev/null 2>&1 || true

  local i
  for i in 1 2 3 4; do
    if ! gop pull --rebase --autostash $SILENCIO; then
      if em_rebase; then
        destravar
        aviso "conflito entre o que você fez aqui e o que veio da outra máquina."
        aviso "Nada foi perdido. Resolva com:  cd $BRAIN_DIR && git status"
        log "conflito no rebase ao enviar, desfeito com segurança"
        return 2
      fi
      sleep $((i * 2)); continue    # falha de rede: tenta de novo
    fi
    if gop push $SILENCIO "$remoto" "HEAD:$rama"; then
      log "enviado ($msg) para $remoto/$rama"
      return 0
    fi
    sleep $((i * 2))
  done

  aviso "não consegui enviar. Seu trabalho está salvo aqui."
  aviso "Veja o motivo em:  tail $LOG"
  aviso "E tente de novo com:  $BRAIN_DIR/bin/cc-sync-push.sh --forcar"
  log "falha ao enviar após 4 tentativas"
  return 1
}

# Traz o que a outra máquina deixou.
baixar() {
  tem_remote || { log "sem remote configurado, nada a baixar"; return 0; }

  destravar || { aviso "repositório travado em $BRAIN_DIR. Rode: git -C $BRAIN_DIR rebase --abort"; return 1; }

  # Guarda o que estiver solto para o pull não recusar.
  g add -A >/dev/null 2>&1
  g diff --cached --quiet 2>/dev/null || g commit -q -m "local antes de sincronizar" >/dev/null 2>&1 || true

  local i
  for i in 1 2 3 4; do
    if gop pull --rebase --autostash $SILENCIO; then
      log "baixado"
      return 0
    fi
    if em_rebase; then
      destravar
      aviso "conflito ao trazer o que veio da outra máquina."
      aviso "Nada foi perdido. Resolva com:  cd $BRAIN_DIR && git status"
      log "conflito ao baixar, desfeito com segurança"
      return 2
    fi
    sleep $((i * 2))
  done

  aviso "sem conexão com o repositório. Seguindo com a memória que já está aqui."
  log "falha ao baixar após 4 tentativas"
  return 1
}
