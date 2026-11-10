#!/usr/bin/env bash
# shellcheck shell=bash
#
# Runs the whole test suite:
#
#   ./test/test.sh
#
# Everything happens in a temporary directory with fake package managers, so
# nothing is installed and neither the home directory nor ~/.gaudi is touched.
# The cases in cases.sh run once per available shell. When a Gaudi checkout is
# found (GAUDI_HELPER_TEST_GAUDI, or ../gaudi next to this repository), the
# files the helper wrote are also validated with `gaudi check`.
set -uo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
ORIGINAL_PATH="$PATH"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gaudi-helper-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
results="$tmp_dir/results"
: > "$results"

pass() {
    printf "ok - %s\n" "$1" >> "$results"
}

fail() {
    printf "not ok - %s\n" "$1" >> "$results"
    printf "not ok - %s\n" "$1" >&2
}

#   check <description> <command>...
check() {
    local description="$1"
    local output=""
    shift

    if output="$("$@" 2>&1)"; then
        pass "$description"
    else
        fail "$description"
        [[ -n "$output" ]] && printf "%s\n" "$output" | sed 's/^/    /' >&2
    fi
}

# --- Static checks -------------------------------------------------------------

shell_files=(gaudi-helper.sh install.sh lib/helper.sh lib/install-helper.sh lib/bash-prexec.sh test/test.sh test/cases.sh)
sourced_by_zsh=(gaudi-helper.sh lib/helper.sh test/cases.sh)

for file in "${shell_files[@]}"; do
    check "syntax: $file parses with /bin/bash" /bin/bash -n "$ROOT_DIR/$file"
done

if command -v zsh >/dev/null 2>&1; then
    for file in "${sourced_by_zsh[@]}"; do
        check "syntax: $file parses with zsh" zsh -n "$ROOT_DIR/$file"
    done
fi

if command -v shellcheck >/dev/null 2>&1; then
    for file in "${shell_files[@]}"; do
        # bash-prexec.sh is bundled third-party code
        [[ "$file" == "lib/bash-prexec.sh" ]] && continue
        check "shellcheck: $file" shellcheck -x -S warning "$ROOT_DIR/$file"
    done
else
    printf "skipped: shellcheck is not installed\n"
fi

# --- Fake package managers --------------------------------------------------------
# Each one logs how it was called and only answers the lookups the helper makes.

fakebin="$tmp_dir/bin"
calls="$tmp_dir/calls"
mkdir -p "$fakebin"
: > "$calls"

cat > "$fakebin/brew" <<'BREW'
#!/bin/bash
printf 'brew %s\n' "$*" >> "$GAUDI_HELPER_TEST_CALLS"
case "$1:$2" in
  desc:--eval-all)
    printf '%s: Description of %s\n' "$3" "$3"
    ;;
  info:--cask)
    printf '==> Description\nCask %s\nhttps://example.invalid/%s\n' "$3" "$3"
    ;;
  info:*)
    printf '%s: stable\nhttps://example.invalid/%s\n' "$2" "$2"
    ;;
esac
BREW

cat > "$fakebin/npm" <<'NPM'
#!/bin/bash
printf 'npm %s\n' "$*" >> "$GAUDI_HELPER_TEST_CALLS"
if [[ "$1" == "view" && "$3" == "description" ]]; then
  printf 'About %s\n' "$2"
elif [[ "$1" == "view" && "$3" == "homepage" ]]; then
  printf 'https://example.invalid/%s\n' "$2"
fi
NPM

cat > "$fakebin/mas" <<'MAS'
#!/bin/bash
printf 'mas %s\n' "$*" >> "$GAUDI_HELPER_TEST_CALLS"
case "$1:${2:-}" in
  list:)
    printf '497799835  Xcode       (15.4)\n'
    ;;
  info:1354318707)
    printf 'Core Tunnel 3.8.2 [Free]\nBy: Someone\n'
    ;;
  info:*)
    exit 1
    ;;
esac
MAS

cat > "$fakebin/apt-cache" <<'APT'
#!/bin/bash
printf 'apt-cache %s\n' "$*" >> "$GAUDI_HELPER_TEST_CALLS"
[[ "$1" == "show" ]] || exit 1
if [[ "$2" == "evil" ]]; then
  # A description that would run commands if it were not escaped
  printf '%s\n' 'Description: Say "hi" $(touch PWNED) `touch PWNED` \ done'
