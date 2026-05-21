#!/bin/bash
# darbs-devuan-bb.sh -- kali/bug bounty tool installer for devuan
# installs all top kali and bug bounty tools without any ricing or theming
# run as your regular user (not root), script will sudo when needed
# usage: bash darbs-devuan-bb.sh

GRN='\033[0;32m'; YLW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "\n${GRN}==>${NC} $1"; }
ok()   { echo -e "  ${GRN}[OK]${NC}   $1"; }
skip() { echo -e "  ${YLW}[SKIP]${NC} $1 -- $2"; }
warn() { echo -e "  ${YLW}[!]${NC}   $1"; }
die()  { echo -e "${RED}[x]${NC} $1"; exit 1; }

[ "$EUID" -eq 0 ] && die "run as your regular user, not root."
command -v apt-get &>/dev/null || die "this script requires a debian/devuan system."

LOGFILE="$HOME/darbs-bb.log"
exec > >(tee -a "$LOGFILE") 2>&1

pkg() {
    dpkg -l "$1" &>/dev/null && ok "$1 already installed" && return
    sudo apt-get install -y "$1" 2>/dev/null && ok "$1" || skip "$1" "not available in repos"
}

gh_latest() {
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4
}

go_install() {
    local name="$1" pkg="$2"
    command -v "$name" &>/dev/null && ok "$name already installed" && return
    GOPATH="$HOME/go" go install "$pkg" 2>/dev/null && \
        sudo ln -sf "$HOME/go/bin/$name" "/usr/local/bin/$name" && \
        ok "$name" || skip "$name" "go install failed"
}

# ── 1. BASE DEPS ───────────────────────────────────────────────────────────────
info "installing base dependencies..."
sudo apt-get update -q
sudo apt-get install -y \
    git curl wget unzip p7zip-full \
    python3 python3-pip python3-venv pipx \
    ruby-full golang \
    jq fzf tmux ncat socat tcpdump \
    build-essential libssl-dev libffi-dev 2>/dev/null || \
    warn "some base packages failed, continuing."

