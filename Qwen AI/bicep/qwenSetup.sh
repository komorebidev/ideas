#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Qwen AI Lab - Rocky Linux setup
#
# Installs:
#   - Ollama
#   - Qwen 3 4B
#   - Open WebUI using Python virtual environment
#   - Tailscale (manual authentication)
#
# Persistent storage:
#   /mnt/qwen-data/ollama
#   /mnt/qwen-data/open-webui
#
# Open WebUI: 127.0.0.1:8080
# Ollama API: 127.0.0.1:11434
# ============================================================

LOG_FILE=/var/log/setupQwen.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "Starting Qwen AI setup: $(date)"
echo "============================================================"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root or with sudo."
    exit 1
fi

# ------------------------------------------------------------
# 1. Install operating system prerequisites
# ------------------------------------------------------------

echo "[1/7] Installing Rocky Linux packages..."

dnf -y install \
    curl \
    ca-certificates \
    jq \
    xfsprogs \
    python3.11 \
    python3.11-pip

# ------------------------------------------------------------
# 2. Mount persistent Azure data disk
# ------------------------------------------------------------

echo "[2/7] Configuring persistent data disk..."

DEVICE=/dev/disk/azure/scsi1/lun0
DATA_DIR=/mnt/qwen-data

for i in $(seq 1 60); do
    [[ -b "$DEVICE" ]] && break
    sleep 5
done

if [[ ! -b "$DEVICE" ]]; then
    echo "ERROR: Data disk not found at $DEVICE"
    exit 1
fi

mkdir -p "$DATA_DIR"

if ! blkid "$DEVICE"; then
    echo "Creating XFS filesystem on $DEVICE..."
    mkfs.xfs "$DEVICE"
fi

DISK_UUID=$(blkid -s UUID -o value "$DEVICE")

if ! grep -q "$DISK_UUID" /etc/fstab; then
    echo "UUID=$DISK_UUID $DATA_DIR xfs defaults,nofail 0 2" \
        >> /etc/fstab
fi

if ! mountpoint -q "$DATA_DIR"; then
    mount "$DATA_DIR"
fi

mkdir -p "$DATA_DIR/ollama"
mkdir -p "$DATA_DIR/open-webui"

# ------------------------------------------------------------
# 3. Install Ollama
# ------------------------------------------------------------

echo "[3/7] Installing Ollama..."

if ! command -v ollama >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh \
        -o /tmp/ollama-install.sh

    sh /tmp/ollama-install.sh
    rm -f /tmp/ollama-install.sh
fi

mkdir -p /etc/systemd/system/ollama.service.d

cat > /etc/systemd/system/ollama.service.d/storage.conf <<'EOF'
[Service]
Environment="OLLAMA_MODELS=/mnt/qwen-data/ollama"
EOF

systemctl daemon-reload
systemctl enable --now ollama

echo "Waiting for Ollama API..."

OLLAMA_READY=false

for i in $(seq 1 60); do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null; then
        OLLAMA_READY=true
        break
    fi
    sleep 5
done

if [[ "$OLLAMA_READY" != true ]]; then
    echo "ERROR: Ollama did not start successfully."
    systemctl status ollama --no-pager || true
    exit 1
fi

# ------------------------------------------------------------
# 4. Download Qwen 3 4B model
# ------------------------------------------------------------

echo "[4/7] Downloading Qwen 3 4B..."

ollama pull qwen3:4b

# ------------------------------------------------------------
# 5. Install Open WebUI using Python
# ------------------------------------------------------------

echo "[5/7] Installing Open WebUI with Python..."

if ! command -v python3.11 >/dev/null 2>&1; then
    echo "ERROR: Python 3.11 is unavailable."
    echo "Check enabled Rocky Linux repositories and package names."
    exit 1
fi

if [[ ! -x /opt/open-webui-venv/bin/python ]]; then
    python3.11 -m venv /opt/open-webui-venv
fi

/opt/open-webui-venv/bin/python -m pip install --upgrade pip
/opt/open-webui-venv/bin/python -m pip install open-webui

# ------------------------------------------------------------
# 6. Configure Open WebUI systemd service
# ------------------------------------------------------------

echo "[6/7] Configuring Open WebUI systemd service..."

cat > /etc/systemd/system/open-webui.service <<'EOF'
[Unit]
Description=Open WebUI
After=network-online.target ollama.service
Wants=network-online.target
Requires=ollama.service

[Service]
Type=simple
WorkingDirectory=/opt/open-webui-venv
Environment="OLLAMA_BASE_URL=http://127.0.0.1:11434"
Environment="DATA_DIR=/mnt/qwen-data/open-webui"
Environment="HOST=127.0.0.1"
Environment="PORT=8080"
ExecStart=/opt/open-webui-venv/bin/open-webui serve
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now open-webui

# ------------------------------------------------------------
# 7. Install and enable Tailscale
# ------------------------------------------------------------

echo "[7/7] Installing Tailscale..."

if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh \
        -o /tmp/tailscale-install.sh

    sh /tmp/tailscale-install.sh
    rm -f /tmp/tailscale-install.sh
fi

systemctl enable --now tailscaled

# ------------------------------------------------------------
# Completion checks
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Qwen AI setup completed: $(date)"
echo "============================================================"

echo
echo "Service status:"
systemctl is-active ollama || true
systemctl is-active open-webui || true
systemctl is-active tailscaled || true

echo
echo "Installed model:"
ollama list

echo
echo "Open WebUI local listener: 127.0.0.1:8080"
echo "Ollama API:                 127.0.0.1:11434"
echo "Persistent data:            $DATA_DIR"
echo
echo "Next steps:"
echo "1. Authenticate Tailscale manually:"
echo "   sudo tailscale up"
echo
echo "2. Test the model interactively:"
echo "   ollama run qwen3:4b"
echo
echo "3. After Tailscale authentication, configure Funnel:"
echo "   sudo tailscale funnel --bg 8080"
echo
echo "4. Check Funnel status:"
echo "   tailscale funnel status"
echo
echo "Setup log: $LOG_FILE"