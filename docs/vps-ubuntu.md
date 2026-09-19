# Ubuntu VPS install — Heartless City RP (Milestone 1 staging)

Run this **after** the client sends SSH credentials. Put those values in `secrets/credentials.local.md` (local only, never git).

## Blocked until we have

| Field | Example |
|-------|---------|
| Public IP | `x.x.x.x` |
| SSH port | `22` (or custom) |
| User | `root` or `ubuntu` |
| Auth | password **or** private key |
| OS | Ubuntu 22.04 LTS |
| Open ports | **22** (SSH), **30120** TCP+UDP (FiveM), **40120** TCP (txAdmin setup, restrict later) |

FiveM license key is already in the local secrets file.

## What this produces

Joinable staging city:

1. FXServer (Linux recommended artifact) + txAdmin
2. MariaDB database `heartless_city`
3. QBCore + oxmysql + ox_lib + ox_inventory + ox_target + pma-voice
4. This repo’s `[heartless]` resources (`hc-core`, `hc-jobs`, `hc-business`, …)
5. `database/schema.sql` imported

Then walk the client through `docs/m1-acceptance.md`.

## Operator steps (from this machine)

### 1. Save SSH details

Edit `secrets/credentials.local.md` → **Ubuntu VPS** section.

### 2. SSH in

```bash
ssh -p 22 USER@IP
```

If using a key:

```bash
ssh -i /path/to/key -p 22 USER@IP
```

### 3. Clone this repo on the VPS

Public HTTPS if the repo is public:

```bash
sudo mkdir -p /opt/heartless
sudo git clone https://github.com/justin-brown-hr/GTA.git /opt/heartless/GTA
```

If private, use a deploy key or a PAT (do not commit the PAT).

### 4. Run the installer (on the VPS)

```bash
sudo bash /opt/heartless/GTA/scripts/vps-install-ubuntu.sh
```

The script:

- Installs `git`, `xz-utils`, `mariadb-server`, `ufw`, `curl`, `screen`
- Opens firewall ports 22 / 30120 / 40120
- Creates MariaDB user + database
- Downloads **LATEST RECOMMENDED** Linux FXServer artifact into `/opt/heartless/fxserver`
- Clones ox + essential QB resources (see `scripts/clone-stack.sh`)
- Writes `server-data/server.cfg` from the example (license key + DB string from env)
- Imports `database/schema.sql`
- Installs a systemd unit `heartless-fx.service`

Environment overrides (optional):

```bash
sudo FIVEM_LICENSE_KEY='from-secrets' \
  MYSQL_PASSWORD='generated-or-chosen' \
  bash /opt/heartless/GTA/scripts/vps-install-ubuntu.sh
```

If `FIVEM_LICENSE_KEY` is omitted, the script leaves `CHANGE_ME_LICENSE_KEY` and prints a reminder.

### 5. First boot: txAdmin vs headless

Default systemd command starts **txAdmin** on port **40120**.

1. Open `http://IP:40120` in a browser
2. Create the txAdmin PIN/password
3. Point the server data path at `/opt/heartless/GTA/server-data`
4. Do **not** overwrite `[heartless]` or `server.cfg` if the installer already wrote them
5. After the city is joinable, firewall-limit 40120 to your IP

Headless (skip txAdmin UI) — only after `server.cfg` is filled:

```bash
sudo systemctl edit heartless-fx --full
# ExecStart=.../run.sh +exec /opt/heartless/GTA/server-data/server.cfg
sudo systemctl restart heartless-fx
```

### 6. ox_inventory items

Merge `database/ox_items_heartless.lua` into `ox_inventory/data/items.lua` (installer prints the path). Required for M2 items; M1 jobs/businesses still demo without those item names.

### 7. Demo

Connect in FiveM → `connect IP:30120`  
Checklist: `docs/m1-acceptance.md`

## Layout on the VPS

```
/opt/heartless/
  fxserver/          # artifacts (run.sh, alpine/)
  GTA/               # this git repo
    server-data/
      server.cfg     # gitignored locally; created on VPS
      resources/
        [cfx]/
        [qb]/
        [standalone]/
        [heartless]/
```

## Do not

- Commit `server.cfg`, DB passwords, or SSH keys
- Open MySQL to the public internet
- Leave txAdmin (40120) world-open after setup

## Stability hardening (2026-09-18)

After a soft lockup (SSH + FiveM stopped answering, no clean OOM log):

- 4G `/swapfile` (fstab persistent), `vm.swappiness=10`
- `vm.oom_kill_allocating_task=1` via `/etc/sysctl.d/99-heartless-stability.conf`
- `heartless-fx.service`: `MemoryHigh=7G`, `MemoryMax=8G`, `Restart=always`, `OOMScoreAdjust=500`
- Watchdog timer: `/usr/local/bin/heartless-fx-watchdog.sh` every 1m — restarts FX after 3 failed `dynamic.json` checks

## Database backups (2026-09-19)

Nightly at **04:30** via systemd (`heartless-db-backup.timer` →
`heartless-db-backup.service` → `scripts/backup-db.sh`). Runs at low CPU/IO
priority, and `Persistent=true` catches up on a night the VPS was off.

- Dumps go to `/opt/heartless/backups/` (mode 700), kept **14 days**.
- A dump is only kept if gzip can read it and it contains tables; a failed
  run leaves the previous backups untouched.
- Restore was tested on 2026-09-19: loaded into a throwaway database, all 18
  tables matched the live row counts.

```bash
systemctl list-timers heartless-db-backup.timer       # next / last run
journalctl -u heartless-db-backup --since today       # what it did
sudo bash /opt/heartless/GTA/scripts/backup-db.sh     # run one now
gunzip -c /opt/heartless/backups/<file>.sql.gz | mysql heartless_city   # restore
```

**Still missing: an off-VPS copy.** Every backup lives on the same disk as the
database, so it does not survive losing the VPS itself. Needs a destination
from the client (object storage, another box, or a scheduled download).
