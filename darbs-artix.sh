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

# not using set -e so one failed package doesn't kill the whole script

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
        if ! sudo pacman -S --noconfirm "${to_install[@]}"; then
            log "Batch pacman install failed, retrying packages individually..."
            for pkg in "${to_install[@]}"; do
                sudo pacman -S --noconfirm "$pkg" 2>/dev/null || log "WARNING: failed to install $pkg (skipping)"
            done
        fi
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
        if ! yay -S --noconfirm "${to_install[@]}"; then
            log "Batch yay install failed, retrying packages individually..."
            for pkg in "${to_install[@]}"; do
                yay -S --noconfirm "$pkg" 2>/dev/null || log "WARNING: failed to install $pkg (skipping)"
            done
        fi
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
# FIX BROKEN PACMAN.CONF (from failed previous runs)
# -----------------------------
if grep -q 'mirrorlist-arch' /etc/pacman.conf 2>/dev/null && [ ! -f /etc/pacman.d/mirrorlist-arch ]; then
    log "Fixing broken Arch repo entries in pacman.conf..."
    sudo sed -i '/^\[extra\]/,/^$/d' /etc/pacman.conf
    sudo sed -i '/^\[multilib\]/,/^$/d' /etc/pacman.conf
    sudo sed -i '/mirrorlist-arch/d' /etc/pacman.conf
fi

# -----------------------------
# INITIALIZE PACMAN KEYRING
# -----------------------------
log "Initializing pacman keyring..."

# clock check: wrong system time is the #1 cause of "signature invalid" / key
# import failures because GPG rejects keys that look like they're from the future
NOW_YEAR="$(date +%Y)"
if [ "$NOW_YEAR" -lt 2024 ] || [ "$NOW_YEAR" -gt 2100 ]; then
    echo
    echo "ERROR: system clock looks wrong: $(date)"
    echo "Fix with one of:"
    echo "  sudo date -s \"\$(curl -sI https://google.com | grep -i '^date:' | cut -d' ' -f2-)\""
    echo "  sudo ntpd -q -p pool.ntp.org"
    echo "Then rerun this script."
    exit 1
fi

# kill stuck gpg-agent / dirmngr from previous failed runs
sudo killall gpg-agent dirmngr gpg 2>/dev/null || true
sleep 1

# nuke any half-broken keyring and start fresh
sudo rm -rf /etc/pacman.d/gnupg

# make sure the keyring packages themselves are present on disk; without them
# /usr/share/pacman/keyrings/*.gpg is empty and --populate silently does nothing
if ! pacman -Qi artix-keyring &>/dev/null; then
    log "artix-keyring not installed, this script needs to be rerun after fixing base install"
fi

# install haveged for entropy — fresh VMs / laptops with SSD boots can stall
# pacman-key --init on low entropy. If haveged isn't installed yet we accept
# that and move on; the kernel's jitter entropy usually suffices.
if ! pacman -Qi haveged &>/dev/null; then
    sudo pacman -S --noconfirm haveged 2>/dev/null || log "haveged not installed (continuing)"
fi
sudo haveged -w 1024 2>/dev/null &
HAVEGED_PID=$!

if ! sudo pacman-key --init; then
    echo "ERROR: pacman-key --init failed. Check /etc/pacman.d/gnupg perms."
    exit 1
fi

# populate master keys - if this silently adds nothing, signatures will fail
sudo pacman-key --populate artix
if [ -d /usr/share/pacman/keyrings ] && ls /usr/share/pacman/keyrings/archlinux*.gpg &>/dev/null; then
    sudo pacman-key --populate archlinux 2>/dev/null || true
fi

# verify that populate actually did something; if not, try refresh-keys
if ! sudo pacman-key --list-keys 2>/dev/null | grep -q '.'; then
    log "WARNING: no keys in keyring after populate, trying --refresh-keys (this can take minutes)..."
    sudo pacman-key --refresh-keys 2>/dev/null || log "WARNING: --refresh-keys failed, check network / keyserver"
fi

# sync repo DBs - keep haveged running through the sync for entropy
# fail loudly so user sees the actual error instead of
# having every subsequent package "skip" with a WARNING line
if ! sudo pacman -Syy --noconfirm; then
    echo
    echo "ERROR: pacman -Syy failed. Common causes:"
    echo "  - Keyring still broken: sudo pacman -S archlinux-keyring artix-keyring && sudo pacman-key --populate"
    echo "  - System clock wrong:   date   (then: sudo ntpd -q -p pool.ntp.org)"
    echo "  - No internet:          ping archlinux.org"
    echo "  - Dead mirror:          edit /etc/pacman.d/mirrorlist and move a closer one to top"
    kill "$HAVEGED_PID" 2>/dev/null || true
    exit 1
fi

