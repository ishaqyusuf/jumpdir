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

assert_eq() {
  local actual expected
  actual="$1"
  expected="$2"
  [ "$actual" = "$expected" ] || fail "expected: $expected"$'\n'"actual: $actual"
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
  printf '{"scripts":{"dev":"echo dev","dev-2":"echo dev2","build":"echo build"}}\n' > "$dir/package.json"
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

run_termcode() {
  TERMCODE_CONFIG_DIR="$TEST_CONFIG_DIR" "$TERMCODE" "$@"
}

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

output="$(TERMCODE_CONFIG_DIR="$TMP_DIR/help-config" "$TERMCODE" --help)"
assert_contains "$output" "termcode - jump into and run scripts for local repos"
assert_contains "$output" "termcode runner set <runner|none>"
assert_contains "$output" "termcode update"
assert_not_contains "$output" "Welcome to termcode."

output="$(TERMCODE_SOURCE_URL="file://$TERMCODE" "$TERMCODE" update)"
assert_contains "$output" "Current version: 0.2.0"
assert_contains "$output" "Latest version:  0.2.0"
assert_contains "$output" "termcode is up to date."

NEWER_TERMCODE="$TMP_DIR/newer-termcode"
printf '#!/usr/bin/env bash\nVERSION="9.9.9"\n' > "$NEWER_TERMCODE"
output="$(TERMCODE_SOURCE_URL="file://$NEWER_TERMCODE" "$TERMCODE" update)"
assert_contains "$output" "Current version: 0.2.0"
assert_contains "$output" "Latest version:  9.9.9"
assert_contains "$output" "A newer termcode version is available."
assert_contains "$output" "curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/termcode/main/install.sh | bash"

TEST_CONFIG_DIR="$TMP_DIR/config"
output="$(
  printf '2\n%s\n1\n%s\n2\n' "$TMP_DIR/root-a" "$TMP_DIR/root-b" |
    TERMCODE_CONFIG_DIR="$TEST_CONFIG_DIR" "$TERMCODE"
)"
assert_contains "$output" "Welcome to termcode."
assert_contains "$output" "Step 1: Choose your preferred runner"
assert_contains "$output" "Preferred runner set to pnpm run."
assert_contains "$output" "Step 2: Add project directories"
assert_contains "$output" "Found 2 projects:"
assert_contains "$output" "Found 3 projects:"
assert_contains "$output" "Setup complete."
assert_file_contains "$TEST_CONFIG_DIR/runner" "pnpm"
assert_file_contains "$TEST_CONFIG_DIR/roots" "$TMP_DIR/root-a"
assert_file_contains "$TEST_CONFIG_DIR/roots" "$TMP_DIR/root-b"
[ -f "$TEST_CONFIG_DIR/onboarded" ] || fail "expected onboarding marker"

output="$(run_termcode)"
assert_contains "$output" "Usage:"
assert_not_contains "$output" "Welcome to termcode."

SET_FIRST_CONFIG="$TMP_DIR/set-first-config"
output="$(TERMCODE_CONFIG_DIR="$SET_FIRST_CONFIG" "$TERMCODE" set "$TMP_DIR/root-a")"
assert_contains "$output" "Saved 1 project root."
output="$(TERMCODE_CONFIG_DIR="$SET_FIRST_CONFIG" "$TERMCODE")"
assert_contains "$output" "Usage:"
assert_not_contains "$output" "Welcome to termcode."

output="$(run_termcode runner get)"
assert_eq "$output" "pnpm"
output="$(run_termcode runner set yarn)"
assert_contains "$output" "Preferred runner set to yarn run."
assert_eq "$(run_termcode runner get)" "yarn"
output="$(run_termcode runner clear)"
assert_contains "$output" "Preferred runner cleared."
assert_eq "$(run_termcode runner get)" "none"

set +e
invalid_runner_output="$(run_termcode runner set deno 2>&1)"
invalid_runner_status="$?"
set -e
[ "$invalid_runner_status" -eq 1 ] || fail "expected invalid runner to exit 1"
assert_contains "$invalid_runner_output" "preferred runner must be bun, pnpm, npm, yarn, or none"

set +e
invalid_prompt_output="$(run_termcode not-a-real-project 2>&1)"
invalid_prompt_status="$?"
set -e
[ "$invalid_prompt_status" -eq 64 ] || fail "expected invalid prompt to exit 64"
assert_contains "$invalid_prompt_output" "project not found: not-a-real-project"
assert_contains "$invalid_prompt_output" "Usage:"
assert_contains "$invalid_prompt_output" "termcode runner get"

output="$(run_termcode ls)"
assert_contains "$output" "alpha"
assert_contains "$output" "beta"
assert_contains "$output" "gamma"
assert_not_contains "$output" "not-a-project"

output="$(run_termcode rename alpha a)"
assert_contains "$output" "Renamed alpha to a."
output="$(run_termcode ls)"
assert_contains "$output" "a"
assert_contains "$output" "$TMP_DIR/root-a/alpha"

run_termcode open a
assert_file_contains "$TERMCODE_TEST_LOG" "open|"
assert_file_contains "$TERMCODE_TEST_LOG" "$TMP_DIR/root-a/alpha"

run_termcode . beta
assert_file_contains "$TERMCODE_TEST_LOG" "code|"
assert_file_contains "$TERMCODE_TEST_LOG" "$TMP_DIR/root-a/beta"

