# shellcheck shell=bash
#
# The test cases. test.sh runs this file once per shell (Bash 3.2, a newer
# Bash when there is one, Zsh), so it only uses syntax those shells share.
#
# Expects: GAUDI_HELPER_DIR (the checkout under test), GAUDI_HELPER_TEST_WORK
# (an empty temporary directory), GAUDI_HELPER_TEST_RESULTS (a file that gets
# one "ok" or "not ok" line per assertion), HOME and HOMEBREW_PREFIX pointing
# into the temporary directory, and fake package managers first on PATH.

work="$GAUDI_HELPER_TEST_WORK"
results="$GAUDI_HELPER_TEST_RESULTS"
shell_name="${GAUDI_HELPER_TEST_SHELL:-shell}"

export GAUDI_HELPER_NO_HOOKS=true
# shellcheck source=/dev/null
source "$GAUDI_HELPER_DIR/gaudi-helper.sh"

pass() {
    printf "ok - [%s] %s\n" "$shell_name" "$1" >> "$results"
}

fail() {
    printf "not ok - [%s] %s\n" "$shell_name" "$1" >> "$results"
    printf "not ok - [%s] %s\n" "$shell_name" "$1" >&2
    [[ -n "${2:-}" ]] && printf "    %s\n" "$2" >&2
    return 0
}

#   is <description> <expected> <actual>
is() {
    if [[ "$2" == "$3" ]]; then
        pass "$1"
    else
        fail "$1" "expected: '$2' got: '$3'"
    fi
}

#   ok <description> <command>...
ok() {
    local description="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description" "failed: $*"
    fi
}

#   not_ok <description> <command>...
not_ok() {
    local description="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        fail "$description" "unexpectedly succeeded: $*"
    else
        pass "$description"
    fi
}

has_line() {
    command grep -Fxq -- "$2" "$1"
}

#   count_is <description> <file> <fixed text> <count>
count_is() {
    local found=""

    found="$(command grep -Fc -- "$3" "$2" 2>/dev/null)"
    is "$1" "$4" "${found:-0}"
}

#   file_is <description> <file> <expected content>
file_is() {
    local content=""

    content="$(command cat "$2" 2>/dev/null)"
    if [[ "$content" == "$3" ]]; then
        pass "$1"
    else
        fail "$1" "content of $2:
$content"
    fi
}

detects() {
    is "detect: $1" "$2" "$(gaudi_helper_detect_install "$1")"
}

ignores() {
    is "ignore: $1" "" "$(gaudi_helper_detect_install "$1")"
}

names() {
    is "name: $1 $2" "$3" "$(gaudi_helper_package_name "$1" "$2")"
}

#   run <command line>: what the hooks do after the command succeeded
run() {
    gaudi_helper_process_command "$1" >> "$work/output.log" 2>&1
}

# shellcheck disable=SC2034
use_templates() {
    GAUDI_HELPER_TEMPLATES_DIR="$1"
    GAUDI_HELPER_LIST_DIR="$1/lists"
}

# --- Which commands are recorded --------------------------------------------------

