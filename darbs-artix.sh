#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
#                                                                              #
#  DARBS - Artix Linux                                                         #
#                                                                              #
#  Artix is Arch without systemd. This script detects whether you are          #
#  running OpenRC, runit, or s6 and handles services accordingly.              #
#                                                                              #
################################################################################

echo -e "\e[38;5;22m
██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║███████║██████╔╝██████╔╝███████╗
██║  ██║██╔══██║██╔══██╗██╔══██╗╚════██║
██████╔╝██║  ██║██║  ██║██████╔╝███████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝
\e[0m"
echo "=== DARBS (Artix Linux) ==="

set -e

LOGFILE="$HOME/darbs.log"
exec > >(tee -a "$LOGFILE") 2>&1

# -----------------------------
# CONFIG
# -----------------------------
DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"
DOT_DIR="$HOME/.dotfiles"

# -----------------------------
# COLORS
# -----------------------------
GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"

log() { echo -e "${GREEN}==>${RESET} $1"; }

pacman_install() {
    local to_install=()
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log "Skipping $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        sudo pacman -S --noconfirm "${to_install[@]}"
    fi
}

go_install() {
    local pkg="$1"
    local bin
    bin="$(basename "${pkg%%@*}")"
    if command -v "$bin" &>/dev/null; then
        log "Skipping $bin (already installed)"
    else
        go install "$pkg"
    fi
}

yay_install() {
    local to_install=()
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log "Skipping $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        yay -S --noconfirm "${to_install[@]}"
    fi
}

# -----------------------------
# VERIFY ARTIX
# -----------------------------
if ! grep -qi 'artix' /etc/os-release 2>/dev/null; then
    echo "This script is for Artix Linux only. Use darbs.sh for Arch."
    exit 1
fi

# -----------------------------
# VERIFY PACMAN EXISTS
# -----------------------------
if ! command -v pacman &>/dev/null; then
    echo "ERROR: pacman not found in PATH."
    echo "Make sure you are running this on Artix Linux with pacman installed."
    echo "Try: export PATH=\$PATH:/usr/bin"
    exit 1
fi

# -----------------------------
# INITIALIZE PACMAN KEYRING
# -----------------------------
log "Initializing pacman keyring..."
sudo mkdir -p /etc/pacman.d/gnupg
sudo pacman-key --init
sudo pacman-key --populate artix
sudo pacman -Sy --noconfirm

# -----------------------------
# DETECT INIT SYSTEM
# -----------------------------
INIT_SYS=""
if command -v openrc &>/dev/null || [ -d /run/openrc ]; then
    INIT_SYS="openrc"
elif command -v runit &>/dev/null || [ -d /run/runit ]; then
    INIT_SYS="runit"
elif command -v s6-rc &>/dev/null || [ -d /run/s6 ]; then
    INIT_SYS="s6"
else
    # fallback: check pid 1
    case "$(cat /proc/1/comm 2>/dev/null)" in
        openrc-init) INIT_SYS="openrc" ;;
        runit)       INIT_SYS="runit" ;;
        s6-svscan)   INIT_SYS="s6" ;;
        *)           INIT_SYS="openrc" ; log "WARNING: could not detect init system, defaulting to openrc" ;;
    esac
fi

echo -e "${BLUE}==> Detected init system: $INIT_SYS${RESET}"

# service management helpers
service_enable() {
    local svc="$1"
    case "$INIT_SYS" in
        openrc)
            sudo rc-update add "$svc" default 2>/dev/null || true
            ;;
        runit)
            if [ -d "/etc/runit/sv/$svc" ] && [ ! -L "/run/runit/service/$svc" ]; then
                sudo ln -s "/etc/runit/sv/$svc" /run/runit/service/ 2>/dev/null || true
            fi
            ;;
        s6)
            # s6 service enabling varies by setup
            if command -v s6-rc &>/dev/null; then
                sudo s6-rc -u change "$svc" 2>/dev/null || true
            fi
            ;;
    esac
}

service_start() {
    local svc="$1"
    case "$INIT_SYS" in
        openrc)
            sudo rc-service "$svc" start 2>/dev/null || true
            ;;
        runit)
            sudo sv start "$svc" 2>/dev/null || true
            ;;
        s6)
            sudo s6-rc -u change "$svc" 2>/dev/null || true
            ;;
    esac
}

service_disable() {
    local svc="$1"
    case "$INIT_SYS" in
        openrc)
            sudo rc-update del "$svc" default 2>/dev/null || true
            ;;
        runit)
            if [ -L "/run/runit/service/$svc" ]; then
                sudo rm "/run/runit/service/$svc" 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc -d change "$svc" 2>/dev/null || true
            ;;
    esac
}

# -----------------------------
# SYSTEM UPDATE
# -----------------------------
log "Updating system..."
sudo pacman -Syu --noconfirm

# -----------------------------
# ADD ARCH REPOS (if needed)
# -----------------------------
if ! grep -q '^\[extra\]' /etc/pacman.conf 2>/dev/null; then
    log "Adding Arch repos to pacman.conf..."
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    # install arch mirrorlist if not present
    pacman_install artix-archlinux-support
    sudo pacman -Sy --noconfirm
