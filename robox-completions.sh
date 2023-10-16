# main function bound to robox command
_robox()
{
    local cur actions cur_action isos boxes configs providers namespaces
    COMPREPLY=()

    cur="${COMP_WORDS[COMP_CWORD]}"
    actions="start links cache validate build cleanup distclean registry-login registry-logout ova vmware hyperv libvirt parallels virtualbox docker isos sums invalid missing public available iso box all"

    isos=`./robox.sh list-isos`
    boxes=`./robox.sh list-boxes`
    configs=`./robox.sh list-configs`
    providers=`./robox.sh list-providers`
    namespaces=`./robox.sh list-namespaces`

    # Complete the action names.
    if ((COMP_CWORD == 1)); then
        COMPREPLY=( $(compgen -W "${actions} ${namespaces} ${providers} ${configs}" -- ${cur}) )
        return 0;
    fi

    # # If there is command or separator in arguments then stop completion.
    # if ((COMP_CWORD > 3)); then
    #     for word in "${COMP_WORDS[@]}"; do
    #         if [[ ${word} == \'* || ${word} == \"* || ${word} == "--" ]] ; then
    #             return 0
    #         fi
    #     done
    # fi

    # Complete one or none action argument.
    if ((COMP_CWORD = 2)); then
        cur_action="${COMP_WORDS[1]}"

        case "$cur_action" in
            

            # Argument is collection name
            iso)
                if ((COMP_CWORD == 2)); then
                    COMPREPLY=( $(compgen -W  "$isos" -- ${cur}) )
                fi
                return 0
            ;;

            # Argument is a box name.
            box)
                COMPREPLY=( $(compgen -W  "$boxes" -- ${cur}))
                return 0
            ;;

            # No argument
            *)
                return 0
            ;;
        esac
    fi

}

# bind the robox command to the _robox function for completion
complete -F _robox ./robox.sh
