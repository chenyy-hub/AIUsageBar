# Changelog

All notable changes to AIUsageBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.2.0] — 2026-07-10

### Added

- Claude Code JSONL usage pipeline with local SQLite analysis.
- Scanner status diagnostics and timezone-safe status decoding.
- Budget balance persistence and remaining-balance calculation.
- Codex quota state machine: `normal`, `warning`, `critical`, `limitReached`, and `reset`.
- Provider-oriented MenuBar state for Claude cost and Codex 5-hour remaining time.

### Changed

- MenuBar refreshes now use the shared `UsageRepository` read path.
- MenuBar presentation is separated into provider status aggregation and a display view model.

### Fixed

- Scanner status JSON decoding for snake_case keys.
- MenuBar activity timestamps now select the newest transcript, usage record, or database timestamp.

## [2.0.0] — 2026-07-09

### Added

+ **Active Agent Detection (`ActiveAgentService`)**
  - Detects Codex, Claude Code, and DeepSeek by file mtime and DB records
  - 5-minute detection window for recent activity
  - Priority-based fallback when multiple agents are active

+ **Dynamic MenuBar State**
  - `◉ Codex 68%` — Codex active, shows quota used
  - `✨ Claude ¥3.2` — Claude Code active, shows today's cost
  - `🤖 DeepSeek ¥1.5` — DeepSeek active, shows today's cost
  - `AI ✓` — idle state with no active agent
  - Automatic switching based on ActiveAgentService

+ **Codex Quota Reset Monitor (`CodexQuotaMonitor`)**
  - 60-second periodic rate limit checks
  - Detects 5-hour window refresh (remaining low → high)
  - macOS notification on reset
  - MenuBar blink animation on detection

+ **Notification System (`NotificationService`)**
  - `quotaReset` — Codex 5-hour window refreshed
  - `quotaWarning` — Codex quota ≥ 80%
  - `apiCostWarning` — Today's cost exceeds threshold
  - macOS native UserNotifications with optional sound

+ **OpenUsage-style MenuBar Dropdown**
  - Clean, minimal layout with status grid
  - Active Agent, Today Cost, Month Cost, Codex Quota
  - Color-coded accent by active agent type

+ **Full zh-CN Localization**
  - Dashboard: "今日消费", "本月消费", "累计"
  - DataHealthView: "数据库", "扫描器", "记录"
  - Status labels, warnings, timestamps in Chinese
  - All new strings in `Localization.swift`

### Changed
- MenuBar label: static → dynamic agent-aware
- Dashboard cost display: single ambiguous → Today/Month/Total
- `MenuBarStatusService`: rewritten for agent-aware status
- `UsageService`: integrated 3 new services
- `MenuBarContentView`: redesigned OpenUsage-style layout
- `DataHealthView`: fully Chinese localized

### Fixed
- Time dimension confusion: MenuBar now shows only Today Cost
- Notification permission: requested on launch for quota events
- Build: 0 errors, 0 new warnings

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
