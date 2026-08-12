#!/bin/bash
# darbs-debian-x200t.sh
# Bootstrap a Debian install on a ThinkPad X200 Tablet:
#   i3 (with gaps) + darbs Everforest theme + Wacom pen + screen rotation.
#
# Run as your normal user (it uses sudo where needed):
#   sudo apt install -y git ca-certificates
#   git clone https://github.com/CyberDiary2/darbs
#   cd darbs && ./darbs-debian-x200t.sh
#
# Chosen defaults: alacritty terminal, firefox-esr, Xournal++/Krita/GIMP/onboard,
# LightDM login, dmenu launcher, pcmanfm+ranger files, neovim, i3status bar.

set -u
GREEN="\e[32m"; BLUE="\e[34m"; RESET="\e[0m"
log() { echo -e "${GREEN}==>${RESET} $1"; }

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not root (it calls sudo when needed)."
    exit 1
fi

echo -e "\e[38;5;22m=== darbs :: Debian X200 Tablet bootstrap ===\e[0m"

# -----------------------------
# PACKAGES
# -----------------------------
log "Updating apt and installing packages..."
sudo apt update
sudo apt install -y \
    xorg x11-xserver-utils xinput \
    xserver-xorg-input-wacom xserver-xorg-input-libinput \
    i3 i3status i3lock suckless-tools \
    picom dunst feh rofi xss-lock \
    xfce4-panel xfce4-whiskermenu-plugin \
    lightdm lightdm-gtk-greeter \
    network-manager network-manager-gnome \
    pulseaudio pulseaudio-utils pavucontrol \
    bluez blueman pulseaudio-module-bluetooth \
    brightnessctl \
    tp-smapi-dkms libnotify-bin \
    mate-polkit \
    alacritty \
    firefox-esr \
    ranger pcmanfm \
    neovim nano htop git curl wget unzip \
    flameshot \
    papirus-icon-theme sassc \
    fonts-dejavu fonts-noto \
    xournalpp onboard krita gimp \
    || log "WARNING: some packages failed to install (continuing)"

# -----------------------------
# SCREEN ROTATION SCRIPT (Wacom pen follows the screen)
# -----------------------------
# The X200t bezel rotate button emits XF86RotateWindows; i3 binds it below.
# Each press cycles normal -> right -> inverted -> left and rotates the pen to
# match via xsetwacom. The trackpoint is left untouched.
log "Installing screen rotation script..."
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/darbs-rotate" <<'ROTEOF'
#!/bin/sh
# darbs screen + pen rotation for a convertible tablet.
# Usage: darbs-rotate [normal|right|inverted|left]
#   no argument -> cycle to the next orientation
# find the internal panel (LVDS on the X200t), else the first connected output
OUT=$(xrandr | awk '/LVDS.* connected/{print $1; exit}')
[ -z "$OUT" ] && OUT=$(xrandr | awk '/ connected/{print $1; exit}')

STATE="${XDG_RUNTIME_DIR:-/tmp}/darbs-screen-rotation"
if [ -n "$1" ]; then
    NEW="$1"
else
    CUR=$(cat "$STATE" 2>/dev/null || echo normal)
    case "$CUR" in
        normal)   NEW=right    ;;
        right)    NEW=inverted ;;
        inverted) NEW=left     ;;
        *)        NEW=normal   ;;
    esac
fi
case "$NEW" in
    right)    WROT=cw   ;;
    inverted) WROT=half ;;
    left)     WROT=ccw  ;;
    *)        NEW=normal; WROT=none ;;
esac

# skip if already in that orientation (keeps the auto-rotate daemon quiet)
[ "$(cat "$STATE" 2>/dev/null)" = "$NEW" ] && exit 0

xrandr --output "$OUT" --rotate "$NEW"
echo "$NEW" > "$STATE"

# rotate every Wacom device (pen, eraser, and touch if present)
xsetwacom --list devices 2>/dev/null | sed -n 's/.*id: \([0-9]\+\).*/\1/p' | while read -r id; do
    xsetwacom set "$id" Rotate "$WROT" 2>/dev/null || true
done
ROTEOF
chmod +x "$HOME/.local/bin/darbs-rotate"