detects 'brew install jq' 'brew|jq'
detects 'brew install jq ripgrep' 'brew|jq ripgrep'
detects 'brew install --cask firefox' 'cask|firefox'
detects 'brew install firefox --cask' 'cask|firefox'
detects 'brew cask install firefox' 'cask|firefox'
detects 'brew install owner/tap/widget' 'brew|owner/tap/widget'
detects 'brew install -f jq' 'brew|jq'
detects 'command brew install --formula jq' 'brew|jq'
detects 'sudo -E brew install --cask --appdir /Applications firefox' 'cask|firefox'
detects 'env HOMEBREW_NO_AUTO_UPDATE=1 brew install jq' 'brew|jq'
detects 'brew tap owner/tools' 'tap|owner/tools'
detects 'brew tap owner/tools https://example.invalid/tools.git' 'tap|owner/tools https://example.invalid/tools.git'
detects 'mas install 497799835' 'mas|497799835'
detects 'mas get 497799835' 'mas|497799835'
detects 'mas purchase 497799835' 'mas|497799835'
detects 'npm install -g left-pad' 'npm|left-pad'
detects 'npm install prettier -g' 'npm|prettier'
detects 'npm i --global typescript' 'npm|typescript'
detects 'npm install --location global eslint' 'npm|eslint'
detects 'npm install --location=global eslint' 'npm|eslint'
detects 'uv tool install ruff' 'uv|ruff'
detects 'uv tool install --python 3.12 --with rich ruff' 'uv|ruff'
detects 'pipx install black' 'uv|black'
detects 'cargo install ripgrep' 'cargo|ripgrep'
detects 'cargo install --locked --version 14.1.0 ripgrep' 'cargo|ripgrep'
detects 'go install golang.org/x/tools/gopls@latest' 'go|golang.org/x/tools/gopls@latest'
detects 'go install -ldflags -s example.invalid/tool@v1' 'go|example.invalid/tool@v1'
detects 'code --install-extension ms-python.python' 'vscode|ms-python.python'
detects 'code --install-extension a.one --force --install-extension b.two' 'vscode|a.one b.two'
detects 'gem install bundler' 'gem|bundler'
detects 'gem install rails -v 7.1.0' 'gem|rails'
detects 'apt install jq' 'apt|jq'
detects 'sudo apt-get install -y jq curl' 'apt|jq curl'
detects 'sudo apt-get install -t bookworm-backports -y jq' 'apt|jq'
detects 'sudo dnf install -y htop' 'dnf|htop'
detects 'sudo pacman -S --noconfirm ripgrep' 'pacman|ripgrep'
detects 'sudo pacman -Syu ripgrep fd' 'pacman|ripgrep fd'
detects 'sudo zypper install htop' 'zypper|htop'
detects 'sudo zypper --non-interactive in htop' 'zypper|htop'

# Gaudi 2.0 has no pip lists: pip installs are never recorded
ignores 'pip install rich'
ignores 'pip3 install --user rich'
ignores 'python3 -m pip install rich'
ignores 'uv pip install rich'
ignores 'npm install left-pad'
ignores 'brew install'
ignores 'brew upgrade jq'
ignores 'brew uninstall jq'
ignores 'brew install --only-dependencies jq'
ignores 'brew install --dry-run jq'
ignores 'brew install --help'
ignores 'brew tap'
ignores 'uv tool install --from git+https://example.invalid/x.git x'
ignores 'pipx install --editable .'
ignores 'cargo install --path .'
ignores 'cargo install --git https://example.invalid/x.git x'
ignores 'code .'
ignores 'sudo pacman -Syu'
ignores 'sudo pacman -Sw ripgrep'
ignores 'sudo pacman -R ripgrep'
ignores 'apt-get install --simulate jq'
ignores 'sudo zypper install --dry-run htop'
ignores 'sudo dnf install --downloadonly htop'
ignores 'brew install jq && brew install fd'
ignores 'brew install jq; echo done'
ignores 'brew install jq | cat'
ignores 'brew install jq > /dev/null'
ignores 'brew install jq &'
ignores 'brew install $(cat packages)'
ignores 'brew install `cat packages`'

# --- Which names are recorded -------------------------------------------------------

names brew jq 'jq'
names brew '"jq"' 'jq'
names brew "'jq'" 'jq'
names brew python@3.12 'python@3.12'
names brew owner/tap/widget 'owner/tap/widget'
names brew owner/widget ''
names brew ./widget.rb ''
names brew https://example.invalid/widget.rb ''
names brew '$PACKAGE' ''
names brew 'j*' ''
names tap owner/tools 'owner/tools'
names tap owner/homebrew-tools 'owner/tools'
names tap tools ''
names mas 497799835 '497799835'
names mas Xcode ''
names npm eslint@9 'eslint'
names npm @scope/pkg '@scope/pkg'
names npm @scope/pkg@1.2.3 '@scope/pkg'
names npm ./local ''
names npm owner/repo ''
names npm package.tgz ''
names uv 'ruff==0.4.0' 'ruff'
names uv '"ruff[extra]==0.4.0"' 'ruff'
names uv ruff@latest 'ruff'
names cargo ripgrep@14.1.0 'ripgrep'
names go golang.org/x/tools/gopls@latest 'golang.org/x/tools/gopls'
names go ./cmd/tool ''
names go ./... ''
names vscode ms-python.python@2024.1.0 'ms-python.python'
names vscode ./extension.vsix ''
names vscode extension ''
names gem rails:7.1.0 'rails'
names gem ./local.gem ''
names apt curl=8.0.0 'curl'
names apt curl/bookworm-backports 'curl'
names apt libc6:i386 'libc6:i386'
names apt ./local.deb ''
names dnf htop 'htop'
names dnf @development-tools ''
names dnf ./local.rpm ''
names pacman extra/ripgrep 'ripgrep'
names zypper htop 'htop'

