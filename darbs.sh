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
    texlive \
    texmaker \
    calcurse \
    picom \
    papirus-icon-theme \
    rofi \
    plank \
    conky \
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
    chromium 

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
 everforest-gtk-theme-git



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
# THEMING / RICING
# -----------------------------
log "Setting up theme, icons, and compositor..."

# Set Everforest GTK theme and Papirus icons
xfconf-query -c xsettings -p /Net/ThemeName -s "Everforest-Dark-BL" --create -t string
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" --create -t string
xfconf-query -c xfwm4 -p /general/theme -s "Everforest-Dark-BL" --create -t string

# Panel: move to top, set semi-transparent
xfconf-query -c xfce4-panel -p /panels/panel-1/position -s "p=6;x=0;y=0" --create -t string
xfconf-query -c xfce4-panel -p /panels/panel-1/background-alpha -s 85 --create -t int

# Picom config for transparency, shadows, rounded corners
mkdir -p "$HOME/.config/picom"
cat > "$HOME/.config/picom/picom.conf" <<'PICOM'
backend = "glx";
vsync = true;

# Shadows
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'xfce4-panel'"
];

# Transparency
inactive-opacity = 0.9;
active-opacity = 1.0;
frame-opacity = 0.9;
inactive-opacity-override = false;
focus-exclude = [
    "class_g = 'firefox'",
    "class_g = 'Chromium'"
];

# Rounded corners
corner-radius = 8;
rounded-corners-exclude = [
    "class_g = 'xfce4-panel'",
    "window_type = 'dock'"
];

# Fading
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
PICOM

# Autostart picom and plank
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/picom.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Picom
Exec=picom --config ~/.config/picom/picom.conf -b
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESK

cat > "$HOME/.config/autostart/plank.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESK

# Rofi config with moss theme
mkdir -p "$HOME/.config/rofi"
cat > "$HOME/.config/rofi/config.rasi" <<'ROFI'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    display-drun: "Apps";
    display-run: "Run";
    display-window: "Windows";
}

* {
    bg:       #1a2a1a;
    bg-alt:   #2e4a2e;
    fg:       #c8e6a0;
    fg-alt:   #8aaa70;
    accent:   #5a8c50;
    urgent:   #e06060;

    background-color: @bg;
    text-color:       @fg;
}

window {
    width:            40%;
    border:           2px;
    border-color:     @accent;
    border-radius:    8px;
    padding:          20px;
}

inputbar {
    children:         [ prompt, entry ];
    spacing:          10px;
    padding:          10px;
    background-color: @bg-alt;
    border-radius:    6px;
}

prompt {
    text-color:       @accent;
    background-color: @bg-alt;
}

entry {
    placeholder:      "Search...";
    background-color: @bg-alt;
}

listview {
    lines:            8;
    spacing:          5px;
    padding:          10px 0 0 0;
}

element {
    padding:          8px;
    border-radius:    4px;
}

element selected {
    background-color: @accent;
    text-color:       #0f1a0f;
}

element-text {
    text-color:       inherit;
}

element-icon {
    size:             24px;
}
ROFI

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
