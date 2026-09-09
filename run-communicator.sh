#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/app"
COMPAT_LIB_DIR="$ROOT_DIR/compat/lib"
GLIBC_DIR="$ROOT_DIR/compat/glibc"
X11_DIR="$ROOT_DIR/compat/x11"
FONT_ROOT="$ROOT_DIR/compat/fonts"
RUNTIME_ETC_DIR="$ROOT_DIR/compat/etc"
STATE_HOME="$ROOT_DIR/state"
NETSCAPE_BIN="$APP_DIR/netscape"
LOADER="$GLIBC_DIR/ld-linux.so.2"
LIBRARY_PATH="$COMPAT_LIB_DIR:$GLIBC_DIR"
HOSTNAME_VALUE="$(hostname)"
ADDED_FONT_PATHS=()

add_font_path() {
  local path="$1"
  if [[ -d "$path" ]] && command -v xset >/dev/null 2>&1; then
    xset q 2>/dev/null | grep -Fq "$path" && return 0
    if xset +fp "$path" >/dev/null 2>&1; then
      ADDED_FONT_PATHS+=("$path")
    fi
  fi
}

remove_font_path() {
  local path="$1"
  if [[ -d "$path" ]] && command -v xset >/dev/null 2>&1; then
    xset -fp "$path" >/dev/null 2>&1 || true
  fi
}

cleanup_font_paths() {
  local path
  for path in "${ADDED_FONT_PATHS[@]}"; do
    remove_font_path "$path"
  done
  if command -v xset >/dev/null 2>&1; then
    xset fp rehash >/dev/null 2>&1 || true
  fi
}

if [[ ! -x "$NETSCAPE_BIN" ]]; then
  printf 'missing %s\n' "$NETSCAPE_BIN" >&2
  printf 'run ./setup.sh first.\n' >&2
  exit 1
fi

if [[ ! -x "$LOADER" ]]; then
  printf 'missing staged loader in %s\n' "$LOADER" >&2
  printf 'run ./setup.sh first.\n' >&2
  exit 1
fi

if ! command -v bwrap >/dev/null 2>&1; then
  printf 'missing required command: bwrap\n' >&2
  exit 1
fi

if [[ ! -f "$X11_DIR/XKeysymDB" ]]; then
  printf 'missing X11 support data in %s\n' "$X11_DIR" >&2
  printf 'run ./setup.sh first.\n' >&2
  exit 1
fi

mkdir -p "$STATE_HOME" "$RUNTIME_ETC_DIR"
cd "$ROOT_DIR"

cat >"$RUNTIME_ETC_DIR/nsswitch.conf" <<'EOF'
hosts: files dns
passwd: files
group: files
shadow: files
networks: files
protocols: files
services: files
ethers: files
rpc: files
EOF

cat >"$RUNTIME_ETC_DIR/hosts" <<EOF
127.0.0.1 localhost $HOSTNAME_VALUE
::1 localhost
EOF

trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
trap cleanup_font_paths EXIT

if command -v xset >/dev/null 2>&1; then
  add_font_path "$FONT_ROOT/misc"
  add_font_path "$FONT_ROOT/75dpi"
  add_font_path "$FONT_ROOT/100dpi"
  xset fp rehash >/dev/null 2>&1 || true
else
  printf 'warning: xset not found; bundled bitmap fonts were not registered, so old X font warnings may remain.\n' >&2
fi

bwrap \
  --bind / / \
  --dev-bind /dev /dev \
  --proc /proc \
  --ro-bind "$RUNTIME_ETC_DIR/nsswitch.conf" /etc/nsswitch.conf \
  --ro-bind "$RUNTIME_ETC_DIR/hosts" /etc/hosts \
  --setenv HOME "$STATE_HOME" \
  --setenv MOZILLA_HOME "$APP_DIR" \
  --setenv LANG "${LANG_OVERRIDE:-C}" \
  --setenv LC_ALL "${LANG_OVERRIDE:-C}" \
  --setenv XKEYSYMDB "$X11_DIR/XKeysymDB" \
  --setenv XLOCALEDIR "/usr/share/X11/locale" \
  --setenv XNLSPATH "/usr/share/X11/locale" \
  --setenv MOZILLA_NO_ASYNC_DNS "${MOZILLA_NO_ASYNC_DNS:-True}" \
  --setenv LD_LIBRARY_PATH "$LIBRARY_PATH" \
  "$LOADER" \
  --library-path "$LIBRARY_PATH" \
  "$NETSCAPE_BIN" \
  "$@"