# --- Starting from templates without any Brewfile or list -----------------------------

created="$work/created"
command mkdir -p "$created"
use_templates "$created"

run 'brew install jq'
run 'brew install jq'
run 'brew install homebrew/core/jq'
run 'brew install owner/tools/widget'
run 'brew install widget'
run 'brew tap owner/homebrew-tools'
run 'brew tap owner/tools'
run 'brew tap other/repo https://example.invalid/repo.git'

file_is "created: core.Brewfile holds formulae and taps, without duplicates" "$created/lists/core.Brewfile" '# @Name: Core tools
# @Description: Command-line tools and libraries installed with Homebrew

tap "owner/tools"
tap "other/repo", "https://example.invalid/repo.git"

# Description of jq https://example.invalid/jq
brew "jq"
# Description of owner/tools/widget https://example.invalid/owner/tools/widget
brew "owner/tools/widget"'

run 'brew install --cask kitty'
run 'brew cask install kitty'
# `brew install <name>` that ended up installing a cask (see the fake Caskroom)
run 'brew install firefox'

file_is "created: apps.Brewfile holds casks, including one installed without --cask" "$created/lists/apps.Brewfile" '# @Name: Applications
# @Description: Desktop applications installed as Homebrew casks

# Cask kitty https://example.invalid/kitty
cask "kitty"
# Cask firefox https://example.invalid/firefox
cask "firefox"'
not_ok "created: a cask installed without --cask is not recorded as a formula" has_line "$created/lists/core.Brewfile" 'brew "firefox"'

run 'mas install 497799835'
run 'mas purchase 497799835'
run 'mas get 1354318707'
run 'mas install 999'

file_is "created: appstore.Brewfile holds apps with their name and id" "$created/lists/appstore.Brewfile" '# @Name: Mac App Store
# @Description: Apps from the Mac App Store (sign in to the App Store app first)

mas "Xcode", id: 497799835
mas "Core Tunnel", id: 1354318707
mas "999", id: 999'

run 'npm install -g left-pad'
run 'npm i -g left-pad@1.3.0 @scope/tool@2'

file_is "created: npm.Brewfile holds global npm packages" "$created/lists/npm.Brewfile" '# @Name: npm globals
# @Description: Global npm packages (needs node and npm on PATH)

# About left-pad https://example.invalid/left-pad
npm "left-pad"
# About @scope/tool https://example.invalid/@scope/tool
npm "@scope/tool"'

run 'uv tool install ruff'
run 'pipx install black'
run 'uv tool install Ruff==0.4.0'
run 'pip install rich'
run 'python3 -m pip install --user rich'

file_is "created: python.Brewfile holds uv tools, and nothing from pip" "$created/lists/python.Brewfile" '# @Name: Python tools
# @Description: Python command-line tools, isolated with uv instead of pip --user

uv "ruff"
uv "black"'
not_ok "created: pip installs do not create a pip list" test -e "$created/lists/default.pip.list.sh"

run 'cargo install ripgrep'
run 'cargo install ripgrep@14.1.0'
file_is "created: cargo.Brewfile holds crates" "$created/lists/cargo.Brewfile" '# @Name: Cargo crates
# @Description: Rust command-line tools installed with cargo

cargo "ripgrep"'

run 'go install golang.org/x/tools/gopls@latest'
run 'go install golang.org/x/tools/gopls@v0.16.0'
run 'go install ./cmd/tool'
file_is "created: go.Brewfile holds Go packages" "$created/lists/go.Brewfile" '# @Name: Go tools
# @Description: Go command-line tools installed with go install

go "golang.org/x/tools/gopls"'

run 'code --install-extension ms-python.python --install-extension GitHub.copilot'
run 'code --install-extension github.copilot@1.0.0'
run 'code --install-extension ./local.vsix'
file_is "created: vscode.Brewfile holds extensions" "$created/lists/vscode.Brewfile" '# @Name: VS Code extensions
# @Description: Extensions for Visual Studio Code

vscode "ms-python.python"
vscode "GitHub.copilot"'

run 'gem install bundler'
run 'gem install bundler -v 2.5.0'
run 'gem install rails:7.1.0'
file_is "created: default.gem.list.sh" "$created/lists/default.gem.list.sh" '# @Name: Default
# @List: gemList
gemList=(
    "bundler"
    "rails"
)'

