#!/bin/bash

# ======================================
#  Seek and Destroy Google Drive's (1)s 
# ======================================
#
# The problem of the "trailing (1)s" from Google Drive only affects local folder
# and file names (both in streaming and mirroring modes!) of Google Drive for
# Desktop (it seems to be actually a Windows problem, rather than Google
# Drive's). On the contrary, names are always clean when looked through the web
# browser. For this reason, it is possible to distinguish wanted and unwanted
# (1)s simply by comparing local with remote (i.e., if a local (1) does not
# exist in remote it is very likely to be an unwanted one). A convenient way to
# do this, is using `googledrive` CRAN R package from the `tidyverse`.
#
# - Run g1finder in `seek` mode on the target directory then manually edit the
#   output list of filenames to keep just those you want to clean from (1)s
# OR
# - Run g1finder in `Seek` mode on the target directory to check filenames
#   directly in the cloud and get an automatic (heuristic) detection of the
#   unwanted (1)s (discrepancies between local and remote filenames are
#   suspected to originate from them...)
# THEN
# - Run g1finder in `destroy` mode sourcing the filename list

# Function Definitions ---------------------------------------------------------

# Print the help
function _help_g1 {
	echo
	echo "Seek and destroy the annoying '(1)s' put in filenames by Google Drive"
	echo
	echo "Usage: $0 [-h | --help] [--test]"
	echo "       $0 -s | --seek NUM TARGET REPORT"
	echo "       $0 -S | --Seek NUM TARGET REPORT"
	echo "       $0 -d | --destroy FNAMES"
	echo
	echo "Positional options:"
	echo "    -h | --help     show this help"
	echo "         --test     test the script run in seek-and-destroy modes"
	echo "    -s | --seek     search (seek) mode"
	echo "    -S | --Seek     enhanced search mode (with cloud connection)"
	echo "    -d | --destroy  cleaning (destroy) mode"
	echo "    NUM             the maximum positive (non-zero) integer to search"
	echo "    TARGET          the Google Drive folder to be scanned (s-mode)"
	echo "    REPORT          the output directory for filename report (s-mode)"
	echo "    FNAMES          the input list of filenames to clean (d-mode)"
	echo
	echo "Examples: $0 -s 3 /mnt/e/UniTo\ Drive/ ~"
	echo "          $0 -d ./loos.txt"
	echo
}

# Select a Google Drive account
function _account_selector {
	COLUMNS=1 # To make "select" display the options in a single column
	PS3="-> Select a number: " # The prompt for the 'select' statement
	domain="federicoalessandro.ruffinatti"
	options=("${domain}@unito.it" "${domain}@gmail.com" "quit")
	select account in "${options[@]}"
	do
		case $REPLY in
			1 | 2)
				echo "Account $REPLY selected: $account"
				break
				;;
			3)
				echo "bye bye!"
				exit 0 # Success exit status
				;;
			*)
				echo "Invalid option '$REPLY'"
				;;
		esac
	done
}

# Print the Connection/Authentication error message
function _auth_error {
	echo "Authentication Error..."
	echo
	echo "Consider running the following commands from R to authenticate"
	echo "via web and cache a token for ${account}:"
	echo "  >"
	echo "  > options(browser = 'wslview')"
	echo "  > googledrive::drive_auth(email = NA)"
	echo "  >"
	echo "When prompted, remember to grant all permissions! (checkboxes)"
	echo "Then try to rerun $0"
}

# Test the script
function _test_g1finder {
	test_dir="g1finder_testFileSystem"
	# REMEMBER: quoting ~ would prevent replacing it with $HOME!
	mkdir -p ~/tmp/
	cp -r ./test/"${test_dir}"/ ~/tmp/
	"$1" -s 3 ~/tmp/"${test_dir}" ~/tmp/
	"$1" -d ~/tmp/"$2"
	find ~/tmp/"${test_dir}" | sed "s|^${HOME}/tmp/${test_dir}||g" \
		> ~/tmp/test.out
	if cmp -s ~/tmp/test.out ./test/"${test_dir}"/test.ref; then
		echo -e "\nTest passed!"
	else
		echo -e "\nWARNING--- Test failed ---WARNING\n"
		diff ~/tmp/test.out ./test/"${test_dir}"/test.ref
	fi
	rm -rf ~/tmp
}

# Script Start -----------------------------------------------------------------

# Name of the filename-containing file (e.g., List_Of_Ones.txt)
meta_name="loos.txt"

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9]+$"

