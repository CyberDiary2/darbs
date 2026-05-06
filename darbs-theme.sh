#!/bin/bash
# darbs-theme.sh — apply darbs Everforest theme without re-running full darbs
# run this on any existing Arch / Artix / BlackArch XFCE install

DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"
DOT_DIR="$HOME/.dotfiles"

GREEN="\e[32m"
RESET="\e[0m"
log() { echo -e "${GREEN}==>${RESET} $1"; }

echo -e "\e[38;5;22m
██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║███████║██████╔╝██████╔╝███████╗
██║  ██║██╔══██║██╔══██╗██╔══██╗╚════██║
██████╔╝██║  ██║██║  ██║██████╔╝███████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝
\e[0m"
echo "=== darbs retheme ==="

# -----------------------------
# DOTFILES
# -----------------------------
log "Syncing dotfiles..."
if [ ! -d "$DOT_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOT_DIR"
else
    git -C "$DOT_DIR" pull
fi

# -----------------------------
# EVERFOREST GTK THEME
# -----------------------------
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    log "Everforest theme already installed, skipping."
else
    log "Installing Everforest GTK theme..."
    command -v sassc &>/dev/null || sudo pacman -S --noconfirm sassc 2>/dev/null || true
    mkdir -p "$HOME/.themes"
    rm -rf /tmp/everforest
    git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
    /tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes" || log "WARNING: install.sh failed"
    rm -rf /tmp/everforest
fi

# copy theme system-wide so LightDM (runs as root) can access it
sudo mkdir -p /usr/share/themes
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/ 2>/dev/null || true
fi

# -----------------------------
# GTK SETTINGS (written directly, not from dotfiles)
# -----------------------------
log "Writing GTK theme settings..."

mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name = Everforest-Green-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Noto Sans 10
gtk-cursor-theme-name = Adwaita
gtk-cursor-theme-size = 0
gtk-toolbar-style = GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size = GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images = 0
gtk-menu-images = 0
gtk-enable-event-sounds = 1
gtk-enable-input-feedback-sounds = 1
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
gtk-toolbar-style = GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size = GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images = 0
gtk-menu-images = 0
gtk-enable-event-sounds = 1
gtk-enable-input-feedback-sounds = 1
EOF

mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name = Everforest-Green-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Noto Sans 10
gtk-cursor-theme-name = Adwaita
EOF

# -----------------------------
# XFCONF XML (written directly so settings survive without a live session)
# -----------------------------
log "Writing xfconf theme XML files..."

XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF_DIR"

# xsettings: GTK theme + icons + fonts
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

# xfwm4: window manager theme + title font
cat > "$XFCONF_DIR/xfwm4.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Everforest-Green-Dark"/>
    <property name="title_font" type="string" value="Noto Sans Bold 9"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="CMH|"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="inactive_opacity" type="int" value="100"/>
  </property>
</channel>
EOF

# xfce4-desktop: wallpaper (paths get set live below if DISPLAY available)
WALL="$HOME/wallpapers/0327.jpg"
if [ ! -f "$WALL" ]; then
    WALL=""
fi

# -----------------------------
# APPLY VIA XFCONF-QUERY (only works if running inside a desktop session)
# -----------------------------
if command -v xfconf-query &>/dev/null && [ -n "$DISPLAY" ]; then
    log "Applying theme live via xfconf-query..."

    xfconf-query -c xsettings -p /Net/ThemeName       -s "Everforest-Green-Dark" --create -t string
    xfconf-query -c xsettings -p /Net/IconThemeName    -s "Papirus-Dark"          --create -t string
    xfconf-query -c xsettings -p /Gtk/FontName         -s "Noto Sans 10"          --create -t string
    xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Noto Sans Mono 10"    --create -t string
    xfconf-query -c xsettings -p /Gtk/CursorThemeName  -s "Adwaita"               --create -t string
    xfconf-query -c xsettings -p /Xft/Antialias        -s 1                       --create -t int
    xfconf-query -c xsettings -p /Xft/Hinting          -s 1                       --create -t int
    xfconf-query -c xsettings -p /Xft/HintStyle        -s "hintslight"            --create -t string
    xfconf-query -c xsettings -p /Xft/RGBA             -s "rgb"                   --create -t string

    xfconf-query -c xfwm4 -p /general/theme       -s "Everforest-Green-Dark" --create -t string
    xfconf-query -c xfwm4 -p /general/title_font  -s "Noto Sans Bold 9"      --create -t string

    if [ -n "$WALL" ]; then
        xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image | while read -r path; do
            xfconf-query -c xfce4-desktop -p "$path" -s "$WALL" 2>/dev/null || true
        done
        xfconf-query -c xfce4-desktop -l 2>/dev/null | grep image-style | while read -r path; do
            xfconf-query -c xfce4-desktop -p "$path" -s 3 2>/dev/null || true
        done
    fi

    log "Theme applied live. Changes visible immediately."
else
    log "No active display session -- XML files written, theme applies on next login."
fi

# -----------------------------
# DOTFILES: picom, rofi, tmux, nanorc, autostart
# -----------------------------
log "Applying dotfiles..."

mkdir -p "$HOME/.config/picom"
[ -f "$DOT_DIR/picom/picom.conf" ] && cp "$DOT_DIR/picom/picom.conf" "$HOME/.config/picom/picom.conf"

mkdir -p "$HOME/.config/rofi"
[ -f "$DOT_DIR/rofi/config.rasi" ] && cp "$DOT_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"

[ -f "$DOT_DIR/nanorc.nanorc" ] && cp "$DOT_DIR/nanorc.nanorc" "$HOME/.nanorc"

if [ -f "$DOT_DIR/.tmux.conf" ]; then
    cp "$DOT_DIR/.tmux.conf" "$HOME/.tmux.conf"
fi

mkdir -p "$HOME/.config/autostart"
[ -d "$DOT_DIR/autostart" ] && cp "$DOT_DIR/autostart/"*.desktop "$HOME/.config/autostart/" 2>/dev/null || true

# xfce4 panel + keyboard + other xml (don't overwrite xsettings/xfwm4 we just wrote)
XFCE_SRC="$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml"
if [ -d "$XFCE_SRC" ]; then
    for f in "$XFCE_SRC"/*.xml; do
        base="$(basename "$f")"
        # skip the ones we write explicitly above
        if [[ "$base" != "xsettings.xml" && "$base" != "xfwm4.xml" ]]; then
            cp "$f" "$XFCONF_DIR/$base"
        fi
    done
    sed -i "s|/home/drew|$HOME|g" "$XFCONF_DIR/xfce4-desktop.xml" 2>/dev/null || true
fi

# -----------------------------
# LIGHTDM GREETER
# -----------------------------
log "Updating LightDM greeter config..."

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
# WALLPAPER
# -----------------------------
mkdir -p "$HOME/wallpapers"
if [ -d "$DOT_DIR/wallpapers" ]; then
    cp -r --no-clobber "$DOT_DIR/wallpapers/." "$HOME/wallpapers/"
fi
[ -f "$HOME/wallpapers/0327.jpg" ] && \
    sudo cp -f "$HOME/wallpapers/0327.jpg" /usr/share/backgrounds/xfce/xfce-x.svg 2>/dev/null || true

# -----------------------------
# FASTFETCH (darbs branding)
# -----------------------------
log "Writing fastfetch config..."
mkdir -p "$HOME/.config/fastfetch"
cat > "$HOME/.config/fastfetch/config.jsonc" <<'FFEOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": { "source": "none" },
    "display": {
        "separator": "  ",
        "color": { "keys": "green", "title": "green" }
    },
    "modules": [
        {
            "type": "custom",
            "format": "[38;5;22m\n  ██████╗  █████╗ ██████╗ ██████╗ ███████╗\n  ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝\n  ██║  ██║███████║██████╔╝██████╔╝█████╗  \n  ██║  ██║██╔══██║██╔══██╗██╔══██╗██╔══╝  \n  ██████╔╝██║  ██║██║  ██║██████╔╝███████╗\n  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝\n[0m"
        },
        "break",
        "OS", "Kernel", "Uptime", "Packages", "Shell",
        "DE", "WM", "Terminal", "CPU", "GPU", "Memory",
        "break"
    ]
}
FFEOF

echo ""
log "darbs theme applied."
echo ""
echo "  If theme does not update immediately: log out and back in."
echo "  Everforest-Green-Dark  |  Papirus-Dark icons  |  Noto Sans 10"
echo ""
