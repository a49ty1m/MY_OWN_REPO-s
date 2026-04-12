#!/bin/bash
# ==============================================================================
# ARCH HOST SETUP SCRIPT (KVM HOST) - FINAL POLISHED VERSION
# Part of the "Twin Script" Framework (Host ↔ Guest)
# ==============================================================================
set -euo pipefail
umask 022

# --- CONFIGURATION & FLAGS ---
USER_NAME="a49ty1m"
USER_EMAIL="a4920251m@gmail.com"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Feature flags
INSTALL_EZA=true
INSTALL_ZOXIDE=true
INSTALL_MARIADB=true
RUN_DB_HARDENING=false
INSTALL_BRAVE=true
INSTALL_SNAP_APPS=true   # On Arch: installs Discord + Telegram via pacman (no snap).
INSTALL_KVM_HOST=true
INSTALL_FRESH=true
INSTALL_THEME=true
INSTALL_NERD_FONT=true
INSTALL_NODE_NVM=true

# Nerd Font config
NERD_FONT_NAME="Hack"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip"
NERD_FONT_TERMINAL_FACE="Hack Nerd Font Mono"
NERD_FONT_SIZE="12"

# --- LOGGING & FRAMEWORK ---
LOG_FILE="$HOME/.local/state/arch-kvm-setup.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/arch-kvm-setup.lock"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
STEP_TOTAL=0; STEP_PASS=0; STEP_SKIP=0; STEP_FAIL=0; SCRIPT_FAILED=0

log_info()  { echo -e "${GREEN}[✔]${NC} [$(date '+%H:%M:%S')] $1"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} [$(date '+%H:%M:%S')] $1"; }
log_error() { echo -e "${RED}[✘]${NC} [$(date '+%H:%M:%S')] $1"; }

retry() {
    local n=1 max=3 delay=5
    while true; do
        "$@" && return 0
        if (( n >= max )); then return 1; fi
        log_warn "Attempt $n/$max failed. Retrying in ${delay}s..."
        sleep $delay; (( n++ ))
    done
}

acquire_lock() {
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log_error "Another setup instance is running (lock: $LOCK_DIR)."; exit 1
    fi
    echo "$$" > "$LOCK_DIR/pid"
}

release_lock() { rm -rf "$LOCK_DIR"; }

start_step() { STEP_TOTAL=$((STEP_TOTAL + 1)); CURRENT_STEP="$1"; echo -e "\n${BOLD}${BLUE}>>> [STEP $STEP_TOTAL] $CURRENT_STEP${NC}"; }
pass_step()  { STEP_PASS=$((STEP_PASS + 1)); }
skip_step()  { STEP_SKIP=$((STEP_SKIP + 1)); echo -e "${YELLOW}[SKIP]${NC} $CURRENT_STEP"; }
on_error()   { SCRIPT_FAILED=1; STEP_FAIL=$((STEP_FAIL + 1)); log_error "Failed: ${CURRENT_STEP:-unknown} (line $1)"; }

