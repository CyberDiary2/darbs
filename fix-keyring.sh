#!/bin/bash
################################################################################
#                                                                              #
#  fix-keyring.sh                                                              #
#                                                                              #
#  Recovery script for Artix (and Arch) when pacman reports:                   #
#    - "signature is unknown trust"                                            #
#    - "invalid or corrupted package (PGP signature)"                          #
#    - "Errors occurred, no packages were upgraded"                            #
#                                                                              #
#  Tries the safe path first, then falls back to a temporary SigLevel=Never    #
#  bypass (only long enough to re-download the keyring packages) and restores  #
#  signature verification afterwards.                                          #
#                                                                              #
#  Run this BEFORE re-running darbs-artix.sh.                                  #
#                                                                              #
################################################################################

set -u

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
RESET="\e[0m"

log()  { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}==> WARNING:${RESET} $1"; }
err()  { echo -e "${RED}==> ERROR:${RESET} $1"; }
info() { echo -e "${BLUE}==>${RESET} $1"; }

if [ "$(id -u)" -eq 0 ]; then
    err "Run this as your normal user (it uses sudo internally)."
    exit 1
fi

# -----------------------------
# SANITY CHECKS
# -----------------------------
info "Clock: $(date)"
NOW_YEAR="$(date +%Y)"
if [ "$NOW_YEAR" -lt 2024 ] || [ "$NOW_YEAR" -gt 2100 ]; then
    err "System clock is wrong — fix it first, GPG will reject keys otherwise:"
    echo "  sudo ntpd -q -p pool.ntp.org"
    echo "  # or"
    echo "  sudo date -s 'YYYY-MM-DD HH:MM:SS'"
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    err "pacman not found. Is this Arch/Artix?"
    exit 1
fi

if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    warn "No internet reachable. Keyserver / mirror refresh will fail."
fi

# -----------------------------
# STEP 1: KILL STUCK GPG PROCESSES
# -----------------------------
log "Killing any stuck gpg-agent / dirmngr processes..."
sudo killall gpg-agent dirmngr gpg 2>/dev/null || true
sleep 1

# -----------------------------
# STEP 2: CLEAN CACHE OF CORRUPTED PACKAGES
# -----------------------------
log "Clearing pacman cache of potentially corrupted packages..."
sudo pacman -Scc --noconfirm 2>/dev/null || true

# -----------------------------
# STEP 3: WIPE AND REINIT KEYRING
# -----------------------------
log "Wiping and re-initializing pacman keyring..."
sudo rm -rf /etc/pacman.d/gnupg
sudo pacman-key --init

# -----------------------------
# STEP 4: TRY SAFE PATH FIRST
# (populate from on-disk keyring pkgs and refresh from keyserver)
# -----------------------------
log "Attempting safe recovery: populate from existing keyring packages..."
sudo pacman-key --populate artix 2>/dev/null || true
if [ -f /usr/share/pacman/keyrings/archlinux.gpg ]; then
    sudo pacman-key --populate archlinux 2>/dev/null || true
fi

log "Refreshing keys from keyserver (this can take several minutes)..."
if sudo timeout 300 pacman-key --refresh-keys; then
    log "Keys refreshed. Trying pacman -Syy..."
    if sudo pacman -Syy --noconfirm && \
       sudo pacman -S --needed --noconfirm archlinux-keyring artix-keyring 2>/dev/null; then
        log "Safe path worked. Re-running full populate..."
        sudo pacman-key --populate artix
        [ -f /usr/share/pacman/keyrings/archlinux.gpg ] && sudo pacman-key --populate archlinux
        sudo pacman -Syyu --noconfirm
        log "Keyring recovered. You can now rerun darbs-artix.sh."
        exit 0
    fi
    warn "Safe path populate succeeded but -Syy / upgrade still failed."
else
    warn "--refresh-keys failed or timed out. Falling back to SigLevel bypass."
fi

# -----------------------------
# STEP 5: FALLBACK — TEMPORARY SIGLEVEL BYPASS
# -----------------------------
warn "About to temporarily disable package signature verification to reinstall"
warn "the keyring packages. This is a well-known Arch recovery procedure."
warn "Signing will be restored immediately after the keyring packages install."
echo
read -r -p "Continue? [y/N] " confirm
case "$confirm" in
    [yY]*) : ;;
    *) info "Aborting. Your keyring is untouched. Investigate manually."; exit 1 ;;
esac

log "Backing up /etc/pacman.conf to /etc/pacman.conf.fixkeyring.bak..."
sudo cp /etc/pacman.conf /etc/pacman.conf.fixkeyring.bak

log "Disabling SigLevel verification temporarily..."
sudo sed -i 's/^SigLevel.*=.*/SigLevel = Never/' /etc/pacman.conf

log "Refreshing mirrors + reinstalling keyring packages (unsigned)..."
if ! sudo pacman -Syy --noconfirm; then
    err "pacman -Syy still failed even with SigLevel=Never. Check:"
    echo "  - Is a mirror reachable?  ping archlinux.org"
    echo "  - Is a closer mirror in /etc/pacman.d/mirrorlist?"
    log "Restoring /etc/pacman.conf..."
    sudo cp /etc/pacman.conf.fixkeyring.bak /etc/pacman.conf
    exit 1
fi

if ! sudo pacman -S --noconfirm archlinux-keyring artix-keyring; then
    err "Could not reinstall keyring packages."
    log "Restoring /etc/pacman.conf..."
    sudo cp /etc/pacman.conf.fixkeyring.bak /etc/pacman.conf
    exit 1
fi

log "Restoring /etc/pacman.conf (signing re-enabled)..."
sudo cp /etc/pacman.conf.fixkeyring.bak /etc/pacman.conf

log "Re-initializing keyring with fresh keyring packages..."
sudo rm -rf /etc/pacman.d/gnupg
sudo pacman-key --init
sudo pacman-key --populate artix
if [ -f /usr/share/pacman/keyrings/archlinux.gpg ]; then
    sudo pacman-key --populate archlinux
fi

log "Running full system upgrade to confirm signatures verify..."
if sudo pacman -Syyu --noconfirm; then
    log "Keyring fully recovered. You can now rerun darbs-artix.sh."
    exit 0
else
    err "Upgrade still failing. Paste the error to get further help."
    exit 1
fi
