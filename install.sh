#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

GAUDI="${GAUDI:-$HOME/.gaudi}"
GAUDI_HELPER_REPO="${GAUDI_HELPER_REPO:-https://github.com/g-udi/gaudi-helper.git}"
GAUDI_HELPER_DIR="${GAUDI_HELPER_DIR:-$GAUDI/gaudi-helper}"
GAUDI_HELPER_BRANCH="${GAUDI_HELPER_BRANCH:-}"

log() {
    printf "%s\n" "$*"
}

clone_helper() {
    local repo="$1"
    local target="$2"
    local -a clone_args=()

    # GAUDI_HELPER_BRANCH picks the branch; without it the default one is cloned
    [[ -z "$GAUDI_HELPER_BRANCH" ]] || clone_args=(--branch "$GAUDI_HELPER_BRANCH")

    if [[ -d "$repo" && "$repo" != http://* && "$repo" != https://* && "$repo" != git@* ]]; then
        git clone ${clone_args[@]+"${clone_args[@]}"} "$repo" "$target"
    else
        git clone --depth=1 ${clone_args[@]+"${clone_args[@]}"} "$repo" "$target"
    fi
}

current_helper_branch() {
    local target="$1"
    local branch="$GAUDI_HELPER_BRANCH"

    if [[ -z "$branch" ]]; then
        branch="$(git -C "$target" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
        branch="${branch#origin/}"
    fi

    if [[ -z "$branch" ]]; then
        branch="$(git -C "$target" branch --show-current 2>/dev/null || true)"
    fi

    printf "%s" "${branch:-main}"
}

update_helper() {
    local target="$1"
    local branch=""

    branch="$(current_helper_branch "$target")"
    # The install is a shallow clone, so a new commit has no shared history to
    # fast-forward along: move the branch to what was just fetched instead.
    git -C "$target" fetch --depth=1 origin "$branch" && git -C "$target" checkout -q -B "$branch" FETCH_HEAD
}

if [[ ! -d "$GAUDI" ]]; then
    printf "Gaudi is required before installing gaudi-helper.\n" >&2
    printf "Install Gaudi first: https://github.com/g-udi/gaudi\n" >&2
    exit 1
fi

umask g-w,o-w

if [[ -d "$GAUDI_HELPER_DIR/.git" ]]; then
    log "Updating gaudi-helper at $GAUDI_HELPER_DIR"
    update_helper "$GAUDI_HELPER_DIR"
elif [[ -e "$GAUDI_HELPER_DIR" ]]; then
    backup_dir="${GAUDI_HELPER_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    log "Moving existing gaudi-helper directory to $backup_dir"
    mv "$GAUDI_HELPER_DIR" "$backup_dir"
    clone_helper "$GAUDI_HELPER_REPO" "$GAUDI_HELPER_DIR"
else
    clone_helper "$GAUDI_HELPER_REPO" "$GAUDI_HELPER_DIR"
fi

# shellcheck source=/dev/null
source "$GAUDI_HELPER_DIR/lib/install-helper.sh"
gaudi_helper_install_shell_integration "$GAUDI_HELPER_DIR" || exit 1

log "gaudi-helper installed. Restart your shell or source your shell profile."