print_summary() {
    echo -e "\n${BOLD}--- SETUP SUMMARY ---${NC}"
    echo "Total: $STEP_TOTAL | Passed: $STEP_PASS | Skipped: $STEP_SKIP | Failed: $STEP_FAIL"
    [ "$SCRIPT_FAILED" -eq 0 ] && echo -e "${GREEN}Status: SUCCESS${NC}" || echo -e "${RED}Status: FAILED${NC}"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

python_bin() {
    if command_exists python3; then echo python3; else echo python; fi
}

# Catppuccin GTK installer compatibility patch:
# Upstream install.py currently defines `--link` with `action=argparse.BooleanOptionalAction`
# and `type=bool`, which raises on Python 3.14+.
patch_catppuccin_gtk_installer() {
    local installer_path="$1"
    [ -f "$installer_path" ] || return 0

    "$(python_bin)" - "$installer_path" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    text = path.read_text(encoding="utf-8")
except FileNotFoundError:
    sys.exit(0)

pattern = re.compile(r"^[ \t]*parser\.add_argument\([\s\S]*?\n[ \t]*\)\s*\n", re.MULTILINE)

def fix(block: str) -> str:
    if "argparse.BooleanOptionalAction" not in block:
        return block
    # Python 3.14+ rejects `type=` for BooleanOptionalAction.
    block = re.sub(r"^[ \t]*type\s*=\s*bool\s*,\s*\n", "", block, flags=re.MULTILINE)
    block = re.sub(r",\s*type\s*=\s*bool\s*", "", block)
    return block

new_text = pattern.sub(lambda m: fix(m.group(0)), text)
if new_text != text:
    path.write_text(new_text, encoding="utf-8")
PY
}

pacman_installed() { pacman -Qi "$1" >/dev/null 2>&1; }
pacman_pkg_exists() { pacman -Si "$1" >/dev/null 2>&1; }

pick_qemu_pkg() {
    if pacman_installed qemu-base; then echo qemu-base; return 0; fi
    if pacman_installed qemu-desktop; then echo qemu-desktop; return 0; fi
    if pacman_installed qemu-full; then echo qemu-full; return 0; fi

    if pacman_pkg_exists qemu-base; then echo qemu-base; return 0; fi
    if pacman_pkg_exists qemu-desktop; then echo qemu-desktop; return 0; fi
    if pacman_pkg_exists qemu-full; then echo qemu-full; return 0; fi
    echo qemu
}

pick_iptables_pkg() {
    if pacman_installed iptables-nft; then echo iptables-nft; return 0; fi
    if pacman_installed iptables; then echo iptables; return 0; fi
    if pacman_pkg_exists iptables-nft; then echo iptables-nft; return 0; fi
    echo iptables
}

aur_helper() {
    if command_exists yay; then echo yay; return 0; fi
    if command_exists paru; then echo paru; return 0; fi
    return 1
}

ensure_aur_helper() {
    if aur_helper >/dev/null 2>&1; then return 0; fi
    log_warn "No AUR helper detected. Installing yay..."
    retry sudo pacman -S --noconfirm --needed base-devel git
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    (
        cd "$tmp_dir"
        git clone --depth 1 https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
    )
    rm -rf "$tmp_dir"
    aur_helper >/dev/null 2>&1 || { log_error "Failed to install AUR helper (yay)."; return 1; }
}

# --- SHARED ALIASES (Twin Symmetry) ---
SHARED_ALIASES='
# --- Custom Aliases ---
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias lt="eza --tree --icons --level=2"
alias cat="bat --paging=never"
alias fd="fd"
alias help="tldr"
alias ports="ss -tulpn"
'

# --- MENU SYSTEM ---
show_menu() {
    local choice
    _flag() { [ "$1" = true ] && echo -e "${GREEN}[ON] ${NC}" || echo -e "${RED}[OFF]${NC}"; }
    while true; do
        clear
        echo -e "${BLUE}=============================================${NC}"
        echo -e "${BLUE}       Arch Host Setup (KVM Framework)       ${NC}"
        echo -e "${BLUE}=============================================${NC}"
        printf "  1) %s eza (ls+)        6) %s Apps (Discord/Telegram)\n" "$(_flag "$INSTALL_EZA")" "$(_flag "$INSTALL_SNAP_APPS")"
        printf "  2) %s zoxide (cd+)     7) %s KVM Host\n" "$(_flag "$INSTALL_ZOXIDE")" "$(_flag "$INSTALL_KVM_HOST")"
        printf "  3) %s MariaDB          8) %s Fresh Prompt\n" "$(_flag "$INSTALL_MARIADB")" "$(_flag "$INSTALL_FRESH")"
        printf "  4) %s Brave Browser    9) %s Catppuccin Theme\n" "$(_flag "$INSTALL_BRAVE")" "$(_flag "$INSTALL_THEME")"
        printf "  5) %s Node (NVM)      10) %s Nerd Font\n" "$(_flag "$INSTALL_NODE_NVM")" "$(_flag "$INSTALL_NERD_FONT")"
        echo
        echo -e "   ${GREEN}r)${NC} Run setup   ${GREEN}a)${NC} All ON   ${YELLOW}n)${NC} All OFF   ${RED}q)${NC} Quit"
        read -rp "  Choose: " choice
        case "$choice" in
            1) INSTALL_EZA=$([ "$INSTALL_EZA" = true ] && echo false || echo true) ;;
            2) INSTALL_ZOXIDE=$([ "$INSTALL_ZOXIDE" = true ] && echo false || echo true) ;;
            3) INSTALL_MARIADB=$([ "$INSTALL_MARIADB" = true ] && echo false || echo true) ;;
            4) INSTALL_BRAVE=$([ "$INSTALL_BRAVE" = true ] && echo false || echo true) ;;
            5) INSTALL_NODE_NVM=$([ "$INSTALL_NODE_NVM" = true ] && echo false || echo true) ;;
            6) INSTALL_SNAP_APPS=$([ "$INSTALL_SNAP_APPS" = true ] && echo false || echo true) ;;
            7) INSTALL_KVM_HOST=$([ "$INSTALL_KVM_HOST" = true ] && echo false || echo true) ;;
            8) INSTALL_FRESH=$([ "$INSTALL_FRESH" = true ] && echo false || echo true) ;;
            9) INSTALL_THEME=$([ "$INSTALL_THEME" = true ] && echo false || echo true) ;;
            10) INSTALL_NERD_FONT=$([ "$INSTALL_NERD_FONT" = true ] && echo false || echo true) ;;
            r|R) return 0 ;;
            a|A) INSTALL_EZA=true; INSTALL_ZOXIDE=true; INSTALL_MARIADB=true; INSTALL_BRAVE=true; INSTALL_NODE_NVM=true; INSTALL_SNAP_APPS=true; INSTALL_KVM_HOST=true; INSTALL_FRESH=true; INSTALL_THEME=true; INSTALL_NERD_FONT=true ;;
            n|N) INSTALL_EZA=false; INSTALL_ZOXIDE=false; INSTALL_MARIADB=false; INSTALL_BRAVE=false; INSTALL_NODE_NVM=false; INSTALL_SNAP_APPS=false; INSTALL_KVM_HOST=false; INSTALL_FRESH=false; INSTALL_THEME=false; INSTALL_NERD_FONT=false ;;
            q|Q) exit 0 ;;
        esac
    done
}