fi

# -----------------------------
# BASE SYSTEM + XFCE
# -----------------------------
log "Installing XFCE and core packages..."

# install init specific packages
pacman_install \
    "networkmanager-$INIT_SYS" \
    "lightdm-$INIT_SYS"

pacman_install \
    xorg \
    xfce4 xfce4-goodies \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    lightdm lightdm-gtk-greeter \
    networkmanager \
    bash-completion \
    tmux \
    wmctrl \
    git \
    curl \
    wget \
    unzip \
    python-pip \
    zip \
    neovim \
    htop \
    tree \
    rsync \
    which \
    base-devel \
    firefox \
    flameshot \
    fastfetch \
    libreoffice-fresh \
    thunderbird \
    ranger \
    qalculate-gtk \
    gnucash \
    rhythmbox \
    inkscape \
    keepassxc \
    copyq \
    redshift \
    picom \
    papirus-icon-theme \
    rofi \
    conky \
    sassc \
    calcurse \
    xfce4-weather-plugin \
    xfce4-systemload-plugin

# -----------------------------
# ENABLE SERVICES
# -----------------------------
log "Enabling services..."
service_enable NetworkManager
service_start NetworkManager

# -----------------------------
# WIFI SETUP
# -----------------------------
log "Checking for WiFi connectivity..."
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    log "No internet detected. Launching WiFi setup..."
    nmtui connect
fi

# disable conflicting display managers
for dm in sddm gdm lxdm xdm; do
    service_disable "$dm"
done
service_enable lightdm

# -----------------------------
# ADD BLACKARCH REPO
# -----------------------------
log "Adding BlackArch repository..."
if ! grep -qE '^\[blackarch\]' /etc/pacman.conf 2>/dev/null; then
    curl -O https://blackarch.org/strap.sh
    chmod +x strap.sh
    sudo ./strap.sh
    rm strap.sh
    sudo pacman -Sy --noconfirm
else
    log "BlackArch repo already present, skipping."
fi

# -----------------------------
# BUG BOUNTY + SECURITY TOOLS
# -----------------------------
log "Installing bug bounty and security tools..."
pacman_install \
    nmap \
    burpsuite \
    sqlmap \
    nikto \
    gobuster \
    ffuf \
    amass \
    whatweb \
    dirsearch \
    wfuzz \
    tcpdump \
    wireshark-qt \
    metasploit \
    hydra \
    masscan \
    openbsd-netcat \
    chromium \
    john \
    hashcat \
    mitmproxy \
    zaproxy \
    theharvester \
    recon-ng \
    responder \
    crackmapexec \
    impacket \
    seclists \
    frida \
    objection \
    commix \
    enum4linux-ng \
    massdns \
    aircrack-ng \
    ettercap \
    kismet \
    binwalk \
    autopsy \
    volatility3 \
    bloodhound \
    bettercap \
    macchanger \
    maltego \
    exploitdb \
    dnsenum \
    cewl \
    wifite \
    reaver \
    foremost \
    socat

# -----------------------------
# INSTALL GO
# -----------------------------
log "Installing Go..."
pacman_install go

# -----------------------------
# GO TOOLS
# -----------------------------
log "Installing Go tools..."
export PATH=$PATH:/usr/lib/go/bin
export GOPATH="$HOME/go"

go_install github.com/tomnomnom/waybackurls@latest
go_install github.com/tomnomnom/httprobe@latest
go_install github.com/tomnomnom/gf@latest
go_install github.com/tomnomnom/assetfinder@latest
go_install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go_install github.com/projectdiscovery/katana/cmd/katana@latest
go_install github.com/hahwul/dalfox/v2@latest
go_install github.com/s0md3v/smap/cmd/smap@latest
go_install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go_install github.com/sensepost/gowitness@latest
go_install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go_install github.com/projectdiscovery/httpx/cmd/httpx@latest
go_install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# -----------------------------
# EXTRA UTILITIES
# -----------------------------
log "Installing extra utilities..."
pacman_install \
    ncdu \
    ripgrep \
    fd \
    bat \
    jq \
    fzf \
    lsof \
    strace \
    bind \
    inetutils \
    net-tools \
    btop \
    python \
    python-pip

# -----------------------------
# INSTALL AUR HELPER (YAY)
# -----------------------------
log "Installing yay..."
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
fi

# -----------------------------
# AUR PACKAGES
# -----------------------------
log "Installing AUR packages..."
yay_install \
 vscodium-bin \
 obsidian \
 nuclei \
 medusa \
 patator \
 subjack \
 eyewitness \
 scout-suite \
 planify \
 peek \
 ttf-jetbrains-mono-nerd \
 ghidra \
 drawio-desktop-bin \
 beef-xss

