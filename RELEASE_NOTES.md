# AIUsageBar v1.0.0

**Release Date**: 2026-07-09

## Overview

AIUsageBar is a native macOS menu bar application that monitors AI coding agent usage, token consumption, API costs, and subscription quotas — all locally on your machine.

This is the first stable open-source release after extensive internal development across 5 major iterations.

## Highlights

- **Claude Code monitoring**: Parse JSONL logs for token and cost tracking
- **Codex monitoring**: Read SQLite database for subscription usage
- **DeepSeek cost accuracy**: Three-tier pricing model (cache hit / miss / output)
- **macOS MenuBar application**: Native SwiftUI MenuBarExtra, no Dock icon
- **Local analytics**: All data in SQLite, no telemetry or cloud upload
- **Privacy-first**: API keys in macOS Keychain, never in files or database

## Installation

```bash
# Download AIUsageBar.app from Releases
open AIUsageBar.app

# Or build from source
git clone https://github.com/YOUR_USER/AIUsageBar.git
cd AIUsageBar
bash Scripts/build_release.sh --install
```

## What's Included

- `AIUsageBar.app` — 2.1 MB, signed (ad-hoc), macOS 14+
- `build_release.sh` — Release build script
- `install_launch_agent.sh` — Auto-start on login
- `sign_app.sh` — Code signing (Developer ID / Ad-hoc)
- Python scanner plugins for Claude Code and Codex

## Release Artifacts

| Asset | Description |
|-------|-------------|
| `AIUsageBar.app` | macOS application bundle |
| `Source code` | Full source (Swift + Python) |
| `Documentation` | README, CHANGELOG, Security Audit |

## Known Issues

- Ad-hoc signing: Gatekeeper may block on first launch (right-click → Open to bypass)
- Screenshots not included (requires Screen Recording permission)
- Codex quota tracking uses estimated values

## Acknowledgments

Inspired by OpenUsage and the modern AI developer tooling ecosystem.
Built with SwiftUI, SQLite, and macOS Keychain services.
