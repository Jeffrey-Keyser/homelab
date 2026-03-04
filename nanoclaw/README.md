# NanoClaw Installation

NanoClaw is installed alongside OpenClaw on the Beelink homelab.

## Installation Details

- **Source**: https://github.com/qwibitai/nanoclaw
- **Location**: `/home/jkeyser/nanoclaw/`
- **Trigger word**: `@NanoMilo`
- **Port**: None (does not use a network port — OpenClaw gateway stays on 18789)
- **Container image**: `nanoclaw-agent:latest` (Docker)
- **SQLite database**: `/home/jkeyser/nanoclaw/store/messages.db`

## Systemd Service

The service unit is installed at `~/.config/systemd/user/nanoclaw.service` and enabled as a user service.

```bash
# Status
systemctl --user status nanoclaw

# Restart
systemctl --user restart nanoclaw

# Logs
tail -f /home/jkeyser/nanoclaw/logs/nanoclaw.log
tail -f /home/jkeyser/nanoclaw/logs/nanoclaw.error.log
```

## Configuration

Configuration lives in `/home/jkeyser/nanoclaw/.env`:

- `ANTHROPIC_API_KEY` — shared with OpenClaw
- `ASSISTANT_NAME=NanoMilo` — trigger word prefix
- `TELEGRAM_BOT_TOKEN` — placeholder; requires manual BotFather step (see below)

## MANUAL STEP REQUIRED: Telegram Bot Token

NanoClaw currently starts in **headless mode** (scheduled tasks and IPC only) because the Telegram bot token is a placeholder. To enable Telegram messaging:

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` and follow prompts:
   - Bot name: `NanoMilo Assistant`
   - Bot username: must end in `bot` (e.g., `nanomilo_bot`)
3. Copy the bot token (format: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)
4. Edit `/home/jkeyser/nanoclaw/.env`:
   ```
   TELEGRAM_BOT_TOKEN=<paste-token-here>
   ```
5. Sync to container environment:
   ```bash
   mkdir -p /home/jkeyser/nanoclaw/data/env && cp /home/jkeyser/nanoclaw/.env /home/jkeyser/nanoclaw/data/env/env
   ```
6. Restart:
   ```bash
   systemctl --user restart nanoclaw
   ```
7. Optional — disable group privacy for group chats:
   - `@BotFather` → `/mybots` → select bot → **Bot Settings** → **Group Privacy** → **Turn off**

After restarting, send `/chatid` to the bot in Telegram to get the chat ID for registration.

## Channels

Installed channels:
- **Telegram** (via `add-telegram` skill) — requires `TELEGRAM_BOT_TOKEN`

## Relationship to OpenClaw

NanoClaw and OpenClaw coexist independently:
- OpenClaw gateway: port `18789` (unchanged)
- NanoClaw: no network port, uses SQLite (not PostgreSQL)
- No shared configuration, databases, or services
