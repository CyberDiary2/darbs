#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
#                                                                              #
#  DARBS - Drew's Auto-Rice Bug Bounty Bootstrapping Scripts                   #
#                                                                              #
#  Author: andrew                                                              #
#  Email : andrew@cyberdiary.net                                               #
#  Description: Based on Luke Smith's LARBS                                    #
#               Automatically sets up a fresh Arch Linux install with XFCE,   #
#               default terminal, bug bounty tools                             #
#                                                                              #
################################################################################

echo -e "\e[38;5;22m
██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║███████║██████╔╝██████╔╝███████║
██║  ██║██╔══██║██╔══██╗██╔══██╗╚════██║
██████╔╝██║  ██║██║  ██║██████╔╝███████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝
\e[0m"

set -e

LOGFILE="$HOME/darbs.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== DARBS (Drew's Auto-Rice Bug Bounty Bootstrapping Scripts) ==="

# ── config ────────────────────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"
DOT_DIR="$HOME/.dotfiles"

# ── colors ────────────────────────────────────────────────────────────────────
GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"

log()  { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "\e[33m[WARN]${RESET} $1"; }

# ── distro detection ──────────────────────────────────────────────────────────
IS_BLACKARCH=false
if grep -qE '^\[blackarch\]' /etc/pacman.conf 2>/dev/null; then
    IS_BLACKARCH=true
fi

if [ "$IS_BLACKARCH" = true ]; then
    echo -e "\e[34m==> Detected BlackArch. Will skip strap.sh bootstrap.\e[0m"
else
    echo -e "\e[34m==> Detected vanilla Arch. Will bootstrap BlackArch repo.\e[0m"
fi

# ── helpers ───────────────────────────────────────────────────────────────────
pacman_install() {
    local to_install=()
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log "skipping $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        if ! sudo pacman -S --noconfirm --needed "${to_install[@]}" 2>/dev/null; then
            warn "bulk install failed, retrying one by one..."
            for pkg in "${to_install[@]}"; do
                sudo pacman -S --noconfirm --needed "$pkg" 2>/dev/null \
                    || warn "skipping $pkg (not found or failed)"
            done
        fi
    fi
}

yay_install() {
    local to_install=()
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log "skipping $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        if ! yay -S --noconfirm "${to_install[@]}" 2>/dev/null; then
            warn "bulk aur install failed, retrying one by one..."
            for pkg in "${to_install[@]}"; do
                yay -S --noconfirm "$pkg" 2>/dev/null \
                    || warn "skipping $pkg (aur: not found or failed)"
            done
        fi
    fi
}

go_install() {
    local pkg="$1"
    local bin
    bin="$(basename "${pkg%%@*}")"
    if command -v "$bin" &>/dev/null; then
        log "skipping $bin (already installed)"
    else
        go install -v "$pkg" || warn "skipping $bin (go install failed)"
    fi
}

# ── system update ─────────────────────────────────────────────────────────────
log "updating system..."
sudo pacman -Syu --noconfirm

# ── base system + xfce ────────────────────────────────────────────────────────
log "installing xfce and core packages..."
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
    texlive \
    texmaker \
    calcurse \
    picom \
    papirus-icon-theme \
    rofi \
    conky \
    sassc \
    xfce4-weather-plugin \
    xfce4-systemload-plugin

# ── enable services ───────────────────────────────────────────────────────────
log "enabling services..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# ── wifi check ────────────────────────────────────────────────────────────────
log "checking for internet connectivity..."
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    log "no internet detected -- launching wifi setup..."
    nmtui connect
fi

# ── display manager ───────────────────────────────────────────────────────────
for dm in sddm gdm lxdm xdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        log "disabling existing display manager: $dm"
        sudo systemctl disable "$dm"
    fi
done
sudo systemctl enable lightdm

# ── blackarch repo ────────────────────────────────────────────────────────────
if [ "$IS_BLACKARCH" = false ]; then
    log "adding blackarch repository..."
    curl -O https://blackarch.org/strap.sh
    chmod +x strap.sh
    sudo ./strap.sh
    rm strap.sh
    sudo pacman -Sy --noconfirm
else
    log "blackarch repo already present, skipping bootstrap."
fi

# ── security tools ────────────────────────────────────────────────────────────
log "installing bug bounty and security tools..."
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

# ── top 100 blackarch tools (additional) ─────────────────────────────────────
log "installing additional blackarch tools..."

# web
pacman_install \
    feroxbuster \
    dirb \
    xsstrike \
    arjun \
    wpscan \
    wafw00f

# recon
pacman_install \
    dnsrecon \
    fierce \
    spiderfoot \
    netdiscover \
    arp-scan \
    dmitry

# passwords / cracking
pacman_install \
    crunch \
    rsmangler \
    fcrackzip \
    hash-identifier \
    ncrack \
    wordlistctl

# wireless
pacman_install \
    mdk4 \
    cowpatty \
    pixiewps \
    bully \
    hostapd-wpe

# active directory / post-exploitation
pacman_install \
    evil-winrm \
    certipy-ad

# network / mitm
pacman_install \
    dsniff \
    sslstrip \
    proxychains-ng \
    hping \
    ngrep

# reverse engineering / exploit dev
pacman_install \
    radare2 \
    python-pwntools

# osint
pacman_install \
    sherlock

# ── kali linux default tools (arch/blackarch equivalents) ────────────────────
log "installing kali default tool equivalents..."

# dns
pacman_install \
    dnschef \
    dnsmap \
    dnstracer \
    dnswalk

# web
pacman_install \
    wapiti \
    weevely \
    xsser \
    sslyze \
    slowhttptest \
    padbuster \
    cutycapt \
    lbd \
    davtest \
    parsero

# network
pacman_install \
    fping \
    tcpreplay \
    ike-scan \
    sslsplit \
    netmask \
    stunnel

# passwords
pacman_install \
    rainbowcrack \
    statsprocessor \
    chntpw \
    polenum

# exploitation
pacman_install \
    legion \
    msfpc

# voip
pacman_install \
    sipvicious

# bluetooth
pacman_install \
    bluelog \
    blueranger \
    bluesnarfer

# misc / post-exploitation
pacman_install \
    smtp-user-enum \
    unix-privesc-check \
    fern-wifi-cracker \
    openvas

# ── 50 more blackarch tools ───────────────────────────────────────────────────
log "installing 50 additional blackarch tools..."

# web
pacman_install \
    sqlninja \
    joomscan \
    skipfish \
    sublist3r \
    whatwaf

# exploitation
pacman_install \
    routersploit \
    set \
    armitage \
    empire

# passwords / cracking
pacman_install \
    hcxtools \
    hcxdumptool \
    hashcat-utils \
    pdfcrack \
    ophcrack \
    pipal \
    truecrack

# wireless
pacman_install \
    airgeddon \
    wifiphisher

# mobile
pacman_install \
    apktool \
    dex2jar \
    androguard

# network / pivoting
pacman_install \
    python-scapy \
    yersinia \
    netsniff-ng \
    p0f \
    tcpflow \
    sshuttle \
    iodine \
    zmap \
    redsocks \
    unicornscan

# forensics
pacman_install \
    scalpel \
    dc3dd \
    perl-image-exiftool \
    testdisk \
    python-oletools \
    peepdf

# reverse engineering / debugging
pacman_install \
    ltrace \
    rizin \
    gdb

# osint / cloud
pacman_install \
    phoneinfoga \
    metagoofil \
    shodan \
    instaloader \
    pacu \
    aws-cli

# auditing
pacman_install \
    lynis

# ── blackarch groups ──────────────────────────────────────────────────────────
log "installing blackarch-webapp group..."
sudo pacman -S --noconfirm --needed blackarch-webapp 2>/dev/null \
    || warn "blackarch-webapp group install had errors, some tools may be missing"

log "installing blackarch-recon group..."
sudo pacman -S --noconfirm --needed blackarch-recon 2>/dev/null \
    || warn "blackarch-recon group install had errors, some tools may be missing"

# ── extra utilities ───────────────────────────────────────────────────────────
log "installing extra utilities..."
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
    python

# ── go ────────────────────────────────────────────────────────────────────────
log "installing go..."
pacman_install go

export GOPATH="$HOME/go"
export PATH="/usr/lib/go/bin:$HOME/go/bin:$HOME/.local/bin:$PATH"

# ── go tools ──────────────────────────────────────────────────────────────────
log "installing go-based tools..."
go_install github.com/tomnomnom/waybackurls@latest
go_install github.com/tomnomnom/httprobe@latest
go_install github.com/tomnomnom/gf@latest
go_install github.com/tomnomnom/assetfinder@latest
go_install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go_install github.com/projectdiscovery/katana/cmd/katana@latest
go_install github.com/projectdiscovery/httpx/cmd/httpx@latest
go_install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go_install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go_install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go_install github.com/hahwul/dalfox/v2@latest
go_install github.com/s0md3v/smap/cmd/smap@latest
go_install github.com/sensepost/gowitness@latest
go_install github.com/haccer/subjack@latest
go_install github.com/ropnop/kerbrute@latest
go_install github.com/jpillora/chisel@latest
go_install github.com/nicocha30/ligolo-ng/cmd/proxy@latest

mkdir -p "$HOME/.gf"
git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null || true
cp /tmp/gf-patterns/*.json "$HOME/.gf/" 2>/dev/null || true
rm -rf /tmp/gf-patterns

# ── yay ───────────────────────────────────────────────────────────────────────
log "installing yay..."
if ! command -v yay &>/dev/null; then
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
fi

# ── aur packages ──────────────────────────────────────────────────────────────
log "installing aur packages..."
yay_install \
    vscodium-bin \
    obsidian \
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

# ── dotfiles ──────────────────────────────────────────────────────────────────
log "cloning dotfiles..."
if [ ! -d "$DOT_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOT_DIR"
else
    log "dotfiles already exist, pulling latest..."
    git -C "$DOT_DIR" pull
fi

# ── bashrc ────────────────────────────────────────────────────────────────────
log "setting up bashrc..."
cp "$DOT_DIR/bashrc" "$HOME/.bashrc"
echo 'export GOPATH=$HOME/go' >> "$HOME/.bashrc"
echo 'export PATH=/usr/lib/go/bin:$HOME/go/bin:$HOME/.local/bin:$PATH' >> "$HOME/.bashrc"

# ── nanorc ────────────────────────────────────────────────────────────────────
log "setting up nanorc..."
cp "$DOT_DIR/nanorc.nanorc" "$HOME/.nanorc"

# ── tmux ──────────────────────────────────────────────────────────────────────
log "setting up tmux config..."
[ -f "$DOT_DIR/tmux-help.txt" ] && cp "$DOT_DIR/tmux-help.txt" "$HOME/.tmux-help.txt"
if [ -f "$SCRIPT_DIR/.tmux.conf" ]; then
    cp "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
elif [ -f "$DOT_DIR/.tmux.conf" ]; then
    cp "$DOT_DIR/.tmux.conf" "$HOME/.tmux.conf"
else
    warn "no .tmux.conf found in darbs repo or dotfiles repo"
fi

# ── xfce4 config ──────────────────────────────────────────────────────────────
log "setting up xfce4 config..."
XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

if [ -d "$HOME/.config/xfce4" ]; then
    mv "$HOME/.config/xfce4" "$HOME/.config/xfce4.bak.$(date +%s)"
    log "backed up existing xfce4 config"
fi
mkdir -p "$XFCONF_DIR"

if [ -d "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml" ]; then
    cp "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml/"*.xml "$XFCONF_DIR/"
    sed -i "s|/home/drew|$HOME|g" "$XFCONF_DIR/xfce4-desktop.xml"
    log "xfce4 xml configs copied"
else
    warn "xfce4/xfconf/xfce-perchannel-xml not found in dotfiles repo"
fi

cat > "$HOME/.config/xfce4/helpers.rc" <<EOF
TerminalEmulator=xfce4-terminal
EOF

# ── gtk theme (everforest) ────────────────────────────────────────────────────
log "installing everforest gtk theme..."
mkdir -p "$HOME/.themes"
rm -rf /tmp/everforest
git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
bash /tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes"
rm -rf /tmp/everforest

# ── gtk / picom / rofi / autostart ───────────────────────────────────────────
log "applying gtk, picom, rofi, autostart configs..."

mkdir -p "$HOME/.config/gtk-3.0"
[ -f "$DOT_DIR/gtk-3.0/settings.ini" ] && cp "$DOT_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
[ -f "$DOT_DIR/gtk-2.0/gtkrc-2.0" ]   && cp "$DOT_DIR/gtk-2.0/gtkrc-2.0" "$HOME/.gtkrc-2.0"

mkdir -p "$HOME/.config/picom"
[ -f "$DOT_DIR/picom/picom.conf" ] && cp "$DOT_DIR/picom/picom.conf" "$HOME/.config/picom/picom.conf"

mkdir -p "$HOME/.config/conky"
[ -f "$DOT_DIR/conky/conky.conf" ] && cp "$DOT_DIR/conky/conky.conf" "$HOME/.config/conky/conky.conf"

mkdir -p "$HOME/.config/rofi"
[ -f "$DOT_DIR/rofi/config.rasi" ] && cp "$DOT_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"

mkdir -p "$HOME/.config/autostart"
if [ -d "$DOT_DIR/autostart" ]; then
    cp "$DOT_DIR/autostart/"*.desktop "$HOME/.config/autostart/" 2>/dev/null || true
fi

# ── wallpapers ────────────────────────────────────────────────────────────────
log "setting up wallpapers..."
mkdir -p "$HOME/wallpapers"
if [ -d "$DOT_DIR/wallpapers" ]; then
    cp -r "$DOT_DIR/wallpapers/." "$HOME/wallpapers/"
fi

WALL="$HOME/wallpapers/0327.jpg"
if [ -n "$DISPLAY" ] && [ -f "$WALL" ]; then
    xfconf-query -c xfce4-desktop -l | grep last-image | while read -r path; do
        xfconf-query -c xfce4-desktop -p "$path" -s "$WALL"
    done
    xfconf-query -c xfce4-desktop -l | grep image-style | while read -r path; do
        xfconf-query -c xfce4-desktop -p "$path" -s 3
    done
else
    warn "no display detected -- set wallpaper manually after login"
fi

# ── lightdm greeter ───────────────────────────────────────────────────────────
log "configuring lightdm greeter..."
if [ -f "$DOT_DIR/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$DOT_DIR/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
    sudo mkdir -p /usr/share/themes
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/ 2>/dev/null || true
fi

# ── done ──────────────────────────────────────────────────────────────────────
log "darbs installation complete!"
echo ""
echo -e "${BLUE}=====================================${RESET}"
echo " done! reboot into xfce."
echo -e "${BLUE}=====================================${RESET}"
