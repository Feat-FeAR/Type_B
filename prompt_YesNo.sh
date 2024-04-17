#!/bin/bash

# Just a general Yes/No user prompt, with Yes as default answer

# Ask for user permission to do something
printf "\nWARNING: This procedure will compromise your dignity..."
valid_ans=false
while ! $valid_ans; do
    read -ep "Proceed anyway (Y/n)? " ans
    no_rgx="^[Nn][Oo]?$"
    yes_rgx="^[Yy](ES|es)?$"
    if [[ $ans =~ $no_rgx ]]; then
        printf "  Aborting procedure... nothing changed.\n"
        exit 1
    elif [[ $ans =~ $yes_rgx || -z "$ans" ]]; then
        printf "\n"
        valid_ans=true
    else
        printf "  Invalid answer '$ans'\n"
    fi
done
