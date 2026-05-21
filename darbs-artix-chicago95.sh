#!/bin/bash
# darbs-artix-chicago95.sh -- fully chicago95-ify an artix xfce laptop
# installs chicago95 theme, icons, cursors, sounds, grub theme, lightdm login,
# wine, and winetricks. works on openrc, runit, s6, and dinit.
# run as your regular user (not root). script will sudo when needed.
# usage: bash darbs-artix-chicago95.sh

GRN='\033[0;32m'; YLW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "\n${GRN}==>${NC} $1"; }
ok()   { echo -e "  ${GRN}[OK]${NC}   $1"; }
skip() { echo -e "  ${YLW}[SKIP]${NC} $1 -- $2"; }
warn() { echo -e "  ${YLW}[!]${NC}   $1"; }
die()  { echo -e "${RED}[x]${NC} $1"; exit 1; }

[ "$EUID" -eq 0 ] && die "run as your regular user, not root."
command -v pacman &>/dev/null || die "pacman not found -- this script is for artix linux only."

LOGFILE="$HOME/darbs-chicago95.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${GRN}"
echo "  ██████╗██╗  ██╗██╗ ██████╗ █████╗  ██████╗  ██████╗  █████╗  ███████╗"
echo "  ██╔════╝██║  ██║██║██╔════╝██╔══██╗██╔════╝ ██╔═══██╗██╔══██╗ ██╔════╝"
echo "  ██║     ███████║██║██║     ███████║██║  ███╗██║   ██║╚██████╔╝ ███████╗"
echo "  ██║     ██╔══██║██║██║     ██╔══██║██║   ██║██║   ██║ ╚═══██╗  ╚════██║"
echo "  ╚██████╗██║  ██║██║╚██████╗██║  ██║╚██████╔╝╚██████╔╝ █████╔╝  ███████║"
echo "   ╚═════╝╚═╝  ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝  ╚════╝   ╚══════╝"
echo -e "${NC}"
echo "  darbs artix chicago95 -- full win95 theme for artix xfce"
echo ""

# ── detect init system ─────────────────────────────────────────────────────────
INIT_SYS=""
if   command -v openrc  &>/dev/null || [ -d /run/openrc ];  then INIT_SYS="openrc"
elif command -v runit   &>/dev/null || [ -d /run/runit ];   then INIT_SYS="runit"
elif command -v s6-rc   &>/dev/null || [ -d /run/s6 ];      then INIT_SYS="s6"
elif command -v dinitctl &>/dev/null;                        then INIT_SYS="dinit"
else
    case "$(cat /proc/1/comm 2>/dev/null)" in
        openrc-init) INIT_SYS="openrc" ;;
        runit)       INIT_SYS="runit"  ;;
        s6-svscan)   INIT_SYS="s6"     ;;
        dinit)       INIT_SYS="dinit"  ;;
        *)           INIT_SYS="openrc" ; warn "could not detect init system, defaulting to openrc" ;;
    esac
fi
ok "init system: $INIT_SYS"

svc_enable() {
    case "$INIT_SYS" in
        openrc) sudo rc-update add "$1" default 2>/dev/null || true ;;
        runit)  [ -d "/etc/runit/sv/$1" ] && sudo ln -sf "/etc/runit/sv/$1" /run/runit/service/ 2>/dev/null || true ;;
        s6)     sudo s6-rc -u change "$1" 2>/dev/null || true ;;
        dinit)  sudo dinitctl enable "$1" 2>/dev/null || true ;;
    esac
}
svc_start() {
    case "$INIT_SYS" in
        openrc) sudo rc-service "$1" start 2>/dev/null || true ;;
        runit)  sudo sv start "$1" 2>/dev/null || true ;;
        s6)     sudo s6-rc -u change "$1" 2>/dev/null || true ;;
        dinit)  sudo dinitctl start "$1" 2>/dev/null || true ;;
    esac
}

