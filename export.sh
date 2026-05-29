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

# --- DSM Scheduled Tasks (task definitions) ---
LATEST_TASKS=$(ls -t /usr/syno/etc/scheduled_tasks_backup/ 2>/dev/null | head -1)
if [ -n "$LATEST_TASKS" ]; then
  cp "/usr/syno/etc/scheduled_tasks_backup/$LATEST_TASKS" \
    "$CONFIG_DIR/dsm-scheduled-tasks.conf" 2>/dev/null || true
fi

# --- RAID Status ---
cp /proc/mdstat "$CONFIG_DIR/raid-status.txt" 2>/dev/null || true

# --- Storage Usage ---
df -h > "$CONFIG_DIR/storage-usage.txt" 2>/dev/null || true

# --- Startup Scripts ---
ls -la /usr/local/etc/rc.d/ > "$CONFIG_DIR/startup-scripts.txt" 2>/dev/null || true

# --- SSH authorized keys (public keys only, safe to store) ---
cp /volume1/homes/rik.wasmus/.ssh/authorized_keys \
  "$CONFIG_DIR/ssh-authorized-keys.txt" 2>/dev/null || true

# --- Sonarr config (no API key) ---
if [ -f /var/packages/sonarr/var/.config/Sonarr/config.xml ]; then
  grep -vEi 'ApiKey|Password|secret' \
    /var/packages/sonarr/var/.config/Sonarr/config.xml \
    > "$CONFIG_DIR/sonarr-config.xml" 2>/dev/null || true
fi

# --- Prowlarr config (no API key) ---
if [ -f /var/packages/prowlarr/var/.config/Prowlarr/config.xml ]; then
  grep -vEi 'ApiKey|Password|secret' \
    /var/packages/prowlarr/var/.config/Prowlarr/config.xml \
    > "$CONFIG_DIR/prowlarr-config.xml" 2>/dev/null || true
fi

# --- nzbget config (no passwords/credentials) ---
if [ -f /var/packages/nzbget/var/nzbget.conf ]; then
  grep -vEi 'password|user|ControlPassword|ControlUsername' \
    /var/packages/nzbget/var/nzbget.conf \
    | grep -v '^#' | grep -v '^$' \
    > "$CONFIG_DIR/nzbget.conf" 2>/dev/null || true
fi

# --- Plex Preferences (no token/secrets) ---
PLEX_PREFS="/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml"
if [ -f "$PLEX_PREFS" ]; then
  # Strip token and cert attributes, keep structural/config attributes
  sed 's/ PlexOnlineToken="[^"]*"//g;
       s/ CertificatePassword="[^"]*"//g;
       s/ ProcessedMachineIdentifier="[^"]*"//g' \
    "$PLEX_PREFS" \
    > "$CONFIG_DIR/plex-preferences.xml" 2>/dev/null || true
fi

# --- HyperBackup task config ---
if [ -f /var/packages/HyperBackup/var/config/synobackup.conf ]; then
  grep -vEi 'password|secret|key|token|encrypt' \
    /var/packages/HyperBackup/var/config/synobackup.conf \
    > "$CONFIG_DIR/hyperbackup.conf" 2>/dev/null || true
fi

# --- Sonarr quality profiles (via API) ---
curl -sf -H 'X-Api-Key: 39982c307eae46a0b88570def3819697' \
  'http://localhost:8989/api/v3/qualityprofile' \
  > "$CONFIG_DIR/sonarr-quality-profiles.json" 2>/dev/null || true

# --- Sonarr custom formats (via API) ---
curl -sf -H 'X-Api-Key: 39982c307eae46a0b88570def3819697' \
  'http://localhost:8989/api/v3/customformat' \
  > "$CONFIG_DIR/sonarr-custom-formats.json" 2>/dev/null || true

# --- Sonarr indexers (via API, strip API keys from output) ---
curl -sf -H 'X-Api-Key: 39982c307eae46a0b88570def3819697' \
  'http://localhost:8989/api/v3/indexer' 2>/dev/null \
  | sed 's/"value":"[^"]*"/"value":"[REDACTED]"/g' \
  > "$CONFIG_DIR/sonarr-indexers.json" 2>/dev/null || true

# --- Prowlarr indexers (via API, strip API keys) ---
curl -sf -H 'X-Api-Key: 72e68f6ed5be47be8386fe7a795cabe9' \
  'http://localhost:9696/api/v1/indexer' 2>/dev/null \
  | sed 's/"value":"[^"]*"/"value":"[REDACTED]"/g' \
  > "$CONFIG_DIR/prowlarr-indexers.json" 2>/dev/null || true

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
