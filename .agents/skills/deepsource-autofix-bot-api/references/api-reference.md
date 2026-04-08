# Autofix Bot API Reference

Base URL: `https://api.autofix.bot`

All requests require: `Authorization: Bearer <API_KEY>`

All timestamps are Unix timestamps (seconds). All monetary amounts are in cents (USD).

## Table of Contents

- [Workspace](#workspace)
- [Repositories](#repositories)
- [Syncs](#syncs)
- [Analyses](#analyses)
- [Issues & Fixes](#issues--fixes)
- [Pagination](#pagination)
- [Error Format](#error-format)
- [Supported Languages](#supported-languages)

---

## Workspace

### Get workspace

```
GET /workspace
```

Returns the workspace associated with the API key.

Response:
```json
{
  "id": "ws_018e8c5a12347890abcdef0123456789",
  "object": "workspace",
  "name": "Acme Corp Engineering",
  "created_at": 1704067200,
  "status": "active"
}
```

---

## Repositories

### Create a repository

```
POST /repositories
```

Body:
```json
{
  "name": "backend-api",
  "external_id": "github:123456789",
  "languages": ["python", "javascript"],
  "test_patterns": ["**/tests/**", "**/*_test.py"],
  "exclude_patterns": ["**/node_modules/**"],
  "detection": ["security", "secrets"],
  "fix": ["security", "secrets"]
}
```

Required: `name`. All other fields optional. `detection` defaults to `["security", "secrets"]`.

Supports `Idempotency-Key` header.

### List repositories

```
GET /repositories?limit=10&after=<id>&before=<id>&status=<status>&archived=<bool>
```

`status` enum: `empty`, `uploading`, `error`, `ready`

### Get a repository

```
GET /repositories/{id}
```

`id` can be the internal ID or `external:{external_id}`.

### Update a repository

```
PATCH /repositories/{id}
```

Body: any subset of create fields.

### Delete a repository

```
DELETE /repositories/{id}
```

Returns 204 on success.

---

## Syncs

Syncs upload code to Autofix Bot. A sync creates a signed upload URL for uploading a git bundle.

### Bundle format

Syncs accept **git bundle** files. Create them with:

```bash
# Full sync (entire repo)
git bundle create repo.bundle --all

# Incremental sync (changes since a ref)
git bundle create repo.bundle <base_ref>..HEAD
```

### Create a sync

```
POST /repositories/{id}/syncs
```

Body:
```json
{
  "type": "full"
}
```

Or for incremental:
```json
{
  "type": "incremental",
  "base_ref": "a1b2c3d"
}
```

Response includes `upload_url` (signed GCS URL) and `upload_expires_at`.

### Upload a bundle

After creating a sync, upload the git bundle to the `upload_url`:

```bash
curl -X PUT "<upload_url>" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @repo.bundle
```

### Sync statuses

| Status | Description |
|--------|-------------|
| `pending_upload` | Waiting for bundle upload |
| `processing` | Bundle uploaded, being processed |
| `completed` | Code synced successfully |
| `failed` | Processing failed (check `error` field) |
| `expired` | Upload URL expired before upload |

### Get a sync

```
GET /repositories/{id}/syncs/{sync_id}
```

### List syncs

```
GET /repositories/{id}/syncs?limit=10&status=<status>&type=<type>
```

---

## Analyses

### Create an analysis

```
POST /analysis
```

**Repository analysis** (requires a synced repository):
```json
{
  "type": "repository",
  "repository_id": "repo_018e8c5a23457891bcdef01234567890",
  "from_ref": "a1b2c3d",
  "to_ref": "d4e5f6a",
  "detection": ["security", "secrets"],
  "fix": ["security"]
}
```

- `type` and `repository_id` required for repository analysis
- `from_ref` required — the starting git reference
- `to_ref` optional — end git reference. Cannot be combined with `patch`
- `patch` optional — git patch to apply before analysis. Cannot be combined with `to_ref`
- `detection` and `fix` default to repository settings

Supports `Idempotency-Key` header.

### Get an analysis

```
GET /analysis/{id}
```

Response when completed includes `detection_result`, `fix_result`, and `cost`:

```json
{
  "id": "an_018e8c5f789a78960123456789012345",
  "object": "analysis",
  "type": "repository",
  "status": "completed",
  "detection_result": {
    "object": "result.detection",
    "issues_detected_count": 12,
    "issues_detected_by_category": {"security": 10, "secrets": 2},
    "issues_detected_by_language": {"python": 8, "javascript": 4},
    "issues": [...],
    "has_more": false,
    "url": "/analysis/<id>/issues"
  },
  "fix_result": {
    "object": "result.fix",
    "patch": "<unified diff>",
    "issues_fixed_count": 8,
    "issues_fixed_by_category": {"security": 8},
    "fixes": [...],
    "has_more": false,
    "url": "/analysis/<id>/fixes"
  },
  "cost": {
    "object": "result.cost",
    "input_loc": 1250,
    "input_loc_rate": 0.01,
    "output_fix_loc": 45,
    "output_fix_rate": 0.05,
    "total": 14.75
  }
}
```

### Analysis statuses

| Status | Description |
|--------|-------------|
| `queued` | Waiting to be processed |
| `in_progress` | Currently being analyzed |
| `completed` | Analysis finished with results |
| `canceled` | Analysis was canceled |

### List analyses

```
GET /analysis?limit=10&repository_id=<id>&status=<status>
```

### Cancel an analysis

```
DELETE /analysis/{id}
```

Returns the analysis with status `canceled`. Cannot cancel already-completed analyses.

---

## Issues & Fixes

### List issues for an analysis

```
GET /analysis/{id}/issues?limit=10&category=<cat>&language=<lang>&file=<path>
```

Issue object:
```json
{
  "object": "result.detection.issue",
  "file": "src/auth.py",
  "position": {
    "begin": {"line": 12, "column": 5},
    "end": {"line": 12, "column": 35}
  },
  "explanation": "Use of eval() with user input can lead to arbitrary code execution",
  "category": "security"
}
```

### List fixes for an analysis

```
GET /analysis/{id}/fixes?limit=10&category=<cat>
```

Fix object:
```json
{
  "object": "result.fix.item",
  "category": "security",
  "explanation": "Replace dangerous eval() with safe ast.literal_eval()",
  "patch": "diff --git a/src/validation.py b/src/validation.py\n..."
}
```

---

## Pagination

All list endpoints use cursor-based pagination:

| Parameter | Description |
|-----------|-------------|
| `limit` | 1-100, default 10 |
| `after` | Object ID — return items after this object |
| `before` | Object ID — return items before this object |

`after` and `before` are mutually exclusive. Results are in reverse chronological order.

Response format:
```json
{
  "object": "list",
  "data": [...],
  "has_more": true,
  "url": "/repositories"
}
```

---

## Error Format

```json
{
  "error": {
    "message": "Human-readable message",
    "type": "invalid_request_error",
    "code": "invalid_parameter",
    "fields": {"field_name": "Error for this field"}
  }
}
```

`type` is one of: `api_error`, `invalid_request_error`.

---

## Supported Languages

| Language | Slug | Extensions |
|----------|------|------------|
| Python | `python` | `.py` |
| JavaScript/TypeScript | `javascript` | `.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs` |
| Java | `java` | `.java` |
| Go | `go` | `.go` |
| C# | `csharp` | `.cs` |
| Ansible | `ansible` | `.yml`, `.yaml` |
| C/C++ | `cxx` | `.c`, `.h`, `.cpp`, `.cc`, `.hpp` |
| Docker | `docker` | `Dockerfile`, `.dockerfile` |
| Kotlin | `kotlin` | `.kt`, `.kts` |
| PHP | `php` | `.php` |
| Ruby | `ruby` | `.rb`, `.gemspec`, `Gemfile` |
| Rust | `rust` | `.rs` |
| Scala | `scala` | `.scala`, `.sc` |
| Shell | `shell` | `.sh` |
| SQL | `sql` | `.sql` |
| Swift | `swift` | `.swift` |
| Terraform | `terraform` | `.tf` |

Use the **Slug** value in `language` and `languages` parameters.

---

## Debugging Headers

Responses include:
- `AutofixBot-Version` — API version date (e.g., `2025-09-16`)
- `AutofixBot-Workspace-ID` — Workspace ID
- `Request-ID` — Unique request ID (e.g., `req_dcfyI4yWFYfxNS`)

## Idempotency

Send `Idempotency-Key` header (max 255 chars) on create endpoints for safe retries. Keys are valid for 24 hours.
