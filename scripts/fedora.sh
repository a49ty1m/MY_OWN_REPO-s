#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== System Setup & Catppuccin GRUB Theme Installer for Fedora ==="

# Ensure the script is run with sudo/root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo:"
  echo "sudo bash \$0"
  exit 1
fi

# Determine the non-root target user and their home directory
if [ -n "$SUDO_USER" ]; then
  TARGET_USER="$SUDO_USER"
  TARGET_HOME=$(eval echo "~$SUDO_USER")
else
  TARGET_USER="$USER"
  TARGET_HOME="$HOME"
fi

echo "Target User: $TARGET_USER"
echo "Target Home: $TARGET_HOME"
echo "============================================="

# ----------------------------------------------------------------------
# 0. Ensure system is fully up-to-date before installing anything
# ----------------------------------------------------------------------
echo "STEP 0: Updating system packages..."
# Kill any stale dnf processes that might hold locks from previous runs
killall -9 dnf dnf5 2>/dev/null || true
sleep 1

# Clean stale metadata so we always fetch fresh mirror lists
dnf clean metadata 2>/dev/null || true

# Upgrade all packages to the latest versions.
# The -y flag auto-confirms; this runs early so subsequent steps use the
# newest library versions.
#
# Note: on Fedora this may pull in newer kernel, glibc, etc.;
# a reboot may be required.
# We use || true because transient mirror 404s should not block the rest
# of the setup.
dnf upgrade -y --refresh || {
  echo "WARNING: System upgrade encountered errors (possibly transient mirror issues)."
  echo "         Continuing with the rest of the setup..."
}

echo "============================================="

# ----------------------------------------------------------------------
# 1. Enable RPM Fusion Repositories & Install Multimedia Codecs
# ----------------------------------------------------------------------
echo "STEP 1: Enabling RPM Fusion & Installing Multimedia Codecs..."
dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
  || true  # don't fail if already installed

# Enable Fedora Cisco openh264 repo (DNF5 syntax)
dnf config-manager setopt fedora-cisco-openh264.enabled=1 || true

# Swap to full FFmpeg (required for H.264/H.265 decoders)
dnf swap -y ffmpeg-free ffmpeg --allowerasing || true

# Install multimedia complements & GStreamer plugins
dnf install -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin || true

# Install OpenH264 support
dnf install -y gstreamer1-plugin-openh264 mozilla-openh264 || true

# Update multimedia packages
dnf upgrade -y @multimedia || true

echo "RPM Fusion repositories enabled and multimedia codecs installed."
echo "============================================="

# ----------------------------------------------------------------------
# 2. Install Nvidia Drivers & 32-bit Libraries (Crucial for Steam)
# ----------------------------------------------------------------------
echo "STEP 2: Installing Nvidia Drivers (akmod-nvidia) & 32-bit Libraries..."
# Enable the nvidia driver repo (DNF5 syntax)
dnf config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1 || true
dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs.i686 egl-wayland || true
echo "Nvidia drivers and Steam graphics libraries installation complete."
echo "============================================="

# ----------------------------------------------------------------------
# 3. Install Zsh and Extensions
# ----------------------------------------------------------------------
echo "STEP 3: Installing and Configuring Zsh..."
dnf install -y zsh git curl

# Install Oh My Zsh if not already present
OMZ_DIR="$TARGET_HOME/.oh-my-zsh"
if [ ! -d "$OMZ_DIR" ]; then
  echo "Installing Oh My Zsh for $TARGET_USER..."
  sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh is already installed for $TARGET_USER."
fi

# Install plugins (autosuggestions & syntax-highlighting)
PLUGINS_DIR="$OMZ_DIR/custom/plugins"
mkdir -p "$PLUGINS_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$PLUGINS_DIR"

SUGGESTIONS_DIR="$PLUGINS_DIR/zsh-autosuggestions"
if [ ! -d "$SUGGESTIONS_DIR" ]; then
  echo "Installing zsh-autosuggestions..."
  sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$SUGGESTIONS_DIR"
fi

