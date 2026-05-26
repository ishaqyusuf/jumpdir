#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERMCODE="$ROOT_DIR/bin/termcode"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"
TMP_DIR="$(mktemp -d "$TMP_BASE/termcode-tests.XXXXXX")"
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack needle
  haystack="$1"
  needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain: $needle"$'\n'"actual: $haystack" ;;
  esac
}

assert_not_contains() {
  local haystack needle
  haystack="$1"
  needle="$2"
  case "$haystack" in
    *"$needle"*) fail "expected output not to contain: $needle"$'\n'"actual: $haystack" ;;
    *) ;;
  esac
}

assert_file_contains() {
  local file needle
  file="$1"
  needle="$2"
  grep -Fq "$needle" "$file" || fail "expected $file to contain: $needle"
}

make_project() {
  local dir
  dir="$1"
  mkdir -p "$dir"
  printf '{"scripts":{"dev":"echo dev","build":"echo build"}}\n' > "$dir/package.json"
}

make_stub() {
  local name
  name="$1"
  cat > "$TMP_DIR/stubs/$name" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s|%s\n' "$(basename "$0")" "$PWD" "$*" >> "$TERMCODE_TEST_LOG"
STUB
  chmod +x "$TMP_DIR/stubs/$name"
}

export TERMCODE_CONFIG_DIR="$TMP_DIR/config"
export TERMCODE_TEST_LOG="$TMP_DIR/commands.log"
mkdir -p "$TMP_DIR/root-a" "$TMP_DIR/root-b" "$TMP_DIR/stubs"
: > "$TERMCODE_TEST_LOG"

make_stub open
make_stub code
make_stub npm
make_stub yarn
make_stub pnpm
make_stub bun
export PATH="$TMP_DIR/stubs:$PATH"

make_project "$TMP_DIR/root-a/alpha"
make_project "$TMP_DIR/root-a/beta"
make_project "$TMP_DIR/root-b/gamma"
mkdir -p "$TMP_DIR/root-a/not-a-project"

output="$("$TERMCODE" set "$TMP_DIR/root-a" "$TMP_DIR/root-b")"
assert_contains "$output" "Saved 2 project roots."
assert_file_contains "$TERMCODE_CONFIG_DIR/roots" "$TMP_DIR/root-a"
assert_file_contains "$TERMCODE_CONFIG_DIR/roots" "$TMP_DIR/root-b"

output="$("$TERMCODE" ls)"
assert_contains "$output" "alpha"
assert_contains "$output" "beta"
assert_contains "$output" "gamma"
assert_not_contains "$output" "not-a-project"

output="$("$TERMCODE" rename alpha a)"
assert_contains "$output" "Renamed alpha to a."
output="$("$TERMCODE" ls)"
assert_contains "$output" "a"
assert_contains "$output" "$TMP_DIR/root-a/alpha"

"$TERMCODE" open a
assert_file_contains "$TERMCODE_TEST_LOG" "open|"
assert_file_contains "$TERMCODE_TEST_LOG" "$TMP_DIR/root-a/alpha"

"$TERMCODE" . beta
assert_file_contains "$TERMCODE_TEST_LOG" "code|"
assert_file_contains "$TERMCODE_TEST_LOG" "$TMP_DIR/root-a/beta"

: > "$TERMCODE_TEST_LOG"
touch "$TMP_DIR/root-b/gamma/pnpm-lock.yaml"
"$TERMCODE" gamma dev --watch
assert_file_contains "$TERMCODE_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|run dev -- --watch"

: > "$TERMCODE_TEST_LOG"
touch "$TMP_DIR/root-a/beta/yarn.lock"
"$TERMCODE" beta build
assert_file_contains "$TERMCODE_TEST_LOG" "yarn|$TMP_DIR/root-a/beta|run build"

make_project "$TMP_DIR/root-b/alpha"
set +e
duplicate_output="$("$TERMCODE" ls 2>&1)"
duplicate_status="$?"
set -e
[ "$duplicate_status" -eq 65 ] || fail "expected duplicate ls to exit 65, got $duplicate_status"
assert_contains "$duplicate_output" "duplicate project name \"alpha\""
assert_contains "$duplicate_output" "$TMP_DIR/root-a/alpha"
assert_contains "$duplicate_output" "$TMP_DIR/root-b/alpha"

output="$(TERMCODE_INSTALL_DIR="$TMP_DIR/install-local" "$ROOT_DIR/install.sh")"
assert_contains "$output" "Installed termcode to $TMP_DIR/install-local/termcode"
"$TMP_DIR/install-local/termcode" --version >/dev/null

cp "$ROOT_DIR/install.sh" "$TMP_DIR/remote-install.sh"
output="$(TERMCODE_INSTALL_DIR="$TMP_DIR/install-remote" TERMCODE_SOURCE_URL="file://$TERMCODE" bash "$TMP_DIR/remote-install.sh")"
assert_contains "$output" "Downloading termcode from file://$TERMCODE"
assert_contains "$output" "Installed termcode to $TMP_DIR/install-remote/termcode"
"$TMP_DIR/install-remote/termcode" --version >/dev/null

printf 'ok - termcode roadmap behavior\n'