pkg() {
    pacman -Qi "$1" &>/dev/null && ok "$1 already installed" && return
    sudo pacman -S --noconfirm "$1" 2>/dev/null && ok "$1" || warn "$1 failed -- skipping"
}
aur() {
    pacman -Qi "$1" &>/dev/null && ok "$1 already installed" && return
    yay -S --noconfirm "$1" 2>/dev/null && ok "$1" || warn "$1 failed (aur) -- skipping"
}

# ── 1. KEYRING + PACMAN SETUP ──────────────────────────────────────────────────
info "initializing pacman keyring..."

# sanity check: clock must be roughly correct or keyring will refuse to work
NOW_YEAR="$(date +%Y)"
if [ "$NOW_YEAR" -lt 2024 ] || [ "$NOW_YEAR" -gt 2100 ]; then
    die "system clock looks wrong ($(date)) -- fix with: sudo date -s \"\$(curl -sI https://google.com | grep -i '^date:' | cut -d' ' -f2-)\""
fi

# ensure mirrorlist exists -- write fallback mirrors if missing
sudo mkdir -p /etc/pacman.d
if [ ! -f /etc/pacman.d/mirrorlist ] || [ ! -s /etc/pacman.d/mirrorlist ]; then
    warn "artix mirrorlist missing -- writing fallback mirrors..."
    sudo tee /etc/pacman.d/mirrorlist > /dev/null << 'EOF'
Server = https://mirrors.dotsrc.org/artix-linux/repos/$repo/os/$arch
Server = https://mirror1.artixlinux.org/$repo/os/$arch
Server = https://mirror.pascalpuffke.de/artix-linux/$repo/os/$arch
Server = https://artix.nze.cz/$repo/os/$arch
Server = https://artixlinux.mirror.liquidtelecom.com/$repo/os/$arch
EOF
    ok "artix mirrorlist written"
fi

if [ ! -f /etc/pacman.d/mirrorlist-arch ] || [ ! -s /etc/pacman.d/mirrorlist-arch ]; then
    warn "arch mirrorlist missing -- writing fallback mirrors..."
    sudo tee /etc/pacman.d/mirrorlist-arch > /dev/null << 'EOF'
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.leaseweb.net/archlinux/$repo/os/$arch
EOF
    ok "arch mirrorlist written"
fi

_keyring_ok() {
    sudo pacman-key --list-keys 2>/dev/null | grep -q '.' || return 1
    sudo pacman -Si artix-keyring &>/dev/null || return 1
    return 0
}

if _keyring_ok; then
    ok "keyring already healthy"
    sudo pacman -Syy --noconfirm || die "pacman -Syy failed -- check mirrors/network"
else
    warn "keyring missing or broken -- reinitializing..."
    sudo killall gpg-agent dirmngr gpg 2>/dev/null || true
    sleep 1
    sudo rm -rf /etc/pacman.d/gnupg

    # haveged speeds up entropy for keyring init on laptops
    if ! pacman -Qi haveged &>/dev/null; then
        sudo pacman -S --noconfirm haveged 2>/dev/null || true
    fi
    sudo haveged -w 1024 2>/dev/null &
    HAVEGED_PID=$!

    sudo pacman-key --init      || die "pacman-key --init failed"
    sudo pacman-key --populate artix
    ls /usr/share/pacman/keyrings/archlinux*.gpg &>/dev/null && \
        sudo pacman-key --populate archlinux 2>/dev/null || true

    sudo pacman -Syy --noconfirm || die "pacman -Syy failed after keyring reinit"
    kill "$HAVEGED_PID" 2>/dev/null || true
    ok "keyring reinitialized"
fi

# fix broken pacman.conf from failed previous runs
if grep -q 'mirrorlist-arch' /etc/pacman.conf 2>/dev/null && \
   [ ! -f /etc/pacman.d/mirrorlist-arch ]; then
    warn "fixing broken arch repo entries in pacman.conf..."
    sudo sed -i '/^\[extra\]/,/^$/d' /etc/pacman.conf
    sudo sed -i '/^\[multilib\]/,/^$/d' /etc/pacman.conf
    sudo sed -i '/mirrorlist-arch/d' /etc/pacman.conf
