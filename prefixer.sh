#!/bin/bash

# This function is meant to prepend a given suffix (typically a unique ID) to
# every file and folder found in the target directory, including possible
# subdirectories. It was originally written as a patch for a pre-release version
# of x.FASTQ, which initially didn't use any suffix for STAR/RSEM (i.e.,
# anqFASTQ module) output files, thus preventing MultiQC from including them in
# the final report. Specifically, it was used to fix filenames in many "Counts"
# subfolders of the first Endothelion project (until x.FASTQ Ver.Sum x.13.62.0,
# April 11, 2024).
#
# By default, the prefix to prepend is the name of the target folder (under the
# hypothesis its name being a meaningful project/sample/run ID), but it can be
# any custom user-defined string passed as second argument. In any case, files
# that already feature the prefix at the beginning of their names are skipped. 
# Currently, the function searches the target directory just two-level deep,
# but it's easy to change this behavior.
# The function is tested for the presence of any spaces in paths or filenames.
# It's important to notice how the results of 'find' are (reverse 'r') sorted
# according to their depth level ('%d'). This is because the 'for' loop needs to
# process files starting from the deepest levels of the filesystem, otherwise it
# won't be able to access those files whose parent directory has already been
# renamed.

# USAGE:
#   _prefixer <target_directory>
#   _prefixer <target_directory> <custom_prefix>
function _prefixer {

	local target_dir="$(realpath "${1:-""}")"
	local prefix="${2:-$(basename "${target_dir}")}"

	if [[ -z "$target_dir" ]]; then
		echo "Invalid target directory."
		return
	fi

	local mv_count=0
	local skip_count=0
	echo "Processing file:"
	# Looping through files with spaces in their names or paths is not such a
	# trivial thing...
	OIFS="$IFS"
	IFS=$'\n'
	for file in $(find "$target_dir" -mindepth 1 -maxdepth 2 \
		\( -type f -o -type d \) -printf '%d %p\n' \
		| sort -nr -k1 | cut -d' ' -f 2-)
	do
		local foldername="$(dirname "${file}")"
		local filename="$(basename "${file}")"

		if [[ "$filename" == "${prefix}"_* ]]; then
			echo "  ${file}"
			echo -e "   └── \e[1;31mskipped (already prefixed)\e[0m"
			skip_count=$(( skip_count + 1 ))
		else
			mv "$file" "${foldername}"/"${prefix}"_"${filename}"
			echo "  ${file}"
			echo -e "   └── \e[1;32mrenamed as .../${prefix}_${filename}\e[0m"
			mv_count=$(( mv_count + 1 ))
		fi
	done
	IFS="$OIFS"

	# Final report
	echo
	echo "$mv_count files prefixed"
	echo "$skip_count files skipped"
}
