#!/bin/bash

# ==============================================================================
#  Script Title
# ==============================================================================

# --- General settings and variables -------------------------------------------

# Strict mode options (set -euEo pipefail)
set -e              # "exit-on-error" (non-zero status) (aka set -o errexit)
set -u              # "no-unset" shell option (aka set -o nounset)
set -o pipefail     # exit on within-pipe (but not process substitution) error
set -o errtrace     # `ERR` trap inherited by functions and subshells (and thus
                    # by pipes, command substitutions, process substitutions)
                    # (aka set -E)

# Set up error handling. General syntax:
#   trap 'handler_command' ERR
# Whenever a command fails (nonzero exit code), 'handler_command' is run.

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
ver="0.0.0"
verbose=true

# Help message
_help_scriptname=""
read -d '' _help_scriptname << EOM || true
This script is meant to do blah blah blah...

Usage:
  scriptname [-h | --help] [-v | --version] ...
  scriptname [-q | --quiet] [--value="PATTERN"] TARGETS

Positional options:
  -h | --help         Shows this help.
  -v | --version      Shows script's version.
  -q | --quiet        Disables verbose on-screen logging.
  --value="PATTERN"   Argument allowing for user-defined input.
  TARGETS             E.g., the path to a file or file-containing
                      folder to work on.
Additional Notes:
  You can use this or that to do something...
EOM

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
# The first one is more strict, but it doesn't work for --value="PATTERN"
frp="^-{1,2}[a-zA-Z0-9-]+$"
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				printf "%s\n" "$_help_scriptname"
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet Script Title
				printf "Ver.${ver}\n"
				exit 0 # Success exit status
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			--value*)
				# Test for '=' presence
				if [[ "$1" =~ ^--value=  ]]; then
					# ...	
					value_pattern="${1/--value=/}"
					shift
					# ...
				else
					printf "Values need to be assigned to '--value' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
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
		# The first non-FRP sequence is taken as the TARGETS argument
		target_file="$(realpath "$1")"
		break
	fi
done

# Argument check: TARGETS directory
if [[ -z "${target_dir:-""}" ]]; then
	printf "Missing option or TARGETS argument.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 1 # Argument failure exit status: missing TARGETS
elif [[ ! -d "$target_dir" ]]; then
	printf "Invalid target directory '$target_dir'.\n"
	exit 1 # Argument failure exit status: invalid TARGETS
fi

# --- Main program -------------------------------------------------------------

### Stuff goes here

end=$(date +%s)
runtime=$((end-start))
echo "Total execution time: ${runtime} seconds"
