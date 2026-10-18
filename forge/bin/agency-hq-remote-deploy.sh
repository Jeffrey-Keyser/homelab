#!/bin/bash
# Invoked over SSH by prod beelink-deploy (proxy) on each agency-hq push.
# Mirrors beelink-deploy immutable-worktree mode locally on forge, then runs the release deploy.sh.
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin"
REPO=$HOME/agency-hq; ROOT=$HOME/releases/agency-hq; BRANCH=${1:-main}
cd "$REPO"; git fetch -q origin "$BRANCH"
REV=$(git rev-parse "origin/$BRANCH"); [[ $REV =~ ^[a-f0-9]{40}$ ]]
DEST=$ROOT/$REV
if [ ! -d "$DEST" ]; then git worktree add --detach "$DEST" "$REV"; fi
cd "$DEST"; [ "$(git rev-parse HEAD)" = "$REV" ]; [ -z "$(git status --porcelain)" ]
echo "Immutable release prepared on forge: $REV"
BEELINK_DEPLOY_IMMUTABLE_REVISION=$REV BEELINK_DEPLOY_SOURCE_PATH=$REPO bash deploy.sh "${@:2}"
