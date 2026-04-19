#!/bin/bash
# NAS Config Export Script
# Runs daily at 3am via DSM Task Scheduler
# Exports NAS configuration (without secrets) and pushes to GitHub

set -euo pipefail

REPO_DIR="/volume1/homes/rik.wasmus/nas-config"
CONFIG_DIR="${REPO_DIR}/config"
GIT="/var/packages/Git/target/bin/git"
LOG="${REPO_DIR}/export.log"

log() { echo "$(date -Iseconds) $1" >> "$LOG"; }

log "Starting config export"

mkdir -p "$CONFIG_DIR"

# --- DSM Version ---
cp /etc.defaults/VERSION "$CONFIG_DIR/dsm-version.txt" 2>/dev/null || true

# --- System Settings (filtered, no secrets) ---
grep -vEi 'password|secret|key|token|serial|mac_addr' /etc/synoinfo.conf \
  > "$CONFIG_DIR/system-settings.conf" 2>/dev/null || true

# --- Installed Packages ---
ls /volume1/@appstore/ 2>/dev/null | sort > "$CONFIG_DIR/packages.txt"

# --- Shared Folders (SMB) ---
if [ -f /etc/samba/smb.share.conf ]; then
  cp /etc/samba/smb.share.conf "$CONFIG_DIR/shares-smb.conf"
fi

# --- Global SMB settings ---
if [ -f /etc/samba/smb.conf ]; then
  grep -vEi 'password|secret|key|token' /etc/samba/smb.conf \
    > "$CONFIG_DIR/smb-global.conf" 2>/dev/null || true
fi

# --- NFS Exports ---
cp /etc/exports "$CONFIG_DIR/nfs-exports.conf" 2>/dev/null || true

# --- Users (no password hashes, just accounts with real UIDs) ---
awk -F: '$3 >= 1000 && $3 < 65000 {print $1 ":" $3 ":" $4 ":" $5 ":" $6 ":" $7}' /etc/passwd \
  > "$CONFIG_DIR/users.txt" 2>/dev/null || true

# --- Groups ---
awk -F: '$3 >= 100 && $3 < 65000 {print}' /etc/group \
  > "$CONFIG_DIR/groups.txt" 2>/dev/null || true

# --- Network ---
{
  echo "# Interfaces"
  ip addr show 2>/dev/null | grep -E 'inet |state|mtu'
  echo ""
  echo "# DNS"
  cat /etc/resolv.conf 2>/dev/null
  echo ""
  echo "# Hostname"
  hostname 2>/dev/null
} > "$CONFIG_DIR/network.txt"

# --- Scheduled Tasks (crontab) ---
cp /etc/crontab "$CONFIG_DIR/crontab.txt" 2>/dev/null || true

# --- RAID Status ---
cp /proc/mdstat "$CONFIG_DIR/raid-status.txt" 2>/dev/null || true

# --- Storage Usage ---
df -h > "$CONFIG_DIR/storage-usage.txt" 2>/dev/null || true

# --- Startup Scripts ---
ls -la /usr/local/etc/rc.d/ > "$CONFIG_DIR/startup-scripts.txt" 2>/dev/null || true

# --- SSH authorized keys (public keys only, safe to store) ---
cp /volume1/homes/rik.wasmus/.ssh/authorized_keys \
  "$CONFIG_DIR/ssh-authorized-keys.txt" 2>/dev/null || true

# --- Commit and push if changed ---
cd "$REPO_DIR"

$GIT add -A

if $GIT diff --cached --quiet; then
  log "No changes detected, skipping commit"
else
  $GIT commit -m "config export $(date -Iseconds)"
  $GIT push -u origin main 2>&1 | tee -a "$LOG"
  log "Changes committed and pushed"
fi

log "Export complete"