HIGHLIGHT_DIR="$PLUGINS_DIR/zsh-syntax-highlighting"
if [ ! -d "$HIGHLIGHT_DIR" ]; then
  echo "Installing zsh-syntax-highlighting..."
  sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HIGHLIGHT_DIR"
fi

# Enable plugins in .zshrc
ZSHRC="$TARGET_HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
  echo "Configuring plugins in $ZSHRC..."
  if grep -q '^plugins=(git)' "$ZSHRC"; then
    sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC"
    echo "Added plugins to $ZSHRC."
  elif ! grep -q 'zsh-autosuggestions' "$ZSHRC"; then
    sed -i 's/plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC"
    echo "Appended plugins to custom list in $ZSHRC."
  else
    echo "Plugins already configured in $ZSHRC."
  fi
fi

# Change default shell to Zsh
CURRENT_SHELL=$(getent passwd "$TARGET_USER" | cut -d: -f7)
if [ "$CURRENT_SHELL" != "$(which zsh)" ]; then
  echo "Changing default shell to Zsh for $TARGET_USER..."
  chsh -s "$(which zsh)" "$TARGET_USER"
else
  echo "Default shell is already Zsh."
fi
echo "============================================="

# ----------------------------------------------------------------------
# 4. Install Fresh Shell Configuration Manager
# ----------------------------------------------------------------------
echo "STEP 4: Installing Fresh Shell Configuration Manager..."
if [ ! -d "$TARGET_HOME/.fresh" ]; then
  sudo -u "$TARGET_USER" bash -c "$(curl -sL https://get.freshshell.com)" || {
    echo "WARNING: Fresh Shell installation failed (Perl dependency?). Skipping."
  }
else
  echo "Fresh is already installed."
fi
echo "============================================="

# ----------------------------------------------------------------------
# 5. Install Brave & Brave Nightly Browsers
# ----------------------------------------------------------------------
echo "STEP 5: Installing Brave and Brave Nightly Browsers..."

# Ensure dnf-plugins-core is available
dnf install -y dnf-plugins-core || true

# Remove any old/broken Brave repo files first
rm -f /etc/yum.repos.d/brave-browser*.repo

# Write correct Brave Browser repo file (with $basearch in the URL)
cat <<'EOF' > /etc/yum.repos.d/brave-browser.repo
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/$basearch
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
EOF

# Write correct Brave Browser Nightly repo file
cat <<'EOF' > /etc/yum.repos.d/brave-browser-nightly.repo
[brave-browser-nightly]
name=Brave Browser Nightly
baseurl=https://brave-browser-rpm-nightly.s3.brave.com/$basearch
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-nightly.s3.brave.com/brave-core-nightly.asc
EOF

# Import GPG keys
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc || true
rpm --import https://brave-browser-rpm-nightly.s3.brave.com/brave-core-nightly.asc || true

dnf install -y brave-browser brave-browser-nightly || {
  echo "WARNING: Brave Nightly may not be available. Installing stable only..."
  dnf install -y brave-browser || true
}
echo "Brave browsers installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 6. Install VS Code (via Microsoft RPM Repository)
# ----------------------------------------------------------------------
echo "STEP 6: Installing VS Code..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat <<'EOF' > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

dnf check-update || true
dnf install -y code
echo "VS Code installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 7. Install Ghostty Terminal Emulator
# ----------------------------------------------------------------------
echo "STEP 7: Installing Ghostty..."
dnf copr enable -y scottames/ghostty || true
dnf install -y ghostty
echo "Ghostty installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 8. Install btop (Resource Monitor)
# ----------------------------------------------------------------------
echo "STEP 8: Installing btop..."
dnf install -y btop
echo "btop installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 8a. Install General CLI Utilities
# ----------------------------------------------------------------------
echo "STEP 8a: Installing General CLI Utilities..."
dnf install -y tldr ncdu calibre gh gcc-c++ fzf duf eza zoxide mycli git-lfs || true
echo "CLI utilities installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 9. Install VLC
# ----------------------------------------------------------------------
echo "STEP 9: Installing VLC Media Player..."
dnf install -y vlc
echo "VLC installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 10. Install Steam and Discord
# ----------------------------------------------------------------------
echo "STEP 10: Installing Steam and Discord..."
dnf install -y steam discord || true
echo "Steam and Discord installed successfully."

