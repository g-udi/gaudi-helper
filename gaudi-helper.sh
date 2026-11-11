#!/usr/bin/env bash
# shellcheck shell=bash
#
# Sourced by interactive Bash (3.2 and later) and Zsh, so everything here has
# to stay within the syntax both shells share. External tools are called
# through `command` so that interactive aliases (rm -i, mv -i, ...) do not
# change how the helper behaves.

GAUDI="${GAUDI:-$HOME/.gaudi}"
GAUDI_HELPER_DIR="${GAUDI_HELPER_DIR:-$GAUDI/gaudi-helper}"
# The directory Gaudi reads Brewfiles and lists from
GAUDI_HELPER_TEMPLATES_DIR="${GAUDI_TEMPLATES_LOCATION:-$GAUDI/templates}"
# Where a Brewfile or list is created when the templates do not have one yet
GAUDI_HELPER_LIST_DIR="${GAUDI_HELPER_LIST_DIR:-$GAUDI_HELPER_TEMPLATES_DIR/lists}"

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

# --- Reading the command -------------------------------------------------------

gaudi_helper_reject_complex_command() {
    case "$1" in
        *";"*|*"&"*|*"|"*|*"<"*|*">"*|*"\`"*|*'$('*|*"
"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Print the command without what can stand in front of it (variable
# assignments, command, env, sudo, time, noglob, nocorrect) and without a
# trailing "# comment".
gaudi_helper_normalize_command() {
    local command_text="$1"

    command_text="$(gaudi_helper_trim "$command_text")"
    # A comment starts at a "#" that begins a word
    case "$command_text" in
        "#"*) command_text="" ;;
        *[[:space:]]"#"*) command_text="$(gaudi_helper_trim "${command_text%%[[:space:]]"#"*}")" ;;
    esac

    printf "%s\n" "$command_text" | command awk '
        {
            i = 1
            while (i <= NF) {
                if ($i == "command" || $i == "noglob" || $i == "nocorrect") {
                    i++
                    continue
                }

                # NAME=value in front of the command
                if ($i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
                    i++
                    continue
                }

                if ($i == "time") {
                    i++
                    while (i <= NF && $i ~ /^-/) {
                        i++
                    }
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

# Options that are followed by a separate value, per package manager, so the
# value is not mistaken for a package name.
gaudi_helper_value_options() {
    case "$1" in
        brew|cask|tap)
            printf "%s" "--[a-z0-9-]*dir|--language|--cc|--env|--bottle-arch|--os|--arch"
            ;;
        npm)
            printf "%s" "--location|--registry|--prefix|--cache|--userconfig|--globalconfig|--tag|--otp|-w|--workspace"
            ;;
        uv)
            printf "%s" "-p|--python|-w|--with|--with-editable|--with-requirements|--with-executables-from|-c|--constraints|-b|--build-constraints|--overrides|--excludes|-i|--index|--index-url|--default-index|--extra-index-url|-f|--find-links|--index-strategy|--keyring-provider|-P|--upgrade-package|--reinstall-package|--refresh-package|--resolution|--prerelease|--fork-strategy|--exclude-newer|--exclude-newer-package|--link-mode|-C|--config-setting|--config-settings-package|--no-build-package|--no-binary-package|--no-sources-package|--python-platform|--python-version|--torch-backend|--cache-dir|--color|--directory|--project|--config-file|--allow-insecure-host|--from|-e|--editable"
            ;;
        pipx)
            printf "%s" "--python|--pip-args|-i|--index-url|--suffix|--preinstall|--backend|--fetch-python"
            ;;
        cargo)
            printf "%s" "--version|--vers|--git|--branch|--tag|--rev|--path|--root|--index|--registry|-j|--jobs|--profile|--target|--target-dir|-F|--features|--bin|--example|--config|-Z|--color|--message-format|--lockfile-path"
            ;;
        go)
            printf "%s" "-C|-p|-asmflags|-buildmode|-buildvcs|-compiler|-gccgoflags|-gcflags|-installsuffix|-ldflags|-mod|-modfile|-overlay|-pgo|-pkgdir|-tags|-toolexec|-exec"
            ;;
        gem)
            printf "%s" "-v|--version|-i|--install-dir|-n|--bindir|-s|--source|-P|--trust-policy|-g|--file|--platform|-p|--http-proxy|--build-root|--document|--target-rbconfig|--without|--config-file"
            ;;
        apt)
            printf "%s" "-t|--target-release|-o|--option|-c|--config-file"
            ;;
        dnf)
            printf "%s" "--repo|--repoid|--enablerepo|--disablerepo|--releasever|--installroot|--setopt|-x|--exclude|-c|--config|--forcearch|--advisory|--comment"
            ;;
        pacman)
            printf "%s" "-b|--dbpath|-r|--root|--arch|--cachedir|--color|--config|--gpgdir|--hookdir|--logfile|--sysroot|--assume-installed|--ignore|--ignoregroup|--overwrite|--print-format"
            ;;
        zypper)
            printf "%s" "-R|--root|-r|--repo|--from|-t|--type|-C|--capability|--download|--solver-focus"
            ;;
        *)
            printf "%s" "--"
            ;;
    esac
}

