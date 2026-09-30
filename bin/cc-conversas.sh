#!/usr/bin/env bash
# Invólucro para cc-conversas.py. Veja lá a documentação.
BRAIN_DIR="${BRAIN_DIR:-$HOME/claude-brain}"
exec python3 "$BRAIN_DIR/bin/cc-conversas.py" "$@"
