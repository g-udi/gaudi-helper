#!/usr/bin/env bash
# shellcheck shell=bash

GAUDI="${GAUDI:-$HOME/.gaudi}"
GAUDI_HELPER_DIR="${GAUDI_HELPER_DIR:-$GAUDI/gaudi-helper}"
GAUDI_HELPER_LIST_DIR="${GAUDI_HELPER_LIST_DIR:-$GAUDI/templates/lists}"

GAUDI_HELPER_GREEN="${GAUDI_HELPER_GREEN:-\\033[0;32m}"
GAUDI_HELPER_YELLOW="${GAUDI_HELPER_YELLOW:-\\033[0;33m}"
GAUDI_HELPER_RED="${GAUDI_HELPER_RED:-\\033[0;31m}"
GAUDI_HELPER_NC="${GAUDI_HELPER_NC:-\\033[0m}"

# shellcheck source=/dev/null
source "$GAUDI_HELPER_DIR/lib/helper.sh"

gaudi_helper_log() {
    printf "%b\n" "${GAUDI_HELPER_GREEN}[ GAUDI ]${GAUDI_HELPER_NC} $*"
}

gaudi_helper_warn() {
    printf "%b\n" "${GAUDI_HELPER_RED}[ GAUDI ]${GAUDI_HELPER_NC} $*" >&2
}

gaudi_helper_list_file_for_target() {
    local target="$1"
    local file_name=""

    case "$target" in
        apt)
            file_name="default.apt-get.sh"
            ;;
        brew|cask|tap|npm|pip|gem|mas)
            file_name="default.${target}.list.sh"
            ;;
        *)
            return 1
            ;;
    esac

    printf "%s/%s" "$GAUDI_HELPER_LIST_DIR" "$file_name"
}

gaudi_helper_reject_complex_command() {
    case "$1" in
        *";"*|*"&&"*|*"||"*|*"|"*|*"\`"*|*'$('*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

gaudi_helper_normalize_command() {
    local command_text="$1"

    command_text="$(gaudi_helper_trim "$command_text")"

    printf "%s\n" "$command_text" | awk '
        {
            i = 1
            while (i <= NF) {
                if ($i == "command") {
                    i++
                    continue
                }

                if ($i == "env") {
                    i++
                    while (i <= NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
                        i++
                    }
                    continue
                }

                if ($i == "sudo") {
                    i++
                    while (i <= NF && $i ~ /^-/) {
                        if ($i ~ /^(-[Cghpu]|--askpass|--background|--chdir|--close-from|--group|--host|--login-class|--prompt|--role|--type|--user)$/) {
                            i += 2
                        } else {
                            i++
                        }
                    }
                    continue
                }

                break
            }

            for (; i <= NF; i++) {
                printf "%s%s", sep, $i
                sep = " "
            }
        }
    '
}

gaudi_helper_filter_package_args() {
    local args="$1"

    printf "%s\n" "$args" | awk '
        function option_takes_value(token) {
            return token ~ /^(-[CcefiIoprt]|--appdir|--arch|--cache|--config|--constraint|--editable|--extra-index-url|--find-links|--fontdir|--globalconfig|--index-url|--language|--location|--prefix|--registry|--root|--target|--userconfig)$/
        }

        {
            for (i = 1; i <= NF; i++) {
                token = $i

                if (skip_next == 1) {
                    skip_next = 0
                    continue
                }

                if (token == "--") {
                    passthrough = 1
                    continue
                }

                if (passthrough != 1 && token ~ /^-/) {
                    if (option_takes_value(token)) {
                        skip_next = 1
                    }
                    continue
                }

                printf "%s%s", sep, token
                sep = " "
            }
        }
    '
}

gaudi_helper_args_contain() {
    local args=" $1 "
    local flag="$2"

    [[ "$args" == *" ${flag} "* ]]
}

gaudi_helper_npm_args_are_global() {
    local args=" $1 "

    [[ "$args" == *" -g "* ]] ||
        [[ "$args" == *" --global "* ]] ||
        [[ "$args" == *" --location=global "* ]] ||
        [[ "$args" == *" --location global "* ]]
}

gaudi_helper_detect_install() {
    local command_text="$1"
    local manager=""
    local action=""
    local rest=""
    local target=""
    local packages=""

    command_text="$(gaudi_helper_normalize_command "$command_text")"
    gaudi_helper_reject_complex_command "$command_text" && return 1

    manager="${command_text%% *}"
    rest="${command_text#"$manager"}"
    rest="$(gaudi_helper_trim "$rest")"
    action="${rest%% *}"
    rest="${rest#"$action"}"
    rest="$(gaudi_helper_trim "$rest")"

    case "$manager:$action" in
        brew:install)
            if gaudi_helper_args_contain "$rest" "--cask"; then
                target="cask"
            else
                target="brew"
            fi
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        brew:cask)
            action="${rest%% *}"
            [[ "$action" == "install" ]] || return 1
            rest="${rest#"$action"}"
            target="cask"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        brew:tap)
            target="tap"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        npm:install|npm:i)
            gaudi_helper_npm_args_are_global "$rest" || return 1
            target="npm"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        pip:install|pip3:install)
            target="pip"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        python:-m|python3:-m)
            action="${rest%% *}"
            rest="${rest#"$action"}"
            rest="$(gaudi_helper_trim "$rest")"
            [[ "$action" == "pip" && "${rest%% *}" == "install" ]] || return 1
            rest="${rest#install}"
            target="pip"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        gem:install)
            target="gem"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        apt:install|apt-get:install)
            target="apt"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        mas:install)
            target="mas"
            packages="$(gaudi_helper_filter_package_args "$rest")"
            ;;
        *)
            return 1
            ;;
    esac

    [[ -n "$packages" ]] || return 1

    printf "%s|%s" "$target" "$packages"
}

