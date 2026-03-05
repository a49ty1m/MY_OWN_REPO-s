#!/bin/bash

set -euo pipefail

# --- CONFIGURATION ---
USER_NAME="a49ty1m"
USER_EMAIL="a4920251m@gmail.com"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Feature flags
INSTALL_MARIADB=true
RUN_DB_HARDENING=false
INSTALL_BRAVE=true
INSTALL_SNAP_APPS=true
INSTALL_KVM_HOST=true
INSTALL_THEME=true

LOG_FILE="$HOME/.local/state/ubuntu-kvm-setup.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STEP_TOTAL=0
STEP_PASS=0
STEP_SKIP=0
STEP_FAIL=0
CURRENT_STEP=""
SCRIPT_FAILED=0

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_step() { echo; echo "========== $1 =========="; }

start_step() {
    STEP_TOTAL=$((STEP_TOTAL + 1))
    CURRENT_STEP="$1"
    echo
    echo -e "${BLUE}>>> [STEP $STEP_TOTAL] $CURRENT_STEP${NC}"
}

pass_step() {
    STEP_PASS=$((STEP_PASS + 1))
    echo -e "${GREEN}[PASS]${NC} $CURRENT_STEP"
}

skip_step() {
    STEP_SKIP=$((STEP_SKIP + 1))
    echo -e "${YELLOW}[SKIP]${NC} $CURRENT_STEP"
}

on_error() {
    SCRIPT_FAILED=1
    STEP_FAIL=1
    echo -e "${RED}[FAIL]${NC} ${CURRENT_STEP:-unknown step} (line $1)"
}

die() {
    local msg="$1"
    SCRIPT_FAILED=1
    STEP_FAIL=1
    echo -e "${RED}[FAIL]${NC} ${CURRENT_STEP:-unknown step}: $msg"
    exit 1
}

print_summary() {
    echo
    echo "-----------------------------------------------------------"
    echo "STEP SUMMARY"
    echo "Total: $STEP_TOTAL | Passed: $STEP_PASS | Skipped: $STEP_SKIP | Failed: $STEP_FAIL"
    if [ "$SCRIPT_FAILED" -eq 1 ]; then
        echo -e "${RED}Status: FAILED${NC}"
    else
        echo -e "${GREEN}Status: SUCCESS${NC}"
    fi
    echo "-----------------------------------------------------------"
}

trap 'on_error $LINENO' ERR
trap 'print_summary' EXIT

start_step "Pre-flight checks"
if [ "$EUID" -eq 0 ]; then
    die "Do not run this script as root. Run as your normal user."
fi

if ! grep -qi "ubuntu" /etc/os-release; then
    die "This script is intended for Ubuntu host systems."
fi

if ! sudo -v; then
    die "Sudo credentials are required."
fi

if ! getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    log_warn "Network/DNS check failed for archive.ubuntu.com. apt may fail."
fi
pass_step

log_info "Starting Ubuntu host setup for Kali-in-KVM workflow"
log_info "Log file: $LOG_FILE"

start_step "1. System update and core packages"
sudo apt update && sudo apt upgrade -y
sudo apt-get install -y zsh tldr ncdu git git-lfs curl vim nano vlc gparted calibre gh \
build-essential gcc g++ make fzf neofetch fonts-powerline wget gpg gnome-tweaks unzip \
python3 python3-pip software-properties-common ca-certificates
pass_step

start_step "2. MariaDB setup"
if [ "$INSTALL_MARIADB" = true ]; then
    sudo apt install -y mariadb-server mariadb-client mycli
    sudo systemctl enable --now mariadb

    if [ "$RUN_DB_HARDENING" = true ]; then
        echo "Running mysql_secure_installation... Please follow the prompts."
        sudo mysql_secure_installation
    else
        log_warn "Skipping mysql_secure_installation (RUN_DB_HARDENING=false)."
        log_warn "Run manually later with: sudo mysql_secure_installation"
    fi
    pass_step
else
    log_info "MariaDB setup disabled"
    skip_step
fi

start_step "3. Brave install (kept as requested)"
if [ "$INSTALL_BRAVE" = true ]; then
    echo "Installing Brave Stable and Nightly..."
    curl -fsS https://dl.brave.com/install.sh | sh
    curl -fsS https://dl.brave.com/install.sh | CHANNEL=nightly sh
    pass_step
else
    log_info "Brave install disabled"
    skip_step
fi

start_step "4. Snap applications"
if [ "$INSTALL_SNAP_APPS" = true ]; then
    sudo snap refresh
    sudo snap install discord || log_warn "discord already installed or failed"
    sudo snap install telegram-desktop || log_warn "telegram-desktop already installed or failed"
    pass_step
