#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JUMPDIR="$ROOT_DIR/bin/jumpdir"
JD="$ROOT_DIR/bin/jd"
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

assert_line_count() {
  local text expected actual
  text="$1"
  expected="$2"
  actual="$(printf '%s\n' "$text" | awk 'NF { count += 1 } END { print count + 0 }')"
  [ "$actual" -eq "$expected" ] || fail "expected $expected non-empty lines, got $actual"$'\n'"actual: $text"
}

assert_not_line() {
  local text unexpected
  text="$1"
  unexpected="$2"
  if printf '%s\n' "$text" | grep -Fxq "$unexpected"; then
    fail "expected output not to contain line: $unexpected"$'\n'"actual: $text"
  fi
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

run_jumpdir_picker() {
  local keys output_file
  keys="$1"
  output_file="$2"
  shift 2

  JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" JUMPDIR_TEST_LOG="$JUMPDIR_TEST_LOG" expect -f - "$JUMPDIR" "$keys" "$@" > "$output_file" 2>&1 <<'EXPECT'
set timeout 5
set jumpdir [lindex $argv 0]
set keys [lindex $argv 1]
set args [lrange $argv 2 end]
set decoded_keys [subst -nocommands -novariables $keys]

spawn bash $jumpdir {*}$args
expect {
  "Select a script" {}
  eof {}
  timeout { exit 124 }
}
send -- $decoded_keys
expect eof
set result [wait]
exit [lindex $result 3]
EXPECT
}

run_history_picker() {
  local keys output_file
  keys="$1"
  output_file="$2"
  shift 2

  JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" JUMPDIR_TEST_LOG="$JUMPDIR_TEST_LOG" expect -f - "$JUMPDIR" "$keys" "$@" > "$output_file" 2>&1 <<'EXPECT'
set timeout 5
set jumpdir [lindex $argv 0]
set keys [lindex $argv 1]
set args [lrange $argv 2 end]
set decoded_keys [subst -nocommands -novariables $keys]

spawn bash $jumpdir history {*}$args
expect {
  "Select a command" {}
  eof {}
  timeout { exit 124 }
}
send -- $decoded_keys
expect eof
set result [wait]
exit [lindex $result 3]
EXPECT
}

run_history_interrupt_restore() {
  local output_file
  output_file="$1"

  JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" JUMPDIR_TEST_LOG="$JUMPDIR_TEST_LOG" expect -f - "$JUMPDIR" > "$output_file" 2>&1 <<'EXPECT'
set timeout 5
set jumpdir [lindex $argv 0]

spawn bash -c {trap : INT; bash "$1" history -f replay-safe -c 1; rc=$?; trap - INT; stty -a; exit "$rc"} jumpdir-history "$jumpdir"
expect {
  "Select a command" {}
  eof {}
  timeout { exit 124 }
}
send -- "\003"
expect eof
set result [wait]
exit [lindex $result 3]
EXPECT
}

run_zsh_history_jump_picker() {
  local output_file zsh_init start_dir
  output_file="$1"
  zsh_init="$2"
  start_dir="$3"

  JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" expect -f - "$zsh_init" "$start_dir" > "$output_file" 2>&1 <<'EXPECT'
set timeout 5
set zsh_init [lindex $argv 0]
set start_dir [lindex $argv 1]

spawn zsh -c {source "$1"; cd "$2"; jd gamma; cd "$2"; jd history -f "jd gamma" -c 1; pwd} jumpdir-history "$zsh_init" "$start_dir"
expect {
  "Select a command" {}
  eof {}
  timeout { exit 124 }
}
send -- "\r"
expect eof
set result [wait]
exit [lindex $result 3]
EXPECT
}

run_zsh_history_action_picker() {
  local output_file zsh_init
  output_file="$1"
  zsh_init="$2"

  JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" JUMPDIR_TEST_LOG="$JUMPDIR_TEST_LOG" expect -f - "$zsh_init" > "$output_file" 2>&1 <<'EXPECT'
set timeout 5
set zsh_init [lindex $argv 0]

spawn zsh -c {source "$1"; jd history -f replay-safe -c 1} jumpdir-history "$zsh_init"
expect {
  "Select a command" {}
  eof {}
  timeout { exit 124 }
}
send -- "\r"
expect eof
set result [wait]
exit [lindex $result 3]
EXPECT
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
assert_contains "$output" "jumpdir history"
assert_contains "$output" "jumpdir alias <name-or-path> <as>"
assert_contains "$output" "Short command:"
assert_contains "$output" "jd"
assert_not_contains "$output" "jumpdir rename <name-or-path> <as>"
assert_not_contains "$output" "Welcome to jumpdir."

output="$(JUMPDIR_CONFIG_DIR="$TMP_DIR/compat-config" bash "$TERMCODE" --help)"
assert_contains "$output" "termcode - jump into and run scripts for local repos"
assert_contains "$output" "termcode runner set <runner|none>"

output="$(JUMPDIR_CONFIG_DIR="$TMP_DIR/jd-config" bash "$JD" --help)"
assert_contains "$output" "jd - jump into and run scripts for local repos"
assert_contains "$output" "jd alias <name-or-path> <as>"
assert_contains "$output" "jd runner set <runner|none>"
assert_contains "$output" "jd history"
assert_not_contains "$output" "Short command:"
assert_not_contains "$output" "jumpdir alias <name-or-path> <as>"

output="$(JUMPDIR_SOURCE_URL="file://$JUMPDIR" bash "$JUMPDIR" update)"
assert_contains "$output" "Current version: 0.4.0"
assert_contains "$output" "Latest version:  0.4.0"
assert_contains "$output" "jumpdir is up to date."

NEWER_JUMPDIR="$TMP_DIR/newer-jumpdir"
printf '#!/usr/bin/env bash\nVERSION="9.9.9"\n' > "$NEWER_JUMPDIR"
output="$(JUMPDIR_SOURCE_URL="file://$NEWER_JUMPDIR" bash "$JUMPDIR" update)"
assert_contains "$output" "Current version: 0.4.0"
assert_contains "$output" "Latest version:  9.9.9"
assert_contains "$output" "A newer jumpdir version is available."
assert_contains "$output" "curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/jumpdir/main/install.sh | bash"

READONLY_XDG_CONFIG_HOME="$TMP_DIR/readonly-xdg"
mkdir -p "$READONLY_XDG_CONFIG_HOME"
chmod 500 "$READONLY_XDG_CONFIG_HOME"
set +e
readonly_update_output="$(
  env JUMPDIR_FORCE_UPDATE_CHECK=1 JUMPDIR_SOURCE_URL="file://$JUMPDIR" XDG_CONFIG_HOME="$READONLY_XDG_CONFIG_HOME" bash "$JUMPDIR" set 2>&1
)"
readonly_update_status="$?"
set -e
chmod 700 "$READONLY_XDG_CONFIG_HOME"
[ "$readonly_update_status" -eq 64 ] || fail "expected readonly update marker command to exit 64"
assert_contains "$readonly_update_output" "jumpdir: set requires at least one path"
assert_contains "$readonly_update_output" "Usage:"

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
output="$(XDG_CONFIG_HOME="$LEGACY_XDG_CONFIG_HOME" bash "$JUMPDIR" ls 2>&1)"
assert_contains "$output" "Migrated config from termcode to jumpdir."
assert_contains "$output" "alpha"
assert_contains "$output" "beta"
assert_not_contains "$output" "gamma"
assert_file_contains "$LEGACY_XDG_CONFIG_HOME/jumpdir/roots" "$TMP_DIR/root-a"
assert_file_contains "$LEGACY_XDG_CONFIG_HOME/termcode/roots" "$TMP_DIR/root-a"
printf '%s\n' "$TMP_DIR/root-b" > "$LEGACY_XDG_CONFIG_HOME/termcode/roots"
output="$(XDG_CONFIG_HOME="$LEGACY_XDG_CONFIG_HOME" bash "$JUMPDIR" ls 2>&1)"
assert_not_contains "$output" "Migrated config from termcode to jumpdir."
assert_contains "$output" "alpha"
assert_contains "$output" "beta"
assert_not_contains "$output" "gamma"

output="$(TERMCODE_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JUMPDIR" runner get)"
assert_eq "$output" "pnpm"