# Drop options (and the values of options that take one), keep the rest.
#   gaudi_helper_filter_package_args <arguments> <manager>
gaudi_helper_filter_package_args() {
    local args="$1"
    local value_options=""

    value_options="$(gaudi_helper_value_options "${2:-}")"

    printf "%s\n" "$args" | command awk -v value_options="$value_options" '
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
                    if (token ~ ("^(" value_options ")$")) {
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

#   gaudi_helper_args_contain_any <arguments> <flag>...
gaudi_helper_args_contain_any() {
    local args="$1"
    local flag=""
    shift

    for flag in "$@"; do
        gaudi_helper_args_contain "$args" "$flag" && return 0
    done
    return 1
}

gaudi_helper_npm_args_are_global() {
    local args=" $1 "

    [[ "$args" == *" -g "* ]] ||
        [[ "$args" == *" --global "* ]] ||
        [[ "$args" == *" --location=global "* ]] ||
        [[ "$args" == *" --location global "* ]]
}

# Print "<target>|<packages>" for a command that installs something Gaudi can
# record, and fail for anything else.
gaudi_helper_detect_install() {
    local command_text="$1"
    local manager=""
    local action=""
    local rest=""
    local target=""
    local packages=""
    local value_options=""
    local option=""
    local leading=""

    command_text="$(gaudi_helper_normalize_command "$command_text")"
    gaudi_helper_reject_complex_command "$command_text" && return 1

    manager="${command_text%% *}"
    rest="${command_text#"$manager"}"
    rest="$(gaudi_helper_trim "$rest")"

    # Options may come before the subcommand (apt-get -y install, dnf -y
    # install, zypper --non-interactive install, npm -g install). They are set
    # aside, with the value of those that take one, and put back after the
    # subcommand so the checks below still see them. Not for pacman and code,
    # whose "subcommand" is itself an option.
    case "$manager" in
        pacman|code) ;;
        *)
            case "$manager" in
                apt-get) value_options="$(gaudi_helper_value_options apt)" ;;
                dnf5) value_options="$(gaudi_helper_value_options dnf)" ;;
                *) value_options="$(gaudi_helper_value_options "$manager")" ;;
            esac
            value_options="^(${value_options})\$"
            while [[ "$rest" == -* ]]; do
                option="${rest%% *}"
                leading="$leading $option"
                case "$rest" in
                    *" "*) rest="$(gaudi_helper_trim "${rest#* }")" ;;
                    *) rest="" ;;
                esac
                if [[ "$option" =~ $value_options && -n "$rest" ]]; then
                    leading="$leading ${rest%% *}"
                    case "$rest" in
                        *" "*) rest="$(gaudi_helper_trim "${rest#* }")" ;;
                        *) rest="" ;;
                    esac
                fi
            done
            ;;
    esac

    action="${rest%% *}"
    rest="${rest#"$action"}"
    rest="$(gaudi_helper_trim "$rest$leading")"

    # Asking for help or a dry run does not install anything
    gaudi_helper_args_contain_any "$rest" -h --help --dry-run && return 1

    case "$manager:$action" in
        brew:install)
            gaudi_helper_args_contain_any "$rest" -n --only-dependencies && return 1
            if gaudi_helper_args_contain_any "$rest" --cask --casks; then
                target="cask"
            else
                target="brew"
            fi
            packages="$(gaudi_helper_filter_package_args "$rest" brew)"
            ;;
        brew:cask)
            action="${rest%% *}"
            [[ "$action" == "install" ]] || return 1
            rest="${rest#"$action"}"
            target="cask"
            packages="$(gaudi_helper_filter_package_args "$rest" cask)"
            ;;
        brew:tap)
            target="tap"
            packages="$(gaudi_helper_filter_package_args "$rest" tap)"
            ;;
        mas:install|mas:get|mas:purchase)
            target="mas"
            packages="$(gaudi_helper_filter_package_args "$rest" mas)"
            ;;
        npm:install|npm:i|npm:add)
            gaudi_helper_npm_args_are_global "$rest" || return 1
            target="npm"
            packages="$(gaudi_helper_filter_package_args "$rest" npm)"
            ;;
        uv:tool)
            action="${rest%% *}"
            [[ "$action" == "install" ]] || return 1
            rest="${rest#"$action"}"
            # Installed from somewhere else than the package index: not reproducible by name
            gaudi_helper_args_contain_any "$rest" --from -e --editable && return 1
            target="uv"
            packages="$(gaudi_helper_filter_package_args "$rest" uv)"
            ;;
        pipx:install)
            gaudi_helper_args_contain_any "$rest" -e --editable && return 1
            target="uv"
            packages="$(gaudi_helper_filter_package_args "$rest" pipx)"
            ;;
        cargo:install)
            gaudi_helper_args_contain_any "$rest" --git --path --list && return 1
            target="cargo"
            packages="$(gaudi_helper_filter_package_args "$rest" cargo)"
            ;;
        go:install)
            target="go"
            packages="$(gaudi_helper_filter_package_args "$rest" go)"
            ;;
        code:*)
            target="vscode"
            packages="$(printf "%s\n" "$action $rest" | command awk '
                {
                    for (i = 1; i < NF; i++) {
                        if ($i == "--install-extension") {
                            printf "%s%s", sep, $(i + 1)
                            sep = " "
                            i++
                        }
                    }
                }
            ')"
            ;;
        gem:install)
            gaudi_helper_args_contain_any "$rest" --explain && return 1
            target="gem"
            packages="$(gaudi_helper_filter_package_args "$rest" gem)"
            ;;
        apt:install|apt-get:install)
            gaudi_helper_args_contain_any "$rest" -s --simulate --just-print --no-act --recon -d --download-only && return 1
            target="apt"
            packages="$(gaudi_helper_filter_package_args "$rest" apt)"
            ;;
        dnf:install|dnf5:install)
            gaudi_helper_args_contain_any "$rest" --downloadonly --assumeno && return 1
            target="dnf"
            packages="$(gaudi_helper_filter_package_args "$rest" dnf)"
            ;;
        pacman:-S|pacman:-Sy|pacman:-Syy|pacman:-Su|pacman:-Syu|pacman:-Syyu|pacman:--sync)
            gaudi_helper_args_contain_any "$rest" -w --downloadonly -p --print && return 1
            target="pacman"
            packages="$(gaudi_helper_filter_package_args "$rest" pacman)"
            ;;
        zypper:install|zypper:in)
            gaudi_helper_args_contain_any "$rest" -D -d --download-only && return 1
            target="zypper"
            packages="$(gaudi_helper_filter_package_args "$rest" zypper)"
            ;;
        *)
            return 1
            ;;
    esac

    [[ -n "$packages" ]] || return 1

    printf "%s|%s" "$target" "$packages"
}

