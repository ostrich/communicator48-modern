#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMUNICATOR_ARCHIVE="${COMMUNICATOR_ARCHIVE:-$ROOT_DIR/communicator-v48-us.x86-unknown-linux2.2.tar.gz}"
INSTALL_ARCHIVE_DIR="$ROOT_DIR/compat/archives/install"
DEB_ARCHIVE_DIR="$ROOT_DIR/compat/archives/debs"
BUILD_DIR="$ROOT_DIR/compat/build"
LIB_DIR="$ROOT_DIR/compat/lib"
GLIBC_DIR="$ROOT_DIR/compat/glibc"
X11_DIR="$ROOT_DIR/compat/x11"
FONT_DIR="$ROOT_DIR/compat/fonts"
APP_DIR="$ROOT_DIR/app"

XLIBS_DEB_URL="https://archive.debian.org/debian/pool/main/x/xfree86/xlibs_4.1.0-16woody6_i386.deb"
LIBSTDCXX_DEB_URL="https://archive.debian.org/debian/pool/main/e/egcs1.1/libstdc++2.9-glibc2.1_2.91.66-4_i386.deb"
LIBC6_DEB_URL="https://archive.debian.org/debian/pool/main/g/glibc/libc6_2.3.6.ds1-13etch10+b1_i386.deb"
XFONTS_BASE_DEB_URL="https://archive.debian.org/debian/dists/slink/main/binary-i386/x11/xfonts-base_3.3.2.3a-11.deb"
XFONTS_75DPI_DEB_URL="https://archive.debian.org/debian/dists/slink/main/binary-i386/x11/xfonts-75dpi_3.3.2.3a-11.deb"
XFONTS_100DPI_DEB_URL="https://archive.debian.org/debian/dists/slink/main/binary-i386/x11/xfonts-100dpi_3.3.2.3a-11.deb"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  }
}

fetch_if_missing() {
  local url="$1"
  local dest="$2"
  if [[ ! -f "$dest" ]]; then
    printf 'downloading %s\n' "$(basename "$dest")"
    curl -fL "$url" -o "$dest"
  fi
}

extract_deb_data() {
  local deb="$1"
  local dest="$2"

  rm -rf "$dest"
  mkdir -p "$dest/pkg" "$dest/root"
  (
    cd "$dest/pkg"
    ar x "$deb"
  )
  tar -xzf "$dest/pkg/data.tar.gz" -C "$dest/root"
}

stage_if_present() {
  local src="$1"
  local dest_dir="$2"

  if [[ -e "$src" ]]; then
    cp -a "$src" "$dest_dir/"
  fi
}

print_staged_entries() {
  local label="$1"
  local dir="$2"

  printf '\n%s in %s\n' "$label" "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 | sort
}

need_cmd curl
need_cmd ar
need_cmd tar
need_cmd find
need_cmd gzip
if [[ ! -f "$COMMUNICATOR_ARCHIVE" ]]; then
  printf 'missing Communicator archive: %s\n' "$COMMUNICATOR_ARCHIVE" >&2
  exit 1
fi

mkdir -p "$INSTALL_ARCHIVE_DIR" "$DEB_ARCHIVE_DIR"

fetch_if_missing "$XLIBS_DEB_URL" "$DEB_ARCHIVE_DIR/$(basename "$XLIBS_DEB_URL")"
fetch_if_missing "$LIBSTDCXX_DEB_URL" "$DEB_ARCHIVE_DIR/$(basename "$LIBSTDCXX_DEB_URL")"
fetch_if_missing "$LIBC6_DEB_URL" "$DEB_ARCHIVE_DIR/$(basename "$LIBC6_DEB_URL")"
fetch_if_missing "$XFONTS_BASE_DEB_URL" "$DEB_ARCHIVE_DIR/$(basename "$XFONTS_BASE_DEB_URL")"
fetch_if_missing "$XFONTS_75DPI_DEB_URL" "$DEB_ARCHIVE_DIR/$(basename "$XFONTS_75DPI_DEB_URL")"
fetch_if_missing "$XFONTS_100DPI_DEB_URL" "$DEB_ARCHIVE_DIR/$(basename "$XFONTS_100DPI_DEB_URL")"