output="$(run_jumpdir)"
assert_contains "$output" "Usage:"
assert_not_contains "$output" "Welcome to jumpdir."

output="$(run_jumpdir history)"
assert_contains "$output" "No jumpdir history yet."

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
assert_contains "$update_prompt_output" "Current version: 0.4.0"
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

output="$(run_jumpdir alias alpha a)"
assert_contains "$output" "Aliased alpha as a."
output="$(run_jumpdir ls)"
assert_contains "$output" "a"
assert_contains "$output" "$TMP_DIR/root-a/alpha"
output="$(run_jumpdir complete projects)"
assert_contains "$output" "a"
assert_contains "$output" "beta"
assert_contains "$output" "gamma"

output="$(run_jumpdir rename beta b)"
assert_contains "$output" "Aliased beta as b."
output="$(run_jumpdir ls)"
assert_contains "$output" "b"
assert_contains "$output" "$TMP_DIR/root-a/beta"

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

history_output="$(run_jumpdir history)"
assert_contains "$history_output" "jumpdir gamma"
assert_contains "$history_output" "jumpdir cd gamma"
assert_contains "$history_output" "jumpdir . beta"
assert_contains "$history_output" "jumpdir open a"
assert_not_contains "$history_output" "jumpdir path gamma"
assert_not_contains "$history_output" "jumpdir runner"
assert_not_contains "$history_output" "jumpdir ls"
assert_not_contains "$history_output" "jumpdir history"
assert_not_contains "$history_output" "not-a-real-project"
assert_eq "$(printf '%s\n' "$history_output" | sed -n '1p')" "jumpdir gamma"
assert_file_contains "$TEST_CONFIG_DIR/history" "jd gamma"