fi

# ── 2. PREREQUISITES ───────────────────────────────────────────────────────────
info "installing prerequisites..."

pkg git
pkg curl
pkg wget
pkg unzip
pkg base-devel
pkg imagemagick

# enable multilib (needed for wine 32-bit)
# must install artix-archlinux-support FIRST so mirrorlist-arch exists
# before pacman.conf references it, otherwise pacman fails to parse the file
if ! grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
    info "enabling multilib repo..."
    if [ ! -f /etc/pacman.d/mirrorlist-arch ]; then
        sudo pacman -S --noconfirm artix-archlinux-support || \
            die "artix-archlinux-support failed -- cannot enable multilib"
        sudo pacman-key --populate archlinux 2>/dev/null || true
    fi
    sudo tee -a /etc/pacman.conf > /dev/null << 'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    sudo pacman -Sy --noconfirm
    ok "multilib enabled"
else
    ok "multilib already enabled"
fi

# install yay if missing
if ! command -v yay &>/dev/null; then
    info "installing yay (aur helper)..."
    rm -rf /tmp/yay-build
    git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    (cd /tmp/yay-build && makepkg -si --noconfirm)
    rm -rf /tmp/yay-build
    ok "yay installed"
else
    ok "yay already installed"
fi

# xfce prereqs -- install init-specific lightdm package so the service exists
pkg lightdm
pkg lightdm-gtk-greeter
pkg xfconf
# artix needs the init-specific service package or lightdm won't start after boot
sudo pacman -S --noconfirm "lightdm-${INIT_SYS}" 2>/dev/null && \
    ok "lightdm-${INIT_SYS} installed" || \
    warn "lightdm-${INIT_SYS} not found -- lightdm may not start at boot"

# ── 2. CHICAGO95 INSTALL ───────────────────────────────────────────────────────
info "installing chicago95..."

# always clone the repo -- used for grub theme, sounds, and as fallback if AUR fails
C95_TMP="/tmp/chicago95-src"
rm -rf "$C95_TMP"
if git clone --depth=1 https://github.com/grassmunk/Chicago95 "$C95_TMP" 2>/dev/null; then
    ok "chicago95 repo cloned"
else
    die "could not clone chicago95 repo -- check internet connection"
fi

# try AUR first, fall back to manual install from the cloned repo
if pacman -Qi chicago95-theme-git &>/dev/null; then
    ok "chicago95-theme-git already installed"
elif yay -S --noconfirm chicago95-theme-git 2>/dev/null; then
    ok "chicago95-theme-git installed via aur"
else
    warn "aur install failed -- installing chicago95 manually from repo clone..."

    # gtk themes
    sudo mkdir -p /usr/share/themes
    for d in "$C95_TMP/Theme"/Chicago95*; do
        [ -d "$d" ] && sudo cp -r "$d" /usr/share/themes/ && ok "theme: $(basename "$d")"
    done

    # icons and cursors
    sudo mkdir -p /usr/share/icons
    for d in "$C95_TMP/icons"/Chicago95*; do
        [ -d "$d" ] && sudo cp -r "$d" /usr/share/icons/ && ok "icons: $(basename "$d")"
    done

    # fonts
    sudo mkdir -p /usr/share/fonts/chicago95
    find "$C95_TMP/fonts" \( -name "*.ttf" -o -name "*.otf" -o -name "*.pcf*" \) \
        -exec sudo cp {} /usr/share/fonts/chicago95/ \; 2>/dev/null || true
    sudo fc-cache -f 2>/dev/null

    # sounds
    sudo mkdir -p /usr/share/sounds/Chicago95/stereo
    find "$C95_TMP" -maxdepth 3 \( -name "*.ogg" -o -name "*.wav" \) \
        -exec sudo cp {} /usr/share/sounds/Chicago95/stereo/ \; 2>/dev/null || true

    ok "chicago95 installed manually from github"
fi