# Note on Steam WebHelper blank screen issues on Wayland / hybrid graphics
echo "TIP: If Steam launches with a black or empty screen, run:"
echo "     steam -cef-disable-gpu"
echo "     Or delete the browser cache by running: rm -rf ~/.local/share/Steam/config/htmlcache/*"
echo "============================================="

# ----------------------------------------------------------------------
# 11. Install Obsidian (AppImage)
# ----------------------------------------------------------------------
echo "STEP 11: Installing Obsidian (AppImage)..."
dnf install -y fuse wget curl

# Create installation directory
mkdir -p /opt/obsidian/

# Fetch latest AppImage URL from GitHub API
LATEST_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
  | grep "browser_download_url.*AppImage" \
  | tail -n 1 \
  | cut -d '"' -f 4)

echo "Downloading Obsidian AppImage from: $LATEST_URL"
wget -O /opt/obsidian/Obsidian.AppImage "$LATEST_URL"
chmod +x /opt/obsidian/Obsidian.AppImage

# Create a symlink to /usr/local/bin/obsidian
ln -sf /opt/obsidian/Obsidian.AppImage /usr/local/bin/obsidian

# Download Obsidian logo for desktop entry
echo "Downloading Obsidian logo..."
mkdir -p /usr/share/icons/hicolor/512x512/apps/
wget -O /usr/share/icons/hicolor/512x512/apps/obsidian.png https://obsidian.md/images/logo.png || true

# Create Desktop Entry
echo "Creating desktop entry for Obsidian..."
cat <<EOF > /usr/share/applications/obsidian.desktop
[Desktop Entry]
Name=Obsidian
Comment=Obsidian knowledge base
Exec=/opt/obsidian/Obsidian.AppImage %u
Icon=obsidian
Terminal=false
Type=Application
Categories=Office;Utility;
MimeType=x-scheme-handler/obsidian;
StartupWMClass=Obsidian
EOF

echo "Obsidian AppImage installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 12. Install Antigravity CLI
# ----------------------------------------------------------------------
echo "STEP 12: Installing Antigravity CLI..."
if ! command -v agy &> /dev/null; then
  sudo -u "$TARGET_USER" bash -c "$(curl -fsSL https://antigravity.google/cli/install.sh)" || {
    echo "WARNING: Antigravity CLI installation failed. Skipping."
  }
else
  echo "Antigravity CLI (agy) is already installed."
fi
echo "============================================="

# ----------------------------------------------------------------------
# 13. Install and Configure Virtualization (KVM/QEMU/Libvirt)
# ----------------------------------------------------------------------
echo "STEP 13: Installing Virtualization Stack..."
# Install the virtualization group
dnf install -y @virtualization

# Enable and start the libvirtd daemon
echo "Enabling and starting libvirtd service..."
systemctl enable --now libvirtd

# Add the target user to the libvirt group
echo "Adding $TARGET_USER to the libvirt group..."
usermod -a -G libvirt "$TARGET_USER"
echo "Virtualization stack installed successfully."
echo "============================================="

# ----------------------------------------------------------------------
# 13a. Create a host-side shared folder for KVM guests (virtiofs)
# ----------------------------------------------------------------------
echo "STEP 13a: Setting up a host shared folder for KVM guests..."

# Create the folder on the host
SHARE_DIR="${TARGET_HOME}/SharedFolder"
mkdir -p "$SHARE_DIR"
chown "$TARGET_USER":"$TARGET_USER" "$SHARE_DIR"
echo "  → Host folder created at: $SHARE_DIR"

# Install virtiofsd (host-side daemon required for virtio-fs)
dnf install -y virtiofsd || true

VM_NAME="Kali-Linux"

