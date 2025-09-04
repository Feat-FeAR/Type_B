#!/bin/bash

# ==============================================================================
#  Pubs - Quickly generates a report of my closed projects and publications 
# ==============================================================================
ver="0.2.0"

# --- General settings and variables -------------------------------------------

# Strict mode
set -e           # "exit-on-error" shell option
set -u           # "no-unset" shell option
set -o pipefail  # exit on within-pipe error

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# For a friendlier use of colors in Bash
red=$'\e[1;31m' # Red
grn=$'\e[1;32m' # Green
yel=$'\e[1;33m' # Yellow
blu=$'\e[1;34m' # Blue
mag=$'\e[1;35m' # Magenta
cya=$'\e[1;36m' # Cyan
end=$'\e[0m'

# --- Help message -------------------------------------------------------------

_help_pubs=""
read -d '' _help_pubs << EOM || true
This utility script allows monitoring my production of scientific papers.
If used without arguments... 

Shows the amount of disk space allocated to each project folder asssociated with
each publication.
Show all my works regardless of the position of my name in the list of authors.

Usage:
    pubs [-h | --help] [-v | --version] [--type=A|R] [--pos=F|L|FL]
         [--year=YY[+]] [-a | --annexes] [-t | --tabular]
         [-x | --export DESTINATION]

Positional options:
    -h | --help     Shows this help.
    -v | --version  Shows script's version.
    --pos=F|L|FL    Show only papers where my name appears in the (co-)first
                    position, in the (co-)last position, or in either position,
                    respectively.
    --type=A|R      Filters document type, showing either Research Articles
                    (A) or Reviews (R) only.  
    --year=YY[+]    Filters publications by year. YY is the year of interest in
                    two-digit format (meaning 20YY). Use the '+' symbol after
                    the year to to include all publications from 20YY on.
    -a | --annexes  Shows also annexes files, such as Supplementary Materials or
                    alternative formats of the final version of the paper.
    -t | --tabular  Shows results in a tabular format.
    -x | --export   Makes a local copy of my papers, accounting for possible
                    filtering parameters included in the query.
    DESTINATION     Target folder for the copy.

Additional Notes:
    ...
EOM

# --- Argument parsing and validity check --------------------------------------

# Default options
position="a-zA-Z"       # Keep all (i.e., do not filter for author position)
doctype="AR"            # Both research articles and Reviews
year_rgx="[0-9]{2}"     # All years (from 2000 to 2099)
annexes=false
tabular=false
export=false
destination="."

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
            --pos*)
                 # Test for '=' presence
                if [[ "$1" =~ ^--pos=  ]]; then
                    position="${1/--pos=/}"
                    if [[ ! $position =~ ^(F|L|FL|LF)$ ]]; then
                        printf "Bad position '$position' for the --pos option.\n"
                        exit 1 # Bad format
                    fi
                    shift
                else
                    printf "Values need to be assigned to '--pos' option using"
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
                        year_rgx=$input_year
                    elif [[ "$input_year" =~ ^[0-9]{2}\+$ ]]; then
                        decade="${input_year:0:1}"
                        year="${input_year:1:1}"
                        year_rgx="(${decade}[${year}-9]|[$((decade+1))-9][0-9])"
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
debug=false
counter=1

while IFS= read -r project
do
    # Debug mode
    if ${debug}; then
        printf "$counter ${project}\n"
        ((counter++))
        continue
    fi

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
        if ${export}; then
            cp "$pub" "$destination"
        fi
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
            -iregex ".*/[0-9]{4}-${year_rgx}[0-9x]{2}-[${doctype}][${position}]-.+")
            