filtered_history_output="$(run_jumpdir history --filter OPEN --count 1)"
assert_eq "$filtered_history_output" "jumpdir open a"
filtered_history_output="$(run_jumpdir history -c 1 -f '.*')"
assert_contains "$filtered_history_output" 'No jumpdir history matched ".*".'

set +e
invalid_history_output="$(run_jumpdir history --count 0 2>&1)"
invalid_history_status="$?"
set -e
[ "$invalid_history_status" -eq 64 ] || fail "expected invalid history count to exit 64"
assert_contains "$invalid_history_output" "history count must be a positive number"

set +e
repeated_history_filter_output="$(run_jumpdir history -f gamma --filter dev 2>&1)"
repeated_history_filter_status="$?"
repeated_history_count_output="$(run_jumpdir history -c 1 --count 2 2>&1)"
repeated_history_count_status="$?"
missing_history_filter_output="$(run_jumpdir history --filter 2>&1)"
missing_history_filter_status="$?"
missing_history_count_output="$(run_jumpdir history --count 2>&1)"
missing_history_count_status="$?"
nonnumeric_history_count_output="$(run_jumpdir history --count ten 2>&1)"
nonnumeric_history_count_status="$?"
negative_history_count_output="$(run_jumpdir history --count -2 2>&1)"
negative_history_count_status="$?"
unknown_history_option_output="$(run_jumpdir history --unknown 2>&1)"
unknown_history_option_status="$?"
set -e
[ "$repeated_history_filter_status" -eq 64 ] || fail "expected repeated history filter to exit 64"
assert_contains "$repeated_history_filter_output" "history filter may only be provided once"
[ "$repeated_history_count_status" -eq 64 ] || fail "expected repeated history count to exit 64"
assert_contains "$repeated_history_count_output" "history count may only be provided once"
[ "$missing_history_filter_status" -eq 64 ] || fail "expected missing history filter to exit 64"
assert_contains "$missing_history_filter_output" "history filter requires text"
[ "$missing_history_count_status" -eq 64 ] || fail "expected missing history count to exit 64"
assert_contains "$missing_history_count_output" "history count requires a positive number"
[ "$nonnumeric_history_count_status" -eq 64 ] || fail "expected nonnumeric history count to exit 64"
assert_contains "$nonnumeric_history_count_output" "history count must be a positive number"
[ "$negative_history_count_status" -eq 64 ] || fail "expected negative history count to exit 64"
assert_contains "$negative_history_count_output" "history count must be a positive number"
[ "$unknown_history_option_status" -eq 64 ] || fail "expected unknown history option to exit 64"
assert_contains "$unknown_history_option_output" "unknown history option: --unknown"

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

