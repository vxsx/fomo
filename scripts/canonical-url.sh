#!/usr/bin/env bash
# Canonicalize a URL so equivalent variants collapse to one ledger entry.
# Reads URLs on stdin (one per line) or as args, prints canonical form per line.
#
# Rules:
#   - lowercase scheme + host
#   - strip query string and fragment
#   - strip trailing slash from path
#   - strip leading "www."
#   - collapse Sentry host variants: blog.sentry.io/X  ↔  sentry.io/blog/X
#     (sentry.engineering is a distinct publication and is left alone)
#
# Usage:
#   echo "https://blog.sentry.io/x/" | scripts/canonical-url.sh
#   scripts/canonical-url.sh https://blog.sentry.io/x/

set -euo pipefail

canonicalize() {
  local url="$1"
  # Drop fragment
  url="${url%%#*}"
  # Drop query
  url="${url%%\?*}"
  # Lowercase scheme://host (leave path case-sensitive)
  if [[ "$url" =~ ^([a-zA-Z]+)://([^/]+)(.*)$ ]]; then
    local scheme="${BASH_REMATCH[1]}"
    local host="${BASH_REMATCH[2]}"
    local path="${BASH_REMATCH[3]}"
    scheme="$(echo "$scheme" | tr '[:upper:]' '[:lower:]')"
    host="$(echo "$host" | tr '[:upper:]' '[:lower:]')"
    # Strip leading www.
    host="${host#www.}"
    # Sentry: blog.sentry.io/<slug>  →  sentry.io/blog/<slug>
    if [[ "$host" == "blog.sentry.io" ]]; then
      host="sentry.io"
      path="/blog${path}"
    fi
    url="${scheme}://${host}${path}"
  fi
  # Strip trailing slash (but keep "scheme://host/")
  if [[ "$url" =~ ^([a-zA-Z]+)://([^/]+)(/.+)/$ ]]; then
    url="${BASH_REMATCH[1]}://${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
  fi
  printf '%s\n' "$url"
}

if [[ $# -gt 0 ]]; then
  for u in "$@"; do canonicalize "$u"; done
else
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    canonicalize "$line"
  done
fi
