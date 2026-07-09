# Changelog

All notable changes to AIUsageBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.1] — 2026-07-09

### Added

+ **Codex Subscription Dashboard Enhancement**
  - Session usage with progress bar (used % + remaining %)
  - Weekly usage with progress bar (used % + remaining %)
  - Reset time display (relative countdown)
  - Model breakdown by tokens and session count

+ **Agent Provider Status System**
  - New `AgentProviderStatus` model (connected/syncing/unavailable/noData)
  - Dashboard "Agent Status" card showing real-time connection state
  - Status indicators with color-coded dots (green/orange/red/gray)

+ **DataHealthView Upgrade**
  - Scanner status cards for Claude Code and Codex
  - Last sync timestamps with "time ago" formatting
  - Database health overview (WAL mode, table count, record count)
  - Agent-level status with icons and connection indicators

+ **Demo Mode**
  - `--demo` launch argument for UI evaluation without real data
  - Bundled demo database (20 API records + 5 quota records)
  - No configuration required — clone, build, and run with `--demo`

+ **GitHub Actions CI**
  - Automated build workflow (push + PR to main)
  - Debug and release builds
  - App bundle artifact upload

+ **Smart Menu Bar**
  - "🤖 ¥xxx" — API has daily usage
  - "⚠️ Codex xx%" — subscription near limit
  - "AI ✓" — normal idle state

### Changed
- Dashboard: Codex card redesigned with session/weekly progress bars
- DataHealthView: Now uses AgentProviderStatus model for consistent display
- README: Architecture diagram updated with dual-pipeline layout

### Fixed
- All SwiftUI `onChange(of:)` deprecation warnings migrated to `initial: false` API

## [1.1.0] — 2026-07-09

### Added

+ **Separate API Cost and Subscription Usage**
  - Dashboard now has two independent data pipelines (api_usage_records + quota_usage_records)
  - API statistics no longer mixed with subscription data
  - Global statistics split into "API Usage" and "Subscription Usage" sections

+ **Codex Plus Subscription Dashboard**
  - Dedicated Codex card with usage progress bars
  - Session and weekly quota visualization
  - Model breakdown (gpt-5.5, codex-auto-review)
  - Data freshness indicator with last sync timestamp
  - No cost/price displayed for subscription data

+ **Dual Refresh Scheduler**
  - API data refreshes every 30 seconds (apiTimer)
  - Codex data refreshes every 120 seconds (codexTimer)
  - Independent timers, no cross-blocking

+ **Improved Dashboard Layout**
  - Data freshness bar at top ("API 30s ago · Codex 2min ago")
  - "API Cost" hero with provider breakdown
  - "Model Usage" with two sections (API Models + Subscription Models)
  - "Statistics" split into API Usage and Subscription Usage areas

+ **Smart Menu Bar**
  - Shows "🤖 ¥xxx" when API has daily usage
  - Shows "⚠️ Codex xx%" when subscription is near limit
  - Shows "AI ✓" for normal idle state

### Fixed
- All SwiftUI `onChange(of:)` deprecation warnings (macOS 14+ API migration)
- Removed project-level cost display (projects are not cost units)

### Changed
- Dashboard title: "AI 成本" → "API Cost" (product positioning)
- Model Distribution renamed to "Model Usage" with API/Subscription split

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
