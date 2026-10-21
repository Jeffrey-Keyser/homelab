#!/usr/bin/env bash
# provider-auth-watch: alert (Telegram via NanoClaw) before agent-CLI auth
# silently stalls dev-inbox/Agency on forge.
#
# Checks, every run (timer: every 3h):
#   - liveness: a tiny non-interactive prompt per provider in $PROVIDERS
#     (claude uses CLAUDE_CODE_OAUTH_TOKEN with an empty config dir, so it
#     tests the long-lived setup-token, never the interactive refresh chain)
#   - claude setup-token expiry: days left from $CLAUDE_TOKEN_EXPIRES_FILE,
#     one alert per threshold (30/14/7/3/1 days)
#
# Alert policy (exception-only): a provider alerts after 2 consecutive failed
# runs, re-alerts at most once per 24h while still failing, and sends one
# "recovered" message when it passes again.
#
# Usage: provider-auth-watch.sh [--dry-run] [--test-alert]
set -uo pipefail

PROVIDERS="${PROVIDER_AUTH_WATCH_PROVIDERS:-claude codex}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/provider-auth-watch"
STATE="$STATE_DIR/state.json"
NANOCLAW_URL="${NANOCLAW_MESSAGES_URL:-http://127.0.0.1:3102/api/v1/messages}"
RECIPIENT="${PROVIDER_AUTH_WATCH_RECIPIENT:-tg:8340382755}"
CLAUDE_TOKEN_ENV_FILE="${CLAUDE_TOKEN_ENV_FILE:-$HOME/.config/environment.d/60-claude-oauth-token.conf}"
CLAUDE_TOKEN_EXPIRES_FILE="${CLAUDE_TOKEN_EXPIRES_FILE:-$HOME/.config/dev-inbox-secrets/claude-oauth-token.expires}"
FAILS_BEFORE_ALERT=2
REALERT_SECONDS=86400
EXPIRY_THRESHOLDS=(30 14 7 3 1)
HOST="$(hostname)"

DRY_RUN=0
TEST_ALERT=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --test-alert) TEST_ALERT=1 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.kimi-code/bin:/usr/local/bin:/usr/bin:/bin"
mkdir -p "$STATE_DIR"
[ -s "$STATE" ] || echo '{}' > "$STATE"
now=$(date +%s)

send() {
    local text="$1"
    if [ "$DRY_RUN" = 1 ]; then
        echo "[dry-run] would send: $text"
        return 0
    fi
    local body
    body=$(jq -nc --arg r "$RECIPIENT" --arg c "$text" '{recipient:$r, content:$c, template:"custom"}')
    if curl -sf --max-time 20 -X POST -H 'Content-Type: application/json' -d "$body" "$NANOCLAW_URL" >/dev/null; then
        echo "sent: ${text%%$'\n'*}"
    else
        echo "ALERT DELIVERY FAILED (nanoclaw $NANOCLAW_URL): $text" >&2
        return 1
    fi
}

state_get() { jq -r --arg k "$1" '.[$k] // empty' "$STATE"; }
state_set() {
    local tmp
    tmp=$(mktemp "$STATE_DIR/.state.XXXXXX")
    jq --arg k "$1" --argjson v "$2" '.[$k] = $v' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
}

if [ "$TEST_ALERT" = 1 ]; then
    send "🔔 provider-auth-watch test from $HOST — alert path works."
    exit $?
fi

# Units get the token from the user manager; an ssh shell may not have it.
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -r "$CLAUDE_TOKEN_ENV_FILE" ]; then
    CLAUDE_CODE_OAUTH_TOKEN=$(sed -n 's/^CLAUDE_CODE_OAUTH_TOKEN=//p' "$CLAUDE_TOKEN_ENV_FILE" | tail -1)
    export CLAUDE_CODE_OAUTH_TOKEN
fi

probe() {
    local provider="$1" out rc
    local work
    work=$(mktemp -d)
    case "$provider" in
        claude)
            if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
                echo "CLAUDE_CODE_OAUTH_TOKEN is not set"
                rm -rf "$work"
                return 1
            fi
            out=$(cd "$work" && CLAUDE_CONFIG_DIR="$work" timeout 180 claude -p "Reply with exactly: ok" \
                --model claude-haiku-4-5-20251001 --output-format text </dev/null 2>&1)
            rc=$?
            ;;
        codex)
            out=$(cd "$work" && timeout 180 codex exec --skip-git-repo-check "Reply with exactly: ok" </dev/null 2>&1)
            rc=$?
            ;;
        kimi)
            out=$(cd "$work" && timeout 180 kimi -p "Reply with exactly: ok" </dev/null 2>&1)
            rc=$?
            if [ $rc -eq 0 ] && grep -q "startup failed\|api_error" <<<"$out"; then rc=1; fi
            ;;
        *)
            out="unknown provider $provider"
            rc=2
            ;;
    esac
    rm -rf "$work"
    # claude can exit 0 while printing "Not logged in".
    if [ $rc -eq 0 ] && grep -qiE 'not logged in|failed to authenticate|please run /login|oauth (session|token) (expired|revoked)' <<<"$out"; then
        rc=1
    fi
    if [ $rc -eq 0 ] && ! grep -qi '\bok\b' <<<"$out"; then
        rc=1
    fi
    printf '%s' "$out" | tail -c 400
    return $rc
}