else
  printf 'Description: Description of %s\n' "$2"
fi
printf 'Homepage: https://example.invalid/%s\n' "$2"
APT

chmod +x "$fakebin/brew" "$fakebin/npm" "$fakebin/mas" "$fakebin/apt-cache"

# --- The cases, once per shell -------------------------------------------------------

# Brewfile lines Gaudi and Homebrew accept, for when `gaudi check` is not around
brewfile_line='^((tap|brew|cask|npm|uv|go|cargo|vscode) ["'"'"'][^"'"'"']+["'"'"'](, "[^"]+")?|mas "[^"]+", id: [0-9]+|cask_args .*|#.*|)$'

#   valid_templates <directory>
valid_templates() {
    local directory="$1"
    local file=""
    local list_name=""
    local status=0

    while IFS= read -r file; do
        if grep -Evn "$brewfile_line" "$file"; then
            printf "%s has lines that are not Brewfile entries\n" "$file"
            status=1
        fi
        if [[ -n "$(grep -E '^(tap|brew|cask|mas|npm|uv|go|cargo|vscode) ' "$file" | sort | uniq -d)" ]]; then
            printf "%s lists an entry twice\n" "$file"
            status=1
        fi
        grep -q '^# @Name: ' "$file" || [[ "$file" != "$directory/created/"* ]] || {
            printf "%s was created without a # @Name header\n" "$file"
            status=1
        }
    done < <(find "$directory" -type f \( -name "Brewfile" -o -name "*.Brewfile" \) -print)

    while IFS= read -r file; do
        list_name="$(sed -n 's/^# @List: *//p' "$file" | head -n 1)"
        if ! /bin/bash -c 'source "$1" >/dev/null 2>&1 && eval "[[ \${#$2[@]} -gt 0 ]]"' _ "$file" "$list_name"; then
            printf "%s does not define a non-empty %s array\n" "$file" "$list_name"
            status=1
        fi
    done < <(find "$directory" -type f -name "*.sh" -print)

    return "$status"
}

gaudi_cli="${GAUDI_HELPER_TEST_GAUDI:-$ROOT_DIR/../gaudi}/bin/gaudi"

#   gaudi_check <templates directory>: no errors and no warnings
gaudi_check() {
    local output=""

    # A scratch home, the real PATH (so Homebrew, when installed, parses the
    # Brewfiles too) and no GAUDI variables from the environment
    output="$(env -u GAUDI -u GAUDI_TEMPLATES_LOCATION HOME="$tmp_dir/check-home" PATH="$ORIGINAL_PATH" \
        HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 "$gaudi_cli" check "$1" 2>&1)" || {
        printf "%s\n" "$output"
        return 1
    }
    printf "%s\n" "$output" | grep -q ": 0 error(s), 0 warning(s)" || {
        printf "%s\n" "$output"
        return 1
    }
}

#   run_cases <label> <shell command>...
run_cases() {
    local label="$1"
    local work="$tmp_dir/$label"
    local directory=""
    shift

    mkdir -p "$work/work" "$work/home" "$work/prefix/Caskroom/firefox" "$tmp_dir/check-home"

    env -i \
        PATH="$fakebin:$ORIGINAL_PATH" \
        HOME="$work/home" \
        TMPDIR="$work" \
        GAUDI="$work/home/.gaudi" \
        HOMEBREW_PREFIX="$work/prefix" \
        GAUDI_HELPER_DIR="$ROOT_DIR" \
        GAUDI_HELPER_TEST_SHELL="$label" \
        GAUDI_HELPER_TEST_WORK="$work/work" \
        GAUDI_HELPER_TEST_RESULTS="$results" \
        GAUDI_HELPER_TEST_CALLS="$calls" \
        "$@" "$ROOT_DIR/test/cases.sh"
    if [[ "$?" -eq 0 ]]; then
        pass "[$label] the cases ran to the end"
    else
        fail "[$label] the cases ran to the end"
    fi

    check "[$label] every file the helper wrote has a valid format" valid_templates "$work/work"

    if [[ -x "$gaudi_cli" ]]; then
        for directory in created existing headed hooked; do
            check "[$label] gaudi check accepts the $directory templates" gaudi_check "$work/work/$directory"
        done
    fi
}

