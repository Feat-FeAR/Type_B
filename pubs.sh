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

# --- Help messages ------------------------------------------------------------

read -d '' _help_pubs << EOM || true
PubS retrieves publications from a Structured local filesystem.
--------------------------------------------------------------------------------
This utility script allows monitoring my production of scientific papers. If
used without arguments, for each closed project, it shows the project ID, the
filename of the associated publication, the amount of disk space allocated to
the project folder, a blue 'git' badge and a red 'Kerblam!' badge if a .git
folder or a kerblam.toml file is found in the project directory, respectively.
If not otherwise specified, all my works are shown, regardless of the position
of my name in the list of authors or the date of publication.

Usage:
    pubs [-h | --help] [-s | --struct | --structure] [-v | --version]
         [--type=A|R] [--pos=F|L|FL] [--year=YY[+]] [-a | --annexes]
         [-t | --tabular] [-x | --export DESTINATION]
    pubs -l | --link [TARGET]

Positional Options:
    -h | --help     Shows this help.
    -s | --struct   Shows the filesystem structure required. 
    -v | --version  Shows script's version.
    --type=A|R      Filters document type, showing either Research Articles
                    (A) or Reviews (R) only.
    --pos=F|L|FL    Show only papers where my name appears in the (co-)first
                    position, in the (co-)last position, or in either position,
                    respectively.
    --year=YY[+]    Filters publications by year. YY is the year of interest in
                    two-digit format (meaning 20YY). Use the '+' symbol after
                    the year to to include all publications from 20YY on.
    -a | --annexes  Shows also annexes files, such as Supplementary Materials or
                    alternative formats of the final version of the paper.
    -t | --tabular  Shows results in a tabular (CSV) format. Requires 'csvlens'!
    -x | --export   Makes a local copy of my papers, accounting for possible
                    filtering parameters included in the query.
    DESTINATION     Target folder for the copy.

Additional Options:
    -l | --link     Symlink the original script in some \$PATH directory to make
                    the 'pubs' command globally available.
    TARGET          The path where the symlink is to be created. If omitted, it
                    defaults to the WD. E.g.:                    
                      /mnt/e/UniTo\ Drive/Coding/Type_B/pubs.sh -l ~/.local/bin/
EOM

read -d '' _help_struct << EOM || true
This script assumes that projects are organized in the local file system
according to the following scheme:

WORKS
  |__ yymm-YYMM-[AR][FLx]-ID
       |__ data
       |    |__ in
       |    |__ out
       |__ (docs)
       |__ (refs)
       |__ reports
       |    |__ 0_draft
       |    |__ 1_submission
       |    |__ 2_submission
       |    |__ ...
       |    |__ x_revision
       |    |__ ...
       |    |__ y_proof
       |    |__ z_final(_v1,2,3...)
       |    |      |__ <author>_yyyy_<journal>(_v1,2,3...).pdf
       |    |      |__ (<author>_yyyy_<journal>_Supplementary.pdf)
       |    |__ (z_supplementary)
       |    |__ figs
       |         |__ (supplementary)
       |         |__ (graphical_abstract)
       |         |__ (other)
       |         |__ (parts)
       |         |__ (old)
       |__ src
            |__ dockerfiles
            |__ workflows
            |__ (utils)

Where:
  - the first yymm is the (putative) starting date, while YYMM is the closing
    one (usually the date of publication)
  - A = Research article; R = Review
  - F = first name; L = last name; x = just a name in the middle
  - ID is the nickname of the project
  - round brackets (...) denote something that is not mandatory
  - <author>_YYYY_<journal>.pdf is the standard filename pattern of the final
    version of the published paper, namely first author(s), year of publication,
    journal abbreviation (as from PubMed, without spaces).
EOM

# --- functions ----------------------------------------------------------------

function _bad_assignment {
    printf "Values need to be assigned to '$1' option using the '=' operator.\n"
    printf "Use '--help' or '-h' to see the correct syntax.\n"
}

function _bad_option {
    printf "Unrecognized option '$1'.\n"
    printf "Use '--help' or '-h' to see possible options.\n"
}

# --- Argument parsing and validity check --------------------------------------

