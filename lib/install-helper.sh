#!/usr/bin/env bash
# shellcheck shell=bash

gaudi_helper_append_once() {
    local file="$1"
    local line="$2"
    local dir=""

    dir="$(dirname "$file")"
    mkdir -p "$dir"
    touch "$file"
    grep -Fqx "$line" "$file" 2>/dev/null || printf "\n%s\n" "$line" >> "$file"
}

gaudi_helper_detect_shell() {
    local shell_name="${GAUDI_HELPER_SHELL:-}"

    if [[ -z "$shell_name" && -n "${SHELL:-}" ]]; then
        shell_name="${SHELL##*/}"
    fi

    if [[ -z "$shell_name" ]]; then
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            shell_name="zsh"
        elif [[ -n "${BASH_VERSION:-}" ]]; then
            shell_name="bash"
        else
            shell_name="bash"
        fi
    fi

    printf "%s" "$shell_name"
}

# The profile file of a supported shell. Fails for any other shell: the lines
# the installer adds are Bash/Zsh syntax, and so is the helper.
gaudi_helper_profile_for_shell() {
    local shell_name="$1"

    case "$shell_name" in
        zsh)
            printf "%s" "${GAUDI_HELPER_PROFILE:-$HOME/.zshrc}"
            ;;
        bash)
            if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
                printf "%s" "${GAUDI_HELPER_PROFILE:-$HOME/.bash_profile}"
            else
                printf "%s" "${GAUDI_HELPER_PROFILE:-$HOME/.bashrc}"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

gaudi_helper_install_shell_integration() {
    local helper_dir="$1"
    local shell_name=""
    local profile=""

    shell_name="$(gaudi_helper_detect_shell)"
    if ! profile="$(gaudi_helper_profile_for_shell "$shell_name")"; then
        printf "gaudi-helper works in Bash and Zsh, not in %s: no shell profile was changed.\n" "$shell_name" >&2
        printf "To use it from Bash or Zsh, run the installer again with GAUDI_HELPER_SHELL=bash or GAUDI_HELPER_SHELL=zsh.\n" >&2
        return 1
    fi

    gaudi_helper_append_once "$profile" "export GAUDI_HELPER_DIR=\"$helper_dir\""
    # gaudi-helper.sh loads bash-preexec itself when the shell is Bash
    gaudi_helper_append_once "$profile" '[ -r "$GAUDI_HELPER_DIR/gaudi-helper.sh" ] && source "$GAUDI_HELPER_DIR/gaudi-helper.sh"'
    printf "Installed gaudi-helper shell integration in %s\n" "$profile"
}
