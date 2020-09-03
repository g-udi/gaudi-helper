#!/usr/bin/env bash

echo ""

if [ ! -n "$GAUDI" ]; then
    GAUDI=${HOME}/.gaudi
fi

if [ ! -d "$GAUDI" ]; then
    printf "You don't have gaudi installed.. This helper requires gaudi to be installed first \\n\\n"
    printf "Please check: https://github.com/ahmadassaf/gaudi on instructions to install gaudi"
fi


# Prevent the cloned repository from having insecure permissions. Failing to do
# so causes compinit() calls to fail with "command not found: compdef" errors
# for users with insecure umasks (e.g., "002", allowing group writability). Note
# that this will be ignored under Cygwin by default, as Windows ACLs take
# precedence over umasks except for filesystems mounted with option "noacl".
umask g-w,o-w

env git clone --depth=1 https://github.com/ahmadassaf/gaudi.git "$GAUDI" || {
    printf "Error: Cloning of gaudi into this machine failed :(\\n"
    exit 1
}

. "$GAUDI/setup.sh"