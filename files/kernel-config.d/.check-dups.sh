#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

files=( * )

p() {
	cut -d= -f1 "$1" \
		| sed 's!^-!!' \
		| sort -u
}

for (( i = 0; i < ${#files[@]}; ++i )); do
	for (( j = i + 1; j < ${#files[@]}; ++j )); do
		f1="${files[$i]}"
		f2="${files[$j]}"
		comm -12 <(p "$f1") <(p "$f2")
	done
done