# Turn one argument of an install command into the name to record: quotes and
# version constraints are removed, and anything that is not a plain package
# name (a path, a URL, a shell variable, a glob) is refused.
#   gaudi_helper_package_name <target> <argument>
gaudi_helper_package_name() {
    local target="$1"
    local name="$2"
    local allowed="A-Za-z0-9._+-"

    case "$name" in
        \"*\")
            name="${name#\"}"
            name="${name%\"}"
            ;;
        \'*\')
            name="${name#\'}"
            name="${name%\'}"
            ;;
    esac

    case "$name" in
        ""|-*|.*|/*|"~"*|*://*) return 1 ;;
    esac

    case "$target" in
        brew|cask)
            # name or owner/tap/name
            case "$name" in
                */*/*/*) return 1 ;;
                */*/*) ;;
                */*) return 1 ;;
            esac
            allowed="A-Za-z0-9@._+/-"
            ;;
        tap)
            case "$name" in
                */*/*) return 1 ;;
                */*) ;;
                *) return 1 ;;
            esac
            # Homebrew calls owner/homebrew-tools "owner/tools"
            case "$name" in
                */homebrew-?*) name="${name%%/*}/${name#*/homebrew-}" ;;
            esac
            allowed="A-Za-z0-9._/-"
            ;;
        mas)
            allowed="0-9"
            ;;
        npm)
            case "$name" in
                @*/*/*|*.tgz|*.tar.gz) return 1 ;;
                @*/*@*) name="${name%@*}" ;;
                @*/*) ;;
                */*|@*) return 1 ;;
                *@*) name="${name%%@*}" ;;
            esac
            allowed="A-Za-z0-9@._/-"
            ;;
        uv)
            name="${name%%\[*}"
            name="${name%%=*}"
            name="${name%%@*}"
            name="${name%%\~*}"
            name="${name%%\!*}"
            allowed="A-Za-z0-9._-"
            ;;
        cargo)
            name="${name%%@*}"
            allowed="A-Za-z0-9_-"
            ;;
        go)
            name="${name%%@*}"
            case "$name" in
                */*) ;;
                *) return 1 ;;
            esac
            allowed="A-Za-z0-9._~+/-"
            ;;
        vscode)
            name="${name%%@*}"
            case "$name" in
                *.vsix|*/*) return 1 ;;
                *.*) ;;
                *) return 1 ;;
            esac
            allowed="A-Za-z0-9._-"
            ;;
        gem)
            name="${name%%:*}"
            case "$name" in
                *.gem) return 1 ;;
            esac
            allowed="A-Za-z0-9._-"
            ;;
        apt)
            name="${name%%=*}"
            name="${name%%/*}"
            case "$name" in
                *.deb) return 1 ;;
            esac
            allowed="A-Za-z0-9.+:_-"
            ;;
        dnf|zypper)
            name="${name%%=*}"
            case "$name" in
                *.rpm) return 1 ;;
            esac
            allowed="A-Za-z0-9.+_-"
            ;;
        pacman)
            # repository/package
            name="${name##*/}"
            name="${name%%=*}"
            allowed="A-Za-z0-9@.+_-"
            ;;
        *)
            return 1
            ;;
    esac

    allowed="^[${allowed}]+\$"
    [[ "$name" =~ $allowed ]] || return 1

    printf "%s" "$name"
}

