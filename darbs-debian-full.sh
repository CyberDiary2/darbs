#!/bin/bash

################################################################################
#                                                                              #
#  DARBS (Debian) - Full Install                                               #
#                                                                              #
#  Runs the dotfiles/theming setup first, then installs the bug bounty and     #
#  security toolset on top. This is the Debian equivalent of darbs.sh, brought #
#  to parity with the Arch version: the full tool set is attempted, apt-first  #
#  with go / pip / manual fallbacks, and anything not packaged for Debian is   #
#  logged (never fatal) so the run always completes.                           #
#                                                                              #
#  Target: real Debian (stable/testing). Many offensive-security tools are not #
#  in Debian main -- those are pulled from go/pip/upstream, or logged as        #
#  unavailable if there is no clean source.                                    #
#                                                                              #
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# one shared failure log for both scripts; truncate before anything runs and
# export it so the dotfiles sub-script records into the same file
export FAILLOG="$HOME/darbs-failed.log"
: > "$FAILLOG"

# -----------------------------
# RUN DOTFILES / THEMING FIRST
# -----------------------------
bash "$SCRIPT_DIR/darbs-debian-dotfiles.sh"

echo "=== DARBS Debian (Full) - Installing security tools ==="

LOGFILE="$HOME/darbs.log"
exec > >(tee -a "$LOGFILE") 2>&1

GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

log()  { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}!! ${RESET} $1"; }

