#!/bin/sh
# Plext CLI installer for macOS and Linux.
#
#   curl -fsSL https://get.plext.com/install.sh | sh
#
# Environment overrides (all optional):
#   PLEXT_VERSION   pin to a specific tag (e.g. v0.1.0). Defaults to latest.
#   PLEXT_INSTALL   install directory. Defaults to ~/.plext/bin.
#   PLEXT_DL_BASE   download base URL. Defaults to https://dl.plext.com.
#   PLEXT_NO_PATH   if set, skip rc file patching.
#
# This script is public and auditable. Read it before piping into sh.

set -eu

DL_BASE="${PLEXT_DL_BASE:-https://dl.plext.com}"
INSTALL_DIR="${PLEXT_INSTALL:-$HOME/.plext/bin}"
BIN_NAME="plext"

say()   { printf '%s\n' "$*"; }
info()  { printf '  %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
err()   { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || err "missing required command: $1"; }

need uname
need tar
need mkdir
need chmod

# Prefer curl; fall back to wget.
if command -v curl >/dev/null 2>&1; then
  DOWNLOAD="curl -fsSL"
  DOWNLOAD_OUT="curl -fsSL -o"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOAD="wget -qO-"
  DOWNLOAD_OUT="wget -qO"
else
  err "need curl or wget to download plext"
fi

# Detect OS.
UNAME_S="$(uname -s)"
case "$UNAME_S" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux"  ;;
  *)      err "unsupported OS: $UNAME_S" ;;
esac

# Detect arch.
UNAME_M="$(uname -m)"
case "$UNAME_M" in
  x86_64|amd64)  ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *)             err "unsupported architecture: $UNAME_M" ;;
esac

# Resolve version.
if [ -n "${PLEXT_VERSION:-}" ]; then
  VERSION="$PLEXT_VERSION"
else
  VERSION="$($DOWNLOAD "$DL_BASE/latest/version.txt" 2>/dev/null | tr -d ' \r\n')"
  if [ -z "$VERSION" ]; then
    err "could not resolve latest version from $DL_BASE/latest/version.txt"
  fi
fi

say
say "Installing plext $VERSION for $OS/$ARCH…"
say

ARCHIVE="plext-${OS}-${ARCH}.tar.gz"
ARCHIVE_URL="$DL_BASE/$VERSION/$ARCHIVE"
CHECKSUMS_URL="$DL_BASE/$VERSION/checksums.txt"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t plext)"
trap 'rm -rf "$TMP"' EXIT INT TERM

info "Downloading $ARCHIVE_URL"
$DOWNLOAD_OUT "$TMP/$ARCHIVE" "$ARCHIVE_URL" || err "download failed"

info "Downloading checksums.txt"
$DOWNLOAD_OUT "$TMP/checksums.txt" "$CHECKSUMS_URL" || err "checksum download failed"

# Verify SHA256.
EXPECTED="$(grep "  $ARCHIVE\$" "$TMP/checksums.txt" | awk '{print $1}')"
if [ -z "$EXPECTED" ]; then
  err "no checksum entry for $ARCHIVE in checksums.txt"
fi

if command -v shasum >/dev/null 2>&1; then
  ACTUAL="$(shasum -a 256 "$TMP/$ARCHIVE" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$TMP/$ARCHIVE" | awk '{print $1}')"
else
  err "need shasum or sha256sum to verify download"
fi

if [ "$EXPECTED" != "$ACTUAL" ]; then
  err "checksum mismatch: expected $EXPECTED, got $ACTUAL"
fi
ok "Checksum verified"

# Extract.
mkdir -p "$INSTALL_DIR"
tar -xzf "$TMP/$ARCHIVE" -C "$TMP"
EXTRACTED="$TMP/plext-${OS}-${ARCH}"
if [ ! -f "$EXTRACTED" ]; then
  err "archive did not contain plext-${OS}-${ARCH}"
fi
mv "$EXTRACTED" "$INSTALL_DIR/$BIN_NAME"
chmod +x "$INSTALL_DIR/$BIN_NAME"
ok "Installed to $INSTALL_DIR/$BIN_NAME"

# Patch shell rc files.
patch_rc() {
  rc="$1"
  line="export PATH=\"$INSTALL_DIR:\$PATH\""
  if [ -f "$rc" ] && grep -qs "$INSTALL_DIR" "$rc"; then
    return 0
  fi
  printf '\n# Added by the plext installer\n%s\n' "$line" >> "$rc"
  ok "Added $INSTALL_DIR to PATH in $rc"
}

if [ -z "${PLEXT_NO_PATH:-}" ]; then
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) : already on PATH ;;
    *)
      [ -f "$HOME/.zshrc" ]   && patch_rc "$HOME/.zshrc"
      [ -f "$HOME/.bashrc" ]  && patch_rc "$HOME/.bashrc"
      [ -f "$HOME/.profile" ] && patch_rc "$HOME/.profile"
      if [ -z "${ZDOTDIR:-}" ] && [ ! -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.profile" ]; then
        warn "No shell rc file found. Add this line manually:"
        warn "  export PATH=\"$INSTALL_DIR:\$PATH\""
      fi
      ;;
  esac
fi

say
ok "plext $VERSION installed"
say
info "Next steps:"
info "  1. Restart your shell (or run: export PATH=\"$INSTALL_DIR:\$PATH\")"
info "  2. Run: plext --help"
info "  3. Get started: plext setup"
say