rm -rf "$BUILD_DIR" "$LIB_DIR" "$GLIBC_DIR" "$X11_DIR" "$FONT_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$LIB_DIR" "$GLIBC_DIR" "$X11_DIR" "$FONT_DIR" "$APP_DIR"

rm -rf "$INSTALL_ARCHIVE_DIR/payload"
mkdir -p "$INSTALL_ARCHIVE_DIR/payload"
tar -xzf "$COMMUNICATOR_ARCHIVE" -C "$INSTALL_ARCHIVE_DIR/payload"
gzip -dc "$INSTALL_ARCHIVE_DIR/payload"/communicator-v48.x86-unknown-linux2.2/netscape-v48.nif | tar -xf - -C "$APP_DIR"

extract_deb_data "$DEB_ARCHIVE_DIR/$(basename "$XLIBS_DEB_URL")" "$BUILD_DIR/xlibs"
extract_deb_data "$DEB_ARCHIVE_DIR/$(basename "$LIBSTDCXX_DEB_URL")" "$BUILD_DIR/libstdcxx"
extract_deb_data "$DEB_ARCHIVE_DIR/$(basename "$LIBC6_DEB_URL")" "$BUILD_DIR/libc6"
extract_deb_data "$DEB_ARCHIVE_DIR/$(basename "$XFONTS_BASE_DEB_URL")" "$BUILD_DIR/xfonts-base"
extract_deb_data "$DEB_ARCHIVE_DIR/$(basename "$XFONTS_75DPI_DEB_URL")" "$BUILD_DIR/xfonts-75dpi"
extract_deb_data "$DEB_ARCHIVE_DIR/$(basename "$XFONTS_100DPI_DEB_URL")" "$BUILD_DIR/xfonts-100dpi"

for name in \
  libICE.so.6 libICE.so.6.3 \
  libSM.so.6 libSM.so.6.0 \
  libX11.so.6 libX11.so.6.2 \
  libXext.so.6 libXext.so.6.4 \
  libXmu.so.6 libXmu.so.6.2 \
  libXpm.so.4 libXpm.so.4.11 \
  libXt.so.6 libXt.so.6.0
do
  stage_if_present "$BUILD_DIR/xlibs/root/usr/X11R6/lib/$name" "$LIB_DIR"
done

stage_if_present "$BUILD_DIR/libstdcxx/root/usr/lib/libstdc++-libc6.1-1.so.2" "$LIB_DIR"
stage_if_present "$BUILD_DIR/libstdcxx/root/usr/lib/libstdc++-2-libc6.1-1-2.9.0.so" "$LIB_DIR"

cp -a "$BUILD_DIR/libc6/root/lib/." "$GLIBC_DIR/"

if [[ -f "$GLIBC_DIR/ld-linux.so.2" ]]; then
  chmod +x "$GLIBC_DIR/ld-linux.so.2"
fi

stage_if_present "$BUILD_DIR/xlibs/root/usr/X11R6/lib/X11/XKeysymDB" "$X11_DIR"
stage_if_present "$APP_DIR/XKeysymDB" "$X11_DIR"
cp -a "$BUILD_DIR/xfonts-base/root/usr/X11R6/lib/X11/fonts/misc" "$FONT_DIR/"
cp -a "$BUILD_DIR/xfonts-75dpi/root/usr/X11R6/lib/X11/fonts/75dpi" "$FONT_DIR/"
cp -a "$BUILD_DIR/xfonts-100dpi/root/usr/X11R6/lib/X11/fonts/100dpi" "$FONT_DIR/"

chmod u+w "$APP_DIR/netscape"

# Modern X servers can reject these startup probes with BadMatch.
# Patch the imported stubs to return NULL immediately.
for offset in $((0x238174)) $((0x239834)); do
  printf '\x31\xc0\xc3\x90\x90\x90\x90\x90\x90\x90\x90' | \
    dd of="$APP_DIR/netscape" bs=1 seek="$offset" conv=notrunc status=none
done

print_staged_entries "compat libraries staged" "$LIB_DIR"
print_staged_entries "local glibc staged" "$GLIBC_DIR"
print_staged_entries "X11 support data staged" "$X11_DIR"
print_staged_entries "bitmap fonts staged" "$FONT_DIR"
print_staged_entries "communicator staged" "$APP_DIR"
