#!/bin/bash

################################################################################
#                                                                              #
#  DARBS - Drew's Auto Rice Bootstrap Script                                   #
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

echo "=== DARBS (Drew's Auto Rice Bootstrap Script) ==="

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
    libreoffice-still 


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
    python-pip \
    burpsuite \
    sqlmap \
    nikto \
    gobuster \
    arachni \
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
    netcat \
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
    dnsutils \
    inetutils \
    net-tools \
    btop

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
 hydra \
 medusa \
 patator \
 subjack \
 eyewitness \
 scout-suite \
 pacu 



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
if [ -f "$DOT_DIR/.tmux.conf" ]; then
    log "Setting up tmux config..."
    cp "$DOT_DIR/.tmux.conf" "$HOME/.tmux.conf"
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
# FINISH
# -----------------------------
log "DARBS installation complete!"

echo -e "${BLUE}"
echo "====================================="
echo " DONE! Reboot into XFCE."
echo "====================================="
echo -e "${RESET}"
