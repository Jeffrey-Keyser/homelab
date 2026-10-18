#!/bin/bash
# beelink-deploy proxy for Jeffrey-Keyser/agency-hq: the service runs on forge (dev host).
# prod only relays the push; the real immutable-worktree deploy happens on forge.
set -euo pipefail
exec ssh -o BatchMode=yes -o ConnectTimeout=15 forge 'bash ~/bin/agency-hq-remote-deploy.sh main'