# --- EXECUTION ---
if [ -t 0 ]; then show_menu; fi
trap 'on_error $LINENO' ERR
acquire_lock

sudo -v
while true; do sudo -n true; sleep 55; done 2>/dev/null &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null; release_lock; print_summary' EXIT

start_step "Pre-flight checks"
[ "$EUID" -eq 0 ] && { log_error "Do not run as root."; exit 1; }
command_exists pacman || { log_error "pacman not found. Arch only."; exit 1; }
grep -qi "arch" /etc/os-release || { log_error "Arch only."; exit 1; }
pass_step

start_step "System update and core packages"
retry sudo pacman -Syu --noconfirm
retry sudo pacman -S --noconfirm --needed \
    zsh tldr ncdu git git-lfs curl vim nano vlc gparted calibre github-cli \
    base-devel fzf bat fd wget gnupg gnome-tweaks btop duf unzip \
    python python-pip ca-certificates mesa-utils
pass_step

start_step "Fastfetch install"
retry sudo pacman -S --noconfirm --needed fastfetch
pass_step

start_step "eza and zoxide installation"
if [ "$INSTALL_EZA" = true ] && ! command_exists eza; then
    retry sudo pacman -S --noconfirm --needed eza
fi
if [ "$INSTALL_ZOXIDE" = true ] && ! command_exists zoxide; then
    retry sudo pacman -S --noconfirm --needed zoxide
fi
pass_step

start_step "MariaDB setup"
if [ "$INSTALL_MARIADB" = true ]; then
    retry sudo pacman -S --noconfirm --needed mariadb
    if sudo pacman -Si mycli >/dev/null 2>&1; then
        retry sudo pacman -S --noconfirm --needed mycli
    else
        log_warn "mycli not found in repositories. Skipping mycli."
    fi
    if [ ! -d /var/lib/mysql/mysql ]; then
        sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    fi
    sudo systemctl enable --now mariadb
    if [ "$RUN_DB_HARDENING" = true ]; then
        if command_exists mysql_secure_installation; then sudo mysql_secure_installation; \
        elif command_exists mariadb-secure-installation; then sudo mariadb-secure-installation; \
        else log_warn "No secure-installation tool found. Skipping."; fi
    else
        log_warn "Skipping DB hardening."
    fi
    pass_step
else
    skip_step
fi

start_step "Brave and Apps"
if [ "$INSTALL_BRAVE" = true ]; then
    ensure_aur_helper
    AUR="$(aur_helper)"
    command_exists brave || retry "$AUR" -S --noconfirm --needed brave-bin
    command_exists brave-nightly || retry "$AUR" -S --noconfirm --needed brave-nightly-bin
fi
if [ "$INSTALL_SNAP_APPS" = true ]; then
    if sudo pacman -Si discord >/dev/null 2>&1; then
        retry sudo pacman -S --noconfirm --needed discord
    else
        ensure_aur_helper
        AUR="$(aur_helper)"
        retry "$AUR" -S --noconfirm --needed discord
    fi
    if sudo pacman -Si telegram-desktop >/dev/null 2>&1; then
        retry sudo pacman -S --noconfirm --needed telegram-desktop
    else
        ensure_aur_helper
        AUR="$(aur_helper)"
        retry "$AUR" -S --noconfirm --needed telegram-desktop
    fi
