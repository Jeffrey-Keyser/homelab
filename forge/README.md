# forge — the dev host (second Beelink ME Mini N150)

Since 2026-10-18 the homelab is two identical Beelinks:

| Host | Role | LAN | Tailscale |
|------|------|-----|-----------|
| `beelink` (prod) | PostgreSQL 17, RabbitMQ, Solo Vault, Pay, all user-facing apps, cloudflared ingress, beelink-deploy webhook, netdata, nanoclaw | 192.168.1.226 (wired) | 100.99.136.81 |
| `forge` (dev) | dev-inbox (work-queue, plan-supervise, issue-*, relay, runstream, clipboard), **agency-hq** (:3040), all agent CLIs, worktrees, go/npm test suites | 192.168.1.175 (Wi-Fi `wlo1`) | 100.108.178.13 |

Why: dev-inbox `go test` stacks and agent CLIs drove prod to load 14–22 with 3 GB of swap in use and
starved the services. The only path from forge to prod is `git push` → GitHub → beelink-deploy.

## How the two talk

- **forge → prod services:** explicit env where the code supports it (`~/agency-hq/.env`,
  `~/.config/dev-inbox-*.env`, `~/.config/environment.d/50-forge-prod-endpoints.conf`) pointing at
  `100.99.136.81:<port>`, **plus** `systemd/prod-loopback-bridge.service`: one SSH session to prod
  forwarding every prod app port onto forge's `127.0.0.1`. That makes `localhost:<port>` fallbacks and
  bare literals in code work unchanged, and reaches prod loopback-only services (nanoclaw 3100–3102).
  - Add a port when a new service lands on prod. **Remove a port when a service moves to forge**
    (`ExitOnForwardFailure` refuses to start otherwise). Then `systemctl --user daemon-reload && systemctl --user restart prod-loopback-bridge`.