# --- Finding the file to write to ------------------------------------------------

#   gaudi_helper_find_templates <find expression>...
gaudi_helper_find_templates() {
    {
        command find "$GAUDI_HELPER_TEMPLATES_DIR" -type f "$@" ! -path "*/.git/*" -print 2>/dev/null
        case "$GAUDI_HELPER_LIST_DIR/" in
            "$GAUDI_HELPER_TEMPLATES_DIR"/*)
                ;;
            *)
                [[ -d "$GAUDI_HELPER_LIST_DIR" ]] &&
                    command find "$GAUDI_HELPER_LIST_DIR" -type f "$@" ! -path "*/.git/*" -print 2>/dev/null
                ;;
        esac
    } | command sort -u
}

# Every Brewfile Gaudi would install: Brewfile or <name>.Brewfile, anywhere
gaudi_helper_brewfiles() {
    gaudi_helper_find_templates \( -name "Brewfile" -o -name "*.Brewfile" \)
}

# Every list Gaudi would read for a type, by the same file names Gaudi matches
gaudi_helper_list_files() {
    local list_type="$1"

    gaudi_helper_find_templates \
        \( -iname "*.${list_type}.list.sh" -o -iname "*.${list_type}.sh" -o -iname "*.${list_type}-*.list.sh" -o -iname "*.${list_type}-*.sh" \) \
        ! -iname "*.hooks.sh"
}

# The Brewfile an entry type goes to when no Brewfile holds that type yet
gaudi_helper_brewfile_for_type() {
    case "$1" in
        tap|brew) printf "core.Brewfile" ;;
        cask) printf "apps.Brewfile" ;;
        mas) printf "appstore.Brewfile" ;;
        npm) printf "npm.Brewfile" ;;
        uv) printf "python.Brewfile" ;;
        cargo) printf "cargo.Brewfile" ;;
        go) printf "go.Brewfile" ;;
        vscode) printf "vscode.Brewfile" ;;
        *) return 1 ;;
    esac
}

gaudi_helper_brewfile_header() {
    local title=""
    local description=""

    case "$1" in
        core.Brewfile)
            title="Core tools"
            description="Command-line tools and libraries installed with Homebrew"
            ;;
        apps.Brewfile)
            title="Applications"
            description="Desktop applications installed as Homebrew casks"
            ;;
        appstore.Brewfile)
            title="Mac App Store"
            description="Apps from the Mac App Store (sign in to the App Store app first)"
            ;;
        npm.Brewfile)
            title="npm globals"
            description="Global npm packages (needs node and npm on PATH)"
            ;;
        python.Brewfile)
            title="Python tools"
            description="Python command-line tools, isolated with uv instead of pip --user"
            ;;
        cargo.Brewfile)
            title="Cargo crates"
            description="Rust command-line tools installed with cargo"
            ;;
        go.Brewfile)
            title="Go tools"
            description="Go command-line tools installed with go install"
            ;;
        vscode.Brewfile)
            title="VS Code extensions"
            description="Extensions for Visual Studio Code"
            ;;
        *)
            return 1
            ;;
    esac

    printf "# @Name: %s\n# @Description: %s\n" "$title" "$description"
}

# Reads Brewfile paths on stdin and prints one line saying what to do:
#   present<TAB><file>   the entry is already in <file>
#   append<TAB><file>    add it to <file>: the conventional Brewfile if it holds
#                        entries of this type, else the Brewfile holding the
#                        most of them (the first one on a tie), else the
#                        conventional file if it exists
#   create               no suitable Brewfile exists yet
# GAUDI_HELPER_TYPE is the entry type, GAUDI_HELPER_KEY the name (the id for
# mas), GAUDI_HELPER_FILE the conventional file name.
# shellcheck disable=SC2016
GAUDI_HELPER_BREWFILE_PLAN='
    function norm(name) {
        name = tolower(name)
        if (type == "brew" || type == "cask") {
            sub(/^.*\//, "", name)
        } else if (type == "tap") {
            sub(/\/homebrew-/, "/", name)
        } else if (type == "uv") {
            gsub(/[._]+/, "-", name)
        }
        return name
    }

    BEGIN {
        type = ENVIRON["GAUDI_HELPER_TYPE"]
        key = norm(ENVIRON["GAUDI_HELPER_KEY"])
        wanted = ENVIRON["GAUDI_HELPER_FILE"]
        quote = "[\"\047]"
        pattern = "^[ \t]*" type "[ \t]+" quote "[^\"\047]+" quote
    }

    {
        file = $0
        base = file
        sub(/^.*\//, "", base)
        holds = 0

        while ((getline text < file) > 0) {
            if (!match(text, pattern)) {
                continue
            }
            holds++
            entry = substr(text, RSTART, RLENGTH)
            rest = substr(text, RSTART + RLENGTH)
            sub("^[^\"\047]*" quote, "", entry)
            sub(quote "$", "", entry)
            if (type == "mas") {
                entry = ""
                if (match(rest, /id:[ \t]*[0-9]+/)) {
                    entry = substr(rest, RSTART, RLENGTH)
                    sub(/^id:[ \t]*/, "", entry)
                }
            }
            if (norm(entry) == key) {
                printf "present\t%s\n", file
                found = 1
                exit
            }
        }
        close(file)

        if (holds && !holder_wanted && (base == wanted || holds > most)) {
            holder = file
            most = holds
            holder_wanted = (base == wanted)
        }
        if (base == wanted && named == "") {
            named = file
        }
    }

    END {
        if (found) {
            exit
        }
        if (holder != "") {
            printf "append\t%s\n", holder
        } else if (named != "") {
            printf "append\t%s\n", named
        } else {
            print "create"
        }
    }