fi
pass_step

start_step "Git and Python setup"
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
pass_step

start_step "KVM host and GPU/3D acceleration"
if [ "$INSTALL_KVM_HOST" = true ]; then
    QEMU_PKG="$(pick_qemu_pkg)"
    IPTABLES_PKG="$(pick_iptables_pkg)"
    EBTABLES_PKG=""
    if pacman_pkg_exists ebtables; then EBTABLES_PKG="ebtables"; fi
    retry sudo pacman -S --noconfirm --needed \
        "$QEMU_PKG" libvirt virt-manager virt-viewer virt-install libosinfo \
        dnsmasq vde2 bridge-utils openbsd-netcat ${EBTABLES_PKG:+"$EBTABLES_PKG"} "$IPTABLES_PKG" \
        edk2-ovmf swtpm spice-gtk virglrenderer

    for grp in libvirt kvm render video; do
        if ! id -nG "$USER" | grep -qw "$grp"; then sudo usermod -aG "$grp" "$USER"; fi
    done
    id libvirt-qemu >/dev/null 2>&1 && sudo usermod -aG render,video libvirt-qemu || true

    sudo systemctl enable --now libvirtd
    sudo virsh net-autostart default >/dev/null 2>&1 || true
    sudo virsh net-start default >/dev/null 2>&1 || true
    pass_step
else
    skip_step
fi

start_step "Node (NVM) installation"
if [ "$INSTALL_NODE_NVM" = true ]; then
    if [ ! -d "$HOME/.nvm" ] && [ ! -d "$HOME/.config/nvm" ]; then
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi
    export NVM_DIR="$([ -d "$HOME/.config/nvm" ] && echo "$HOME/.config/nvm" || echo "$HOME/.nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 20 --lts
    pass_step
else
    skip_step
fi

start_step "Oh My Zsh and Shell Prompt"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
sed -i 's|^plugins=.*|plugins=(git sudo fzf z extract dirhistory copypath copyfile history command-not-found zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-syntax-highlighting)|' "$HOME/.zshrc"
grep -q "SHARED_ALIASES" "$HOME/.zshrc" || echo -e "\n# SHARED_ALIASES\n$SHARED_ALIASES" >> "$HOME/.zshrc"

mkdir -p "$ZSH_CUSTOM_DIR/plugins"
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-completions" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM_DIR/plugins/zsh-completions"
fi
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-history-substring-search" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM_DIR/plugins/zsh-history-substring-search"
fi
if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
fi

if [ "$INSTALL_FRESH" = true ] && ! command_exists fresh; then
    retry bash -c 'curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh'
fi
pass_step

