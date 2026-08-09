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

# Robust: try the batch, and on failure (usually one package absent on this
# Debian release) retry each individually so the run never aborts. Misses are
# logged to ~/darbs-failed.log.
FAILLOG="${FAILLOG:-$HOME/darbs-failed.log}"
apt_install() {
    local to_install=()
    for pkg in "$@"; do
        if dpkg -s "$pkg" &>/dev/null; then
            log "Skipping $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    [ ${#to_install[@]} -eq 0 ] && return 0
    if sudo apt-get install -y "${to_install[@]}" 2>/dev/null; then
        return 0
    fi
    log "batch apt install failed, retrying one by one..."
    for pkg in "${to_install[@]}"; do
        if ! sudo apt-get install -y "$pkg" 2>/dev/null; then
            echo "apt: $pkg" >> "$FAILLOG"
            log "WARNING: could not install $pkg (logged to $FAILLOG)"
        fi
    done
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

# -----------------------------
# CONKY (desktop system monitor, laptop-tuned)
# -----------------------------
log "Setting up conky desktop monitor..."
mkdir -p "$HOME/.config/conky"
cat > "$HOME/.config/conky/conky.conf" <<'CONKYEOF'
conky.config = {
    -- display
    alignment = 'top_right',
    gap_x = 20,
    gap_y = 40,

    -- window
    own_window = true,
    own_window_type = 'desktop',
    own_window_transparent = false,
    own_window_argb_visual = true,
    own_window_argb_value = 120,
    own_window_colour = '000000',
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',

    -- appearance
    background = false,
    double_buffer = true,
    draw_shades = false,
    draw_outline = false,
    draw_borders = false,

    -- fonts
    use_xft = true,
    font = 'JetBrains Mono:size=12',
    xftalpha = 0.9,

    -- colors
    default_color = 'white',
    color1 = '88ccff',  -- label color (light blue)
    color2 = 'ffaa44',  -- warning color (orange)

    -- update
    update_interval = 2,
    cpu_avg_samples = 2,
    net_avg_samples = 2,

    -- misc
    no_buffers = true,
    uppercase = false,
    use_spacer = 'none',
    show_graph_scale = false,
    out_to_console = false,
    out_to_stderr = false,
};

conky.text = [[
${color1}${time %A, %B %e}${alignr}${color}${time %I:%M %p}
${color1}uptime:${color} ${uptime}
${hr 1}
${color1}CPU  ${color}${execi 3600 sed -n 's/^model name.*: //p' /proc/cpuinfo | head -1 | cut -c1-30}
usage:  ${cpu cpu0}%${alignr}temp: ${execi 5 sensors 2>/dev/null | grep -im1 -E 'Package id 0:|Tctl:|Tdie:' | grep -oE '[+][0-9]+' | head -1 | tr -d '+' | awk '{if($1!="")printf "%.0fF",$1*9/5+32}'}
${cpubar cpu0 8,260}
cores:  ${execi 3600 nproc}${alignr}load: ${loadavg 1}
${hr 1}
${color1}MEMORY
ram:    ${mem} / ${memmax}${alignr}${memperc}%
${membar 8,260}
swap:   ${swap} / ${swapmax}${alignr}${swapperc}%
${swapbar 8,260}
${hr 1}
${color1}BATTERY  ${color}${battery_short __BAT__}${alignr}${battery_time __BAT__}
${battery_bar 8,260 __BAT__}
${hr 1}
${color1}STORAGE
disk:   ${fs_used /} / ${fs_size /}${alignr}${fs_used_perc /}%
${fs_bar 8,260 /}
${hr 1}
${color1}NETWORK  ${color}__IFACE__${alignr}${wireless_essid __IFACE__}
up:     ${upspeed __IFACE__}${alignr}down: ${downspeed __IFACE__}
signal: ${wireless_link_qual_perc __IFACE__}%
${hr 1}
${color1}TOP PROCESSES
${color1}name              cpu%   ram%
${color}${top name 1} ${top cpu 1}   ${top mem 1}
${top name 2} ${top cpu 2}   ${top mem 2}
${top name 3} ${top cpu 3}   ${top mem 3}
${top name 4} ${top cpu 4}   ${top mem 4}
${top name 5} ${top cpu 5}   ${top mem 5}
]];
CONKYEOF

# fill in the laptop's WiFi/primary interface and battery name
IFACE="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
[ -z "$IFACE" ] && IFACE="$(ls /sys/class/net 2>/dev/null | grep -m1 -E '^wl')"
[ -z "$IFACE" ] && IFACE="$(ls /sys/class/net 2>/dev/null | grep -m1 -E '^en|^eth')"
[ -z "$IFACE" ] && IFACE="wlan0"
BAT="$(ls /sys/class/power_supply 2>/dev/null | grep -m1 -E '^BAT')"
[ -z "$BAT" ] && BAT="BAT0"
sed -i "s|__IFACE__|$IFACE|g; s|__BAT__|$BAT|g" "$HOME/.config/conky/conky.conf"
log "conky configured (interface: $IFACE, battery: $BAT)"

# autostart conky under XFCE (pause lets the desktop settle first)
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/conky.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Conky
Comment=Desktop system monitor (darbs)
Exec=conky --daemonize --pause=3 --config=$HOME/.config/conky/conky.conf
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

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
