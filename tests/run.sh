#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JUMPDIR="$ROOT_DIR/bin/jumpdir"
TERMCODE="$ROOT_DIR/bin/termcode"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"
TMP_DIR="$(mktemp -d "$TMP_BASE/jumpdir-tests.XXXXXX")"
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
printf '%s|%s|%s\n' "$(basename "$0")" "$PWD" "$*" >> "$JUMPDIR_TEST_LOG"
STUB
  chmod +x "$TMP_DIR/stubs/$name"
}

run_jumpdir() {
  JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JUMPDIR" "$@"
}

export JUMPDIR_TEST_LOG="$TMP_DIR/commands.log"
mkdir -p "$TMP_DIR/root-a" "$TMP_DIR/root-b" "$TMP_DIR/stubs"
: > "$JUMPDIR_TEST_LOG"

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

output="$(JUMPDIR_CONFIG_DIR="$TMP_DIR/help-config" bash "$JUMPDIR" --help)"
assert_contains "$output" "jumpdir - jump into and run scripts for local repos"
assert_contains "$output" "jumpdir runner set <runner|none>"
assert_contains "$output" "jumpdir update"
assert_not_contains "$output" "Welcome to jumpdir."

output="$(JUMPDIR_CONFIG_DIR="$TMP_DIR/compat-config" bash "$TERMCODE" --help)"
assert_contains "$output" "termcode - jump into and run scripts for local repos"
assert_contains "$output" "termcode runner set <runner|none>"

output="$(JUMPDIR_SOURCE_URL="file://$JUMPDIR" bash "$JUMPDIR" update)"
assert_contains "$output" "Current version: 0.3.0"
assert_contains "$output" "Latest version:  0.3.0"
assert_contains "$output" "jumpdir is up to date."

NEWER_JUMPDIR="$TMP_DIR/newer-jumpdir"
printf '#!/usr/bin/env bash\nVERSION="9.9.9"\n' > "$NEWER_JUMPDIR"
output="$(JUMPDIR_SOURCE_URL="file://$NEWER_JUMPDIR" bash "$JUMPDIR" update)"
assert_contains "$output" "Current version: 0.3.0"
assert_contains "$output" "Latest version:  9.9.9"
assert_contains "$output" "A newer jumpdir version is available."
assert_contains "$output" "curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/jumpdir/main/install.sh | bash"

TEST_CONFIG_DIR="$TMP_DIR/config"
output="$(
  printf '2\n%s\n1\n%s\n2\n' "$TMP_DIR/root-a" "$TMP_DIR/root-b" |
    JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JUMPDIR"
)"
assert_contains "$output" "Welcome to jumpdir."
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

LEGACY_XDG_CONFIG_HOME="$TMP_DIR/legacy-xdg"
mkdir -p "$LEGACY_XDG_CONFIG_HOME/termcode"
printf '%s\n' "$TMP_DIR/root-a" > "$LEGACY_XDG_CONFIG_HOME/termcode/roots"
output="$(XDG_CONFIG_HOME="$LEGACY_XDG_CONFIG_HOME" bash "$JUMPDIR" ls)"
assert_contains "$output" "alpha"
assert_contains "$output" "beta"
assert_not_contains "$output" "gamma"

output="$(TERMCODE_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JUMPDIR" runner get)"
assert_eq "$output" "pnpm"

output="$(run_jumpdir)"
assert_contains "$output" "Usage:"
assert_not_contains "$output" "Welcome to jumpdir."

SET_FIRST_CONFIG="$TMP_DIR/set-first-config"
output="$(JUMPDIR_CONFIG_DIR="$SET_FIRST_CONFIG" bash "$JUMPDIR" set "$TMP_DIR/root-a")"
assert_contains "$output" "Saved 1 project root."
output="$(JUMPDIR_CONFIG_DIR="$SET_FIRST_CONFIG" bash "$JUMPDIR")"
assert_contains "$output" "Usage:"
assert_not_contains "$output" "Welcome to jumpdir."

