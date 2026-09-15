#!/usr/bin/env bash
# ZimMux verification suite — non-interactive.
#
# Starts a throwaway tmux server against this repo's tmux.conf, asserts that
# the theme loaded and that every option and binding the theme promises is
# actually in effect, then tears the server down.
#
#   ./tests/verify.sh
#
# Overridable:
#   TMUX_CONF   config to test (default: <repo>/tmux.conf)
#   TMUX_BIN    tmux binary (default: tmux on PATH)

set -uo pipefail   # deliberately not -e: run every check, then report

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${TMUX_CONF:-$REPO_DIR/tmux.conf}"
TMUX_BIN="${TMUX_BIN:-tmux}"
# Per-PID socket so parallel runs and a live server never collide.
SOCKET="zmux-verify-$$"

PASS=0
FAIL=0
FAILED=()

if [ -t 1 ]; then
    C_OK=$'\033[38;2;95;174;116m'; C_ERR=$'\033[38;2;199;62;62m'
    C_ACC=$'\033[38;2;203;166;247m'; C_DIM=$'\033[38;2;138;136;145m'; C_OFF=$'\033[0m'
else
    C_OK=''; C_ERR=''; C_ACC=''; C_DIM=''; C_OFF=''
fi

TMPDIR_RUN="$(mktemp -d)"
cleanup() {
    "$TMUX_BIN" -L "$SOCKET" kill-server >/dev/null 2>&1 || true
    # kill-server does not always unlink the socket file (tmux leaves it
    # behind on some builds), so remove it explicitly rather than leave
    # litter in the tmux socket directory.
    rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET" 2>/dev/null || true
    rm -rf "$TMPDIR_RUN"
}
trap cleanup EXIT

# ── Check helpers ────────────────────────────────────────────────────
pass() { PASS=$((PASS + 1)); printf '  %sPASS%s %s\n' "$C_OK" "$C_OFF" "$1"; }
fail() {
    FAIL=$((FAIL + 1)); FAILED+=("$1")
    printf '  %sFAIL%s %s\n' "$C_ERR" "$C_OFF" "$1"
    [ $# -gt 1 ] && printf '       %sexpected:%s %s\n' "$C_DIM" "$C_OFF" "$2"
    [ $# -gt 2 ] && printf '       %sactual:%s   %s\n' "$C_DIM" "$C_OFF" "$3"
    return 0
}

# check_eq <label> <actual> <expected>
check_eq() {
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "$3" "${2:-<empty>}"; fi
}
# check_has <label> <haystack> <needle>
check_has() {
    case "$2" in
        *"$3"*) pass "$1" ;;
        *)      fail "$1" "to contain '$3'" "${2:-<empty>}" ;;
    esac
}
# check_nonempty <label> <value>
check_nonempty() {
    if [ -n "$2" ]; then pass "$1"; else fail "$1" "a non-empty value" "<empty>"; fi
}
# opt <scope> <name>  -> option value, empty if unset
opt() { "$TMUX_BIN" -L "$SOCKET" show-options "$1"v "$2" 2>/dev/null; }
# check_binding <table> <key> — list-keys exits 0 even when unbound, so grep output
check_binding() {
    if "$TMUX_BIN" -L "$SOCKET" list-keys -T "$1" 2>/dev/null | grep -qE "[[:space:]]$2[[:space:]]"; then
        pass "bind $1 $2"
    else
        fail "bind $1 $2" "a binding for $2 in table $1" "unbound"
    fi
}

# ── Preflight ────────────────────────────────────────────────────────
command -v "$TMUX_BIN" >/dev/null 2>&1 || { echo "tmux not found" >&2; exit 2; }
[ -f "$CONF" ] || { echo "missing config: $CONF" >&2; exit 2; }

printf '\n%sZimMux verify%s  %s\n' "$C_ACC" "$C_OFF" "$CONF"
printf '%stmux %s%s\n\n' "$C_DIM" "$("$TMUX_BIN" -V 2>&1 | awk '{print $2}')" "$C_OFF"

# ── Boot a detached server on the repo config ────────────────────────
ERRLOG="$TMPDIR_RUN/stderr"
if ! "$TMUX_BIN" -L "$SOCKET" -f "$CONF" new-session -d -x 200 -y 50 2>"$ERRLOG"; then
    printf '%sFATAL%s tmux could not start with this config:\n' "$C_ERR" "$C_OFF"
    sed 's/^/       /' "$ERRLOG"
    exit 1
fi
if [ -s "$ERRLOG" ]; then
    fail "config loads without errors" "no output on stderr" "$(tr '\n' ';' < "$ERRLOG")"
else
    pass "config loads without errors"
fi

