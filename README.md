# Gaudi Helper

Gaudi Helper accompanies the [Gaudi project](https://github.com/g-udi/gaudi). It keeps your Gaudi templates up to date by watching successful package-manager install commands in your interactive shell and adding the installed software to the matching [Brewfile](https://docs.brew.sh/Brew-Bundle-and-Brewfile) or list in your templates.

It does not re-run your command. It records the command before execution and processes it only when the prompt returns with exit status `0`.

It writes the format [Gaudi 2.0](https://github.com/g-udi/gaudi#software-brewfiles) installs: Brewfiles for everything [Homebrew](https://brew.sh/) can install, and lists only for the system package managers and Ruby gems.

<img width="1143" alt="Gaudi Helper updating template lists" src="https://github.com/user-attachments/assets/b66803b8-ebaf-4301-9056-47d1bb2401c0">

## Installation

[Gaudi](https://github.com/g-udi/gaudi) must already be installed.

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi-helper/master/install.sh)"
```

The installer clones or updates:

```sh
${GAUDI:-$HOME/.gaudi}/gaudi-helper
```

Then it adds idempotent profile lines for the detected shell: `~/.zshrc` for Zsh, `~/.bash_profile` (macOS) or `~/.bashrc` (Linux) for Bash.

Supported shells:

- Bash 3.2 and later (including the Bash that ships with macOS), via the bundled [bash-preexec](https://github.com/rcaloras/bash-preexec)
- Zsh, via its native [`add-zsh-hook`](https://zsh.sourceforge.io/Doc/Release/User-Contributions.html#Manipulating-Hook-Functions)

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
- If the command is a supported install command, the helper adds the package to the matching Brewfile or list.

It looks for Brewfiles and lists anywhere in the templates directory, the same way Gaudi does:

```sh
${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}
```

When the templates have no suitable file yet, it creates one under:

```sh
${GAUDI_HELPER_LIST_DIR:-<templates directory>/lists}
```

When possible, the helper also looks up the package description and homepage through the package manager. In a Brewfile they become the comment line above the entry, which Gaudi shows when it asks about that package; in a list they follow Gaudi's `package::description website` format.

```ruby
# Lightweight and flexible command-line JSON processor https://jqlang.github.io/jq/
brew "jq"
```

Files are never edited in place: the new content is written next to the file and moved over it, so an interrupted shell cannot leave a half-written Brewfile or list.

## Supported Commands

Gaudi Helper tracks simple install commands:

```sh
brew install jq
brew install owner/tap/formula
brew install --cask firefox
brew cask install firefox
brew tap owner/tools
mas install 497799835
npm install -g prettier
npm i --global typescript
npm install --location global eslint
uv tool install ruff
pipx install black
cargo install ripgrep
go install golang.org/x/tools/gopls@latest
code --install-extension ms-python.python
gem install bundler
apt install jq
apt-get install jq
dnf install htop
pacman -S ripgrep
zypper install htop
```

The parser also handles common wrappers such as:

```sh
command brew install jq
sudo -E brew install --cask firefox
env HOMEBREW_NO_AUTO_UPDATE=1 brew install jq
```

Versions are left out, so `npm install -g eslint@9`, `cargo install ripgrep@14.1.0` and `go install example.com/tool@latest` record `eslint`, `ripgrep` and `example.com/tool`. Arguments that are not package names (local paths, URLs, archives, shell variables) are skipped, and so are dry runs and installs from somewhere other than the package index (`cargo install --git`, `cargo install --path`, `uv tool install --from`, `pipx install --editable`).

Complex commands containing command separators, pipes, redirections, `&`, backticks, or command substitutions are intentionally ignored. This keeps shell tracking predictable and avoids rewriting your templates from ambiguous command lines.

Removals (`brew uninstall`, `npm uninstall -g`, ...) are not tracked: the helper only ever adds entries.

### Python packages

Gaudi 2.0 has no pip lists; Python command-line tools are declared in a Brewfile as [uv](https://docs.astral.sh/uv/) tools. The helper follows that:

- `uv tool install <tool>` and [`pipx install <tool>`](https://pipx.pypa.io/) install a command-line tool in its own environment, so they are recorded as `uv "<tool>"`.
- `pip install`, `pip3 install`, `python -m pip install` and `uv pip install` are **not recorded**. They usually put a library into a project's virtual environment, the command line does not say whether a package is a tool, and Gaudi would ignore a pip list anyway.

To keep a Python tool in your templates, install it with `uv tool install`.

## File Mapping

Software Homebrew can install goes to a Brewfile, as one line per package:

| Command | Line added | Brewfile created when none fits |
| --- | --- | --- |
| `brew install <formula>` | `brew "<formula>"` | `core.Brewfile` |
| `brew tap <owner/repo> [URL]` | `tap "<owner/repo>"` (with the URL when one was given) | `core.Brewfile` |
| `brew install --cask <cask>`, `brew cask install <cask>` | `cask "<cask>"` | `apps.Brewfile` |
| `mas install <id>`, `mas get <id>`, `mas purchase <id>` | `mas "<App name>", id: <id>` | `appstore.Brewfile` |
| `npm install -g <package>` | `npm "<package>"` | `npm.Brewfile` |
| `uv tool install <tool>`, `pipx install <tool>` | `uv "<tool>"` | `python.Brewfile` |
| `cargo install <crate>` | `cargo "<crate>"` | `cargo.Brewfile` |
| `go install <package>@<version>` | `go "<package>"` | `go.Brewfile` |
| `code --install-extension <publisher.extension>` | `vscode "<publisher.extension>"` | `vscode.Brewfile` |

The Brewfile is chosen in this order:

1. The file with the conventional name above (the layout of [gaudi-templates](https://github.com/g-udi/gaudi-templates)), if it already holds entries of that type.
2. Otherwise the Brewfile (`Brewfile` or `<name>.Brewfile`, anywhere in the templates) that holds the most entries of that type.
3. Otherwise the file with the conventional name, if it exists.
4. Otherwise the conventional file is created in `GAUDI_HELPER_LIST_DIR`, with its `# @Name:` and `# @Description:` header.

Entries are appended at the end of the file. Taps go after the last `tap` line, or right below the header when the file has none.

A few details:

- `brew install <name>` installs a cask when no formula has that name. The helper checks Homebrew's `Caskroom` and records a `cask` in that case.
- The [mas](https://github.com/mas-cli/mas) app name is read from `mas list` or `mas info`; when neither knows it, the id is used as the name.
- `brew tap owner/homebrew-tools` is recorded under the name Homebrew uses, `owner/tools`.

System packages and Ruby gems stay in Gaudi lists, a Bash array of `"package::description"` items named by a `# @List:` line:

| Command | List created when there is none |
| --- | --- |
| `apt install`, `apt-get install` | `default.apt.list.sh` |
| `dnf install` | `default.dnf.list.sh` |
| `pacman -S` | `default.pacman.list.sh` |
| `zypper install`, `zypper in` | `default.zypper.list.sh` |
| `gem install` | `default.gem.list.sh` |

An existing list of that type is used when there is one, under any of the names Gaudi reads (for example `default.apt-get.sh`); `default.<type>.list.sh` is preferred when several exist. The new item is inserted before the closing `)` of the array. If the array cannot be found, or the result would not be valid Bash, the file is left untouched and the helper prints a warning.

Duplicate entries are skipped. An entry counts as present when any Brewfile (or any list of that type) in the templates already has it: formulae and casks are compared by name, so `owner/tap/jq` and `jq` are the same package; App Store apps are compared by id.

If the templates directory does not exist, the helper logs a warning and does not block your shell command.

Run `gaudi check` to validate the templates at any time.

### Coming from the old list files

Older versions of the helper wrote `default.brew.list.sh`, `default.cask.list.sh`, `default.tap.list.sh`, `default.npm.list.sh`, `default.pip.list.sh` and `default.mas.list.sh`. Gaudi 2.0 no longer installs those lists, and the helper no longer writes to them. Move their entries into Brewfiles as described in the [Gaudi README](https://github.com/g-udi/gaudi#software-brewfiles).

## Configuration

Useful environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `GAUDI` | `$HOME/.gaudi` | Where Gaudi is installed |
| `GAUDI_TEMPLATES_LOCATION` | `$GAUDI/templates` | The templates directory, as in Gaudi itself |
| `GAUDI_HELPER_DIR` | `$GAUDI/gaudi-helper` | Where the helper is installed |
| `GAUDI_HELPER_LIST_DIR` | `<templates directory>/lists` | Where a new Brewfile or list is created; keep it inside the templates directory so Gaudi finds the files |
| `GAUDI_HELPER_NO_HOOKS` | `false` | `true` loads the helper functions without registering shell hooks |
| `GAUDI_HELPER_SHELL` | detected from `$SHELL` | Installer: `bash` or `zsh` |
| `GAUDI_HELPER_PROFILE` | the shell's profile | Installer: the profile file to add the lines to |
| `GAUDI_HELPER_BRANCH` | the repository's default branch | Installer: branch to update to |
| `GAUDI_HELPER_REPO` | `https://github.com/g-udi/gaudi-helper.git` | Installer: repository to clone |

`GAUDI_HELPER_NO_HOOKS=true` is useful for tests or manual sourcing when you want the helper functions without registering shell hooks.

## Development

Run the tests:

```sh
./test/test.sh
```

The tests use fake package-manager binaries and temporary directories, so they are deterministic, do not install software, and touch neither your home directory nor your templates. They check shell syntax, [ShellCheck](https://www.shellcheck.net/) when available, command detection, every command-to-file mapping, duplicate prevention, metadata capture, the shell hooks and installer profile updates. The cases run once per available shell: `/bin/bash` (Bash 3.2 on macOS), a newer Bash when one is on `PATH`, and Zsh.

When a Gaudi checkout is available, the files the helper wrote are also validated with `gaudi check`. The tests look for it next to this repository (`../gaudi`); point them elsewhere with:

```sh
GAUDI_HELPER_TEST_GAUDI=/path/to/gaudi ./test/test.sh
```
