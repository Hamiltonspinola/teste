#!/usr/bin/env bash
# =============================================================================
# ÚNICO ARQUIVO QUE VOCÊ PRECISA EDITAR.
# Vale para as duas máquinas (notebook e computador).
# =============================================================================

# Onde este repositório fica clonado. Precisa ser IGUAL nas duas máquinas.
BRAIN_DIR="${BRAIN_DIR:-$HOME/claude-brain}"

# O que sincronizar entre as máquinas:
#   "tudo"    = memória do Claude + histórico das conversas (permite reabrir
#               uma conversa da outra máquina de onde parou)
#   "memoria" = só a memória. As conversas ficam locais em cada máquina.
#
# ATENÇÃO ao escolher "tudo": o histórico guarda tudo que passou pela tela,
# inclusive conteúdo de arquivo lido e saída de comando. Se alguma sessão leu
# um arquivo de senha, ele vai junto. Use SEMPRE repositório privado.
SINCRONIZAR="tudo"

# Por quantos dias guardar as conversas antigas.
# O padrão do Claude Code é 30; abaixo disso você perde histórico sem perceber.
RETENCAO_DIAS=180

# Enviar automaticamente ao encerrar a sessão ("sim" recomendado).
# Com "nao", você sincroniza na mão rodando: ~/claude-brain/bin/cc-sync-push.sh
AUTO_PUSH="sim"

# Aviso quando a MESMA conversa parecer aberta nas duas máquinas ao mesmo tempo.
AVISAR_SESSAO_DUPLA="sim"
