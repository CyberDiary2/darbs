# darbs dwm keybindings (LARBS)

The Artix darbs build installs Luke Smith's LARBS suckless suite (dwm + st + dmenu +
dwmblocks) as a session you can pick next to XFCE. These are the keybindings that ship
in Luke's `dwm/config.h`, exactly as compiled by `darbs-artix.sh`.

`Super` is the modifier key (the Windows / Meta key). Every binding below uses it unless
noted. `Caps Lock` is remapped to `Escape` in the dwm session.

## darbs integration notes

- **Choosing the session:** at the LightDM login screen, click the session menu and pick
  `dwm` (or `Xfce Session` to go back). Nothing about XFCE changes.
- **Colors:** dwm and st read the darbs Everforest palette from
  `~/.config/x11/xresources`. `Super + F5` reloads it live after an edit.
- **Terminal is `st`, launcher is `dmenu`, file manager is `lfub` (lf).**
- **Edit keybindings:** they live in `~/.dotfiles/dwm/config.h`. After editing, rebuild:
  `cd ~/.dotfiles/dwm && sudo make install`, then log out and back in (or restart dwm
  with `Super + F12` remap if bound).

## Essentials

| Keys | Action |
| --- | --- |
| `Super + Return` | Open terminal (st) |
| `Super + Shift + Return` | Toggle dropdown/scratchpad terminal |
| `Super + d` | dmenu application launcher |
| `Super + w` | Open browser |
| `Super + q` | Close focused window |
| `Super + Shift + q` | System menu (shutdown / reboot / logout / lock) |
| `Super + BackSpace` | System menu (same as above) |
| `Super + b` | Toggle the status bar |
| `Super + F5` | Reload colors from xresources (darbs palette) |

## Focus and moving windows

| Keys | Action |
| --- | --- |
| `Super + j` | Focus next window in the stack |
| `Super + k` | Focus previous window in the stack |
| `Super + v` | Focus the master window |
| `Super + Shift + j` | Move focused window down the stack |
| `Super + Shift + k` | Move focused window up the stack |
| `Super + Shift + v` | Move focused window to master |
| `Super + space` | Promote focused window to master (zoom) |
| `Super + Shift + space` | Toggle floating for focused window |
| `Super + Left` / `Super + Right` | Focus previous / next monitor |
| `Super + Shift + Left` / `Right` | Send focused window to previous / next monitor |

## Master area and resizing

| Keys | Action |
| --- | --- |
| `Super + h` | Shrink master area |
| `Super + l` | Grow master area |
| `Super + o` | Increase number of master windows |
| `Super + Shift + o` | Decrease number of master windows |

## Layouts

| Keys | Layout |
| --- | --- |
| `Super + t` | Tile (default) |
| `Super + Shift + t` | Bottom stack |
| `Super + y` | Spiral (fibonacci) |
| `Super + Shift + y` | Dwindle |
| `Super + u` | Deck |
| `Super + Shift + u` | Monocle (stacked full) |
| `Super + i` | Centered master |
| `Super + Shift + i` | Centered floating master |
| `Super + f` | Toggle fullscreen |
| `Super + Shift + f` | Floating layout |

## Gaps

| Keys | Action |
| --- | --- |
| `Super + a` | Toggle gaps on/off |
| `Super + Shift + a` | Reset gaps to default |
| `Super + z` | Increase gaps |
| `Super + x` | Decrease gaps |
| `Super + Shift + '` | Toggle smart gaps (no gaps when only one window) |

## Tags (workspaces 1-9)

Tags are dwm's workspaces. A window can live on more than one tag.

| Keys | Action |
| --- | --- |
| `Super + 1..9` | View tag N |
| `Super + Shift + 1..9` | Send focused window to tag N |
| `Super + Ctrl + 1..9` | Toggle tag N into the current view (overlay) |
| `Super + Ctrl + Shift + 1..9` | Add/remove focused window from tag N |
| `Super + 0` | View all tags at once |
| `Super + Shift + 0` | Put focused window on all tags |
| `Super + Tab` | Jump back to the last-viewed tag |
| `Super + g` / `Super + ;` | View the previous / next tag |
| `Super + Shift + g` / `Super + Shift + ;` | Send window to previous / next tag |
| `Super + Page_Up` / `Page_Down` | View previous / next tag |
| `Super + s` | Toggle sticky (window shows on every tag) |

