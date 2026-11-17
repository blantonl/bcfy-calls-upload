#!/usr/bin/env bash
# Send one call the way a form-field-style recorder does: register it, then PUT its audio.
#
#   scripts/upload-call.sh SYSTEM_ID API_KEY AUDIO_FILE TG FREQ_MHZ [SRC]
#
# The call is timed as ending now (start = now - its length), so it falls inside the time window.
# This sends a REAL call to the node: it appears on Broadcastify Calls. Use a node of your own,
# and a TG (or slot) and audio that belong on it.
#
# AUDIO_FILE: .m4a (AAC) or .mp3. Its length is read with ffprobe, or set CALL_DURATION=seconds.
set -euo pipefail
[ $# -ge 5 ] || { echo "usage: $0 SYSTEM_ID API_KEY AUDIO_FILE TG FREQ_MHZ [SRC]" >&2; exit 2; }
system_id=$1 api_key=$2 audio=$3 tg=$4 freq=$5 src=${6:-0}
URL="${CALLS_UPLOAD_URL:-https://api.broadcastify.com/call-upload}"

case "${audio##*.}" in
  m4a) enc=m4a; type=audio/aac ;;
  mp3) enc=mp3; type=audio/mpeg ;;
  *) echo "audio must be .m4a or .mp3" >&2; exit 2 ;;
esac
duration=${CALL_DURATION:-$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$audio")}
ts=$(awk -v now="$(date +%s)" -v d="$duration" 'BEGIN { printf "%d", now - d }')

# 1. Register the call.
answer=$(curl -sS -F "systemId=$system_id" -F "apiKey=$api_key" -F "enc=$enc" \
  -F "tg=$tg" -F "freq=$freq" -F "ts=$ts" -F "callDuration=$duration" -F "src=$src" "$URL")
code=${answer%% *}
rest=${answer#* }
if [ "$code" != 0 ]; then
  echo "not accepted: $answer" >&2
  # A call Broadcastify already has isn't an error.
  case "$rest" in SKIPPED---ALREADY-RECEIVED-THIS-CALL) exit 0 ;; esac
  exit 1
fi

# 2. Upload the audio to the URL it answered, within 180 s, with the matching Content-Type.
status=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H "Content-Type: $type" \
  --data-binary @"$audio" "$rest")
if [ "$status" = 200 ]; then
  echo "uploaded (tg $tg, $duration s, started $ts)"
else
  echo "audio upload failed: HTTP $status" >&2
  exit 1
fi
