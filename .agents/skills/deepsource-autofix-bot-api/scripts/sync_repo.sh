#!/usr/bin/env bash
#
# sync_repo.sh - Create a git bundle and sync it to Autofix Bot
#
# Usage:
#   Full sync:        ./sync_repo.sh <repo_path> <api_repo_id> [base_ref]
#   Incremental sync: ./sync_repo.sh <repo_path> <api_repo_id> <base_ref>
#
# Requires AUTOFIX_BOT_API_KEY environment variable.
#
# Creates a git bundle from a local repository and uploads it to Autofix Bot
# via a signed URL. Returns the sync ID on success.

set -euo pipefail

REPO_PATH="${1:?Usage: sync_repo.sh <repo_path> <api_repo_id> [base_ref]}"
API_REPO_ID="${2:?Missing api_repo_id}"
BASE_REF="${3:-}"

: "${AUTOFIX_BOT_API_KEY:?Set the AUTOFIX_BOT_API_KEY environment variable}"

API_BASE="https://api.autofix.bot"
BUNDLE_FILE=$(mktemp /tmp/autofix-bundle-XXXXXX.bundle)

cleanup() { rm -f "$BUNDLE_FILE"; }
trap cleanup EXIT

# Determine sync type and create bundle
if [ -z "$BASE_REF" ]; then
    SYNC_TYPE="full"
    echo "Creating full git bundle..."
    git -C "$REPO_PATH" bundle create "$BUNDLE_FILE" --all
else
    SYNC_TYPE="incremental"
    echo "Creating incremental git bundle from $BASE_REF..."
    git -C "$REPO_PATH" bundle create "$BUNDLE_FILE" "$BASE_REF"..HEAD
fi

BUNDLE_SIZE=$(stat -f%z "$BUNDLE_FILE" 2>/dev/null || stat -c%s "$BUNDLE_FILE" 2>/dev/null)
echo "Bundle created: $(( BUNDLE_SIZE / 1024 )) KB"

# Create sync to get upload URL
echo "Creating $SYNC_TYPE sync..."
if [ "$SYNC_TYPE" = "full" ]; then
    SYNC_BODY="{\"type\":\"full\"}"
else
    SYNC_BODY="{\"type\":\"incremental\",\"base_ref\":\"$BASE_REF\"}"
fi

SYNC_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_BASE/repositories/$API_REPO_ID/syncs" \
    -H "Authorization: Bearer $AUTOFIX_BOT_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$SYNC_BODY")

HTTP_CODE=$(echo "$SYNC_RESPONSE" | tail -1)
SYNC_JSON=$(echo "$SYNC_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo "Error creating sync (HTTP $HTTP_CODE):" >&2
    echo "$SYNC_JSON" >&2
    exit 1
fi

SYNC_ID=$(echo "$SYNC_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
UPLOAD_URL=$(echo "$SYNC_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['upload_url'])")

echo "Sync created: $SYNC_ID"

# Upload bundle to signed URL
echo "Uploading bundle..."
UPLOAD_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT "$UPLOAD_URL" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$BUNDLE_FILE")

if [ "$UPLOAD_CODE" -lt 200 ] || [ "$UPLOAD_CODE" -ge 300 ]; then
    echo "Error uploading bundle (HTTP $UPLOAD_CODE)" >&2
    exit 1
fi

echo "Upload complete."

# Poll until sync is processed
echo "Waiting for sync to complete..."
while true; do
    POLL_RESPONSE=$(curl -s \
        "$API_BASE/repositories/$API_REPO_ID/syncs/$SYNC_ID" \
        -H "Authorization: Bearer $AUTOFIX_BOT_API_KEY")

    STATUS=$(echo "$POLL_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")

    case "$STATUS" in
        completed)
            echo "Sync completed successfully."
            echo "$SYNC_ID"
            exit 0
            ;;
        failed)
            ERROR=$(echo "$POLL_RESPONSE" | python3 -c "import sys,json; e=json.load(sys.stdin).get('error',{}); print(e.get('message','Unknown error'))")
            echo "Sync failed: $ERROR" >&2
            exit 1
            ;;
        expired)
            echo "Sync expired before processing." >&2
            exit 1
            ;;
        *)
            sleep 3
            ;;
    esac
done