else
    log_info "Snap app setup disabled"
    skip_step
fi

start_step "5. Git configuration"
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
pass_step

start_step "6. KVM host setup (Ubuntu host for Kali guest)"
if [ "$INSTALL_KVM_HOST" = true ]; then
    if [ "$(egrep -c '(vmx|svm)' /proc/cpuinfo)" -eq 0 ]; then
        log_warn "CPU virtualization flags (vmx/svm) not detected. Check BIOS/UEFI virtualization settings."
    fi

    sudo apt install -y qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
    virt-manager virtinst libosinfo-bin bridge-utils cpu-checker ovmf swtpm dnsmasq-base \
    spice-client-gtk

    kvm-ok || log_warn "kvm-ok reported issues; verify BIOS virtualization and kernel modules"

    sudo adduser "$USER" libvirt || true
    sudo adduser "$USER" kvm || true
    sudo systemctl enable --now libvirtd

    # Ensure default libvirt network is available for NAT-based Kali VM networking.
    if ! sudo virsh net-info default >/dev/null 2>&1; then
        log_warn "Default libvirt network not found. You may need to define it in virt-manager."
    else
        sudo virsh net-autostart default || true
        sudo virsh net-start default || true
    fi

    log_info "KVM host setup complete"
    pass_step
else
    log_info "KVM host setup disabled"
    skip_step
fi

start_step "7. Zsh and Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

mkdir -p "$ZSH_CUSTOM_DIR/plugins"

if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
fi

if [ ! -f "$HOME/.zshrc" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
fi

if grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="agnoster"|' "$HOME/.zshrc"
else
    echo 'ZSH_THEME="agnoster"' >> "$HOME/.zshrc"
fi

if grep -q '^plugins=(' "$HOME/.zshrc"; then
    sed -i 's|^plugins=.*|plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)|' "$HOME/.zshrc"
else
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)' >> "$HOME/.zshrc"
fi
pass_step

start_step "8. Catppuccin theme setup"
if [ "$INSTALL_THEME" = true ]; then
    mkdir -p "$HOME/.themes" "$HOME/.icons"

    (
        cd /tmp || exit
        rm -rf gtk
        git clone --depth 1 https://github.com/catppuccin/gtk.git
        cd gtk
        python3 install.py mocha blue
    )

    echo "Installing Papirus icons and applying Catppuccin flavor..."
    sudo add-apt-repository -y ppa:papirus/papirus
    sudo apt update
    sudo apt install -y papirus-icon-theme
    (
        cd /tmp || exit
        rm -rf papirus-folders
        git clone --depth 1 https://github.com/catppuccin/papirus-folders.git
        cd papirus-folders
        sudo cp -r src/* /usr/share/icons/Papirus
        ./papirus-folders -C cat-mocha-blue --theme Papirus-Dark
    )

    echo "Installing Catppuccin cursor theme..."
    curl -LOsS https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-blue-cursors.zip
    unzip -o catppuccin-mocha-blue-cursors.zip -d "$HOME/.icons"
    rm -f catppuccin-mocha-blue-cursors.zip

    echo "Installing Catppuccin theme for GNOME Terminal..."
    curl -L https://raw.githubusercontent.com/catppuccin/gnome-terminal/v1.0.0/install.py | python3 -

    gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-blue-standard+default"
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
    gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-mocha-blue-cursors"
    pass_step
else
    log_info "Theme setup disabled"
    skip_step
fi

start_step "9. Final cleanup"
sudo apt-get autoremove -y
sudo apt-get autoclean -y
sudo chsh -s "$(which zsh)" "$USER"
pass_step

start_step "10. Post-setup helpers for Kali guest"
cat << 'EOF'
Inside Kali guest (recommended), run:
  sudo apt update && sudo apt install -y qemu-guest-agent spice-vdagent
  sudo systemctl enable --now qemu-guest-agent

For 9p shared folder in Kali /etc/fstab:
  kali_share /home/<kali-user>/Desktop/SharedFolder 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail 0 0
EOF
pass_step

echo "Opening VS Code and Obsidian websites in Brave..."
if command -v brave-browser >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    brave-browser https://code.visualstudio.com https://obsidian.md/download &
else
    log_warn "Skipping browser launch (brave-browser missing or no GUI session)."
fi

echo "-----------------------------------------------------------"
echo "SETUP COMPLETE."
echo "1. Reboot Ubuntu host to apply group/shell changes."
echo "2. In Kali guest, install qemu-guest-agent + spice-vdagent."
echo "3. Full log: $LOG_FILE"
echo "-----------------------------------------------------------"