: > "$JUMPDIR_TEST_LOG"
run_jumpdir runner set pnpm >/dev/null
picker_output="$TMP_DIR/picker-output.txt"
run_jumpdir_picker "\033\[B\r" "$picker_output" gamma dev2 --watch
assert_file_contains "$picker_output" "script not found: dev2"
assert_file_contains "$picker_output" "Select a script for gamma:"
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|run dev-2 -- --watch"
corrected_history_output="$(run_jumpdir history -f 'gamma dev-2 --watch' -c 1)"
assert_eq "$corrected_history_output" "jumpdir gamma dev-2 --watch"

: > "$JUMPDIR_TEST_LOG"
explicit_picker_output="$TMP_DIR/explicit-picker-output.txt"
run_jumpdir_picker "\033\[B\033\[B\r" "$explicit_picker_output" gamma bun run dev2 --mode production
assert_file_contains "$explicit_picker_output" "script not found: dev2"
assert_file_contains "$explicit_picker_output" "Select a script for gamma:"
assert_file_contains "$JUMPDIR_TEST_LOG" "bun|$TMP_DIR/root-b/gamma|run build -- --mode production"

: > "$JUMPDIR_TEST_LOG"
cancel_picker_output="$TMP_DIR/cancel-picker-output.txt"
set +e
run_jumpdir_picker "\033" "$cancel_picker_output" gamma missing
cancel_picker_status="$?"
set -e
[ "$cancel_picker_status" -eq 130 ] || fail "expected picker cancel to exit 130"
assert_file_contains "$cancel_picker_output" "Canceled."
assert_eq "$(wc -l < "$JUMPDIR_TEST_LOG" | tr -d ' ')" "0"

run_jumpdir gamma bun run build --mode production
assert_file_contains "$JUMPDIR_TEST_LOG" "bun|$TMP_DIR/root-b/gamma|run build -- --mode production"

: > "$JUMPDIR_TEST_LOG"
run_jumpdir gamma bun install --frozen-lockfile
assert_file_contains "$JUMPDIR_TEST_LOG" "bun|$TMP_DIR/root-b/gamma|install --frozen-lockfile"

run_jumpdir gamma pnpm add react
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|add react"

run_jumpdir gamma pnpm exec "space value" 'quote"value' 'semi;colon' >/dev/null
escaped_history_output="$(run_jumpdir history -f 'space' -c 1)"
assert_contains "$escaped_history_output" 'space\ value'
assert_contains "$escaped_history_output" 'quote\"value'
assert_contains "$escaped_history_output" 'semi\;colon'

run_jumpdir gamma pnpm exec duplicate-entry >/dev/null
run_jumpdir gamma pnpm exec duplicate-entry >/dev/null
duplicate_history_output="$(run_jumpdir history -f duplicate-entry --count 10)"
assert_line_count "$duplicate_history_output" 1

history_index=1
while [ "$history_index" -le 205 ]; do
  run_jumpdir gamma pnpm exec "retention-$history_index" >/dev/null 2>&1
  history_index=$((history_index + 1))
