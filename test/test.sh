#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

find "$ROOT_DIR" -name '*.sh' -type f ! -path '*/lib/bash-prexec.sh' -print0 | xargs -0 /bin/bash -n
/bin/bash -n "$ROOT_DIR/lib/bash-prexec.sh"

if command -v shellcheck >/dev/null 2>&1; then
    find "$ROOT_DIR" -name '*.sh' -type f ! -path '*/lib/bash-prexec.sh' -print0 | xargs -0 shellcheck -x -S warning
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fakebin="$tmp_dir/bin"
gaudi_home="$tmp_dir/.gaudi"
list_dir="$gaudi_home/templates/lists"
mkdir -p "$fakebin" "$list_dir"

cat > "$fakebin/brew" <<'BREW'
#!/usr/bin/env bash
case "$1:$2" in
  desc:--eval-all)
    printf '%s: Command-line JSON processor\n' "$3"
    ;;
  info:--cask)
    printf '==> Description\nFast browser\nhttps://example.invalid/firefox\n'
    ;;
  info:*)
    printf 'jq: stable\nhttps://example.invalid/jq\n'
    ;;
esac
BREW

cat > "$fakebin/npm" <<'NPM'
#!/usr/bin/env bash
if [[ "$1" == "view" && "$3" == "description" ]]; then
  printf 'left pad strings\n'
elif [[ "$1" == "view" && "$3" == "homepage" ]]; then
  printf 'https://example.invalid/left-pad\n'
fi
NPM

cat > "$fakebin/python3" <<'PYTHON'
#!/usr/bin/env bash
if [[ "$1" == "-m" && "$2" == "pip" && "$3" == "show" ]]; then
  printf 'Name: %s\nSummary: Python helper\nHome-page: https://example.invalid/pip\n' "$4"
fi
PYTHON

chmod +x "$fakebin/brew" "$fakebin/npm" "$fakebin/python3"

cat > "$list_dir/default.brew.list.sh" <<'EOF'
# @Name: Default
# @List: brewList
brewList=(
)
EOF

cat > "$list_dir/default.cask.list.sh" <<'EOF'
# @Name: Default
# @List: caskList
caskList=(
)
EOF

cat > "$list_dir/default.npm.list.sh" <<'EOF'
# @Name: Default
# @List: npmList
npmList=(
)
EOF

cat > "$list_dir/default.pip.list.sh" <<'EOF'
# @Name: Default
# @List: pipList
pipList=(
)
EOF

PATH="$fakebin:$PATH" \
GAUDI="$gaudi_home" \
GAUDI_HELPER_DIR="$ROOT_DIR" \
GAUDI_HELPER_NO_HOOKS=true \
/bin/bash --noprofile --norc <<'BASH'
source "$GAUDI_HELPER_DIR/gaudi-helper.sh"
[[ "$(gaudi_helper_detect_install 'brew install jq')" == "brew|jq" ]]
[[ "$(gaudi_helper_detect_install 'brew install --cask firefox')" == "cask|firefox" ]]
[[ "$(gaudi_helper_detect_install 'command brew install --formula jq')" == "brew|jq" ]]
[[ "$(gaudi_helper_detect_install 'sudo -E brew install --cask --appdir /Applications firefox')" == "cask|firefox" ]]
[[ "$(gaudi_helper_detect_install 'npm install -g left-pad')" == "npm|left-pad" ]]
[[ "$(gaudi_helper_detect_install 'npm install prettier -g')" == "npm|prettier" ]]
[[ "$(gaudi_helper_detect_install 'npm install --location global eslint')" == "npm|eslint" ]]
[[ "$(gaudi_helper_detect_install 'env HOMEBREW_NO_AUTO_UPDATE=1 brew install jq')" == "brew|jq" ]]
[[ "$(gaudi_helper_detect_install 'apt-get install -y jq curl')" == "apt|jq curl" ]]
if gaudi_helper_detect_install 'npm install left-pad'; then
  exit 1
fi
gaudi_helper_process_command 'brew install jq'
gaudi_helper_process_command 'brew install jq'
gaudi_helper_process_command 'brew install --cask firefox'
gaudi_helper_process_command 'npm install -g left-pad'
gaudi_helper_process_command 'python3 -m pip install pycparser'
BASH

[[ "$(grep -c '"jq::' "$list_dir/default.brew.list.sh")" -eq 1 ]]
grep -Fq 'Command-line JSON processor https://example.invalid/jq' "$list_dir/default.brew.list.sh"
grep -Fq '"firefox::Fast browser https://example.invalid/firefox"' "$list_dir/default.cask.list.sh"
grep -Fq '"left-pad::left pad strings https://example.invalid/left-pad"' "$list_dir/default.npm.list.sh"
grep -Fq '"pycparser::Python helper https://example.invalid/pip"' "$list_dir/default.pip.list.sh"

install_home="$tmp_dir/install-home"
helper_repo="$tmp_dir/helper-repo"
mkdir -p "$install_home/.gaudi"
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
    -c user.email="gaudi-helper-smoke@example.invalid" \
    -c user.name="Gaudi Helper Smoke" \
    commit -m "smoke fixture" >/dev/null

HOME="$install_home" \
GAUDI="$install_home/.gaudi" \
GAUDI_HELPER_REPO="$helper_repo" \
GAUDI_HELPER_SHELL=bash \
/bin/bash "$ROOT_DIR/install.sh" >/dev/null

grep -Fq 'GAUDI_HELPER_DIR' "$install_home/.bash_profile"
grep -Fq 'bash-prexec.sh' "$install_home/.bash_profile"
grep -Fq 'gaudi-helper.sh' "$install_home/.bash_profile"

printf "gaudi-helper smoke ok\n"
