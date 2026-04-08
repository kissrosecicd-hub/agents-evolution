---
name: secret-guard
description: Mandatory secret scanning before any git operation. MUST trigger automatically before git commit, git push, git add, PR creation, or any commit-related skill. Scans staged files for API keys, tokens, credentials, and other secrets to prevent accidental exposure in version control.
context: fork
model: claude-sonnet-4-5
---

# Secret Guard

**MANDATORY**: Run before ANY git commit, push, add, or PR operation.

## Scan Commands

Run these before proceeding with any git operation:

```bash
# Check for secret keywords in staged changes (skip removed lines)
git diff --cached | grep -iE '(client_secret|password|api[_-]?key|secret_key|private_key|token|bearer|credential)' | grep -v "^-" | head -20

# Check for long credential-like strings (base64, hex, Azure secrets with ~)
git diff --cached | grep -oE '[a-zA-Z0-9+/~]{35,}' | head -10

# Check config files specifically for secrets
git diff --cached -- '*.json' '*.yaml' '*.yml' | grep -iE '(secret|password|key|token)' | grep -v "^-" | head -10

# List staged files
git diff --cached --name-only
```

## High-Risk Files

**STOP and warn** if any of these are staged:
- `.env`, `.env.*` — Never commit
- `.claude/settings.json` — Often contains embedded secrets
- `*.pem`, `*.key`, `*.p12`, `*.pfx` — Private keys
- `credentials.json`, `secrets.json`, `auth*.json`, `*token*.json`
- `**/config/*.json` — May contain hardcoded credentials

## Secret Patterns

| Pattern              | Identifier                              |
|----------------------|-----------------------------------------|
| Azure AD secrets     | Contains `~` (e.g., `Pl~8Q~abc...`)     |
| AWS Access Keys      | Starts with `AKIA`                      |
| GitHub tokens        | Starts with `ghp_`, `gho_`, `ghs_`      |
| API keys             | Prefixes: `sk-`, `pk-`, `api_`          |
| JWT tokens           | Starts with `eyJ`                       |
| Base64 secrets       | 40+ alphanumeric chars                  |

## If Secrets Detected

**BLOCK the git operation immediately.**

Response format:
```
🚨 SECRET DETECTED - BLOCKING COMMIT

Found in: <filename>
Pattern: <what was found>

REQUIRED ACTIONS:
1. Remove the secret from the file
2. Use environment variables instead
3. If already committed: rotate the credential immediately

Proceed with commit? (only after user confirms false positive)
```

## Safe to Proceed When

- No secret keywords in staged diffs
- No high-risk files staged (or user explicitly reviewed)
- No long random strings resembling credentials
- User confirmed any flagged items are false positives

## Post-Commit Reminder

After successful commit without pre-commit hooks installed:
> "Consider adding a pre-commit hook for automatic secret scanning."