classify() {
    if grep -qiE 'login|authenticat|401|403|expired|revoked|unauthori|subscription|credential' <<<"$1"; then
        echo "auth"
    elif grep -qiE 'rate.?limit|429|quota|usage limit|overloaded' <<<"$1"; then
        echo "quota"
    else
        echo "probe-failed"
    fi
}

overall=0
for provider in $PROVIDERS; do
    key="probe:$provider"
    prev=$(jq -c --arg k "$key" '.[$k] // {}' "$STATE")
    fails=$(jq -r '.fails // 0' <<<"$prev")
    last_alert=$(jq -r '.lastAlert // 0' <<<"$prev")
    alerted=$(jq -r '.alerted // false' <<<"$prev")

    if detail=$(probe "$provider"); then
        echo "$provider: ok"
        if [ "$alerted" = true ]; then
            send "✅ $provider auth recovered on $HOST (was failing for $fails check(s))." || overall=1
        fi
        state_set "$key" "$(jq -nc --argjson t "$now" '{fails:0, alerted:false, lastOk:$t, lastAlert:0}')"
        continue
    fi

    fails=$((fails + 1))
    kind=$(classify "$detail")
    echo "$provider: FAIL #$fails ($kind): $(tr '\n' ' ' <<<"$detail" | tail -c 200)"
    if [ "$fails" -ge "$FAILS_BEFORE_ALERT" ] && [ $((now - last_alert)) -ge "$REALERT_SECONDS" ]; then
        hint=""
        case "$provider:$kind" in
            claude:auth) hint=$'\nFix: on forge run `claude setup-token`, then update ~/.config/environment.d/60-claude-oauth-token.conf + `systemctl --user set-environment` and restart the dev-inbox/agency units.' ;;
            codex:auth) hint=$'\nFix: on forge run `codex login` (or set OPENAI_API_KEY for the units).' ;;
        esac
        msg="⚠️ $provider auth check failing on $HOST ($kind, $fails consecutive checks, every 3h). dev-inbox/Agency roles on $provider will stall.
Last output: $(tr '\n' ' ' <<<"$detail" | tail -c 300)$hint"
        if send "$msg"; then
            last_alert=$now
            alerted=true
        else
            overall=1
        fi
    fi
    state_set "$key" "$(jq -nc --argjson f "$fails" --argjson a "$last_alert" --argjson al "$alerted" \
        --arg k "$kind" '{fails:$f, lastAlert:$a, alerted:$al, kind:$k}')"
done

# Claude setup-token expiry countdown.
if [ -r "$CLAUDE_TOKEN_EXPIRES_FILE" ]; then
    expires=$(head -1 "$CLAUDE_TOKEN_EXPIRES_FILE")
    if exp_s=$(date -d "$expires" +%s 2>/dev/null); then
        days=$(( (exp_s - now) / 86400 ))
        echo "claude setup-token: $days day(s) left (expires $expires)"
        # Tightest threshold already crossed; alert once per threshold.
        crossed=""
        for t in "${EXPIRY_THRESHOLDS[@]}"; do
            [ "$days" -le "$t" ] && crossed=$t
        done
        sent_at=$(state_get "expiry:claude:threshold")
        if [ -n "$crossed" ] && { [ -z "$sent_at" ] || [ "$sent_at" -gt "$crossed" ]; }; then
            if send "⏳ Claude setup-token on $HOST expires in $days day(s) ($expires). Renew: \`claude setup-token\` on forge, update ~/.config/environment.d/60-claude-oauth-token.conf + $CLAUDE_TOKEN_EXPIRES_FILE, \`systemctl --user set-environment\`, restart dev-inbox/agency units."; then
                state_set "expiry:claude:threshold" "$crossed"
            else
                overall=1
            fi
        fi
    else
        echo "unparseable expiry date in $CLAUDE_TOKEN_EXPIRES_FILE: $expires" >&2
    fi
fi

exit $overall
