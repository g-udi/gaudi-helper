
function getSoftwareInfo {
    
    local info website 
    local command=$1 software=$2 software_info=$3

    [[ $info = "*" ]] && echo "$software::"
    
    if [ $command = "cask" ]; then
        line_number="$((`$(echo $software_info $software) | grep -n "Description" | cut -d: -f1`+1))"
        info=$($(echo $software_info $software) | gsed -r "/^\s*$/d" | gsed -n "${line_number} p") 
        website=$($(echo $software_info $software) | gsed -r '/^\s*$/d' | gsed -n '2 p')
    elif [ $command = "brew" ] || [ $1 == "npm" ]; then
        info=$($(echo $software_info $software) | less | gsed -r "/^\s*$/d" | gsed -n "2 p") 
        website=$($(echo $software_info $software) | less | gsed -r '/^\s*$/d' | gsed -n '3 p')
    elif [ $command = "pip" ]; then
        info="$($(echo $software_info $software) | grep "Summary" | awk -F "Summary:" '{print $2}' | xargs)"
        website="$($(echo $software_info $software) | grep "Home-page" | awk -F "Home-page:" '{print $2}')"
    fi

    if [[ $info = "None" ]]; then echo $software::$website
        else echo $software::$info $website | tr -d '\n'
    fi
    
}

export -f getSoftwareInfo