'

# Reads the current Brewfile on stdin and prints it with GAUDI_HELPER_ENTRY
# added. Entries go at the end. With GAUDI_HELPER_ARG=tap the entry goes after
# the last tap, or right after the "# @" header when there is no tap yet, so
# taps stay above the packages that need them.
# shellcheck disable=SC2016
GAUDI_HELPER_BREWFILE_ADD='
    BEGIN {
        entry = ENVIRON["GAUDI_HELPER_ENTRY"]
        after = ENVIRON["GAUDI_HELPER_ARG"]
        pattern = "^[ \t]*" after "[ \t]+[\"\047]"
    }

    {
        text[NR] = $0
        if (after != "" && $0 ~ pattern) {
            last = NR
        }
        if (header == NR - 1 && $0 ~ /^# @/) {
            header = NR
        }
    }

    END {
        if (after == "") {
            for (i = 1; i <= NR; i++) {
                print text[i]
            }
            # A comment directly above an entry is read as its description
            if (NR > 0 && text[NR] ~ /^[ \t]*#/) {
                print ""
            }
            print entry
            exit
        }

        position = last ? last : header
        for (i = 1; i <= position; i++) {
            print text[i]
        }
        if (!last && position > 0) {
            print ""
        }
        print entry
        if (!last && position < NR && text[position + 1] !~ /^[ \t]*$/) {
            print ""
        }
        for (i = position + 1; i <= NR; i++) {
            print text[i]
        }
    }
