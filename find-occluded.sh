#!/usr/bin/env bash
# Copyright 2013-2014, Michiel Buddingh, All rights reserved.  Use of this
# code is governed by version 2.0 or later of the Apache License,
# available at http://www.apache.org/licenses/LICENSE-2.0

function difference {
    local -r A=$1
    local -r B=$2

    (
	echo "$A"
	echo "$B"
    ) | sort | uniq -u
}

function intersect {
    local -r A=$1
    local -r B=$2

    (
	echo "$A"
	echo "$B"
    ) | sort | uniq -d
}

function report {
    local -r MERGE=$1
    local -r CHANGE=$2
    local -r FILES=$3
    local -r DIFFOPTS=$4

    echo "Merge $MERGE reverts the following from $CHANGE:"
    git --no-pager diff $DIFFOPTS $CHANGE $MERGE -- $FILES
}

function print-help-and-quit {
    cat <<EOF
find-occluded.sh [<commit>] [diffopts]

traverses the ancestors of <commit> (presumed to be HEAD if omitted)
to find commits that have been occluded by a merge.  An occluded
ancestor is essentially reverted, but does not show up in git logs
very clearly.  [diffopts] can be used to pass output options to git
diff.

Octopus merges will not be handled correctly.

This script is very slow, and works its way back to the very first
merge commit ancestor.  On long, merge-intensive histories, expect it
to take several minutes to complete.
EOF
    exit
}

function find {
    if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "--h" ]]; then
	print-help-and-quit;
    else
	local -r HEAD=${1:-"HEAD"};
    fi

    shift

    DIFFOPTS=${*:---stat}

    local MERGE LEFT RIGHT BASE TOTAL LEFTCHANGE RIGHTCHANGE

    for MERGE in $(git rev-list --abbrev-commit --merges $HEAD); do
	LEFT="$MERGE^1"
	RIGHT="$MERGE^2"
	BASE=$(git merge-base $LEFT $RIGHT)

	TOTAL=$(git diff-tree --name-only $MERGE $BASE)
	LEFTCHANGE=$(git diff-tree --name-only $LEFT $BASE)
	RIGHTCHANGE=$(git diff-tree --name-only $RIGHT $BASE)

	LEFTREVERT=$(intersect "$(difference "$TOTAL" "$LEFTCHANGE")" "$LEFTCHANGE")
	RIGHTREVERT=$(intersect "$(difference "$TOTAL" "$RIGHTCHANGE")" "$RIGHTCHANGE")

	if [ ! -z "$LEFTREVERT$RIGHTREVERT" ]; then
	    TOTAL=$(git diff --name-only $MERGE $BASE)

	    if [ ! -z "$LEFTREVERT" ]; then
		LEFTCHANGE=$(git diff --name-only $LEFT $BASE)
		LEFTREVERT=$(intersect "$(difference "$TOTAL" "$LEFTCHANGE")" "$LEFTCHANGE")
		report $MERGE $LEFT "$LEFTREVERT" "$DIFFOPTS"
	    fi

	    if [ ! -z "$RIGHTREVERT" ]; then
		RIGHTCHANGE=$(git diff --name-only $RIGHT $BASE)
		RIGHTREVERT=$(intersect "$(difference "$TOTAL" "$RIGHTCHANGE")" "$RIGHTCHANGE")
		report $MERGE $RIGHT "$RIGHTREVERT" "$DIFFOPTS"
	    fi
	fi
    done;
}

find $*;
