# Customization

ZimMux is a plain `tmux.conf`, so everything here is a direct edit. After any
change, reload it:

```sh
tmux source-file ~/.config/tmux/tmux.conf
```

or press `prefix` then `r` if you're inside tmux.

> **Edit the repo file, not the installed path.** `~/.config/tmux/tmux.conf` is a
> **symlink** to `tmux.conf` in this repo. Editing either path edits the same
> file, but edit the one in the repo so your changes are under version control.
> Because it's a symlink rather than a copy, `git pull` updates your live theme
> immediately — there's no re-install step. The installer is idempotent: re-running
> it against a correct symlink does nothing and makes no backup.

## Change the accent colour

The palette is documented as a comment block at the top of `tmux.conf` (around
lines 6–10), but the values are used **inline** throughout the file — there are
no variables to redefine. So changing the accent is a global find-and-replace:

```sh
sed -i 's/#cba6f7/#8839ef/g' tmux.conf   # lavender -> mauve
tmux source-file ~/.config/tmux/tmux.conf
```

`#cba6f7` appears 15 times by design — active pane border, status highlight, the
current-window marker, copy-mode selection, menu borders, and more. Replacing
every occurrence is what you want; replacing one leaves the theme inconsistent.

Two caveats worth knowing before you run it:

- **Don't touch the comment block.** Lines 6–10 are documentation, not
  configuration. `sed` will rewrite them too, which is harmless but leaves the
  header describing a palette the file no longer uses. Either accept that, or
  edit the header afterwards to match.
- **Choose a replacement that works as a *background* too.** Several uses are
  `bg=#cba6f7` with `fg=#17171A` on top (current window, mode line, menu
  selection). A very light accent makes that foreground text unreadable. The
  accent has to clear three bars: legible as text on `ground`, visible as a
  border against `edge`, and dark enough to carry `ground` text as a background.

If you'd rather keep a record of the change, put the `sed` invocation in a small
script next to your dotfiles rather than editing by hand, so you can reapply it
after pulling a newer version of the theme.

### Picking a new accent

Saturated mid-tones work; very dark colours vanish into the border, and very
light ones make the `fg=#17171A` text on accent backgrounds unreadable. Good
starting points:

| Colour | Hex |
| --- | --- |
| Lavender (default) | `#cba6f7` |
| Sky | `#89b4fa` |
| Peach | `#fab387` |
| Rose | `#f38ba8` |
| Sapphire | `#74c7ec` |

## Move the status bar to the top

The theme sets this explicitly, so **edit the existing line** rather than adding
a new one. It's around line 108:

```tmux
set -g status-position bottom   # -> change to: top
```

Verify it took:

```sh
tmux show-options -g status-position
```

The theme's status styling doesn't assume a position, so nothing else needs to
change. The one thing to check is your terminal's own padding — some terminals
inset the first line slightly, which reads as a gap above the bar.

## Paper — a light variant sketch

A starting point, not a finished theme. The dark palette is built on a low-chroma
grey ramp; Paper keeps the same token names and inverts the ramp, so only the
values change.

| Token | Dark | Paper |
| --- | --- | --- |
| `ground` | `#17171A` | `#F0ECE5` |
| `panel` | `#26262B` | `#DDD8CC` |
| `ink` | `#eae8ee` | `#15140f` |
| `accent` | `#cba6f7` | `#8839ef` |
| `edge` | `#3a3a41` | *unchosen* |
| `dim` | `#cdccd2` | *unchosen* |
| `faint` | `#8a8891` | *unchosen* |
| `green` | `#5fae74` | *unchosen* |
| `yellow` | `#d3a027` | *unchosen* |
| `red` | `#c73e3e` | *unchosen* |
| `teal` | `#94e2d5` | *unchosen* |
| `muted` | `#55534a` | *unchosen* |

Apply the four settled values the same way as the accent above:

```sh
sed -i \
  -e 's/#17171A/#F0ECE5/g' \
  -e 's/#26262B/#DDD8CC/g' \
  -e 's/#eae8ee/#15140f/g' \
  -e 's/#cba6f7/#8839ef/g' \
  tmux.conf
tmux source-file ~/.config/tmux/tmux.conf
```

> **Use uppercase hex.** The theme writes every colour in uppercase (`#17171A`),
> and the substitutions above match that. A lowercase pattern like `#f0ece5`
> will silently match nothing — `sed` exits 0 and you'll see no change.

**The gaps are deliberate — the rest don't invert cleanly.** The four values in
the table are the ones that flip predictably. The remaining tokens have to be
*chosen*, not inverted:

- **`edge`** must be *darker* than `ground` on a light background, where on dark
  it is lighter. Around `#c4bdae` reads as a hairline without becoming a hard rule.
- **`dim`** and **`faint`** carry contrast requirements the inverted dark values
  won't meet. Aim for `dim` ≈ 7:1 against `ground`, `faint` ≈ 4.5:1. `faint` fails
  first, since it sits on `panel` rather than `ground` in several places.
- **`accent`** `#8839ef` is dark enough for light-background text but reads heavy
  as a border; you may want a lighter companion for border use.
- **`green` / `yellow` / `red` / `teal`** are tuned for legibility on `#17171A`
  and are too light on `#F0ECE5`. Darken each until it passes against the new
  `ground` — the status bar puts them on `panel`, so check both.

Check contrast before settling on a value. The dark theme's `faint` on `panel` is
the tightest pair in the whole palette and is worth measuring as your baseline.

## Other things worth knowing

**The `Alt+Tab` binding.** Most window managers and terminal emulators intercept
`Alt+Tab` before tmux sees it. If scroll mode doesn't trigger, the binding is
fine — the keystroke never arrived. Rebind it to something your environment
passes through:

```tmux
unbind -n M-Tab
bind -n M-z copy-mode
```

**Alt bindings and Meta.** Alt bindings need the terminal to send Meta rather
than a composed character. macOS Terminal and iTerm2 both have an *Option as Meta
key* setting that must be on. On Linux, most terminals send Meta by default.

**Prefix key.** The theme keeps tmux's default `C-b`. If you use `C-a`, change it
early in the file, before the theme's bindings are declared:

```tmux
set -g prefix C-a
unbind C-b
bind C-a send-prefix
```
