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

# ============================================================
# Color output & logging
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/var/log/mysetup.log"
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log_info()    { echo -e "${GREEN}[✔]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✘]${NC} $1"; }
log_section() {
    echo -e "\n${BOLD}${BLUE}══════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════${NC}"
}

# ============================================================
# Pre-flight checks
# ============================================================
log_section "Pre-flight Checks"

if [ "$EUID" -eq 0 ]; then
    log_error "Do not run this script as root or with sudo!"
    log_error "Run it as your normal user: bash mysetup.sh"
    exit 1
fi

if ! grep -qi "kali" /etc/os-release 2>/dev/null; then
    log_error "This script is designed for Kali Linux only."
    exit 1
fi

log_info "Running as user: $USER (home: $HOME)"
log_info "OS check passed: Kali Linux detected"
log_info "Logging output to: $LOG_FILE"

# --- Configuration ---
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
SHARE_TAG="kali_share"
SHARE_POINT="$HOME/Desktop/SharedFolder"

# ============================================================
# [1/8] SYSTEM UPDATE & BASE TOOLS
# ============================================================
log_section "[1/8] Updating system and installing base tools"

sudo apt update && sudo apt upgrade -y
sudo apt install -y zsh tealdeer ncdu git git-lfs curl vim nano build-essential \
gcc g++ make fzf fastfetch fonts-powerline wget gpg unzip terminator htop tree jq \
bat eza ripgrep fd-find tmux p7zip-full python3-pip python3-venv pipx fonts-liberation \
zoxide atuin

if ! command -v fresh &> /dev/null; then
    log_info "Installing fresh..."
    curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh
else
    log_warn "fresh already installed, skipping..."
fi

log_info "Base tools done."

# ============================================================
# [2/8] KVM GUEST AGENTS
# ============================================================
log_section "[2/8] Installing KVM guest agents"

sudo apt install -y qemu-guest-agent spice-vdagent

# FIX: Both qemu-guest-agent AND spice-vdagent have no [Install] section
# so systemctl enable fails for both. Just start them instead.
sudo systemctl start qemu-guest-agent || true
sudo systemctl start spice-vdagent || true

log_info "KVM guest agents configured."

# ============================================================
# [3/8] KALI SECURITY TOOLS & WORDLISTS
# ============================================================
log_section "[3/8] Installing Kali security tools"

sudo apt install -y seclists wordlists kali-tools-web kali-tools-passwords \
kali-tools-exploitation kali-tools-sniffing-spoofing nmap metasploit-framework \
gobuster feroxbuster sqlmap nikto john hashcat hydra bloodhound neo4j

if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    log_info "Unzipping rockyou.txt.gz..."
    sudo gunzip -f /usr/share/wordlists/rockyou.txt.gz
fi

log_info "Security tools done."

# ============================================================
# [4/8] BRAVE NIGHTLY
# ============================================================
log_section "[4/8] Installing Brave Nightly"

if ! command -v brave-browser-nightly &> /dev/null; then
    curl -fsSL https://dl.brave.com/install.sh | CHANNEL=nightly sh
    log_info "Brave Nightly installed."
else
    log_warn "Brave Nightly already installed, skipping..."
fi

# ============================================================
# [5/8] NODE (NVM)
# ============================================================
log_section "[5/8] Setting up NVM and Node"

if [ ! -d "$HOME/.nvm" ] && [ ! -d "$HOME/.config/nvm" ]; then
    log_info "Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# FIX: Newer NVM versions install to ~/.config/nvm (XDG) instead of ~/.nvm.
# Detect whichever path was actually used.
if [ -d "$HOME/.config/nvm" ]; then
    export NVM_DIR="$HOME/.config/nvm"
