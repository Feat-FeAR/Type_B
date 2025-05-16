#!/bin/bash

# ==============================================================================
#  md5sum checker
# ==============================================================================

# --- Help ---------------------------------------------------------------------
#
# Check the integrity of a set of files in a directory by comparing MD5 hashes
#
# USAGE:
#    ./md5sum_checker.sh <target_path> <extension> <chechsum_table>
#
#    <target_path>       folder containing the files to be checked (possibly
#                        organized inside one subfolder)
#    <extension>         extension (not a regex!) used to filter the files found
#                        in <target_path>
#    <chechsum_table>    reference hashes. A file containing a list of verified
#                        MD5 hashes (e.g., as provided by the sequencer), one
#                        for each file to check, formatted as follows
#                           <verified_hash_1> <file_name_1>
#                           <verified_hash_2> <file_name_2>
#                           <verified_hash_3> <file_name_3>
#                           ...
#
# EXAMPLE:
#  ./md5sum_checker.sh . ".fastq.gz" ./md5sum.txt
#  ./md5sum_checker.sh . ".fastq.gz" ./md5sum.txt | tee ./checksum_results.txt

# --- Strict mode options ------------------------------------------------------
set -e           # "exit-on-error" shell option
set -u           # "no-unset" shell option
set -o pipefail  # exit on within-pipe error

# --- Main program -------------------------------------------------------------
target_path="$(realpath "$1")"
extension="$2"
chechsum_table="$(realpath "$3")"

tot=$(find "$target_path" -maxdepth 2 -type f -iname "*${extension}" | wc -l)
counter=1

# Loop through files (accounting for possible spaces in their names)
OIFS="$IFS"
IFS=$'\n'
for target_file in $(find "$target_path" -maxdepth 2 -type f \
    -iname "*${extension}" | sort)
do
    file_name="$(basename "$target_file")"
    printf "\nChecking file ${counter}/${tot}: ${file_name}\n"
    
    # Actual hash
    checksum=$(cat "$target_file" | md5sum | cut -d' ' -f1)
    checksum=$(printf '%s' "$checksum" | tr '[:upper:]' '[:lower:]')
    printf "md5sum:    ${checksum}\n"

    # Expected hash
    should_be=$(grep -P "^\w{32} +$file_name" "$chechsum_table" \
        | cut -d' ' -f1 || [[ $? == 1 ]])
    should_be=$(printf '%s' "$should_be" | tr '[:upper:]' '[:lower:]')

    if [[ -z $should_be ]]; then
        printf "Error: cannot find ${file_name} hash in ${chechsum_table}.\n" >&2
        exit 1
    fi
    printf "should be: ${should_be}\n"

    # Case-insensitive comparison
    if [[ $checksum == $should_be ]]; then
        printf "\e[1;32m[---OK---]\e[0m\n"
    else
        printf "\e[1;31m[-FAILED-]\e[0m\n"
    fi
    ((counter++))
done
IFS="$OIFS"