assert_eq "$(run_termcode path gamma)" "$TMP_DIR/root-b/gamma"
assert_eq "$(run_termcode gamma)" "$TMP_DIR/root-b/gamma"

: > "$TERMCODE_TEST_LOG"
run_termcode runner set pnpm >/dev/null
set +e
invalid_script_output="$(run_termcode gamma dev2 2>&1)"
invalid_script_status="$?"
set -e
[ "$invalid_script_status" -eq 64 ] || fail "expected invalid script to exit 64"
assert_contains "$invalid_script_output" "script not found: dev2"
assert_contains "$invalid_script_output" "available script names on your project \"gamma\""
assert_contains "$invalid_script_output" "[dev]"
assert_contains "$invalid_script_output" "[dev-2]"
assert_contains "$invalid_script_output" "[build]"
assert_eq "$(wc -l < "$TERMCODE_TEST_LOG" | tr -d ' ')" "0"

run_termcode gamma dev --watch
assert_file_contains "$TERMCODE_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|run dev -- --watch"

: > "$TERMCODE_TEST_LOG"
run_termcode runner clear >/dev/null
set +e
invalid_explicit_script_output="$(run_termcode gamma bun run dev2 2>&1)"
invalid_explicit_script_status="$?"
set -e
[ "$invalid_explicit_script_status" -eq 64 ] || fail "expected invalid explicit script to exit 64"
assert_contains "$invalid_explicit_script_output" "script not found: dev2"
assert_contains "$invalid_explicit_script_output" "available script names on your project \"gamma\""
assert_contains "$invalid_explicit_script_output" "[dev]"
assert_contains "$invalid_explicit_script_output" "[dev-2]"
assert_contains "$invalid_explicit_script_output" "[build]"
assert_eq "$(wc -l < "$TERMCODE_TEST_LOG" | tr -d ' ')" "0"

run_termcode gamma bun run build --mode production
assert_file_contains "$TERMCODE_TEST_LOG" "bun|$TMP_DIR/root-b/gamma|run build -- --mode production"

set +e
missing_runner_output="$(run_termcode gamma dev 2>&1)"
missing_runner_status="$?"
set -e
[ "$missing_runner_status" -eq 64 ] || fail "expected missing runner to exit 64"
assert_contains "$missing_runner_output" "no preferred runner is set"
assert_contains "$missing_runner_output" "termcode gamma bun run dev"

init_output="$(run_termcode init zsh)"
assert_contains "$init_output" "termcode()"
assert_contains "$init_output" "command termcode path"
printf '%s\n' "$init_output" > "$TMP_DIR/termcode.zsh"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$TMP_DIR/termcode.zsh"
fi

make_project "$TMP_DIR/root-b/alpha"
set +e
duplicate_output="$(run_termcode ls 2>&1)"
duplicate_status="$?"
set -e
[ "$duplicate_status" -eq 65 ] || fail "expected duplicate ls to exit 65, got $duplicate_status"
assert_contains "$duplicate_output" "duplicate project name \"alpha\""
assert_contains "$duplicate_output" "$TMP_DIR/root-a/alpha"
assert_contains "$duplicate_output" "$TMP_DIR/root-b/alpha"

output="$(TERMCODE_INSTALL_DIR="$TMP_DIR/install-local" "$ROOT_DIR/install.sh")"
assert_contains "$output" "Installed termcode to $TMP_DIR/install-local/termcode"
assert_contains "$("$TMP_DIR/install-local/termcode" --version)" "termcode 0.2.0"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/remote-install.sh"
output="$(TERMCODE_INSTALL_DIR="$TMP_DIR/install-remote" TERMCODE_SOURCE_URL="file://$TERMCODE" bash "$TMP_DIR/remote-install.sh")"
assert_contains "$output" "Downloading termcode from file://$TERMCODE"
assert_contains "$output" "Installed termcode to $TMP_DIR/install-remote/termcode"
assert_contains "$("$TMP_DIR/install-remote/termcode" --version)" "termcode 0.2.0"

output="$(TERMCODE_INSTALL_DIR="$TMP_DIR/install-piped" TERMCODE_SOURCE_URL="file://$TERMCODE" bash < "$ROOT_DIR/install.sh")"
assert_contains "$output" "Downloading termcode from file://$TERMCODE"
assert_contains "$output" "Installed termcode to $TMP_DIR/install-piped/termcode"
assert_contains "$("$TMP_DIR/install-piped/termcode" --version)" "termcode 0.2.0"

mkdir -p "$TMP_DIR/readonly"
chmod 555 "$TMP_DIR/readonly"
set +e
readonly_output="$(TERMCODE_INSTALL_DIR="$TMP_DIR/readonly" TERMCODE_SOURCE_URL="file://$TERMCODE" bash < "$ROOT_DIR/install.sh" 2>&1)"
readonly_status="$?"
set -e
chmod 755 "$TMP_DIR/readonly"
[ "$readonly_status" -eq 1 ] || fail "expected readonly install to exit 1, got $readonly_status"
assert_contains "$readonly_output" "Cannot write to $TMP_DIR/readonly."
assert_contains "$readonly_output" "sudo env TERMCODE_INSTALL_DIR=\"$TMP_DIR/readonly\" bash"

printf 'ok - termcode v0.2 behavior\n'