# Check if the VM exists
if ! virsh -c qemu:///system dominfo "$VM_NAME" &>/dev/null; then
  echo "WARNING: VM '$VM_NAME' not found. Skipping shared folder attachment."
  echo "  Create the VM first, then re-run this script."
  echo "============================================="
else
  # ── virtiofs requires the VM to be SHUT DOWN to modify its XML ──
  VM_STATE=$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null | head -1)

  if [ "$VM_STATE" = "running" ]; then
    echo "  → Shutting down '$VM_NAME' to apply shared folder config..."
    virsh -c qemu:///system shutdown "$VM_NAME" 2>/dev/null || true
    # Wait for it to actually stop (up to 60 seconds)
    for i in $(seq 1 60); do
      VM_STATE=$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null | head -1)
      [ "$VM_STATE" = "shut off" ] && break
      sleep 1
    done
    if [ "$VM_STATE" != "shut off" ]; then
      echo "  → Force-stopping '$VM_NAME'..."
      virsh -c qemu:///system destroy "$VM_NAME" 2>/dev/null || true
      sleep 2
    fi
  fi

  # ── 1. Add <memoryBacking> for shared memory (required by virtiofs) ──
  # Check if memoryBacking is already configured
  if ! virsh -c qemu:///system dumpxml "$VM_NAME" | grep -q "<memoryBacking>"; then
    echo "  → Adding shared memory backing to VM (required for virtiofs)..."
    # Use virt-xml if available, otherwise patch the XML manually
    if command -v virt-xml &>/dev/null; then
      virt-xml "$VM_NAME" --edit --memorybacking source.type=memfd,access.mode=shared 2>/dev/null || {
        # Fallback: manual XML edit
        TMPXML=$(mktemp)
        virsh -c qemu:///system dumpxml "$VM_NAME" > "$TMPXML"
        # Insert memoryBacking after the closing </vcpu> or </currentMemory> tag
        sed -i '/<\/currentMemory>/a \  <memoryBacking>\n    <source type="memfd"/>\n    <access mode="shared"/>\n  </memoryBacking>' "$TMPXML"
        virsh -c qemu:///system define "$TMPXML"
        rm -f "$TMPXML"
      }
    else
      TMPXML=$(mktemp)
      virsh -c qemu:///system dumpxml "$VM_NAME" > "$TMPXML"
      sed -i '/<\/currentMemory>/a \  <memoryBacking>\n    <source type="memfd"/>\n    <access mode="shared"/>\n  </memoryBacking>' "$TMPXML"
      virsh -c qemu:///system define "$TMPXML"
      rm -f "$TMPXML"
    fi
    echo "  → Shared memory backing added."
  else
    echo "  → Shared memory backing already configured."
  fi

  # ── 2. Add <filesystem> device for the shared folder ──
  if ! virsh -c qemu:///system dumpxml "$VM_NAME" | grep -q "kali_share"; then
    echo "  → Adding shared folder device to VM..."
    FSXML=$(mktemp)
    cat > "$FSXML" <<'XMLEOF'
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs"/>
  <source dir="SHARE_DIR_PLACEHOLDER"/>
  <target dir="kali_share"/>
</filesystem>
XMLEOF
    # Replace placeholder with actual path
    sed -i "s|SHARE_DIR_PLACEHOLDER|$SHARE_DIR|" "$FSXML"
    virsh -c qemu:///system attach-device "$VM_NAME" "$FSXML" --config
    rm -f "$FSXML"
    echo "  → Shared folder device added to VM config."
  else
    echo "  → Shared folder device already configured."
  fi

  # ── 3. Start the VM back up ──
  echo "  → Starting '$VM_NAME'..."
  virsh -c qemu:///system start "$VM_NAME" 2>/dev/null || true

  echo ""
  echo "  ┌─────────────────────────────────────────────────────────┐"
  echo "  │  STEP 13a DONE — Host shared folder configured.        │"
  echo "  │                                                        │"
  echo "  │  Host folder:  $SHARE_DIR"
  echo "  │  VM device:    kali_share (virtiofs)                   │"
  echo "  │                                                        │"
  echo "  │  ⚠  You still need to MOUNT it inside the Kali VM:    │"
  echo "  │                                                        │"
  echo "  │  1. Open a terminal inside Kali and run:               │"
  echo "  │     sudo mkdir -p ~/Desktop/SharedFolder               │"
  echo "  │     sudo mount -t virtiofs kali_share \\                │"
  echo "  │          ~/Desktop/SharedFolder                        │"
  echo "  │                                                        │"
  echo "  │  2. To auto-mount on every boot, add to /etc/fstab:   │"
  echo "  │     kali_share /home/kali/Desktop/SharedFolder \\       │"
  echo "  │          virtiofs defaults 0 0                         │"
  echo "  │                                                        │"
  echo "  └─────────────────────────────────────────────────────────┘"
  echo ""