# Argument check
if [[ "$1" =~ $frp ]]; then
	case "$1" in
		-h | --help)
			_help_g1
			exit 0 # Success exit status
		;;
		-s | -S | --seek | --Seek)
			if [[ $# -ge 4 ]]; then
				upper="$2"
				target="$3"
				report="${4%/}"
				# Remove possible trailing slashes using Bash-native string 
				# removal syntax: ${string%$substring}
				# The above one-liner is equivalent to:
				#    report="$4"
				#    report="${report%/}"
				# NOTE: while `$substring` is a literal string, `string` MUST be
				#       a reference to a variable name!
			else
				printf "Missing parameter(s).\n"
				printf "Use '--help' or '-h' to see the correct s-mode syntax.\n"
				exit 1 # Argument failure exit status
			fi
		;;
		-d | --destroy)
			if [[ $# -ge 2 ]]; then
				fnames="$2"
			else
				printf "Missing parameter.\n"
				printf "Use '--help' or '-h' to see the correct d-mode syntax.\n"
				exit 1 # Argument failure exit status
			fi
		;;
		--test)
			_test_g1finder "$0" "$meta_name"
		;;
		* )
			printf "Unrecognized flag '$1'.\n"
			printf "Use '--help' or '-h' to see the possible options.\n"
			exit 1 # Argument failure exit status
		;;
	esac
else
	printf "Missing flag.\n"
	printf "Use '--help' or '-h' to see possible options.\n"
	exit 1 # Argument failure exit status
fi

# To lower case (to match both -s and -S)
flag=$(echo "$1" | tr '[:upper:]' '[:lower:]')

if [[ "$flag" == "-s" || "$flag" == "--seek" ]]; then

	# The 'Target Regex Pattern' (TRP) is a white-space followed by a one-digit
	# number (1 to $2) within round brackets; i.e.: (1), (2), (3), ...
	trp=" \([1-${upper}]\)"

	# Create empty output file
	touch "$report"/"$meta_name"

	# Find folders and sub-folders that end with the TRP
	# NOTE: If a folder name has a dot somewhere, during the unfortunate process
	# 		of (1) spawning, the substring after the dot will be seen by Windows
	# 		just like the name extension of a regular file. For this reason, we
	# 		must consider the possibility that there may be something after the
	# 		TRP not only in file names, but even in folder names.
	find "$target" -type d | grep -E ".+$trp(\..+)?$" \
		> "$report"/"$meta_name"

	# Find regular files that end with the TRP, plus possible filename extension
	find "$target" -type f | grep -E ".+$trp(\.[a-zA-Z0-9]+)?$" \
		>> "$report"/"$meta_name"

	total_hits=$(wc -l "$report"/"$meta_name" | cut -f1 -d" ")
	echo -e "\nNumber of hits:\t${total_hits}\t${report}/${meta_name}"
	
	if [[ "$1" == "-s" || "$1" == "--seek" ]]; then
		
		exit 0 # Success exit status
	
	elif [[ "$1" == "-S" || "$1" == "--Seek" ]]; then

		# Create a counter and an empty output file
		counter=0
		touch "$report"/heuristic_"$meta_name"
		
		# Get current default browser for possible web authentication
		browser="$(echo $BROWSER)"

		# Select a Google Drive account and check the connection via R interface
		echo
		_account_selector
		Rscript --vanilla \
				-e "args = commandArgs(trailingOnly = TRUE)" \
				-e "googledrive::drive_auth(email = args[1])" \
				"$account" 2> /dev/null

		if [[ $? -ne 0 ]]; then
			_auth_error
			exit 2 # Account failure exit status
		else
			echo -e "Connection successfully established!\n"
		fi

		while IFS= read -r line
		do
			# The Drive API identifies a file by its unique ID, rather than its
			# full path. 'googledrive' R package makes it easy to specify your
			# file of interest by name at first and then retrieves file’s ID. 
			base_line="$(basename "$line")"

			# Live counter updating in console (by carriage return \r)
			counter=$(( counter + 1 ))
			echo -ne "Progress:\t${counter}/${total_hits}" \
				"\t[ $(( (counter*100)/total_hits ))% ]\r"
			
			# Access Google Drive Cloud by R metacoding
			remote=$(Rscript --vanilla \
				-e "args = commandArgs(trailingOnly = TRUE)" \
				-e "options(browser = args[1])" \
				-e "options(googledrive_quiet = TRUE)" \
				-e "googledrive::drive_auth(email = args[2])" \
				-e "x <- googledrive::drive_get(args[3])" \
				-e "cat(nrow(x))" \
				"$browser" "$account" "$base_line" 2> /dev/null)

			if [[ $remote -eq 0 ]]; then
				# Discrepancies between local and remote filenames are suspected
				# to originate from (1)s
				echo "$line" >> "$report"/heuristic_"$meta_name"
			fi	
		done < "$report"/"$meta_name"

		echo -e	"\nDetections:" \
			"\t$(wc -l "$report"/heuristic_"$meta_name" | cut -f1 -d" ")" \
			"\t${report}/heuristic_${meta_name}"
		exit 0 # Success exit status
	fi

elif [[ "$1" == "-d" || "$1" == "--destroy" ]]; then

	# Here the 'Target Regex Pattern' (TRP) has been redefined to match any
	# number from 0 to 9 inside round brackets, however it will be used as a
	# simple Bash wild-card expression (not actually a regex). 
	trp=" \([0-9]\)"

	# Save a temporary reverse-sorted filename list (see below the reason why)
	temp_out="$(dirname "$fnames")"/temp.out
	sort -r "$fnames" > "$temp_out"

	while IFS= read -r line
	do
		# Remove TRP from filenames using Bash-native string substitution:
		# ${string/$substring/$replacement}
		# NOTE: while `$substring` and `$replacement` are literal strings
		# 		the starting `string` MUST be a reference to a variable name!
		# Split each filename between dirname and basename to match and
		# substitute the TRP from the end of the strings.
		# This, in combination with the previous reverse-sorting, ensures that
		# mv is always possible, even for nested TRPs, since it starts pruning
		# from the leaves of the filesystem.
		
		dir_line="$(dirname "$line")"
		base_line="$(basename "$line")"

		# Toggle verbose debugging
		if true; then
			echo
			echo "From: $line"
			echo "To  : ${dir_line}/${base_line/$trp/}"
		fi
		
		# Now clean!
		mv "$line" "$dir_line"/"${base_line/$trp/}"
		
	done < "$temp_out"

	# Remove the temporary file
	rm "$temp_out"
	exit 0 # Success exit status
fi
