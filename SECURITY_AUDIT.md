# AIUsageBar Security Audit

Audit Date: 2026-07-09
Version: v1.0.0

## Summary

AIUsageBar is designed with a privacy-first, local-only architecture. This audit confirms that no sensitive data is exposed in the source code or build artifacts.

## Audit Results

| Check | Status | Notes |
|-------|--------|-------|
| API Keys in source | ✅ PASS | No API keys found. Keys stored in macOS Keychain only. |
| .env files | ✅ PASS | No .env files in repository. |
| Certificate/Key files | ✅ PASS | No .key, .pem files present. |
| Token/Secret files | ✅ PASS | No .token, .secret, .credential files. |
| Database files | ✅ PASS | SQLite databases excluded via .gitignore. |
| Log files | ✅ PASS | Log files and crash reports excluded via .gitignore. |
| Personal paths | ✅ PASS | No hardcoded /Users/ paths in source code. Uses NSHomeDirectory(). |
| Credential files | ✅ PASS | Only Info.plist (non-sensitive), LICENSE, README. |
| Build artifacts | ✅ PASS | .build/ and build/ directories excluded via .gitignore. |

## Security Architecture

- **API Keys**: Stored exclusively in macOS Keychain via Security framework
  - Service name: `com.a1.ai-usage-bar.provider.<name>`
  - Account: `api_key`
  - Accessible: `kSecAttrAccessibleAfterFirstUnlock`

- **Database**: Local SQLite in `runtime/` directory (excluded from git)
  - WAL mode for concurrent access
  - No telemetry, no cloud sync

- **Configuration**: `pricing.yaml` contains only pricing data
  - No API keys, tokens, or secrets
  - Configurable by user

- **Data Sources**: Read-only access to:
  - `~/.claude/projects/**/*.jsonl` — Claude Code session logs
  - `~/.codex/state_*.sqlite` — Codex usage data

## Sensitive Files (Excluded via .gitignore)

```
.build/
build/
.env
.env.local
*.sqlite
*.sqlite-wal
*.sqlite-shm
*.log
*.ips
*.key
*.pem
DerivedData/
```

## Conclusion

The AIUsageBar repository is safe for public release. No sensitive information is present in the source code, configuration files, or documentation. All user data stays local, API keys are secured in the system Keychain, and build artifacts are excluded from version control.
