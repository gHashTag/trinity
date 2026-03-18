---
sidebar_position: 22
sidebar_label: Notify
---

# tri notify — Telegram Notifications

Send notifications to Telegram chats. Used by agents, hooks, and manual alerts.

## Usage

```bash
tri notify "<message>"
```

## Flags

| Flag | Description |
|------|-------------|
| `"<message>"` | Message text to send |
| `--chat <id>` | Target chat ID (overrides default) |
| `--pin` | Pin the message after sending |
| `--edit <msg_id>` | Edit an existing message instead of sending new |

## Examples

```bash
tri notify "Build complete"                    # Simple notification
tri notify "Deploy done" --pin                 # Send and pin
tri notify "Updated status" --edit 12345       # Edit existing message
tri notify "Alert" --chat -1001234567890       # Send to specific chat
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Yes | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID` | Yes | Default target chat ID |

## Handler

**File:** `src/tri/tri_commands.zig:393`