- **prod → forge:** cloudflared `agency.jeffreykeyser.net → http://100.108.178.13:3040`;
  `struct.service.d/agency-forge.conf` sets `AGENCY_HQ_URL`; beelink-deploy's live `repos.json` entry
  for agency-hq is path mode → `deploy-proxy/deploy.sh` (lives at prod `~/agency-hq-deploy-proxy`, a
  tiny git repo) which runs `bin/agency-hq-remote-deploy.sh` on forge over SSH (the immutable-worktree
  dance: fetch, `git worktree add ~/releases/agency-hq/<sha>`, run the release's `deploy.sh`).
- **Wakes and Telegram, both directions:**
  - dev-inbox hardcodes `127.0.0.1:3099/plan-manager/wake/<id>` and the bridge's wake handler must run on
    the host that owns `~/dev-inbox` (it writes `plans/<id>/wake-inbox/` and runs `scripts/plan-manager.sh`).
    So forge runs `systemd/plan-manager-shim.service` (`bin/plan-manager-shim.js`) on `127.0.0.1:3099`: it
    mounts openclaw-bridge's own `handlers/plan-manager` module and reverse-proxies every other path to the
    real bridge on prod (Telegram notify, `/decisions/notify`, `/live-orchestration`). Needs `~/openclaw-bridge`
    cloned + `npm ci`. Port 3099 is therefore **not** in the loopback bridge list.
  - prod-side callers that assume agency-hq is local (nanoclaw's Telegram vote handler → `localhost:3040`,
    nanoclaw container skill → `host.docker.internal:3040`) go through `prod-side/agency-hq-forge-proxy.service`
    on prod: `socat 0.0.0.0:3040 → forge:3040`. Install it on prod as a user unit. Forge's loopback bridge must
    keep 3040 excluded or traffic loops.
  - Telegram bot for Accept cards (agency bot) hits `agency.jeffreykeyser.net/api/v1/webhook/telegram` → forge.
- cloudflared does **not** hot-reload ingress rules; `scripts/update-cloudflared.sh` restarts it (~5 s blip).

## Env file: `~/.config/environment.d/50-forge-prod-endpoints.conf`

```
AGENCY_HQ_URL=http://localhost:3040          # agency-hq runs on forge
AGENCY_HQ_BASE_URL=http://100.99.136.81:3012
SOLO_VAULT_URL=http://100.99.136.81:3015
OPENCLAW_BRIDGE_URL=http://100.99.136.81:3099
PLAN_MANAGER_WEBHOOK_BASE=http://100.99.136.81:3099
BEELINK_PROD_HOST=100.99.136.81
BEELINK_DEPLOY_CONFIG=/home/jkeyser/.config/dev-inbox/beelink-deploy-repos.forge.json   # localhost→prod copy of beelink-deploy/config/repos.json
```

## Parity checklist (each item cost a debugging round on 2026-10-17/18)

1. `kernel.apparmor_restrict_unprivileged_userns=0` (`sysctl.d/99-codex-userns.conf`) or bwrap fails
   `setting up uid map: Permission denied` → dev-inbox `sandbox-wrapper-setup-failure`, exit 96,
   queue-manager episodes fail every 5 min. Also `apt install bubblewrap expect`.
2. Ubuntu's `.bashrc` returns early for non-interactive shells. PATH/env exports appended at the bottom are
   invisible to `bash -lc`, ssh commands and scripts. Put them in lines 1–3.
3. sshd drop-ins apply alphabetically; `90-forge.conf` loses to cloud-init's `50-cloud-init.conf`
   (`PasswordAuthentication yes`). Use `00-forge.conf`.
4. dev-inbox's release store is `~/.local/share/dev-inbox/releases/` (~9 GB), not `~/dev-inbox/releases/`.
   Unit drop-ins under `~/.config/systemd/user/dev-inbox-*.service.d/` (~470 files) are live operator
   state, not in the repo, and reference many releases via `EnvironmentFile=`. Copy both.
5. `systemd/*.service` in dev-inbox are templates (`@DEV_INBOX_DIR@`); render them (install script does).
6. Repos with local-only remotes are skipped by a "clone from GitHub" pass: `~/ClaudeIssueTriager`,
   `~/dev-inbox-observability-canary` (+ `*-remote.git`), `~/wt/release-main`. Canary matrix needs them.
7. `rsync --exclude='bin/'` also skips `releases/*/bin`. Anchor as `/bin/`.
8. agency-hq falls back to `localhost:<port>` for Pay (3017), cron (3016), feedback-registry (3025), logos
   (3070), ai-proxy (3005), struct (3032), nanoclaw status (3101) when env is unset → Pay login 503.
   Set them, and run the loopback bridge.
9. **Copy `~/.gitconfig`** (user.name/email + gh credential helper). Without it the agency design-review
   agent's commit fails `Author identity unknown` → `Agent invocation failed: exit code 128`, and the failed
   intent blocks its replay lane so later Telegram accepts sit at 0 attempts.
10. Prod-only apt packages that matter for dev: bubblewrap expect sqlite3 shellcheck cmake pkg-config pipx
   ffmpeg xvfb rclone postgresql-client google-chrome-stable.

## Rollback (either service back to prod)

dev-inbox: on forge `systemctl --user disable --now` the 15 units, rsync `~/dev-inbox/{results,plans,queue,data}`
+ `~/.local/share/dev-inbox` + `~/.local/state/dev-inbox*` back, on prod `enable --now`.
agency-hq: prod's unit file was removed by `disable` (it was linked); restore it from forge
`~/.config/systemd/user/agency-hq.service`, revert the cloudflared line, struct drop-in and the
beelink-deploy `repos.json` entry (`.bak.pre-forge-agency.*` copies sit next to each live file).

## Not moved

`~/.worktrees` (10 GB), `~/dev-inbox-worktrees`, `~/dev-inbox/.claude/worktrees` (11 GB transcripts),
`beelink-steward` (samples the prod host), the nightly agency DB backup cron (dumps via the Postgres container).
Forge has no backup job yet.
