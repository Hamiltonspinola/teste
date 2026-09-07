#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de sincronização.

set -uo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/claude-brain}"
[ -f "$BRAIN_DIR/config.sh" ] && . "$BRAIN_DIR/config.sh"

: "${SINCRONIZAR:=tudo}"
: "${RETENCAO_DIAS:=180}"
: "${AUTO_PUSH:=sim}"
: "${AVISAR_SESSAO_DUPLA:=sim}"

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

tem_remote() { g remote get-url origin >/dev/null 2>&1; }

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

  g add -A >/dev/null 2>&1
  g diff --cached --quiet 2>/dev/null || g commit -q -m "$msg" >/dev/null 2>&1 || true

  local i
  for i in 1 2 3 4; do
    if ! g pull --rebase --autostash -q 2>>"$LOG"; then
      if em_rebase; then
        destravar
        aviso "conflito entre o que você fez aqui e o que veio da outra máquina."
        aviso "Nada foi perdido. Resolva com:  cd $BRAIN_DIR && git status"
        log "conflito no rebase ao enviar, desfeito com segurança"
        return 2
      fi
      sleep $((i * 2)); continue    # falha de rede: tenta de novo
    fi
    if g push -q 2>>"$LOG"; then
      log "enviado ($msg)"
      return 0
    fi
    sleep $((i * 2))
  done

  aviso "não consegui enviar (sem rede?). Seu trabalho está salvo aqui."
  aviso "Tente depois:  $BRAIN_DIR/bin/cc-sync-push.sh --forcar"
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
    if g pull --rebase --autostash -q 2>>"$LOG"; then
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
