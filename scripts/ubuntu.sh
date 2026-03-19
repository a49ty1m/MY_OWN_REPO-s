#!/bin/bash

set -euo pipefail
umask 022

export DEBIAN_FRONTEND=noninteractive

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
INSTALL_FRESH=true
INSTALL_EZA=true
INSTALL_ZOXIDE=true
INSTALL_NERD_FONT=true

# Nerd Font config
NERD_FONT_NAME="Hack"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip"
NERD_FONT_TERMINAL_FACE="Hack Nerd Font Mono"
NERD_FONT_SIZE="12"

LOG_FILE="$HOME/.local/state/ubuntu-kvm-setup.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/ubuntu-kvm-setup.lock"

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

log_info() { echo "[$(date '+%H:%M:%S')] [INFO] $1"; }
log_warn() { echo "[$(date '+%H:%M:%S')] [WARN] $1"; }

# Retry wrapper for flaky network commands (3 attempts, 5s delay)
retry() {
    local n=1 max=3 delay=5
    while true; do
        "$@" && return 0
        if (( n >= max )); then
            log_warn "Command failed after $max attempts: $*"
            return 1
        fi
        log_warn "Attempt $n/$max failed. Retrying in ${delay}s..."
        sleep $delay
        (( n++ ))
    done
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

acquire_lock() {
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        if [ -f "$LOCK_DIR/pid" ]; then
            lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
            if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
                log_warn "Removing stale setup lock from dead PID $lock_pid"
                rm -rf "$LOCK_DIR"
                mkdir "$LOCK_DIR"
            else
                die "Another setup instance appears to be running (lock: $LOCK_DIR)."
            fi
        else
            die "Another setup instance appears to be running (lock: $LOCK_DIR)."
        fi
    fi
    echo "$$" > "$LOCK_DIR/pid"
}

release_lock() {
    if [ -d "$LOCK_DIR" ]; then
        rm -rf "$LOCK_DIR"
    fi
}

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
    STEP_FAIL=$((STEP_FAIL + 1))
    echo -e "${RED}[FAIL]${NC} ${CURRENT_STEP:-unknown step} (line $1)"
}