run_cases bash-3.2 /bin/bash --noprofile --norc
[[ "$(/bin/bash -c 'printf %s "${BASH_VERSINFO[0]}"')" == "3" ]] || printf "note: /bin/bash is not Bash 3.2 on this machine\n"

newer_bash="$(command -v bash 2>/dev/null || true)"
if [[ -n "$newer_bash" && "$newer_bash" != "/bin/bash" ]]; then
    run_cases bash "$newer_bash" --noprofile --norc
fi

if command -v zsh >/dev/null 2>&1; then
    run_cases zsh zsh -f
else
    printf "skipped: zsh is not installed\n"
fi

[[ -x "$gaudi_cli" ]] || printf "skipped: gaudi check (no Gaudi checkout at %s)\n" "${gaudi_cli%/bin/gaudi}"

# --- Installer ---------------------------------------------------------------------

helper_repo="$tmp_dir/helper-repo"
mkdir -p "$helper_repo"
cp -R "$ROOT_DIR/README.md" \
      "$ROOT_DIR/gaudi-helper.sh" \
      "$ROOT_DIR/install.sh" \
      "$ROOT_DIR/lib" \
      "$ROOT_DIR/test" \
      "$helper_repo/"
git -C "$helper_repo" -c init.defaultBranch=master init >/dev/null
git -C "$helper_repo" add . >/dev/null
git -C "$helper_repo" \
    -c user.email="gaudi-helper-test@example.invalid" \
    -c user.name="Gaudi Helper Test" \
    commit -m "test fixture" >/dev/null

#   install_for <shell> <profile file name>
install_for() {
    local shell_name="$1"
    local profile="$2"
    local install_home="$tmp_dir/install-$shell_name"

    mkdir -p "$install_home/.gaudi"
    check "install ($shell_name): install.sh succeeds" env \
        HOME="$install_home" \
        GAUDI="$install_home/.gaudi" \
        GAUDI_HELPER_REPO="$helper_repo" \
        GAUDI_HELPER_SHELL="$shell_name" \
        /bin/bash "$ROOT_DIR/install.sh"
    check "install ($shell_name): the helper is cloned into Gaudi" test -r "$install_home/.gaudi/gaudi-helper/gaudi-helper.sh"
    check "install ($shell_name): $profile sets GAUDI_HELPER_DIR" grep -Fq "export GAUDI_HELPER_DIR=\"$install_home/.gaudi/gaudi-helper\"" "$install_home/$profile"
    check "install ($shell_name): $profile sources the helper" grep -Fq 'source "$GAUDI_HELPER_DIR/gaudi-helper.sh"' "$install_home/$profile"

    cp "$install_home/$profile" "$install_home/profile.before"
    check "install ($shell_name): installing again succeeds" env \
        HOME="$install_home" \
        GAUDI="$install_home/.gaudi" \
        GAUDI_HELPER_REPO="$helper_repo" \
        GAUDI_HELPER_SHELL="$shell_name" \
        /bin/bash "$ROOT_DIR/install.sh"
    check "install ($shell_name): installing again does not repeat the profile lines" cmp -s "$install_home/profile.before" "$install_home/$profile"
}

bash_profile=".bashrc"
[[ "$(uname -s)" == "Darwin" ]] && bash_profile=".bash_profile"
install_for bash "$bash_profile"
check "install (bash): $bash_profile loads bash-preexec" grep -Fq 'bash-prexec.sh' "$tmp_dir/install-bash/$bash_profile"
install_for zsh ".zshrc"

check "install: refuses to run without Gaudi" /bin/bash -c '! HOME="$1" GAUDI="$1/.gaudi" /bin/bash "$2" >/dev/null 2>&1' _ "$tmp_dir/no-gaudi" "$ROOT_DIR/install.sh"

# --- Summary -----------------------------------------------------------------------

passed="$(grep -c '^ok ' "$results")"
failed="$(grep -c '^not ok ' "$results")"
printf "\n%s passed, %s failed\n" "$passed" "$failed"
[[ "$failed" -eq 0 ]]
