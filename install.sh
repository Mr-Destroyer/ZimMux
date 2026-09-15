#!/usr/bin/env bash
# ZimMux installer — symlink this repo's tmux.conf into place.
#
# Idempotent: safe to re-run. An existing config is backed up once, then
# replaced by a symlink to this repo, so `git pull` updates your live theme.
#
#   ./install.sh
#
# Overridable:
#   TMUX_CONF_TARGET   where the symlink lands (default ~/.config/tmux/tmux.conf)
#   TMUX_BACKUP_DIR    where backups go (default ~/.agent-mux/backups if that
#                      tree exists, else ~/.config/tmux/backups)

set -euo pipefail

# ── Resolve this script's real directory (follows symlinks) ──────────
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
REPO_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

REPO_CONF="$REPO_DIR/tmux.conf"

TARGET="${TMUX_CONF_TARGET:-$HOME/.config/tmux/tmux.conf}"
if [ -n "${TMUX_BACKUP_DIR:-}" ]; then
    BACKUP_DIR="$TMUX_BACKUP_DIR"
elif [ -d "$HOME/.agent-mux" ]; then
    BACKUP_DIR="$HOME/.agent-mux/backups"
else
    BACKUP_DIR="$HOME/.config/tmux/backups"
fi

# ── Output helpers (colour only on a tty) ────────────────────────────
if [ -t 1 ]; then
    C_OK=$'\033[38;2;95;174;116m'; C_WARN=$'\033[38;2;211;160;39m'
    C_ERR=$'\033[38;2;199;62;62m'; C_ACC=$'\033[38;2;203;166;247m'
    C_DIM=$'\033[38;2;138;136;145m'; C_OFF=$'\033[0m'
else
    C_OK=''; C_WARN=''; C_ERR=''; C_ACC=''; C_DIM=''; C_OFF=''
fi
info() { printf '%s==>%s %s\n' "$C_ACC" "$C_OFF" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s  !!%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
die()  { printf '%s  xx%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────
command -v tmux >/dev/null 2>&1 || die "tmux not found on PATH — install tmux first."
[ -f "$REPO_CONF" ] || die "missing $REPO_CONF — run this from a full checkout of ZimMux."

printf '\n%sZimMux%s — herdr Ink tmux theme\n\n' "$C_ACC" "$C_OFF"
info "repo   $REPO_CONF"
info "target $TARGET"

# ── Refuse to clobber a real directory ───────────────────────────────
if [ -d "$TARGET" ] && [ ! -L "$TARGET" ]; then
    die "$TARGET is a directory, not a file — move it aside and re-run."
fi

# ── Link (backing up anything real that is already there) ────────────
mkdir -p "$(dirname "$TARGET")"

if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$REPO_CONF" ]; then
    ok "already linked — nothing to back up"
elif [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    mkdir -p "$BACKUP_DIR"
    STAMP="$(date +%Y%m%d-%H%M%S)"
    BACKUP="$BACKUP_DIR/tmux.conf.$STAMP.bak"
    # Two runs inside the same second must not clobber each other.
    n=1
    while [ -e "$BACKUP" ]; do BACKUP="$BACKUP_DIR/tmux.conf.$STAMP-$n.bak"; n=$((n + 1)); done
    # -p preserves the original's mtime; follow the link if it dangles.
    cp -p "$TARGET" "$BACKUP" 2>/dev/null || cp -pL "$TARGET" "$BACKUP"
    ok "backed up existing config -> $BACKUP"
else
    ok "no existing config — fresh install"
fi

ln -sfn "$REPO_CONF" "$TARGET"
ok "linked $TARGET -> $REPO_CONF"

# ── Reload a running server, if there is one ─────────────────────────
if tmux list-sessions >/dev/null 2>&1; then
    if tmux source-file "$TARGET" 2>/dev/null; then
        ok "reloaded running tmux server"
    else
        warn "tmux is running but the reload failed — press PREFIX+r inside tmux"
    fi
else
    ok "no running tmux server — nothing to reload"
fi

# ── Next steps ───────────────────────────────────────────────────────
cat <<EOF

$(printf '%sNext steps%s' "$C_ACC" "$C_OFF")
  • Start tmux (or press $(printf '%sPREFIX+r%s' "$C_ACC" "$C_OFF") in a live session) to apply the theme.
  • Verify non-interactively:  $(printf '%s./tests/verify.sh%s' "$C_ACC" "$C_OFF")
  • Undo:  rm "$TARGET" && cp "$BACKUP_DIR"/tmux.conf.*.bak "$TARGET"

$(printf '%sNote%s' "$C_DIM" "$C_OFF") truecolor needs a 24-bit terminal (Windows Terminal, kitty, iTerm2, …).
EOF