# ── 3. GTK THEME + ICONS ───────────────────────────────────────────────────────
info "applying chicago95 gtk theme and icons..."

# copy to user dirs as well so xfce picks them up without a relogin
mkdir -p "$HOME/.themes" "$HOME/.icons"
for d in "$C95_TMP/Theme"/Chicago95*; do
    [ -d "$d" ] && cp -r "$d" "$HOME/.themes/" 2>/dev/null || true
done
for d in "$C95_TMP/icons"/Chicago95*; do
    [ -d "$d" ] && cp -r "$d" "$HOME/.icons/" 2>/dev/null || true
done

# fonts
if [ -d "$C95_TMP/fonts" ]; then
    sudo mkdir -p /usr/share/fonts/chicago95
    find "$C95_TMP/fonts" \( -name "*.ttf" -o -name "*.otf" -o -name "*.pcf*" \) \
        -exec sudo cp {} /usr/share/fonts/chicago95/ \; 2>/dev/null || true
    sudo fc-cache -f 2>/dev/null && ok "chicago95 fonts installed"
fi

# write gtk2 settings
cat > "$HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name="Chicago95"
gtk-icon-theme-name="Chicago95"
gtk-font-name="Liberation Sans 10"
gtk-cursor-theme-name="Chicago95-cursor-black"
gtk-xft-antialias=0
gtk-xft-hinting=0
EOF

# write gtk3 settings
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Chicago95
gtk-icon-theme-name=Chicago95
gtk-font-name=Liberation Sans 10
gtk-cursor-theme-name=Chicago95-cursor-black
gtk-xft-antialias=0
gtk-xft-hinting=0
EOF

ok "gtk2 and gtk3 settings written"

# ── 4. XFCE SETTINGS ───────────────────────────────────────────────────────────
info "applying chicago95 to xfce..."

XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF_DIR"

# xsettings channel (gtk theme, icons, fonts, cursor)
cat > "$XFCONF_DIR/xsettings.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName"     type="string" value="Chicago95"/>
    <property name="IconThemeName" type="string" value="Chicago95"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName"          type="string" value="Liberation Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Liberation Mono 10"/>
    <property name="CursorThemeName"   type="string" value="Chicago95-cursor-black"/>
    <property name="CursorThemeSize"   type="int"    value="0"/>
    <property name="DecorationLayout"  type="string" value="menu:minimize,maximize,close"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int"    value="0"/>
    <property name="Hinting"   type="int"    value="0"/>
    <property name="HintStyle" type="string" value="hintnone"/>
    <property name="RGBA"      type="string" value="none"/>
  </property>
</channel>
EOF

# xfwm4 channel (window manager theme, buttons)
cat > "$XFCONF_DIR/xfwm4.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme"          type="string" value="Chicago95"/>
    <property name="title_font"     type="string" value="Liberation Sans Bold 8"/>
    <property name="title_alignment" type="string" value="left"/>
    <property name="button_layout"  type="string" value="menu|minimize,maximize,close"/>
    <property name="use_compositing" type="bool"  value="false"/>
    <property name="snap_to_border" type="bool"   value="true"/>
  </property>
</channel>
EOF

# apply live if in a desktop session
if command -v xfconf-query &>/dev/null && [ -n "$DISPLAY" ]; then
    xfconf-query -c xsettings -p /Net/ThemeName          -s "Chicago95"               2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName       -s "Chicago95"               2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName            -s "Liberation Sans 10"      2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/CursorThemeName     -s "Chicago95-cursor-black"  2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/Antialias           -s 0                         2>/dev/null || true
    xfconf-query -c xsettings -p /Xft/Hinting             -s 0                         2>/dev/null || true
    xfconf-query -c xfwm4     -p /general/theme           -s "Chicago95"               2>/dev/null || true
    xfconf-query -c xfwm4     -p /general/title_font      -s "Liberation Sans Bold 8"  2>/dev/null || true
    xfconf-query -c xfwm4     -p /general/button_layout   -s "menu|minimize,maximize,close" 2>/dev/null || true
    xfconf-query -c xfwm4     -p /general/use_compositing -s false                     2>/dev/null || true
    ok "xfce settings applied live"
