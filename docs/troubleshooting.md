# Troubleshooting

## Claude Code JSONL not generated

### Causes

- `CLAUDE_CODE_SKIP_PROMPT_HISTORY` can prevent transcript history from being written.
- Closing a Claude Code session abnormally can skip normal transcript finalization.
- JSONL writes are buffered and may not be visible until the session flushes data.

### Resolution

- Remove the `CLAUDE_CODE_SKIP_PROMPT_HISTORY` configuration.
- Use `/exit` to close Claude Code sessions normally.
- Wait for the transcript flush, then confirm that a JSONL file exists under `~/.claude/projects/`.

---

## Scanner Offline

### Cause

The scanner status payload used Python `last_insert_count`, while Swift expected `lastInsertCount`. The snake_case and camelCase names did not decode to the same property.

### Resolution

Define explicit Swift `CodingKeys` for scanner-status decoding.

---

## App updated but UI did not change

### Cause

The binary produced from source can differ from the app installed in `/Applications`.

### Resolution

Verify that the release binary and installed binary are identical before testing:

```bash
md5 .build/release/AIUsageBar
md5 /Applications/AIUsageBar.app/Contents/MacOS/AIUsageBar
```

---

## MenuBar data did not refresh

### Previous architecture

The MenuBar maintained a separate cache, which could diverge from Dashboard data.

### Resolution

The current read path is shared:

```text
UsageRepository
    |
    v
UsageService
    |
    v
MenuBar
```

Provider display state is now aggregated before presentation, so the label and expanded view consume the same snapshot.

---

## Excessive Codex notifications

### Cause

Refreshing the quota without a state transition check can notify repeatedly.

### Resolution

`CodexQuotaState` persists state in `UserDefaults` and sends alerts only when entering a new state:

```text
normal
warning
critical
limitReached
reset
```

The alert manager also stores the last alert time and filters repeated notifications.
