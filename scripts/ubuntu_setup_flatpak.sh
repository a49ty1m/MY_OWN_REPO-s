#!/usr/bin/env bash

# -------------------------------------------------
#  Basic system update / upgrade
# -------------------------------------------------
echo "Updating the system..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y tldr ncdu git curl vim nano vlc gparted calibre
echo "Core packages installed."

# Refresh tldr pages
tldr --update
echo "tldr pages updated."

# -------------------------------------------------
#  Install Brave (stable & nightly)
# -------------------------------------------------
echo "Installing Brave Browser (stable)..."
sudo curl -fsS https://dl.brave.com/install.sh | sh
echo "Brave stable installed."

echo "Installing Brave Browser (nightly)..."
sudo curl -fsS https://dl.brave.com/install.sh | CHANNEL=nightly sh
echo "Brave nightly installed."

# -------------------------------------------------
#  Git configuration
# -------------------------------------------------
echo "Configuring Git..."
git --version
git config --global core.editor "code --wait"
git config --global user.name "a49ty1m"
git config --global user.email "a4920251m@gmail.com"
echo "Git configured."

# -------------------------------------------------
#  Python3 + pip
# -------------------------------------------------
echo "Setting up Python3 and pip..."
sudo apt-get install -y python-is-python3 python3-pip
pip3 install --upgrade pip
echo "Python3 and pip ready."

# -------------------------------------------------
#  Flatpak setup (run once per machine)
# -------------------------------------------------
# Install Flatpak if it isn’t already
if ! command -v flatpak &>/dev/null; then
    echo "Installing Flatpak..."
    sudo apt-get install -y flatpak
fi

# Add Flathub repository (only needed the first time)
if ! flatpak remote-list | grep -q flathub; then
    echo "Adding Flathub remote..."
    sudo flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
fi

# -------------------------------------------------
#  Install extra apps via Flatpak
# -------------------------------------------------
declare -A flatpak_apps=(
    ["org.videolan.VLC"]="vlc"                     # optional, already apt‑installed
    ["com.visualstudio.code"]="visual-studio-code" # VS Code (official Flatpak)
    ["com.discordapp.Discord"]="discord"
    ["com.notionhq.Notion"]="notion"
    # Add more Flatpak IDs here as needed
)

echo "Installing extra apps with Flatpak..."
for app_id in "${!flatpak_apps[@]}"; do
    if ! flatpak list --app | grep -q "$app_id"; then
        echo "→ Installing ${flatpak_apps[$app_id]} ($app_id)"
        sudo flatpak install -y flathub "$app_id"
    else
        echo "→ ${flatpak_apps[$app_id]} already installed."
    fi
done

# -------------------------------------------------
#  Final touches
# -------------------------------------------------
echo "Setup complete. Launching VS Code..."
code .

echo "Opening Brave to WhatsApp and sync pages..."
brave-browser https://web.whatsapp.com \
               brave://settings/braveSync \
               https://github.com/login

echo "All done. Enjoy your environment."
