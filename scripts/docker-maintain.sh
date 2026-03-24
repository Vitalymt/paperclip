#!/usr/bin/env bash
# docker-maintain.sh — periodic Docker cleanup for the Paperclip VM
#
# Usage (manual):
#   ./scripts/docker-maintain.sh
#
# Usage (cron, weekly on Sunday at 03:00):
#   (crontab -l 2>/dev/null; echo "0 3 * * 0 $HOME/paperclip/scripts/docker-maintain.sh >> /var/log/docker-maintain.log 2>&1") | crontab -

set -euo pipefail

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

log "=== Docker maintenance start ==="

log "Removing stopped containers..."
docker container prune -f

log "Removing unused images..."
docker image prune -a -f

log "Pruning build cache (keeping ≤2GB)..."
docker builder prune --keep-storage 2GB -f

log "=== After cleanup ==="
docker system df

log "Disk usage:"
df -h /

log "=== Docker maintenance complete ==="
