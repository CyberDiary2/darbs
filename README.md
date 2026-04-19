# darbs


```

██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║███████║██████╔╝██████╔╝███████╗
██║  ██║██╔══██║██╔══██╗██╔══██╗╚════██║
██████╔╝██║  ██║██║  ██║██████╔╝███████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝

```



### Drew's Auto-Rice Bug Bounty Bootstrapping Scripts

I stole this idea from Luke Smith's LARBS.

This is an automatic rice and bootstrapping scripts program that auto configures a fresh arch install with xfce4, some bug bounty tools, and productivity tools.

The terminal color scheme is based on the "moss" theme I like using when taking notes in obsidian. 

### How to run

```bash
git clone https://github.com/CyberDiary2/darbs.git
cd darbs
chmod +x darbs.sh
./darbs.sh
```

Run on a fresh Arch install. Reboot when it finishes.

Already-installed packages and tools are detected and skipped, so re-running the script is safe.

If the batch pacman or yay install fails (one missing package in the group), the script automatically retries each package individually and logs the ones that couldn't be installed instead of aborting.

### Artix variant

`darbs-artix.sh` is the systemd-free variant. It auto-detects whether the host runs openrc, runit, s6, or dinit and installs the matching init-specific packages (`networkmanager-$INIT`, `lightdm-$INIT`, `bluez-$INIT`, `cups-$INIT`, `tlp-$INIT`, `docker-$INIT`) and enables services through the matching tool (`rc-update`, `sv`, `s6-rc`, `dinitctl`).

```bash
chmod +x darbs-artix.sh
./darbs-artix.sh
```

In addition to everything in the main list, `darbs-artix.sh` also installs:

**Audio**: pipewire, pipewire-pulse, pipewire-alsa, pipewire-jack, wireplumber, pavucontrol, alsa-utils  
**Bluetooth**: bluez, bluez-utils, blueman  
**Printing**: cups, cups-pdf, system-config-printer, ghostscript  
**Fonts**: noto-fonts, noto-fonts-emoji, noto-fonts-cjk, ttf-dejavu, ttf-liberation, ttf-hack  
**Archive**: p7zip, unrar, file-roller, thunar-archive-plugin  
**Media**: mpv, vlc, imv, zathura, zathura-pdf-mupdf  
**Power / network tray**: tlp, xfce4-power-manager, network-manager-applet  
**CPU microcode**: auto-detects intel-ucode or amd-ucode from /proc/cpuinfo  
**Dev / QoL**: nodejs, npm, rustup (auto-runs `rustup default stable`), zoxide, lazygit, starship, docker, docker-compose (user added to docker group)  
**Extra security**: wpscan, feroxbuster, arjun, sublist3r, trufflehog, gitleaks, sherlock, nuclei-templates  
**Extra Go tools**: gau, hakrawler, interactsh-client, notify, shuffledns, chaos



### Core
xorg  
xfce4 xfce4-goodies  
xfce4-terminal  
xfce4-whiskermenu-plugin  
lightdm lightdm-gtk-greeter  
networkmanager  
bash-completion  
tmux  
wmctrl  
git  
curl  
wget  
unzip  
zip  
neovim  
htop  
tree  
rsync  
which  
base-devel  
firefox  
fastfetch  
go  
python  
python-pip  
btop  

### Bug Bounty / Security
nmap  
burpsuite  
sqlmap  
nikto  
gobuster  
ffuf  
amass  
whatweb  
dirsearch  
wfuzz  
tcpdump  
wireshark-qt  
metasploit  
hydra  
masscan  
openbsd-netcat  
chromium  
john  
hashcat  
mitmproxy  
zaproxy  
theharvester  
recon-ng  
responder  
crackmapexec  
impacket  
seclists  
frida  
objection  
commix  
enum4linux-ng  
massdns  
aircrack-ng  
ettercap  
kismet  
binwalk  
autopsy  
volatility3  
bloodhound  
bettercap  
macchanger  
maltego  
exploitdb  
dnsenum  
searchsploit  
dirb  
cewl  
wifite  
reaver  
foremost  
socat  
ghidra  
beef-xss  

### Go Tools
waybackurls  
httprobe  
gf  
assetfinder  
subfinder  
katana  
dalfox  
smap  
naabu  
gowitness  
dnsx  
httpx  
nuclei  

### Python Tools
xsstrike  
gf-patterns  

### AUR
vscodium-bin  
obsidian  
nuclei  
medusa  
patator  
subjack  
eyewitness  
scout-suite  
planify  
peek  
ttf-jetbrains-mono-nerd  
ghidra  
drawio-desktop-bin  
beef-xss  

### Utilities
ncdu  
ripgrep  
fd  
bat  
jq  
fzf  
lsof  
strace  
bind  
inetutils  
net-tools  
simplescreenrecorder  

### Productivity
libreoffice-fresh  
obsidian  
flameshot  
planify  
peek  
thunderbird  
ranger  
qalculate-gtk  
texlive  
texmaker  
calcurse  
gnucash  
rhythmbox  
caligula  
inkscape  
keepassxc  
copyq  
redshift  
drawio-desktop-bin  

### Ricing / Theming
picom  
papirus-icon-theme  
rofi  
conky  
sassc  
everforest-gtk-theme (cloned from github)  
xfce4-weather-plugin  
xfce4-systemload-plugin  

### Other
lazys3 (nahamsec - cloned from github)  
