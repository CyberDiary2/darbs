#!/bin/bash

################################################################################
#                                                                              #
#  DARBS (Debian) - Full Install                                               #
#                                                                              #
#  Runs the dotfiles setup first, then installs bug bounty and security        #
#  tools on top. This is the complete Debian equivalent of darbs.sh.           #
#                                                                              #
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------
# RUN DOTFILES SETUP FIRST
# -----------------------------
bash "$SCRIPT_DIR/darbs-debian-dotfiles.sh"

echo "=== DARBS Debian (Full) - Installing security tools ==="

LOGFILE="$HOME/darbs.log"
exec > >(tee -a "$LOGFILE") 2>&1

GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"

log() { echo -e "${GREEN}==>${RESET} $1"; }

apt_install() {
    local to_install=()
    for pkg in "$@"; do
        if dpkg -s "$pkg" &>/dev/null; then
            log "Skipping $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        sudo apt install -y "${to_install[@]}"
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

# -----------------------------
# SECURITY TOOLS (from Debian repos)
# -----------------------------
log "Installing security tools from Debian repos..."
apt_install \
    nmap \
    sqlmap \
    nikto \
    gobuster \
    ffuf \
    whatweb \
    dirb \
    wfuzz \
    tcpdump \
    wireshark \
    hydra \
    masscan \
    ncat \
    john \
    hashcat \
    mitmproxy \
    theharvester \
    recon-ng \
    responder \
    crackmapexec \
    python3-impacket \
    seclists \
    aircrack-ng \
    ettercap-text-only \
    kismet \
    binwalk \
    macchanger \
    dnsenum \
    cewl \
    wifite \
    reaver \
    foremost \
    socat \
    enum4linux \
    commix \
    massdns \
    chromium

# -----------------------------
# TOOLS NOT IN DEBIAN REPOS
# -----------------------------
# These need manual install or pip

log "Installing pip based security tools..."
pip3 install --user --break-system-packages dirsearch 2>/dev/null || pip3 install --user dirsearch

# amass
log "Installing amass..."
if ! command -v amass &>/dev/null; then
    AMASS_VER=$(curl -s https://api.github.com/repos/owasp-amass/amass/releases/latest | grep tag_name | cut -d '"' -f 4)
    if [ -n "$AMASS_VER" ]; then
        curl -sL "https://github.com/owasp-amass/amass/releases/download/${AMASS_VER}/amass_Linux_amd64.zip" -o /tmp/amass.zip
        unzip -o /tmp/amass.zip -d /tmp/amass
        sudo cp /tmp/amass/amass_Linux_amd64/amass /usr/local/bin/
        rm -rf /tmp/amass /tmp/amass.zip
    fi
else
    log "Skipping amass (already installed)"
fi

# burpsuite (community)
log "Installing Burp Suite Community..."
if ! command -v burpsuite &>/dev/null && [ ! -f /opt/BurpSuiteCommunity/BurpSuiteCommunity ]; then
    log "Burp Suite must be downloaded manually from portswigger.net"
    log "Visit: https://portswigger.net/burp/communitydownload"
else
    log "Skipping Burp Suite (already installed)"
fi

# metasploit
log "Installing Metasploit Framework..."
if ! command -v msfconsole &>/dev/null; then
    curl -sL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod +x /tmp/msfinstall
    sudo /tmp/msfinstall
    rm /tmp/msfinstall
else
    log "Skipping metasploit (already installed)"
fi

# zaproxy
log "Installing OWASP ZAP..."
if ! command -v zaproxy &>/dev/null && ! command -v zap &>/dev/null; then
    sudo snap install zaproxy --classic 2>/dev/null || log "ZAP: install snap or download from zaproxy.org"
else
    log "Skipping ZAP (already installed)"
fi

# -----------------------------
# INSTALL GO
# -----------------------------
log "Installing Go..."
if ! command -v go &>/dev/null; then
    GO_VER=$(curl -s https://go.dev/VERSION?m=text | head -1)
    curl -sL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
else
    log "Skipping Go (already installed)"
fi

export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
export GOPATH="$HOME/go"

# -----------------------------
# GO SECURITY TOOLS
# -----------------------------
log "Installing Go security tools..."

go_install github.com/tomnomnom/waybackurls@latest
go_install github.com/tomnomnom/httprobe@latest
go_install github.com/tomnomnom/gf@latest
go_install github.com/tomnomnom/assetfinder@latest
go_install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go_install github.com/projectdiscovery/katana/cmd/katana@latest
go_install github.com/hahwul/dalfox/v2@latest
go_install github.com/s0md3v/smap/cmd/smap@latest
go_install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go_install github.com/sensepost/gowitness@latest
go_install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go_install github.com/projectdiscovery/httpx/cmd/httpx@latest
go_install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# gf patterns
mkdir -p "$HOME/.gf"
if [ ! "$(ls -A "$HOME/.gf" 2>/dev/null)" ]; then
    git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null && \
        cp /tmp/gf-patterns/*.json "$HOME/.gf/" && \
        rm -rf /tmp/gf-patterns
fi

# Add go to path in bashrc
if ! grep -q '/usr/local/go/bin' "$HOME/.bashrc"; then
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin' >> "$HOME/.bashrc"
fi

# -----------------------------
# EXTRA DEBIAN PACKAGES
# -----------------------------
log "Installing additional tools..."
apt_install \
    obsidian 2>/dev/null || true

# vscodium
log "Installing VSCodium..."
if ! command -v codium &>/dev/null; then
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor \
        | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
        | sudo tee /etc/apt/sources.list.d/vscodium.list > /dev/null
    sudo apt update
    sudo apt install -y codium
else
    log "Skipping VSCodium (already installed)"
fi

# ghidra
log "Installing Ghidra..."
if ! command -v ghidra &>/dev/null && [ ! -d /opt/ghidra ]; then
    apt_install default-jdk
    GHIDRA_VER=$(curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest | grep tag_name | cut -d '"' -f 4)
    if [ -n "$GHIDRA_VER" ]; then
        GHIDRA_URL=$(curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest | grep browser_download_url | grep '.zip"' | head -1 | cut -d '"' -f 4)
        if [ -n "$GHIDRA_URL" ]; then
            curl -sL "$GHIDRA_URL" -o /tmp/ghidra.zip
            sudo unzip -o /tmp/ghidra.zip -d /opt/
            sudo ln -sf /opt/ghidra*/ghidraRun /usr/local/bin/ghidra
            rm /tmp/ghidra.zip
        fi
    fi
else
    log "Skipping Ghidra (already installed)"
fi

# -----------------------------
# FINISH
# -----------------------------
log "DARBS Debian (Full) installation complete!"

echo -e "${BLUE}"
echo "====================================="
echo " DONE! Full install complete."
echo " Reboot into XFCE."
echo "====================================="
echo -e "${RESET}"
