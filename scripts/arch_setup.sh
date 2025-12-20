#!/bin/bash
# ==============================================================
# Arch Linux Setup Script
# ==============================================================
set -euo pipefail

echo "============================================================"
echo "Arch Linux setup started at $(date)"
echo "============================================================"

# --------------------------------------------------------------
# 1️⃣ Update and upgrade the system
# --------------------------------------------------------------
echo "Step 1: Updating system..."
sudo pacman -Syu --noconfirm
echo "✅ System updated and upgraded."

# --------------------------------------------------------------
# 2️⃣ Install necessary packages from official repositories
# --------------------------------------------------------------
echo "Step 2: Installing official repository packages..."
sudo pacman -S --noconfirm --needed \
    tldr \
    ncdu \
    git \
    curl \
    vim \
    nano \
    vlc \
    gparted \
    calibre \
    discord \
    python-pip \
    base-devel
echo "✅ Official packages installed."

# --------------------------------------------------------------
# 3️⃣ Update tldr pages
# --------------------------------------------------------------
echo "Step 3: Updating tldr pages..."
tldr --update
echo "✅ tldr pages updated."

# --------------------------------------------------------------
# 4️⃣ Install yay (AUR helper) if not present
# --------------------------------------------------------------
if ! command -v yay &> /dev/null
then
    echo "Step 4: yay not found. Installing yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd /tmp
    rm -rf yay
    echo "✅ yay installed."
else
    echo "Step 4: yay is already installed."
fi

# --------------------------------------------------------------
# 5️⃣ Install applications from the AUR using yay
# --------------------------------------------------------------
echo "Step 5: Installing AUR packages (Brave, VS Code, Notion)..."
yay -S --noconfirm \
    brave-browser \
    brave-nightly-bin \
    visual-studio-code-bin \
    notion-app \
    notion-calendar-bin
echo "✅ AUR packages installed."

# --------------------------------------------------------------
# 6️⃣ Configure Git
# --------------------------------------------------------------
echo "Step 6: Configuring Git..."
git --version
git config --global core.editor "code --wait"
git config --global user.name "a49ty1m"
git config --global user.email "a4920251m@gmail.com"
echo "✅ Git configured with global username and email."

# --------------------------------------------------------------
# 7️⃣ Upgrade pip
# --------------------------------------------------------------
echo "Step 7: Upgrading pip..."
pip install --upgrade pip
echo "✅ Pip upgraded to the latest version."

# --------------------------------------------------------------
# 8️⃣ Launch initial tools
# --------------------------------------------------------------
echo "Step 8: Opening Visual Studio Code..."
code . &

echo "Step 9: Opening Brave Browser..."
echo "Now Open Your Phone and connect both WhatsApp and Brave Sync."
brave-browser https://web.whatsapp.com brave://settings/braveSync https://github.com/login &

# --------------------------------------------------------------
# Completion message
# --------------------------------------------------------------
echo "============================================================"
echo "✅ Arch Linux setup completed successfully at $(date)"
echo "============================================================"
