#!/bin/bash

# ==============================================================================
#  Script Title
# ==============================================================================

# --- General settings and variables -------------------------------------------

# The so-called strict mode (see https://mywiki.wooledge.org/BashFAQ/105)
set -e           # "exit-on-error" shell option
set -u           # "no-unset" shell option
set -o pipefail  # exit on within-pipe error

# ==============================================================================
# NOTE on -e option
# -----------------
# `set -e` immediately stops the execution of a script if a command has non-zero
# exit status. This is the opposite of the default shell behavior, which is to
# ignore errors in scripts. The problem is that a non-zero exit code not always
# means an error. In particular, if you use `grep` (or `pgrep`) and do NOT
# consider finding no match as an error, you need to use the following syntax
#
#     grep "<expression>" "<target>" || [[ $? == 1 ]]
#
# to prevent `grep` from causing premature termination of the script.
# This works since `[[ $? == 1 ]]` is executed if and only if `grep` fails (even
# when `-e` option is active!) and, according to POSIX manual, `grep` exit code
#   1 means "no lines selected";
#   > 1 means an error.
#
# For the same reason, if you need to use `ls` you have to do this 
#
#      ls "<files>" 2> /dev/null || [[ $? == 2 ]]
#
# However, for these purposes it is recommended to use `find`, which does not
# suffer from such a problem, since it returns an error only when the target
# directory is not found (which is a much more unlikely event). When even the
# existence of the searching location is uncertain, you can use:
#
#     find "<target_dir>" -type f -iname "<files>" 2> /dev/null || [[ $? == 1 ]]
#
# The same is true for `which`:
#
#     which <command> 2> /dev/null || [[ $? == 1 ]]
#
# In general, remember that enclosing a command within a conditional block
# allows excluding it from the `set -e` behavior. E.g.,
#
#     if which <command> > /dev/null 2>&1; then ...; fi
#
# is fine, even without `|| [[ $? == 1 ]]`.
#
# NOTE on -o pipefail option
# --------------------------
# By default, the exit status of a pipe of many commands is the exit status of
# the last (rightmost) command in the pipe. By setting `-o pipefail` the exit
# status of the first (leftmost) non-zero command of the pipeline is propagated
# to the end. However, the remaining commands in the pipeline still run and, if
# the `-e` option is set, the script will exit at the end of the failing
# pipeline (to be regarded as a single command).
# When using grep within a pipeline with both `-o pipefail` and `-e` option set,
# put the `|| [[ $? == 1 ]]` condition at the end of the pipeline.
#
#   grep "<expression>" "<target>" | command_2 | command_3 || [[ $? == 1 ]] 
#
# NOTE on -u option
# ------------------
# The existence operator ${:-} allows avoiding errors when testing variables by
# providing a default value in case the variable is not defined or empty.
#
# result=${var:-value}
#
# If `var` is unset or null, `value` is substituted (and assigned to `results`).
# Otherwise, the value of `var` is substituted and assigned.
# ==============================================================================

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# Timestamp in seconds for execution-time computation
# (use `time` in front of command lines running in background)
start=$(date +%s)

# For a friendlier use of colors in Bash
red=$'\e[1;31m' # Red
grn=$'\e[1;32m' # Green
yel=$'\e[1;33m' # Yellow
blu=$'\e[1;34m' # Blue
mag=$'\e[1;35m' # Magenta
cya=$'\e[1;36m' # Cyan
end=$'\e[0m'

# --- Function definition ------------------------------------------------------

# Default options
ver="0.2.0"
first_rgx=".*" # Keep all (i.e., do not filter for first author)
doctype="AR" # Both research articles and Reviews
year_pub="[0-9][0-9]" # All years (from 2000 to 2099)
annexes=false
tabular=false
export=false
destination="."

# Help message
_help_pubs=""
read -d '' _help_pubs << EOM || true
This utility script allows monitoring my production of scientific papers.
If used without arguments... 

Shows the amount of disk space allocated to each project folder asssociated with
each publication.
Show all my works regardless of the position of my name in the list of authors.

Usage:
    pubs [-h | --help] [-v | --version] [--pos=F|L|FL] [--type=A|R]
             [--year=YYYY[+]] [-a | --annexes] [-t | --tabular]
             [-x | --export DESTINATION]

Positional options:
    -h | --help     Shows this help.
    -v | --version  Shows script's version.
    --pos=F|L|FL    Show only papers where my name appears in the (co-)first
                    position, in the (co-)last position, or in either position,
                    respectively.
    --type=A|R      Filters document type, showing either Research Articles
                    (A) or Reviews (R) only.  
    --year=YYYY[+]  Filters publications by year. YYYY is the year of interest
                    in four digit format. Use the '+' symbol after the year to
                    to include all publications from YYYY on.
    -a | --annexes  Shows also annexes files, such as Supplementary Materials or
                    alternative formats of the final version of the paper.
    -t | --tabular  Shows results in a tabular format.
    -x | --export   Makes a local copy of my papers, accounting for possible
                    filtering parameters included in the query.
    DESTINATION     Target folder for the copy.

Additional Notes:
    ...
EOM

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                printf "%s\n" "$_help_pubs"
                exit 0 # Success exit status
            ;;
            -v | --version)
                figlet PubS
                printf "Ver.${ver}\n"
                exit 0 # Success exit status
            ;;
            -f | --first)
                first_rgx="ruffinatti"
                shift
            ;;
            -a | --annexes)
                annexes=true
                shift
            ;;
            -t | --tabular)
                tabular=true
                shift
            ;;
            -x | --export)
                export=true
                if [[ ! "$2" =~ $frp ]]; then # && $2 is not null
                    destination="$(realpath "$2")"
                    if [[ ! -d "$destination" ]]; then
                        printf "Invalid target directory '$destination'.\n"
                        exit 1 # Argument failure exit status: invalid TARGETS
                    fi
                fi
                shift
            ;;
            --type*)
                # Test for '=' presence
                if [[ "$1" =~ ^--type=  ]]; then
                    doctype="${1/--type=/}"
                    if [[ "$doctype" != "A" && "$doctype" != "R" ]]; then 
                        printf "Bad type '$doctype' for the --type option.\n"
                        exit 1 # Bad format
                    fi
                    shift
                else
                    printf "Values need to be assigned to '--type' option using"
                    printf " the '=' operator.\n"
                    printf "Use '--help' or '-h' to see the correct syntax.\n"
                    exit 1 # Bad suffix assignment
                fi
            ;;
            --year*)
                # Test for '=' presence
                if [[ "$1" =~ ^--year=  ]]; then
                    input_year="${1/--year=/}"
                    if [[ "$input_year" =~ ^[0-9]{2}$ ]]; then
                        year_pub=$input_year
                    elif [[ "$input_year" =~ ^[0-9]{2}\+$ ]]; then
                        decade="${input_year:1:1}"
                        year="${input_year:2:1}"
                        year_pub="${decade}[${year}-9]|[$((decade+1))-9][0-9]"
                    else
                        printf "Bad format for the --year option.\n"
                        exit 1 # Bad format
                    fi
                    shift
                else
                    printf "Values need to be assigned to '--year' option using the '='"
                    printf "operator.\nUse '--help' or '-h' to see the correct syntax.\n"
                    exit 1 # Bad suffix assignment
                fi
            ;;
            *)
                printf "Unrecognized option flag '$1'.\n"
                printf "Use '--help' or '-h' to see possible options.\n"
                exit 1 # Argument failure exit status: bad flag
            ;;
        esac
    else
        printf "Unrecognized option '$1'.\n"
        printf "Use '--help' or '-h' to see possible options.\n"
        exit 1 # Argument failure exit status: bad flag
    fi
done

# --- Main program -------------------------------------------------------------

echo
counter=1

while IFS= read -r project
do
    # Collect project info
    project_ID="$(basename "$project")"
    size=$(du -h -s "$project" | cut -f1 -d$'\t')
    if [[ -d "${project}/.git" ]]; then
        git_flag=${blu}git${end}
    else
        git_flag="---"
    fi
    if [[ -f "${project}/kerblam.toml" ]]; then
        ker_flag=${red}Kerblam!${end}
    else
        ker_flag="---"
    fi

    # Print report
    printf "   ${counter}\t${grn}${project_ID}${end}\n"
    printf "\t${size}B  $git_flag  ${ker_flag}\n"

    # Find publications
    if ${annexes}; then
        pub_rgx=".+_final(_v.+)?/.+_[0-9]{4}_.+\..+"
    else
        pub_rgx=".+_final(_v.+)?/.+_[0-9]{4}_[^_]+(_v.+)?\.pdf$"
    fi
    while IFS= read -r pub; do
        printf "\t  - $(basename "$pub")\n"
    done <<< $(find "${project}/reports" \
                -maxdepth 3 \
                -regextype egrep \
                -iregex "$pub_rgx")

    printf "\n"
    ((counter++))

done <<< $(find "$PWD" \
            -maxdepth 1 \
            -type d \
            -regextype egrep \
            -iregex ".*/[0-9][0-9][0-9][0-9]-${year_pub}[0-9x][0-9x]-[${doctype}]-.+")
            

#  | grep -iE "$first_rgx" \
