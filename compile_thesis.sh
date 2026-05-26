#!/usr/bin/env bash
set -euo pipefail

if [ -d "$HOME/Library/TinyTeX/bin/universal-darwin" ]; then
  export PATH="$HOME/Library/TinyTeX/bin/universal-darwin:$PATH"
fi

latexmk -xelatex -interaction=nonstopmode -halt-on-error tesis_draft_detallado.tex
