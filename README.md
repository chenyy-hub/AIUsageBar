<div align="center">
  <img src="docs/images/menubar.png" alt="AIUsageBar" width="600">
  <h1>AIUsageBar</h1>
  <p>
    <strong>Local-first AI Agent Usage Observability Platform for macOS</strong>
  </p>
  <p>
    <a href="#features">Features</a> •
    <a href="#architecture">Architecture</a> •
    <a href="#installation">Installation</a> •
    <a href="#development">Development</a> •
    <a href="#roadmap">Roadmap</a>
  </p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS">
    <img src="https://img.shields.io/badge/Swift-5.9%2B-orange" alt="Swift">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  </p>
</div>

---

## Overview

Modern AI coding workflows involve multiple agents — Claude Code, Codex, DeepSeek, OpenAI, Anthropic — each with their own usage tracking, token consumption, and cost structures scattered across different platforms.

**AIUsageBar** is a native macOS menu bar application for AI Agent Usage Observability — API cost tracking, model analytics, and subscription quota monitoring.

AIUsageBar is a local AI Agent usage monitoring platform for macOS. It supports Claude Code, Codex CLI, DeepSeek API, and OpenAI-compatible APIs while keeping usage data on the local machine.

### Core Capabilities

1. Token usage statistics
2. API cost analysis
3. Agent activity monitoring
4. Codex quota monitoring
5. Budget management
6. Local SQLite usage analysis

### Pipeline Architecture

```text
Claude Code
    |
    v
JSONL Transcript
    |
    v
Python Scanner
    |
    v
SQLite
    |
    v
SwiftUI AIUsageBar
```

### Why AIUsageBar?

- **API Cost Tracking** — Real-time API cost monitoring, three-tier pricing model (cache hit / miss / output).
- **Subscription Monitoring** — Track Codex Plus session and weekly usage, with progress bars and reset timers.
- **Local Privacy-first Storage** — All data in SQLite. API keys in macOS Keychain. No telemetry, no cloud upload.
- **Multi Agent Dashboard** — Unified view of Claude Code, Codex, DeepSeek, OpenAI, Anthropic, and OpenRouter.

---

## Features

### 🤖 AI Agent Monitoring

| Agent | Type | Status |
|-------|------|--------|
| **Claude Code** | API Cost (JSONL parsing) | ✅ |
| **Codex** | Subscription (SQLite) | ✅ |
| OpenClaw | API / Local | 🚧 Planned |
| Cursor | TBD | 🚧 Planned |
| Gemini CLI | TBD | 🚧 Planned |

### 📊 Cost Analytics

Multi-provider, multi-model cost tracking with configurable pricing:

```
cost = cache_hit_tokens × hit_price
     + cache_miss_tokens × miss_price
     + output_tokens × output_price
```

- **DeepSeek** (V4 Pro / Flash) — fully tested
- **OpenAI** (GPT-4o, o-series) — adapter ready
- **Anthropic** (Claude) — adapter ready
- **OpenRouter** — adapter ready

### 🖥️ Menu Bar Experience

The menu bar icon dynamically shows based on current status:

- **🤖 ¥12.50** — API cost when there's daily usage today
- **⚠️ Codex 90%** — warning when Codex subscription is near limit
- **AI ✓** — normal idle state with no active usage

Click to open the full dashboard with tabbed views for Dashboard, Provider management, Pricing editor, and Data Health.

### 📱 Dashboard Views

| View | Description |
|------|-------------|
| **API Cost** | Real-time API spending — today, monthly, and total cost |
| **Codex Plus** | Session and weekly usage with progress bars and reset timer |
| **Model Usage** | API Models (with cost) and Subscription Models (tokens only) |
| **Agent Status** | Connection status for each AI agent |
| **Statistics** | API Usage and Subscription Usage split into separate areas |

### 🧪 Demo Mode

Run without a real database to see the full UI:

```bash
.build/debug/AIUsageBar --demo
```

This loads sample data from `Resources/demo/demo_usage.db` with pre-populated API and subscription records.

### 🔒 Privacy First

All data stays on your machine:

- **No telemetry**, no cloud upload, no tracking
- API keys stored securely in **macOS Keychain** (never in SQLite)
- Local SQLite database with WAL mode
- Source code is fully auditable

---

## Demo Mode

AIUsageBar can run in demo mode without any real AI agent data:

```bash
# Build and run with demo data
swift build --configuration debug
.build/debug/AIUsageBar --demo
```

This loads a pre-populated SQLite database from `Resources/demo/demo_usage.db` containing:
- **20 API records** — simulated Claude Code + DeepSeek usage with realistic token counts and costs
- **5 Quota records** — simulated Codex Plus subscription data with session and weekly usage

Demo mode is useful for:
- Evaluating the UI before setting up real data sources
- Development and testing
- Taking screenshots for documentation

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    AIUsageBar.app                        │
│               SwiftUI · MenuBarExtra                      │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │Dashboard │  │Provider  │  │Pricing   │ │
│  │   View   │  │ Manager  │  │ Manager  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│       │             │             │        │
│  ┌────┴─────────────┴─────────────┴────┐   │
│  │              DatabaseService                       │   │
│  │   (READONLY · SQLite3 · Keychain · WAL mode)      │   │
│  └─────────────────────┬─────────────────────────────┘   │
└────────────────────────┼────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ API Cost     │  │ Subscription │  │ Management   │
│ Records      │  │ Records      │  │ Tables       │
│ (api_usage)  │  │ (quota_usage)│  │ (profiles,   │
│              │  │              │  │  providers,  │
│ Claude Code  │  │ Codex Plus   │  │  pricing)    │
│ DeepSeek API │  │ gpt-5.5      │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
        ▲                ▲
        │                │
