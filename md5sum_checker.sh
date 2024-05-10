#!/bin/bash

# ==============================================================================
#  md5sum checker
# ==============================================================================

# USAGE:
#  ./md5sum_checker.sh <target_path> <extension> <chechsum_table>
# Example:
#  ./md5sum_checker.sh . ".fastq.gz" ./md5sum.txt

target_path="$1"
extension="$2"
chechsum_table="$3"

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
    
    checksum=$(cat "$target_file" | md5sum | cut -d' ' -f1)
    printf "md5sum:    ${checksum}\n"

    should_be=$(grep -F "$file_name" "$chechsum_table" | cut -d' ' -f1 \
        || [[ $? == 1 ]])
    printf "should be: ${should_be}\n"

    if [[ $checksum == $should_be ]]; then
        printf "\e[1;32m[---OK---]\e[0m\n"
    else
        printf "\e[1;31m[-FAILED-]\e[0m\n"
    fi
    ((counter++))
done
IFS="$OIFS"