output="$(run_jumpdir runner get)"
assert_eq "$output" "pnpm"
output="$(run_jumpdir runner set yarn)"
assert_contains "$output" "Preferred runner set to yarn run."
assert_eq "$(run_jumpdir runner get)" "yarn"
output="$(run_jumpdir runner clear)"
assert_contains "$output" "Preferred runner cleared."
assert_eq "$(run_jumpdir runner get)" "none"

set +e
invalid_runner_output="$(run_jumpdir runner set deno 2>&1)"
invalid_runner_status="$?"
set -e
[ "$invalid_runner_status" -eq 1 ] || fail "expected invalid runner to exit 1"
assert_contains "$invalid_runner_output" "preferred runner must be bun, pnpm, npm, yarn, or none"

set +e
invalid_prompt_output="$(run_jumpdir not-a-real-project 2>&1)"
invalid_prompt_status="$?"
set -e
[ "$invalid_prompt_status" -eq 64 ] || fail "expected invalid prompt to exit 64"
assert_contains "$invalid_prompt_output" "project not found: not-a-real-project"
assert_contains "$invalid_prompt_output" "Usage:"
assert_contains "$invalid_prompt_output" "jumpdir runner get"

output="$(run_jumpdir ls)"
assert_contains "$output" "alpha"
assert_contains "$output" "beta"
assert_contains "$output" "gamma"
assert_not_contains "$output" "not-a-project"

update_prompt_output="$(
  printf 'n\n' |
    env JUMPDIR_FORCE_UPDATE_CHECK=1 JUMPDIR_SOURCE_URL="file://$NEWER_JUMPDIR" JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JUMPDIR" ls 2>&1
)"
assert_contains "$update_prompt_output" "jumpdir update available."
assert_contains "$update_prompt_output" "Current version: 0.3.0"
assert_contains "$update_prompt_output" "Latest version:  9.9.9"
assert_contains "$update_prompt_output" "Update now? [Y/n]"
assert_contains "$update_prompt_output" "alpha"
assert_contains "$update_prompt_output" "gamma"

update_prompt_second_output="$(
  printf 'n\n' |
    env JUMPDIR_FORCE_UPDATE_CHECK=1 JUMPDIR_SOURCE_URL="file://$NEWER_JUMPDIR" JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JUMPDIR" ls 2>&1
)"
assert_not_contains "$update_prompt_second_output" "jumpdir update available."
assert_contains "$update_prompt_second_output" "alpha"

output="$(run_jumpdir complete projects)"
assert_contains "$output" "alpha"
assert_contains "$output" "beta"
assert_contains "$output" "gamma"
assert_not_contains "$output" "not-a-project"

output="$(run_jumpdir rename alpha a)"
assert_contains "$output" "Renamed alpha to a."
output="$(run_jumpdir ls)"
assert_contains "$output" "a"
assert_contains "$output" "$TMP_DIR/root-a/alpha"
output="$(run_jumpdir complete projects)"
assert_contains "$output" "a"
assert_contains "$output" "beta"
assert_contains "$output" "gamma"

output="$(run_jumpdir complete scripts gamma)"
assert_contains "$output" "dev"
assert_contains "$output" "dev-2"
assert_contains "$output" "build"

set +e
unknown_completion_output="$(run_jumpdir complete scripts not-a-real-project 2>&1)"
unknown_completion_status="$?"
set -e
[ "$unknown_completion_status" -eq 0 ] || fail "expected unknown completion to exit 0"
assert_eq "$unknown_completion_output" ""

run_jumpdir open a
assert_file_contains "$JUMPDIR_TEST_LOG" "open|"
assert_file_contains "$JUMPDIR_TEST_LOG" "$TMP_DIR/root-a/alpha"

run_jumpdir . beta
assert_file_contains "$JUMPDIR_TEST_LOG" "code|"
assert_file_contains "$JUMPDIR_TEST_LOG" "$TMP_DIR/root-a/beta"

assert_eq "$(run_jumpdir path gamma)" "$TMP_DIR/root-b/gamma"
assert_eq "$(run_jumpdir cd gamma)" "$TMP_DIR/root-b/gamma"
assert_eq "$(run_jumpdir gamma)" "$TMP_DIR/root-b/gamma"

