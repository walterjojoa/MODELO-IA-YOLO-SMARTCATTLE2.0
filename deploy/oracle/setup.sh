#!/usr/bin/env bash
# Installs the shared vision service on an always-on Ubuntu server (Oracle Cloud Always Free, Ampere A1).
# It needs no open port: a Cloudflare quick tunnel publishes it, and it tells the backend its address.
# Every 10 minutes it pulls main from GitHub and restarts itself when something changed.
#
# Usage, on the server:  curl -fsSL https://raw.githubusercontent.com/walterjojoa/MODELO-IA-YOLO-SMARTCATTLE2.0/main/deploy/oracle/setup.sh | sudo bash
# It asks once for AI_API_KEY (the backend's shared key in Render → smartcattle2-backend → Environment).
set -euo pipefail

REPO=https://github.com/walterjojoa/MODELO-IA-YOLO-SMARTCATTLE2.0.git
DIR=/opt/smartcattle-ia
RUN_AS=smartcattle

apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q git python3-venv python3-pip libgl1 libglib2.0-0 curl

# cloudflared, from Cloudflare's own releases.
if ! command -v cloudflared >/dev/null; then
  arch=$(dpkg --print-architecture)
  curl -fsSL -o /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb"
  dpkg -i /tmp/cloudflared.deb
fi

id -u "$RUN_AS" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$RUN_AS"
if [ ! -d "$DIR/.git" ]; then
  git clone --depth 1 "$REPO" "$DIR"
fi
chown -R "$RUN_AS:$RUN_AS" "$DIR"

sudo -u "$RUN_AS" bash -c "
  cd '$DIR'
  python3 -m venv .venv
  .venv/bin/pip install -q --upgrade pip
  .venv/bin/pip install -q torch torchvision --index-url https://download.pytorch.org/whl/cpu
  .venv/bin/pip install -q -c constraints.txt -r requirements.txt
"

if [ ! -f "$DIR/.env" ]; then
  key="${AI_API_KEY:-}"
  if [ -z "$key" ]; then
    read -r -p "Pega AI_API_KEY (de Render) y Enter: " key < /dev/tty
  fi
  cat > "$DIR/.env" <<ENV
SMARTCATTLE_BACKEND_URL=https://smartcattle2-backend.onrender.com
SMARTCATTLE_API_KEY=$key
SMARTCATTLE_LIVE_ORIGINS=https://smartcattle2-frontend.onrender.com
SMARTCATTLE_LIVE_TUNNEL=1
SMARTCATTLE_CLOUD=1
SMARTCATTLE_IMGSZ=416
SMARTCATTLE_MAX_CAMERAS=8
SMARTCATTLE_DEVICE=cpu
ENV
  chown "$RUN_AS:$RUN_AS" "$DIR/.env"
  chmod 600 "$DIR/.env"
fi

cat > /etc/systemd/system/smartcattle-ia.service <<UNIT
[Unit]
Description=SmartCattle shared vision service
After=network-online.target
Wants=network-online.target

[Service]
User=$RUN_AS
WorkingDirectory=$DIR
Environment=YOLO_CONFIG_DIR=/tmp/ultralytics-$RUN_AS
ExecStart=$DIR/.venv/bin/python -u live.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

cat > /usr/local/bin/smartcattle-ia-update <<'UPD'
#!/usr/bin/env bash
# Follows main on GitHub: pulls, reinstalls if the requirements changed, and restarts the service.
set -euo pipefail
cd /opt/smartcattle-ia
before=$(sudo -u smartcattle git rev-parse HEAD)
sudo -u smartcattle git fetch -q --depth 1 origin main
after=$(sudo -u smartcattle git rev-parse FETCH_HEAD)
[ "$before" = "$after" ] && exit 0
sudo -u smartcattle git reset -q --hard FETCH_HEAD
if ! sudo -u smartcattle git diff --quiet "$before" "$after" -- requirements.txt constraints.txt 2>/dev/null; then
  sudo -u smartcattle .venv/bin/pip install -q -c constraints.txt -r requirements.txt
fi
systemctl restart smartcattle-ia
echo "Updated $before -> $after"
UPD
chmod +x /usr/local/bin/smartcattle-ia-update

cat > /etc/systemd/system/smartcattle-ia-update.service <<UNIT
[Unit]
Description=Pull SmartCattle IA from GitHub

[Service]
Type=oneshot
ExecStart=/usr/local/bin/smartcattle-ia-update
UNIT

cat > /etc/systemd/system/smartcattle-ia-update.timer <<UNIT
[Unit]
Description=Pull SmartCattle IA from GitHub every 10 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now smartcattle-ia.service smartcattle-ia-update.timer
sleep 20
journalctl -u smartcattle-ia -n 15 --no-pager
echo "Listo. Ver el registro: sudo journalctl -u smartcattle-ia -f"
