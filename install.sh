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

    if [[ -d "$repo" && "$repo" != http://* && "$repo" != https://* && "$repo" != git@* ]]; then
        git clone "$repo" "$target"
    else
        git clone --depth=1 "$repo" "$target"
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

    printf "%s" "${branch:-master}"
}

update_helper() {
    local target="$1"
    local branch=""

    branch="$(current_helper_branch "$target")"
    git -C "$target" fetch --depth=1 origin "$branch"
    git -C "$target" checkout "$branch" 2>/dev/null || git -C "$target" checkout -B "$branch" "origin/$branch"
    git -C "$target" pull --ff-only origin "$branch"
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
gaudi_helper_install_shell_integration "$GAUDI_HELPER_DIR"

log "gaudi-helper installed. Restart your shell or source your shell profile."
