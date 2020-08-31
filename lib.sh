
function getSoftwareInfo {
    
    local info website 
    local command=$1 software=$2 info=$3

    [[ $info == "*" ]] && echo $software
    $info $software &> /dev/null || return 0
    
    if [ $command == "cask" ]; then
        line_number="$((`$3 $software | grep -n "Description" | cut -d: -f1`+1))"
        info=$($3 $software | gsed -r "/^\s*$/d" | gsed -n "${line_number} p") 
        website=$($3 $software | gsed -r '/^\s*$/d' | gsed -n '2 p')
    elif [ $command == "brew" ] || [ $1 == "npm" ]; then
        info=$($3 $software | less | gsed -r "/^\s*$/d" | gsed -n "2 p") 
        website=$($3 $software | less | gsed -r '/^\s*$/d' | gsed -n '3 p')
    elif [ $command == "pip" ]; then
        info="$($3 $software | grep "Summary" | awk -F "Summary:" '{print $2}' | xargs)"
        website="$($3 $software | grep "Home-page" | awk -F "Home-page:" '{print $2}')"
    fi

    if [[ $info == "None" ]]; then echo $software::$website
        else echo $software::$info $website | tr -d '\n'
    fi
    
}

export -f getSoftwareInfo