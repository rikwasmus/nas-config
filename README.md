# NAS Configuration - l-space (DS418)

Automated daily export of NAS configuration from l-space.local (Synology DS418, DSM 7.3.2).

## What's tracked

| File | Contents |
|------|----------|
| `config/dsm-version.txt` | DSM version and build info |
| `config/system-settings.conf` | System settings (secrets filtered out) |
| `config/packages.txt` | Installed packages |
| `config/shares-smb.conf` | SMB shared folder definitions and permissions |
| `config/smb-global.conf` | Global SMB/Samba settings |
| `config/nfs-exports.conf` | NFS exports |
| `config/users.txt` | User accounts (no password hashes) |
| `config/groups.txt` | Groups |
| `config/network.txt` | Network interfaces, DNS, hostname |
| `config/crontab.txt` | Scheduled tasks |
| `config/raid-status.txt` | RAID array status |
| `config/storage-usage.txt` | Disk usage |
| `config/startup-scripts.txt` | Boot scripts in rc.d |
| `config/ssh-authorized-keys.txt` | SSH public keys |

## How it works

`export.sh` runs daily at 3:00 AM via DSM Task Scheduler. It dumps all config
files, and only commits+pushes if something actually changed.

Git diffs show exactly what changed and when.

## Notes

See `notes/settings-rationale.md` for documentation on why certain settings
are configured the way they are.

## Security

- No passwords, secrets, tokens, or serial numbers are exported
- Private keys are never committed
- This repo uses a deploy key with write access scoped to this repo only