run 'sudo apt-get install -y jq curl=8.0.0'
run 'apt install jq'
file_is "created: default.apt.list.sh" "$created/lists/default.apt.list.sh" '# @Name: Default
# @List: aptList
aptList=(
    "jq::Description of jq https://example.invalid/jq"
    "curl::Description of curl https://example.invalid/curl"
)'

run 'sudo dnf install -y htop'
run 'sudo dnf install htop'
file_is "created: default.dnf.list.sh" "$created/lists/default.dnf.list.sh" '# @Name: Default
# @List: dnfList
dnfList=(
    "htop"
)'

run 'sudo pacman -S --noconfirm extra/ripgrep'
run 'sudo pacman -Syu ripgrep'
file_is "created: default.pacman.list.sh" "$created/lists/default.pacman.list.sh" '# @Name: Default
# @List: pacmanList
pacmanList=(
    "ripgrep"
)'

run 'sudo zypper --non-interactive install htop'
run 'sudo zypper in htop'
file_is "created: default.zypper.list.sh" "$created/lists/default.zypper.list.sh" '# @Name: Default
# @List: zypperList
zypperList=(
    "htop"
)'

is "created: only the expected files exist" \
    "apps.Brewfile appstore.Brewfile cargo.Brewfile core.Brewfile default.apt.list.sh default.dnf.list.sh default.gem.list.sh default.pacman.list.sh default.zypper.list.sh go.Brewfile npm.Brewfile python.Brewfile vscode.Brewfile" \
    "$(cd "$created/lists" && command find . -type f | command sed 's|^\./||' | command sort | command tr '\n' ' ' | command sed 's/ $//')"

# --- Templates that already have Brewfiles and lists -----------------------------------

existing="$work/existing"
command mkdir -p "$existing/lists" "$existing/software/nested"
use_templates "$existing"

# Formulae live in a Brewfile with another name: it is the one to append to
printf '%s\n' '# @Name: Base' '' 'tap "first/tap"' '' 'brew "wget"' 'brew "git"' > "$existing/software/nested/base.Brewfile"
# The conventional file exists, but holds no cask yet
printf '%s\n' '# @Name: Applications' '# @Description: Desktop applications' '' '# Link casks in /Applications' 'cask_args appdir: "/Applications"' > "$existing/lists/apps.Brewfile"
# Two Brewfiles hold npm entries: the conventional name wins over sort order
printf '%s\n' 'npm "aaa"' > "$existing/lists/aaa.Brewfile"
printf '%s\n' '# @Name: npm globals' '' 'npm "mocha"' > "$existing/lists/npm.Brewfile"
# uv entries next to formulae, no newline at the end of the file
printf '%s\n%s' 'brew "uv"' 'uv "pylint"' > "$existing/lists/python.Brewfile"
command chmod 600 "$existing/lists/python.Brewfile"
# A formula that lives in a second Brewfile, found later than the first
printf '%s\n' '# @Name: Languages' '# Version manager' 'brew "pyenv"' > "$existing/software/zz.Brewfile"
# A plain Brewfile, the only one with cargo entries
printf '%s\n' 'cargo "bat"' > "$existing/Brewfile"

run 'brew install ripgrep'
run 'brew install wget'
run 'brew install homebrew/core/git'
run 'brew install pyenv'
run 'brew tap second/tap'
run 'brew tap first/homebrew-tap'

file_is "existing: formulae and taps go to the Brewfile that already holds them" "$existing/software/nested/base.Brewfile" "# @Name: Base

tap \"first/tap\"
tap \"second/tap\"

brew \"wget\"
brew \"git\"
# Description of ripgrep https://example.invalid/ripgrep
brew \"ripgrep\""
not_ok "existing: no core.Brewfile is created when another Brewfile holds formulae" test -e "$existing/lists/core.Brewfile"
file_is "existing: a formula listed in another Brewfile is not added again" "$existing/software/zz.Brewfile" '# @Name: Languages
# Version manager
brew "pyenv"'

run 'cargo install ripgrep'
run 'cargo install bat'
file_is "existing: a file named Brewfile is used like any other" "$existing/Brewfile" 'cargo "bat"
cargo "ripgrep"'
not_ok "existing: no cargo.Brewfile is created when the Brewfile holds crates" test -e "$existing/lists/cargo.Brewfile"