done
retained_history_output="$(run_jumpdir history --count 500)"
assert_line_count "$retained_history_output" 200
assert_contains "$retained_history_output" "jumpdir gamma pnpm exec retention-205"
assert_not_line "$retained_history_output" "jumpdir gamma pnpm exec retention-5"
default_history_output="$(run_jumpdir history)"
assert_line_count "$default_history_output" 20
huge_count_history_output="$(run_jumpdir history --count 999999999999999999999999999999)"
assert_line_count "$huge_count_history_output" 200

history_index=1
while [ "$history_index" -le 8 ]; do
  run_jumpdir gamma pnpm exec "concurrent-$history_index" >/dev/null 2>&1 &
  history_index=$((history_index + 1))
done
wait
concurrent_history_output="$(run_jumpdir history -f concurrent --count 20)"
assert_line_count "$concurrent_history_output" 8
all_history_output="$(run_jumpdir history --count 500)"
assert_line_count "$all_history_output" 200
unique_history_output="$(printf '%s\n' "$all_history_output" | sort -u)"
assert_line_count "$unique_history_output" 200

run_jumpdir gamma pnpm exec replay-first >/dev/null
run_jumpdir gamma pnpm exec replay-second >/dev/null
: > "$JUMPDIR_TEST_LOG"
history_picker_output="$TMP_DIR/history-picker-output.txt"
run_history_picker "\033\[B\r" "$history_picker_output" -f replay- --count 2
assert_file_contains "$history_picker_output" "Select a command"
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|exec replay-first"

: > "$JUMPDIR_TEST_LOG"
wrap_history_picker_output="$TMP_DIR/wrap-history-picker-output.txt"
run_history_picker "\033\[A\r" "$wrap_history_picker_output" -f replay- --count 2
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|exec replay-second"

injection_file="$TMP_DIR/history-injection"
run_jumpdir gamma pnpm exec replay-safe "safe;touch $injection_file" >/dev/null
: > "$JUMPDIR_TEST_LOG"
safe_history_picker_output="$TMP_DIR/safe-history-picker-output.txt"
run_history_picker "\r" "$safe_history_picker_output" -f replay-safe -c 1
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|exec replay-safe safe;touch $injection_file"
[ ! -e "$injection_file" ] || fail "history replay executed shell syntax from an argument"
output="$(JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JD" history -f replay-safe -c 1)"
assert_contains "$output" "jd gamma pnpm exec replay-safe"
output="$(JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$TERMCODE" history -f replay-safe -c 1)"
assert_contains "$output" "termcode gamma pnpm exec replay-safe"

: > "$JUMPDIR_TEST_LOG"
cancel_history_picker_output="$TMP_DIR/cancel-history-picker-output.txt"
set +e
run_history_picker "\033" "$cancel_history_picker_output" -f replay-safe
cancel_history_picker_status="$?"
set -e
[ "$cancel_history_picker_status" -eq 130 ] || fail "expected history picker cancel to exit 130"
assert_file_contains "$cancel_history_picker_output" "Canceled."
assert_eq "$(wc -l < "$JUMPDIR_TEST_LOG" | tr -d ' ')" "0"

: > "$JUMPDIR_TEST_LOG"
interrupt_history_picker_output="$TMP_DIR/interrupt-history-picker-output.txt"
set +e
run_history_interrupt_restore "$interrupt_history_picker_output"
interrupt_history_picker_status="$?"
set -e
[ "$interrupt_history_picker_status" -eq 130 ] ||
  fail "expected history picker Ctrl-C to exit 130"$'\n'"$(sed -n '1,160p' "$interrupt_history_picker_output")"
assert_file_contains "$interrupt_history_picker_output" "icanon"
assert_file_contains "$interrupt_history_picker_output" "echo"
assert_eq "$(wc -l < "$JUMPDIR_TEST_LOG" | tr -d ' ')" "0"

