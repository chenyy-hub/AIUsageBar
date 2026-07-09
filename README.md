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

**AIUsageBar** provides a unified, local-first observability platform that lives in your macOS menu bar. It aggregates usage data from all your AI agents into a single dashboard, giving you real-time visibility into token consumption, API costs, and subscription quotas.

### Why AIUsageBar?

- **Unified view**: All AI agent usage in one place
- **Cost control**: Track spending across providers and models
- **Privacy-first**: Everything stays on your machine
- **Extensible**: Plugin architecture for future AI agents

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

The menu bar icon dynamically shows:

- **AI 🤖** — when subscription-based agents are active
- **¥12.50** — API cost for today
- **443M** — subscription token usage

Click to open the full dashboard with tabbed views for Dashboard, Provider management, Pricing editor, and Budget tracking.

### 🔒 Privacy First

All data stays on your machine:

- **No telemetry**, no cloud upload, no tracking
- API keys stored securely in **macOS Keychain** (never in SQLite)
- Local SQLite database with WAL mode
- Source code is fully auditable

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    AI UsageBar.app                        │
│               SwiftUI · MenuBarExtra                      │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │Dashboard │  │Provider  │  │Pricing   │  │Budget    │ │
│  │   View   │  │ Manager  │  │ Manager  │  │ Manager  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│       │             │             │             │        │
│  ┌────┴─────────────┴─────────────┴─────────────┴────┐   │
│  │                DatabaseService                     │   │
│  │            (SQLite3 · Keychain)                    │   │
│  └─────────────────────┬─────────────────────────────┘   │
└────────────────────────┼────────────────────────────────┘
                         │
┌────────────────────────┼────────────────────────────────┐
│   ai-cost-monitor      │        (Python Backend)         │
│   ┌────────────────────┴─────┐                           │
│   │    Scanner Dispatcher    │                           │
│   │  ┌────────┐ ┌─────────┐  │                           │
│   │  │ Claude  │ │  Codex  │  │                           │
│   │  │  JSONL  │ │  SQLite │  │                           │
│   │  └────────┘ └─────────┘  │                           │
│   └──────────────────────────┘                           │
└──────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Python scanners** read Claude Code JSONL logs (`~/.claude/projects/`) and Codex SQLite databases (`~/.codex/state_*.sqlite`)
2. **Usage records** are normalized and stored in local SQLite (`api_usage_records` + `quota_usage_records`)
3. **Cost engine** calculates costs using configurable three-tier pricing
4. **SwiftUI app** reads the database via `DatabaseService` and renders the dashboard

### Tech Stack

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
      <td><img src="docs/images/budget.png" alt="Budget" width="320"></td>
    </tr>
    <tr>
      <td align="center"><em>Dashboard & Agent Usage</em></td>
      <td align="center"><em>Budget & Trend View</em></td>
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
- [ ] Budget forecasting with anomaly detection
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
