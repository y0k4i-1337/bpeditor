#!/bin/bash

# Copyright 2021 M. Choji
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

DEPENDS="jq"

echoerr() {
    printf "\e[0;31m[!]\e[0m %s\n" "$*" >&2
}

echook() {
	printf "\e[0;32m[+]\e[0m %s\n" "$*" >&1
}

print_help() {
	echo -e "\033[0;32mUsage:\033[0m $0 [-o FILE] INPUT PROJECT"
	echo ""
	echo "  -o           write results to FILE"
	echo "               By default, it makes a backup from PROJECT and overwrites it."
	echo ""
	echo "  INPUT        file containing the input data"
	echo "  PROJECT      Burp's project settings"
	echo ""
	echo -e "\033[0;32mExample:\033[0m $0 ssl-pass-through-rules.txt myproject.json"
}

check_dep() {
    cmd=$(which $1)
    if [ $? -ne 0 ]; then
        echoerr Command $1 required but not found
        exit 1
    fi
}

check_all_deps() {
    for dep in $1; do
        check_dep $dep
    done
}

validate_input_file() {
	if [ ! -f $1 ]; then
		echoerr File was not found: $1
		exit 1
	elif [ ! -r $1 ]; then
		echoerr Missing permission to read file: $1
		exit 1
	fi
}

# set of functions for proxy ssl_pass_through (pspt) module

# reads a file containing domains (usually regex) and creates an array
pspt_make_array() {
	local first=0
	local array="["
	while read -r entry; do
		entry_esc=$(echo -E $entry | sed 's/\\/\\\\/g')
		new_rule="{\"enabled\":true, \"host\":\"$entry_esc\", \"protocol\":\"any\"}"
		if [ $first -eq 0 ]; then
			array+="$new_rule"
			first=1
		else
			array+=", $new_rule"
		fi
	done < $1
	array+="]"
	echo -E $array
}

# append new rules to proxy's ssl_pass_through option
# $1: rules as JSON array
# $2: Burp's project file
pspt_append_rules() {
	local cmd
	cmd="jq '.proxy.ssl_pass_through.rules |= . + "
	cmd+="$1"
	cmd+="' $2"
	eval $cmd
	if [ $? -ne 0 ]; then
		echoerr Aborting!
		exit 1
	fi
}

# run module pspt
pspt_run() {
	local rules_file=$1
	local project_file=$2
	local output_file=$3

	pspt_new_rules=$(pspt_make_array $rules_file)
	pspt_append_rules "$pspt_new_rules" $project_file > $output_file
}

# SCRIPT STARTS HERE
input_file=""
project_file=""
output_file=""

# process options and arguments
while getopts ":ho:" opt; do
	case ${opt} in
		h)
			print_help
			exit
			;;
		o)
			output_file=$OPTARG
			;;
		\?)
			echoerr Invalid option: -$OPTARG
			print_help
			exit 1
			;;
		:)
			echoerr Invalid option: -$OPTARG requires an argument
			print_help
			exit 1
			;;
		*)
			echoerr Unexpected error
			exit 1
			;;
	esac
done

shift $(( OPTIND - 1 )) # processing additional arguments
if [ $# -ne 2 ]; then
	echoerr Invalid number of positional arguments: expected 2
	print_help
	exit 1
fi

# check if input files exist and are readable
validate_input_file $1
validate_input_file $2

# if output file was given, check if it is writable
if [ -n "$output_file" ]; then
	if [ -f $output_file -a ! -w $output_file ]; then
		echoerr Cannot write to file: $output_file
		exit 1
	elif [ ! -f $output_file -a ! -w $(dirname $output_file) ]; then
		echoerr Cannot write to directory: $(dirname $output_file)
		exit 1
	fi
fi

input_file=$1
project_file=$2

# end of options parsing

check_all_deps $DEPENDS


# make temporary file to store results
new_project_file=$(mktemp)

echook Processing input file
pspt_run $input_file $project_file $new_project_file

if [ $? -ne 0 ]; then
	echoerr Unexpected error. Aborting!
fi

# save results
if [ -n "$output_file" ]; then
	mv $new_project_file $output_file
	echook Output writen to $output_file
else
	mv $project_file $project_file.bak
	echook Original file moved to $project_file.bak
	mv $new_project_file $project_file
	echook Ouptut writen to $project_file
fi

echook Done! 