# keyring and first sync succeeded — stop the entropy helper
kill "$HAVEGED_PID" 2>/dev/null || true

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
elif command -v dinitctl &>/dev/null; then
    INIT_SYS="dinit"
else
    # fallback: check pid 1
    case "$(cat /proc/1/comm 2>/dev/null)" in
        openrc-init) INIT_SYS="openrc" ;;
        runit)       INIT_SYS="runit" ;;
        s6-svscan)   INIT_SYS="s6" ;;
        dinit)       INIT_SYS="dinit" ;;
        *)           INIT_SYS="openrc" ; log "WARNING: could not detect init system, defaulting to openrc" ;;
    esac
fi

echo -e "${BLUE}==> Detected init system: $INIT_SYS${RESET}"

# -----------------------------
# EARLY WIFI SETUP
# -----------------------------
log "Checking network connectivity..."

# bring up NetworkManager early if already installed
if command -v nmcli &>/dev/null; then
    service_enable NetworkManager
    service_start NetworkManager
    sleep 3
fi

if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
    log "No internet detected."
    if command -v nmtui &>/dev/null; then
        log "Launching WiFi setup — connect then press Quit..."
        nmtui connect
        sleep 3
    else
        log "nmtui not found. Connect manually with iwctl or wpa_supplicant then rerun."
        echo "  iwctl"
        echo "    station wlan0 scan"
        echo "    station wlan0 connect \"YourSSID\""
        echo "    exit"
    fi

    if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
        echo ""
        echo "ERROR: still no internet. Fix WiFi and rerun the script."
        exit 1
    fi
fi
log "Internet connection confirmed."

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
        dinit)
            sudo dinitctl enable "$svc" 2>/dev/null || true
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
        dinit)
            sudo dinitctl start "$svc" 2>/dev/null || true
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
        dinit)
            sudo dinitctl disable "$svc" 2>/dev/null || true
            ;;
    esac
}

# -----------------------------
# CPU MICROCODE
# -----------------------------
log "Detecting CPU vendor for microcode..."
CPU_VENDOR="$(grep -m1 '^vendor_id' /proc/cpuinfo | awk '{print $3}')"
case "$CPU_VENDOR" in
    GenuineIntel) pacman_install intel-ucode ;;
    AuthenticAMD) pacman_install amd-ucode ;;
    *) log "Unknown CPU vendor ($CPU_VENDOR), skipping microcode" ;;
esac

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
    # install artix-archlinux-support FIRST so mirrorlist-arch exists
    # before pacman.conf references it
    sudo pacman -S --noconfirm artix-archlinux-support
    sudo pacman-key --populate archlinux
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    sudo pacman -Sy --noconfirm
fi

# -----------------------------
# BASE SYSTEM + XFCE
# -----------------------------
log "Installing XFCE and core packages..."

# install init specific packages
pacman_install \
    "networkmanager-$INIT_SYS" \
    "lightdm-$INIT_SYS" \
    "bluez-$INIT_SYS" \
    "cups-$INIT_SYS" \
    "tlp-$INIT_SYS" \
    "docker-$INIT_SYS"

# install xorg, skip vesa to avoid xlibre conflict
sudo pacman -S --noconfirm --ignore xf86-video-vesa xorg 2>/dev/null || true

pacman_install \
    xfce4 xfce4-goodies \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    xfce4-power-manager \
    lightdm lightdm-gtk-greeter \
    networkmanager \
    network-manager-applet \
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
    caligula \
    texlive \
    texmaker \
    xfce4-weather-plugin \
    xfce4-systemload-plugin \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    pavucontrol \
    alsa-utils \
    bluez \
    bluez-utils \
    blueman \
    cups \
    cups-pdf \
    system-config-printer \
    ghostscript \
    tlp \
    noto-fonts \
    noto-fonts-emoji \
    noto-fonts-cjk \
    ttf-dejavu \
    ttf-liberation \
    ttf-hack \
    p7zip \
    unrar \
    file-roller \
    thunar-archive-plugin \
    mpv \
    vlc \
    imv \
    zathura \
    zathura-pdf-mupdf

# -----------------------------
# ENABLE SERVICES
# -----------------------------
log "Enabling services..."
service_enable NetworkManager
service_start NetworkManager
service_enable bluetoothd
service_enable cupsd
service_enable tlp
service_enable docker

# disable conflicting display managers
for dm in sddm gdm lxdm xdm; do
    service_disable "$dm"
done
service_enable lightdm

# -----------------------------
# INSTALL AUR HELPER (YAY) - needed for security tools
# -----------------------------
log "Installing yay..."
if ! command -v yay &> /dev/null; then
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
fi