fi

# ── 5. PANEL (win95 taskbar style) ─────────────────────────────────────────────
info "configuring xfce panel for win95 taskbar look..."

if command -v xfconf-query &>/dev/null && [ -n "$DISPLAY" ]; then
    # panel at bottom, small, no transparency
    xfconf-query -c xfce4-panel -p /panels/panel-1/position      -s "p=8;x=0;y=0"  2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size          -s 28              2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/background-style -s 0            2>/dev/null || true
    ok "panel positioned at bottom (win95 taskbar)"
fi

# ── 6. GRUB THEME ──────────────────────────────────────────────────────────────
info "installing chicago95 grub theme..."

GRUB_THEME_SRC=$(find "$C95_TMP/GRUB" -maxdepth 2 -name "theme.txt" 2>/dev/null | head -1 | xargs -I{} dirname {} 2>/dev/null)

if [ -n "$GRUB_THEME_SRC" ]; then
    sudo mkdir -p /boot/grub/themes/Chicago95
    sudo cp -r "$GRUB_THEME_SRC"/. /boot/grub/themes/Chicago95/
    ok "chicago95 grub theme files copied"

    GRUB_CFG=/etc/default/grub

    # remove any existing conflicting theme/terminal lines first then rewrite them
    sudo sed -i '/^GRUB_THEME=/d'           "$GRUB_CFG"
    sudo sed -i '/^GRUB_TERMINAL_OUTPUT=/d' "$GRUB_CFG"
    sudo sed -i '/^GRUB_GFXMODE=/d'         "$GRUB_CFG"
    sudo sed -i '/^GRUB_GFXPAYLOAD_LINUX=/d' "$GRUB_CFG"
    sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|' "$GRUB_CFG"

    sudo tee -a "$GRUB_CFG" > /dev/null << 'EOF'
GRUB_TERMINAL_OUTPUT=gfxterm
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_THEME=/boot/grub/themes/Chicago95/theme.txt
EOF
    ok "/etc/default/grub updated"

    # verify the theme file actually landed
    if sudo test -f /boot/grub/themes/Chicago95/theme.txt; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null && \
            ok "grub.cfg regenerated -- chicago95 theme will show on next boot" || \
            warn "grub-mkconfig failed -- run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    else
        warn "theme.txt missing from /boot/grub/themes/Chicago95/ -- grub-mkconfig skipped"
    fi
else
    skip "chicago95 grub theme" "theme.txt not found in repo clone"
fi

# ── 7. LIGHTDM LOGIN SCREEN ────────────────────────────────────────────────────
info "configuring lightdm login screen with chicago95..."

# copy theme to /usr/share so lightdm (root) can read it
if [ -d "/usr/share/themes/Chicago95" ]; then
    ok "chicago95 theme already in /usr/share/themes"
elif [ -d "$HOME/.themes/Chicago95" ]; then
    sudo cp -r "$HOME/.themes/Chicago95" /usr/share/themes/
    ok "chicago95 copied to /usr/share/themes"
fi
if [ -d "/usr/share/icons/Chicago95" ]; then
    ok "chicago95 icons already in /usr/share/icons"
elif [ -d "$HOME/.icons/Chicago95" ]; then
    sudo cp -r "$HOME/.icons/Chicago95" /usr/share/icons/
    ok "chicago95 icons copied to /usr/share/icons"
fi

# find a chicago95 wallpaper for the login screen
C95_WALL=$(find "$C95_TMP" \( -name "*.png" -o -name "*.jpg" \) 2>/dev/null | grep -i "wallpaper\|background\|desktop" | head -1)
[ -z "$C95_WALL" ] && C95_WALL=$(find "$C95_TMP" -name "*.png" 2>/dev/null | head -1)
if [ -n "$C95_WALL" ]; then
    sudo mkdir -p /usr/share/backgrounds/chicago95
    sudo cp "$C95_WALL" /usr/share/backgrounds/chicago95/login.png
    BG_LINE="background=/usr/share/backgrounds/chicago95/login.png"
