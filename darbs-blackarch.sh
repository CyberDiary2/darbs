#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
#                                                                              #
#  DARBS - BlackArch                                                           #
#                                                                              #
#  Strips BlackArch branding and applies darbs theming on top of BlackArch.   #
#  Works on a fresh BlackArch install or plain Arch (adds the repo for you).  #
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
echo "=== DARBS (BlackArch) ==="

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
            log "Batch install failed, retrying individually..."
            for pkg in "${to_install[@]}"; do
                sudo pacman -S --noconfirm "$pkg" 2>/dev/null || log "WARNING: failed to install $pkg (skipping)"
            done
        fi
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
            log "Batch yay install failed, retrying individually..."
            for pkg in "${to_install[@]}"; do
                yay -S --noconfirm "$pkg" 2>/dev/null || log "WARNING: failed to install $pkg (skipping)"
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

# -----------------------------
# VERIFY ARCH / BLACKARCH
# -----------------------------
if ! command -v pacman &>/dev/null; then
    echo "ERROR: pacman not found. This script requires Arch or BlackArch Linux."
    exit 1
fi

# -----------------------------
# ADD BLACKARCH REPO (if not already present)
# -----------------------------
if grep -qE '^\[blackarch\]' /etc/pacman.conf 2>/dev/null; then
    log "BlackArch repo already configured, skipping bootstrap."
else
    log "Adding BlackArch repository..."
    curl -O https://blackarch.org/strap.sh
    chmod +x strap.sh
    sudo ./strap.sh
    rm -f strap.sh
fi

# -----------------------------
# SYSTEM UPDATE
# -----------------------------
log "Updating system..."
sudo pacman -Syu --noconfirm

# -----------------------------
# STRIP BLACKARCH BRANDING
# -----------------------------
log "Removing BlackArch branding packages..."

# remove branding packages -- ignore errors since not all may be installed
for pkg in \
    blackarch-config-xfce \
    blackarch-config-gtk \
    blackarch-config-openbox \
    blackarch-config-fluxbox \
    blackarch-config-i3 \
    blackarch-config-awesome \
    blackarch-config-bspwm \
    blackarch-config-lxde \
    blackarch-config-wmii \
    blackarch-config-spectrwm \
    blackarch-config-plymouth \
    blackarch-wallpaper \
    blackarch-menus \
    blackarch-screensavers \
    blackarch-config-xorg; do
    if pacman -Qi "$pkg" &>/dev/null; then
        sudo pacman -R --noconfirm "$pkg" 2>/dev/null || true
    fi
done

log "Removing BlackArch-specific config and theme files..."

# Plymouth
sudo rm -rf /usr/share/plymouth/themes/blackarch 2>/dev/null || true
sudo rm -rf /usr/share/plymouth/themes/blackarch-* 2>/dev/null || true

# Wallpapers and backgrounds
sudo rm -rf /usr/share/backgrounds/blackarch 2>/dev/null || true
sudo rm -rf /usr/share/wallpapers/blackarch 2>/dev/null || true

# BlackArch GTK/icon themes
sudo rm -rf /usr/share/themes/BlackArch* 2>/dev/null || true
sudo rm -rf /usr/share/icons/blackarch* 2>/dev/null || true

# BlackArch LightDM greeter config (we overwrite ours below)
sudo rm -f /etc/lightdm/lightdm-blackarch-greeter.conf 2>/dev/null || true

# BlackArch XFCE configs from user home (we replace these below)
rm -rf "$HOME/.config/xfce4" 2>/dev/null || true

# BlackArch fastfetch/neofetch ascii config
rm -f "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null || true
rm -f "$HOME/.config/neofetch/config.conf" 2>/dev/null || true

log "BlackArch branding removed."

# -----------------------------
# INSTALL AUR HELPER (YAY)
# -----------------------------
log "Checking for yay..."
if ! command -v yay &>/dev/null; then
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
fi

# -----------------------------
# BASE SYSTEM + XFCE
# -----------------------------
log "Installing XFCE and core packages..."

pacman_install \
    xorg \
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
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# disable any display manager already enabled, then enable lightdm
for dm in sddm gdm lxdm xdm; do
    sudo systemctl disable "$dm" 2>/dev/null || true
done
sudo systemctl enable lightdm

sudo systemctl enable bluetooth
sudo systemctl enable cups
sudo systemctl enable tlp

# -----------------------------
# BUG BOUNTY + SECURITY TOOLS
# -----------------------------
log "Installing bug bounty and security tools..."
# BlackArch repo has most of these natively, so pacman_install is preferred
pacman_install \
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
    semgrep \
    apktool \
    jadx \
    beef-xss \
    ghidra \
    medusa \
    patator \
    subjack \
    eyewitness \
    nuclei

