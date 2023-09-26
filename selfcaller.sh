#!/bin/bash

# ============================================================================ #
# Selfcaller
# ============================================================================ #

# This is meant to be a template-script to build programs that run always in
# 'nohup' mode (and in the background) even if not explicitly called in that way.
#
# https://stackoverflow.com/questions/6168781/how-to-include-nohup-inside-a-bash-script
# see also the 'anqfastq.sh' script of my x.FASTQ suite

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# Make sure that the script is called with `nohup`
if [[ "$1" != "selfcall" ]]; then
	# This script has *not* been called recursively by itself
	nohup_out="nohup-${now}.out"
	nohup "$0" "selfcall" "$@" > "$nohup_out" &
	sleep 1
	tail -f $nohup_out
	exit
else
	# This script has been called recursively by itself
	shift # Remove the termination condition flag in $1
fi

# --- The rest of the script goes here -----------------------------------------

echo "Dumb script that counts to $1, in $1 seconds"
n=$1
for (( i = 0; i < n; i++ )); do
	printf "    "
	printf %$((i+1))s | tr " " "."
	printf $((n-i))
	printf "\r"
	sleep 1
done
printf "    "
printf "B"
printf %$((n-1))s | tr " " "o"
printf "M! \r"
sleep 1