# Default options
position="a-zA-Z"       # Keep all (i.e., do not filter for author position)
doctype="AR"            # Both research articles and Reviews
year_rgx="[0-9]{2}"     # All years (from 2000 to 2099)
annexes=false
tabular=false
export=false
destination="${HOME}/papers"

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -l | --link)
                # Full path of the real script
                pubs_path="$(realpath "$0")"
                # Target directory (default to the WD if unset)
                target_dir="$(realpath "${2:-.}")"
                link_path="${target_dir}/pubs"
                if [[ -e "$link_path" ]]; then
                    printf "Removing old symlink...\n"
                    rm "$link_path"
                fi
                printf "Creating a new PubS symlink in '$(dirname "${link_path}")'\n"
                ln -s "$pubs_path" "$link_path"
                exit 0
            ;;
            -h | --help)
                printf "%s\n" "$_help_pubs"
                exit 0
            ;;
            -s | --struct | --structure)
                printf "%s\n" "$_help_struct"
                exit 0
            ;;
            -v | --version)
                figlet "   PubS"
                printf "           Ver.${ver}\n\n"
                printf " retrieves Publications from a\n"
                printf "  Structured local filesystem\n"
                exit 0
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
                # Overwrite default destination if a target path is provided
                if [[ -n "${2:-}" && ! "$2" =~ $frp ]]; then
                    destination="$(realpath "$2")"
                    shift
                fi
                shift
                # Check target directory
                if [[ ! -d "$destination" ]]; then
                    mkdir "$destination"
                    printf "Created target directory '$destination'\n"
                fi
                printf "Papers will be exported into '$destination'\n"
            ;;
            --type*)
                # Test for '=' presence
                if [[ "$1" =~ ^--type=  ]]; then
                    doctype="${1/--type=/}"
                    if [[ "$doctype" != "A" && "$doctype" != "R" ]]; then 
                        printf "Bad type '$doctype' for the --type option.\n"
                        exit 1
                    fi
                    shift
                else
                    _bad_assignment "--type"
                    exit 1
                fi
            ;;
            --pos*)
                 # Test for '=' presence
                if [[ "$1" =~ ^--pos=  ]]; then
                    position="${1/--pos=/}"
                    if [[ ! $position =~ ^(F|L|FL|LF)$ ]]; then
                        printf "Bad position '$position' for the --pos option.\n"
                        exit 1
                    fi
                    shift
                else
                    _bad_assignment "--pos"
                    exit 1
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
                        exit 1
                    fi
                    shift
                else
                    _bad_assignment "--year"
                    exit 1
                fi
            ;;
            *)
                _bad_option "$1"
                exit 1
            ;;
        esac
    else
        _bad_option "$1"
        exit 1
    fi
done

# --- Main program -------------------------------------------------------------

echo

# Project Regex
prj_rgx=".*/[0-9]{4}-${year_rgx}[0-9x]{2}-[${doctype}][${position}]-.+"
# Publication Regex (ignore annexes in tabular mode)
if ${annexes} && ! ${tabular}; then
    pub_rgx=".+_final(_v.+)?/.+_[0-9]{4}_.+\..+"
else
    pub_rgx=".+_final(_v.+)?/.+_[0-9]{4}_[^_]+(_v.+)?\.pdf$"
fi

# Check the current location
if [[ -z "$(find . -mindepth 1 -maxdepth 1 -type d \
                -regextype egrep -iregex "$prj_rgx")" ]]; then
    printf "Couldn't find any project-containing folder in the WD...\n"
    exit 1
fi

# Make a temporary file for tabular view
if ${tabular}; then
    pubs_tmp=$(mktemp)
    # Set table header
    echo "n,Project Name,Started,Ended,Size,Pub Type,Position,Pub Filename" >> $pubs_tmp
fi

# Start the main 'while' loop
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
    start_date="20${project_ID:0:2}-${project_ID:2:2}"
    end_date="20${project_ID:5:2}-${project_ID:7:2}"
    if [[ "${project_ID:10:1}" == "A" ]]; then
        pub_type="Article"
    elif [[ "${project_ID:10:1}" == "R" ]]; then
        pub_type="Review"
    fi
    if [[ "${project_ID:11:1}" == "F" ]]; then
        pub_pos="First Author"
    elif [[ "${project_ID:11:1}" == "L" ]]; then
        pub_pos="Last Author"
    else
        pub_pos=""
    fi
    project_name="${project_ID:13}"
    size=$(du -h -s "$project" | cut -f1 -d$'\t')
    # '| head -n 1' is to stop 'find' at the first match and speed up the computation
    if [[ -n "$(find "$project" -maxdepth 4 -type d -name ".git" | head -n 1)" ]]; then
        git_badge=${blu}git${end}
    else
        git_badge="---"
    fi
    if [[ -f "${project}/kerblam.toml" ]]; then
        ker_badge=${red}Kerblam!${end}
    else
        ker_badge="---"
    fi

    # Find publications associated with 'project' and store them into an array
    mapfile -d '' pub_array < <(find "${project}/reports" \
                                -maxdepth 3 \
                                -type f \
                                -regextype egrep \
                                -iregex "$pub_rgx" \
                                -print0)

    # Print report
    if ${tabular}; then
        printf "Publications retrieved: ${counter}\r"
        # [-1] index is to keep only the most recent version of the paper in the
        # case of versioned publications (e.g., F1000Res)
        pub_base="$(basename "${pub_array[-1]:-}")"
        # Build the CSV by rows
        echo "${counter},${project_name},${start_date},${end_date},${size},${pub_type},${pub_pos},${pub_base}" >> $pubs_tmp
    else
        printf "   ${counter}\t${grn}${project_ID}${end}\n"
        printf "\t${size}B  $git_badge  ${ker_badge}\n"
        for pub in "${pub_array[@]}"; do
            printf "\t  - $(basename "$pub")\n"
        done
        printf "\n"
    fi
    
    # Export publications
    if ${export}; then
        for pub in "${pub_array[@]}"; do
            cp "$pub" "$destination"
        done
    fi

    ((counter++))

done <<< $(find . \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -regextype egrep \
            -iregex "$prj_rgx")

# Show CSV table on screen
if ${tabular}; then
    echo
    csvlens $pubs_tmp
fi