# AUR-only security tools
yay_install \
    scout-suite \
    aws-cli-v2

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
go_install github.com/tomnomnom/anew@latest
go_install github.com/tomnomnom/qsreplace@latest
go_install github.com/tomnomnom/unfurl@latest
go_install github.com/tomnomnom/meg@latest
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

if command -v rustup &>/dev/null && ! rustup show active-toolchain &>/dev/null; then
    log "Setting rustup default toolchain to stable..."
    rustup default stable || log "WARNING: rustup default stable failed"
fi

if getent group docker &>/dev/null; then
    sudo usermod -aG docker "$USER" 2>/dev/null || true
fi

sudo systemctl enable docker

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
    planify \
    peek \
    ttf-jetbrains-mono-nerd \
    drawio-desktop-bin \
    espanso

# -----------------------------
# PIP SECURITY TOOLS
# -----------------------------
log "Installing pip security tools..."
pip_install uro
pip_install corscanner
pip_install jwt_tool
pip_install s3scanner

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
    log "Bashrc already configured, skipping."
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
# -- wipe any BlackArch XFCE config and apply darbs dotfiles clean
# -----------------------------
log "Setting up XFCE config (replacing any BlackArch defaults)..."

XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
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
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    log "Everforest theme already installed, skipping."
else
    log "Installing Everforest GTK theme (replacing BlackArch theme)..."
    pacman_install sassc
    mkdir -p "$HOME/.themes"
    rm -rf /tmp/everforest
    git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
    /tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes" || log "WARNING: Everforest install.sh failed"
    rm -rf /tmp/everforest
fi

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
# FASTFETCH (darbs branding, no BlackArch)
# -----------------------------
log "Setting up fastfetch with darbs branding..."
mkdir -p "$HOME/.config/fastfetch"
cat > "$HOME/.config/fastfetch/config.jsonc" <<'FFEOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "source": "none"
    },
    "display": {
        "separator": "  ",
        "color": {
            "keys": "green",
            "title": "green"
        }
    },
    "modules": [
        {
            "type": "custom",
            "format": "[38;5;22m\n  ██████╗  █████╗ ██████╗ ██████╗ ███████╗\n  ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝\n  ██║  ██║███████║██████╔╝██████╔╝█████╗  \n  ██║  ██║██╔══██║██╔══██╗██╔══██╗██╔══╝  \n  ██████╔╝██║  ██║██║  ██║██████╔╝███████╗\n  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝\n[0m"
        },
        "break",
        "OS",
        "Kernel",
        "Uptime",
        "Packages",
        "Shell",
        "DE",
        "WM",
        "Terminal",
        "CPU",
        "GPU",
        "Memory",
        "break"
    ]
}
FFEOF

# -----------------------------
# WALLPAPERS
# -----------------------------
log "Setting up wallpapers directory..."
mkdir -p "$HOME/wallpapers"
if [ -d "$DOT_DIR/wallpapers" ]; then
    cp -r --no-clobber "$DOT_DIR/wallpapers/." "$HOME/wallpapers/"
    log "Wallpapers synced from dotfiles."
else
    log "No wallpapers folder in dotfiles."
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

sudo cp -f "$HOME/wallpapers/0327.jpg" /usr/share/backgrounds/xfce/xfce-x.svg 2>/dev/null || true

# nuke any BlackArch login screen background that might have survived
sudo cp -f "$HOME/wallpapers/0327.jpg" /usr/share/pixmaps/blackarch-greeter-bg.png 2>/dev/null || true

# -----------------------------
# LIGHTDM GREETER THEME
# -----------------------------
log "Configuring LightDM greeter with darbs/Everforest theme..."

sudo mkdir -p /usr/share/themes
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/
fi

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

# force lightdm to use the gtk greeter (not the blackarch one)
sudo mkdir -p /etc/lightdm
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
else
    sudo tee /etc/lightdm/lightdm.conf > /dev/null <<'LIGHTDMEOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
LIGHTDMEOF
fi

