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

pip_install() {
    local pkg="$1"
    if pip show "$pkg" &>/dev/null 2>&1; then
        log "Skipping $pkg (already installed via pip)"
    else
        pip install --break-system-packages "$pkg" 2>/dev/null || \
        pip install --user "$pkg" 2>/dev/null || \
        log "WARNING: failed to pip install $pkg"
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
log "Checking pacman keyring..."

# clock check
NOW_YEAR="$(date +%Y)"
if [ "$NOW_YEAR" -lt 2024 ] || [ "$NOW_YEAR" -gt 2100 ]; then
    echo "ERROR: system clock looks wrong: $(date)"
    echo "Fix with: sudo date -s \"\$(curl -sI https://google.com | grep -i '^date:' | cut -d' ' -f2-)\""
    exit 1
fi

# test if the keyring is already healthy: list-keys returns output and a test
# install succeeds without signature errors
_keyring_healthy() {
    sudo pacman-key --list-keys 2>/dev/null | grep -q '.' || return 1
    sudo pacman -Si artix-keyring &>/dev/null || return 1
    return 0
}

if _keyring_healthy; then
    log "Keyring already initialized, skipping reinit."
    if ! sudo pacman -Syy --noconfirm; then
        echo "ERROR: pacman -Syy failed. Check mirror / network."
        exit 1
    fi
else
    log "Keyring missing or broken — reinitializing..."

    sudo killall gpg-agent dirmngr gpg 2>/dev/null || true
    sleep 1
    sudo rm -rf /etc/pacman.d/gnupg

    if ! pacman -Qi artix-keyring &>/dev/null; then
        log "artix-keyring not installed — fix base install and rerun"
    fi

    if ! pacman -Qi haveged &>/dev/null; then
        sudo pacman -S --noconfirm haveged 2>/dev/null || log "haveged not installed (continuing)"
    fi
    sudo haveged -w 1024 2>/dev/null &
    HAVEGED_PID=$!

    if ! sudo pacman-key --init; then
        echo "ERROR: pacman-key --init failed."
        exit 1
    fi

    sudo pacman-key --populate artix
    if ls /usr/share/pacman/keyrings/archlinux*.gpg &>/dev/null; then
        sudo pacman-key --populate archlinux 2>/dev/null || true
    fi

    if ! sudo pacman-key --list-keys 2>/dev/null | grep -q '.'; then
        log "WARNING: no keys after populate, trying --refresh-keys..."
        sudo pacman-key --refresh-keys 2>/dev/null || log "WARNING: --refresh-keys failed"
    fi

    if ! sudo pacman -Syy --noconfirm; then
        echo "ERROR: pacman -Syy failed."
        kill "$HAVEGED_PID" 2>/dev/null || true
        exit 1
    fi

    kill "$HAVEGED_PID" 2>/dev/null || true
fi

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
# ADD BLACKARCH REPO (if needed)
# -----------------------------
if ! grep -qE '^\[blackarch\]' /etc/pacman.conf 2>/dev/null; then
    log "Adding BlackArch repository..."
    curl -O https://blackarch.org/strap.sh
    chmod +x strap.sh
    sudo ./strap.sh
    rm -f strap.sh
    sudo pacman -Sy --noconfirm
else
    log "BlackArch repo already present, skipping."
fi

# -----------------------------
# ELOGIND (libsystemd shim for Artix)
# lets BlackArch packages that link against libsystemd.so install correctly
# -----------------------------
pacman_install elogind

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
    nuclei-templates \
    proxychains-ng \
    android-tools \
    semgrep

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
go_install github.com/tomnomnom/anew@latest
go_install github.com/tomnomnom/qsreplace@latest
go_install github.com/tomnomnom/unfurl@latest
go_install github.com/tomnomnom/meg@latest
go_install github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest
go_install github.com/devploit/nomore403@latest

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
    espanso \
    apktool \
    jadx \
    aws-cli-v2

# -----------------------------
# PIP SECURITY TOOLS
# -----------------------------
log "Installing pip security tools..."
pip_install uro
pip_install corscanner
pip_install jwt_tool
pip_install s3scanner

# -----------------------------
# PLYMOUTH DARBS SPLASH THEME
# (boot splash, shutdown splash, LUKS encryption prompt)
# -----------------------------
if [ -f /usr/share/plymouth/themes/darbs/darbs.script ]; then
    log "darbs Plymouth theme already installed, skipping."
else
log "Installing Plymouth with darbs branding..."

pacman_install imagemagick
yay_install plymouth

sudo mkdir -p /usr/share/plymouth/themes/darbs

# generate ASCII art logo PNG (fallback to plain text if font missing)
sudo convert \
    -background "#0d1210" \
    -fill "#5a9e44" \
    -font "DejaVu-Sans-Mono-Bold" \
    -pointsize 22 \
    label:"$(printf '██████╗  █████╗ ██████╗ ██████╗ ███████╗\n██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝\n██║  ██║███████║██████╔╝██████╔╝███████╗\n██║  ██║██╔══██║██╔══██╗██╔══██╗╚════██║\n██████╔╝██║  ██║██║  ██║██████╔╝███████║\n╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝')" \
    /usr/share/plymouth/themes/darbs/logo.png 2>/dev/null || \
sudo convert -size 500x80 xc:"#0d1210" \
    -fill "#5a9e44" \
    -font "DejaVu-Sans-Mono-Bold" \
    -pointsize 60 \
    -gravity Center \
    -annotate 0 "DARBS" \
    /usr/share/plymouth/themes/darbs/logo.png 2>/dev/null || \
    log "WARNING: ImageMagick logo generation failed"

# progress bar images
sudo convert -size 400x8 xc:"#1a2a16" \
    /usr/share/plymouth/themes/darbs/bar-bg.png 2>/dev/null || true
sudo convert -size 2x8 xc:"#5a9e44" \
    /usr/share/plymouth/themes/darbs/bar-fill.png 2>/dev/null || true

# theme descriptor
sudo tee /usr/share/plymouth/themes/darbs/darbs.plymouth > /dev/null <<'EOF'
[Plymouth Theme]
Name=darbs
Description=DARBS - Everforest dark splash with LUKS prompt
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/darbs
ScriptFile=/usr/share/plymouth/themes/darbs/darbs.script
EOF

# Plymouth rendering script
sudo tee /usr/share/plymouth/themes/darbs/darbs.script > /dev/null <<'PLYSCRIPT'
# darbs Plymouth theme — colors match Everforest dark
# bg=#0d1210  green=#5a9e44  text=#d3c6aa  muted=#83a598

Window.SetBackgroundTopColor(0.051, 0.071, 0.063);
Window.SetBackgroundBottomColor(0.031, 0.047, 0.039);

# Logo
logo_img = Image("logo.png");
if (logo_img) {
    logo_sprite = Sprite(logo_img);
    logo_sprite.SetX(Window.GetWidth() / 2 - logo_img.GetWidth() / 2);
    logo_sprite.SetY(Window.GetHeight() / 2 - logo_img.GetHeight() / 2 - 70);
    logo_sprite.SetZ(1);
}

# Progress bar track
bar_w = 400; bar_h = 8;
bar_x = Window.GetWidth() / 2 - bar_w / 2;
bar_y = Window.GetHeight() / 2 + 70;

bar_bg_img = Image("bar-bg.png");
if (bar_bg_img) {
    bar_bg_sprite = Sprite(Image.Scale(bar_bg_img, bar_w, bar_h));
    bar_bg_sprite.SetX(bar_x);
    bar_bg_sprite.SetY(bar_y);
    bar_bg_sprite.SetZ(2);
}

progress = 0;
bar_fill_base = Image("bar-fill.png");
bar_fill_sprite = Sprite();
bar_fill_sprite.SetX(bar_x);
bar_fill_sprite.SetY(bar_y);
bar_fill_sprite.SetZ(3);

fun refresh_callback() {
    progress = progress + 0.003;
    if (progress > 1) { progress = 1; }
    fill_w = Math.Int(bar_w * progress);
    if (fill_w < 2) { fill_w = 2; }
    if (bar_fill_base) {
        bar_fill_sprite.SetImage(Image.Scale(bar_fill_base, fill_w, bar_h));
    }
}
Plymouth.SetRefreshFunction(refresh_callback);

# Boot status line
status_sprite = Sprite();
status_sprite.SetZ(4);

fun status_callback(text) {
    status_img = Image.Text(text, 0.514, 0.584, 0.455);
    status_sprite.SetImage(status_img);
    status_sprite.SetX(Window.GetWidth() / 2 - status_img.GetWidth() / 2);
    status_sprite.SetY(bar_y + 20);
}
Plymouth.SetUpdateStatusFunction(status_callback);

# LUKS encryption / password prompt
prompt_sprite = Sprite();
prompt_sprite.SetZ(5);
bullets_sprite = Sprite();
bullets_sprite.SetZ(5);

fun display_password_callback(prompt, bullets) {
    prompt_img = Image.Text(prompt, 0.353, 0.620, 0.267);
    prompt_sprite.SetImage(prompt_img);
    prompt_sprite.SetX(Window.GetWidth() / 2 - prompt_img.GetWidth() / 2);
    prompt_sprite.SetY(Window.GetHeight() / 2 + 20);
    prompt_sprite.SetOpacity(1);

    stars = "";
    for (i = 0; i < bullets; i++) { stars = stars + "*"; }
    bullets_img = Image.Text("[ " + stars + " ]", 0.827, 0.776, 0.667);
    bullets_sprite.SetImage(bullets_img);
    bullets_sprite.SetX(Window.GetWidth() / 2 - bullets_img.GetWidth() / 2);
    bullets_sprite.SetY(Window.GetHeight() / 2 + 48);
    bullets_sprite.SetOpacity(1);
}
Plymouth.SetDisplayPasswordFunction(display_password_callback);

fun display_normal_callback() {
    prompt_sprite.SetOpacity(0);
    bullets_sprite.SetOpacity(0);
}
Plymouth.SetDisplayNormalFunction(display_normal_callback);
PLYSCRIPT

# set darbs as the default theme (safe — only writes a config file)
sudo plymouth-set-default-theme darbs 2>/dev/null || true

log "darbs Plymouth theme files installed."
echo ""
echo "=========================================================="
echo " PLYMOUTH MANUAL ACTIVATION — do these steps yourself:"
echo "=========================================================="
echo ""
echo " 1. Verify Plymouth hooks are present:"
echo "      ls /usr/lib/initcpio/hooks/plymouth"
echo "      ls /usr/lib/initcpio/hooks/plymouth-encrypt"
echo ""
echo " 2. Edit /etc/mkinitcpio.conf HOOKS line:"
echo "    - Using LUKS: replace 'encrypt' with 'plymouth plymouth-encrypt'"
echo "    - No LUKS:    add 'plymouth' before 'filesystems'"
echo "    Current HOOKS:"
grep '^HOOKS' /etc/mkinitcpio.conf 2>/dev/null || echo "    (could not read mkinitcpio.conf)"
echo ""
echo " 3. Rebuild initramfs:"
echo "      sudo mkinitcpio -P"
echo ""
echo " 4. Add 'quiet splash' to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
echo "    then run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
echo ""
echo " 5. Reboot."
echo "=========================================================="
echo ""
fi  # end plymouth skip block

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
if grep -q 'DARBS_CONFIGURED' "$HOME/.bashrc" 2>/dev/null; then
    log "Bashrc already configured, skipping (remove DARBS_CONFIGURED line to force reset)."
else
    log "Setting up bashrc..."
    cp "$DOT_DIR/bashrc" "$HOME/.bashrc"
    echo 'export PATH=$PATH:/usr/lib/go/bin:$HOME/go/bin' >> "$HOME/.bashrc"
    echo '# DARBS_CONFIGURED' >> "$HOME/.bashrc"
fi

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

if [ ! -d "$XFCONF_DIR" ]; then
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
else
    log "XFCE config already present, skipping (delete ~/.config/xfce4 to force reset)."
fi

# -----------------------------
# GTK THEME (Everforest)
# -----------------------------
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    log "Everforest theme already installed, skipping."
else
    log "Installing Everforest GTK theme..."
    pacman_install sassc
    mkdir -p "$HOME/.themes"
    rm -rf /tmp/everforest
    git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
    /tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes" || log "WARNING: Everforest install.sh failed"
    if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
        log "Everforest theme installed successfully."
    else
        log "WARNING: Everforest-Green-Dark not found in ~/.themes"
    fi
    rm -rf /tmp/everforest
fi

# -----------------------------
# THEMING / RICING
# -----------------------------
log "Applying darbs Everforest theme..."

# GTK settings written directly -- not copied from dotfiles which may be stale
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name = Everforest-Green-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Noto Sans 10
gtk-cursor-theme-name = Adwaita
gtk-cursor-theme-size = 0
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
EOF

cat > "$HOME/.gtkrc-2.0" <<'EOF'
gtk-theme-name = "Everforest-Green-Dark"
gtk-icon-theme-name = "Papirus-Dark"
gtk-font-name = "Noto Sans 10"
gtk-cursor-theme-name = "Adwaita"
gtk-cursor-theme-size = 0
EOF

mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name = Everforest-Green-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Noto Sans 10
gtk-cursor-theme-name = Adwaita
EOF

# xfconf XML files -- written directly so they survive without a live session
XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF_DIR"

cat > "$XFCONF_DIR/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Everforest-Green-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
    <property name="DPI" type="int" value="-1"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Noto Sans Mono 10"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="0"/>
    <property name="DecorationLayout" type="string" value="menu:minimize,maximize,close"/>
  </property>
</channel>
EOF

cat > "$XFCONF_DIR/xfwm4.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Everforest-Green-Dark"/>
    <property name="title_font" type="string" value="Noto Sans Bold 9"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="CMH|"/>
    <property name="use_compositing" type="bool" value="true"/>
  </property>
</channel>
EOF

# apply live if running inside a desktop session
if command -v xfconf-query &>/dev/null && [ -n "$DISPLAY" ]; then
    xfconf-query -c xsettings -p /Net/ThemeName        -s "Everforest-Green-Dark" --create -t string
    xfconf-query -c xsettings -p /Net/IconThemeName     -s "Papirus-Dark"          --create -t string
    xfconf-query -c xsettings -p /Gtk/FontName          -s "Noto Sans 10"          --create -t string
    xfconf-query -c xsettings -p /Gtk/CursorThemeName   -s "Adwaita"               --create -t string
    xfconf-query -c xsettings -p /Xft/Antialias         -s 1                       --create -t int
    xfconf-query -c xsettings -p /Xft/Hinting           -s 1                       --create -t int
    xfconf-query -c xsettings -p /Xft/HintStyle         -s "hintslight"            --create -t string
    xfconf-query -c xsettings -p /Xft/RGBA              -s "rgb"                   --create -t string
    xfconf-query -c xfwm4     -p /general/theme         -s "Everforest-Green-Dark" --create -t string
    xfconf-query -c xfwm4     -p /general/title_font    -s "Noto Sans Bold 9"      --create -t string
fi

# dotfiles: picom, rofi, autostart (not GTK -- those are forced above)
mkdir -p "$HOME/.config/picom"
[ -f "$DOT_DIR/picom/picom.conf" ] && cp "$DOT_DIR/picom/picom.conf" "$HOME/.config/picom/picom.conf"

mkdir -p "$HOME/.config/rofi"
[ -f "$DOT_DIR/rofi/config.rasi" ] && cp "$DOT_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"

mkdir -p "$HOME/.config/autostart"
[ -d "$DOT_DIR/autostart" ] && cp "$DOT_DIR/autostart/"*.desktop "$HOME/.config/autostart/" 2>/dev/null || true

# -----------------------------
# WALLPAPERS
# -----------------------------
log "Setting up wallpapers directory..."
mkdir -p "$HOME/wallpapers"
if [ -d "$DOT_DIR/wallpapers" ]; then
    # --ignore-existing skips files already present so reruns don't copy everything again
    cp -r --no-clobber "$DOT_DIR/wallpapers/." "$HOME/wallpapers/"
    log "Wallpapers synced from dotfiles (existing files untouched)."
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
# WHISKER MENU - SECURITY SHORTCUTS
# -----------------------------
mkdir -p "$HOME/.local/share/applications"
_sec_count=$(ls "$HOME/.local/share/applications/sec-"*.desktop 2>/dev/null | wc -l)
if [ "$_sec_count" -ge 75 ]; then
    log "Security shortcuts already created ($_sec_count found), skipping."
else
log "Creating security tool shortcuts for Whisker Menu..."

# Helper: creates a .desktop entry that opens xfce4-terminal running the tool.
# Terminal=true lets xfce4-terminal (set as default) launch automatically.
# Usage: sec_desktop "Menu Name" "exec string" "Tooltip" "SubCategory"
sec_desktop() {
    local name="$1" exec="$2" desc="$3" sub="$4"
    local slug
    slug="$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    cat > "$HOME/.local/share/applications/sec-${slug}.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$desc
Exec=sh -c '$exec; \$SHELL'
Icon=utilities-terminal
Terminal=true
Categories=Security;${sub};
Keywords=${slug};security;pentest;hacking;
EOF
}

# ── Reconnaissance ──────────────────────────────────────────────────────────
sec_desktop "Amass"          "amass -h"                         "Subdomain enumeration"             "Reconnaissance"
sec_desktop "Subfinder"      "subfinder -h"                     "Passive subdomain discovery"        "Reconnaissance"
sec_desktop "Assetfinder"    "assetfinder -h"                   "Find domains and subdomains"        "Reconnaissance"
sec_desktop "TheHarvester"   "theHarvester -h"                  "Email, subdomain, IP harvester"     "Reconnaissance"
sec_desktop "Recon-ng"       "recon-ng"                         "Web reconnaissance framework"       "Reconnaissance"
sec_desktop "Sherlock"       "sherlock -h"                      "Username hunt across social media"  "Reconnaissance"
sec_desktop "Sublist3r"      "sublist3r -h"                     "Sublist3r subdomain scanner"        "Reconnaissance"
sec_desktop "Shodan CLI"     "shodan -h"                        "Shodan command-line client"         "Reconnaissance"
sec_desktop "DNSEnum"        "dnsenum -h"                       "DNS enumeration"                    "Reconnaissance"
sec_desktop "MassDNS"        "massdns -h"                       "High-performance DNS resolver"      "Reconnaissance"
sec_desktop "DNSX"           "dnsx -h"                          "Fast DNS toolkit"                   "Reconnaissance"
sec_desktop "Waybackurls"    "waybackurls -h"                   "Fetch URLs from Wayback Machine"    "Reconnaissance"
sec_desktop "GAU"            "gau -h"                           "Get all URLs (AlienVault + Wayback)" "Reconnaissance"
sec_desktop "Httprobe"       "httprobe -h"                      "Probe for live HTTP/S hosts"        "Reconnaissance"
sec_desktop "Gowitness"      "gowitness -h"                     "Web screenshot utility"             "Reconnaissance"
sec_desktop "Chaos"          "chaos -h"                         "ProjectDiscovery chaos client"      "Reconnaissance"
sec_desktop "Shuffledns"     "shuffledns -h"                    "Mass DNS resolver using massdns"    "Reconnaissance"

# ── Scanning ─────────────────────────────────────────────────────────────────
sec_desktop "Nmap"           "nmap --help 2>&1 | head -60"      "Network port scanner"               "Scanner"
sec_desktop "Masscan"        "masscan --help 2>&1 | head -40"   "Mass IP port scanner"               "Scanner"
sec_desktop "Naabu"          "naabu -h"                         "Fast port scanner"                  "Scanner"
sec_desktop "Smap"           "smap -h"                          "Shodan-powered port scanner"        "Scanner"
sec_desktop "Whatweb"        "whatweb -h"                       "Web technology fingerprinter"       "Scanner"
sec_desktop "Nuclei"         "nuclei -h"                        "Template-based vulnerability scanner" "Scanner"
sec_desktop "Nikto"          "nikto -h"                         "Web server vulnerability scanner"   "Scanner"

# ── Web Application ──────────────────────────────────────────────────────────
sec_desktop "Gobuster"       "gobuster -h"                      "Directory/DNS brute-forcer"         "WebApp"
sec_desktop "FFuf"           "ffuf -h"                          "Web fuzzer"                         "WebApp"
sec_desktop "Feroxbuster"    "feroxbuster -h"                   "Recursive content discovery"        "WebApp"
sec_desktop "Wfuzz"          "wfuzz -h"                         "Web application fuzzer"             "WebApp"
sec_desktop "Dirsearch"      "dirsearch -h"                     "Web path scanner"                   "WebApp"
sec_desktop "SQLMap"         "sqlmap -h"                        "SQL injection tool"                 "WebApp"
sec_desktop "WPScan"         "wpscan -h"                        "WordPress vulnerability scanner"    "WebApp"
sec_desktop "Commix"         "commix -h"                        "Command injection exploiter"        "WebApp"
sec_desktop "Arjun"          "arjun -h"                         "HTTP parameter discovery"           "WebApp"
sec_desktop "Dalfox"         "dalfox -h"                        "XSS scanning and parameter analysis" "WebApp"
sec_desktop "Katana"         "katana -h"                        "Next-gen web crawler"               "WebApp"
sec_desktop "Hakrawler"      "hakrawler -h"                     "Simple web crawler"                 "WebApp"
sec_desktop "HTTPX"          "httpx -h"                         "HTTP toolkit"                       "WebApp"
sec_desktop "GF"             "gf -h"                            "Grep with predefined patterns"      "WebApp"
sec_desktop "Mitmproxy"      "mitmproxy -h"                     "Interactive HTTPS proxy"            "WebApp"
sec_desktop "Mitmweb"        "mitmweb"                          "Mitmproxy web interface"            "WebApp"

# ── Password ─────────────────────────────────────────────────────────────────
sec_desktop "Hydra"          "hydra -h 2>&1 | head -40"         "Network login brute-forcer"         "Password"
sec_desktop "John"           "john --help 2>&1 | head -40"      "John the Ripper password cracker"   "Password"
sec_desktop "Hashcat"        "hashcat -h 2>&1 | head -40"       "GPU password cracker"               "Password"
sec_desktop "Medusa"         "medusa -h 2>&1 | head -40"        "Parallel login brute-forcer"        "Password"
sec_desktop "Patator"        "patator -h"                       "Multi-purpose brute-forcer"         "Password"
sec_desktop "CeWL"           "cewl -h"                          "Custom wordlist generator"          "Password"

# ── Wireless ─────────────────────────────────────────────────────────────────
sec_desktop "Aircrack-ng"    "aircrack-ng --help"               "WiFi security auditing suite"       "Wireless"
sec_desktop "Airodump-ng"    "airodump-ng --help"               "WiFi packet capture"                "Wireless"
sec_desktop "Aireplay-ng"    "aireplay-ng --help"               "WiFi injection and replay"          "Wireless"
sec_desktop "Wifite"         "wifite -h"                        "Automated wireless auditor"         "Wireless"
sec_desktop "Reaver"         "reaver -h"                        "WPS brute-force attack"             "Wireless"
sec_desktop "Kismet"         "kismet --help"                    "Wireless network detector/sniffer"  "Wireless"
sec_desktop "Bettercap"      "bettercap -h"                     "Network attacks and monitoring"     "Wireless"
sec_desktop "Macchanger"     "macchanger -h"                    "MAC address changer"                "Wireless"

# ── Exploitation ─────────────────────────────────────────────────────────────
sec_desktop "Metasploit"     "msfconsole"                       "Penetration testing framework"      "Exploitation"
sec_desktop "CrackMapExec"   "crackmapexec -h"                  "SMB/AD exploitation"                "Exploitation"
sec_desktop "Impacket"       "echo 'Impacket tools: psexec.py secretsdump.py wmiexec.py smbclient.py'; ls /usr/lib/python3*/dist-packages/impacket/examples/*.py 2>/dev/null | xargs -I{} basename {} .py | sort" \
                                                                 "Impacket Windows protocol tools"    "Exploitation"
sec_desktop "Responder"      "responder -h"                     "LLMNR/NBT-NS poisoner"              "Exploitation"
sec_desktop "Enum4linux-ng"  "enum4linux-ng -h"                 "SMB/NetBIOS enumeration"            "Exploitation"
sec_desktop "Bloodhound"     "bloodhound-python -h"             "AD attack path mapper (collector)"  "Exploitation"
sec_desktop "Searchsploit"   "searchsploit -h"                  "Exploit-DB offline search"          "Exploitation"
sec_desktop "Interactsh"     "interactsh-client -h"             "OOB interaction server client"      "Exploitation"

# ── Forensics ────────────────────────────────────────────────────────────────
sec_desktop "Binwalk"        "binwalk -h"                       "Firmware analysis and extraction"   "Forensics"
sec_desktop "Foremost"       "foremost -h"                      "File recovery by header/footer"     "Forensics"
sec_desktop "Volatility3"    "vol -h"                           "Memory forensics framework"         "Forensics"
sec_desktop "Strings"        "strings --help"                   "Extract printable strings"          "Forensics"

# ── MITM / Capture ───────────────────────────────────────────────────────────
sec_desktop "Ettercap"       "ettercap -h"                      "MITM attack suite"                  "MITM"
sec_desktop "TCPDump"        "tcpdump -h 2>&1 | head -40"       "Packet capture"                     "MITM"
sec_desktop "Socat"          "socat -h 2>&1 | head -40"         "Multipurpose relay"                 "MITM"

# ── Secrets & OSINT ──────────────────────────────────────────────────────────
sec_desktop "TruffleHog"     "trufflehog -h"                    "Credential scanner in git repos"    "Secrets"
sec_desktop "Gitleaks"       "gitleaks -h"                      "Detect secrets in git history"      "Secrets"
sec_desktop "Subjack"        "subjack -h"                       "Subdomain takeover detection"       "Secrets"
sec_desktop "Semgrep"        "semgrep --help"                   "SAST scanner for code review"       "Secrets"

# ── URL / Pipeline Utilities ─────────────────────────────────────────────────
sec_desktop "Anew"           "anew -h"                          "Append new unique lines to file"    "WebApp"
sec_desktop "Qsreplace"      "qsreplace -h"                     "Replace query string values"        "WebApp"
sec_desktop "Unfurl"         "unfurl -h"                        "Extract URL components"             "WebApp"
sec_desktop "Meg"            "meg -h"                           "Fetch many paths for many hosts"    "WebApp"
sec_desktop "URO"            "uro -h"                           "Deduplicate and clean URL lists"    "WebApp"

# ── Injection / Bypass ───────────────────────────────────────────────────────
sec_desktop "CRLFuzz"        "crlfuzz -h"                       "CRLF injection scanner"             "WebApp"
sec_desktop "NoMore403"      "nomore403 -h"                     "403 Forbidden bypass tool"          "WebApp"
sec_desktop "CORScanner"     "corscanner -h"                    "CORS misconfiguration scanner"      "WebApp"
sec_desktop "JWT Tool"       "jwt_tool -h"                      "JWT security testing toolkit"       "WebApp"

# ── Cloud ─────────────────────────────────────────────────────────────────────
sec_desktop "AWS CLI"        "aws --version && aws help"        "Amazon Web Services CLI"            "Cloud"
sec_desktop "S3Scanner"      "s3scanner -h"                     "Open S3 bucket scanner"             "Cloud"

# ── Mobile ───────────────────────────────────────────────────────────────────
sec_desktop "Apktool"        "apktool -h"                       "APK decompilation and rebuilding"   "Mobile"
sec_desktop "JADX"           "jadx --help"                      "Java decompiler for Android APKs"   "Mobile"
sec_desktop "ADB"            "adb --version && adb help"        "Android Debug Bridge"               "Mobile"

# ── Proxy / Anonymity ────────────────────────────────────────────────────────
sec_desktop "Proxychains"    "proxychains -h 2>&1 | head -30"  "Route tools through proxy chain"    "MITM"

# ── Update desktop database so Whisker picks up new entries ──────────────────
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

log "Security shortcuts created in ~/.local/share/applications"
log "They will appear under 'Security' in Whisker Menu."
fi  # end security shortcuts skip block

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