output="$(run_jumpdir gamma '?')"
assert_contains "$output" "$TMP_DIR/root-b/gamma"
assert_contains "$output" "Available commands for gamma:"
assert_contains "$output" "jumpdir cd gamma"
assert_contains "$output" "Scripts:"
assert_contains "$output" "jumpdir gamma dev"
assert_contains "$output" "jumpdir gamma run build"
assert_contains "$output" "Package manager commands:"
assert_contains "$output" "jumpdir gamma bun install"

output="$(run_jumpdir gamma help)"
assert_contains "$output" "Available commands for gamma:"
assert_contains "$output" "jumpdir gamma run build"

: > "$JUMPDIR_TEST_LOG"
run_jumpdir runner set pnpm >/dev/null
set +e
invalid_script_output="$(run_jumpdir gamma dev2 2>&1)"
invalid_script_status="$?"
set -e
[ "$invalid_script_status" -eq 64 ] || fail "expected invalid script to exit 64"
assert_contains "$invalid_script_output" "script not found: dev2"
assert_contains "$invalid_script_output" "available script names on your project \"gamma\""
assert_contains "$invalid_script_output" "[dev]"
assert_contains "$invalid_script_output" "[dev-2]"
assert_contains "$invalid_script_output" "[build]"
assert_eq "$(wc -l < "$JUMPDIR_TEST_LOG" | tr -d ' ')" "0"

run_jumpdir gamma dev --watch
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|run dev -- --watch"

run_jumpdir gamma run build --mode production
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|run build -- --mode production"

: > "$JUMPDIR_TEST_LOG"
run_jumpdir runner clear >/dev/null
set +e
invalid_explicit_script_output="$(run_jumpdir gamma bun run dev2 2>&1)"
invalid_explicit_script_status="$?"
set -e
[ "$invalid_explicit_script_status" -eq 64 ] || fail "expected invalid explicit script to exit 64"
assert_contains "$invalid_explicit_script_output" "script not found: dev2"
assert_contains "$invalid_explicit_script_output" "available script names on your project \"gamma\""
assert_contains "$invalid_explicit_script_output" "[dev]"
assert_contains "$invalid_explicit_script_output" "[dev-2]"
assert_contains "$invalid_explicit_script_output" "[build]"
assert_eq "$(wc -l < "$JUMPDIR_TEST_LOG" | tr -d ' ')" "0"

run_jumpdir gamma bun run build --mode production
assert_file_contains "$JUMPDIR_TEST_LOG" "bun|$TMP_DIR/root-b/gamma|run build -- --mode production"

: > "$JUMPDIR_TEST_LOG"
run_jumpdir gamma bun install --frozen-lockfile
assert_file_contains "$JUMPDIR_TEST_LOG" "bun|$TMP_DIR/root-b/gamma|install --frozen-lockfile"

run_jumpdir gamma pnpm add react
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|add react"

set +e
missing_runner_output="$(run_jumpdir gamma dev 2>&1)"
missing_runner_status="$?"
set -e
[ "$missing_runner_status" -eq 64 ] || fail "expected missing runner to exit 64"
assert_contains "$missing_runner_output" "no preferred runner is set"
assert_contains "$missing_runner_output" "jumpdir gamma bun run dev"

set +e
missing_run_keyword_output="$(run_jumpdir gamma run dev 2>&1)"
missing_run_keyword_status="$?"
set -e
[ "$missing_run_keyword_status" -eq 64 ] || fail "expected missing run keyword runner to exit 64"
assert_contains "$missing_run_keyword_output" "no preferred runner is set"
assert_contains "$missing_run_keyword_output" "jumpdir gamma run dev"

init_output="$(run_jumpdir init zsh)"
assert_contains "$init_output" "jumpdir()"
assert_contains "$init_output" "_jumpdir()"
assert_contains "$init_output" "compdef _jumpdir jumpdir"
assert_contains "$init_output" "__jumpdir_bin="
assert_contains "$init_output" "\"\${__jumpdir_bin[@]}\" complete projects"
assert_contains "$init_output" "\"\${__jumpdir_bin[@]}\" complete scripts"
assert_contains "$init_output" "\"\${__jumpdir_bin[@]}\" path"
assert_contains "$init_output" "cd)"
printf '%s\n' "$init_output" > "$TMP_DIR/jumpdir.zsh"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$TMP_DIR/jumpdir.zsh"
  output="$(PATH="$ROOT_DIR/bin:$PATH" JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" zsh -c "source '$TMP_DIR/jumpdir.zsh'; jumpdir cd gamma; pwd")"
  assert_eq "$output" "$TMP_DIR/root-b/gamma"