die() {
    local msg="$1"
    SCRIPT_FAILED=1
    STEP_FAIL=$((STEP_FAIL + 1))
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

# ---------------------------------------------------------------------------
# Interactive feature-selection menu
# Shown at startup so the user can toggle flags before anything runs.
# Skipped automatically when stdin is not a terminal (CI / piped usage).
# ---------------------------------------------------------------------------
show_menu() {
    local choice
    _flag() { [ "$1" = true ] && echo -e "${GREEN}[ON] ${NC}" || echo -e "${RED}[OFF]${NC}"; }

    while true; do
        clear
        echo -e "${BLUE}=============================================${NC}"
        echo -e "${BLUE}      Ubuntu Setup — Feature Selection       ${NC}"
        echo -e "${BLUE}=============================================${NC}"
        echo
        printf "  %2s) %s  eza (modern ls replacement)\n"              "1"  "$(_flag "$INSTALL_EZA")"
        printf "  %2s) %s  zoxide (smarter cd)\n"                      "2"  "$(_flag "$INSTALL_ZOXIDE")"
        printf "  %2s) %s  MariaDB\n"                                  "3"  "$(_flag "$INSTALL_MARIADB")"
        printf "  %2s) %s  DB Hardening (mysql_secure_installation)\n" "4"  "$(_flag "$RUN_DB_HARDENING")"
        printf "  %2s) %s  Brave Browser\n"                            "5"  "$(_flag "$INSTALL_BRAVE")"
        printf "  %2s) %s  Snap Apps (Discord, Telegram)\n"            "6"  "$(_flag "$INSTALL_SNAP_APPS")"
        printf "  %2s) %s  KVM Host Setup\n"                           "7"  "$(_flag "$INSTALL_KVM_HOST")"
        printf "  %2s) %s  Fresh Shell Prompt\n"                       "8"  "$(_flag "$INSTALL_FRESH")"
        printf "  %2s) %s  Catppuccin Theme\n"                         "9"  "$(_flag "$INSTALL_THEME")"
        printf "  %2s) %s  Nerd Font (%s)\n"                          "10"  "$(_flag "$INSTALL_NERD_FONT")" "$NERD_FONT_NAME"
        echo
        echo -e "   ${GREEN}r)${NC}  Run setup with current settings"
        echo -e "   ${GREEN}a)${NC}  Enable ALL features"
        echo -e "   ${YELLOW}n)${NC}  Disable ALL features"
        echo -e "   ${RED}q)${NC}  Quit"
        echo
        read -rp "  Choose [1-10 / r / a / n / q]: " choice
        case "$choice" in
            1)  if [ "$INSTALL_EZA"       = true ]; then INSTALL_EZA=false;       else INSTALL_EZA=true;       fi ;;
            2)  if [ "$INSTALL_ZOXIDE"    = true ]; then INSTALL_ZOXIDE=false;    else INSTALL_ZOXIDE=true;    fi ;;
            3)  if [ "$INSTALL_MARIADB"   = true ]; then INSTALL_MARIADB=false;   else INSTALL_MARIADB=true;   fi ;;
            4)  if [ "$RUN_DB_HARDENING"  = true ]; then RUN_DB_HARDENING=false;  else RUN_DB_HARDENING=true;  fi ;;
            5)  if [ "$INSTALL_BRAVE"     = true ]; then INSTALL_BRAVE=false;     else INSTALL_BRAVE=true;     fi ;;
            6)  if [ "$INSTALL_SNAP_APPS" = true ]; then INSTALL_SNAP_APPS=false; else INSTALL_SNAP_APPS=true; fi ;;
            7)  if [ "$INSTALL_KVM_HOST"  = true ]; then INSTALL_KVM_HOST=false;  else INSTALL_KVM_HOST=true;  fi ;;
            8)  if [ "$INSTALL_FRESH"     = true ]; then INSTALL_FRESH=false;     else INSTALL_FRESH=true;     fi ;;
            9)  if [ "$INSTALL_THEME"     = true ]; then INSTALL_THEME=false;     else INSTALL_THEME=true;     fi ;;
            10) if [ "$INSTALL_NERD_FONT" = true ]; then INSTALL_NERD_FONT=false; else INSTALL_NERD_FONT=true; fi ;;
            r|R)
                echo
                echo -e "${GREEN}  Starting setup...${NC}"
                sleep 1
                return 0
                ;;
            a|A)
                INSTALL_EZA=true; INSTALL_ZOXIDE=true; INSTALL_MARIADB=true
                RUN_DB_HARDENING=true; INSTALL_BRAVE=true; INSTALL_SNAP_APPS=true
                INSTALL_KVM_HOST=true; INSTALL_FRESH=true; INSTALL_THEME=true
                INSTALL_NERD_FONT=true
                ;;
            n|N)
                INSTALL_EZA=false; INSTALL_ZOXIDE=false; INSTALL_MARIADB=false
                RUN_DB_HARDENING=false; INSTALL_BRAVE=false; INSTALL_SNAP_APPS=false
                INSTALL_KVM_HOST=false; INSTALL_FRESH=false; INSTALL_THEME=false
                INSTALL_NERD_FONT=false
                ;;
            q|Q)
                echo "  Exiting."
                exit 0
                ;;
            *)
                echo -e "${YELLOW}  Invalid option. Press Enter to continue.${NC}"
                read -r
                ;;
        esac
    done
}

# Only show the menu when running interactively.
if [ -t 0 ]; then
    show_menu
fi

trap 'on_error $LINENO' ERR

acquire_lock

# Keep sudo credentials alive in the background for long-running steps.
sudo -v
while true; do sudo -n true; sleep 55; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null; release_lock; print_summary' EXIT

start_step "Pre-flight checks"
if [ "$EUID" -eq 0 ]; then
    die "Do not run this script as root. Run as your normal user."
fi

if ! grep -qi "ubuntu" /etc/os-release; then
    die "This script is intended for Ubuntu host systems."
fi

if ! getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    log_warn "Network/DNS check failed for archive.ubuntu.com. apt may fail."
fi
pass_step

log_info "Starting Ubuntu host setup for Kali-in-KVM workflow"
log_info "Log file: $LOG_FILE"

start_step "1. System update and core packages"
retry sudo apt-get update
retry sudo apt-get upgrade -y
retry sudo apt-get install -y zsh tldr ncdu git git-lfs curl vim nano vlc gparted calibre gh \
build-essential gcc g++ make fzf bat wget gpg gnome-tweaks btop duf unzip \
python3 python3-pip software-properties-common ca-certificates
pass_step

start_step "2. Fastfetch install"
if ! grep -Rqs "ppa.launchpadcontent.net/zhangsongcui3371/fastfetch/ubuntu" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    retry sudo apt-get update
else
    log_info "Fastfetch PPA already configured"