elif [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
else
    log_error "NVM directory not found after install!"
    exit 1
fi

log_info "NVM directory: $NVM_DIR"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install 20 --lts || nvm install 20
log_info "Node $(node --version) ready."

# ============================================================
# [6/8] ZSH, OH-MY-ZSH & SHELL CONFIG
# ============================================================
log_section "[6/8] Setting up Zsh, Oh My Zsh and shell config"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh..."
    set +e
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
    set -e
    log_info "Oh My Zsh installed."
else
    log_warn "Oh My Zsh already installed, skipping..."
fi

ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM_DIR/plugins" "$ZSH_CUSTOM_DIR/themes"

function clone_plugin() {
    local repo_url=$1
    local plugin_name=$2
    if [ ! -d "$ZSH_CUSTOM_DIR/plugins/$plugin_name" ]; then
        log_info "Cloning plugin: $plugin_name"
        git clone --depth 1 "$repo_url" "$ZSH_CUSTOM_DIR/plugins/$plugin_name"
    else
        log_warn "Plugin $plugin_name already exists, skipping..."
    fi
}

clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting"

# Install Powerlevel10k
if [ ! -d "$ZSH_CUSTOM_DIR/themes/powerlevel10k" ]; then
    log_info "Installing Powerlevel10k theme..."
    git clone --depth 1 https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
else
    log_warn "Powerlevel10k already installed, skipping..."
fi

# Ensure .zshrc exists
if [ ! -f "$HOME/.zshrc" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
fi

# Set theme to Powerlevel10k
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"

# Add plugins
for plugin in zsh-autosuggestions zsh-syntax-highlighting fzf sudo; do
    if ! grep -q "$plugin" "$HOME/.zshrc"; then
        sed -i "/^plugins=(/ s/)/ $plugin)/" "$HOME/.zshrc"
    fi
done

# FIX: NVM installer auto-appends its own source lines to .zshrc pointing to
# the wrong path. Strip them all out before we write our own clean block.
log_info "Cleaning up NVM lines auto-added by installer..."
sed -i '/NVM_DIR/d' "$HOME/.zshrc"
sed -i '/nvm\.sh/d' "$HOME/.zshrc"
sed -i '/bash_completion/d' "$HOME/.zshrc"

# Write custom config block (IDEMPOTENT)
if ! grep -q "Custom Config Added by mysetup.sh" "$HOME/.zshrc"; then
    # FIX: Use the detected NVM_DIR instead of hardcoding ~/.nvm
    cat << EOF >> "$HOME/.zshrc"

# Custom Config Added by mysetup.sh
alias cat="batcat"
alias ls="eza --icons"
alias l="eza -lh --icons"
alias la="eza -lah --icons"
alias fd="fdfind"
alias help="tldr"

# Zoxide (smart cd - use 'z <dir>' to jump anywhere)
eval "\$(zoxide init zsh)"

# Atuin (better ctrl+r shell history search)
eval "\$(atuin init zsh)"

# NVM Setup (path auto-detected during install)
export NVM_DIR="$NVM_DIR"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"

# Start fastfetch in interactive terminals only
[[ \$- == *i* ]] && command -v fastfetch >/dev/null && fastfetch
EOF
    log_info ".zshrc configured."
fi

# ============================================================
# [7/8] PYTHON PIPX TOOLS
# ============================================================
log_section "[7/8] Installing Python tools via pipx"

pipx ensurepath

declare -a PIPX_TOOLS=(
    "impacket"
    "pwntools"
    "volatility3"
    "crackmapexec"
)

for tool in "${PIPX_TOOLS[@]}"; do
    log_info "Installing $tool..."
    pipx install "$tool" || log_warn "$tool already installed or failed, skipping..."
done

log_info "Python tools done."

# ============================================================
# [8/8] SHARED FOLDER & CLEANUP
# ============================================================
log_section "[8/8] Shared folder, cleanup and finalizing"

mkdir -p "$SHARE_POINT"
if ! grep -q "$SHARE_TAG" /etc/fstab; then
    log_info "Adding shared folder to /etc/fstab..."
    echo "$SHARE_TAG $SHARE_POINT 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail 0 0" | \
        sudo tee -a /etc/fstab
fi
sudo mount -a || log_warn "Shared folder mount failed (host share may not be configured yet)"

log_info "Running apt autoremove..."
sudo apt autoremove -y

sudo chsh -s "$(which zsh)" "$USER"
log_info "Default shell set to zsh."

tldr --update || true

echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}   KALI SETUP COMPLETE — PLEASE REBOOT  ${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}After reboot:${NC}"
echo "  • Terminal will launch Powerlevel10k config wizard"
echo "  • Use 'z <dir>' instead of cd (zoxide)"
echo "  • Press Ctrl+R for atuin history search"
echo "  • Full log saved to: $LOG_FILE"
echo ""
```

---

*Last updated: February 2026*