'

# Reads list paths on stdin and prints one line saying what to do:
#   present<TAB><file>           the package is already in <file>
#   append<TAB><array><TAB><file>  add it to the array <array> of <file>
#                                (default.<type>.list.sh if it exists)
#   create                       there is no list of this type yet
# shellcheck disable=SC2016
GAUDI_HELPER_LIST_PLAN='
    BEGIN {
        key = ENVIRON["GAUDI_HELPER_KEY"]
        wanted = ENVIRON["GAUDI_HELPER_FILE"]
        plain = "\"" key "\""
        described = "\"" key "::"
    }

    {
        file = $0
        base = file
        sub(/^.*\//, "", base)
        list = ""

        while ((getline text < file) > 0) {
            if (list == "" && text ~ /^# @List:/) {
                list = text
                sub(/^# @List:[ \t]*/, "", list)
                sub(/[ \t\r]+$/, "", list)
            }
            if (text ~ /^[ \t]*#/) {
                continue
            }
            if (index(text, plain) > 0 || index(text, described) > 0) {
                printf "present\t%s\n", file
                found = 1
                exit
            }
        }
        close(file)

        if (list ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && (target == "" || (base == wanted && !target_wanted))) {
            target = file
            target_list = list
            target_wanted = (base == wanted)
        }
    }

    END {
        if (found) {
            exit
        }
        if (target != "") {
            printf "append\t%s\t%s\n", target_list, target
        } else {
            print "create"
        }
    }
'

# Reads the current list on stdin and prints it with GAUDI_HELPER_ENTRY added
# as the last item of the array named GAUDI_HELPER_ARG. Fails, printing an
# incomplete file that must be thrown away, when the array cannot be found.
# shellcheck disable=SC2016
GAUDI_HELPER_LIST_ADD='
    BEGIN {
        entry = ENVIRON["GAUDI_HELPER_ENTRY"]
        opening = "^[ \t]*" ENVIRON["GAUDI_HELPER_ARG"] "=\\("
    }

    state == 0 && $0 ~ opening {
        if ($0 ~ /\)[ \t]*$/) {
            # The whole array is on one line: array=() or array=("a" "b")
            sub(/[ \t]*\)[ \t]*$/, "")
            print
            print entry
            print ")"
            state = 2
            next
        }
        state = 1
        print
        next
    }

    state == 1 && /^[ \t]*\)[ \t]*$/ {
        print entry
        state = 2
    }

    { print }

    END {
        exit (state == 2 ? 0 : 1)
    }
'

# --- Writing ---------------------------------------------------------------------

# Rewrite a file through an awk program: the current content is read from
# stdin, the result is written next to the file and moved into place only when
# the program succeeded, so a failure never leaves a half-written file.
#   gaudi_helper_write_file <file> <awk program> <entry> <argument> [list]
gaudi_helper_write_file() {
    local file="$1"
    local program="$2"
    local entry="$3"
    local argument="${4:-}"
    local kind="${5:-}"
    local dir="${file%/*}"
    local tmp_file=""

    command mkdir -p "$dir" || return 1
    tmp_file="$(command mktemp "$dir/.gaudi-helper.XXXXXX")" || return 1

    # Keep the permissions of the file being replaced
    if [[ -f "$file" ]]; then
        command cp -p "$file" "$tmp_file" 2>/dev/null
    else
        command chmod 644 "$tmp_file"
    fi

    if GAUDI_HELPER_ENTRY="$entry" GAUDI_HELPER_ARG="$argument" command awk "$program" >| "$tmp_file" &&
        { [[ "$kind" != "list" ]] || ! command -v bash >/dev/null 2>&1 || command bash -n "$tmp_file" 2>/dev/null; } &&
        command mv -f "$tmp_file" "$file"; then
        return 0
    fi

    command rm -f "$tmp_file"
    return 1
}

gaudi_helper_display_path() {
    printf "%s" "${1#"$GAUDI_HELPER_TEMPLATES_DIR"/}"
}

# The description that goes with an entry, on one line (empty when unknown)
gaudi_helper_describe() {
    local info=""

    info="$(gaudi_helper_get_software_info "$1" "$2" 2>/dev/null)" || return 0
    gaudi_helper_one_line "${info#*::}"
}

#   gaudi_helper_add_to_brewfile <type> <name> <Brewfile line> [key] [lookup type]
gaudi_helper_add_to_brewfile() {
    local entry_type="$1"
    local package_name="$2"
    local entry="$3"
    local key="${4:-$2}"
    local lookup="${5:-$1}"
    local conventional=""
    local plan=""
    local file=""
    local description=""
    local position=""
    local created=""
    local tab=$'\t'

    conventional="$(gaudi_helper_brewfile_for_type "$entry_type")" || return 0
    plan="$(gaudi_helper_brewfiles |
        GAUDI_HELPER_TYPE="$entry_type" GAUDI_HELPER_KEY="$key" GAUDI_HELPER_FILE="$conventional" command awk "$GAUDI_HELPER_BREWFILE_PLAN")"

    case "$plan" in
        present"$tab"*)
            gaudi_helper_log "${package_name} is already present in $(gaudi_helper_display_path "${plan#*"$tab"}")"
            return 0
            ;;
        append"$tab"*)
            file="${plan#*"$tab"}"
            ;;
        create)
            file="$GAUDI_HELPER_LIST_DIR/$conventional"
            created=" (new file)"
            ;;
        *)
            return 0
            ;;
    esac

    description="$(gaudi_helper_describe "$lookup" "$package_name")"
    [[ -n "$description" ]] && entry="# ${description}
${entry}"
    [[ "$entry_type" == "tap" ]] && position="tap"

    if [[ -n "$created" ]]; then
        gaudi_helper_brewfile_header "$conventional" |
            gaudi_helper_write_file "$file" "$GAUDI_HELPER_BREWFILE_ADD" "$entry" "$position"
    else
        gaudi_helper_write_file "$file" "$GAUDI_HELPER_BREWFILE_ADD" "$entry" "$position" < "$file"
    fi || {
        gaudi_helper_warn "Could not add ${package_name} to $file"
        return 0
    }

    gaudi_helper_log "Added ${GAUDI_HELPER_YELLOW}${package_name}${GAUDI_HELPER_NC} to $(gaudi_helper_display_path "$file")${created}"
}

#   gaudi_helper_add_to_list <type> <name>
gaudi_helper_add_to_list() {
    local list_type="$1"
    local package_name="$2"
    local conventional="default.${list_type}.list.sh"
    local plan=""
    local file=""
    local list_name=""
    local description=""
    local entry=""
    local created=""
    local tab=$'\t'

    plan="$(gaudi_helper_list_files "$list_type" |
        GAUDI_HELPER_KEY="$package_name" GAUDI_HELPER_FILE="$conventional" command awk "$GAUDI_HELPER_LIST_PLAN")"

    case "$plan" in
        present"$tab"*)
            gaudi_helper_log "${package_name} is already present in $(gaudi_helper_display_path "${plan#*"$tab"}")"
            return 0
            ;;
        append"$tab"*)
            plan="${plan#*"$tab"}"
            list_name="${plan%%"$tab"*}"
            file="${plan#*"$tab"}"
            ;;
        create)
            list_name="${list_type}List"
            file="$GAUDI_HELPER_LIST_DIR/$conventional"
            created=" (new file)"
            ;;
        *)
            return 0
            ;;
    esac

    description="$(gaudi_helper_describe "$list_type" "$package_name")"
    if [[ -n "$description" ]]; then
        entry="    \"${package_name}::$(gaudi_helper_escape_entry "$description")\""
    else
        entry="    \"${package_name}\""
    fi

    if [[ -n "$created" ]]; then
        printf "# @Name: Default\n# @List: %s\n%s=(\n)\n" "$list_name" "$list_name" |
            gaudi_helper_write_file "$file" "$GAUDI_HELPER_LIST_ADD" "$entry" "$list_name" list
    else
        gaudi_helper_write_file "$file" "$GAUDI_HELPER_LIST_ADD" "$entry" "$list_name" list < "$file"
    fi || {
        gaudi_helper_warn "Could not add ${package_name} to $file: the ${list_name} array was not found or the result was not valid Bash"
        return 0
    }

    gaudi_helper_log "Added ${GAUDI_HELPER_YELLOW}${package_name}${GAUDI_HELPER_NC} to $(gaudi_helper_display_path "$file")${created}"
}

# `brew install <name>` installs a cask when no formula has that name. The
# Caskroom tells the two apart after the fact, without asking Homebrew.
gaudi_helper_brew_installed_a_cask() {
    local token="${1##*/}"
    local prefix="${HOMEBREW_PREFIX:-}"

    [[ -n "$prefix" ]] || prefix="$(brew --prefix 2>/dev/null)"
    [[ -n "$prefix" ]] || return 1
    [[ -d "$prefix/Caskroom/$token" && ! -d "$prefix/Cellar/$token" ]]
}

# Record one argument of a detected install command.
#   gaudi_helper_record <target> <argument> [tap URL]
gaudi_helper_record() {
    local target="$1"
    local package_name=""
    local remote="${3:-}"
    local app_name=""

    package_name="$(gaudi_helper_package_name "$target" "$2")" || return 0

    case "$target" in
        apt|dnf|pacman|zypper|gem)
            gaudi_helper_add_to_list "$target" "$package_name"
            ;;
        brew)
            if gaudi_helper_brew_installed_a_cask "$package_name"; then
                gaudi_helper_add_to_brewfile cask "$package_name" "cask \"${package_name}\""
            else
                gaudi_helper_add_to_brewfile brew "$package_name" "brew \"${package_name}\""
            fi
            ;;
        tap)
            case "$remote" in
                ""|*[!A-Za-z0-9@:/._~+-]*)
                    gaudi_helper_add_to_brewfile tap "$package_name" "tap \"${package_name}\""
                    ;;
                *)
                    gaudi_helper_add_to_brewfile tap "$package_name" "tap \"${package_name}\", \"${remote}\""
                    ;;
            esac
            ;;
        mas)
            app_name="$(gaudi_helper_mas_name "$package_name" 2>/dev/null)"
            app_name="${app_name:-$package_name}"
            # The name was looked up by id above; there is no description to look up ("none")
            gaudi_helper_add_to_brewfile mas "$app_name" "mas \"${app_name}\", id: ${package_name}" "$package_name" none
            ;;
        cask|npm|uv|cargo|go|vscode)
            gaudi_helper_add_to_brewfile "$target" "$package_name" "${target} \"${package_name}\""
            ;;
    esac
}

gaudi_helper_process_command() {
    local command_text="$1"
    local detection=""
    local target=""
    local packages=""
    local package_name=""

    detection="$(gaudi_helper_detect_install "$command_text")" || return 0
    target="${detection%%|*}"
    packages="${detection#*|}"

    if [[ ! -d "$GAUDI_HELPER_TEMPLATES_DIR" ]]; then
        gaudi_helper_warn "No Gaudi templates found at $GAUDI_HELPER_TEMPLATES_DIR"
        return 0
    fi

    if [[ "$target" == "tap" ]]; then
        # brew tap <owner/repo> [URL]
        package_name="${packages%% *}"
        case "$packages" in
            *" "*) packages="${packages#* }" ;;
            *) packages="" ;;
        esac
        gaudi_helper_record tap "$package_name" "${packages%% *}"
        return 0
    fi

    printf "%s\n" "$packages" | command awk '{ for (i = 1; i <= NF; i++) print $i }' | while IFS= read -r package_name; do
        [[ -n "$package_name" ]] || continue
        gaudi_helper_record "$target" "$package_name"
    done
}

# --- Shell hooks -------------------------------------------------------------------

# Remember the command only when it names a package manager somewhere. This
# runs before every interactive command, so it is one `case` and nothing is
# started for an ordinary command (ls, cd, git ...); whether it really is an
# install is worked out after it succeeded.
gaudi_helper_preexec() {
    case "$1" in
        *brew*|*mas*|*npm*|*uv*|*pipx*|*cargo*|*go*|*code*|*gem*|*apt*|*dnf*|*pacman*|*zypper*)
            GAUDI_HELPER_PENDING_COMMAND="$1"
            ;;
        *)
            unset GAUDI_HELPER_PENDING_COMMAND
            ;;
    esac
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
    if [[ -z "${__bp_imported:-}" && -r "$GAUDI_HELPER_DIR/lib/bash-preexec.sh" ]]; then
        # shellcheck source=/dev/null
        source "$GAUDI_HELPER_DIR/lib/bash-preexec.sh"
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