fi

retry sudo apt-get install -y fastfetch
pass_step

start_step "3. eza installation"
if [ "$INSTALL_EZA" = true ]; then
    if command_exists eza; then
        log_info "eza is already installed"
    else
        if apt-cache show eza >/dev/null 2>&1; then
            retry sudo apt-get install -y eza
        else
            if ! grep -Rqs "deb.gierens.de" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | sudo gpg --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
                echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
                | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
                sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
                retry sudo apt-get update
            fi
            retry sudo apt-get install -y eza
        fi
    fi
    pass_step
else
    log_info "eza install disabled"
    skip_step
fi

start_step "4. zoxide installation"
if [ "$INSTALL_ZOXIDE" = true ]; then
    if command_exists zoxide; then
        log_info "zoxide is already installed"
    else
        if apt-cache show zoxide >/dev/null 2>&1; then
            retry sudo apt-get install -y zoxide
        else
            log_info "zoxide not in apt repos, installing via official script..."
            retry bash -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
        fi
    fi
    pass_step
else
    log_info "zoxide install disabled"
    skip_step
fi

start_step "5. MariaDB setup"
if [ "$INSTALL_MARIADB" = true ]; then
    retry sudo apt-get install -y mariadb-server mariadb-client mycli
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

start_step "6. Brave browser install"
if [ "$INSTALL_BRAVE" = true ]; then
    if ! command_exists brave-browser; then
        log_info "Installing Brave Stable..."
        retry bash -c 'curl -fsSL https://dl.brave.com/install.sh | sh'
    else
        log_info "Brave Stable already installed"
    fi

    if ! command_exists brave-browser-nightly; then
        log_info "Installing Brave Nightly..."
        retry bash -c 'curl -fsSL https://dl.brave.com/install.sh | CHANNEL=nightly sh'
    else
        log_info "Brave Nightly already installed"
    fi
    pass_step
else
    log_info "Brave install disabled"
    skip_step
fi

start_step "7. Snap applications"
if [ "$INSTALL_SNAP_APPS" = true ]; then
    if command_exists snap; then
        sudo snap refresh

        for app in discord telegram-desktop; do
            if snap list "$app" >/dev/null 2>&1; then
                sudo snap refresh "$app" || log_warn "$app refresh failed"
            else
                sudo snap install "$app" || log_warn "$app install failed"
            fi
        done
        pass_step
    else
        log_warn "snap command not found; skipping Snap applications step"
        skip_step
    fi
else
    log_info "Snap app setup disabled"
    skip_step
fi

start_step "8. Git configuration"
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
pass_step

start_step "9. KVM host setup (Ubuntu host for Kali guest)"
if [ "$INSTALL_KVM_HOST" = true ]; then
    if [ "$(grep -Ec '(vmx|svm)' /proc/cpuinfo)" -eq 0 ]; then
        log_warn "CPU virtualization flags (vmx/svm) not detected. Check BIOS/UEFI virtualization settings."
    fi

    retry sudo apt-get install -y qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
    virt-manager virtinst libosinfo-bin bridge-utils cpu-checker ovmf swtpm dnsmasq-base \
    spice-client-gtk

    if command_exists kvm-ok; then
        kvm-ok || log_warn "kvm-ok reported issues; verify BIOS virtualization and kernel modules"
    else
        log_warn "kvm-ok not found; install/check cpu-checker package manually if needed"
    fi

    # GPU / 3D Acceleration Support
    log_info "Configuring GPU access for 3D acceleration..."
    for grp in libvirt kvm render video; do
        if ! id -nG "$USER" | grep -qw "$grp"; then
            sudo usermod -aG "$grp" "$USER"
        fi
    done

    # Grant libvirt-qemu access to GPU nodes
    if id libvirt-qemu >/dev/null 2>&1; then
        sudo usermod -aG render,video libvirt-qemu
    fi

    # Fix AppArmor blocking GPU access for QEMU
    APPARMOR_LIBVIRT_CONF="/etc/apparmor.d/abstractions/libvirt-qemu"
    if [ -f "$APPARMOR_LIBVIRT_CONF" ]; then
        log_info "Updating AppArmor for GPU access..."
        if ! grep -q "/dev/dri/" "$APPARMOR_LIBVIRT_CONF"; then
            sudo bash -c "printf '\n  # GPU 3D acceleration\n  /dev/dri/renderD* rw,\n  /dev/dri/ r,\n  /usr/share/libdrm/ r,\n  /usr/share/libdrm/** r,\n' >> $APPARMOR_LIBVIRT_CONF"
            # Optional: NVIDIA specific library access if driver is detected
            if nvidia-smi >/dev/null 2>&1; then
                sudo bash -c "printf '  /dev/nvidia* rw,\n  /usr/share/glvnd/egl_vendor.d/ r,\n  /usr/share/glvnd/egl_vendor.d/** r,\n  /usr/share/egl/egl_external_platform.d/ r,\n  /usr/share/egl/egl_external_platform.d/** r,\n  /usr/lib/x86_64-linux-gnu/libnvidia-egl* r,\n  /usr/lib/x86_64-linux-gnu/libEGL_nvidia* r,\n' >> $APPARMOR_LIBVIRT_CONF"
                # Ensure GBM library for NVIDIA EGL is present
                retry sudo apt-get install -y libnvidia-egl-gbm1 || true
            fi
            sudo systemctl reload apparmor
        fi
    fi

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

start_step "10. Zsh and Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh..."
    omz_installer="$(mktemp)"
    retry curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_installer"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$omz_installer" --unattended
    rm -f "$omz_installer"
fi

mkdir -p "$ZSH_CUSTOM_DIR/plugins"

if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
fi
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-history-substring-search" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM_DIR/plugins/zsh-history-substring-search"
fi
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-completions" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM_DIR/plugins/zsh-completions"
fi

if [ ! -f "$HOME/.zshrc" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
fi

if grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="robbyrussell"|' "$HOME/.zshrc"
else
    echo 'ZSH_THEME="robbyrussell"' >> "$HOME/.zshrc"
fi

if grep -q '^plugins=(' "$HOME/.zshrc"; then
    sed -i 's|^plugins=.*|plugins=(git sudo fzf z extract dirhistory copypath copyfile history command-not-found zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-syntax-highlighting)|' "$HOME/.zshrc"
else
    echo 'plugins=(git sudo fzf z extract dirhistory copypath copyfile history command-not-found zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-syntax-highlighting)' >> "$HOME/.zshrc"
fi

# Add eza and bat aliases if not already present.
if ! grep -q 'alias ls=' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" << 'ALIASES'

# --- Custom aliases ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first'
alias lt='eza --tree --icons --level=2'
if command -v batcat >/dev/null 2>&1; then
    alias cat='batcat --paging=never'
elif command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi
ALIASES
fi

# Add zoxide shell integration if installed and not already hooked in.
if [ "$INSTALL_ZOXIDE" = true ] && ! grep -q 'zoxide init' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" << 'ZOXIDE_INIT'

# --- zoxide (smarter cd) ---
eval "$(zoxide init zsh)"
ZOXIDE_INIT
fi
pass_step

start_step "11. Fresh shell prompt setup"
if [ "$INSTALL_FRESH" = true ]; then
    if command_exists fresh; then
        log_info "fresh is already installed"
    else
        retry bash -c 'curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh'
    fi
    pass_step
else
    log_info "Fresh setup disabled"
    skip_step
fi

start_step "12. Catppuccin theme setup"
if [ "$INSTALL_THEME" = true ]; then
    mkdir -p "$HOME/.themes" "$HOME/.icons"

    theme_tmp_dir="$(mktemp -d)"

    (
        cd "$theme_tmp_dir" || exit
        git clone --depth 1 https://github.com/catppuccin/gtk.git
        cd gtk
        python3 install.py mocha blue
    )

    log_info "Installing Papirus icons and applying Catppuccin flavor..."
    if ! grep -Rqs "ppa.launchpadcontent.net/papirus/papirus/ubuntu" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        sudo add-apt-repository -y ppa:papirus/papirus
        retry sudo apt-get update
    fi
    retry sudo apt-get install -y papirus-icon-theme

    papirus_folders_cmd=""
    if command_exists papirus-folders; then
        papirus_folders_cmd="$(command -v papirus-folders)"
    else
        papirus_folders_cmd="$theme_tmp_dir/papirus-folders"
        curl -fsSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders -o "$papirus_folders_cmd"
        chmod +x "$papirus_folders_cmd"
    fi

    (
        cd "$theme_tmp_dir" || exit
        git clone --depth 1 https://github.com/catppuccin/papirus-folders.git
        cd papirus-folders
        sudo cp -r src/* /usr/share/icons/Papirus
        "$papirus_folders_cmd" -C cat-mocha-blue --theme Papirus-Dark
    )

    log_info "Installing Catppuccin cursor theme..."
    cursor_zip="$theme_tmp_dir/catppuccin-mocha-blue-cursors.zip"
    curl -fsSL https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-blue-cursors.zip -o "$cursor_zip"
    unzip -o "$cursor_zip" -d "$HOME/.icons"

    log_info "Installing Catppuccin theme for btop..."
    btop_theme_dir="$HOME/.config/btop/themes"
    btop_conf_file="$HOME/.config/btop/btop.conf"
    mkdir -p "$btop_theme_dir"
    curl -fsSL https://raw.githubusercontent.com/catppuccin/btop/main/themes/catppuccin_mocha.theme \
        -o "$btop_theme_dir/catppuccin_mocha.theme"

    mkdir -p "$(dirname "$btop_conf_file")"
    if [ ! -f "$btop_conf_file" ]; then
        printf 'color_theme = "catppuccin_mocha"\n' > "$btop_conf_file"
    elif grep -q '^color_theme\s*=\s*"' "$btop_conf_file"; then
        sed -i 's|^color_theme\s*=\s*".*"|color_theme = "catppuccin_mocha"|' "$btop_conf_file"
    else
        printf '\ncolor_theme = "catppuccin_mocha"\n' >> "$btop_conf_file"
    fi

    if [ -n "${DISPLAY:-}" ] && command_exists gsettings; then
        log_info "Installing Catppuccin theme for GNOME Terminal..."
        curl -fsSL https://raw.githubusercontent.com/catppuccin/gnome-terminal/v1.0.0/install.py | python3 -

        gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-blue-standard+default"
        gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
        gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-mocha-blue-cursors"
    else
        log_warn "Skipping gsettings/GNOME Terminal theme apply (no GUI session detected)."
    fi

    rm -rf "$theme_tmp_dir"
    pass_step
else
    log_info "Theme setup disabled"
    skip_step
fi

start_step "13. Nerd Font install for terminal"
if [ "$INSTALL_NERD_FONT" = true ]; then
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_TARGET_DIR="$FONT_DIR/${NERD_FONT_NAME}NerdFont"
    TERMINAL_FONT="${NERD_FONT_TERMINAL_FACE} ${NERD_FONT_SIZE}"

    font_tmp_dir="$(mktemp -d)"
    font_zip="$font_tmp_dir/${NERD_FONT_NAME}.zip"

    log_info "Reinstalling ${NERD_FONT_NAME} Nerd Font and replacing existing files..."
    rm -rf "$FONT_TARGET_DIR"
    mkdir -p "$FONT_TARGET_DIR"
    retry curl -fL "$NERD_FONT_URL" -o "$font_zip"
    unzip -o "$font_zip" -d "$font_tmp_dir"

    # Move only actual font files into Ubuntu's user font folder.
    find "$font_tmp_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec mv -f {} "$FONT_TARGET_DIR/" \;
    fc-cache -fv "$FONT_DIR"
    rm -rf "$font_tmp_dir"

    # Apply Nerd Font to GNOME interface and current GNOME Terminal profile.
    if [ -n "${DISPLAY:-}" ] && command_exists gsettings; then
        gsettings set org.gnome.desktop.interface monospace-font-name "$TERMINAL_FONT" || true

        profile_id="$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")"
        if [ -n "$profile_id" ]; then
            gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile_id}/" use-system-font false || true
            gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile_id}/" font "$TERMINAL_FONT" || true
        else
            log_warn "Could not resolve GNOME Terminal default profile for font apply."
        fi
    else
        log_warn "Skipping Nerd Font terminal apply (no GUI session detected)."
    fi

    pass_step
else
    log_info "Nerd Font install disabled"
    skip_step
fi

start_step "14. Final cleanup"
sudo apt-get autoremove -y
sudo apt-get autoclean -y
zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" != "$zsh_path" ]; then
    sudo chsh -s "$zsh_path" "$USER"
else
    log_info "Default shell is already zsh"
fi
pass_step

start_step "15. Post-setup helpers for Kali guest"
cat << 'EOF'
Inside Kali guest (recommended), run:
  sudo apt update && sudo apt install -y qemu-guest-agent spice-vdagent
  sudo systemctl enable --now qemu-guest-agent

For 9p shared folder in Kali /etc/fstab:
  kali_share /home/<kali-user>/Desktop/SharedFolder 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail 0 0
EOF
pass_step

log_info "Opening VS Code and Obsidian websites in Brave..."
if command_exists brave-browser && [ -n "${DISPLAY:-}" ]; then
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