else
    BG_LINE=""
fi

sudo mkdir -p /etc/lightdm
sudo tee /etc/lightdm/lightdm-gtk-greeter.conf > /dev/null << EOF
[greeter]
theme-name=Chicago95
icon-theme-name=Chicago95
font-name=Liberation Sans 10
${BG_LINE}
xft-antialias=false
xft-hinting=false
indicators=~clock;~spacer;~session;~power
clock-format=%A, %B %d    %H:%M
position=50%,center 50%,center
panel-position=bottom
EOF

# ensure lightdm uses gtk greeter
sudo mkdir -p /etc/lightdm
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
else
    sudo tee /etc/lightdm/lightdm.conf > /dev/null << 'EOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
EOF
fi

svc_enable lightdm
svc_start lightdm 2>/dev/null || true
ok "lightdm chicago95 greeter configured and enabled at boot"

# ── 8. SYSTEM SOUNDS ───────────────────────────────────────────────────────────
info "installing chicago95 system sounds..."

SOUNDS_SRC=$(find "$C95_TMP" -maxdepth 2 -type d -name "sounds" 2>/dev/null | head -1)
if [ -n "$SOUNDS_SRC" ]; then
    sudo mkdir -p /usr/share/sounds/Chicago95/stereo
    find "$SOUNDS_SRC" \( -name "*.ogg" -o -name "*.wav" \) 2>/dev/null \
        | xargs -I{} sudo cp {} /usr/share/sounds/Chicago95/stereo/ 2>/dev/null || true

    sudo tee /usr/share/sounds/Chicago95/index.theme > /dev/null << 'EOF'
[Sound Theme]
Name=Chicago95
Comment=Windows 95 style sound theme
Directories=stereo

[stereo]
OutputProfile=stereo
EOF
    ok "chicago95 sounds installed to /usr/share/sounds/Chicago95/"
    info "enable in xfce: settings manager -> sound -> sound theme -> Chicago95"
else
    # try the aur package location
    if [ -d /usr/share/sounds/Chicago95 ]; then
        ok "chicago95 sounds already at /usr/share/sounds/Chicago95 (from aur package)"
    else
        skip "chicago95 sounds" "sounds directory not found"
    fi
fi

# ── 9. WINE + WINETRICKS ───────────────────────────────────────────────────────
info "installing wine and winetricks..."

pkg wine
pkg wine-mono
pkg wine-gecko
pkg lib32-alsa-plugins
pkg lib32-libpulse
pkg lib32-openal

# winetricks from aur
aur winetricks

# playonlinux from aur
aur playonlinux

ok "wine packages installed"
# wine will auto-initialize ~/.wine on first use
# run 'winecfg' or 'winetricks' manually after install to set up runtimes

# ── 10. CLEANUP ────────────────────────────────────────────────────────────────
rm -rf "$C95_TMP"

# reload panel if in session
pkill -SIGUSR1 xfce4-panel 2>/dev/null || xfce4-panel --restart 2>/dev/null || true

# ── DONE ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}================================================${NC}"
echo -e "${GRN}  darbs artix chicago95 -- done${NC}"
echo -e "${GRN}================================================${NC}"
echo ""
echo "  reboot to see:"
echo "    - chicago95 grub theme at boot"
echo "    - chicago95 lightdm login screen"
echo ""
echo "  after reboot, finish in xfce:"
echo "    - settings manager -> appearance -> Chicago95"
echo "    - settings manager -> window manager -> Chicago95"
echo "    - settings manager -> sound -> sound theme -> Chicago95"
echo "    - right-click desktop -> desktop settings -> icons -> Chicago95"
echo ""
echo "  wine:"
echo "    - run 'winecfg' to configure wine"
echo "    - run 'winetricks' for more windows runtimes"
echo "    - use playonlinux for a gui wine manager"
echo ""
echo "  full log: $LOGFILE"
echo ""