# ── 2. KALI REPO (pinned low) ──────────────────────────────────────────────────
info "adding kali repo (pinned low priority)..."
if ! grep -q 'kali' /etc/apt/sources.list.d/*.list 2>/dev/null; then
    curl -fsSL https://archive.kali.org/archive-key.asc \
        | sudo gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] https://http.kali.org/kali kali-rolling main non-free non-free-firmware contrib" \
        | sudo tee /etc/apt/sources.list.d/kali.list > /dev/null
    sudo tee /etc/apt/preferences.d/kali-priority > /dev/null << 'EOF'
Package: *
Pin: release o=Kali
Pin-Priority: 50
EOF
    sudo apt-get update -q
    ok "kali repo added"
else
    ok "kali repo already configured"
fi

kali_pkg() {
    dpkg -l "$1" &>/dev/null && ok "$1 already installed" && return
    sudo apt-get install -y -t kali-rolling "$1" 2>/dev/null && ok "$1" || \
        sudo apt-get install -y "$1" 2>/dev/null && ok "$1 (from devuan)" || \
        skip "$1" "not available"
}

# ── 3. NETWORK SCANNERS ────────────────────────────────────────────────────────
info "installing network scanners..."
pkg nmap
pkg masscan
pkg wireshark
pkg tcpdump
pkg netdiscover
pkg arp-scan
pkg hping3
pkg whois
pkg dnsutils

# ── 4. WEB APP TOOLS ───────────────────────────────────────────────────────────
info "installing web app tools..."
pkg gobuster
pkg ffuf
pkg wfuzz
pkg nikto
pkg sqlmap
pkg whatweb
pkg dirb
pkg wafw00f
pkg mitmproxy

# feroxbuster from kali
kali_pkg feroxbuster

# ── 5. PASSWORD TOOLS ──────────────────────────────────────────────────────────
info "installing password tools..."
pkg john
pkg hashcat
pkg hydra
pkg medusa
pkg crunch
pkg cewl

# ── 6. WIFI TOOLS ──────────────────────────────────────────────────────────────
info "installing wifi tools..."
pkg aircrack-ng
pkg wifite
pkg reaver
pkg bully
pkg pixiewps
pkg cowpatty

# ── 7. EXPLOITATION / POST-EXPLOITATION ────────────────────────────────────────
info "installing exploitation tools..."
pkg exploitdb
pkg binwalk
pkg foremost
pkg macchanger
pkg socat
pkg proxychains4
pkg tor
pkg onionshare

# responder, crackmapexec, impacket from kali
kali_pkg responder
kali_pkg crackmapexec
kali_pkg impacket-scripts
kali_pkg bloodhound

# metasploit
info "installing metasploit framework..."
if ! command -v msfconsole &>/dev/null; then
    curl -sL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
        > /tmp/msfinstall
    chmod +x /tmp/msfinstall
    sudo /tmp/msfinstall
    rm -f /tmp/msfinstall
    ok "metasploit installed"
else
    ok "metasploit already installed"
fi

# ── 8. RECON / OSINT TOOLS ─────────────────────────────────────────────────────
info "installing recon/osint tools..."
pkg recon-ng
pkg theharvester
pkg dnsenum
pkg dnsrecon
pkg amass
pkg maltego 2>/dev/null || skip "maltego" "not in repos -- download manually from maltego.com"
pkg spiderfoot

# ── 9. WORDLISTS ───────────────────────────────────────────────────────────────
info "installing wordlists..."
kali_pkg seclists
pkg wordlists

# rockyou -- extract if packed
if [ -f /usr/share/wordlists/rockyou.txt.gz ] && \
   [ ! -f /usr/share/wordlists/rockyou.txt ]; then
    sudo gunzip /usr/share/wordlists/rockyou.txt.gz && ok "rockyou.txt extracted"
fi
[ -f /usr/share/wordlists/rockyou.txt ] && ok "rockyou.txt present" || \
    skip "rockyou.txt" "not found after extraction"

# ── 10. GO TOOLS (projectdiscovery + others) ───────────────────────────────────
info "installing go-based tools..."

export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin"

# install go if missing or too old
if ! command -v go &>/dev/null || \
   [[ "$(go version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 | cut -d. -f1)" -lt 1 ]]; then
    info "installing go from upstream..."
    GO_VER=$(curl -s https://go.dev/VERSION?m=text | head -1)
    curl -sL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    export PATH="$PATH:/usr/local/go/bin"
    echo 'export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"' >> "$HOME/.bashrc"
    ok "go installed: $(go version)"
fi

mkdir -p "$HOME/go/bin"

go_install subfinder   "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
go_install httpx       "github.com/projectdiscovery/httpx/cmd/httpx@latest"
go_install nuclei      "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
go_install dnsx        "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
go_install katana      "github.com/projectdiscovery/katana/cmd/katana@latest"
go_install interactsh-client "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
go_install shuffledns  "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"
go_install naabu       "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
go_install notify      "github.com/projectdiscovery/notify/cmd/notify@latest"

go_install gau         "github.com/lc/gau/v2/cmd/gau@latest"
go_install waybackurls "github.com/tomnomnom/waybackurls@latest"
go_install anew        "github.com/tomnomnom/anew@latest"
go_install qsreplace   "github.com/tomnomnom/qsreplace@latest"
go_install unfurl      "github.com/tomnomnom/unfurl@latest"
go_install meg         "github.com/tomnomnom/meg@latest"
go_install gf          "github.com/tomnomnom/gf@latest"
go_install assetfinder "github.com/tomnomnom/assetfinder@latest"
go_install httprobe    "github.com/tomnomnom/httprobe@latest"
go_install hakrawler   "github.com/hakluke/hakrawler@latest"
go_install dalfox      "github.com/hahwul/dalfox/v2@latest"
go_install gospider    "github.com/jaeles-project/gospider@latest"
go_install arjun       "github.com/s0md3v/Arjun@latest" 2>/dev/null || \
    pip3 install arjun --quiet 2>/dev/null && ok "arjun (pip)" || skip "arjun" "failed"

# gf patterns
if [ -d "$HOME/.gf" ]; then
    ok "gf patterns already present"
else
    git clone --depth=1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null && \
        mkdir -p "$HOME/.gf" && cp /tmp/gf-patterns/*.json "$HOME/.gf/" && \
        rm -rf /tmp/gf-patterns && ok "gf patterns installed" || skip "gf patterns" "git clone failed"
fi

# ── 11. GITHUB RELEASE INSTALLS ────────────────────────────────────────────────
info "installing tools from github releases..."

# chisel (tunneling)
command -v chisel &>/dev/null && ok "chisel already installed" || (
    VER=$(gh_latest jpillora/chisel)
    curl -sL "https://github.com/jpillora/chisel/releases/download/${VER}/chisel_${VER#v}_linux_amd64.gz" \
        -o /tmp/chisel.gz
    gunzip /tmp/chisel.gz
    sudo install -m755 /tmp/chisel /usr/local/bin/chisel
    rm -f /tmp/chisel
) 2>/dev/null && ok "chisel" || skip "chisel" "download failed"

# ligolo-ng (tunneling)
command -v ligolo-agent &>/dev/null && ok "ligolo-ng already installed" || (
    VER=$(gh_latest nicocha30/ligolo-ng)
    curl -sL "https://github.com/nicocha30/ligolo-ng/releases/download/${VER}/ligolo-ng_agent_${VER#v}_linux_amd64.tar.gz" \
        -o /tmp/ligolo-agent.tar.gz
    curl -sL "https://github.com/nicocha30/ligolo-ng/releases/download/${VER}/ligolo-ng_proxy_${VER#v}_linux_amd64.tar.gz" \
        -o /tmp/ligolo-proxy.tar.gz
    tar -xzf /tmp/ligolo-agent.tar.gz -C /tmp
    tar -xzf /tmp/ligolo-proxy.tar.gz -C /tmp
    sudo install -m755 /tmp/agent /usr/local/bin/ligolo-agent
    sudo install -m755 /tmp/proxy /usr/local/bin/ligolo-proxy
    rm -f /tmp/ligolo-*.tar.gz /tmp/agent /tmp/proxy
) 2>/dev/null && ok "ligolo-ng" || skip "ligolo-ng" "download failed"

# caido (web proxy)
command -v caido &>/dev/null && ok "caido already installed" || (
    VER=$(gh_latest caido/caido)
    [ -z "$VER" ] && exit 1
    curl -sL "https://github.com/caido/caido/releases/download/${VER}/caido-cli-${VER#v}-linux-x86_64.tar.gz" \
        -o /tmp/caido.tar.gz
    tar -xzf /tmp/caido.tar.gz -C /tmp
    find /tmp -maxdepth 2 -name "caido*" -type f \
        -exec sudo install -m755 {} /usr/local/bin/caido \; 2>/dev/null || true
    rm -f /tmp/caido.tar.gz
) 2>/dev/null && ok "caido" || skip "caido" "download failed"

# ── 12. PIP TOOLS ──────────────────────────────────────────────────────────────
info "installing python tools..."
pip3 install --quiet --break-system-packages \
    pwncat-cs \
    dirsearch \
    droopescan \
    wpscan-api \
    shodan \
    censys \
    2>/dev/null || \
pip3 install --quiet \
    pwncat-cs \
    dirsearch \
    droopescan \
    shodan \
    censys \
    2>/dev/null
ok "python tools installed"

# ── 13. RUBY TOOLS ─────────────────────────────────────────────────────────────
info "installing ruby tools..."
gem install evil-winrm --quiet 2>/dev/null && ok "evil-winrm" || skip "evil-winrm" "gem failed"
gem install wpscan --quiet 2>/dev/null && ok "wpscan" || skip "wpscan" "gem failed"

# ── 14. TOR (devuan-safe enable) ───────────────────────────────────────────────
info "enabling tor service..."
sudo update-rc.d tor enable 2>/dev/null && ok "tor enabled at boot" || \
    warn "could not enable tor at boot -- run: sudo service tor start"

# ── 15. NUCLEI TEMPLATES ───────────────────────────────────────────────────────
info "updating nuclei templates..."
command -v nuclei &>/dev/null && \
    nuclei -update-templates -silent 2>/dev/null && ok "nuclei templates updated" || \
    skip "nuclei templates" "nuclei not found"

# ── 16. CHICAGO95 ──────────────────────────────────────────────────────────────
info "installing chicago95 theme, login screen, grub theme, and sounds..."

sudo apt-get install -y \
    lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    gtk2-engines-pixbuf \
    fonts-liberation \
    2>/dev/null || warn "some lightdm packages failed, continuing."

C95_TMP="/tmp/chicago95"
rm -rf "$C95_TMP"
if git clone --depth=1 https://github.com/grassmunk/Chicago95 "$C95_TMP" 2>/dev/null; then
    ok "chicago95 repo cloned"

    # gtk theme
    mkdir -p "$HOME/.themes"
    for d in "$C95_TMP/Theme"/Chicago95*; do
        [ -d "$d" ] && cp -r "$d" "$HOME/.themes/" && \
            sudo cp -r "$d" /usr/share/themes/ 2>/dev/null || true
    done
    ok "chicago95 gtk themes installed"

    # icon + cursor themes
    mkdir -p "$HOME/.icons"
    for d in "$C95_TMP/icons"/Chicago95*; do
        [ -d "$d" ] && cp -r "$d" "$HOME/.icons/" && \
            sudo cp -r "$d" /usr/share/icons/ 2>/dev/null || true
    done
    ok "chicago95 icons and cursors installed"

    # fonts (MS Core / Chicago95 pixel fonts)
    sudo mkdir -p /usr/share/fonts/chicago95
    find "$C95_TMP/fonts" -name "*.ttf" -o -name "*.otf" -o -name "*.pcf*" 2>/dev/null \
        | xargs -I{} sudo cp {} /usr/share/fonts/chicago95/ 2>/dev/null || true
    sudo fc-cache -f 2>/dev/null && ok "chicago95 fonts installed" || true

    # grub theme
    C95_GRUB=$(find "$C95_TMP/GRUB" -maxdepth 2 -name "theme.txt" 2>/dev/null | head -1 | xargs -I{} dirname {})
    if [ -n "$C95_GRUB" ]; then
        sudo mkdir -p /boot/grub/themes/Chicago95
        sudo cp -r "$C95_GRUB"/. /boot/grub/themes/Chicago95/
        sudo sed -i \
            -e 's|^GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/Chicago95/theme.txt|' \
            -e 's|^#GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/Chicago95/theme.txt|' \
            /etc/default/grub 2>/dev/null
        grep -q 'GRUB_THEME' /etc/default/grub || \
            echo 'GRUB_THEME=/boot/grub/themes/Chicago95/theme.txt' \
            | sudo tee -a /etc/default/grub > /dev/null
        sudo sed -i \
            -e 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|' \
            -e 's|^GRUB_TERMINAL_OUTPUT=.*|GRUB_TERMINAL_OUTPUT=gfxterm|' \
            /etc/default/grub 2>/dev/null
        grep -q 'GRUB_TERMINAL_OUTPUT' /etc/default/grub || \
            echo 'GRUB_TERMINAL_OUTPUT=gfxterm' | sudo tee -a /etc/default/grub > /dev/null
        sudo update-grub 2>/dev/null && ok "chicago95 grub theme set" || \
            skip "grub update" "update-grub failed -- run manually"
    else
        skip "chicago95 grub theme" "theme.txt not found in repo"
    fi

    # lightdm login screen (gtk greeter)
    C95_WALL=$(find "$C95_TMP" -name "*.png" -path "*/wallpapers/*" 2>/dev/null | head -1)
    [ -z "$C95_WALL" ] && C95_WALL=$(find "$C95_TMP" -name "*.png" 2>/dev/null | head -1)
    if [ -n "$C95_WALL" ]; then
        sudo mkdir -p /usr/share/backgrounds/chicago95
        sudo cp "$C95_WALL" /usr/share/backgrounds/chicago95/login.png
    fi

    sudo mkdir -p /etc/lightdm
    sudo tee /etc/lightdm/lightdm-gtk-greeter.conf > /dev/null << EOF
[greeter]
theme-name=Chicago95
icon-theme-name=Chicago95
font-name=Liberation Sans 10
background=${C95_WALL:+/usr/share/backgrounds/chicago95/login.png}
xft-antialias=false
indicators=~clock;~spacer;~session;~power
clock-format=%A, %B %d    %H:%M
position=50%,center 50%,center
panel-position=top
EOF
    ok "lightdm chicago95 greeter configured"

    # system sounds
    SOUNDS_SRC=$(find "$C95_TMP" -maxdepth 2 -type d -name "sounds" 2>/dev/null | head -1)
    if [ -n "$SOUNDS_SRC" ]; then
        sudo mkdir -p /usr/share/sounds/Chicago95/stereo
        find "$SOUNDS_SRC" -name "*.ogg" -o -name "*.wav" 2>/dev/null \
            | xargs -I{} sudo cp {} /usr/share/sounds/Chicago95/stereo/ 2>/dev/null || true

        # write freedesktop sound theme index
        sudo tee /usr/share/sounds/Chicago95/index.theme > /dev/null << 'EOF'
[Sound Theme]
Name=Chicago95
Comment=Windows 95 style sounds
Directories=stereo

[stereo]
OutputProfile=stereo
EOF
        ok "chicago95 system sounds installed to /usr/share/sounds/Chicago95/"
        info "to enable sounds in xfce: settings manager -> sound -> sound theme -> Chicago95"
    else
        skip "chicago95 sounds" "sounds directory not found in repo"
    fi

    # apply gtk + icon theme via xfconf if in a desktop session
    xfconf-query -c xsettings -p /Net/ThemeName    -s "Chicago95"        2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "Chicago95"        2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "Chicago95-cursor-black" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName     -s "Liberation Sans 10" 2>/dev/null || true

    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Chicago95
gtk-icon-theme-name=Chicago95
gtk-font-name=Liberation Sans 10
gtk-cursor-theme-name=Chicago95-cursor-black
gtk-xft-antialias=0
EOF
    cat > "$HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name="Chicago95"
gtk-icon-theme-name="Chicago95"
gtk-font-name="Liberation Sans 10"
gtk-cursor-theme-name="Chicago95-cursor-black"
gtk-xft-antialias=0
EOF
    ok "gtk settings written"

    rm -rf "$C95_TMP"
else
    skip "chicago95" "git clone failed -- check internet connection"
fi

# ── 17. WINE ───────────────────────────────────────────────────────────────────
info "installing wine..."

# enable 32-bit arch (required for wine32)
sudo dpkg --add-architecture i386 2>/dev/null
sudo apt-get update -q

# try winehq stable repo first (best version), fall back to distro wine
WINE_INSTALLED=false
if ! dpkg -l winehq-stable &>/dev/null && ! dpkg -l wine &>/dev/null; then

    # detect devuan/debian codename for winehq repo
    CODENAME=$(grep VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    # devuan uses its own codenames -- map to debian equivalents for winehq
    case "$CODENAME" in
        excalibur) DEB_CODENAME="trixie" ;;
        daedalus)  DEB_CODENAME="bookworm" ;;
        chimaera)  DEB_CODENAME="bullseye" ;;
        beowulf)   DEB_CODENAME="buster" ;;
        *)         DEB_CODENAME="$CODENAME" ;;
    esac

    info "adding winehq repo for debian $DEB_CODENAME..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key 2>/dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian/ $DEB_CODENAME main" \
        | sudo tee /etc/apt/sources.list.d/winehq.list > /dev/null && \
    sudo apt-get update -q && \
    sudo apt-get install -y --install-recommends winehq-stable 2>/dev/null && \
    WINE_INSTALLED=true && ok "winehq-stable installed" || {
        warn "winehq repo failed, falling back to distro wine..."
        sudo rm -f /etc/apt/sources.list.d/winehq.list
        sudo apt-get update -q
    }
fi

# distro wine fallback
if ! $WINE_INSTALLED && ! dpkg -l wine &>/dev/null; then
    sudo apt-get install -y wine wine32 wine64 libwine libwine:i386 2>/dev/null && \
        WINE_INSTALLED=true && ok "wine installed (distro)" || \
        skip "wine" "install failed -- try manually: sudo apt install wine"
fi

dpkg -l wine* &>/dev/null && WINE_INSTALLED=true

# winetricks
if ! command -v winetricks &>/dev/null; then
    curl -sL https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
        -o /tmp/winetricks
    sudo install -m755 /tmp/winetricks /usr/local/bin/winetricks
    rm -f /tmp/winetricks
    ok "winetricks installed"
else
    ok "winetricks already installed"
fi

# playonlinux (gui wine manager)
pkg playonlinux

# init default wineprefix silently (needs display -- skip if headless)
if $WINE_INSTALLED && [ -n "$DISPLAY" ]; then
    WINEDEBUG=-all WINEPREFIX="$HOME/.wine" wineboot --init 2>/dev/null && \
        ok "wineprefix initialized at ~/.wine" || \
        warn "wineprefix init failed -- run 'winecfg' after first login"
elif $WINE_INSTALLED; then
    warn "no display detected -- run 'winecfg' after first login to initialize wineprefix"
fi

# common winetricks verbs for compatibility
if $WINE_INSTALLED && [ -n "$DISPLAY" ] && command -v winetricks &>/dev/null; then
    info "installing common wine runtime components..."
    WINEDEBUG=-all winetricks -q vcrun2019 vcrun6 d3dx9 corefonts 2>/dev/null && \
        ok "wine runtimes installed (vcrun2019, d3dx9, corefonts)" || \
        warn "some winetricks components failed -- run winetricks manually if needed"
fi

# ── 18. ALL KALI TOOL META-PACKAGES ───────────────────────────────────────────
info "installing all kali tool groups from kali repo..."

# these are the kali meta-packages that pull in every tool in each category
KALI_METAS=(
    kali-tools-information-gathering
    kali-tools-vulnerability
    kali-tools-web
    kali-tools-database
    kali-tools-passwords
    kali-tools-wireless
    kali-tools-reverse-engineering
    kali-tools-exploitation
    kali-tools-sniffing-spoofing
    kali-tools-post-exploitation
    kali-tools-forensics
    kali-tools-reporting
    kali-tools-social-engineering
    kali-tools-crypto-stego
    kali-tools-hardware
)

for meta in "${KALI_METAS[@]}"; do
    dpkg -l "$meta" &>/dev/null && ok "$meta already installed" && continue
    sudo apt-get install -y -t kali-rolling "$meta" 2>/dev/null && ok "$meta" || \
        warn "$meta failed -- some tools in this group may not be available on devuan"
done

# ── 19. KALI-STYLE WHISKER MENU ────────────────────────────────────────────────
info "building kali-style whisker menu..."

DDIR="/usr/share/desktop-directories"
ADIR="/usr/share/applications"
MDIR="/etc/xdg/menus/applications-merged"
sudo mkdir -p "$DDIR" "$ADIR" "$MDIR"

# helper: write a .directory file
make_dir() {
    local file="$1" name="$2" icon="$3"
    sudo tee "$DDIR/$file" > /dev/null << EOF
[Desktop Entry]
Type=Directory
Name=$name
Icon=$icon
EOF
}

# helper: write a terminal .desktop file (for cli tools without one)
make_desktop() {
    local id="$1" name="$2" exec="$3" cats="$4" comment="$5"
    [ -f "$ADIR/${id}.desktop" ] && return
    sudo tee "$ADIR/${id}.desktop" > /dev/null << EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=xfce4-terminal -T "$name" -e "bash -c '$exec; bash'"
Icon=utilities-terminal
Categories=$cats
Terminal=false
EOF
}

# ── directory entries ──────────────────────────────────────────────────────────
make_dir "kali-tools.directory"                "Kali Tools"              "kali-menu"
make_dir "kali-01-info.directory"              "Information Gathering"   "kali-information-gathering"
make_dir "kali-02-vuln.directory"              "Vulnerability Analysis"  "kali-vulnerability-analysis"
make_dir "kali-03-web.directory"               "Web Application"         "kali-web-application-analysis"
make_dir "kali-04-db.directory"                "Database Assessment"     "kali-database-assessment"
make_dir "kali-05-passwords.directory"         "Password Attacks"        "kali-password-attacks"
make_dir "kali-06-wireless.directory"          "Wireless Attacks"        "kali-wireless-attacks"
make_dir "kali-07-re.directory"                "Reverse Engineering"     "kali-reverse-engineering"
make_dir "kali-08-exploit.directory"           "Exploitation Tools"      "kali-exploitation-tools"
make_dir "kali-09-sniff.directory"             "Sniffing & Spoofing"     "kali-sniffing-spoofing"
make_dir "kali-10-post.directory"              "Post Exploitation"       "kali-post-exploitation"
make_dir "kali-11-forensics.directory"         "Forensics"               "kali-forensics"
make_dir "kali-12-reporting.directory"         "Reporting Tools"         "kali-reporting-tools"
make_dir "kali-13-social.directory"            "Social Engineering"      "kali-social-engineering"
make_dir "kali-14-recon.directory"             "Recon / OSINT"           "kali-information-gathering"

# ── .desktop files for tools without them (go tools, pip tools) ───────────────

# information gathering
make_desktop "darbs-subfinder"    "Subfinder"       "subfinder"              "Kali;Kali-Information-Gathering;"   "subdomain discovery"
make_desktop "darbs-assetfinder"  "Assetfinder"     "assetfinder"            "Kali;Kali-Information-Gathering;"   "find domains and subdomains"
make_desktop "darbs-amass"        "Amass"           "amass enum -d example.com" "Kali;Kali-Information-Gathering;" "in-depth subdomain enumeration"
make_desktop "darbs-dnsx"         "Dnsx"            "dnsx"                   "Kali;Kali-Information-Gathering;"   "dns toolkit"
make_desktop "darbs-httprobe"     "Httprobe"        "httprobe"               "Kali;Kali-Information-Gathering;"   "probe hosts for http/https"
make_desktop "darbs-httpx"        "Httpx"           "httpx"                  "Kali;Kali-Information-Gathering;"   "fast http toolkit"
make_desktop "darbs-naabu"        "Naabu"           "naabu"                  "Kali;Kali-Information-Gathering;"   "fast port scanner"
make_desktop "darbs-shodan"       "Shodan CLI"      "shodan"                 "Kali;Kali-Information-Gathering;"   "shodan command line"

# web application
make_desktop "darbs-ffuf"         "Ffuf"            "ffuf"                   "Kali;Kali-Web-Applications;"        "fast web fuzzer"
make_desktop "darbs-feroxbuster"  "Feroxbuster"     "feroxbuster"            "Kali;Kali-Web-Applications;"        "fast content discovery"
make_desktop "darbs-dirsearch"    "Dirsearch"       "dirsearch"              "Kali;Kali-Web-Applications;"        "web path scanner"
make_desktop "darbs-katana"       "Katana"          "katana"                 "Kali;Kali-Web-Applications;"        "web crawler"
make_desktop "darbs-gospider"     "Gospider"        "gospider"               "Kali;Kali-Web-Applications;"        "fast web spider"
make_desktop "darbs-hakrawler"    "Hakrawler"       "hakrawler"              "Kali;Kali-Web-Applications;"        "web crawler for endpoints"
make_desktop "darbs-gau"          "Gau"             "gau"                    "Kali;Kali-Web-Applications;"        "fetch known urls"
make_desktop "darbs-waybackurls"  "Waybackurls"     "waybackurls"            "Kali;Kali-Web-Applications;"        "fetch wayback machine urls"
make_desktop "darbs-dalfox"       "Dalfox"          "dalfox"                 "Kali;Kali-Web-Applications;"        "xss scanner"
make_desktop "darbs-arjun"        "Arjun"           "arjun"                  "Kali;Kali-Web-Applications;"        "http parameter discovery"
make_desktop "darbs-qsreplace"    "Qsreplace"       "qsreplace"              "Kali;Kali-Web-Applications;"        "replace querystring values"
make_desktop "darbs-caido"        "Caido"           "caido"                  "Kali;Kali-Web-Applications;"        "web security testing proxy"

# vulnerability analysis
make_desktop "darbs-nuclei"       "Nuclei"          "nuclei"                 "Kali;Kali-Vulnerability-Analysis;"  "vulnerability scanner"

# password attacks
make_desktop "darbs-cewl"         "CeWL"            "cewl"                   "Kali;Kali-Password-Attacks;"        "custom wordlist generator"
make_desktop "darbs-crunch"       "Crunch"          "crunch"                 "Kali;Kali-Password-Attacks;"        "wordlist generator"

# exploitation
make_desktop "darbs-chisel"       "Chisel"          "chisel"                 "Kali;Kali-Exploitation-Tools;"      "tcp/udp tunnel over http"
make_desktop "darbs-ligolo-proxy" "Ligolo Proxy"    "ligolo-proxy"           "Kali;Kali-Exploitation-Tools;"      "ligolo-ng proxy (attacker)"
make_desktop "darbs-ligolo-agent" "Ligolo Agent"    "ligolo-agent"           "Kali;Kali-Exploitation-Tools;"      "ligolo-ng agent (target)"

# post exploitation
make_desktop "darbs-evil-winrm"   "Evil-WinRM"      "evil-winrm"             "Kali;Kali-Post-Exploitation;"       "winrm shell for pentesting"
make_desktop "darbs-pwncat"       "Pwncat-cs"       "pwncat-cs"              "Kali;Kali-Post-Exploitation;"       "reverse shell handler"

# recon / osint
make_desktop "darbs-unfurl"       "Unfurl"          "unfurl"                 "Kali;Kali-Recon-OSINT;"             "extract url components"
make_desktop "darbs-meg"          "Meg"             "meg"                    "Kali;Kali-Recon-OSINT;"             "fetch many paths for many hosts"
make_desktop "darbs-gf"           "Gf"              "gf"                     "Kali;Kali-Recon-OSINT;"             "grep patterns for security"
make_desktop "darbs-anew"         "Anew"            "anew"                   "Kali;Kali-Recon-OSINT;"             "add lines to file if not seen"
make_desktop "darbs-interactsh"   "Interactsh"      "interactsh-client"      "Kali;Kali-Recon-OSINT;"             "oob interaction testing"

# ── the menu file ──────────────────────────────────────────────────────────────
sudo tee "$MDIR/kali-tools.menu" > /dev/null << 'MENUEOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>Kali Tools</Name>
    <Directory>kali-tools.directory</Directory>
    <Menu>
      <Name>Information Gathering</Name>
      <Directory>kali-01-info.directory</Directory>
      <Include><Category>Kali-Information-Gathering</Category></Include>
    </Menu>
    <Menu>
      <Name>Vulnerability Analysis</Name>
      <Directory>kali-02-vuln.directory</Directory>
      <Include><Category>Kali-Vulnerability-Analysis</Category></Include>
    </Menu>
    <Menu>
      <Name>Web Application</Name>
      <Directory>kali-03-web.directory</Directory>
      <Include><Category>Kali-Web-Applications</Category></Include>
    </Menu>
    <Menu>
      <Name>Database Assessment</Name>
      <Directory>kali-04-db.directory</Directory>
      <Include><Category>Kali-Database-Assessment</Category></Include>
    </Menu>
    <Menu>
      <Name>Password Attacks</Name>
      <Directory>kali-05-passwords.directory</Directory>
      <Include><Category>Kali-Password-Attacks</Category></Include>
    </Menu>
    <Menu>
      <Name>Wireless Attacks</Name>
      <Directory>kali-06-wireless.directory</Directory>
      <Include><Category>Kali-Wireless-Attacks</Category></Include>
    </Menu>
    <Menu>
      <Name>Reverse Engineering</Name>
      <Directory>kali-07-re.directory</Directory>
      <Include><Category>Kali-Reverse-Engineering</Category></Include>
    </Menu>
    <Menu>
      <Name>Exploitation Tools</Name>
      <Directory>kali-08-exploit.directory</Directory>
      <Include><Category>Kali-Exploitation-Tools</Category></Include>
    </Menu>
    <Menu>
      <Name>Sniffing &amp; Spoofing</Name>
      <Directory>kali-09-sniff.directory</Directory>
      <Include><Category>Kali-Sniffing-Spoofing</Category></Include>
    </Menu>
    <Menu>
      <Name>Post Exploitation</Name>
      <Directory>kali-10-post.directory</Directory>
      <Include><Category>Kali-Post-Exploitation</Category></Include>
    </Menu>
    <Menu>
      <Name>Forensics</Name>
      <Directory>kali-11-forensics.directory</Directory>
      <Include><Category>Kali-Forensics</Category></Include>
    </Menu>
    <Menu>
      <Name>Reporting Tools</Name>
      <Directory>kali-12-reporting.directory</Directory>
      <Include><Category>Kali-Reporting-Tools</Category></Include>
    </Menu>
    <Menu>
      <Name>Social Engineering</Name>
      <Directory>kali-13-social.directory</Directory>
      <Include><Category>Kali-Social-Engineering</Category></Include>
    </Menu>
    <Menu>
      <Name>Recon / OSINT</Name>
      <Directory>kali-14-recon.directory</Directory>
      <Include><Category>Kali-Recon-OSINT</Category></Include>
    </Menu>
  </Menu>
</Menu>
MENUEOF
ok "kali menu file written"

# refresh xdg menu cache
sudo update-menus 2>/dev/null || true
xdg-desktop-menu forceupdate 2>/dev/null || true

# tell whisker to reload
pkill -SIGUSR1 xfce4-panel 2>/dev/null || xfce4-panel --restart 2>/dev/null || true
ok "whisker menu updated -- log out and back in if categories don't appear"

# ── DONE ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}================================================${NC}"
echo -e "${GRN}  darbs devuan bb -- done${NC}"
echo -e "${GRN}================================================${NC}"
echo ""
echo "  manual installs needed:"
echo "    burp suite:  https://portswigger.net/burp/communitydownload"
echo "    maltego:     https://www.maltego.com/downloads/"
echo ""
echo "  to finish chicago95:"
echo "    - reboot to see grub theme and lightdm login screen"
echo "    - xfce settings manager -> appearance -> Chicago95"
echo "    - xfce settings manager -> sound -> sound theme -> Chicago95"
echo ""
echo "  wine notes:"
echo "    - run 'winecfg' to configure wine settings"
echo "    - run 'winetricks' for additional windows runtimes"
echo "    - playonlinux provides a gui for managing wine apps"
echo ""
echo "  kali menu notes:"
echo "    - log out and back in if the Kali Tools menu doesn't appear"
echo "    - right-click whisker menu -> properties -> edit menu to verify"
echo ""
echo "  reload shell to pick up go tools:"
echo "    source ~/.bashrc"
echo ""
echo "  full log: $LOGFILE"
echo ""
