# AIUsageBar v2.0.0 — AI Agent Status Bar

**Release Date**: 2026-07-09

## Overview

AIUsageBar v2.0 upgrades from a usage monitor to an **AI Agent Status Bar** — actively detecting which AI coding agent you're using and dynamically showing its status in the macOS menu bar.

## Highlights

### 1. Active Agent Detection
- New **ActiveAgentService** detects which agent (Codex / Claude Code / DeepSeek) is currently active
- Checks file modification times and recent database records
- Automatically switches MenuBar display

### 2. Dynamic MenuBar State
Replaces the previous static "AI ✓ / 🤖 AI" with agent-aware display:

| State | Display |
|-------|---------|
| Normal (idle) | `AI ✓` |
| Codex active | `◉ Codex 68%` |
| Claude Code active | `✨ Claude ¥3.2` |
| DeepSeek active | `🤖 DeepSeek ¥1.5` |

### 3. Codex Quota Reset Monitor
- **CodexQuotaMonitor** checks Codex rate limits every 60 seconds
- Detects 5-hour window refreshes (remaining goes from low → high)
- Triggers macOS notifications on reset
- MenuBar blinks briefly on reset detection

### 4. macOS Notification System
- **NotificationService** with three notification types:
  - `quotaReset` — Codex quota refresh detected
  - `quotaWarning` — Codex quota ≥ 80%
  - `apiCostWarning` — Today's cost exceeds threshold

### 5. Time Dimension Fix
- MenuBar now shows **Today Cost** only (not ambiguous total)
- Dashboard shows **今日消费** and **本月消费** side by side

### 6. OpenUsage-style MenuBar UI
- Clean, minimal dropdown with status grid
- Shows: Active Agent, Today Cost, Month Cost, Codex Quota
- Color-coded by active agent

### 7. Full zh-CN Localization
- All Dashboard text in Chinese
- DataHealthView fully localized
- Status labels, warnings, and timestamps in Chinese

## New Files

| File | Description |
|------|-------------|
| `Services/ActiveAgentService.swift` | Agent detection by file mtime + DB records |
| `Services/NotificationService.swift` | macOS UserNotifications (quota reset/warning) |
| `Services/CodexQuotaMonitor.swift` | 60s periodic quota monitoring |

## Modified Files

| File | Changes |
|------|---------|
| `Models.swift` | Added `ActiveAgent` / `ActiveAgentInfo` |
| `UsageService.swift` | Integrated ActiveAgentService, NotificationService, CodexQuotaMonitor |
| `MenuBarStatusService.swift` | Agent-aware label computation |
| `AIUsageBarApp.swift` | Dynamic MenuBar label, blink on quota reset |
| `MenuBarContentView.swift` | OpenUsage-style dropdown with status grid |
| `DashboardView.swift` | Chinese localization, Today/Month cost |
| `DataHealthView.swift` | Chinese localization |
| `Localization.swift` | Extended with 30+ new Chinese strings |

## Build

```bash
swift build --configuration debug
# 0 errors, 0 new warnings
```

## Upgrade Notes

- **No SQLite schema changes** — existing `ai_usage.db` works directly
- **No Tauri changes** — remains native SwiftUI
- **No Python backend changes** — scanner plugins unchanged
- `CodexQuotaMonitor` runs independently at 60s intervals
- macOS Sonoma 14+ required (MenuBarExtra API)
