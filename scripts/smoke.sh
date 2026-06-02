#!/usr/bin/env bash
# HTTP smoke checks for storefront / health endpoints (Phase 9).
# Usage:
#   ./scripts/smoke.sh --url https://example.com
#   ./scripts/smoke.sh --env stage
#   SMOKE_URLS="https://a https://b" ./scripts/smoke.sh
# Env overrides (defaults match README reference hosts):
#   SMOKE_DEV_URL, SMOKE_STAGE_URL, SMOKE_PROD_URL
set -euo pipefail

SMOKE_DEV_URL="${SMOKE_DEV_URL:-https://dev.boutique.example.com}"
SMOKE_STAGE_URL="${SMOKE_STAGE_URL:-https://stage.boutique.example.com}"
SMOKE_PROD_URL="${SMOKE_PROD_URL:-https://boutique.example.com}"

urls=()

usage() {
  cat <<'EOF'
Usage: scripts/smoke.sh [--url URL]... [--env dev|stage|prod]... [URL]...
  Or: SMOKE_URLS="https://a https://b" scripts/smoke.sh
Override defaults: SMOKE_DEV_URL, SMOKE_STAGE_URL, SMOKE_PROD_URL
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage 0 ;;
    --url)
      [[ -n "${2:-}" ]] || usage 2
      urls+=("$2")
      shift 2
      ;;
    --env)
      [[ -n "${2:-}" ]] || usage 2
      case "$2" in
        dev) urls+=("$SMOKE_DEV_URL") ;;
        stage) urls+=("$SMOKE_STAGE_URL") ;;
        prod) urls+=("$SMOKE_PROD_URL") ;;
        *) echo "Unknown --env $2 (use dev, stage, or prod)" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    *)
      urls+=("$1")
      shift
      ;;
  esac
done

if [[ -n "${SMOKE_URLS:-}" ]]; then
  read -r -a _smoke_extra <<< "$SMOKE_URLS"
  urls+=("${_smoke_extra[@]}")
fi

if [[ ${#urls[@]} -eq 0 ]]; then
  echo "smoke.sh: no URLs. Use --url, --env, positional URLs, or SMOKE_URLS." >&2
  usage 2
fi

failures=0
for u in "${urls[@]}"; do
  if [[ -z "$u" ]]; then
    continue
  fi
  echo "##[group]GET $u"
  code="$(
    curl -sS -o /dev/null -w '%{http_code}' \
      --max-time 45 \
      --retry 3 \
      --retry-delay 2 \
      --retry-all-errors \
      -L \
      "$u" || echo "000"
  )"
  echo "HTTP $code"
  echo "##[endgroup]"
  if [[ "$code" != "200" ]]; then
    echo "##[error]Smoke failed: $u returned HTTP $code (expected 200)" >&2
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
echo "Smoke OK (${#urls[@]} URL(s))."