fi

compat_init_output="$(JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$TERMCODE" init zsh)"
assert_contains "$compat_init_output" "termcode()"
assert_contains "$compat_init_output" "_termcode()"
assert_contains "$compat_init_output" "compdef _termcode termcode"

make_project "$TMP_DIR/root-b/alpha"
set +e
duplicate_output="$(run_jumpdir ls 2>&1)"
duplicate_status="$?"
set -e
[ "$duplicate_status" -eq 65 ] || fail "expected duplicate ls to exit 65, got $duplicate_status"
assert_contains "$duplicate_output" "duplicate project name \"alpha\""
assert_contains "$duplicate_output" "$TMP_DIR/root-a/alpha"
assert_contains "$duplicate_output" "$TMP_DIR/root-b/alpha"

output="$(JUMPDIR_INSTALL_DIR="$TMP_DIR/install-local" bash "$ROOT_DIR/install.sh")"
assert_contains "$output" "Installed jumpdir to $TMP_DIR/install-local/jumpdir"
assert_contains "$output" "Installed termcode compatibility command to $TMP_DIR/install-local/termcode"
assert_contains "$("$TMP_DIR/install-local/jumpdir" --version)" "jumpdir 0.3.0"
assert_contains "$("$TMP_DIR/install-local/termcode" --version)" "termcode 0.3.0"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/remote-install.sh"
output="$(JUMPDIR_INSTALL_DIR="$TMP_DIR/install-remote" JUMPDIR_SOURCE_URL="file://$JUMPDIR" bash "$TMP_DIR/remote-install.sh")"
assert_contains "$output" "Downloading jumpdir from file://$JUMPDIR"
assert_contains "$output" "Installed jumpdir to $TMP_DIR/install-remote/jumpdir"
assert_contains "$output" "Installed termcode compatibility command to $TMP_DIR/install-remote/termcode"
assert_contains "$("$TMP_DIR/install-remote/jumpdir" --version)" "jumpdir 0.3.0"
assert_contains "$("$TMP_DIR/install-remote/termcode" --version)" "termcode 0.3.0"

output="$(JUMPDIR_INSTALL_DIR="$TMP_DIR/install-piped" JUMPDIR_SOURCE_URL="file://$JUMPDIR" bash < "$ROOT_DIR/install.sh")"
assert_contains "$output" "Downloading jumpdir from file://$JUMPDIR"
assert_contains "$output" "Installed jumpdir to $TMP_DIR/install-piped/jumpdir"
assert_contains "$output" "Installed termcode compatibility command to $TMP_DIR/install-piped/termcode"
assert_contains "$("$TMP_DIR/install-piped/jumpdir" --version)" "jumpdir 0.3.0"
assert_contains "$("$TMP_DIR/install-piped/termcode" --version)" "termcode 0.3.0"

mkdir -p "$TMP_DIR/readonly"
chmod 555 "$TMP_DIR/readonly"
set +e
readonly_output="$(JUMPDIR_INSTALL_DIR="$TMP_DIR/readonly" JUMPDIR_SOURCE_URL="file://$JUMPDIR" bash < "$ROOT_DIR/install.sh" 2>&1)"
readonly_status="$?"
set -e
chmod 755 "$TMP_DIR/readonly"
[ "$readonly_status" -eq 1 ] || fail "expected readonly install to exit 1, got $readonly_status"
assert_contains "$readonly_output" "Cannot write to $TMP_DIR/readonly."
assert_contains "$readonly_output" "sudo env JUMPDIR_INSTALL_DIR=\"$TMP_DIR/readonly\" bash"

printf 'ok - jumpdir behavior\n'
