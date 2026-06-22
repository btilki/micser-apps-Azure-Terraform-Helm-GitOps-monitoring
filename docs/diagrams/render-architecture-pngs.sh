#!/usr/bin/env bash
# Regenerate architecture PNGs from Mermaid sources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/source"
CFG="${SRC}/mermaid-config.json"
cd "${SRC}"

MM="npx --yes @mermaid-js/mermaid-cli@11.4.0"

echo "Rendering infrastructure-diagram.png (high resolution) ..."
${MM} -i infrastructure-diagram.mmd -o ../infrastructure-diagram.png \
  -c "${CFG}" -b white -w 5200 -H 3600 -s 2

echo "Rendering architecture-cicd-sequence.png ..."
${MM} -i architecture-cicd-sequence.mmd -o ../architecture-cicd-sequence.png \
  -c "${CFG}" -b white -w 3200 -H 4200 -s 2

echo "Done. Output: ${ROOT}/*.png"