# ── Theme: status bar ────────────────────────────────────────────────
check_eq "status-style"                  "$(opt -g status-style)"                 "bg=#17171A,fg=#cdccd2"
check_eq "status on"                     "$(opt -g status)"                       "on"
check_eq "status-position"               "$(opt -g status-position)"              "bottom"
check_eq "status-interval"               "$(opt -g status-interval)"              "5"
check_has "status-left has session pill" "$(opt -g status-left)"                  "◉"
check_has "status-left has PREFIX chip"  "$(opt -g status-left)"                  "PREFIX"
check_has "status-right has clock"       "$(opt -g status-right)"                 "%H:%M"
check_has "status-right has host"        "$(opt -g status-right)"                 "#h"

# ── Theme: panes ─────────────────────────────────────────────────────
check_eq "pane-active-border-style"      "$(opt -g pane-active-border-style)"     "fg=#cba6f7"
check_eq "pane-border-style"             "$(opt -g pane-border-style)"            "fg=#3a3a41"
check_eq "pane-border-lines"             "$(opt -g pane-border-lines)"            "single"
check_eq "pane-border-status"            "$(opt -g pane-border-status)"           "top"
check_has "pane-border-format has @name" "$(opt -g pane-border-format)"           "@name"

# ── Theme: windows ───────────────────────────────────────────────────
check_eq "window-status-current-style"   "$(opt -gw window-status-current-style)" "bg=#cba6f7,fg=#17171A,bold"
check_eq "window-status-style"           "$(opt -gw window-status-style)"         "bg=#17171A,fg=#8a8891"

# ── Theme: modes, menus, dialogs ─────────────────────────────────────
check_eq "mode-style"                    "$(opt -g mode-style)"                   "bg=#cba6f7,fg=#17171A,bold"
check_eq "message-style"                 "$(opt -g message-style)"                "bg=#26262B,fg=#eae8ee"
check_eq "message-command-style"         "$(opt -g message-command-style)"        "bg=#26262B,fg=#cba6f7"
check_eq "clock-mode-colour"             "$(opt -g clock-mode-colour)"            "#cba6f7"
check_eq "menu-selected-style"           "$(opt -g menu-selected-style)"          "bg=#cba6f7,fg=#17171A,bold"

# ── Behaviour: terminal, base index, mouse ───────────────────────────
check_eq "default-terminal"              "$(opt -g default-terminal)"             "tmux-256color"
check_has "terminal-overrides truecolor" "$(opt -g terminal-overrides)"           ":Tc"
check_has "terminal-features RGB"        "$(opt -g terminal-features)"            ":RGB"
check_eq "focus-events"                  "$(opt -g focus-events)"                 "on"
check_eq "escape-time (server)"          "$(opt -s escape-time)"                  "0"
check_eq "extended-keys (server)"        "$(opt -s extended-keys)"                "on"
check_eq "base-index"                    "$(opt -g base-index)"                   "1"
check_eq "pane-base-index"               "$(opt -g pane-base-index)"              "1"
check_eq "renumber-windows"              "$(opt -g renumber-windows)"             "on"
check_eq "mouse"                         "$(opt -g mouse)"                        "on"

# ── Functional bindings: must all survive the retheme ────────────────
for k in M-j M-l M-i M-k M-n M-w M-o M-g M-y M-u M-h M-m M-Tab WheelUpPane MouseDown3Pane; do
    check_binding root "$k"
done
for k in i k I K MouseDragEnd1Pane; do
    check_binding copy-mode "$k"
done
check_binding prefix r

# ── Runtime values that only exist once the server is live ───────────
# @clip is resolved by an async `if-shell -b`, so allow it a moment.
CLIP=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
    CLIP="$("$TMUX_BIN" -L "$SOCKET" show-options -gv @clip 2>/dev/null)"
    [ -n "$CLIP" ] && break
    sleep 0.2
done
check_nonempty "@clip resolved to a copier" "$CLIP"

# The PREFIX+r reload binding is self-locating: it reads #{config_files}.
check_nonempty "config_files resolves (reload binding)" \
    "$("$TMUX_BIN" -L "$SOCKET" display-message -p '#{config_files}' 2>/dev/null)"

# ── Teardown happens via the EXIT trap ───────────────────────────────
printf '\n%s%d passed, %d failed%s\n' \
    "$([ "$FAIL" -eq 0 ] && printf '%s' "$C_OK" || printf '%s' "$C_ERR")" \
    "$PASS" "$FAIL" "$C_OFF"

if [ "$FAIL" -gt 0 ]; then
    printf '\n%sFailed checks:%s\n' "$C_ERR" "$C_OFF"
    for f in "${FAILED[@]}"; do printf '  • %s\n' "$f"; done
    exit 1
fi
printf '%sAll checks passed.%s\n' "$C_OK" "$C_OFF"
exit 0
