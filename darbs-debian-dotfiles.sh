#!/bin/bash

################################################################################
#                                                                              #
#  DARBS (Debian) - Dotfiles Only                                              #
#                                                                              #
#  Sets up XFCE theming, dotfiles, wallpapers, and configs on Debian XFCE.     #
#  Does not install security tools or bug bounty packages.                     #
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
echo "=== DARBS Debian (Dotfiles Only) ==="

set -e

LOGFILE="$HOME/darbs.log"
exec > >(tee -a "$LOGFILE") 2>&1

DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"
DOT_DIR="$HOME/.dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"

log() { echo -e "${GREEN}==>${RESET} $1"; }

apt_install() {
    local to_install=()
    for pkg in "$@"; do
        if dpkg -s "$pkg" &>/dev/null; then
            log "Skipping $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        sudo apt install -y "${to_install[@]}"
    fi
}

snap_install() {
    for pkg in "$@"; do
        if snap list "$pkg" &>/dev/null 2>&1; then
            log "Skipping $pkg (already installed via snap)"
        else
            sudo snap install "$pkg"
        fi
    done
}

snap_install_classic() {
    for pkg in "$@"; do
        if snap list "$pkg" &>/dev/null 2>&1; then
            log "Skipping $pkg (already installed via snap)"
        else
            sudo snap install "$pkg" --classic
        fi
    done
}

# try apt first, fall back to snap
apt_or_snap() {
    local pkg="$1"
    local snap_name="${2:-$1}"
    local classic="${3:-}"
    if dpkg -s "$pkg" &>/dev/null || snap list "$snap_name" &>/dev/null 2>&1; then
        log "Skipping $pkg (already installed)"
        return
    fi
    if apt-cache show "$pkg" &>/dev/null 2>&1; then
        sudo apt install -y "$pkg"
    else
        log "$pkg not found in apt, installing via snap..."
        if [ "$classic" = "classic" ]; then
            sudo snap install "$snap_name" --classic
        else
            sudo snap install "$snap_name"
        fi
    fi
}

# -----------------------------
# VERIFY DEBIAN/UBUNTU
# -----------------------------
if ! grep -qi 'debian\|ubuntu' /etc/os-release 2>/dev/null; then
    echo "This script is for Debian and Ubuntu based systems only."
    exit 1
fi

# detect distro
IS_UBUNTU=false
if grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
    IS_UBUNTU=true
    echo -e "${BLUE}==> Detected Ubuntu based system.${RESET}"
else
    echo -e "${BLUE}==> Detected Debian based system.${RESET}"
fi

# -----------------------------
# SYSTEM UPDATE
# -----------------------------
log "Updating system..."
sudo apt update && sudo apt upgrade -y

# -----------------------------
# INSTALL SNAP (if not present)
# -----------------------------
if [ "$IS_UBUNTU" = true ]; then
    if ! command -v snap &>/dev/null; then
        log "Installing snapd..."
        sudo apt install -y snapd
        sudo systemctl enable snapd
        sudo systemctl start snapd
        sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
    else
        log "Skipping snapd (already installed)"
    fi
fi

# -----------------------------
# BASE PACKAGES
# -----------------------------
log "Installing base packages..."
# set firefox package name based on distro
if [ "$IS_UBUNTU" = true ]; then
    FIREFOX_PKG="firefox"
else
    FIREFOX_PKG="firefox-esr"
fi

# fastfetch may not be in older repos, add ppa on ubuntu
if [ "$IS_UBUNTU" = true ] && ! apt-cache show fastfetch &>/dev/null; then
    log "Adding fastfetch PPA..."
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch 2>/dev/null || true
    sudo apt update
fi

apt_install \
    xfce4 xfce4-goodies \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    xfce4-weather-plugin \
    xfce4-systemload-plugin \
    lightdm lightdm-gtk-greeter \
    network-manager \
    bash-completion \
    tmux \
    wmctrl \
    git \
    curl \
    wget \
    unzip \
    zip \
    neovim \
    htop \
    tree \
    rsync \
    build-essential \
    "$FIREFOX_PKG" \
    flameshot \
    fastfetch \
    libreoffice \
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
    conky-all \
    sassc \
    calcurse \
    fonts-jetbrains-mono

# -----------------------------
# ENABLE SERVICES
# -----------------------------
log "Enabling services..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# -----------------------------
# WIFI SETUP
# -----------------------------
log "Checking for connectivity..."
if ! ping -c 1 -W 3 google.com &>/dev/null; then
    log "No internet detected. Launching WiFi setup..."
    nmtui connect
fi

# Disable conflicting display managers
for dm in sddm gdm lxdm xdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        log "Disabling existing display manager: $dm"
        sudo systemctl disable "$dm"
    fi
done
sudo systemctl enable lightdm

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
log "Configuring LightDM greeter..."
if [ -f "$DOT_DIR/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$DOT_DIR/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
    sudo mkdir -p /usr/share/themes
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/ 2>/dev/null || true
fi

# -----------------------------
# EXTRA UTILITIES
# -----------------------------
log "Installing extra utilities..."
apt_install \
    ncdu \
    ripgrep \
    fd-find \
    bat \
    jq \
    fzf \
    lsof \
    strace \
    dnsutils \
    net-tools \
    btop \
    python3 \
    python3-pip

# -----------------------------
# FINISH
# -----------------------------
log "DARBS Debian (Dotfiles) installation complete!"

echo -e "${BLUE}"
echo "====================================="
echo " DONE! Reboot into XFCE."
echo "====================================="
echo -e "${RESET}"
