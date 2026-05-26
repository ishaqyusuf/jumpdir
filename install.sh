#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="${TERMCODE_REPO_OWNER:-ishaqyusuf}"
REPO_NAME="${TERMCODE_REPO_NAME:-termcode}"
REF="${TERMCODE_REF:-main}"
SOURCE_URL="${TERMCODE_SOURCE_URL:-https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$REF/bin/termcode}"
INSTALL_DIR="${TERMCODE_INSTALL_DIR:-$HOME/.local/bin}"
INSTALL_BIN="$INSTALL_DIR/termcode"
TMP_FILE=""

permission_error() {
  cat >&2 <<EOF
Cannot write to $INSTALL_DIR.

Use the default user install:
  curl -fsSL https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$REF/install.sh | bash

Or rerun with sudo for this install directory:
  curl -fsSL https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$REF/install.sh | sudo env TERMCODE_INSTALL_DIR="$INSTALL_DIR" bash
EOF
  exit 1
}

cleanup() {
  if [ -n "$TMP_FILE" ] && [ -f "$TMP_FILE" ]; then
    rm -f "$TMP_FILE"
  fi
}
trap cleanup EXIT

local_source_bin() {
  local source_path source_dir
  source_path="${BASH_SOURCE[0]:-}"
  [ -n "$source_path" ] || return 0

  source_dir="$(cd "$(dirname "$source_path")" 2>/dev/null && pwd -P || true)"
  if [ -n "$source_dir" ] && [ -f "$source_dir/bin/termcode" ]; then
    printf '%s\n' "$source_dir/bin/termcode"
  fi
}

ensure_install_dir() {
  local parent
  if [ -d "$INSTALL_DIR" ]; then
    [ -w "$INSTALL_DIR" ] || permission_error
    return 0
  fi

  parent="$(dirname "$INSTALL_DIR")"
  [ -w "$parent" ] || permission_error
  install -d "$INSTALL_DIR"
}

download_source_bin() {
  command -v curl >/dev/null 2>&1 || {
    echo "curl is required for remote install." >&2
    exit 1
  }

  TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/termcode.XXXXXX")"
  curl -fsSL "$SOURCE_URL" -o "$TMP_FILE"
  chmod +x "$TMP_FILE"
  printf '%s\n' "$TMP_FILE"
}

SOURCE_BIN="$(local_source_bin)"
if [ -z "$SOURCE_BIN" ]; then
  echo "Downloading termcode from $SOURCE_URL"
  SOURCE_BIN="$(download_source_bin)"
fi

ensure_install_dir
install -m 0755 "$SOURCE_BIN" "$INSTALL_BIN"

echo "Installed termcode to $INSTALL_BIN"
"$INSTALL_BIN" --version

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo "Add this to your shell config if termcode is not found:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac
