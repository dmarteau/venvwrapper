#
# Partial port of  virtualenvwrapper commands for supporting
# python 3 venv module
#
# For original parts of virtualenvwrapper:
# Copyright Doug Hellmann, All Rights Reserved
#
# See https://bitbucket.org/virtualenvwrapper/virtualenvwrapper/
#

# Locate the global Python 
if [ "${VENVWRAPPER_PYTHON:-}" = "" ]
then
    VENVWRAPPER_PYTHON="$(command \which python)"
fi

VENVWRAPPER_VENV="$VENVWRAPPER_PYTHON -m venv"

# Verify that the requested environment exists
function venvwrapper_verify_workon_environment {
    typeset env_name="$1"
    if [ ! -d "$WORKON_HOME/$env_name" ]
    then
       echo "ERROR: Environment '$env_name' does not exist. Create it with 'mkvenv $env_name'." >&2
       return 1
    fi
    return 0
}

# Portable shell scripting is hard, let's go shopping.
#
# People insist on aliasing commands like 'cd', either with a real
# alias or even a shell function. Under bash and zsh, "builtin" forces
# the use of a command that is part of the shell itself instead of an
# alias, function, or external command, while "command" does something
# similar but allows external commands. Under ksh "builtin" registers
# a new command from a shared library, but "command" will pick up
# existing builtin commands. We need to use a builtin for cd because
# we are trying to change the state of the current shell, so we use
# "builtin" for bash and zsh but "command" under ksh.
function venvwrapper_cd {
    if [ -n "${BASH:-}" ]
    then
        builtin \cd "$@"
    elif [ -n "${ZSH_VERSION:-}" ]
    then
        builtin \cd -q "$@"
    else
        command \cd "$@"
    fi
}

# Help text for mkvenv
function venvwrapper_mkvenv_help {
    echo "Usage: mkvenv [venv options] env_name"
    echo
    echo 'venv help:';
    echo;
    "$VENVWRAPPER_VENV" $@;
}