mkdir "$TEST_CONFIG_DIR/history.lock"
printf '%s\n' "$$" > "$TEST_CONFIG_DIR/history.lock/owner"
: > "$JUMPDIR_TEST_LOG"
busy_history_output="$(run_jumpdir gamma pnpm exec busy-history 2>&1)"
rm -f "$TEST_CONFIG_DIR/history.lock/owner"
rmdir "$TEST_CONFIG_DIR/history.lock"
assert_contains "$busy_history_output" "command history is busy; command was not recorded"
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|exec busy-history"
busy_history_listing="$(run_jumpdir history -f busy-history)"
assert_contains "$busy_history_listing" 'No jumpdir history matched "busy-history".'

mkdir "$TEST_CONFIG_DIR/history.lock"
printf '%s\n' "$$" > "$TEST_CONFIG_DIR/history.lock/owner"
mkdir "$TEST_CONFIG_DIR/history.lock/reap"
abandoned_reaper_output="$(run_jumpdir gamma pnpm exec abandoned-reaper 2>&1)"
rmdir "$TEST_CONFIG_DIR/history.lock/reap"
rm -f "$TEST_CONFIG_DIR/history.lock/owner"
rmdir "$TEST_CONFIG_DIR/history.lock"
assert_contains "$abandoned_reaper_output" "command history is busy; command was not recorded"
assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|exec abandoned-reaper"

stale_history_owner=999999999
mkdir "$TEST_CONFIG_DIR/history.lock"
printf '%s\n' "$stale_history_owner" > "$TEST_CONFIG_DIR/history.lock/owner"
run_jumpdir gamma pnpm exec stale-lock-reclaimed-a >/dev/null &
stale_writer_a=$!
run_jumpdir gamma pnpm exec stale-lock-reclaimed-b >/dev/null &
stale_writer_b=$!
wait "$stale_writer_a"
wait "$stale_writer_b"
stale_history_listing="$(run_jumpdir history -f stale-lock-reclaimed -c 2)"
assert_contains "$stale_history_listing" "jumpdir gamma pnpm exec stale-lock-reclaimed-a"
assert_contains "$stale_history_listing" "jumpdir gamma pnpm exec stale-lock-reclaimed-b"
[ ! -e "$TEST_CONFIG_DIR/history.lock" ] || fail "expected stale history lock to be reclaimed"

set +e
missing_executable_output="$(
  PATH="/usr/bin:/bin" JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JUMPDIR" gamma yarn exec missing-executable 2>&1
)"
missing_executable_status="$?"
set -e
[ "$missing_executable_status" -eq 1 ] || fail "expected missing executable action to exit 1"
assert_contains "$missing_executable_output" "required command not found: yarn"
missing_executable_history="$(run_jumpdir history -f missing-executable)"
assert_contains "$missing_executable_history" 'No jumpdir history matched "missing-executable".'

run_jumpdir runner clear >/dev/null

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
assert_contains "$init_output" "history_options="
assert_contains "$init_output" "JUMPDIR_HISTORY_EMIT0=1"
assert_contains "$init_output" "JUMPDIR_HISTORY_RECORD_ONLY=1"
assert_contains "$init_output" "cd)"
printf '%s\n' "$init_output" > "$TMP_DIR/jumpdir.zsh"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$TMP_DIR/jumpdir.zsh"
  output="$(PATH="$ROOT_DIR/bin:$PATH" JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" zsh -c "source '$TMP_DIR/jumpdir.zsh'; jumpdir cd gamma; pwd")"
  assert_eq "$output" "$TMP_DIR/root-b/gamma"
fi

