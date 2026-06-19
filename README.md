# Gaudi Helper

Gaudi Helper keeps Gaudi template package lists up to date while you work. It observes package-manager install commands in your interactive shell and, after a successful command, appends the installed package to the matching default list under:

```sh
${GAUDI:-$HOME/.gaudi}/templates/lists
```

It does not re-run your command. It records the command before execution and processes it only when the prompt returns with exit status `0`.

## Install

Gaudi must already be installed.

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi-helper/master/install.sh)"
```

The installer clones or updates `${GAUDI:-$HOME/.gaudi}/gaudi-helper` and adds idempotent profile lines for the detected shell.

Supported shells:

- Bash, via bundled `bash-prexec`
- Zsh, via native `add-zsh-hook`

Force a target shell/profile if needed:

```sh
GAUDI_HELPER_SHELL=zsh bash install.sh
GAUDI_HELPER_PROFILE="$HOME/.zshrc" bash install.sh
GAUDI_HELPER_BRANCH=master bash install.sh
```

## Supported Commands

Gaudi Helper tracks simple install commands:

```sh
brew install jq
brew install --cask firefox
brew cask install firefox
brew tap homebrew/cask-fonts
npm install -g prettier
npm i --global typescript
pip install rich
pip3 install rich
python3 -m pip install rich
gem install bundler
apt install jq
apt-get install jq
mas install 497799835
```

Complex commands containing command separators, pipes, backticks, or command substitutions are intentionally ignored.

## List Mapping

Commands update these files when present:

```text
default.brew.list.sh
default.cask.list.sh
default.tap.list.sh
default.npm.list.sh
default.pip.list.sh
default.gem.list.sh
default.apt-get.sh
default.mas.list.sh
```

If a list file is missing, the helper logs a warning and does not block your shell command.

## Development

Run the smoke test:

```sh
./test/test.sh
```

The test uses fake package-manager binaries, so it is deterministic and does not install software.
