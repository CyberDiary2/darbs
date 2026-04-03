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

####################################################################
#
echo -e "\e[38;5;22m
██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║███████║██████╔╝██████╔╝███████╗
██║  ██║██╔══██║██╔══██╗██╔══██╗╚════██║
██████╔╝██║  ██║██║  ██║██████╔╝███████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝
\e[0m"
####################################################################






set -e

LOGFILE="$HOME/darbs.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== DARBS (Drew's Auto-Rice Bug Bounty Bootstrapping Script) ==="

# -----------------------------
# CONFIG (EDIT THIS)
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

# -----------------------------
# SYSTEM UPDATE
# -----------------------------
log "Updating system..."
sudo pacman -Syu --noconfirm

# -----------------------------
# BASE SYSTEM + XFCE
# -----------------------------
log "Installing XFCE and core packages..."
sudo pacman -S --noconfirm \
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
    caligula \
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


# -----------------------------
# ENABLE SERVICES
# -----------------------------
log "Enabling services..."
sudo systemctl enable NetworkManager
sudo systemctl enable lightdm

# -----------------------------
# ADD BLACKARCH REPO
# -----------------------------
log "Adding BlackArch repository..."
if ! grep -q "blackarch" /etc/pacman.conf; then
    curl -O https://blackarch.org/strap.sh
    chmod +x strap.sh
    sudo ./strap.sh
    rm strap.sh
fi

# -----------------------------
# BUG BOUNTY + SECURITY TOOLS
# -----------------------------
log "Installing bug bounty and security tools..."
sudo pacman -S --noconfirm \
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
sudo pacman -S --noconfirm go

# -----------------------------
# TOMNOMNOM TOOLS (Go)
# -----------------------------
log "Installing Tomnomnom Go tools..."
export PATH=$PATH:/usr/lib/go/bin
export GOPATH="$HOME/go"

go install github.com/tomnomnom/waybackurls@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/tomnomnom/gf@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/hahwul/dalfox/v2@latest
go install github.com/s0md3v/smap/cmd/smap@latest
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install github.com/sensepost/gowitness@latest
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest


# -----------------------------
# PYTHON SECURITY TOOLS
# -----------------------------
#log "Installing Python security tools..."

#pip install --user xsstrike
#done

# -----------------------------
# NAHAMSEC TOOLS
# -----------------------------
#log "Installing NahamSec tools..."
#git clone https://github.com/nahamsec/lazys3.git "$HOME/tools/lazys3" 2>/dev/null || true

# -----------------------------
# EXTRA UTILITIES
# -----------------------------
log "Installing extra utilities..."
sudo pacman -S --noconfirm \
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
log "Installing AUR packages: VSCodium..."
#paru -S --noconfirm vscodium-bin
yay -S --noconfirm \
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
# Append Go path so tomnomnom tools are available in shell
echo 'export PATH=$PATH:/usr/lib/go/bin:$HOME/go/bin' >> "$HOME/.bashrc"

#-----------------------------
# NANORC
#-----------------------------
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

# Wipe any existing XFCE config to start completely clean
rm -rf "$HOME/.config/xfce4"
mkdir -p "$XFCONF_DIR"

# Copy all XML config files directly from dotfiles repo
if [ -d "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml" ]; then
    cp "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml/"*.xml "$XFCONF_DIR/"
    log "XFCE XML configs copied."
else
    log "WARNING: xfce4/xfconf/xfce-perchannel-xml not found in dotfiles repo!"
fi

# Fix hardcoded /home/drew paths to match the current user's home directory
sed -i "s|/home/drew|$HOME|g" "$XFCONF_DIR/xfce4-desktop.xml"

# Set xfce4-terminal as default terminal
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

# GTK theme configs
mkdir -p "$HOME/.config/gtk-3.0"
if [ -f "$DOT_DIR/gtk-3.0/settings.ini" ]; then
    cp "$DOT_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
fi
if [ -f "$DOT_DIR/gtk-2.0/gtkrc-2.0" ]; then
    cp "$DOT_DIR/gtk-2.0/gtkrc-2.0" "$HOME/.gtkrc-2.0"
fi

# Picom
mkdir -p "$HOME/.config/picom"
if [ -f "$DOT_DIR/picom/picom.conf" ]; then
    cp "$DOT_DIR/picom/picom.conf" "$HOME/.config/picom/picom.conf"
fi

# Rofi
mkdir -p "$HOME/.config/rofi"
if [ -f "$DOT_DIR/rofi/config.rasi" ]; then
    cp "$DOT_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
fi

# Autostart entries (picom, plank)
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
    log "No wallpapers folder found in dotfiles — add images to ~/wallpapers/ manually."
fi

#Set wallpaper 

# xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s /home/wallpers/0327.jpg && xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-style -s 5

#!/bin/bash

WALL="$HOME/wallpapers/0327.jpg"

# Set wallpaper for all monitors/workspaces
xfconf-query -c xfce4-desktop -l | grep last-image | while read -r path; do
  xfconf-query -c xfce4-desktop -p "$path" -s "$WALL"
done

# Set style to stretched
xfconf-query -c xfce4-desktop -l | grep image-style | while read -r path; do
  xfconf-query -c xfce4-desktop -p "$path" -s 3
done

sudo cp -f ~/wallpapers/0327.jpg /usr/share/backgrounds/xfce/xfce-x.svg

# -----------------------------
# LIGHTDM GREETER THEME
# -----------------------------
log "Configuring LightDM greeter to match Everforest theme..."
if [ -f "$DOT_DIR/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$DOT_DIR/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
    # Copy Everforest theme to system-wide location so greeter (running as root) can access it
    sudo mkdir -p /usr/share/themes
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/ 2>/dev/null || true
fi

GO_BIN="$HOME/.local/bin"

mkdir -p "$GO_BIN"

#------------------------------
# MORE GO 
#------------------------------

export PATH=$HOME/go/bin:$HOME/.local/bin:$PATH && GO111MODULE=on go install github.com/projectdiscovery/httpx/cmd/httpx@latest github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest github.com/tomnomnom/assetfinder@latest && pip install --user gf-patterns && echo 'export PATH=$HOME/go/bin:$HOME/.local/bin:$PATH' >> ~/.bashrc

# -----------------------------
# FINISH
# -----------------------------
log "DARBS installation complete!"

echo -e "${BLUE}"
echo "====================================="
echo " DONE! Reboot into XFCE."
echo "====================================="
echo -e "${RESET}"