fi
echo "============================================="

# ----------------------------------------------------------------------
# 14. Configure Catppuccin GRUB Theme & Custom Wallpaper
# ----------------------------------------------------------------------
echo "STEP 14: Configuring Catppuccin GRUB Theme..."

REPO_DIR="grub"
REPO_URL="https://github.com/catppuccin/grub.git"

if [ -d "$REPO_DIR" ]; then
  echo "Using existing repository directory: $REPO_DIR"
else
  echo "Cloning Catppuccin GRUB repository..."
  sudo -u "$TARGET_USER" git clone "$REPO_URL" "$REPO_DIR"
fi

echo "Cleaning up any old/misplaced theme files..."
rm -rf /usr/share/grub/themes/{background.png,font.pf2,icons,logo.png,select_c.png,select_e.png,select_w.png,theme.txt}

mkdir -p /usr/share/grub/themes/

echo "Copying Catppuccin GRUB themes..."
cp -r "$REPO_DIR"/src/catppuccin-*-grub-theme /usr/share/grub/themes/

# Apply custom wallpaper if available
if [ -f "/home/smilo/288.jpg" ]; then
  echo "Custom wallpaper /home/smilo/288.jpg found. Applying to GRUB themes..."
  dnf install -y ImageMagick # Ensure magick is available
  for theme_dir in /usr/share/grub/themes/catppuccin-*-grub-theme; do
    if [ -d "$theme_dir" ]; then
      magick /home/smilo/288.jpg "$theme_dir/background.png"
    fi
  done
  echo "Custom wallpaper applied."

  # Apply custom lock screen wallpaper to KDE Plasma
  if command -v kwriteconfig6 &> /dev/null; then
    echo "Applying lock screen wallpaper to KDE Plasma..."
    sudo -u "$TARGET_USER" kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --key wallpaperplugin "org.kde.image"
    sudo -u "$TARGET_USER" kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file:///home/smilo/288.jpg"
  fi
fi

echo "Configuring /etc/default/grub..."
if grep -q '^GRUB_TERMINAL_OUTPUT="console"' /etc/default/grub; then
  sed -i 's/^GRUB_TERMINAL_OUTPUT="console"/#GRUB_TERMINAL_OUTPUT="console"/' /etc/default/grub
  echo "Commented out GRUB_TERMINAL_OUTPUT=\"console\""
fi

THEME_PATH="/usr/share/grub/themes/catppuccin-mocha-grub-theme/theme.txt"
if grep -q '^GRUB_THEME=' /etc/default/grub; then
  sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_PATH\"|" /etc/default/grub
  echo "Updated existing GRUB_THEME setting to Mocha flavor."
else
  echo "GRUB_THEME=\"$THEME_PATH\"" >> /etc/default/grub
  echo "Added GRUB_THEME setting for Mocha flavor."
fi

echo "Regenerating GRUB configuration..."
grub2-mkconfig -o /boot/grub2/grub.cfg
echo "============================================="

# ----------------------------------------------------------------------
# 15. Configure Catppuccin KDE Theme, GTK Theme, Konsole Theme, and Ghostty Theme
# ----------------------------------------------------------------------
echo "STEP 15: Installing Catppuccin KDE, GTK, Konsole, and Ghostty themes..."

# Install compile dependencies
dnf install -y sassc unzip wget tar