# -----------------------------
# CLONE DOTFILES
# -----------------------------
log "Cloning dotfiles..."
if [ ! -d "$DOT_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOT_DIR"
else
    log "Dotfiles already exist, pulling latest..."
    git -C "$DOT_DIR" pull
fi

# -----------------------------
# BASHRC
# -----------------------------
log "Setting up bashrc..."
cp "$DOT_DIR/bashrc" "$HOME/.bashrc"
echo 'export PATH=$PATH:/usr/lib/go/bin:$HOME/go/bin' >> "$HOME/.bashrc"

# -----------------------------
# NANORC
# -----------------------------
log "Setting up nanorc..."
cp "$DOT_DIR/nanorc.nanorc" "$HOME/.nanorc"

# -----------------------------
# TMUX CONFIG
# -----------------------------
log "Setting up tmux config..."
if [ -f "$DOT_DIR/tmux-help.txt" ]; then
    cp "$DOT_DIR/tmux-help.txt" "$HOME/.tmux-help.txt"
fi
if [ -f "$SCRIPT_DIR/.tmux.conf" ]; then
    cp "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
elif [ -f "$DOT_DIR/.tmux.conf" ]; then
    cp "$DOT_DIR/.tmux.conf" "$HOME/.tmux.conf"
else
    log "WARNING: No .tmux.conf found in darbs repo or dotfiles repo"
fi

# -----------------------------
# XFCE CONFIG
# -----------------------------
log "Setting up XFCE config..."

XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

rm -rf "$HOME/.config/xfce4"
mkdir -p "$XFCONF_DIR"

if [ -d "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml" ]; then
    cp "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml/"*.xml "$XFCONF_DIR/"
    log "XFCE XML configs copied."
else
    log "WARNING: xfce4/xfconf/xfce-perchannel-xml not found in dotfiles repo!"
fi

sed -i "s|/home/drew|$HOME|g" "$XFCONF_DIR/xfce4-desktop.xml"

cat > "$HOME/.config/xfce4/helpers.rc" <<EOF
TerminalEmulator=xfce4-terminal
EOF

# -----------------------------
# GTK THEME (Everforest)
# -----------------------------
log "Installing Everforest GTK theme..."
mkdir -p "$HOME/.themes"
rm -rf /tmp/everforest
git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
/tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes"
rm -rf /tmp/everforest

# -----------------------------
# THEMING / RICING
# -----------------------------
log "Setting up picom, rofi, and autostart from dotfiles..."

mkdir -p "$HOME/.config/gtk-3.0"
if [ -f "$DOT_DIR/gtk-3.0/settings.ini" ]; then
    cp "$DOT_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
fi
if [ -f "$DOT_DIR/gtk-2.0/gtkrc-2.0" ]; then
    cp "$DOT_DIR/gtk-2.0/gtkrc-2.0" "$HOME/.gtkrc-2.0"
fi

mkdir -p "$HOME/.config/picom"
if [ -f "$DOT_DIR/picom/picom.conf" ]; then
    cp "$DOT_DIR/picom/picom.conf" "$HOME/.config/picom/picom.conf"
fi

mkdir -p "$HOME/.config/rofi"
if [ -f "$DOT_DIR/rofi/config.rasi" ]; then
    cp "$DOT_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
fi

mkdir -p "$HOME/.config/autostart"
if [ -d "$DOT_DIR/autostart" ]; then
    cp "$DOT_DIR/autostart/"*.desktop "$HOME/.config/autostart/"
fi

# -----------------------------
# WALLPAPERS
# -----------------------------
log "Setting up wallpapers directory..."
mkdir -p "$HOME/wallpapers"
if [ -d "$DOT_DIR/wallpapers" ]; then
    cp -r "$DOT_DIR/wallpapers/." "$HOME/wallpapers/"
    log "Wallpapers copied from dotfiles."
else
    log "No wallpapers folder found in dotfiles."
fi

WALL="$HOME/wallpapers/0327.jpg"

xfconf-query -c xfce4-desktop -l | grep last-image | while read -r path; do
  xfconf-query -c xfce4-desktop -p "$path" -s "$WALL"
done

xfconf-query -c xfce4-desktop -l | grep image-style | while read -r path; do
  xfconf-query -c xfce4-desktop -p "$path" -s 3
done

sudo cp -f ~/wallpapers/0327.jpg /usr/share/backgrounds/xfce/xfce-x.svg 2>/dev/null || true

# -----------------------------
# LIGHTDM GREETER THEME
# -----------------------------
log "Configuring LightDM greeter to match Everforest theme..."
if [ -f "$DOT_DIR/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$DOT_DIR/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
    sudo mkdir -p /usr/share/themes
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/ 2>/dev/null || true
fi

# gf patterns
mkdir -p "$HOME/.gf"
if [ ! "$(ls -A "$HOME/.gf" 2>/dev/null)" ]; then
    git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null && \
        cp /tmp/gf-patterns/*.json "$HOME/.gf/" && \
        rm -rf /tmp/gf-patterns
fi

echo 'export PATH=$HOME/go/bin:$HOME/.local/bin:$PATH' >> ~/.bashrc

# -----------------------------
# FINISH
# -----------------------------
log "DARBS Artix installation complete!"

echo -e "${BLUE}"
echo "====================================="
echo " DONE! Reboot into XFCE."
echo " Init system: $INIT_SYS"
echo "====================================="
echo -e "${RESET}"
