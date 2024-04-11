#!/bin/bash

# This function is meant to prepend a given suffix (typically a unique ID) to
# every file found in the target directory, including possible subdirectory.
# It was originally written as a patch for a pre-release version of x.FASTQ,
# which initially didn't use any suffix for STAR/RSEM (i.e., anqFASTQ module)
# output files, thus preventing MultiQC from including them in the final report.
# Specifically, it was used to fix filenames in many "Counts" subfolders of the
# first Endothelion project (until x.FASTQ Ver.Sum x.13.62.0, April 11, 2024).

function _prefixer {

	local target_dir="$(realpath "${1:-.}")"
	local prefix="$(basename "${target_dir}")"

	# Looping through files with spaces in their names or paths is not such a
	# trivial thing...
	OIFS="$IFS"
	IFS=$'\n'
	for file in $(find "$target_dir" -mindepth 1 -maxdepth 2 \
		\( -type f -o -type d \) -printf '%d %p\n' \
		| sort -nr -k1 | cut -d' ' -f2)
	do
		local foldername="$(dirname "${file}")"
		local filename="$(basename "${file}")"
		mv "$foldername"/"$filename" "$foldername"/"$prefix"_"$filename" 
	done
	IFS="$OIFS"
}