# Robust apt install: try the whole batch, and if that fails (usually one
# package that does not exist on Debian), retry every package individually and
# record the ones that could not be installed -- mirrors the Arch pacman_install
# so a big list with a few Debian-unavailable names never aborts the run.
apt_install() {
    local to_install=()
    for pkg in "$@"; do
        if dpkg -s "$pkg" &>/dev/null; then
            :  # already installed
        else
            to_install+=("$pkg")
        fi
    done
    [ ${#to_install[@]} -eq 0 ] && return 0
    if sudo apt-get install -y "${to_install[@]}" 2>/dev/null; then
        return 0
    fi
    warn "batch apt install failed, retrying one by one..."
    for pkg in "${to_install[@]}"; do
        if ! sudo apt-get install -y "$pkg" 2>/dev/null; then
            echo "apt: $pkg" >> "$FAILLOG"
            warn "could not install $pkg (logged to $FAILLOG)"
        fi
    done
}

# pip: prefer the apt package where it exists; fall back to pip (PEP 668 friendly)
pip_install() {
    for pkg in "$@"; do
        if pip3 install --user --break-system-packages "$pkg" 2>/dev/null \
            || pip3 install --user "$pkg" 2>/dev/null; then
            :
        else
            echo "pip: $pkg" >> "$FAILLOG"
            warn "could not pip install $pkg"
        fi
    done
}

go_install() {
    local pkg="$1"
    local bin; bin="$(basename "${pkg%%@*}")"
    if command -v "$bin" &>/dev/null; then
        log "skipping $bin (already installed)"
    elif ! go install "$pkg" 2>/dev/null; then
        echo "go: $pkg" >> "$FAILLOG"
        warn "could not go install $pkg"
    fi
}

log "updating apt..."
sudo apt-get update -y

# -----------------------------
# SECURITY TOOLS (apt)
# -----------------------------
# Everything below that Debian packages. Names are Debian's; anything absent on
# a given release is logged and skipped by apt_install, not fatal.
log "installing security tools from Debian repos..."
apt_install \
    nmap ncat sqlmap nikto gobuster ffuf whatweb dirb wfuzz wafw00f wapiti \
    skipfish davtest cadaver joomscan dmitry \
    tcpdump wireshark tshark ngrep netsniff-ng arp-scan netdiscover masscan \
    p0f hping3 fping ike-scan dsniff ettercap-text-only bettercap mitmproxy \
    socat proxychains4 redsocks iodine dns2tcp \
    john hydra medusa ncrack patator crunch cewl fcrackzip pdfcrack \
    hashcat hashcat-data hash-identifier chntpw \
    aircrack-ng wifite reaver pixiewps kismet cowpatty mdk3 mdk4 hcxtools \
    hcxdumptool macchanger \
    binwalk foremost scalpel sleuthkit steghide libimage-exiftool-perl \
    gdb ltrace radare2 \
    dnsenum dnsmap dnsrecon dnstracer dnswalk fierce theharvester recon-ng \
    metagoofil commix \
    enum4linux crackmapexec responder python3-impacket seclists \
    smbclient smbmap onesixtyone snmpcheck sipvicious \
    whois dnsutils curl wget git jq \
    net-tools inetutils-traceroute netmask lynis nbtscan

# -----------------------------
# PIP-BASED SECURITY TOOLS
# -----------------------------
log "installing pip-based security tools..."
pip_install \
    dirsearch \
    enum4linux-ng \
    scoutsuite \
    certipy-ad \
    droopescan \
    arjun \
    pwntools \
    scapy \
    oletools \
    instaloader \
    volatility3 \
    name-that-hash

# -----------------------------
# GO
# -----------------------------
log "installing Go (latest upstream)..."
if ! command -v go &>/dev/null; then
    GO_VER=$(curl -s https://go.dev/VERSION?m=text | head -1)
    curl -sL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
else
    log "skipping Go (already installed)"
fi
export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
export GOPATH="$HOME/go"

# -----------------------------
# GO SECURITY TOOLS (full set, matches darbs.sh)
# -----------------------------
log "installing Go security tools..."
go_install github.com/tomnomnom/waybackurls@latest
go_install github.com/tomnomnom/httprobe@latest
go_install github.com/tomnomnom/gf@latest
go_install github.com/tomnomnom/assetfinder@latest
go_install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go_install github.com/projectdiscovery/katana/cmd/katana@latest
go_install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go_install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go_install github.com/projectdiscovery/httpx/cmd/httpx@latest
go_install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go_install github.com/hahwul/dalfox/v2@latest
go_install github.com/s0md3v/smap/cmd/smap@latest
go_install github.com/sensepost/gowitness@latest
go_install github.com/haccer/subjack@latest
go_install github.com/jpillora/chisel@latest
go_install github.com/nicocha30/ligolo-ng/cmd/proxy@latest
go_install github.com/ropnop/kerbrute@latest

# gf patterns
mkdir -p "$HOME/.gf"
if [ -z "$(ls -A "$HOME/.gf" 2>/dev/null)" ]; then
    git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null \
        && cp /tmp/gf-patterns/*.json "$HOME/.gf/" && rm -rf /tmp/gf-patterns
fi

# ensure go + local bin on PATH for future shells
if ! grep -q '/usr/local/go/bin' "$HOME/.bashrc"; then
    echo 'export GOPATH=$HOME/go' >> "$HOME/.bashrc"
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin' >> "$HOME/.bashrc"
fi

# -----------------------------
# BIG FRAMEWORKS / UPSTREAM INSTALLERS
# -----------------------------
# amass
log "installing amass..."
if ! command -v amass &>/dev/null; then
    AMASS_VER=$(curl -s https://api.github.com/repos/owasp-amass/amass/releases/latest | grep -m1 tag_name | cut -d '"' -f 4)
    if [ -n "$AMASS_VER" ]; then
        curl -sL "https://github.com/owasp-amass/amass/releases/download/${AMASS_VER}/amass_Linux_amd64.zip" -o /tmp/amass.zip
        unzip -o /tmp/amass.zip -d /tmp/amass && sudo cp /tmp/amass/amass_Linux_amd64/amass /usr/local/bin/
        rm -rf /tmp/amass /tmp/amass.zip
    fi
fi

# metasploit
log "installing Metasploit Framework..."
if ! command -v msfconsole &>/dev/null; then
    curl -sL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod +x /tmp/msfinstall && sudo /tmp/msfinstall && rm -f /tmp/msfinstall
fi

# exploitdb / searchsploit (not in Debian main -- pull from upstream git)
log "installing exploitdb (searchsploit)..."
if ! command -v searchsploit &>/dev/null; then
    sudo git clone --depth 1 https://gitlab.com/exploit-database/exploitdb.git /opt/exploitdb 2>/dev/null \
        && sudo ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit \
        || echo "manual: exploitdb" >> "$FAILLOG"
fi

# ghidra
log "installing Ghidra..."
if ! command -v ghidra &>/dev/null && [ ! -d /opt/ghidra ]; then
    apt_install default-jdk
    GHIDRA_URL=$(curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest | grep -m1 'browser_download_url' | grep '.zip"' | cut -d '"' -f 4)
    if [ -n "$GHIDRA_URL" ]; then
        curl -sL "$GHIDRA_URL" -o /tmp/ghidra.zip && sudo unzip -o /tmp/ghidra.zip -d /opt/ \
            && sudo ln -sf /opt/ghidra*/ghidraRun /usr/local/bin/ghidra && rm -f /tmp/ghidra.zip
    fi
fi

# nuclei templates
command -v nuclei &>/dev/null && nuclei -update-templates 2>/dev/null || true

# tools with no clean Debian/pure-FOSS path -- logged so they are on the radar
for note in "burpsuite (portswigger.net/burp)" "bloodhound (github.com/SpecterOps/BloodHound, docker)" \
            "maltego (maltego.com)" "empire (github.com/BC-SECURITY/Empire)" \
            "evil-winrm (gem install evil-winrm)" "beef-xss (github.com/beefproject/beef)"; do
    echo "manual: $note" >> "$FAILLOG"
done
log "manual-install tools noted in $FAILLOG (burp, bloodhound, maltego, empire, evil-winrm, beef)"

# zaproxy
log "installing OWASP ZAP..."
apt_install zaproxy
command -v zaproxy &>/dev/null || echo "manual: zaproxy (snap install zaproxy)" >> "$FAILLOG"

# -----------------------------
# DESKTOP / PRODUCTIVITY
# -----------------------------
log "installing desktop + productivity apps..."
apt_install \
    keepassxc libreoffice inkscape gimp flameshot copyq redshift \
    calcurse qalculate-gtk rhythmbox gnucash peek neovim ranger \
    btop htop bat fd-find ripgrep fzf ncdu

# obsidian (not in apt) -- snap if available, else note
if ! command -v obsidian &>/dev/null; then
    if command -v snap &>/dev/null; then
        sudo snap install obsidian --classic 2>/dev/null || echo "manual: obsidian (obsidian.md)" >> "$FAILLOG"
    else
        echo "manual: obsidian (obsidian.md)" >> "$FAILLOG"
    fi
fi

# vscodium (own apt repo)
log "installing VSCodium..."
if ! command -v codium &>/dev/null; then
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
        | sudo tee /etc/apt/sources.list.d/vscodium.list > /dev/null
    sudo apt-get update -y && sudo apt-get install -y codium || echo "manual: codium" >> "$FAILLOG"
fi

# drawio (.deb from GitHub releases)
if ! command -v drawio &>/dev/null; then
    DRAWIO_URL=$(curl -s https://api.github.com/repos/jgraph/drawio-desktop/releases/latest | grep -m1 'browser_download_url' | grep 'amd64.deb"' | cut -d '"' -f 4)
    if [ -n "$DRAWIO_URL" ]; then
        curl -sL "$DRAWIO_URL" -o /tmp/drawio.deb && sudo apt-get install -y /tmp/drawio.deb && rm -f /tmp/drawio.deb \
            || echo "manual: drawio" >> "$FAILLOG"
    fi
fi

# -----------------------------
# FINISH
# -----------------------------
log "DARBS Debian (Full) installation complete!"
if [ -s "$FAILLOG" ]; then
    warn "some tools could not be installed automatically -- review $FAILLOG:"
    sed 's/^/    /' "$FAILLOG"
fi

echo -e "${BLUE}"
echo "====================================="
echo " DONE! Full install complete."
echo " Reboot into XFCE."
echo "====================================="
echo -e "${RESET}"
