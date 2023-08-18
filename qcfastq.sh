#!/bin/bash

ADD SPECIFICITY TO LOG FINDING IN ALL SCRIPTS!!!

# ============================================================================ #
#  FASTQ Quality Control
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Function definition ------------------------------------------------------

# FastQC local folder (** TO ADAPT UPON INSTALLATION **)
fastqc_path="${HOME}/FastQC"
#multiqc_path=   ...TO BE IMPLEMENTED...
#qualimap_path=
#pca_path=
if [[ ! -f "${fastqc_path}/fastqc" ]]; then
	printf "Couldn't find 'fastqc' in '"${fastqc_path}"'!\n"
	exit 1 # Argument failure exit status: bad target path
fi

# Default options
ver="1.0.0"
verbose=true
suffix=".fastq.gz"
tool="FastQC"

# Print the help
function _help_qcfastq {
	echo
	echo "This script is meant to perform Quality Control (QC) analyses of NGS"
	echo "data running the most popular software tools over a set of FASTQ"
	echo "files in a "
	echo
	echo "Usage:"
	echo "  qcfastq [-h | --help] [-v | --version]"
	echo "  qcfastq -p | --progress [TARGETS]"
	echo "  qcfastq [-q | --quiet] [--suffix=STRING] [--tool=QCTYPE]"
	echo "          [--out=NAME] TARGETS"
	echo
	echo "Positional options:"
	echo "  -h | --help       Show this help."
	echo "  -v | --version    Show script's version."
	echo "  -p | --progress   Show TARGETS QC analysis progress. If TARGETS is"
	echo "                    not specified, search \$PWD for QC processes."
	echo "  -q | --quiet      Disable verbose on-screen logging."
	echo "  --suffix=STRING   Argument allowing for user-defined input."
	echo "  --tool=QCTYPE     QC software to be used"
	echo "  --out=NAME        the name of the output folder. Just the name of"
	echo "                    the folder, not the entire path. In case a path"
	echo "                    is provided it will be ignored and only the"
	echo "                    basename will be used to make a sub dir in TARGETS folder"
	echo "  TARGETS           The path to the file-containing folder to work on."
	echo
	echo "Additional Notes:"
	echo "    You can use this or that to do something..."
}

# Show analysis progress printing the tail of the latest log
function _progress_qcfastq {

	if [[ -d "$1" ]]; then
		target_dir="$1"
	else
		printf "Bad TARGETS path '$1'.\n"
		exit 1 # Argument failure exit status: bad target path
	fi

	# NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
	#       the modification timestamp followed by the filename.
	latest_log=$(find "${target_dir}" -maxdepth 1 -type f -iname "QC_*.log" \
		-printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d " " -f 2)

	if [[ -n "$latest_log" ]]; then
		
		echo -e "\n${latest_log}"

		printf "\n${grn}Completed:${end}\n"
		grep --no-filename "Analysis complete" "${latest_log}" || [[ $? == 1 ]]
		
		printf "\n${yel}Tails:${end}\n"
		tail -n 1 "${latest_log}"
		exit 0 # Success exit status
	else
		printf "No log file found in '$(realpath "$target_dir")'.\n"
		exit 1 # Argument failure exit status: missing log
	fi
}

# On-screen and to-file logging function
#
# USAGE: _dual_log $verbose log_file "message"
#
# Always redirect "message" to log_file; also redirect it to standard output
# (i.e., print on screen) if $verbose == true.
# NOTE:	the 'sed' part allows tabulations to be ignored while still allowing
#       the code (i.e., multi-line messages) to be indented.
function _dual_log {
	if $1; then echo -e "$3" | sed "s/\t//g"; fi
	echo -e "$3" | sed "s/\t//g" >> "$2"
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_qcfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet qc FASTQ
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
			-p | --progress)
				# Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
				_progress_qcfastq "${2:-.}"
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			--suffix*)
				# Test for '=' presence
				if [[ "$1" =~ ^--suffix=  ]]; then
					suffix="${1/--suffix=/}"
					shift
				else
					printf "Values need to be assigned to '--suffix' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 1 # Bad suffix assignment
				fi
			;;
			--tool*)
				# Test for '=' presence
				if [[ "$1" =~ ^--tool=  ]]; then
					
					tool="${1/--tool=/}"
					
					if [[ "$tool" == "PCA" || \
					      "$tool" == "FastQC" || \
					      "$tool" == "MultiQC" || \
					      "$tool" == "QualiMap" ]]; then
						shift
					else
						printf "Invalid QC tool name: '${tool}'.\n"
						printf "Please, choose among the following options:\n"
						printf "  -  PCA\n"
						printf "  -  FastQC\n"
						printf "  -  MultiQC\n"
						printf "  -  QualiMap\n"
						exit 1
					fi
				else
					printf "Values need to be assigned to '--tool' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 1 # Bad suffix assignment
				fi
			;;
			--out*)
				# Test for '=' presence
				if [[ "$1" =~ ^--out=  ]]; then
					out_dirname="${1/--out=/}"
					shift
				else
					printf "Values need to be assigned to '--out' option "
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
		target_dir="$1"
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

target_dir="$(realpath "$target_dir")"
log_file="${target_dir}"/QC_"${tool}"_"$(basename "$target_dir")"_"${now}".log

counter=$(ls "${target_dir}"/*"$suffix" 2>/dev/null | wc -l)

if (( counter > 0 )); then
	_dual_log $verbose "$log_file" "\n\
		Found $counter FASTQ files ending with \"${suffix}\" in ${target_dir}."
else
	_dual_log true "$log_file" "\n\
		There are no FASTQ files ending with \"${suffix}\" in ${target_dir}."
	exit 1 # Argument failure exit status: no FASTQ found
fi

# Existence operator ${:-} <=> ${user-defined_name:-default_name}
output_dir="${target_dir}/${out_dirname:-"${tool}_out"}"
mkdir "$output_dir"

target_files=$(find "$target_dir" -maxdepth 1 -type f -iname *"$suffix")

_dual_log $verbose "$log_file" "\n\
	Running ${tool} tool in background and saving output in ${output_dir}...\n"

case "$tool" in
	PCA)
		echo "PCA selected. TO BE DONE..."
	;;
	FastQC)
		nohup "${fastqc_path}"/fastqc -o "${output_dir}" ${target_files} \
			>> "$log_file" 2>&1 &
	;;
	MultiQC)
		echo "MultiQC selected. TO BE DONE..."
	;;
	QualiMap)
		echo "QualiMap selected. TO BE DONE..."
	;;
esac