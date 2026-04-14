#!/bin/bash

################################################################################
#                                                                              #
#  DARBS (Debian) - Kali Top 30 Tools                                         #
#                                                                              #
#  Runs the dotfiles setup first, then installs the top 30 tools from          #
#  Kali Linux on a Debian XFCE system.                                        #
#                                                                              #
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------
# RUN DOTFILES SETUP FIRST
# -----------------------------
bash "$SCRIPT_DIR/darbs-debian-dotfiles.sh"

echo "=== DARBS Debian (Kali Top 30) ==="

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

# -----------------------------
# ADD KALI REPO
# -----------------------------
log "Adding Kali Linux repository..."
if ! grep -q 'kali' /etc/apt/sources.list.d/*.list 2>/dev/null; then
    # import kali archive key
    curl -fsSL https://archive.kali.org/archive-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] https://http.kali.org/kali kali-rolling main non-free non-free-firmware contrib" \
        | sudo tee /etc/apt/sources.list.d/kali.list > /dev/null

    # pin kali packages low so they dont replace debian system packages
    sudo tee /etc/apt/preferences.d/kali-priority > /dev/null <<EOF
Package: *
Pin: release o=Kali
Pin-Priority: 50
EOF

    sudo apt update
else
    log "Kali repo already configured."
fi

# -----------------------------
# KALI TOP 30 TOOLS
# -----------------------------
# These are the tools included in kali-tools-top10 and the most used
# tools by pentesters, matching the "Top 30" from Kali's meta packages.
#
#  1. nmap                    network scanner
#  2. burpsuite               web app proxy (manual install)
#  3. wireshark               packet analyzer
#  4. metasploit-framework    exploitation framework
#  5. aircrack-ng             wifi security
#  6. john                    password cracker
#  7. hashcat                 gpu password cracker
#  8. hydra                   login bruteforcer
#  9. sqlmap                  sql injection
# 10. nikto                   web server scanner
# 11. responder               llmnr/nbt-ns poisoner
# 12. gobuster                directory bruteforcer
# 13. ffuf                    web fuzzer
# 14. wfuzz                   web fuzzer
# 15. ncat                    netcat
# 16. tcpdump                 packet capture
# 17. masscan                 fast port scanner
# 18. crackmapexec            smb/ad toolkit
# 19. impacket                windows protocol toolkit
# 20. ettercap                mitm attacks
# 21. mitmproxy               http proxy
# 22. recon-ng                recon framework
# 23. theharvester            osint emails/subdomains
# 24. maltego                 osint graphing (manual install)
# 25. binwalk                 firmware analysis
# 26. foremost                file carving
# 27. macchanger              mac spoofing
# 28. wifite                  automated wifi attacks
# 29. dnsenum                 dns enumeration
# 30. socat                   multipurpose relay

log "Installing Kali Top 30 tools..."

# tools available in debian repos
apt_install \
    nmap \
    wireshark \
    aircrack-ng \
    john \
    hashcat \
    hydra \
    sqlmap \
    nikto \
    gobuster \
    ffuf \
    wfuzz \
    ncat \
    tcpdump \
    masscan \
    ettercap-text-only \
    mitmproxy \
    recon-ng \
    theharvester \
    binwalk \
    foremost \
    macchanger \
    wifite \
    dnsenum \
    socat

# tools from kali repo (pinned low, install explicitly)
log "Installing tools from Kali repo..."
for pkg in responder crackmapexec python3-impacket seclists; do
    if dpkg -s "$pkg" &>/dev/null; then
        log "Skipping $pkg (already installed)"
    else
        sudo apt install -y -t kali-rolling "$pkg" 2>/dev/null || log "Could not install $pkg from Kali repo, trying Debian..." && apt_install "$pkg"
    fi
done

# metasploit framework
log "Installing Metasploit Framework..."
if ! command -v msfconsole &>/dev/null; then
    curl -sL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod +x /tmp/msfinstall
    sudo /tmp/msfinstall
    rm /tmp/msfinstall
else
    log "Skipping metasploit (already installed)"
fi

# burpsuite
log "Burp Suite Community must be downloaded manually."
log "Visit: https://portswigger.net/burp/communitydownload"

# maltego
log "Maltego must be downloaded manually."
log "Visit: https://www.maltego.com/downloads/"

# -----------------------------
# FINISH
# -----------------------------
log "DARBS Debian (Kali Top 30) installation complete!"
log ""
log "Manual installs needed:"
log "  1. Burp Suite: https://portswigger.net/burp/communitydownload"
log "  2. Maltego:    https://www.maltego.com/downloads/"

echo -e "${BLUE}"
echo "====================================="
echo " DONE! Kali Top 30 installed."
echo " Reboot into XFCE."
echo "====================================="
echo -e "${RESET}"