# -----------------------------
# GF PATTERNS
# -----------------------------
mkdir -p "$HOME/.gf"
if [ ! "$(ls -A "$HOME/.gf" 2>/dev/null)" ]; then
    git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null && \
        cp /tmp/gf-patterns/*.json "$HOME/.gf/" && \
        rm -rf /tmp/gf-patterns
fi

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

# remove any existing BlackArch Plymouth theme and set darbs as default
sudo rm -rf /usr/share/plymouth/themes/blackarch* 2>/dev/null || true

sudo mkdir -p /usr/share/plymouth/themes/darbs

# generate ASCII art logo PNG
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

sudo convert -size 400x8 xc:"#1a2a16" \
    /usr/share/plymouth/themes/darbs/bar-bg.png 2>/dev/null || true
sudo convert -size 2x8 xc:"#5a9e44" \
    /usr/share/plymouth/themes/darbs/bar-fill.png 2>/dev/null || true

sudo tee /usr/share/plymouth/themes/darbs/darbs.plymouth > /dev/null <<'EOF'
[Plymouth Theme]
Name=darbs
Description=DARBS - Everforest dark splash with LUKS prompt
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/darbs
ScriptFile=/usr/share/plymouth/themes/darbs/darbs.script
EOF

sudo tee /usr/share/plymouth/themes/darbs/darbs.script > /dev/null <<'PLYSCRIPT'
# darbs Plymouth theme -- colors match Everforest dark
Window.SetBackgroundTopColor(0.051, 0.071, 0.063);
Window.SetBackgroundBottomColor(0.031, 0.047, 0.039);

logo_img = Image("logo.png");
if (logo_img) {
    logo_sprite = Sprite(logo_img);
    logo_sprite.SetX(Window.GetWidth() / 2 - logo_img.GetWidth() / 2);
    logo_sprite.SetY(Window.GetHeight() / 2 - logo_img.GetHeight() / 2 - 70);
    logo_sprite.SetZ(1);
}

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

status_sprite = Sprite();
status_sprite.SetZ(4);

fun status_callback(text) {
    status_img = Image.Text(text, 0.514, 0.584, 0.455);
    status_sprite.SetImage(status_img);
    status_sprite.SetX(Window.GetWidth() / 2 - status_img.GetWidth() / 2);
    status_sprite.SetY(bar_y + 20);
}
Plymouth.SetUpdateStatusFunction(status_callback);

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

sudo plymouth-set-default-theme darbs 2>/dev/null || true

log "darbs Plymouth theme installed."
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
echo " 3. sudo mkinitcpio -P"
echo " 4. Add 'quiet splash' to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
echo "    then: sudo grub-mkconfig -o /boot/grub/grub.cfg"
echo " 5. Reboot."
echo "=========================================================="
echo ""
fi  # end plymouth skip block

# -----------------------------
# WHISKER MENU - SECURITY SHORTCUTS
# -----------------------------
mkdir -p "$HOME/.local/share/applications"
_sec_count=$(ls "$HOME/.local/share/applications/sec-"*.desktop 2>/dev/null | wc -l)
if [ "$_sec_count" -ge 75 ]; then
    log "Security shortcuts already created ($_sec_count found), skipping."
else
log "Creating security tool shortcuts for Whisker Menu..."

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

# Reconnaissance
sec_desktop "Amass"          "amass -h"                         "Subdomain enumeration"              "Reconnaissance"
sec_desktop "Subfinder"      "subfinder -h"                     "Passive subdomain discovery"         "Reconnaissance"
sec_desktop "Assetfinder"    "assetfinder -h"                   "Find domains and subdomains"         "Reconnaissance"
sec_desktop "TheHarvester"   "theHarvester -h"                  "Email, subdomain, IP harvester"      "Reconnaissance"
sec_desktop "Recon-ng"       "recon-ng"                         "Web reconnaissance framework"        "Reconnaissance"
sec_desktop "Sherlock"       "sherlock -h"                      "Username hunt across social media"   "Reconnaissance"
sec_desktop "Sublist3r"      "sublist3r -h"                     "Sublist3r subdomain scanner"         "Reconnaissance"
sec_desktop "Shodan CLI"     "shodan -h"                        "Shodan command-line client"          "Reconnaissance"
sec_desktop "DNSEnum"        "dnsenum -h"                       "DNS enumeration"                     "Reconnaissance"
sec_desktop "MassDNS"        "massdns -h"                       "High-performance DNS resolver"       "Reconnaissance"
sec_desktop "DNSX"           "dnsx -h"                          "Fast DNS toolkit"                    "Reconnaissance"
sec_desktop "Waybackurls"    "waybackurls -h"                   "Fetch URLs from Wayback Machine"     "Reconnaissance"
sec_desktop "GAU"            "gau -h"                           "Get all URLs (AlienVault + Wayback)" "Reconnaissance"
sec_desktop "Httprobe"       "httprobe -h"                      "Probe for live HTTP/S hosts"         "Reconnaissance"
sec_desktop "Gowitness"      "gowitness -h"                     "Web screenshot utility"              "Reconnaissance"
sec_desktop "Chaos"          "chaos -h"                         "ProjectDiscovery chaos client"       "Reconnaissance"
sec_desktop "Shuffledns"     "shuffledns -h"                    "Mass DNS resolver using massdns"     "Reconnaissance"

# Scanning
sec_desktop "Nmap"           "nmap --help 2>&1 | head -60"      "Network port scanner"                "Scanner"
sec_desktop "Masscan"        "masscan --help 2>&1 | head -40"   "Mass IP port scanner"                "Scanner"
sec_desktop "Naabu"          "naabu -h"                         "Fast port scanner"                   "Scanner"
sec_desktop "Smap"           "smap -h"                          "Shodan-powered port scanner"         "Scanner"
sec_desktop "Whatweb"        "whatweb -h"                       "Web technology fingerprinter"        "Scanner"
sec_desktop "Nuclei"         "nuclei -h"                        "Template-based vulnerability scanner" "Scanner"
sec_desktop "Nikto"          "nikto -h"                         "Web server vulnerability scanner"    "Scanner"

# Web Application
sec_desktop "Gobuster"       "gobuster -h"                      "Directory/DNS brute-forcer"          "WebApp"
sec_desktop "FFuf"           "ffuf -h"                          "Web fuzzer"                          "WebApp"
sec_desktop "Feroxbuster"    "feroxbuster -h"                   "Recursive content discovery"         "WebApp"
sec_desktop "Wfuzz"          "wfuzz -h"                         "Web application fuzzer"              "WebApp"
sec_desktop "Dirsearch"      "dirsearch -h"                     "Web path scanner"                    "WebApp"
sec_desktop "SQLMap"         "sqlmap -h"                        "SQL injection tool"                  "WebApp"
sec_desktop "WPScan"         "wpscan -h"                        "WordPress vulnerability scanner"     "WebApp"
sec_desktop "Commix"         "commix -h"                        "Command injection exploiter"         "WebApp"
sec_desktop "Arjun"          "arjun -h"                         "HTTP parameter discovery"            "WebApp"
sec_desktop "Dalfox"         "dalfox -h"                        "XSS scanning and parameter analysis" "WebApp"
sec_desktop "Katana"         "katana -h"                        "Next-gen web crawler"                "WebApp"
sec_desktop "Hakrawler"      "hakrawler -h"                     "Simple web crawler"                  "WebApp"
sec_desktop "HTTPX"          "httpx -h"                         "HTTP toolkit"                        "WebApp"
sec_desktop "GF"             "gf -h"                            "Grep with predefined patterns"       "WebApp"
sec_desktop "Mitmproxy"      "mitmproxy -h"                     "Interactive HTTPS proxy"             "WebApp"
sec_desktop "Mitmweb"        "mitmweb"                          "Mitmproxy web interface"             "WebApp"
sec_desktop "Anew"           "anew -h"                          "Append new unique lines to file"     "WebApp"
sec_desktop "Qsreplace"      "qsreplace -h"                     "Replace query string values"         "WebApp"
sec_desktop "Unfurl"         "unfurl -h"                        "Extract URL components"              "WebApp"
sec_desktop "Meg"            "meg -h"                           "Fetch many paths for many hosts"     "WebApp"
sec_desktop "URO"            "uro -h"                           "Deduplicate and clean URL lists"     "WebApp"
sec_desktop "CRLFuzz"        "crlfuzz -h"                       "CRLF injection scanner"              "WebApp"
sec_desktop "NoMore403"      "nomore403 -h"                     "403 Forbidden bypass tool"           "WebApp"
sec_desktop "CORScanner"     "corscanner -h"                    "CORS misconfiguration scanner"       "WebApp"
sec_desktop "JWT Tool"       "jwt_tool -h"                      "JWT security testing toolkit"        "WebApp"

# Password
sec_desktop "Hydra"          "hydra -h 2>&1 | head -40"         "Network login brute-forcer"          "Password"
sec_desktop "John"           "john --help 2>&1 | head -40"      "John the Ripper password cracker"    "Password"
sec_desktop "Hashcat"        "hashcat -h 2>&1 | head -40"       "GPU password cracker"                "Password"
sec_desktop "Medusa"         "medusa -h 2>&1 | head -40"        "Parallel login brute-forcer"         "Password"
sec_desktop "Patator"        "patator -h"                       "Multi-purpose brute-forcer"          "Password"
sec_desktop "CeWL"           "cewl -h"                          "Custom wordlist generator"           "Password"

# Wireless
sec_desktop "Aircrack-ng"    "aircrack-ng --help"               "WiFi security auditing suite"        "Wireless"
sec_desktop "Airodump-ng"    "airodump-ng --help"               "WiFi packet capture"                 "Wireless"
sec_desktop "Aireplay-ng"    "aireplay-ng --help"               "WiFi injection and replay"           "Wireless"
sec_desktop "Wifite"         "wifite -h"                        "Automated wireless auditor"          "Wireless"
sec_desktop "Reaver"         "reaver -h"                        "WPS brute-force attack"              "Wireless"
sec_desktop "Kismet"         "kismet --help"                    "Wireless network detector/sniffer"   "Wireless"
sec_desktop "Bettercap"      "bettercap -h"                     "Network attacks and monitoring"      "Wireless"
sec_desktop "Macchanger"     "macchanger -h"                    "MAC address changer"                 "Wireless"

# Exploitation
sec_desktop "Metasploit"     "msfconsole"                       "Penetration testing framework"       "Exploitation"
sec_desktop "CrackMapExec"   "crackmapexec -h"                  "SMB/AD exploitation"                 "Exploitation"
sec_desktop "Impacket"       "echo 'psexec.py secretsdump.py wmiexec.py smbclient.py'; ls /usr/lib/python3*/dist-packages/impacket/examples/*.py 2>/dev/null | xargs -I{} basename {} .py | sort" \
                                                                 "Impacket Windows protocol tools"     "Exploitation"
sec_desktop "Responder"      "responder -h"                     "LLMNR/NBT-NS poisoner"               "Exploitation"
sec_desktop "Enum4linux-ng"  "enum4linux-ng -h"                 "SMB/NetBIOS enumeration"             "Exploitation"
sec_desktop "Bloodhound"     "bloodhound-python -h"             "AD attack path mapper (collector)"   "Exploitation"
sec_desktop "Searchsploit"   "searchsploit -h"                  "Exploit-DB offline search"           "Exploitation"
sec_desktop "Interactsh"     "interactsh-client -h"             "OOB interaction server client"       "Exploitation"
sec_desktop "BeEF"           "beef"                             "Browser exploitation framework"      "Exploitation"

# Forensics
sec_desktop "Binwalk"        "binwalk -h"                       "Firmware analysis and extraction"    "Forensics"
sec_desktop "Foremost"       "foremost -h"                      "File recovery by header/footer"      "Forensics"
sec_desktop "Volatility3"    "vol -h"                           "Memory forensics framework"          "Forensics"
sec_desktop "Ghidra"         "ghidra"                           "NSA reverse engineering suite"       "Forensics"
sec_desktop "Strings"        "strings --help"                   "Extract printable strings"           "Forensics"
sec_desktop "Autopsy"        "autopsy"                          "Digital forensics platform"          "Forensics"

# MITM / Capture
sec_desktop "Ettercap"       "ettercap -h"                      "MITM attack suite"                   "MITM"
sec_desktop "TCPDump"        "tcpdump -h 2>&1 | head -40"       "Packet capture"                      "MITM"
sec_desktop "Socat"          "socat -h 2>&1 | head -40"         "Multipurpose relay"                  "MITM"
sec_desktop "Proxychains"    "proxychains -h 2>&1 | head -30"   "Route tools through proxy chain"     "MITM"

# Secrets & OSINT
sec_desktop "TruffleHog"     "trufflehog -h"                    "Credential scanner in git repos"     "Secrets"
sec_desktop "Gitleaks"       "gitleaks -h"                      "Detect secrets in git history"       "Secrets"
sec_desktop "Subjack"        "subjack -h"                       "Subdomain takeover detection"        "Secrets"
sec_desktop "Semgrep"        "semgrep --help"                   "SAST scanner for code review"        "Secrets"

# Cloud
sec_desktop "AWS CLI"        "aws --version && aws help"        "Amazon Web Services CLI"             "Cloud"
sec_desktop "S3Scanner"      "s3scanner -h"                     "Open S3 bucket scanner"              "Cloud"

# Mobile
sec_desktop "Apktool"        "apktool -h"                       "APK decompilation and rebuilding"    "Mobile"
sec_desktop "JADX"           "jadx --help"                      "Java decompiler for Android APKs"    "Mobile"
sec_desktop "ADB"            "adb --version && adb help"        "Android Debug Bridge"                "Mobile"

if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

log "Security shortcuts created in ~/.local/share/applications"
log "They will appear under 'Security' in Whisker Menu."
fi  # end security shortcuts skip block

# -----------------------------
# FINISH
# -----------------------------
log "DARBS BlackArch installation complete!"

echo -e "${BLUE}"
echo "=========================================="
echo " DONE! Reboot into XFCE."
echo " BlackArch branding stripped."
echo " darbs Everforest theme applied."
echo "=========================================="
echo -e "${RESET}"