# -----------------------------
# BUG BOUNTY + SECURITY TOOLS (via yay - handles both repos and AUR)
# -----------------------------
log "Installing bug bounty and security tools..."
yay_install \
    nmap \
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
    impacket \
    seclists \
    commix \
    enum4linux-ng \
    massdns \
    aircrack-ng \
    ettercap \
    kismet \
    binwalk \
    macchanger \
    exploitdb \
    dnsenum \
    cewl \
    wifite \
    reaver \
    foremost \
    socat \
    burpsuite \
    metasploit \
    maltego \
    bloodhound \
    bettercap \
    autopsy \
    volatility3 \
    frida \
    objection \
    crackmapexec \
    wpscan \
    feroxbuster \
    arjun \
    sublist3r \
    trufflehog \
    gitleaks \
    sherlock \
    nuclei-templates

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
go_install github.com/lc/gau/v2/cmd/gau@latest
go_install github.com/hakluke/hakrawler@latest
go_install github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest
go_install github.com/projectdiscovery/notify/cmd/notify@latest
go_install github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
go_install github.com/projectdiscovery/chaos-client/cmd/chaos@latest

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
    python

# -----------------------------
# DEV / QoL TOOLS
# -----------------------------
log "Installing dev and quality-of-life tools..."
pacman_install \
    nodejs \
    npm \
    rustup \
    zoxide \
    lazygit \
    starship \
    docker \
    docker-compose

# initialize rustup with stable toolchain if not already set up
if command -v rustup &>/dev/null && ! rustup show active-toolchain &>/dev/null; then
    log "Setting rustup default toolchain to stable..."
    rustup default stable || log "WARNING: rustup default stable failed"
fi

# add current user to docker group so docker can run without sudo
if getent group docker &>/dev/null; then
    sudo usermod -aG docker "$USER" 2>/dev/null || true
fi

# -----------------------------
# PRODUCTIVITY EXTRAS
# -----------------------------
log "Installing productivity extras..."
pacman_install \
    anki \
    xournalpp \
    gimp \
    atuin \
    syncthing \
    pandoc \
    gajim

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
    beef-xss \
    espanso

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

sed -i "s|/home/drew|$HOME|g" "$XFCONF_DIR/xfce4-desktop.xml" 2>/dev/null || true

cat > "$HOME/.config/xfce4/helpers.rc" <<EOF
TerminalEmulator=xfce4-terminal
EOF

# -----------------------------
# GTK THEME (Everforest)
# -----------------------------
log "Installing Everforest GTK theme..."
# make sure sassc is installed first (needed to compile the theme)
pacman_install sassc
mkdir -p "$HOME/.themes"
rm -rf /tmp/everforest
git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
/tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes" || log "WARNING: Everforest install.sh failed"
# verify the theme was actually created
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    log "Everforest theme installed successfully."
else
    log "WARNING: Everforest-Green-Dark not found in ~/.themes"
fi
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

if command -v xfconf-query &>/dev/null && [ -n "$DISPLAY" ]; then
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image | while read -r path; do
        xfconf-query -c xfce4-desktop -p "$path" -s "$WALL" 2>/dev/null || true
    done
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep image-style | while read -r path; do
        xfconf-query -c xfce4-desktop -p "$path" -s 3 2>/dev/null || true
    done
fi

sudo cp -f ~/wallpapers/0327.jpg /usr/share/backgrounds/xfce/xfce-x.svg 2>/dev/null || true

# -----------------------------
# LIGHTDM GREETER THEME
# -----------------------------
log "Configuring LightDM greeter to match Everforest theme..."
# copy theme to system dir so lightdm (running as root) can access it
sudo mkdir -p /usr/share/themes
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/
fi

# use dotfiles greeter config or create one
if [ -f "$DOT_DIR/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$DOT_DIR/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
else
    sudo tee /etc/lightdm/lightdm-gtk-greeter.conf > /dev/null <<'GREETEREOF'
[greeter]
theme-name = Everforest-Green-Dark
icon-theme-name = Papirus-Dark
font-name = JetBrainsMono Nerd Font 12
background = /usr/share/backgrounds/xfce/xfce-x.svg
user-background = false
position = 50%,center 50%,center
clock-format = %A, %B %d   %H:%M
indicators = ~host;~spacer;~clock;~spacer;~session;~power
GREETEREOF
fi

# make sure lightdm uses the gtk greeter, not some other one
sudo mkdir -p /etc/lightdm
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
else
    sudo tee /etc/lightdm/lightdm.conf > /dev/null <<'LIGHTDMEOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
LIGHTDMEOF
fi

# gf patterns
mkdir -p "$HOME/.gf"
if [ ! "$(ls -A "$HOME/.gf" 2>/dev/null)" ]; then
    git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null && \
        cp /tmp/gf-patterns/*.json "$HOME/.gf/" && \
        rm -rf /tmp/gf-patterns
fi

# PATH already added above, skip duplicate

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
