# darbs X200 Tablet (Debian i3) keybindings

Every keybinding for the setup installed by `darbs-debian-x200t.sh`.

`Super` is the modifier (the Windows/Meta key). `Caps Lock` is remapped to
`Escape`. Edit `~/.config/i3/config` and press `Super + Shift + c` to reload
after changing anything.

## Tablet

| Keys | Action |
| --- | --- |
| Bezel rotate button (`XF86RotateWindows`) | Rotate screen + pen one step |
| `Super + o` | Rotate screen + pen one step (cycles normal, right, inverted, left) |
| `Super + Shift + o` | Toggle the auto-rotate daemon on/off |
| `Super + F1` | Show/hide the on-screen keyboard (onboard) |

Auto-rotate reads the hdaps accelerometer if this X200t exposes it. Toggle it
off with `Super + Shift + o` when using the machine as a laptop so it does not
rotate while you type.

## Launching programs

| Keys | Action |
| --- | --- |
| `Super + Return` | Terminal (alacritty) |
| `Super + d` | dmenu application launcher |
| `Super + w` | Firefox |
| `Super + r` | File manager (ranger in a terminal) |
| `Super + n` | Xournal++ (handwritten notes / PDF annotation) |
| `Print` | Screenshot (flameshot) |

You can also click the **Whisker menu** on the xfce4-panel to browse and launch
apps with the mouse or pen.

## Terminal zoom (alacritty built-in)

| Keys | Action |
| --- | --- |
| `Ctrl + =` (or `Ctrl + +`) | Zoom in (larger font) |
| `Ctrl + -` | Zoom out (smaller font) |
| `Ctrl + 0` | Reset to default size |

Note: plain `Ctrl`, not `Super`. Permanent size is the `size` value under
`[font]` in `~/.config/alacritty/alacritty.toml`.

## Window focus (vim keys or arrows)

| Keys | Action |
| --- | --- |
| `Super + h / j / k / l` | Focus left / down / up / right |
| `Super + Left / Down / Up / Right` | Focus left / down / up / right |
| `Super + a` | Focus the parent container |
| Mouse hover | Focus follows the pointer (no click needed) |

## Moving windows

| Keys | Action |
| --- | --- |
| `Super + Shift + h / j / k / l` | Move window left / down / up / right |
| `Super + Shift + arrows` | Move window left / down / up / right |
| `Super + drag` | Move a floating window with the mouse/pen |

## Splits (where the next window opens)

| Keys | Action |
| --- | --- |
| `Super + -` or `Super + _` | Split so the next window opens **below** (top/bottom stack) |
| `Super + \` or `Super + \|` | Split so the next window opens to the **right** (side by side) |
| `Super + v` | Vertical split (i3 default, same as `-`) |

## Layout

| Keys | Action |
| --- | --- |
| `Super + f` | Fullscreen toggle |
| `Super + s` | Stacking layout |
| `Super + t` | Tabbed layout |
| `Super + e` | Toggle split orientation |
| `Super + Shift + Space` | Toggle floating on the focused window |
| `Super + Space` | Toggle focus between tiling and floating |

## Resize

| Keys | Action |
| --- | --- |
| `Super + Ctrl + h` | Shrink width |
| `Super + Ctrl + l` | Grow width |
| `Super + Ctrl + k` | Grow height |
| `Super + Ctrl + j` | Shrink height |

## Transparency (focused window, via picom)

| Keys | Action |
| --- | --- |
| `Super + Ctrl + =` | More opaque |
| `Super + Ctrl + -` | More transparent |
| `Super + Ctrl + 0` | Reset opacity |

Global defaults live in `~/.config/picom/picom.conf` (`inactive-opacity` and the
`opacity-rule` lines).

## Workspaces

| Keys | Action |
| --- | --- |
| `Super + 1` .. `Super + 0` | Switch to workspace 1 .. 10 |
| `Super + Shift + 1` .. `Super + Shift + 0` | Move focused window to workspace 1 .. 10 |
| `Super + grave` (`` ` ``) | Show the scratchpad |
| `Super + Shift + grave` | Move focused window to the scratchpad |

## Media and brightness (hardware keys)

| Keys | Action |
| --- | --- |
| Volume Up / Down keys | Volume +/- 5% (via pactl) |
| Mute key | Toggle mute |
| Brightness Up / Down keys | Brightness +/- 10% (via brightnessctl) |

## Session

| Keys | Action |
| --- | --- |
| `Super + q` | Close the focused window |
| `Super + Shift + c` | Reload the i3 config |
| `Super + Shift + r` | Restart i3 in place (keeps windows) |
| `Super + Shift + e` | Exit i3 (log out, with confirm) |
| `Super + x` | Lock the screen (i3lock) |

## The toolbar

The top bar is **xfce4-panel**, not i3bar. Click it with the mouse or pen:
Whisker app menu on the left, a window tasklist, the system tray (network,
etc.), and a clock on the right. Right-click the panel to add or rearrange
items.
