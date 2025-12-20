# Customization Guide

Learn how to customize the setup scripts for your specific needs.

## Table of Contents

1. [Changing Git Configuration](#changing-git-configuration)
2. [Adding/Removing Packages](#addingremoving-packages)
3. [Modifying Browser Startup](#modifying-browser-startup)
4. [Creating Your Own Script Variant](#creating-your-own-script-variant)

## Changing Git Configuration

### Default Configuration

All scripts set up Git with these defaults:

```bash
git config --global core.editor "code --wait"
git config --global user.name "a49ty1m"
git config --global user.email "a4920251m@gmail.com"
```

### Customizing for Your Account

1. Open the script you want to use (e.g., `scripts/ubuntu_setup_snap.sh`)
2. Find the "Configure Git" section
3. Change the values:

```bash
git config --global user.name "YourGitHubUsername"
git config --global user.email "your.email@example.com"
```

### Using a Different Editor

If you prefer vim, nano, or another editor:

```bash
# For vim
git config --global core.editor "vim"

# For nano
git config --global core.editor "nano"

# For emacs
git config --global core.editor "emacs"
```

## Adding/Removing Packages

### Arch Linux (`arch_setup.sh`)

#### Adding Official Packages

Find this section:
```bash
sudo pacman -S --noconfirm --needed \
    tldr \
    ncdu \
    # ... other packages
```

Add your package:
```bash
sudo pacman -S --noconfirm --needed \
    tldr \
    ncdu \
    htop \        # New package added
    # ... other packages
```

#### Adding AUR Packages

Find this section:
```bash
yay -S --noconfirm \
    brave-browser \
    # ... other packages
```

Add your AUR package:
```bash
yay -S --noconfirm \
    brave-browser \
    spotify \     # New AUR package
    # ... other packages
```

### Ubuntu Snap (`ubuntu_setup_snap.sh`)

#### Adding APT Packages

Find Step 2:
```bash
run_step 2 "Installing core utilities" bash -c '
    sudo apt-get install -y tldr ncdu git curl vim nano vlc gparted calibre
'
```

Modify to:
```bash
run_step 2 "Installing core utilities" bash -c '
    sudo apt-get install -y tldr ncdu git curl vim nano vlc gparted calibre htop
'
```

#### Adding Snap Packages

Find Step 4:
```bash
run_step 4 "Installing Notion, Discord, and Notion Calendar" bash -c '
    sudo snap install notion-desktop --classic || true
    sudo snap install discord || true
    sudo snap install notion-calendar-snap || true
'
```

Add your snap:
```bash
run_step 4 "Installing applications" bash -c '
    sudo snap install notion-desktop --classic || true
    sudo snap install discord || true
    sudo snap install notion-calendar-snap || true
    sudo snap install spotify || true
'
```

### Ubuntu Flatpak (`ubuntu_setup_flatpak.sh`)

Find the `flatpak_apps` array:
```bash
declare -A flatpak_apps=(
    ["org.videolan.VLC"]="vlc"
    ["com.visualstudio.code"]="visual-studio-code"
    ["com.discordapp.Discord"]="discord"
    ["com.notionhq.Notion"]="notion"
)
```

Add your application:
```bash
declare -A flatpak_apps=(
    ["org.videolan.VLC"]="vlc"
    ["com.visualstudio.code"]="visual-studio-code"
    ["com.discordapp.Discord"]="discord"
    ["com.notionhq.Notion"]="notion"
    ["com.spotify.Client"]="spotify"
)
```

**Finding Flatpak IDs:**
Search on [Flathub](https://flathub.org/) or use:
```bash
flatpak search spotify
```

## Modifying Browser Startup

### Default Behavior

All scripts open these pages in Brave:
- WhatsApp Web (`web.whatsapp.com`)
- Brave Sync settings (`brave://settings/braveSync`)
- GitHub login (`github.com/login`)

### Customizing Startup Pages

Find the browser launch section in your script.

**Arch Linux:**
```bash
brave-browser web.whatsapp.com brave://settings/braveSync github.com/login &
```

**Ubuntu Scripts:**
```bash
brave-browser \
    https://web.whatsapp.com \
    brave://settings/braveSync \
    https://github.com/login &
```

Modify to your preferences:
```bash
brave-browser \
    https://gmail.com \
    https://calendar.google.com \
    https://github.com \
    https://stackoverflow.com &
```

### Disabling Browser Auto-Launch

Comment out or remove the browser launch lines:
```bash
# brave-browser https://web.whatsapp.com &
```

## Creating Your Own Script Variant

### Method 1: Copy and Modify

1. Choose the script closest to your needs
2. Copy it to a new file:
   ```bash
   cp scripts/ubuntu_setup_snap.sh scripts/my_custom_setup.sh
   ```
3. Make your modifications
4. Test thoroughly!

### Method 2: Modular Approach

Create a base script and source it:

**base_setup.sh:**
```bash
#!/bin/bash

setup_git() {
    git config --global user.name "YourName"
    git config --global user.email "your@email.com"
}

install_basics() {
    sudo apt-get install -y git curl vim nano
}
```

**my_setup.sh:**
```bash
#!/bin/bash
source ./base_setup.sh

install_basics
setup_git
# Add your custom steps
```

## Advanced Customization

### Adding Conditional Logic

Install different tools based on system:

```bash
if [ -f /etc/arch-release ]; then
    echo "Detected Arch Linux"
    sudo pacman -S --noconfirm package-name
elif [ -f /etc/lsb-release ]; then
    echo "Detected Ubuntu/Debian"
    sudo apt-get install -y package-name
fi
```

### Adding User Prompts

Ask before installing certain tools:

```bash
read -p "Install Docker? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt-get install -y docker.io
fi
```

### Creating Install Groups

```bash
install_dev_tools() {
    echo "Installing development tools..."
    sudo apt-get install -y build-essential cmake
}

install_media_tools() {
    echo "Installing media tools..."
    sudo apt-get install -y vlc gimp inkscape
}

# Call based on your needs
install_dev_tools
install_media_tools
```

## Testing Your Changes

Always test your modifications:

1. **Use a Virtual Machine** - Test on a clean VM first
2. **Check Syntax** - Use `bash -n your_script.sh` to check for errors
3. **Dry Run** - Comment out actual installations and test the flow
4. **Version Control** - Commit working versions before big changes

## Getting Help

If you need help customizing:

1. Check the [COMPARISON.md](COMPARISON.md) guide
2. Review the main [README.md](../README.md)
3. Look at package documentation:
   - Arch: `man pacman`, `yay --help`
   - Ubuntu: `man apt-get`, `snap help`, `flatpak --help`
