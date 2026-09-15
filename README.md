# ZimMux

A one-file tmux theme with a calm, high-contrast palette and Alt-key bindings that stay out of your way — inspired by [herdr.dev](https://herdr.dev)'s Ink.

![ZimMux preview](assets/preview.png)

> The preview image lives at `assets/preview.png`. See [`assets/README.md`](assets/README.md) if it isn't rendering yet.

## Features

- **One file.** The entire theme is a single `tmux.conf`. No plugin manager, no TPM, no dependencies.
- **Palette-first.** Every colour is a named token in one block at the top of the file, so retheming is a find-and-replace rather than a hunt.
- **Alt-key bindings.** Pane and window navigation without a prefix chord — `Alt+ijkl` moves, the rest is muscle memory.
- **Mouse-native.** Click to focus a pane, drag to resize, wheel to scroll history.
- **Quiet status bar.** Reads as part of the terminal, not a separate chrome layer.
- **Reversible install.** `install.sh` backs up your existing config before touching anything.

## Palette

| Token | Hex | Used for |
| --- | --- | --- |
| `ground` | `#17171A` | Terminal / status background |
| `panel` | `#26262B` | Inactive pane and status segments |
| `edge` | `#3a3a41` | Pane borders, separators |
| `ink` | `#eae8ee` | Primary text |
| `dim` | `#cdccd2` | Secondary text |
| `faint` | `#8a8891` | Inactive / tertiary text |
| `accent` | `#cba6f7` | Active border, highlights (lavender) |
| `green` | `#5fae74` | Attached, success |
| `yellow` | `#d3a027` | Bell, warning |
| `red` | `#c73e3e` | Activity, error |
| `teal` | `#94e2d5` | Copy mode, selection |
| `muted` | `#55534a` | Disabled, inactive marks |

## Install

```sh
git clone https://github.com/<your-username>/ZimMux.git
cd ZimMux
./install.sh
```

`install.sh` **symlinks** this repo's `tmux.conf` to `~/.config/tmux/tmux.conf` — it does not copy it, so `git pull` updates your live theme. An existing config is backed up first and the backup path is printed. Re-running the installer is a no-op when the symlink already points here.

Reload an already-running server with:

```sh
tmux source-file ~/.config/tmux/tmux.conf
```

or press `prefix` then `r`. To check the theme loaded correctly without starting a session:

```sh
./tests/verify.sh
```

**Overrides.** `TMUX_CONF_TARGET` changes where the symlink lands; `TMUX_BACKUP_DIR` changes where backups go.

**Truecolor.** The palette is 24-bit hex, so it needs a truecolor terminal (kitty, iTerm2, Windows Terminal, Alacritty, …). On a 256-colour terminal the theme still loads, but the colours will be approximated.

## Keybindings

| Key | Action |
| --- | --- |
| `Alt+i` / `Alt+k` | Pane up / down |
| `Alt+j` / `Alt+l` | Pane left / right |
| `Alt+n` | New pane |
| `Alt+w` | Close pane |
| `Alt+o` | Cycle layout |
| `Alt+g` | Mark pane |
| `Alt+y` | Swap with marked pane |
| `Alt+m` | New window |
| `Alt+u` | Next window |
| `Alt+h` | Previous window |
| `Alt+Tab` | Scroll mode |
| `prefix` `r` | Reload config |
| Mouse click / drag / wheel | Focus pane / resize / scroll |

> **Terminal note.** Alt bindings require the terminal to send Meta. On macOS Terminal and iTerm2, enable *Use Option as Meta key*. On some terminals `Alt+Tab` is captured by the window manager — see [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) if it doesn't reach tmux.
>
> **`Alt+h` is previous-window, not pane-left.** Pane navigation is `Alt+i/j/k/l` (up/left/down/right), which is *not* vim's `hjkl` — `Alt+j` moves left, not down. If you have vim muscle memory, expect to reach for `Alt+h` and get a window switch instead. Remap in [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) if that trade isn't worth it.

## Customization

The whole theme is meant to be edited. [`docs/CUSTOMIZATION.md`](docs/CUSTOMIZATION.md) covers:

- changing the accent colour
- moving the status bar to the top of the screen
- a sketch of a **Paper** light variant

## Uninstall / restore

Your original config was never deleted — `install.sh` copied it to a timestamped backup and printed the path. Backups land in `~/.agent-mux/backups/` if that tree exists, otherwise `~/.config/tmux/backups/` (override with `TMUX_BACKUP_DIR`).

```sh
rm ~/.config/tmux/tmux.conf
cp ~/.agent-mux/backups/tmux.conf.<timestamp>.bak ~/.config/tmux/tmux.conf
tmux kill-server        # or: tmux source-file ~/.config/tmux/tmux.conf
```

The backup filename carries a timestamp — `tmux.conf.20260916-022732.bak` — so list the directory and pick the one you want. (A second run inside the same second appends `-1`, `-2`, … .)

To remove the theme without restoring anything, delete the symlink and start a fresh server. Deleting the symlink leaves the repo untouched; if you never had a config before installing, there is nothing to restore.

## Credits

Palette and mood inspired by the **Ink** theme at [herdr.dev](https://herdr.dev). Built as a plain `tmux.conf` — no plugin framework, no runtime.

## License

[MIT](LICENSE)