gaudi_helper_escape_entry() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf "%s" "$value"
}

gaudi_helper_add_to_list() {
    local list_file="$1"
    local package_name="$2"
    local software_info="$3"
    local escaped_info=""
    local tmp_file=""

    if [[ ! -f "$list_file" ]]; then
        gaudi_helper_warn "No Gaudi list found at $list_file"
        return 0
    fi

    if grep -Fq "\"${package_name}::" "$list_file"; then
        gaudi_helper_log "${package_name} is already present in $(basename "$list_file")"
        return 0
    fi

    escaped_info="$(gaudi_helper_escape_entry "$software_info")"
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/gaudi-helper.XXXXXX")" || return 1

    awk -v entry="    \"${escaped_info}\"" '
        /^[[:space:]]*\)[[:space:]]*$/ && inserted == 0 {
            print entry
            inserted = 1
        }
        { print }
        END {
            if (inserted == 0) {
                print entry
            }
        }
    ' "$list_file" > "$tmp_file" && mv "$tmp_file" "$list_file"

    gaudi_helper_log "Added ${GAUDI_HELPER_YELLOW}${package_name}${GAUDI_HELPER_NC} to $(basename "$list_file")"
}

gaudi_helper_process_command() {
    local command_text="$1"
    local detection=""
    local target=""
    local packages=""
    local list_file=""
    local package_name=""
    local software_info=""

    detection="$(gaudi_helper_detect_install "$command_text")" || return 0
    target="${detection%%|*}"
    packages="${detection#*|}"
    list_file="$(gaudi_helper_list_file_for_target "$target")" || return 0

    printf "%s\n" "$packages" | awk '{ for (i = 1; i <= NF; i++) print $i }' | while IFS= read -r package_name; do
        [[ -n "$package_name" ]] || continue
        software_info="$(gaudi_helper_get_software_info "$target" "$package_name" 2>/dev/null || gaudi_helper_join_info "$package_name")"
        gaudi_helper_add_to_list "$list_file" "$package_name" "$software_info"
    done
}

gaudi_helper_preexec() {
    GAUDI_HELPER_PENDING_COMMAND="$1"
}

gaudi_helper_precmd() {
    local command_status="$?"
    local pending_command="${GAUDI_HELPER_PENDING_COMMAND:-}"

    unset GAUDI_HELPER_PENDING_COMMAND
    [[ -n "$pending_command" ]] || return "$command_status"
    [[ "$command_status" -eq 0 ]] || return "$command_status"

    gaudi_helper_process_command "$pending_command"
    return "$command_status"
}

gaudi_helper_array_contains() {
    local needle="$1"
    local item=""
    shift

    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

gaudi_helper_register_bash_hooks() {
    if [[ -z "${__bp_imported:-}" && -r "$GAUDI_HELPER_DIR/lib/bash-prexec.sh" ]]; then
        # shellcheck source=/dev/null
        source "$GAUDI_HELPER_DIR/lib/bash-prexec.sh"
    fi

    gaudi_helper_array_contains gaudi_helper_preexec "${preexec_functions[@]:-}" || preexec_functions+=(gaudi_helper_preexec)
    gaudi_helper_array_contains gaudi_helper_precmd "${precmd_functions[@]:-}" || precmd_functions+=(gaudi_helper_precmd)
}

gaudi_helper_register_zsh_hooks() {
    autoload -Uz add-zsh-hook 2>/dev/null || return 1
    add-zsh-hook -d preexec gaudi_helper_preexec 2>/dev/null || true
    add-zsh-hook -d precmd gaudi_helper_precmd 2>/dev/null || true
    add-zsh-hook preexec gaudi_helper_preexec
    add-zsh-hook precmd gaudi_helper_precmd
}

gaudi_helper_register_hooks() {
    [[ "${GAUDI_HELPER_NO_HOOKS:-false}" == "true" ]] && return 0

    if [[ -n "${BASH_VERSION:-}" ]]; then
        gaudi_helper_register_bash_hooks
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        gaudi_helper_register_zsh_hooks || gaudi_helper_warn "Unable to register zsh hooks"
    else
        gaudi_helper_warn "Unsupported shell for automatic command tracking"
    fi
}

gaudi_helper_register_hooks