# Create a new environment, in the WORKON_HOME.
#
# Usage: mkvenv [options] ENVNAME
# (where the options are passed directly to venv)
#
#:help:mkvenv: Create a new venv in $WORKON_HOME
function mkvenv {
    typeset -a in_args
    typeset -a out_args
    typeset tst
    typeset envname

    in_args=( "$@" )

    if [ -n "$ZSH_VERSION" ]
    then
        i=1
        tst="-le"
    else
        i=0
        tst="-lt"
    fi
    while [ $i $tst $# ]
        do
        a="${in_args[$i]}"
        # echo "arg $i : $a"
        case "$a" in
            -h|--help)
                venvwrapper_mkvenv_help $a;
                return;;
            *)
                if [ ${#out_args} -gt 0 ]
                then
                    out_args=( "${out_args[@]-}" "$a" )
                else
                    out_args=( "$a" )
                fi;;
        esac
        i=$(( $i + 1 ))
    done

    eval "envname=\$$#"
    venvwrapper_verify_workon_home || return 1
    (
        [ -n "$ZSH_VERSION" ] && setopt SH_WORD_SPLIT
        venvwrapper_cd "$WORKON_HOME" &&
        $VENVWRAPPER_VENV $VENVWRAPPER_VENV_ARGS "$@"
    )
    typeset RC=$?
    [ $RC -ne 0 ] && return $RC

    # If they passed a help option or got an error from venv,
    # the environment won't exist.  Use that to tell whether
    # we should switch to the environment and run the hook.
    [ ! -d "$WORKON_HOME/$envname" ] && return 0

    # Now activate the new environment
    workon "$envname"
}


# Check if the WORKON_HOME directory exists,
# create it if it does not
# seperate from creating the files in it because this used to just error
# and maybe other things rely on the dir existing before that happens.
function venvwrapper_verify_workon_home {
    RC=0
    if [ ! -d "$WORKON_HOME/" ]
    then
        if [ "$1" != "-q" ]
        then
            echo "NOTE: Virtual environments directory $WORKON_HOME does not exist. Creating..." 1>&2
        fi
        mkdir -p "$WORKON_HOME"
        RC=$?
    fi
    return $RC
}

# Show help for workon
function venvwrapper_workon_help {
    echo "Usage: workon env_name"
    echo ""
    echo "           Deactivate any currently activated venv"
    echo "           and activate the named environment, triggering"
    echo "           any hooks in the process."
    echo ""
    echo "       workon"
    echo ""
    echo "           Print a list of available environments."
    echo "           (See also lsvenv)"
    echo ""
    echo "       workon (-h|--help)"
    echo ""
    echo "           Show this help message."
    echo ""
}

#:help:workon: list or change working venvs
function workon {
    typeset -a in_args
    typeset -a out_args

    in_args=( "$@" )

    if [ -n "$ZSH_VERSION" ]
    then
        i=1
        tst="-le"
    else
        i=0
        tst="-lt"
    fi
    typeset cd_after_activate=$VIRTUALENVWRAPPER_WORKON_CD
    while [ $i $tst $# ]
    do
        a="${in_args[$i]}"
        case "$a" in
            -h|--help)
                venvwrapper_workon_help;
                return 0;;
            *)
                if [ ${#out_args} -gt 0 ]
                then
                    out_args=( "${out_args[@]-}" "$a" )
                else
                    out_args=( "$a" )
                fi;;
        esac
        i=$(( $i + 1 ))
    done

    set -- "${out_args[@]}"

    typeset env_name="$1"
    if [ "$env_name" = "" ]
    then
        lsvenv
        return 1
    elif [ "$env_name" = "." ]
    then
        # The IFS default of breaking on whitespace causes issues if there
        # are spaces in the env_name, so change it.
        IFS='%'
        env_name="$(basename $(pwd))"
        unset IFS
    fi

    venvwrapper_verify_workon_home || return 1
    venvwrapper_verify_workon_environment "$env_name" || return 1

    activate="$WORKON_HOME/$env_name/bin/activate"
    if [ ! -f "$activate" ]
    then
        echo "ERROR: Environment '$WORKON_HOME/$env_name' does not contain an activate script." >&2
        return 1
    fi

    # Deactivate any current environment
    if [ -n "${VIRTUAL_ENV}" ]
    then
        deactivate
    fi

    source "$activate"
    return 0
}


#:help:lsvenv: list venvs
function lsvenv {
    venvwrapper_show_workon_options
}

#:help:rmvenv: Remove a venv
function rmvenv {
    venvwrapper_verify_workon_home || return 1
    if [ ${#@} = 0 ]
    then
        echo "Please specify an environment." >&2
        return 1
    fi

    # support to remove several environments
    typeset env_name
    # Must quote the parameters, as environments could have spaces in their names
    for env_name in "$@"
    do
        echo "Removing $env_name..."
        typeset env_dir="$WORKON_HOME/$env_name"
        if [ "$VIRTUAL_ENV" = "$env_dir" ]
        then
            echo "ERROR: You cannot remove the active environment ('$env_name')." >&2
            echo "Either switch to another environment, or run 'deactivate'." >&2
            return 1
        fi

        if [ ! -d "$env_dir" ]; then
            echo "Did not find environment $env_dir to remove." >&2
        fi

        # Move out of the current directory to one known to be
        # safe, in case we are inside the environment somewhere.
        typeset prior_dir="$(pwd)"
        venvwrapper_cd "$WORKON_HOME"

        command \rm -rf "$env_dir"

        # If the directory we used to be in still exists, move back to it.
        if [ -d "$prior_dir" ]
        then
            venvwrapper_cd "$prior_dir"
        fi
    done
}

# List the available environments.
function venvwrapper_show_workon_options {
    venvwrapper_verify_workon_home || return 1
    # NOTE: DO NOT use ls or cd here because colorized versions spew control
    #       characters into the output list.
    # echo seems a little faster than find, even with -depth 3.
    # Note that this is a little tricky, as there may be spaces in the path.
    #
    # 1. Look for environments by finding the activate scripts.
    #    Use a subshell so we can suppress the message printed
    #    by zsh if the glob pattern fails to match any files.
    #    This yields a single, space-separated line containing all matches.
    # 2. Replace the trailing newline with a space, so every
    #    possible env has a space following it.
    # 3. Strip the bindir/activate script suffix, replacing it with
    #    a slash, as that is an illegal character in a directory name.
    #    This yields a slash-separated list of possible env names.
    # 4. Replace each slash with a newline to show the output one name per line.
    # 5. Eliminate any lines with * on them because that means there
    #    were no envs.
    (venvwrapper_cd "$WORKON_HOME" && echo */bin/activate) 2>/dev/null \
        | command \tr "\n" " " \
        | command \sed "s|/bin/activate |/|g" \
        | command \tr "/" "\n" \
        | command \sed "/^\s*$/d" \
        | (unset GREP_OPTIONS; command \egrep -v '^\*$') 2>/dev/null
}

# Does a ``cd`` to the root of the currently-active venv.
#:help:cdvirtualenv: change to the $VIRTUAL_ENV directory
function cdvenv {
    venvwrapper_verify_workon_home || return 1
    venvwrapper_verify_active_environment || return 1
    venvwrapper_cd "$VIRTUAL_ENV/$1"
}



# Set up tab completion.  (Adapted from Arthur Koziel's version at
# http://arthurkoziel.com/2008/10/11/virtualenvwrapper-bash-completion/)
function venvwrapper_setup_tab_completion {
    if [ -n "${BASH:-}" ] ; then
        _venvs () {
            local cur="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=( $(compgen -W "`venvwrapper_show_workon_options`" -- ${cur}) )
        }
        _cdvenv_complete () {
            local cur="$2"
            COMPREPLY=( $(cdvenv && compgen -d -- "${cur}" ) )
        }
        complete -o nospace -F _cdvenv_complete -S/ cdvenv
        complete -o default -o nospace -F _venvs workon
        complete -o default -o nospace -F _venvs rmvenv
    elif [ -n "$ZSH_VERSION" ] ; then
        _venvs () {
            reply=( $(venvwrapper_show_workon_options) )
        }
        _cdvenv_complete () {
            reply=( $(cdvenv && ls -d ${1}*) )
        }
        compctl -K _venvs workon rmvenv
        compctl -K _cdvenv_complete cdvenv
    fi
}

# Initialize tab completion
venvwrapper_setup_tab_completion

