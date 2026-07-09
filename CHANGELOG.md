# Changelog

All notable changes to AIUsageBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-07-09

### 🎉 Initial Release

AIUsageBar — a native macOS AI Agent usage monitor and cost control center.

### Features

**AI Agent Tracking**
- Claude Code — API cost tracking via JSONL log scanning
- Codex — Subscription usage tracking via SQLite database scanning
- Extensible plugin architecture for future agents (OpenClaw, Cursor, Gemini CLI)

**Usage Monitoring**
- Real-time token consumption display
- Three-tier cost calculation: input cache hit / cache miss / output
- Subscription quota monitoring (session usage, weekly limits, reset time)
- Per-project and per-model breakdowns
- 7-day usage trend charts

**Cost Control**
- Provider manager with Keychain-secured API key storage
- Model pricing editor (provider/model two-level)
- Budget manager (global & per-provider, total/daily/weekly/monthly)
- Balance prediction with runway calculation

**Privacy & Security**
- Local-first architecture: all data in SQLite, no telemetry
- API keys stored in macOS Keychain only (never in SQLite or files)
- No cloud upload, no tracking, no external dependencies
- Full source code auditability

**Infrastructure**
- Scanner plugin system (ClaudeScanner, CodexScanner, OpenClawScanner)
- Provider adapter protocol (DeepSeek, OpenAI, Anthropic, OpenRouter)
- Model profile export (.env / clipboard)
- macOS LaunchAgent support for auto-start
- Code signing support (Developer ID / Ad-hoc)

### Tech Stack
- SwiftUI 5 + MenuBarExtra (macOS 14+)
- Python 3 scanner plugins
- SQLite 3 (WAL mode, 10 tables)
- macOS Keychain (Security framework)

### Known Issues
- Ad-hoc code signing may trigger Gatekeeper on first launch (right-click → Open)
- Screenshots require Screen Recording permission for terminal apps (macOS 14+)
- Codex quota tracking uses estimated values (SQLite lacks complete quota info)