# 15a. KDE Theme
echo "Installing Catppuccin KDE theme..."
KDE_REPO_DIR="/tmp/catppuccin-kde"
rm -rf "$KDE_REPO_DIR"
sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/catppuccin/kde "$KDE_REPO_DIR"
sudo -u "$TARGET_USER" bash -c "cd $KDE_REPO_DIR && chmod +x install.sh && ./install.sh 1 4 1 auto" || true
rm -rf "$KDE_REPO_DIR"

# 15b. Konsole Color Schemes
echo "Installing Catppuccin Konsole color schemes..."
KONSOLE_DIR="$TARGET_HOME/.local/share/konsole"
sudo -u "$TARGET_USER" mkdir -p "$KONSOLE_DIR"
KONSOLE_REPO_DIR="/tmp/catppuccin-konsole"
rm -rf "$KONSOLE_REPO_DIR"
sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/catppuccin/konsole "$KONSOLE_REPO_DIR"
sudo -u "$TARGET_USER" cp "$KONSOLE_REPO_DIR"/themes/*.colorscheme "$KONSOLE_DIR/" || true
rm -rf "$KONSOLE_REPO_DIR"

# 15c. GTK Theme
echo "Installing Catppuccin GTK theme..."
GTK_THEME_DIR="$TARGET_HOME/.themes"
sudo -u "$TARGET_USER" mkdir -p "$GTK_THEME_DIR"
GTK_REPO_DIR="/tmp/Catppuccin-GTK-Theme"
rm -rf "$GTK_REPO_DIR"
sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme.git "$GTK_REPO_DIR"
# Run the installer as TARGET_USER in batch mode
sudo -u "$TARGET_USER" env BATCH_MODE=true bash "$GTK_REPO_DIR/themes/install.sh" -a mauve -m dark || true
rm -rf "$GTK_REPO_DIR"

# 15d. Cursor compatibility symlink
echo "Creating cursor compatibility symlink..."
if [ ! -e "$TARGET_HOME/.icons" ]; then
  sudo -u "$TARGET_USER" ln -s "$TARGET_HOME/.local/share/icons" "$TARGET_HOME/.icons"
fi

# 15e. Ghostty Theme
echo "Configuring Catppuccin theme for Ghostty..."
GHOSTTY_CONFIG_DIR="$TARGET_HOME/.config/ghostty"
sudo -u "$TARGET_USER" mkdir -p "$GHOSTTY_CONFIG_DIR"
GHOSTTY_CONFIG_FILE="$GHOSTTY_CONFIG_DIR/config"
if [ ! -f "$GHOSTTY_CONFIG_FILE" ]; then
  sudo -u "$TARGET_USER" touch "$GHOSTTY_CONFIG_FILE"
fi
if ! grep -q "^theme =" "$GHOSTTY_CONFIG_FILE"; then
  sudo -u "$TARGET_USER" sh -c "echo 'theme = Catppuccin Mocha' >> '$GHOSTTY_CONFIG_FILE'"
else
  sudo -u "$TARGET_USER" sed -i 's/^theme =.*/theme = Catppuccin Mocha/' "$GHOSTTY_CONFIG_FILE"
fi

echo "Catppuccin KDE, GTK, Konsole, and Ghostty themes installed/configured."
echo "============================================="

# ----------------------------------------------------------------------
# 16. Install AnyDesk
# ----------------------------------------------------------------------
echo "STEP 16: Installing AnyDesk..."
cat << 'EOF' > /etc/yum.repos.d/AnyDesk-Fedora.repo
[anydesk]
name=AnyDesk Fedora - stable
baseurl=http://rpm.anydesk.com/fedora/$basearch/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://keys.anydesk.com/repos/RPM-GPG-KEY
EOF

dnf install -y anydesk || true
echo "AnyDesk installed successfully."
echo "============================================="

echo "Setup completed successfully!"
echo "Note: To install the graphical Antigravity IDE, download the RPM directly from: https://antigravity.google/download"
echo "Please reboot your system for Nvidia drivers and other changes to take full effect."
echo "============================================="
