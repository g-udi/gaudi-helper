# Gaudi Helper

Gaudi Helper accompanies the [Gaudi project](https://github.com/g-udi/gaudi). It keeps your Gaudi template package lists up to date by watching successful package-manager install commands in your interactive shell and adding the installed software to the matching list file.

It does not re-run your command. It records the command before execution and processes it only when the prompt returns with exit status `0`.

<img width="1143" alt="Gaudi Helper updating template lists" src="https://github.com/user-attachments/assets/b66803b8-ebaf-4301-9056-47d1bb2401c0">

## Installation

Gaudi must already be installed.

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi-helper/master/install.sh)"
```

The installer clones or updates:

```sh
${GAUDI:-$HOME/.gaudi}/gaudi-helper
```

Then it adds idempotent profile lines for the detected shell.

Supported shells:

- Bash, via bundled `bash-prexec`
- Zsh, via native `add-zsh-hook`

Force a target shell, profile, branch, or repository when needed:

```sh
GAUDI_HELPER_SHELL=zsh bash install.sh
GAUDI_HELPER_PROFILE="$HOME/.zshrc" bash install.sh
GAUDI_HELPER_BRANCH=master bash install.sh
GAUDI_HELPER_REPO=https://github.com/g-udi/gaudi-helper.git bash install.sh
```

Restart your shell or source your profile after installation.

## How it works

Gaudi Helper integrates with shell lifecycle hooks:

- `preexec` records the command before it runs.
- `precmd` runs before the next prompt is displayed.
- If the previous command exited with status `0`, the helper parses the recorded command.
- If the command is a supported install command, the helper appends the package to the matching Gaudi template list.

Template lists are updated under:

```sh
${GAUDI_HELPER_LIST_DIR:-${GAUDI:-$HOME/.gaudi}/templates/lists}
```

When possible, the helper also looks up package descriptions or homepages through the package manager, so entries follow Gaudi's `package::description website` list format.

## Supported Commands

Gaudi Helper tracks simple install commands:

```sh
brew install jq
brew install --cask firefox
brew cask install firefox
brew tap homebrew/cask-fonts
npm install -g prettier
npm i --global typescript
npm install --location global eslint
pip install rich
pip3 install rich
python3 -m pip install rich
gem install bundler
apt install jq
apt-get install jq
mas install 497799835
```

The parser also handles common wrappers such as:

```sh
command brew install jq
sudo -E brew install --cask firefox
env HOMEBREW_NO_AUTO_UPDATE=1 brew install jq
```

Complex commands containing command separators, pipes, backticks, or command substitutions are intentionally ignored. This keeps shell tracking predictable and avoids rewriting lists from ambiguous command lines.

## List Mapping

Commands update these files when present:

```text
brew install              -> default.brew.list.sh
brew install --cask       -> default.cask.list.sh
brew cask install         -> default.cask.list.sh
brew tap                  -> default.tap.list.sh
npm install -g            -> default.npm.list.sh
pip install               -> default.pip.list.sh
python3 -m pip install    -> default.pip.list.sh
gem install               -> default.gem.list.sh
apt install               -> default.apt-get.sh
apt-get install           -> default.apt-get.sh
mas install               -> default.mas.list.sh
```

If a list file is missing, the helper logs a warning and does not block your shell command.

Duplicate entries are skipped. Existing list files are edited by inserting the new entry before the closing `)` when possible.

## Configuration

Useful environment variables:

```sh
GAUDI=/path/to/.gaudi
GAUDI_HELPER_DIR=/path/to/gaudi-helper
GAUDI_HELPER_LIST_DIR=/path/to/templates/lists
GAUDI_HELPER_SHELL=bash|zsh
GAUDI_HELPER_PROFILE=/path/to/shell/profile
GAUDI_HELPER_BRANCH=master
GAUDI_HELPER_REPO=https://github.com/g-udi/gaudi-helper.git
GAUDI_HELPER_NO_HOOKS=true
```

`GAUDI_HELPER_NO_HOOKS=true` is useful for tests or manual sourcing when you want the helper functions without registering shell hooks.

## Development

Run the smoke test:

```sh
./test/test.sh
```

The test uses fake package-manager binaries, so it is deterministic and does not install software. It checks shell syntax, ShellCheck when available, command detection, duplicate prevention, metadata capture, and installer profile updates.
