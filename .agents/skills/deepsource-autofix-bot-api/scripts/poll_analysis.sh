#!/usr/bin/env bash
#
# poll_analysis.sh - Poll an Autofix Bot analysis until completion
#
# Usage: ./poll_analysis.sh <analysis_id> [poll_interval_seconds]
#
# Requires AUTOFIX_BOT_API_KEY environment variable.
#
# Polls the analysis endpoint and prints the full result JSON when complete.
# Exits with code 0 on completion, 1 on cancellation or error.

set -euo pipefail

ANALYSIS_ID="${1:?Usage: poll_analysis.sh <analysis_id> [poll_interval]}"
POLL_INTERVAL="${2:-5}"

: "${AUTOFIX_BOT_API_KEY:?Set the AUTOFIX_BOT_API_KEY environment variable}"

API_BASE="https://api.autofix.bot"

echo "Polling analysis $ANALYSIS_ID (every ${POLL_INTERVAL}s)..."

while true; do
    RESPONSE=$(curl -s \
        "$API_BASE/analysis/$ANALYSIS_ID" \
        -H "Authorization: Bearer $AUTOFIX_BOT_API_KEY")

    STATUS=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")

    case "$STATUS" in
        completed)
            echo "Analysis completed." >&2
            echo "$RESPONSE"
            exit 0
            ;;
        canceled)
            echo "Analysis was canceled." >&2
            echo "$RESPONSE"
            exit 1
            ;;
        queued|in_progress)
            echo "  Status: $STATUS" >&2
            sleep "$POLL_INTERVAL"
            ;;
        *)
            echo "Unexpected status: $STATUS" >&2
            echo "$RESPONSE"
            exit 1
            ;;
    esac
done
