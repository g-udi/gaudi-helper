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
            printf "%s" "${GAUDI_HELPER_PROFILE:-$HOME/.profile}"
            ;;
    esac
}

gaudi_helper_install_shell_integration() {
    local helper_dir="$1"
    local shell_name=""
    local profile=""

    shell_name="$(gaudi_helper_detect_shell)"
    profile="$(gaudi_helper_profile_for_shell "$shell_name")"

    gaudi_helper_append_once "$profile" "export GAUDI_HELPER_DIR=\"$helper_dir\""

    if [[ "$shell_name" == "bash" ]]; then
        gaudi_helper_append_once "$profile" '[ -r "$GAUDI_HELPER_DIR/lib/bash-prexec.sh" ] && source "$GAUDI_HELPER_DIR/lib/bash-prexec.sh"'
    fi

    gaudi_helper_append_once "$profile" '[ -r "$GAUDI_HELPER_DIR/gaudi-helper.sh" ] && source "$GAUDI_HELPER_DIR/gaudi-helper.sh"'
    printf "Installed gaudi-helper shell integration in %s\n" "$profile"
}

# Backwards-compatible wrapper used by older install flows.
set_environment_exports() {
    local line="$1"
    local shell_scope="${2:-}"
    local profile=""

    if [[ "$shell_scope" == "bash" ]]; then
        profile="$(gaudi_helper_profile_for_shell bash)"
    else
        profile="$(gaudi_helper_profile_for_shell "$(gaudi_helper_detect_shell)")"
    fi

    gaudi_helper_append_once "$profile" "$line"
}
