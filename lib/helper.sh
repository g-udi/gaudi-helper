#!/usr/bin/env bash
# shellcheck shell=bash

gaudi_helper_trim() {
    local value="$*"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf "%s" "$value"
}

gaudi_helper_strip_ansi() {
    sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g'
}

# Collapse a value to a single trimmed line
gaudi_helper_one_line() {
    gaudi_helper_trim "$(printf "%s" "$*" | tr '\n\r\t' '   ')"
}

# Escape a value for use inside a double-quoted Bash string: Gaudi sources the
# list files, so nothing in a description may be expanded or executed.
gaudi_helper_escape_entry() {
    printf "%s" "$1" | sed 's/[\\"$`]/\\&/g'
}

gaudi_helper_join_info() {
    local package_name="$1"
    local description="${2:-}"
    local website="${3:-}"
    local details=""

    description="$(gaudi_helper_trim "$description")"
    website="$(gaudi_helper_trim "$website")"
    details="$(gaudi_helper_trim "$description $website")"

    printf "%s::%s" "$package_name" "$details"
}

gaudi_helper_brew_info() {
    local package_name="$1"
    local description=""
    local website=""

    description="$(brew desc --eval-all "$package_name" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//' | head -n 1)"
    website="$(brew info "$package_name" 2>/dev/null | gaudi_helper_strip_ansi | awk '/^https?:\/\// { print; exit }')"
    [[ -n "$description$website" ]] || return 1
    gaudi_helper_join_info "$package_name" "$description" "$website"
}

gaudi_helper_cask_info() {
    local package_name="$1"
    local description=""
    local website=""

    description="$(brew info --cask "$package_name" 2>/dev/null | awk '/^==> Description/{ getline; print; exit }')"
    website="$(brew info --cask "$package_name" 2>/dev/null | gaudi_helper_strip_ansi | awk '/^https?:\/\// { print; exit }')"
    [[ -n "$description$website" ]] || return 1
    gaudi_helper_join_info "$package_name" "$description" "$website"
}

gaudi_helper_npm_info() {
    local package_name="$1"
    local description=""
    local website=""

    description="$(npm view "$package_name" description 2>/dev/null | head -n 1)"
    website="$(npm view "$package_name" homepage 2>/dev/null | head -n 1)"
    [[ -n "$description$website" ]] || return 1
    gaudi_helper_join_info "$package_name" "$description" "$website"
}

gaudi_helper_apt_info() {
    local package_name="$1"
    local description=""
    local website=""

    command -v apt-cache >/dev/null 2>&1 || return 1
    description="$(apt-cache show "$package_name" 2>/dev/null | awk -F': ' '/^Description:/ { print $2; exit }')"
    website="$(apt-cache show "$package_name" 2>/dev/null | awk -F': ' '/^Homepage:/ { print $2; exit }')"
    [[ -n "$description$website" ]] || return 1
    gaudi_helper_join_info "$package_name" "$description" "$website"
}

# The name of a Mac App Store app from its id (empty when mas cannot tell).
# `mas list` answers offline for installed apps; `mas info` asks the store.
gaudi_helper_mas_name() {
    local app_id="$1"
    local name=""

    command -v mas >/dev/null 2>&1 || return 0

    # "497799835  Xcode  (15.4)"
    name="$(mas list 2>/dev/null | awk -v id="$app_id" '$1 == id { $1 = ""; sub(/[ \t]*\([^()]*\)[ \t]*$/, ""); print; exit }')"
    # "Xcode 15.4 [Free]"
    [[ -n "$name" ]] || name="$(mas info "$app_id" 2>/dev/null | head -n 1 | sed -E 's/ *\[[^]]*\] *$//; s/ +[0-9][^ ]*$//')"

    # The name is written inside a double-quoted Brewfile (Ruby) string
    gaudi_helper_one_line "$(printf "%s" "$name" | sed 's/["\\]//g; s/#{//g')"
}

gaudi_helper_mas_info() {
    local package_name="$1"

    gaudi_helper_join_info "$package_name" "$(gaudi_helper_mas_name "$package_name")"
}

gaudi_helper_get_software_info() {
    local target="$1"
    local package_name="$2"

    case "$target" in
        brew)
            gaudi_helper_brew_info "$package_name"
            ;;
        cask)
            gaudi_helper_cask_info "$package_name"
            ;;
        npm)
            gaudi_helper_npm_info "$package_name"
            ;;
        apt)
            gaudi_helper_apt_info "$package_name"
            ;;
        mas)
            gaudi_helper_mas_info "$package_name"
            ;;
        tap|gem)
            gaudi_helper_join_info "$package_name"
            ;;
        *)
            return 1
            ;;
    esac
}

# Backwards-compatible API used by older tests and callers.
getSoftwareInfo() {
    local command_name="$1"
    local package_name="$2"
    local info_command="${3:-}"

    if [[ "$info_command" == "*" ]]; then
        gaudi_helper_join_info "$package_name"
        return 0
    fi

    case "$command_name" in
        brew|cask|npm|tap|gem|apt|mas)
            gaudi_helper_get_software_info "$command_name" "$package_name"
            ;;
        *)
            return 1
            ;;
    esac
}

export -f getSoftwareInfo >/dev/null 2>&1 || true
