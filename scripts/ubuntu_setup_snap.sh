#!/usr/bin/env bash
# ==============================================================
# Ubuntu Setup – Keep Snap (Stable Version)
# ==============================================================
set -euo pipefail

LOG_FILE="$HOME/ubuntu-setup.log"
STEP_FILE="$HOME/.ubuntu-setup-step"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "Ubuntu setup started at $(date)"
echo "Logs will be saved to: $LOG_FILE"
echo "============================================================"

# --------------------------------------------------------------
# Error handling
# --------------------------------------------------------------
trap 'echo "❌ Setup interrupted. Check $LOG_FILE for details."; exit 1' ERR

# --------------------------------------------------------------
# Helper function for step tracking
# --------------------------------------------------------------
run_step() {
    local step_num="$1"
    local step_desc="$2"
    shift 2
    local last_step=$(cat "$STEP_FILE" 2>/dev/null || echo 0)

    if (( step_num <= last_step )); then
        echo "Skipping step $step_num: $step_desc (already done)"
        return
    fi

    echo "------------------------------------------------------------"
    echo "Step $step_num: $step_desc"
    echo "------------------------------------------------------------"
    "$@"
    echo "$step_num" > "$STEP_FILE"
    echo "✅ Step $step_num completed"
}

# --------------------------------------------------------------
# 1️⃣ Update and upgrade system
# --------------------------------------------------------------
run_step 1 "Updating system" bash -c '
    sudo apt-get update -y
    sudo apt-get upgrade -y
'

# --------------------------------------------------------------
# 2️⃣ Install core packages
# --------------------------------------------------------------
run_step 2 "Installing core utilities" bash -c '
    sudo apt-get install -y tldr ncdu git curl vim nano vlc gparted calibre
'

# --------------------------------------------------------------
# 3️⃣ Ensure snapd is installed
# --------------------------------------------------------------
run_step 3 "Ensuring snapd is installed" bash -c '
    if ! command -v snap >/dev/null; then
        sudo apt-get install -y snapd
    fi
'

# --------------------------------------------------------------
# 4️⃣ Install apps via Snap
# --------------------------------------------------------------
run_step 4 "Installing Notion, Discord, Telegram, and Notion Calendar" bash -c '
    sudo snap install notion-desktop --classic || true
    sudo snap install discord || true
    sudo snap install notion-calendar-snap || true
    sudo snap install telegram-desktop || true
'

# --------------------------------------------------------------
# 5️⃣ Update TLDR pages
# --------------------------------------------------------------
run_step 5 "Updating tldr pages" bash -c '
    tldr -u || true
'

# --------------------------------------------------------------
# 6️⃣ Install Brave Browser
# --------------------------------------------------------------
run_step 6 "Installing Brave Browser (stable + nightly)" bash -c '
    install_brave() {
        local channel="$1"
        local script="/tmp/brave-${channel}.sh"
        curl -fsS https://dl.brave.com/install.sh -o "$script"
        if [[ "$channel" == "stable" ]]; then
            sudo bash "$script"
        else
            sudo CHANNEL="$channel" bash "$script"
        fi
        rm -f "$script"
    }

    install_brave stable
    install_brave nightly
'

# --------------------------------------------------------------
# 7️⃣ Configure Git
# --------------------------------------------------------------
run_step 7 "Configuring Git" bash -c '
    git config --global core.editor "code --wait"
    git config --global user.name "a49ty1m"
    git config --global user.email "a4920251m@gmail.com"
'

# --------------------------------------------------------------
# 8️⃣ Install Python 3 and pip
# --------------------------------------------------------------
run_step 8 "Installing Python 3 and pip" bash -c '
    sudo apt-get install -y python3 python3-pip python-is-python3
'

# --------------------------------------------------------------
# 9️⃣ Launch initial tools
# --------------------------------------------------------------
run_step 9 "Launching Brave with useful tabs" bash -c '
    if command -v brave-browser >/dev/null; then
        brave-browser \
            https://web.whatsapp.com \
            brave://settings/braveSync \
            https://github.com/login &
    fi
'

# --------------------------------------------------------------
# Completion message
# --------------------------------------------------------------
echo "============================================================"
echo "✅ Ubuntu setup completed successfully at $(date)"
echo "Log: $LOG_FILE"
echo "============================================================"
