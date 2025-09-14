#!/usr/bin/env bash
set -euo pipefail

VER=${1:-"0.16.9"}
DST="NoteChat/KaTeX"
mkdir -p "$DST"

echo "Fetching KaTeX $VER assets into $DST..."
curl -fsSL "https://cdn.jsdelivr.net/npm/katex@${VER}/dist/katex.min.js" -o "$DST/katex.min.js"
curl -fsSL "https://cdn.jsdelivr.net/npm/katex@${VER}/dist/contrib/auto-render.min.js" -o "$DST/auto-render.min.js"
curl -fsSL "https://cdn.jsdelivr.net/npm/katex@${VER}/dist/katex.min.css" -o "$DST/katex.min.css"

echo "Done. Add NoteChat/KaTeX/* to Copy Bundle Resources in Xcode."

