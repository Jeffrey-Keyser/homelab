# Ecosystem Service Health Report

**Generated:** 2026-04-22T21:36Z
**Host:** beelink (Ubuntu Server 24.04 LTS)

## Summary

- **Total services checked:** 23
- **Running & healthy:** 20
- **Not running (missing deps):** 1 (music-store server)
- **No systemd unit / data-only project:** 1 (spanish-tutor)
- **Repo not found on disk:** 1 (travel-map — exists as `insta-travel-map`)

All critical ecosystem services are operational. Health endpoints return HTTP 200 across the board for running services.

## Service Status Matrix

| Service | Status | Systemd Unit | Port | Health Endpoint | Notes |
|---------|--------|-------------|------|-----------------|-------|
| pay | **active** | No unit file | 3017 | `GET /health` 200 | Running via process manager; healthy |
| prompt-registry | **active** | `prompt-registry.service` (enabled) | 3002 | `GET /health` 200 | Systemd-managed; running 6+ days |
| solo-vault | **active** | No unit file | 3015 | `GET /health` 200 | Running via process manager; healthy |
| ai-proxy | **active** | No unit file | 3005 | `GET /health` 200 | Running via process manager; healthy |
| ping | **active** | No unit file | 3020 (API), 3021 (client) | `GET /health` 200 | Running via process manager; healthy |
| life-journal | **active** | No unit file | 3026 (API), 3027 (client) | `GET /health` 200 | Repo on disk as `Life/`; running |
| image-studio | **active** | No unit file | 3030 (API), 3031 (client) | `GET /health` 200 | Running via process manager; healthy |
| pantry-manager | **active** | `pantry-manager.service` (enabled) | 3052 | `GET /health` 200 | Systemd-managed; running 6+ days; unit has `StartLimitIntervalSec` warning |
| music-store | **inactive** | No linked unit (`.service` file exists in repo) | 3022 (configured), 3023 (client only) | N/A | **Server not running** — missing `node_modules` (`pino` not found). Client running on 3023. Needs `npm install` in `server/` |
| flights | **active** | No unit file | 3081 (API), 3080 (client) | `GET /health` 200 | Running via process manager; healthy |
| feedback-registry | **active** | No unit file | 3025 | `GET /health` 200 | Running via process manager; healthy |
| nanoclaw | **active** | `nanoclaw.service` (enabled) | 3100 (credential-proxy), 3101 (skill-server), 3102 (message-api) | `GET /health` 200 (3100, 3101) | Systemd-managed; running 38 min; 3102 returns 404 on `/health` |
| agency-hq | **active** | `agency-hq.service` (enabled) | 3040 | `GET /health` 200 | Systemd-managed; running 4+ hrs; actively orchestrating tasks |
| cron-service | **active** | No linked unit (`.service` file exists in repo) | 3016 | `GET /health` 200 | Running via process manager; 30 scheduled jobs active |
| openclaw-bridge | **active** | `openclaw-bridge.service` (enabled) | 3099 | `GET /health` 200 | Systemd-managed; running 1+ day |
| beelink-deploy | **active** | No linked unit (`.service` file exists in repo) | 9000 (localhost only) | `GET /health` 200 | Webhook deploy service; running; binds to 127.0.0.1 only |
| travel-map | **active** | No unit file | 3009 (API), 3010 (client) | `GET /health` 200 | Repo on disk as `insta-travel-map/`; running |
| analytics-pulse | **active** | No unit file | 3018 (API), 3019 (client) | `GET /health` 200 | Running via process manager; healthy |
| jeffreykeyser-net | **active** | No unit file | 3003 (API), 3004 (client) | `GET /health` 200 | Running via process manager; healthy |
| qa-patrol | **active** | `qa-patrol.service` (enabled) | 3042 | `GET /health` 200 | Systemd-managed; running 2+ days; RabbitMQ connected |
| struct | **active** | No linked unit (`.service` file exists in repo) | 3032 | `GET /health` 200 | Running via process manager; healthy |
| nof1 | **active** | No unit file | 3060 (API), 3061 (client) | `GET /health` 200 | Running via process manager; healthy |
| spanish-tutor | **N/A** | No unit file | N/A | N/A | Data-only project (SQL schemas + Python tests); no server component |

## Systemd Unit Status

### Managed by systemd (user units)

