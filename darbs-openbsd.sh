#!/bin/ksh
# shellcheck shell=ksh

################################################################################
#                                                                              #
#  DARBS - OpenBSD                                                             #
#                                                                              #
#  OpenBSD version. Uses pkg_add, rcctl, doas, and xenodm.                    #
#  Run as a regular user with doas configured.                                 #
#                                                                              #
#  NOTE: OpenBSD uses ksh by default. This script is ksh-compatible.          #
#  After bash is installed you can re-run with bash if preferred.              #
#                                                                              #
################################################################################

printf "\033[38;5;22m
██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║███████║██████╔╝██████╔╝███████╗
██║  ██║██╔══██║██╔══██╗██╔══██╗╚════██║
██████╔╝██║  ██║██║  ██║██████╔╝███████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝
\033[0m\n"
echo "=== DARBS (OpenBSD) ==="

# not using set -e so one failed package doesn't kill the whole script

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGFILE="$HOME/darbs.log"

# log output to file (ksh compatible)
touch "$LOGFILE"

# -----------------------------
# CONFIG
# -----------------------------
DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"
DOT_DIR="$HOME/.dotfiles"

# -----------------------------
# COLORS
# -----------------------------
GREEN="\033[32m"
BLUE="\033[34m"
RED="\033[31m"
RESET="\033[0m"

log() { printf "${GREEN}==>${RESET} %s\n" "$1"; }
warn() { printf "${RED}==>${RESET} %s\n" "$1"; }

# -----------------------------
# VERIFY OPENBSD
# -----------------------------
if [ "$(uname -s)" != "OpenBSD" ]; then
    echo "This script is for OpenBSD only."
    exit 1
fi

# -----------------------------
# VERIFY DOAS
# -----------------------------
if ! command -v doas >/dev/null 2>&1; then
    echo "ERROR: doas not found. Configure /etc/doas.conf first."
    echo "As root, run: echo 'permit persist :wheel' > /etc/doas.conf"
    exit 1
fi

# test that doas actually works for this user
if ! doas true 2>/dev/null; then
    echo "ERROR: doas is not configured for your user."
    echo "As root, make sure your user is in the wheel group and /etc/doas.conf exists:"
    echo "  echo 'permit persist :wheel' > /etc/doas.conf"
    exit 1
fi

# -----------------------------
# PACKAGE INSTALL HELPER
# -----------------------------
pkg_install() {
    for pkg in "$@"; do
        if pkg_info -e "$pkg" >/dev/null 2>&1; then
            log "Skipping $pkg (already installed)"
        else
            doas pkg_add "$pkg" || warn "Could not install $pkg, skipping"
        fi
    done
}

go_install() {
    local pkg="$1"
    local bin
    bin="$(basename "${pkg%%@*}")"
    if command -v "$bin" >/dev/null 2>&1; then
        log "Skipping $bin (already installed)"
    else
        go install "$pkg"
    fi
}

pip_install() {
    # use a venv to avoid externally-managed-environment error
    if [ ! -d "$HOME/.darbs-venv" ]; then
        python3 -m venv --system-site-packages "$HOME/.darbs-venv"
    fi
    for pkg in "$@"; do
        if "$HOME/.darbs-venv/bin/pip" show "$pkg" >/dev/null 2>&1; then
            log "Skipping $pkg (already installed)"
        else
            "$HOME/.darbs-venv/bin/pip" install "$pkg"
        fi
    done
}

# -----------------------------
# SYSTEM UPDATE
# -----------------------------
log "Updating installed packages..."
doas pkg_add -u

# -----------------------------
# INSTALL BASH
# -----------------------------
log "Installing bash..."
pkg_install bash bash-completion

# -----------------------------
# CORE SYSTEM + XFCE
# -----------------------------
log "Installing XFCE and core packages..."
pkg_install \
    xfce \
    xfce-extras \
    xfce4-terminal \
    xfce4-power-manager \
    ffmpeg \
    git \
    curl \
    wget \
    unzip-- \
    zip-- \
    neovim-- \
    htop \
    tree \
    rsync-- \
    wmctrl \
    firefox-esr \
    libreoffice \
    thunderbird \
    ranger \
    keepassxc \
    picom \
    rofi \
    conky \
    calcurse \
    redshift \
    inkscape \
    gnucash \
    papirus-icon-theme \
    sassc

# -----------------------------
# BUILD WHISKERMENU FROM SOURCE
# -----------------------------
log "Building xfce4-whiskermenu-plugin from source..."
pkg_install cmake gtk+3 garcon gettext-tools
if ! pkg_info -e xfce4-whiskermenu-plugin >/dev/null 2>&1; then
    WHISKER_VER="2.8.3"
    rm -rf /tmp/whiskermenu-build
    mkdir -p /tmp/whiskermenu-build
    cd /tmp/whiskermenu-build
    curl -LO "https://archive.xfce.org/src/panel-plugins/xfce4-whiskermenu-plugin/2.8/xfce4-whiskermenu-plugin-${WHISKER_VER}.tar.bz2"
    tar xjf "xfce4-whiskermenu-plugin-${WHISKER_VER}.tar.bz2"
    cd "xfce4-whiskermenu-plugin-${WHISKER_VER}"
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_ACCOUNTS_SERVICE=OFF ..
    make
    doas make install
    cd /
    rm -rf /tmp/whiskermenu-build
    log "Whiskermenu installed."
else
    log "Skipping whiskermenu (already installed)"
fi

# -----------------------------
# ENABLE SERVICES
# -----------------------------
log "Enabling services..."

# add current user to audio/video groups
CURRENT_USER="$(whoami)"
log "Adding $CURRENT_USER to audio, video, and staff groups..."
doas usermod -G operator,wheel,staff "$CURRENT_USER"

# enable xenodm (OpenBSD display manager)
doas rcctl enable xenodm
doas rcctl set xenodm flags ""

# enable networking services
doas rcctl enable dhcpleased
doas rcctl enable resolvd

# enable ntpd for time sync
doas rcctl enable ntpd

# start services that aren't running
doas rcctl start dhcpleased 2>/dev/null || true
doas rcctl start resolvd 2>/dev/null || true
doas rcctl start ntpd 2>/dev/null || true

# -----------------------------
# WIFI SETUP
# -----------------------------
log "Checking for WiFi connectivity..."
if ! ping -c 1 -W 3 openbsd.org >/dev/null 2>&1; then
    log "No internet detected."
    echo ""
    echo "To configure WiFi manually:"
    echo "  1. Find your interface:  ifconfig | grep -i ieee"
    echo "  2. Configure it:         doas ifconfig iwn0 nwid YOUR_SSID wpakey YOUR_PASS"
    echo "  3. Get an IP:            doas dhcpleased"
    echo "  4. Make permanent:       echo 'join YOUR_SSID wpakey YOUR_PASS' | doas tee /etc/hostname.iwn0"
    echo ""
    echo "Replace iwn0 with your wifi interface name."
    echo "Press Enter to continue or Ctrl+C to set up WiFi first."
    read -r _
fi

# -----------------------------
# SECURITY TOOLS (from ports)
# -----------------------------
log "Installing security tools from ports..."
pkg_install \
    nmap \
    nikto \
    wireshark \
    hydra \
    john \
    socat

# tcpdump and nc are already in OpenBSD base

# -----------------------------
# BUILD SECURITY TOOLS FROM SOURCE
# -----------------------------
log "Building security tools from source..."
pkg_install autoconf automake libtool pcre openssl libusb1

# hashcat
if ! command -v hashcat >/dev/null 2>&1; then
    log "Building hashcat..."
    rm -rf /tmp/hashcat-build
    git clone --depth 1 https://github.com/hashcat/hashcat.git /tmp/hashcat-build
    cd /tmp/hashcat-build
    gmake || make
    doas gmake install || doas make install
    cd /
    rm -rf /tmp/hashcat-build
else
    log "Skipping hashcat (already installed)"
fi

# masscan
if ! command -v masscan >/dev/null 2>&1; then
    log "Building masscan..."
    rm -rf /tmp/masscan-build
    git clone --depth 1 https://github.com/robertdavidgraham/masscan.git /tmp/masscan-build
    cd /tmp/masscan-build
    gmake || make
    doas cp bin/masscan /usr/local/bin/
    cd /
    rm -rf /tmp/masscan-build
else
    log "Skipping masscan (already installed)"
fi

# macchanger
if ! command -v macchanger >/dev/null 2>&1; then
    log "Building macchanger..."
    rm -rf /tmp/macchanger-build
    git clone --depth 1 https://github.com/alobbs/macchanger.git /tmp/macchanger-build
    cd /tmp/macchanger-build
    autoreconf -i 2>/dev/null || true
    ./configure --prefix=/usr/local
    make
    doas make install
    cd /
    rm -rf /tmp/macchanger-build
else
    log "Skipping macchanger (already installed)"
fi

# foremost
if ! command -v foremost >/dev/null 2>&1; then
    log "Building foremost..."
    rm -rf /tmp/foremost-build
    git clone --depth 1 https://github.com/korczis/foremost.git /tmp/foremost-build
    cd /tmp/foremost-build
    make
    doas make install PREFIX=/usr/local
    cd /
    rm -rf /tmp/foremost-build
else
    log "Skipping foremost (already installed)"
fi

# aircrack-ng
if ! command -v aircrack-ng >/dev/null 2>&1; then
    log "Building aircrack-ng..."
    rm -rf /tmp/aircrack-build
    git clone --depth 1 https://github.com/aircrack-ng/aircrack-ng.git /tmp/aircrack-build
    cd /tmp/aircrack-build
    autoreconf -i
    ./configure --prefix=/usr/local
    make
    doas make install
    cd /
    rm -rf /tmp/aircrack-build
else
    log "Skipping aircrack-ng (already installed)"
fi

# binwalk (pip install)
if ! command -v binwalk >/dev/null 2>&1; then
    log "Installing binwalk via pip..."
fi

# -----------------------------
# PYTHON + PIP SECURITY TOOLS
# -----------------------------
log "Installing Python and pip-based tools..."
pkg_install \
    python3 \
    py3-pip \
    py3-curl

pip_install \
    wfuzz \
    dirsearch \
    impacket \
    theharvester \
    cewl \
    sqlmap \
    mitmproxy \
    binwalk

# -----------------------------
# INSTALL GO
# -----------------------------
log "Installing Go..."
pkg_install go

# -----------------------------
# GO TOOLS
# -----------------------------
log "Installing Go security tools..."
export GOPATH="$HOME/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"

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
go_install github.com/OJ/gobuster/v3@latest
go_install github.com/ffuf/ffuf/v2@latest

# gf patterns
mkdir -p "$HOME/.gf"
if [ ! "$(ls -A "$HOME/.gf" 2>/dev/null)" ]; then
    git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null && \
        cp /tmp/gf-patterns/*.json "$HOME/.gf/" && \
        rm -rf /tmp/gf-patterns
fi

# -----------------------------
# EXTRA UTILITIES
# -----------------------------
log "Installing extra utilities..."
pkg_install \
    ncdu \
    ripgrep \
    fd \
    bat \
    jq \
    fzf \
    btop \
    nano

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
# SHELL CONFIG
# -----------------------------
log "Setting up shell configs..."

# bashrc (for bash sessions)
if [ -f "$DOT_DIR/bashrc" ]; then
    cp "$DOT_DIR/bashrc" "$HOME/.bashrc"
fi
# append OpenBSD-specific paths
cat >> "$HOME/.bashrc" <<'BASHEOF'
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.darbs-venv/bin
BASHEOF

# ksh profile (OpenBSD default shell)
cat >> "$HOME/.profile" <<'PROFILEEOF'
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.darbs-venv/bin
export ENV=$HOME/.kshrc
PROFILEEOF

# kshrc
cat > "$HOME/.kshrc" <<'KSHEOF'
PS1='\[\033[32m\]\u@\h\[\033[0m\]:\[\033[34m\]\w\[\033[0m\]\$ '
alias ll='ls -la'
alias la='ls -a'
alias grep='grep --color=auto'
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.darbs-venv/bin
KSHEOF

# nanorc
if [ -f "$DOT_DIR/nanorc.nanorc" ]; then
    cp "$DOT_DIR/nanorc.nanorc" "$HOME/.nanorc"
fi

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

# fix hardcoded home paths (BSD sed needs empty string for -i)
sed -i '' "s|/home/drew|$HOME|g" "$XFCONF_DIR/xfce4-desktop.xml" 2>/dev/null || true

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
/tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes" 2>/dev/null || true
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
    cp "$DOT_DIR/autostart/"*.desktop "$HOME/.config/autostart/" 2>/dev/null || true
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

# set wallpaper (xfconf-query may not work until XFCE is running)
WALL="$HOME/wallpapers/0327.jpg"
if command -v xfconf-query >/dev/null 2>&1; then
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image | while read -r path; do
        xfconf-query -c xfce4-desktop -p "$path" -s "$WALL" 2>/dev/null || true
    done
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep image-style | while read -r path; do
        xfconf-query -c xfce4-desktop -p "$path" -s 3 2>/dev/null || true
    done
fi

# -----------------------------
# XENODM THEME
# -----------------------------
log "Configuring xenodm..."
# set a simple background color for the login screen
if [ -f /etc/X11/xenodm/Xsetup_0 ]; then
    doas cp /etc/X11/xenodm/Xsetup_0 /etc/X11/xenodm/Xsetup_0.bak
    echo 'xsetroot -solid "#2b3339"' | doas tee /etc/X11/xenodm/Xsetup_0 >/dev/null
fi

# set XFCE as default session
cat > "$HOME/.xsession" <<'EOF'
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.darbs-venv/bin
exec startxfce4
EOF
chmod +x "$HOME/.xsession"

# -----------------------------
# PF FIREWALL (basic config)
# -----------------------------
log "Setting up basic pf firewall..."
if [ ! -f /etc/pf.conf.darbs-backup ]; then
    doas cp /etc/pf.conf /etc/pf.conf.darbs-backup
fi
doas tee /etc/pf.conf >/dev/null <<'PFEOF'
# DARBS pf config - basic desktop firewall
set skip on lo

block return in on ! lo0 proto tcp to port 6000:6010

pass out quick
pass in on egress proto { tcp udp } from any to any port { 22 80 443 }
pass in on egress proto icmp
PFEOF
doas pfctl -f /etc/pf.conf 2>/dev/null || true

# -----------------------------
# FINISH
# -----------------------------
log "DARBS OpenBSD installation complete!"

printf "${BLUE}"
echo "====================================="
echo " DONE! Reboot into XFCE."
echo ""
echo " Display manager: xenodm"
echo " Session:         startxfce4"
echo " Firewall:        pf (enabled)"
echo " Shell:           ksh (bash also installed)"
echo ""
echo " Tools NOT in ports (install manually):"
echo "   burpsuite, metasploit, maltego,"
echo "   ghidra, bloodhound, bettercap,"
echo "   responder, crackmapexec, ettercap"
echo ""
echo " To change default shell to bash:"
echo "   chsh -s /usr/local/bin/bash"
echo "====================================="
printf "${RESET}\n"