# auto-rotate daemon: reads the ThinkPad APS (hdaps) accelerometer and rotates
# to match how you are physically holding the tablet. hdaps support on the X200
# is hit or miss, so this exits cleanly if the sensor is not exposed. Thresholds
# and axis signs are calibration knobs (override via env before launch).
cat > "$HOME/.local/bin/darbs-autorotate" <<'AREOF'
#!/bin/sh
# auto screen rotation from the hdaps accelerometer
POS=/sys/devices/platform/hdaps/position
if [ ! -r "$POS" ]; then
    command -v notify-send >/dev/null 2>&1 && \
        notify-send "darbs-autorotate" "No hdaps sensor. Load it: sudo modprobe hdaps. If it still fails, this X200t does not expose the accelerometer."
    exit 1
fi

THRESH=${DARBS_AR_THRESH:-45}   # ignore tilts smaller than this (near-flat)
INTERVAL=${DARBS_AR_INTERVAL:-1}
LAST=""
while :; do
    RAW=$(cat "$POS" 2>/dev/null | tr -d '() ')   # "(x,y)" -> "x,y"
    X=${RAW%,*}; Y=${RAW#*,}
    case "$X$Y" in *[!0-9-]*|"") sleep "$INTERVAL"; continue ;; esac
    ax=${X#-}; ay=${Y#-}
    # near flat on a desk: keep whatever we have, do not flip randomly
    if [ "$ax" -lt "$THRESH" ] && [ "$ay" -lt "$THRESH" ]; then
        sleep "$INTERVAL"; continue
    fi
    if [ "$ax" -ge "$ay" ]; then
        [ "$X" -gt 0 ] && O=right || O=left
    else
        [ "$Y" -gt 0 ] && O=normal || O=inverted
    fi
    if [ "$O" != "$LAST" ]; then
        "$HOME/.local/bin/darbs-rotate" "$O"
        LAST="$O"
    fi
    sleep "$INTERVAL"
done
AREOF
chmod +x "$HOME/.local/bin/darbs-autorotate"

# load the accelerometer module now and at every boot (best effort)
log "Enabling hdaps accelerometer module (best effort)..."
echo -e "tp_smapi\nhdaps" | sudo tee /etc/modules-load.d/darbs-hdaps.conf > /dev/null
sudo modprobe tp_smapi 2>/dev/null || true
sudo modprobe hdaps 2>/dev/null || true

# -----------------------------
# EVERFOREST GTK THEME
# -----------------------------
if [ -d "$HOME/.themes/Everforest-Green-Dark" ] || [ -d "/usr/share/themes/Everforest-Green-Dark" ]; then
    log "Everforest GTK theme already present."
else
    log "Installing Everforest GTK theme..."
    mkdir -p "$HOME/.themes"
    rm -rf /tmp/everforest
    if git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest; then
        /tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes" || log "WARNING: theme install.sh failed"
    else
        log "WARNING: could not clone Everforest theme (check network/DNS)"
    fi
    rm -rf /tmp/everforest
fi
if [ -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    sudo mkdir -p /usr/share/themes
    sudo cp -rn "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/ 2>/dev/null || true
fi

# -----------------------------
# GTK SETTINGS
# -----------------------------
log "Writing GTK settings..."
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    cat > "$ini" <<'EOF'
[Settings]
gtk-theme-name = Everforest-Green-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Noto Sans 10
gtk-cursor-theme-name = Adwaita
gtk-application-prefer-dark-theme = 1
EOF
done
cat > "$HOME/.gtkrc-2.0" <<'EOF'
gtk-theme-name = "Everforest-Green-Dark"
gtk-icon-theme-name = "Papirus-Dark"
gtk-font-name = "Noto Sans 10"
EOF

# -----------------------------
# X RESOURCES (palette for xterm / st / any X client)
# -----------------------------
mkdir -p "$HOME/.config/x11"
cat > "$HOME/.config/x11/xresources" <<'EOF'
*.background: #0d1210
*.foreground: #d3c6aa
*.cursorColor: #5a9e44
*.color0:  #0d1210
*.color8:  #5a9e44
*.color1:  #e67e80
*.color9:  #e67e80
*.color2:  #5a9e44
*.color10: #a7c080
*.color3:  #dbbc7f
*.color11: #dbbc7f
*.color4:  #83a598
*.color12: #7fbbb3
*.color5:  #d699b6
*.color13: #d699b6
*.color6:  #83c092
*.color14: #83c092
*.color7:  #d3c6aa
*.color15: #d3c6aa
EOF

# -----------------------------
# ALACRITTY (themed, both TOML and YAML so any version works)
# -----------------------------
log "Writing alacritty config..."
mkdir -p "$HOME/.config/alacritty"
cat > "$HOME/.config/alacritty/alacritty.toml" <<'EOF'
[font]
size = 11.0
[font.normal]
family = "monospace"

[colors.primary]
background = "#0d1210"
foreground = "#d3c6aa"

[colors.cursor]
cursor = "#5a9e44"

[colors.normal]
black   = "#0d1210"
red     = "#e67e80"
green   = "#5a9e44"
yellow  = "#dbbc7f"
blue    = "#83a598"
magenta = "#d699b6"
cyan    = "#83c092"
white   = "#d3c6aa"

[colors.bright]
black   = "#5a9e44"
red     = "#e67e80"
green   = "#a7c080"
yellow  = "#dbbc7f"
blue    = "#7fbbb3"
magenta = "#d699b6"
cyan    = "#83c092"
white   = "#d3c6aa"
EOF
cat > "$HOME/.config/alacritty/alacritty.yml" <<'EOF'
font:
  normal:
    family: monospace
  size: 11.0
colors:
  primary:
    background: '#0d1210'
    foreground: '#d3c6aa'
  cursor:
    cursor: '#5a9e44'
  normal:
    black:   '#0d1210'
    red:     '#e67e80'
    green:   '#5a9e44'
    yellow:  '#dbbc7f'
    blue:    '#83a598'
    magenta: '#d699b6'
    cyan:    '#83c092'
    white:   '#d3c6aa'
  bright:
    black:   '#5a9e44'
    red:     '#e67e80'
    green:   '#a7c080'
    yellow:  '#dbbc7f'
    blue:    '#7fbbb3'
    magenta: '#d699b6'
    cyan:    '#83c092'
    white:   '#d3c6aa'
EOF

# -----------------------------
# i3 CONFIG (LARBS-style keys, Everforest, tablet bindings)
# -----------------------------
log "Writing i3 config..."
mkdir -p "$HOME/.config/i3" "$HOME/.config/i3status"
cat > "$HOME/.config/i3/config" <<'I3EOF'
# darbs i3 (Debian X200 Tablet) -- Super+Shift+c reloads, Super+Shift+r restarts

set $mod Mod4
set $term alacritty
set $menu dmenu_run -i

font pango:monospace 10

set $bg     #0d1210
set $fg     #d3c6aa
set $green  #5a9e44
set $blue   #83a598
set $gray   #2b3339
set $urgent #e67e80

# ---- autostart ----
exec_always --no-startup-id setxkbmap -option caps:escape
exec_always --no-startup-id sh -c 'test -f "$HOME/.config/x11/xresources" && xrdb -merge "$HOME/.config/x11/xresources"'
exec_always --no-startup-id sh -c 'test -f "$HOME/wallpapers/0327.jpg" && feh --bg-fill "$HOME/wallpapers/0327.jpg" || xsetroot -solid "#0d1210"'
exec --no-startup-id picom
exec --no-startup-id xfce4-panel
exec --no-startup-id dunst
exec --no-startup-id nm-applet
exec --no-startup-id blueman-applet
exec --no-startup-id /usr/lib/mate-polkit/polkit-mate-authentication-agent-1
exec --no-startup-id xss-lock -- i3lock -c 0d1210

# ---- mouse: hover to focus, mod+drag to move floating ----
focus_follows_mouse yes
floating_modifier $mod
tiling_drag modifier titlebar

# ---- gaps ----
gaps inner 12
gaps outer 4
smart_gaps on
smart_borders on
default_border pixel 2

# ---- tablet: rotate screen + pen ----
# auto-rotate from the accelerometer (exits quietly if hdaps is not present)
exec --no-startup-id ~/.local/bin/darbs-autorotate
# manual rotate: bezel rotate button or Super+o cycles orientation
bindsym XF86RotateWindows exec --no-startup-id ~/.local/bin/darbs-rotate
bindsym $mod+o exec --no-startup-id ~/.local/bin/darbs-rotate
# toggle the auto-rotate daemon on/off (handy in laptop mode)
bindsym $mod+Shift+o exec --no-startup-id sh -c 'pkill -f darbs-autorotate || ~/.local/bin/darbs-autorotate'
# on-screen keyboard toggle
bindsym $mod+F1 exec --no-startup-id sh -c 'pkill onboard || onboard'

# ---- core apps ----
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+w exec --no-startup-id firefox-esr
bindsym $mod+r exec --no-startup-id $term -e ranger
bindsym $mod+n exec --no-startup-id xournalpp
bindsym $mod+q kill
bindsym $mod+Shift+q kill

# ---- focus (vim + arrows) ----
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# ---- move ----
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# ---- splits ----
# Super+minus/underscore: opens BELOW (stack top/bottom) = i3 split v
bindsym $mod+minus split v
bindsym $mod+underscore split v
# Super+backslash/bar: opens to the RIGHT (side by side) = i3 split h
bindsym $mod+backslash split h
bindsym $mod+bar split h
bindsym $mod+v split v

# ---- layout ----
bindsym $mod+f fullscreen toggle
bindsym $mod+s layout stacking
bindsym $mod+t layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

# ---- resize ----
bindsym $mod+Ctrl+h resize shrink width 5 px or 5 ppt
bindsym $mod+Ctrl+l resize grow width 5 px or 5 ppt
bindsym $mod+Ctrl+k resize grow height 5 px or 5 ppt
bindsym $mod+Ctrl+j resize shrink height 5 px or 5 ppt

# ---- transparency of the focused window (picom must be running) ----
bindsym $mod+Ctrl+equal exec --no-startup-id picom-trans -c +5
bindsym $mod+Ctrl+minus exec --no-startup-id picom-trans -c -5
bindsym $mod+Ctrl+0 exec --no-startup-id picom-trans -c --reset

# ---- scratchpad ----
bindsym $mod+grave scratchpad show
bindsym $mod+Shift+grave move scratchpad

# ---- workspaces ----
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9
bindsym $mod+Shift+0 move container to workspace number 10

# ---- system ----
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec --no-startup-id i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'
bindsym $mod+x exec --no-startup-id i3lock -c 0d1210

# ---- media + screenshots (pactl works on pulseaudio or pipewire-pulse) ----
bindsym Print exec --no-startup-id flameshot gui
bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86MonBrightnessUp exec --no-startup-id brightnessctl set 10%+
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl set 10%-

# ---- colors ----
#                       border  bg      text  indicator child_border
client.focused          $green  $green  $bg   $blue     $green
client.focused_inactive $gray   $gray   $fg   $gray     $gray
client.unfocused        $bg     $bg     $fg   $bg       $gray
client.urgent           $urgent $urgent $bg   $urgent   $urgent
client.placeholder      $bg     $bg     $fg   $bg       $bg
client.background       $bg

# No i3bar: xfce4-panel provides the clickable top toolbar (menu, tasklist,
# tray, clock) and is started from the autostart section above.
I3EOF

cat > "$HOME/.config/i3status/config" <<'EOF'
general {
    colors = true
    color_good = "#5a9e44"
    color_degraded = "#dbbc7f"
    color_bad = "#e67e80"
    interval = 5
}
order += "wireless _first_"
order += "ethernet _first_"
order += "battery all"
order += "memory"
order += "volume master"
order += "tztime local"

wireless _first_ {
    format_up = "wifi %essid %quality"
    format_down = "wifi down"
}
ethernet _first_ {
    format_up = "eth %ip"
    format_down = "eth down"
}
battery all {
    format = "%status %percentage"
    status_chr = "chr"
    status_bat = "bat"
    status_full = "full"
}
memory {
    format = "mem %used"
    threshold_degraded = "10%"
}
volume master {
    format = "vol %volume"
    format_muted = "vol muted"
    device = "pulse"
}
tztime local {
    format = "%Y-%m-%d %H:%M"
}
EOF

# -----------------------------
# PICOM (compositor: window transparency)
# -----------------------------
# xrender backend + no shadows keeps the old Intel GMA on the X200t responsive.
# Unfocused windows go translucent; terminals stay slightly see-through.
log "Writing picom transparency config..."
mkdir -p "$HOME/.config/picom"
cat > "$HOME/.config/picom/picom.conf" <<'EOF'
backend = "xrender";
vsync = true;

# transparency
inactive-opacity = 0.88;
active-opacity = 1.00;
frame-opacity = 0.90;
inactive-opacity-override = false;

opacity-rule = [
    "92:class_g = 'Alacritty' && focused",
    "82:class_g = 'Alacritty' && !focused",
    "95:class_g = 'Xfce4-panel'"
];

# fading
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;

# shadows off (cheap on old hardware)
shadow = false;

# do not fade/blur the panel or dock oddly
wintypes:
{
    dock = { shadow = false; };
    tooltip = { fade = true; shadow = false; opacity = 0.95; focus = true; };
    popup_menu = { opacity = 0.95; };
    dropdown_menu = { opacity = 0.95; };
};
EOF

# -----------------------------
# XFCE4-PANEL LAYOUT (clickable toolbar inside i3)
# -----------------------------
# Pre-seed a top panel so xfce4-panel comes up configured (no first-run dialog):
# Whisker app menu, window tasklist, spacer, system tray, clock.
log "Writing xfce4-panel layout..."
XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF_DIR"
cat > "$XFCONF_DIR/xfce4-panel.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="icon-size" type="uint" value="16"/>
      <property name="size" type="uint" value="28"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="tasklist">
      <property name="grouping" type="uint" value="1"/>
    </property>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-5" type="string" value="clock">
      <property name="digital-layout" type="uint" value="3"/>
      <property name="digital-time-format" type="string" value="%Y-%m-%d %H:%M"/>
    </property>
  </property>
</channel>
EOF

# -----------------------------
# WALLPAPER (best effort from the darbs dotfiles; solid Everforest otherwise)
# -----------------------------
log "Fetching wallpaper (best effort)..."
mkdir -p "$HOME/wallpapers"
if [ ! -f "$HOME/wallpapers/0327.jpg" ]; then
    for br in master main; do
        if curl -fsSL "https://raw.githubusercontent.com/CyberDiary2/dotfiles/$br/wallpapers/0327.jpg" -o "$HOME/wallpapers/0327.jpg"; then
            break
        fi
    done
fi
if [ -f "$HOME/wallpapers/0327.jpg" ]; then
    sudo mkdir -p /usr/share/backgrounds
    sudo cp -f "$HOME/wallpapers/0327.jpg" /usr/share/backgrounds/darbs.jpg 2>/dev/null || true
fi

# -----------------------------
# LIGHTDM GREETER
# -----------------------------
log "Configuring LightDM greeter..."
sudo mkdir -p /etc/lightdm
GREETER_BG="/usr/share/backgrounds/darbs.jpg"
[ -f "$GREETER_BG" ] || GREETER_BG="#0d1210"
sudo tee /etc/lightdm/lightdm-gtk-greeter.conf > /dev/null <<EOF
[greeter]
theme-name = Everforest-Green-Dark
icon-theme-name = Papirus-Dark
font-name = monospace 12
background = $GREETER_BG
user-background = false
EOF
sudo systemctl enable lightdm 2>/dev/null || true

# NetworkManager as the network stack
sudo systemctl enable NetworkManager 2>/dev/null || true

# Bluetooth
sudo systemctl enable bluetooth 2>/dev/null || true
sudo systemctl start bluetooth 2>/dev/null || true

# -----------------------------
# DONE
# -----------------------------
echo ""
log "darbs X200 Tablet bootstrap complete."
echo -e "${BLUE}"
echo "====================================================="
echo " Reboot, then pick 'i3' at the LightDM login screen."
echo " Rotate: press the bezel rotate button or Super+o."
echo " Pen works in Xournal++/Krita/GIMP (pressure enabled)."
echo " On-screen keyboard: Super+F1."
echo "====================================================="
echo -e "${RESET}"
