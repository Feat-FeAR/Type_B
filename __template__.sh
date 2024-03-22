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
# means an error. In particular, if you use grep and do NOT consider grep
# finding no match as an error, you need to use the following syntax
#
#     grep "<expression>" "<target>" || [[ $? == 1 ]]
#
# to prevent grep from causing premature termination of the script.
# This works since `[[ $? == 1 ]]` is executed if and only if grep fails (even
# when `-e` option is active) and, according to POSIX manual, grep exit code
#   1 means "no lines selected";
#   > 1 means an error.
#
# For the same reason, if you need to use 'ls' you have to do this 
#
#      ls "<files>" 2> /dev/null || [[ $? == 2 ]]
#
# However, for these purposes it is recommended to use 'find', which does not
# suffer from such a problem, since it returns an error only when the target
# directory is not found (which is a much more unlikely event). When even the
# existence of the searching location is uncertain, you can use:
#
#     find "<target_dir>" -type f -iname "<files>" 2> /dev/null || [[ $? == 1 ]]
#
# The same is true for 'which':
#
#     which <command> 2> /dev/null || [[ $? == 1 ]]
#
# In general, remember that enclosing a command within a conditional block
# allows excluding it from the 'set -e' behavior. E.g.,
#
#     if which <command> > /dev/null 2>&1; then ...; fi
#
# is fine, even without '|| [[ $? == 1 ]]'.
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
# (use 'time' in front of command lines running in background)
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

# On-screen and to-file logging function
#
# 	USAGE:	_dual_log $verbose log_file "message"
#
# Always redirect "message" to log_file; additionally, redirect it to standard
# output (i.e., print on screen) if $verbose == true
# NOTE:	the 'sed' part allows tabulations to be stripped, while still allowing
# 		the code (i.e., multi-line messages) to be indented in a natural fashion.
function _dual_log {
	if $1; then echo -e "$3" | sed "s/\t//g"; fi
	echo -e "$3" | sed "s/\t//g" >> "$2"
}

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