start_step "Catppuccin theme setup"
if [ "$INSTALL_THEME" = true ]; then
    mkdir -p "$HOME/.themes" "$HOME/.icons" "$HOME/.local/share/themes"
    tmp_theme="$(mktemp -d)"
    (
        cd "$tmp_theme" && git clone --depth 1 https://github.com/catppuccin/gtk.git
        patch_catppuccin_gtk_installer "$tmp_theme/gtk/install.py"
        cd "$tmp_theme/gtk" && "$(python_bin)" install.py mocha blue --dest "$HOME/.local/share/themes"
    )

    # Verify install (install.py logs errors but exits 0 on failure).
    if [ ! -d "$HOME/.local/share/themes/catppuccin-mocha-blue-standard+default" ] \
        && [ ! -d "$HOME/.local/share/themes/catppuccin-mocha-blue-standard+default-dark" ] \
        && [ ! -d "$HOME/.local/share/themes/catppuccin-mocha-blue-standard+default-light" ]; then
        log_warn "Catppuccin GTK theme not found after installer run; falling back to direct zip download."
        GTK_RELEASE="$(sed -n 's/^[[:space:]]*release = "\(v[^\"]\+\)".*/\1/p' "$tmp_theme/gtk/install.py" | head -n1)"
        GTK_RELEASE="${GTK_RELEASE:-v1.0.3}"
        THEME_ZIP="catppuccin-mocha-blue-standard+default.zip"
        retry curl -fL "https://github.com/catppuccin/gtk/releases/download/${GTK_RELEASE}/${THEME_ZIP}" -o "$tmp_theme/${THEME_ZIP}"
        unzip -o "$tmp_theme/${THEME_ZIP}" -d "$HOME/.local/share/themes"
    fi

    retry sudo pacman -S --noconfirm --needed papirus-icon-theme
    curl -fsSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders -o "$tmp_theme/p-folders"
    chmod +x "$tmp_theme/p-folders"
    (
        cd "$tmp_theme" && git clone --depth 1 https://github.com/catppuccin/papirus-folders.git
        cd "$tmp_theme/papirus-folders" && sudo cp -r src/* /usr/share/icons/Papirus
        "$tmp_theme/p-folders" -C cat-mocha-blue --theme Papirus-Dark
    )

    curl -fsSL https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-blue-cursors.zip -o "$tmp_theme/cursor.zip"
    unzip -o "$tmp_theme/cursor.zip" -d "$HOME/.icons"
    
    # Set default theme/icons/cursors
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        if command_exists gsettings; then
            gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-blue-standard+default" 2>/dev/null || true
            gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true
            gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-mocha-blue-cursors" 2>/dev/null || true
        fi
        
        if echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "kde"; then
            if command_exists kwriteconfig6; then
                kwriteconfig6 --file kdeglobals --group Icons --key Theme "Papirus-Dark"
                kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "catppuccin-mocha-blue-cursors"
            elif command_exists kwriteconfig5; then
                kwriteconfig5 --file kdeglobals --group Icons --key Theme "Papirus-Dark"
                kwriteconfig5 --file kcminputrc --group Mouse --key cursorTheme "catppuccin-mocha-blue-cursors"
            fi
        fi
    fi

    rm -rf "$tmp_theme"
    pass_step
else
    skip_step
fi

start_step "Nerd Font installation"
if [ "$INSTALL_NERD_FONT" = true ]; then
    f_dir="$HOME/.local/share/fonts/HackNerdFont"
    mkdir -p "$f_dir" && tmp_f="$(mktemp -d)"
    retry curl -fL "$NERD_FONT_URL" -o "$tmp_f/font.zip"
    unzip -o "$tmp_f/font.zip" -d "$tmp_f"
    find "$tmp_f" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec mv -f {} "$f_dir/" \;
    # Cache only the user font dir to avoid noisy loop warnings.
    fc-cache -f "$HOME/.local/share/fonts" || log_warn "fc-cache failed; fonts may require a logout/login to be detected."
    rm -rf "$tmp_f"

    # Apply font in desktop environment (best effort; never fail setup on font setting).
    if echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "kde"; then
        # KDE Plasma: set fixed-width (monospace) font
        KDE_FIXED_VALUE="$NERD_FONT_TERMINAL_FACE,$NERD_FONT_SIZE,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
        if command_exists kwriteconfig6; then
            kwriteconfig6 --file kdeglobals --group General --key fixed "$KDE_FIXED_VALUE" || log_warn "Could not set KDE fixed font automatically."
            command_exists kreadconfig6 && log_info "KDE fixed font is now: $(kreadconfig6 --file kdeglobals --group General --key fixed || true)"
            log_warn "You may need to log out/in (or reboot) for KDE font changes to fully apply."
        elif command_exists kwriteconfig5; then
            kwriteconfig5 --file kdeglobals --group General --key fixed "$KDE_FIXED_VALUE" || log_warn "Could not set KDE fixed font automatically."
            command_exists kreadconfig5 && log_info "KDE fixed font is now: $(kreadconfig5 --file kdeglobals --group General --key fixed || true)"
            log_warn "You may need to log out/in (or reboot) for KDE font changes to fully apply."
        else
            log_warn "KDE detected but kwriteconfig is missing; set Fixed width font manually in System Settings → Fonts."
        fi
    elif echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "gnome"; then
        # GNOME: set interface monospace font
        if command_exists gsettings; then
            gsettings set org.gnome.desktop.interface monospace-font-name "$NERD_FONT_TERMINAL_FACE $NERD_FONT_SIZE" || log_warn "Could not set GNOME monospace font automatically."
        fi
    else
        log_warn "Installed Nerd Font, but your desktop environment isn't KDE/GNOME; set terminal monospace font manually."
    fi
    pass_step
else
    skip_step
fi

start_step "Cleanup and Finalization"
sudo pacman -Sc --noconfirm || true
if [ -n "${DISPLAY:-}" ]; then
    if command_exists brave; then
        brave https://code.visualstudio.com https://obsidian.md/download &
    elif command_exists brave-browser; then
        brave-browser https://code.visualstudio.com https://obsidian.md/download &
    fi
fi
log_info "Setup complete! Reboot recommended."
pass_step
