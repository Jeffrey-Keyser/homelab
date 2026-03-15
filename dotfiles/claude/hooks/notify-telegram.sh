#!/bin/bash
# Claude Code hook: Send Telegram notification via NanoClaw IPC
# Usage: echo '{"hook_event_name":"..."}' | notify-telegram.sh [message_override]

IPC_PATH="/home/jkeyser/nanoclaw/data/ipc"
GROUP="milo"
CHAT_JID="tg:8340382755"

MESSAGES_DIR="${IPC_PATH}/${GROUP}/messages"
mkdir -p "$MESSAGES_DIR"

# Read hook input from stdin
INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"')

# Build message based on event type
case "$EVENT" in
  Notification)
    TYPE=$(echo "$INPUT" | jq -r '.type // "unknown"')
    case "$TYPE" in
      permission_prompt)
        MSG="Claude Code needs permission approval"
        ;;
      idle_prompt)
        MSG="Claude Code is waiting for your input"
        ;;
      *)
        MSG="Claude Code needs your attention"
        ;;
    esac
    ;;
  Stop)
    MSG="Claude Code finished its response"
    ;;
  TaskCompleted)
    MSG="Claude Code task completed"
    ;;
  *)
    MSG="Claude Code event: ${EVENT}"
    ;;
esac

# Allow message override via argument
[ -n "$1" ] && MSG="$1"

# Write IPC message file for NanoClaw (direct send, no container agent)
FILENAME="$(date +%s%3N)-$(head -c 4 /dev/urandom | xxd -p).json"

cat > "${MESSAGES_DIR}/${FILENAME}" <<EOF
{
  "type": "message",
  "chatJid": "${CHAT_JID}",
  "text": "🖥️ ${MSG}"
}
EOF

exit 0