run 'brew install --cask kitty'
file_is "existing: the conventional Brewfile is used when no Brewfile holds the type" "$existing/lists/apps.Brewfile" '# @Name: Applications
# @Description: Desktop applications

# Link casks in /Applications
cask_args appdir: "/Applications"
# Cask kitty https://example.invalid/kitty
cask "kitty"'

run 'npm install -g eslint'
run 'npm install -g aaa'
ok "existing: the conventional Brewfile wins when several hold the type" has_line "$existing/lists/npm.Brewfile" 'npm "eslint"'
file_is "existing: the other Brewfile is left alone" "$existing/lists/aaa.Brewfile" 'npm "aaa"'

run 'uv tool install ruff'
run 'uv tool install pylint'
file_is "existing: an entry is appended to a file without a final newline" "$existing/lists/python.Brewfile" 'brew "uv"
uv "pylint"
uv "ruff"'
is "existing: file permissions are kept" "-rw-------" "$(command ls -l "$existing/lists/python.Brewfile" | command cut -c 1-10)"

# A tap added to a Brewfile without taps goes below the header, above the packages
headed="$work/headed"
command mkdir -p "$headed/lists"
use_templates "$headed"
printf '%s\n' '# @Name: Core tools' '# @Description: Tools' '# GNU grep' 'brew "grep"' > "$headed/lists/core.Brewfile"
run 'brew tap owner/tools'
file_is "existing: the first tap goes between the header and the packages" "$headed/lists/core.Brewfile" '# @Name: Core tools
# @Description: Tools

tap "owner/tools"

# GNU grep
brew "grep"'
# A trailing comment must not become the description of the new entry
printf '%s\n' 'brew "grep"' '# --- More ---' > "$headed/lists/core.Brewfile"
run 'brew install owner/tools/widget'
file_is "existing: an entry is not attached to a trailing comment" "$headed/lists/core.Brewfile" 'brew "grep"
# --- More ---

# Description of owner/tools/widget https://example.invalid/owner/tools/widget
brew "owner/tools/widget"'

# Entries written with single quotes are Ruby too, and count as present
quoted="$work/quoted"
command mkdir -p "$quoted/lists"
use_templates "$quoted"
printf '%s\n' "brew 'wget'" "tap 'first/tap'" > "$quoted/lists/core.Brewfile"
run 'brew install wget'
run 'brew tap first/tap'
file_is "existing: single-quoted entries are recognised as duplicates" "$quoted/lists/core.Brewfile" "brew 'wget'
tap 'first/tap'"

# Lists: Gaudi also reads <name>.<type>-<anything>.sh, as in default.apt-get.sh
use_templates "$existing"
printf '%s\n' '# @Name: Default' '# @List: aptList' 'aptList=(' '    # Core' '    "build-essential"' '    "pkg-config::Manage compile and link flags"' '' '    # Development' '    "docker-ce::Docker https://example.invalid/docker"' ')' '' 'echo "after the array"' > "$existing/lists/default.apt-get.sh"
printf '%s\n' '# @Name: Default' '# @List: gemList' 'gemList=("bundler" "travis")' > "$existing/lists/default.gem.list.sh"
printf '%s\n' '# @Name: Empty' '# @List: dnfList' 'dnfList=()' > "$existing/lists/default.dnf.list.sh"
printf '%s\n' '# @Name: Broken' '# @List: pacmanList' 'pacmanList=(' '    "fd"' > "$existing/lists/default.pacman.list.sh"
command cp "$existing/lists/default.pacman.list.sh" "$work/broken.before"

run 'sudo apt-get install -y evil build-essential pkg-config docker-ce'
file_is "existing: an apt package is added inside the array of the existing list" "$existing/lists/default.apt-get.sh" '# @Name: Default
# @List: aptList
aptList=(
    # Core
    "build-essential"
    "pkg-config::Manage compile and link flags"

    # Development
    "docker-ce::Docker https://example.invalid/docker"
    "evil::Say \"hi\" \$(touch PWNED) \`touch PWNED\` \\ done https://example.invalid/evil"
)

echo "after the array"'
not_ok "existing: no default.apt.list.sh is created next to default.apt-get.sh" test -e "$existing/lists/default.apt.list.sh"

run 'gem install rails'
run 'gem install travis'
file_is "existing: an array written on one line is extended" "$existing/lists/default.gem.list.sh" '# @Name: Default
# @List: gemList
gemList=("bundler" "travis"
    "rails"
)'

