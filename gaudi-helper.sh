#!/usr/bin/env bash

export GREEN="\\033[0;32m"
export YELLOW="\\033[0;33m"
export RED="\\033[0;31m"
export NC="\\033[0m"

commandsList=(
    "brew install|brew info::default.brew.list"
    "brew cask install|brew cask info::default.cask.list"
    "brew tap|*::default.tap.list"
    "npm install|npm view::default.npm.list"
    "npm i|npm view::default.npm.list"
    "pip install|pip show::default.pip.list"
    "gem install|*::default.gem.list"
)

source ./lib.sh

if [ ! -n "$GAUDI" ]; then
    GAUDI=${HOME}/.gaudi
fi

preexec() {
    
    for _command in "${commandsList[@]}"; do

        local _commands="${_command%%::*}"
        local install_command="${_command%%|*}"
        local list="${_command#*::}"
        local info="${_commands#*|}"
        local command=$(echo $install_command | cut -f 1 -d " ")

        if [[ ${1% *} == "$install_command" ]]; then
            
            # If the installation command fails or if the software_info is not found make sure we do not run the command twice
            if [[ $(ps -p $$ | grep bash)  ]]; then
                # shopt -s extdebug enables some debugging features with one of them checks for return value before executing original command.
                # Note: shopt -u extdebug disable this feature so original command always get executed.
                shopt -s extdebug
            fi

            `echo "${1}"` || return 1
            
            local software_name=`echo "$1" | sed -e "s/$install_command //g"`
            local software_info=$(getSoftwareInfo $command $software_name "$info")

            echo "software_info: $software_info"
            
            if [[ ${#software_info} != 0 ]]; then

                printf "\n${GREEN}%s${NC}%s ${YELLOW}%s${NC}\n" "[ GAUDI ]" " Detected a new $command installation. It will be added to the default $command list if it does not already exist"
                printf "${GREEN}%s${NC}%s${YELLOW}${software_info}${NC}\n" "[ GAUDI ]" " is about to add: "
                if grep -q $(echo "$software_name::") $GAUDI/$list.sh; then
                    printf "${GREEN}%s $software_name${NC}%s${RED}%s${NC}\n" "[ GAUDI ]" " was found and" " will not be added to the default $command list"
                else
                    gsed -i "\$i $(echo "\"$software_info")\"" $GAUDI/$list.sh
                    printf "${GREEN}%s${YELLOW} $software_name${NC}%s\n" "[ GAUDI ]" " was found and added to the default $command list"
                fi
            fi

            echo "" && return 1
            
        fi    
    done

}