jd_init_output="$(JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" bash "$JD" init zsh)"
assert_contains "$jd_init_output" "jd()"
assert_contains "$jd_init_output" "_jd()"
assert_contains "$jd_init_output" "compdef _jd jd"
assert_contains "$jd_init_output" "__jumpdir_bin="
printf '%s\n' "$jd_init_output" > "$TMP_DIR/jd.zsh"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$TMP_DIR/jd.zsh"
  output="$(PATH="$ROOT_DIR/bin:$PATH" JUMPDIR_CONFIG_DIR="$TEST_CONFIG_DIR" zsh -c "source '$TMP_DIR/jd.zsh'; jd cd gamma; pwd; jd history -f 'jd cd gamma' -c 1")"
  assert_contains "$output" "$TMP_DIR/root-b/gamma"
  assert_eq "$(printf '%s\n' "$output" | sed -n '$p')" "jd cd gamma"

  zsh_history_jump_output="$TMP_DIR/zsh-history-jump-output.txt"
  set +e
  run_zsh_history_jump_picker "$zsh_history_jump_output" "$TMP_DIR/jd.zsh" "$TMP_DIR/root-a/alpha"
  zsh_history_jump_status="$?"
  set -e
  if [ "$zsh_history_jump_status" -ne 0 ]; then
    fail "expected zsh history jump picker to succeed"$'\n'"$(sed -n '1,160p' "$zsh_history_jump_output")"
  fi
  assert_file_contains "$zsh_history_jump_output" "Select a command"
  assert_file_contains "$zsh_history_jump_output" "$TMP_DIR/root-b/gamma"

  : > "$JUMPDIR_TEST_LOG"
  zsh_history_action_output="$TMP_DIR/zsh-history-action-output.txt"
  run_zsh_history_action_picker "$zsh_history_action_output" "$TMP_DIR/jd.zsh"
  assert_file_contains "$zsh_history_action_output" "Select a command"
  assert_file_contains "$JUMPDIR_TEST_LOG" "pnpm|$TMP_DIR/root-b/gamma|exec replay-safe safe;touch $injection_file"
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
assert_contains "$output" "Installed jd shortcut command to $TMP_DIR/install-local/jd"
assert_contains "$output" "Installed termcode compatibility command to $TMP_DIR/install-local/termcode"
assert_contains "$("$TMP_DIR/install-local/jumpdir" --version)" "jumpdir 0.4.0"
assert_contains "$("$TMP_DIR/install-local/jd" --version)" "jd 0.4.0"
assert_contains "$("$TMP_DIR/install-local/termcode" --version)" "termcode 0.4.0"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/remote-install.sh"
output="$(JUMPDIR_INSTALL_DIR="$TMP_DIR/install-remote" JUMPDIR_SOURCE_URL="file://$JUMPDIR" bash "$TMP_DIR/remote-install.sh")"
assert_contains "$output" "Downloading jumpdir from file://$JUMPDIR"
assert_contains "$output" "Installed jumpdir to $TMP_DIR/install-remote/jumpdir"
assert_contains "$output" "Installed jd shortcut command to $TMP_DIR/install-remote/jd"
assert_contains "$output" "Installed termcode compatibility command to $TMP_DIR/install-remote/termcode"
assert_contains "$("$TMP_DIR/install-remote/jumpdir" --version)" "jumpdir 0.4.0"
assert_contains "$("$TMP_DIR/install-remote/jd" --version)" "jd 0.4.0"
assert_contains "$("$TMP_DIR/install-remote/termcode" --version)" "termcode 0.4.0"

output="$(JUMPDIR_INSTALL_DIR="$TMP_DIR/install-piped" JUMPDIR_SOURCE_URL="file://$JUMPDIR" bash < "$ROOT_DIR/install.sh")"
assert_contains "$output" "Downloading jumpdir from file://$JUMPDIR"
assert_contains "$output" "Installed jumpdir to $TMP_DIR/install-piped/jumpdir"
assert_contains "$output" "Installed jd shortcut command to $TMP_DIR/install-piped/jd"
assert_contains "$output" "Installed termcode compatibility command to $TMP_DIR/install-piped/termcode"
assert_contains "$("$TMP_DIR/install-piped/jumpdir" --version)" "jumpdir 0.4.0"
assert_contains "$("$TMP_DIR/install-piped/jd" --version)" "jd 0.4.0"
assert_contains "$("$TMP_DIR/install-piped/termcode" --version)" "termcode 0.4.0"

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
