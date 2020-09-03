#!/usr/bin/env bash

echo ""

if [ ! -n "$GAUDI" ]; then
    GAUDI=${HOME}/.gaudi
fi

source "$GAUDI/gaudi-helper/lib/install-helper.sh"

if [ ! -d "$GAUDI" ]; then
    printf "${RED}%s${NC}\n" "You don't have gaudi installed.. This helper requires gaudi to be installed first"
    printf "%s${GREEN} %s${NC} %s\n" "Please check:" "https://github.com/ahmadassaf/gaudi" "on instructions to install gaudi"
else
    rm -rf "$GAUDI/gaudi-helper"
fi

# Prevent the cloned repository from having insecure permissions. Failing to do
# so causes compinit() calls to fail with "command not found: compdef" errors
# for users with insecure umasks (e.g., "002", allowing group writability). Note
# that this will be ignored under Cygwin by default, as Windows ACLs take
# precedence over umasks except for filesystems mounted with option "noacl".
umask g-w,o-w

env git clone --depth=1 https://github.com/ahmadassaf/gaudi-helper.git "$GAUDI/gaudi-helper" || {
    printf "Error: Cloning of gaudi-helper into this machine failed :(\\n"
    exit 1
}

if [[ $(ps -p $$ | grep bash)  ]]; then
    set_environment_exports "source $HOME/.gaudi/gaudi-helper/lib/bash-prexec.sh"
fi

set_environment_exports "source $HOME/.gaudi/gaudi-helper/gaudi-helper.sh"
printf "Do not forget now to enable the plugin by sourcing your .bash_profile, .bashrc or .zshrc\n"
