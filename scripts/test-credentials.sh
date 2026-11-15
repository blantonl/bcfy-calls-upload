#!/usr/bin/env bash
# Check a node's system ID and API key against Broadcastify Calls (test=1). Records nothing.
#   scripts/test-credentials.sh SYSTEM_ID API_KEY
# Prints the answer; exits 0 only on "OK".
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: $0 SYSTEM_ID API_KEY" >&2; exit 2; }
URL="${CALLS_UPLOAD_URL:-https://api.broadcastify.com/call-upload}"
answer=$(curl -sS -F "systemId=$1" -F "apiKey=$2" -F test=1 "$URL")
echo "$answer"
[ "$answer" = OK ]
