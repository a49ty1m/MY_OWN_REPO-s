# Kali Linux Setup Guide for KVM

> **Why KVM?** KVM (Kernel-based Virtual Machine) offers near-native performance but requires extra configuration for features like clipboard sharing and folder mounting that work out-of-the-box in VirtualBox/VMware.

---

## Part 1: Initial VM Creation

### Step 1: Create the Virtual Machine

| Setting | Recommended Value | Notes |
|---------|-------------------|-------|
| **Installation Method** | ISO image | Download from [kali.org](https://www.kali.org/get-kali/) |
| **OS Type** | Debian 12/13 | Select the closest match available |
| **RAM** | 8192 MiB (8 GB) | Minimum 4 GB; 8 GB recommended for smooth operation |
| **CPU Cores** | 8 cores | Adjust based on your host CPU |
| **Disk Space** | 60–96 GiB | 60 GiB minimum; 96 GiB if running multiple tools |

### Step 2: Complete Installation

1. Boot from the ISO and follow the Kali installer prompts
2. Choose your preferred desktop environment:
   - **Xfce** — Lightweight, fast, low resource usage (recommended for VMs)
   - **GNOME** — Feature-rich, better clipboard integration with KVM
   - **Hybrid approach:** Install GNOME as display manager but use Xfce as desktop session for better performance while retaining GNOME's integration benefits
3. Set up your user account and complete the installation
4. Reboot into your new Kali system

---

## Part 2: Post-Installation Configuration (KVM-Specific)

### Phase A: Enable Clipboard & Display Integration

These agents enable essential VM features that make Kali usable:

| Agent | Purpose |
|-------|--------|
| `qemu-guest-agent` | Allows host to communicate with guest (graceful shutdown, freeze/thaw for snapshots) |
| `spice-vdagent` | Enables clipboard sharing, automatic screen resizing, and drag-and-drop |

**1. Update repositories and install guest agents:**

```bash
sudo apt update && sudo apt install -y qemu-guest-agent spice-vdagent
```

**2. Enable the QEMU guest agent service to start on boot:**

```bash
sudo systemctl enable --now qemu-guest-agent
```

> **Note:** You may need to reboot or log out/in for clipboard sharing to activate.

**Troubleshooting clipboard issues:**
- Ensure SPICE display is selected in virt-manager (not VNC)
- Verify spice-vdagent is running: `systemctl status spice-vdagent`
- Try restarting the service: `sudo systemctl restart spice-vdagent`

---

### Phase B: Set Up Shared Folder (Host ↔ Guest File Transfer)

The 9p virtio filesystem allows direct folder sharing between host and guest without network overhead.

#### Prerequisites: Configure virt-manager (Host Side)

1. Open your VM settings in `virt-manager`
2. Click **Add Hardware** → **Filesystem**
3. Configure as follows:

| Field | Value |
|-------|-------|
| **Type** | mount |
| **Driver** | virtio-9p |
| **Source path** | `/path/to/your/host/folder` (e.g., `/home/user/kali-share`) |
| **Target path** | `kali_share` (this is the mount tag, not a path) |

4. Click **Finish** and start the VM

#### Guest Configuration (Inside Kali)

**1. Create the mount point on your Kali desktop:**

```bash
mkdir -p ~/Desktop/SharedFolder
```

**2. Add a permanent mount entry to `/etc/fstab`:**

This ensures the shared folder mounts automatically on every boot.

```bash
echo "kali_share /home/$(whoami)/Desktop/SharedFolder 9p trans=virtio,version=9p2000.L,rw,_netdev 0 0" | sudo tee -a /etc/fstab
```

| Mount Option | Meaning |
|--------------|--------|
| `trans=virtio` | Use virtio transport layer |
| `version=9p2000.L` | Linux-specific 9p protocol |
| `rw` | Read-write access |
| `_netdev` | Wait for "network" (virtio) before mounting |

**3. Mount the shared folder immediately:**

```bash
sudo mount -a
```

**Verify:** Check that your host files appear in `~/Desktop/SharedFolder`.

**Troubleshooting:**
- If mount fails, verify the target path in virt-manager matches exactly (`kali_share`)
- Check kernel support: `ls /sys/module/ | grep 9p` should show `9p`, `9pnet`, `9pnet_virtio`

---

## Part 3: Complete Kali Setup Script

This script automates the entire post-installation setup. Save as `kali-setup.sh` and run with `bash kali-setup.sh`.

**What it installs:**
- Core utilities (zsh, git, vim, fzf, htop, etc.)
- KVM guest agents (clipboard & display)
- Security tools & wordlists (seclists, rockyou, nmap, burpsuite, metasploit, etc.)
- Brave Browser (Nightly)
- ZSH + Oh My Zsh with plugins
- Catppuccin theme (GTK, icons, cursor)
- Shared folder mount configuration

```bash
#!/bin/bash
set -euo pipefail

# Configuration
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
SHARE_TAG="kali_share"
SHARE_POINT="$HOME/Desktop/SharedFolder"

echo "Starting Kali Linux setup..."

# 1. UPDATE SYSTEM & MODERN TOOLS
echo "[1/8] Updating system and installing base tools..."
sudo apt update && sudo apt upgrade -y
# Note: On Kali, some tools have specific names: bat -> batcat, fd-find -> fdfind
sudo apt install -y zsh tealdeer ncdu git git-lfs curl vim nano build-essential \
gcc g++ make fzf fastfetch fonts-powerline wget gpg unzip terminator htop tree jq \
bat eza ripgrep fd-find tmux p7zip-full python3-pip python3-venv pipx fonts-liberation

# Install fresh
if ! command -v fresh &> /dev/null; then
    echo "Installing fresh..."
    curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh
else
    echo "fresh is already installed, skipping..."
fi

# 2. KVM GUEST AGENTS (For VMs)
echo "[2/8] Installing KVM guest agents..."
sudo apt install -y qemu-guest-agent spice-vdagent
sudo systemctl enable --now qemu-guest-agent spice-vdagent || true

# 3. SECURITY TOOLS & WORDLISTS
echo "[3/8] Installing Kali security tools..."
sudo apt install -y seclists wordlists kali-tools-web kali-tools-passwords \
kali-tools-exploitation kali-tools-sniffing-spoofing nmap metasploit-framework \
gobuster feroxbuster sqlmap nikto john hashcat hydra bloodhound neo4j

# Unzip rockyou if it exists
if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    echo "Unzipping rockyou.txt.gz..."
    sudo gunzip -f /usr/share/wordlists/rockyou.txt.gz
fi

# 4. BRAVE NIGHTLY
echo "[4/8] Installing Brave Nightly..."
if ! command -v brave-browser-nightly &> /dev/null; then
    curl -fsSL https://dl.brave.com/install.sh | CHANNEL=nightly sh
fi

# 5. NODE (NVM) SETUP
echo "[5/8] Setting up NVM..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# Load NVM for the rest of this script session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install 20 --lts || nvm install 20

# 6. ZSH & OH-MY-ZSH SETUP
echo "[6/8] Setting up Zsh and Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Ensure ZSH_CUSTOM_DIR is correctly set if Oh My Zsh was just installed
ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM_DIR/plugins"

function clone_plugin() {
    local repo_url=$1
    local plugin_name=$2
    if [ ! -d "$ZSH_CUSTOM_DIR/plugins/$plugin_name" ]; then
        echo "Cloning plugin: $plugin_name"
        git clone --depth 1 "$repo_url" "$ZSH_CUSTOM_DIR/plugins/$plugin_name"
    fi
}

clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting"

# Configure .zshrc Theme and Plugins
echo "Configuring .zshrc theme and plugins..."
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"

# More robust plugin insertion: adds plugins to the list if they aren't already there
for plugin in zsh-autosuggestions zsh-syntax-highlighting fzf sudo; do
    if ! grep -q "$plugin" "$HOME/.zshrc"; then
        sed -i "/^plugins=(/ s/)/ $plugin)/" "$HOME/.zshrc"
    fi
done

# Add aliases and NVM loading to .zshrc (IDEMPOTENT)
if ! grep -q "Custom Config Added by mysetup.sh" "$HOME/.zshrc"; then
    cat << 'EOF' >> "$HOME/.zshrc"

# Custom Config Added by mysetup.sh
alias cat="batcat"
alias ls="eza --icons"
alias l="eza -lh --icons"
alias la="eza -lah --icons"
alias fd="fdfind"
alias help="tldr"

# NVM Setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Start fastfetch if available
command -v fastfetch >/dev/null && fastfetch
EOF
fi

# 7. PYTHON PIPX TOOLS
echo "[7/8] Installing tools via pipx..."
pipx ensurepath
pipx install impacket || true

# 8. SHARED FOLDER (9p for VMs)
echo "[8/8] Configuring Shared folder..."
mkdir -p "$SHARE_POINT"
if ! grep -q "$SHARE_TAG" /etc/fstab; then
    echo "$SHARE_TAG $SHARE_POINT 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail 0 0" | sudo tee -a /etc/fstab
    sudo mount "$SHARE_POINT" || true
fi

# CLEANUP & FINALIZING
echo "Finalizing setup..."
sudo apt autoremove -y
sudo chsh -s $(which zsh) $USER
tldr --update || true

echo "-----------------------------------------------------------"
echo "KALI SETUP COMPLETE. PLEASE REBOOT."
echo "-----------------------------------------------------------"
```

---

*Last updated: February 2026*