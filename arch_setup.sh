#!/bin/bash

# This is a setup script for Arch Linux
echo "Setting up the Arch Linux environment..."

# Update and upgrade the system
sudo pacman -Syu --noconfirm
echo "System updated and upgraded."

# Install necessary packages from official repositories
# We also install 'git' and 'base-devel' which are needed to build AUR packages
echo "Installing official repository packages..."
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
echo "Official packages (tldr, ncdu, git, curl, vim, nano, vlc, gparted, calibre, discord, pip, base-devel) installed."
#!bin/bash

# This is a setup script
echo "Setting up the environment..."

#update and upgrade the system
sudo apt-get update && sudo apt-get upgrade -y
sudo snap refresh # Update snap packages

echo "System updated and upgraded, and snap packages refreshed."

# Install necessary packages
sudo apt-get install -y tldr ncdu git curl vim nano vlc gparted calibre 

echo "tldr, ncdu, git, curl, vim, and nano text editors, vlc media player, gparted disk manager, calibre ebook manager installed."

tldr -update # Update tldr pages
echo "tldr pages updated."

sudo curl -fsS https://dl.brave.com/install.sh | sh # Install Brave Browser
echo "Brave Browser installed."

sudo curl -fsS https://dl.brave.com/install.sh | CHANNEL=nightly sh # Install Brave Browser Nightly
echo "Brave Browser and Brave Nightly installed."

sudo snap install code --classic # Install Visual Studio Code
echo "Visual Studio Code installed."

sudo snap install notion --classic # Install Notion
echo "Notion installed."

sudo snap install notion-calendar-snap # Install Notion Calendar
echo "Notion Calendar installed."

sudo snap install discord # Install Discord
echo "Discord installed."

echo "Configuring Git..."
git --version # Check git version
git config --global core.editor "code" --wait # Set VS Code as default git editor 
git config --global user.name "a49ty1m"
git config --global user.email "a4920251m@gmail.com"
echo "Git configured with global username and email."

echo "setting up Python3 and installing pip..."
sudo apt install python-is-python3 -y # Make python command point to python3
echo "Python command now points to Python3."

sudo apt install python3-pip -y # Install pip for python3
echo "Pip for Python3 installed."

pip3 install --upgrade pip # Upgrade pip
echo "Pip upgraded to the latest version."

echo "Setup complete. You can now start using your environment."

echo "Opening Visual Studio Code..."
code . 

echo "opening brave browser..."
echo "Now Open Your Phone and connect both whatsapp and braveSync." 
brave-browser web.whatsapp.com
brave-browser brave://settings/braveSync
brave-browser github.com/login 
# Update tldr pages
tldr --update
echo "tldr pages updated."

# Check if yay (AUR helper) is installed. If not, install it.
if ! command -v yay &> /dev/null
then
    echo "yay not found. Installing yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd /tmp
    rm -rf yay
    echo "yay installed."
else
    echo "yay is already installed."
fi

# Install applications from the AUR using yay
echo "Installing AUR packages (Brave, VS Code, Notion)..."
yay -S --noconfirm \
    brave-browser \
    brave-nightly-bin \
    visual-studio-code-bin \
    notion-app \
    notion-calendar-bin
echo "AUR packages installed."

echo "Configuring Git..."
git --version # Check git version
# Set VS Code (from visual-studio-code-bin) as default git editor
git config --global core.editor "code" --wait 
git config --global user.name "a49ty1m"
git config --global user.email "a4920251m@gmail.com"
echo "Git configured with global username and email."

echo "Upgrading pip..."
pip install --upgrade pip
echo "Pip upgraded to the latest version."

echo "Setup complete. You can now start using your environment."

echo "Opening Visual Studio Code..."
code .

echo "Opening Brave Browser..."
echo "Now Open Your Phone and connect both whatsapp and braveSync."
brave-browser web.whatsapp.com brave://settings/braveSync github.com/login
