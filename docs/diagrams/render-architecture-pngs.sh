#!/usr/bin/env bash
# Regenerate architecture PNGs 00-03 from Mermaid sources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/source"
cd "${SRC}"
for f in 00-platform-overview 01-cicd-flow 02-azure-resources 03-inside-cluster; do
  echo "Rendering ${f}.png ..."
  npx --yes @mermaid-js/mermaid-cli@11.4.0 -i "${f}.mmd" -o "../${f}.png" -b white -w 1600
done
echo "Done. Output: ${ROOT}/*.png"