## Scratchpads

| Keys | Action |
| --- | --- |
| `Super + Shift + Return` | Toggle scratchpad terminal 0 |
| `Super + '` | Toggle scratchpad 1 |

## Volume and media

Volume uses PipeWire (`wpctl`); music control uses mpd (`mpc`). These need those programs
installed (see Dependencies).

| Keys | Action |
| --- | --- |
| `Super + =` | Volume up 5% (`Super + Shift + =` for 15%) |
| `Super + -` | Volume down 5% (`Super + Shift + -` for 15%) |
| `Super + Shift + m` | Mute toggle |
| `Super + p` | Play / pause music |
| `Super + comma` / `Super + period` | Previous / next track |
| `Super + [` / `Super + ]` | Seek music back / forward 10s (Shift = 60s) |
| `Super + m` | Open ncmpcpp music player |
| Media keys | Standard XF86 volume, play/pause, next/prev, brightness |

## Screenshots and screen recording

| Keys | Action |
| --- | --- |
| `Print` | Screenshot whole screen to a file |
| `Shift + Print` | Screenshot menu (select area / window / screen) |
| `Super + Print` | Start a screen recording (dmenurecord) |
| `Super + Shift + Print` / `Super + Delete` | Stop the recording |
| `Super + Scroll_Lock` | Toggle on-screen keystroke display (screenkey) |

## Apps and utilities

Many of these launch programs that darbs does not install by default (see Dependencies).

| Keys | Action |
| --- | --- |
| `Super + r` | File manager (lfub) |
| `Super + Shift + r` | htop (process monitor) |
| `Super + Shift + w` | nmtui (Wi-Fi / network) |
| `Super + e` | neomutt (email) |
| `Super + Shift + e` | abook (address book) |
| `Super + n` | nvim vimwiki index |
| `Super + Shift + n` | newsboat (RSS reader) |
| `Super + c` | profanity (XMPP chat) |
| `Super + Shift + d` | passmenu (password store) |
| `Super + grave` (`` ` ``) | Emoji / unicode picker |
| `Super + Insert` | Paste a saved text snippet via dmenu |

## Function keys

| Keys | Action |
| --- | --- |
| `Super + F1` | Open the LARBS help document |
| `Super + F2` | Tutorial videos |
| `Super + F3` | Display / monitor layout selector |
| `Super + F4` | pulsemixer (audio mixer) |
| `Super + F5` | Reload xresources colors |
| `Super + F6` | Toggle Tor |
| `Super + F7` | Toggle transmission daemon |
| `Super + F8` | Sync mail |
| `Super + F9` | Mount a drive (dmenu) |
| `Super + F10` | Unmount a drive (dmenu) |
| `Super + F11` | Show webcam |
| `Super + F12` | Reload keyboard remaps |

## Mouse (LARBS defaults)

| Action | Result |
| --- | --- |
| `Super + Left-drag` | Move a window (makes it floating) |
| `Super + Right-drag` | Resize a window |
| `Super + Middle-click` | Toggle floating on the window |
| Click a tag in the bar | View that tag |
| `Super + Click` a tag | Send focused window to that tag |
| Scroll on the bar | Cycle through tags |

## Dependencies

The core window manager works out of the box: window navigation, layouts, tags, gaps,
`st` terminal, `dmenu`, `lfub` file manager, screenshots (`maim`), and the status bar.
The darbs Artix script installs these plus the LARBS helper scripts from voidrice.

Some bindings call programs that darbs does not install. They simply do nothing until you
install the program:

- Volume/mute keys need **pipewire + wireplumber** (`wpctl`).
- Music keys (`Super + p/m/comma/period/[/]`) need **mpd + mpc** and **ncmpcpp**.
- `Super + e` / `Super + Shift + e` need **neomutt** / **abook**.
- `Super + n` / `Super + Shift + n` need **neovim (+vimwiki)** / **newsboat**.
- `Super + c` needs **profanity**; `Super + Shift + d` needs **pass**.
- `Super + F6/F7` need **tor** / **transmission**.

To see or change the exact bindings, read `~/.dotfiles/dwm/config.h` (the `keys[]` array),
edit, then `cd ~/.dotfiles/dwm && sudo make install` and re-log in.
