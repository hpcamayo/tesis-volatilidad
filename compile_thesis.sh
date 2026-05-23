#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/Library/TinyTeX/bin/universal-darwin:$PATH"

latexmk -pdf -interaction=nonstopmode -halt-on-error tesis_draft_detallado.tex