run 'sudo dnf install htop'
file_is "existing: an empty array is filled" "$existing/lists/default.dnf.list.sh" '# @Name: Empty
# @List: dnfList
dnfList=(
    "htop"
)'

run 'sudo pacman -S ripgrep'
ok "existing: a list whose array cannot be found is left untouched" command cmp -s "$work/broken.before" "$existing/lists/default.pacman.list.sh"
ok "existing: and the problem is reported" command grep -Fq "Could not add ripgrep" "$work/output.log"
# Repaired here so the directory can be handed to `gaudi check` afterwards
printf '%s\n' ')' >> "$existing/lists/default.pacman.list.sh"
run 'sudo pacman -S ripgrep'
ok "existing: the same list accepts the package once it is valid" has_line "$existing/lists/default.pacman.list.sh" '    "ripgrep"'

# What Gaudi gets when it sources the list: the description stays text
evil_value="$(cd "$work" && command bash -c 'source "$1" >/dev/null; printf "%s" "${aptList[3]}"' _ "$existing/lists/default.apt-get.sh")"
is "existing: a description is escaped, not expanded, when Gaudi sources the list" \
    'evil::Say "hi" $(touch PWNED) `touch PWNED` \ done https://example.invalid/evil' "$evil_value"
not_ok "existing: nothing from a description was executed" test -e "$work/PWNED"

is "no temporary file is left behind" "" "$(command find "$work" -name '.gaudi-helper.*' -print)"

# --- Hooks: only after success, and without running anything again -----------------------

hooked="$work/hooked"
command mkdir -p "$hooked"
use_templates "$hooked"

gaudi_helper_preexec 'brew install failed-formula'
(exit 3)
gaudi_helper_precmd >> "$work/output.log" 2>&1
is "hooks: the exit status of a failed command is passed through" "3" "$?"
not_ok "hooks: a failed install is not recorded" test -e "$hooked/lists/core.Brewfile"

gaudi_helper_preexec 'brew install hooked-formula'
(exit 0)
gaudi_helper_precmd >> "$work/output.log" 2>&1
is "hooks: the exit status of a successful command is passed through" "0" "$?"
ok "hooks: a successful install is recorded" has_line "$hooked/lists/core.Brewfile" 'brew "hooked-formula"'

(exit 0)
gaudi_helper_precmd >> "$work/output.log" 2>&1
count_is "hooks: a command is recorded once, not at every prompt" "$hooked/lists/core.Brewfile" 'hooked-formula"' 1

gaudi_helper_preexec 'ls -la'
(exit 0)
gaudi_helper_precmd >> "$work/output.log" 2>&1
is "hooks: other commands change nothing" "core.Brewfile" "$(command ls "$hooked/lists")"

# The fake package managers log every call: only lookups may appear
not_ok "the helper never runs an install, tap or uninstall itself" \
    command grep -Eq '^(brew|npm|mas|apt-cache) (install|uninstall|tap|i|add|get|purchase|reinstall|upgrade)( |$)' "$GAUDI_HELPER_TEST_CALLS"
ok "the helper only asks package managers for descriptions" command grep -Fxq 'brew desc --eval-all jq' "$GAUDI_HELPER_TEST_CALLS"

# --- No templates ----------------------------------------------------------------------

use_templates "$work/missing"
: > "$work/missing.log"
gaudi_helper_process_command 'brew install jq' >> "$work/missing.log" 2>&1
ok "missing templates: a warning is printed" command grep -Fq "No Gaudi templates found" "$work/missing.log"
not_ok "missing templates: nothing is created" test -e "$work/missing"

is "nothing was written to the home directory" "" "$(command find "$HOME" -mindepth 1 -print)"

# --- Hook registration --------------------------------------------------------------------

GAUDI_HELPER_NO_HOOKS=false
gaudi_helper_register_hooks >> "$work/output.log" 2>&1
gaudi_helper_register_hooks >> "$work/output.log" 2>&1
# shellcheck disable=SC2154
is "hooks: preexec is registered once" "1" "$(printf '%s\n' "${preexec_functions[@]}" | command grep -c '^gaudi_helper_preexec$')"
# shellcheck disable=SC2154
is "hooks: precmd is registered once" "1" "$(printf '%s\n' "${precmd_functions[@]}" | command grep -c '^gaudi_helper_precmd$')"
