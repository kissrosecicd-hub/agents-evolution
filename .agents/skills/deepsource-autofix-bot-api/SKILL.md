---
name: autofix-bot-api
description: >
  Scan code for security vulnerabilities, leaked secrets, and dependency issues using the
  Autofix Bot API (api.autofix.bot), and auto-fix detected issues. Use this skill when asked to:
  (1) Scan or analyze a repository or code for security issues, secrets, or vulnerabilities using Autofix Bot,
  (2) Upload/sync a local git repository to Autofix Bot for analysis,
  (3) Run Autofix Bot on code changes, pull requests, or patches,
  (4) Apply auto-fixes from Autofix Bot analysis results.
  Requires an Autofix Bot API key (environment variable AUTOFIX_BOT_API_KEY).
---

# Autofix Bot API

Scan code for security vulnerabilities, secrets, and dependency issues via the Autofix Bot REST API, and auto-fix detected issues.

## Authentication

All API calls require a Bearer token. Read the key from the `AUTOFIX_BOT_API_KEY` environment variable:

```bash
curl https://api.autofix.bot/workspace \
  -H "Authorization: Bearer $AUTOFIX_BOT_API_KEY"
```

If the key is not set, ask the user to provide it. Never hardcode API keys or pass them as command-line arguments. All bundled scripts read from this environment variable automatically.

## Workflow

### Step 1: Create a repository

```bash
curl -X POST https://api.autofix.bot/repositories \
  -H "Authorization: Bearer $AUTOFIX_BOT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-repo",
    "external_id": "local:my-repo",
    "detection": ["security", "secrets"],
    "fix": ["security", "secrets"]
  }'
```

Save the returned `id` (e.g., `repo_...`). Use `external_id` to avoid duplicates — if a repo with the same `external_id` exists, retrieve it with `GET /repositories/external:local:my-repo` instead.

### Step 2: Sync code

Use the bundled `scripts/sync_repo.sh` script:

```bash
# Full sync (first time)
./scripts/sync_repo.sh /path/to/repo <repo_id>

# Incremental sync (subsequent updates)
./scripts/sync_repo.sh /path/to/repo <repo_id> <base_ref>
```

The script creates a git bundle, obtains a signed upload URL, uploads the bundle, and polls until sync completes. It outputs the sync ID on success.

**Manual sync steps** (if not using the script):

1. Create a git bundle:
   ```bash
   # Full
   git bundle create repo.bundle --all
   # Incremental from a base ref
   git bundle create repo.bundle <base_ref>..HEAD
   ```

2. Create a sync: `POST /repositories/{id}/syncs` with `{"type": "full"}` or `{"type": "incremental", "base_ref": "<ref>"}`

3. Upload the bundle to the `upload_url` from the response:
   ```bash
   curl -X PUT "<upload_url>" -H "Content-Type: application/octet-stream" --data-binary @repo.bundle
   ```

4. Poll `GET /repositories/{id}/syncs/{sync_id}` until `status` is `completed`.

### Step 3: Run analysis

```bash
curl -X POST https://api.autofix.bot/analysis \
  -H "Authorization: Bearer $AUTOFIX_BOT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "repository",
    "repository_id": "<repo_id>",
    "from_ref": "<commit_sha>"
  }'
```

- `from_ref` (required): the git commit/ref to analyze from. Use the full SHA of HEAD for a full scan.
- `to_ref` (optional): end ref for analyzing a range of changes.
- `patch` (optional): git patch to apply before analysis. Mutually exclusive with `to_ref`.

### Step 4: Poll for results

Use the bundled `scripts/poll_analysis.sh` script:

```bash
RESULT=$(./scripts/poll_analysis.sh <analysis_id>)
```

Or poll manually: `GET /analysis/{id}` until `status` is `completed`.

### Step 5: Inspect results and apply fixes

The completed analysis contains:

- `detection_result.issues` — list of detected issues with file, position, explanation, category
- `fix_result.patch` — unified diff patch that fixes the detected issues
- `fix_result.fixes` — individual fixes with explanations

**Apply the fix patch:**

```bash
echo "$FIX_PATCH" | git apply
```

If only the first 50 issues/fixes are returned (`has_more: true`), paginate with:
- `GET /analysis/{id}/issues?limit=100`
- `GET /analysis/{id}/fixes?limit=100`

## Detection Categories

| Category | Description |
|----------|-------------|
| `security` | Code vulnerabilities (injection, XSS, unsafe deserialization, etc.) |
| `secrets` | Leaked credentials, API keys, tokens in source code |
| `dependencies` | Vulnerable dependencies |

Default detection: `["security", "secrets"]`. Set per-repository or per-analysis.

## Key Patterns

**Reuse repositories**: Look up existing repos by external_id (`GET /repositories/external:<external_id>`) before creating new ones.

**Incremental syncs**: After the first full sync, use incremental syncs with `base_ref` set to the last synced commit for faster uploads.

**Idempotency**: Send `Idempotency-Key` header on create operations for safe retries.

**Ref for full scan**: To scan the entire repo, set `from_ref` to the root commit or the HEAD commit SHA after syncing.

## API Reference

For detailed endpoint documentation, request/response schemas, pagination, and error codes, see [references/api-reference.md](references/api-reference.md).
