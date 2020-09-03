#!/usr/bin/env sh

function set_environment_exports {
    

    # Setting $BASH to maintain backwards compatibility
    # Getting the user's OS type in order to load the correct installation and configuration scripts
    if [[ "$OSTYPE" = "linux-gnu" ]]; then
        if ! grep -q "${1}" "${HOME}/.bashrc" ; then
          echo "Editing .bashrc to load on Terminal launch"
          printf "\n%s\n" "${1}" >> "${HOME}/.bashrc"
        fi
    elif [[ "$OSTYPE" = "darwin"* ]]; then
        if ! grep -q "${1}" "${HOME}/.bash_profile" ; then
          echo "Editing .bash_profile to load on Terminal launch"
          printf "\n%s\n" "${1}" >> "${HOME}/.bash_profile"
        fi
    fi

    # Check if we have a .zshrc regardless of the os .. and copy that to the zsh source file
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "${1}" "${HOME}/.zshrc" ; then
          printf "%s\n" "Noticed that you have Zsh installed (there might be some compatibility issues exporting there as well)"
          read -p "Are you sure you want to proceed exporting in your .zshrc ? [Y/N] " -n 1;
          echo ""
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Editing .zshrc to load on Terminal launch"
            printf "\n%s\n" "${1}" >> "${HOME}/.zshrc"
          fi
        fi
    fi
}

export -f set_environment_exports