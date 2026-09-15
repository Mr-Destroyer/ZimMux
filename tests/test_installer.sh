#!/usr/bin/env bash
# tests/test_installer.sh — network-free checks for install.sh.
#
# 1. --help advertises --with-agent-mux (no side effects).
# 2. Full --with-agent-mux run in a sandbox: fake HOME, file:// stub
#    upstream installer, isolated tmux socket dir. Asserts the stub ran,
#    the theme symlink landed, a backup was taken, and re-runs are clean.
set -euo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  PASS %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$*" >&2; }

# ── 1. help text ─────────────────────────────────────────────────────
if bash "$REPO_DIR/install.sh" --help 2>&1 | grep -q -- --with-agent-mux; then
    pass "--help advertises --with-agent-mux"
else
    fail "--help advertises --with-agent-mux"
fi
if bash "$REPO_DIR/install.sh" --bogus-flag >/dev/null 2>&1; then
    fail "unknown flag exits nonzero"
else
    pass "unknown flag exits nonzero"
fi

# ── 2. sandboxed run ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
export TMUX_TMPDIR="$SANDBOX/tmux"   # keep clear of the live tmux server
# Hide the real agent-mux (if any) so the stub path is exercised.
export PATH="$(dirname "$(command -v tmux)"):/usr/local/bin:/usr/bin:/bin"
export TMUX_CONF_TARGET="$SANDBOX/target/tmux.conf"
export TMUX_BACKUP_DIR="$SANDBOX/backups"
mkdir -p "$HOME" "$TMUX_TMPDIR" "$(dirname "$TMUX_CONF_TARGET")"

# Stub upstream installer: mimics the real one's contract just enough —
# consumes the piped script, honours --no-config, drops the bin file.
cat > "$SANDBOX/upstream.sh" <<'STUB'
#!/usr/bin/env bash
# stub: first arg must be --no-config (what ZimMux passes through the pipe)
[ "${1:-}" = "--no-config" ] || { echo "stub: expected --no-config, got: $*" >&2; exit 1; }
mkdir -p "$HOME/.agent-mux/bin"
printf '#!/usr/bin/env bash\necho stub-agent-mux\n' > "$HOME/.agent-mux/bin/agent-mux"
chmod +x "$HOME/.agent-mux/bin/agent-mux"
touch "$HOME/.agent-mux/stub-ran"
STUB
chmod +x "$SANDBOX/upstream.sh"
export AGENT_MUX_INSTALL_URL="file://$SANDBOX/upstream.sh"

# Pre-existing config so the backup path is exercised.
echo "# before-zimmux" > "$TMUX_CONF_TARGET"

OUT="$(bash "$REPO_DIR/install.sh" --with-agent-mux 2>&1)" || {
    fail "sandboxed --with-agent-mux run (exit $?)"; printf '%s\n' "$OUT" >&2;
}

[ -f "$HOME/.agent-mux/stub-ran" ] \
    && pass "upstream installer invoked via pipe" \
    || fail "upstream installer invoked via pipe"
[ -x "$HOME/.agent-mux/bin/agent-mux" ] \
    && pass "engine bin file present" \
    || fail "engine bin file present"
[ -L "$TMUX_CONF_TARGET" ] && [ "$(readlink "$TMUX_CONF_TARGET")" = "$REPO_DIR/tmux.conf" ] \
    && pass "theme symlink wins" \
    || fail "theme symlink wins"
compgen -G "$TMUX_BACKUP_DIR/tmux.conf.*.bak" > /dev/null \
    && pass "pre-existing config backed up" \
    || fail "pre-existing config backed up"
grep -q "not on PATH yet" <<<"$OUT" \
    && pass "PATH hint printed" \
    || fail "PATH hint printed"

# Idempotent re-run: engine skipped, symlink kept, no second backup.
BACKUPS_BEFORE="$(compgen -G "$TMUX_BACKUP_DIR/tmux.conf.*.bak" | wc -l)"
OUT2="$(bash "$REPO_DIR/install.sh" --with-agent-mux 2>&1)" || fail "re-run exits 0"
BACKUPS_AFTER="$(compgen -G "$TMUX_BACKUP_DIR/tmux.conf.*.bak" | wc -l)"
grep -q "already installed — skipping" <<<"$OUT2" \
    && pass "engine skipped on re-run" \
    || fail "engine skipped on re-run"
[ "$BACKUPS_BEFORE" = "$BACKUPS_AFTER" ] \
    && pass "no duplicate backup on re-run" \
    || fail "no duplicate backup on re-run"

# Plain run (no flag) still works and never touches the network.
OUT3="$(bash "$REPO_DIR/install.sh" 2>&1)" || fail "plain run exits 0"
grep -q "already linked" <<<"$OUT3" \
    && pass "plain run links theme" \
    || fail "plain run links theme"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