| Service | Unit File | Enabled | Status |
|---------|-----------|---------|--------|
| prompt-registry | `~/.config/systemd/user/prompt-registry.service` | Yes | active (running) |
| pantry-manager | `~/.config/systemd/user/pantry-manager.service` | Yes | active (running) |
| nanoclaw | `~/.config/systemd/user/nanoclaw.service` | Yes | active (running) |
| agency-hq | `~/.config/systemd/user/agency-hq.service` (symlink) | Yes | active (running) |
| openclaw-bridge | `~/.config/systemd/user/openclaw-bridge.service` | Yes | active (running) |
| qa-patrol | `~/.config/systemd/user/qa-patrol.service` (symlink) | Yes | active (running) |

### Have unit files but not linked/installed

| Service | Unit File Location | Notes |
|---------|-------------------|-------|
| music-store | `/home/jkeyser/music-store/music-store.service` | Targets `multi-user.target`; needs adaptation for user-level systemd |
| cron-service | `/home/jkeyser/cron-service/cron-service.service` | Targets `multi-user.target`; currently running via other means |
| beelink-deploy | `/home/jkeyser/beelink-deploy/beelink-deploy.service` | Targets `multi-user.target`; currently running via other means |
| struct | `/home/jkeyser/struct/struct.service` | Targets `multi-user.target`; currently running via other means |

### No unit file (running via process manager)

pay, solo-vault, ai-proxy, ping, life-journal, image-studio, flights, feedback-registry, analytics-pulse, jeffreykeyser-net, nof1, travel-map

### No unit file (no server component)

spanish-tutor

## Items Requiring Attention

### 1. music-store server not running
- **Severity:** Medium
- **Issue:** Server process on port 3022 is down. `node dist/bin/www.js` fails with `ERR_MODULE_NOT_FOUND: Cannot find package 'pino'`
- **Fix:** Run `npm install` in `/home/jkeyser/music-store/server/` and restart
- **Impact:** Client (port 3023) is running but has no backend API

### 2. pantry-manager systemd unit warning
- **Severity:** Low
- **Issue:** `StartLimitIntervalSec` in `[Service]` section should be in `[Unit]` section
- **Fix:** Move `StartLimitIntervalSec=60` from `[Service]` to `[Unit]` in the unit file

### 3. nanoclaw message-api health endpoint
- **Severity:** Low
- **Issue:** Port 3102 (message-api) returns 404 on `/health` while credential-proxy (3100) and skill-server (3101) return 200
- **Fix:** Add `/health` endpoint to message-api, or this may be by design

### 4. Unlinked systemd unit files
- **Severity:** Low
- **Issue:** 4 services (music-store, cron-service, beelink-deploy, struct) have `.service` files in their repos but target `multi-user.target` instead of `default.target` and are not symlinked into `~/.config/systemd/user/`
- **Fix:** Adapt unit files for user-level systemd and symlink them

### 5. 12 services without systemd units
- **Severity:** Info
- **Issue:** pay, solo-vault, ai-proxy, ping, life-journal, image-studio, flights, feedback-registry, analytics-pulse, jeffreykeyser-net, nof1, travel-map are running but not managed by systemd
- **Impact:** These services won't auto-restart on crash or reboot unless managed by another process supervisor

## Port Allocation Map

| Port Range | Service | Type |
|-----------|---------|------|
| 3001-3002 | myrrs (API), prompt-registry | API |
| 3003-3004 | jeffreykeyser-net | API + Client |
| 3005 | ai-proxy | API |
| 3008 | myrrs (client) | Client |
| 3009-3010 | travel-map (insta-travel-map) | API + Client |
| 3011-3012 | pantry (legacy) | API + Client |
| 3013-3014 | dota-2-draft-helper | API + Client |
| 3015 | solo-vault | API |
| 3016 | cron-service | API |
| 3017 | pay | API |
| 3018-3019 | analytics-pulse | API + Client |
| 3020-3021 | ping | API + Client |
| 3022-3023 | music-store | API (down) + Client |
| 3025 | feedback-registry | API |
| 3026-3027 | life-journal (Life) | API + Client |
| 3030-3031 | image-studio | API + Client |
| 3032 | struct | API |
| 3035-3036 | myrrs (alt) | API + Client |
| 3040 | agency-hq | API |
| 3041 | business-hq | API |
| 3042 | qa-patrol | API |
| 3050-3051 | cream-city-web | Client + API |
| 3052 | pantry-manager | API |
| 3060-3061 | nof1 | API + Client |
| 3080-3081 | flights | Client + API |
| 3099 | openclaw-bridge | API |
| 3100-3102 | nanoclaw | Credential Proxy, Skill Server, Message API |
| 9000 | beelink-deploy | Webhook (localhost only) |