┌───────┴───────┐  ┌────┴───────┐
│ ClaudeScanner │  │CodexScanner│
│ (JSONL)       │  │(SQLite)    │
└───────────────┘  └────────────┘
        │                │
  ┌─────┴─────────────────┴─────┐
  │   Python Scanner Backend   │
  └────────────────────────────┘
```

### Data Flow

1. **Python scanners** read Claude Code JSONL logs (`~/.claude/projects/`) and Codex SQLite databases (`~/.codex/state_*.sqlite`)
2. **Usage records** are normalized and stored in local SQLite (`api_usage_records` + `quota_usage_records`)
3. **Cost engine** calculates costs using configurable three-tier pricing
4. **SwiftUI app** reads the database via `DatabaseService` and renders the dashboard

### Release Guide

```bash
# 1. Update version
# Edit Resources/Info.plist: CFBundleShortVersionString and CFBundleVersion

# 2. Build release
bash Scripts/build_release.sh

# 3. Sign (if Developer ID available)
bash Scripts/sign_app.sh

# 4. Test
open build/release/AIUsageBar.app

# 5. Tag and push
git tag -a v1.1.0 -m "AIUsageBar v1.1.0"
git push origin v1.1.0

# 6. Create GitHub Release
# Upload build/release/AIUsageBar.app.zip
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | SwiftUI 5, MenuBarExtra, SQLite3 C API |
| **Auth** | macOS Keychain (Security framework) |
| **Backend** | Python 3, Scanner Plugin System |
| **Database** | SQLite 3 (WAL mode, 10 tables) |
| **Minimum OS** | macOS 14.0 (Sonoma+) |

---

## Screenshots

<div align="center">
  <table>
    <tr>
      <td><img src="docs/images/dashboard.png" alt="Dashboard" width="320"></td>
    </tr>
    <tr>
      <td align="center"><em>Dashboard & Agent Usage</em></td>
    </tr>
  </table>
</div>

> **Note**: Screenshots require Screen Recording permission for `screencapture` (macOS 14+).
> See `docs/images/README.md` for capture instructions.

---

## Installation

### Prerequisites

- macOS 14.0+
- Xcode 16+ or Swift 6.0+ CLI tools
- Python 3.10+ (for scanner plugins)

### Quick Install

```bash
# Download the latest AIUsageBar.app from Releases
# Or build from source:

git clone https://github.com/YOUR_USER/AIUsageBar.git
cd AIUsageBar
swift build --configuration release

# Create app bundle
mkdir -p build/release/AIUsageBar.app/Contents/{MacOS,Resources}
cp .build/release/AIUsageBar build/release/AIUsageBar.app/Contents/MacOS/
cp Resources/Info.plist build/release/AIUsageBar.app/Contents/Info.plist
cp Resources/AppIcon.icns build/release/AIUsageBar.app/Contents/Resources/

# Run
open build/release/AIUsageBar.app
```

### Install to /Applications

```bash
bash Scripts/build_release.sh --install
```

### Auto-start on Login

```bash
bash Scripts/install_launch_agent.sh
```

### First-time Setup

1. Open AIUsageBar from the menu bar
2. Navigate to **供应商** (Providers) tab
3. Click **+ 添加供应商** and enter your AI provider details
4. API keys are securely stored in macOS Keychain
5. Click **测试连接** to verify

---

## Development

```bash
# Build (debug)
swift build --configuration debug

# Run from terminal
.build/debug/AIUsageBar.app/Contents/MacOS/AIUsageBar

# Release build
bash Scripts/build_release.sh

# Code sign
bash Scripts/sign_app.sh

# Run scanner (populate database)
python3 -m scripts.monitor_daemon scan
```

### Project Structure

```
AIUsageBar/
├── Sources/
│   └── AIUsageBar/
│       ├── AIUsageBarApp.swift      # @main entry, MenuBarExtra
│       ├── Models/                  # Data structures
│       ├── Services/                # DB, Keychain, Adapters, Business logic
│       └── Views/                   # SwiftUI views (12 files)
├── Resources/                       # Info.plist, AppIcon.icns
├── Scripts/                         # Build, sign, launch agent scripts
├── docs/images/                     # Screenshots
├── Package.swift
├── CHANGELOG.md
├── SECURITY_AUDIT.md
├── LICENSE                          # MIT
└── README.md
```

### Backend (ai-cost-monitor)

The Python backend lives at:
```
~/.claude/skills/ai-cost-monitor/
```

Or the workspace location:
```
/Users/a1-6/workspace-agent-digital-employee/skills/ai-cost-monitor/
```

---

## Roadmap

### v1.1
- [ ] More AI agents (OpenClaw, Cursor, Gemini CLI)
- [ ] Advanced analytics & export
- [ ] Usage alerts & notifications
- [ ] Custom dashboard layouts

### v1.2
- [ ] Tauri/Electron cross-platform version (Windows support)
- [ ] Historical trend analysis with ML
- [ ] Team usage aggregation
- [ ] API for custom integrations

### Future
- [ ] Plugin marketplace for community scanners
- [ ] Multi-user support
- [ ] Cloud sync (optional, opt-in)

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

Inspired by [OpenUsage](https://github.com/) and the modern AI developer tooling ecosystem.

Built with:
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [SQLite](https://www.sqlite.org/)
- [macOS Keychain](https://developer.apple.com/documentation/security/keychain_services)
