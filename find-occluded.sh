#!/usr/bin/env bash
# Copyright 2013, Michiel Buddingh, All rights reserved.  Use of this
# code is governed by version 2.0 or later of the Apache License,
# available at http://www.apache.org/licenses/LICENSE-2.0

function difference {
    A=$1
    B=$2

    (
	echo "$A"
	echo "$B"
    ) | sort | uniq -u
}

function intersect {
    A=$1
    B=$2

    (
	echo "$A"
	echo "$B"
    ) | sort | uniq -d
}

function report {
    MERGE=$1
    CHANGE=$2
    FILES=$3

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

HEAD=$1

if [ -z $HEAD ]; then
    HEAD="HEAD";
elif [[ "$HEAD" == "--help" || "$HEAD" == "-h" || "$HEAD" == "--h" ]]; then
    print-help-and-quit;
fi

shift

DIFFOPTS=$*

if [ -z $DIFFOPTS ]; then
    DIFFOPTS="--stat";
fi

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
	    report $MERGE $LEFT "$LEFTREVERT"
	fi

	if [ ! -z "$RIGHTREVERT" ]; then
	    RIGHTCHANGE=$(git diff --name-only $RIGHT $BASE)
	    RIGHTREVERT=$(intersect "$(difference "$TOTAL" "$RIGHTCHANGE")" "$RIGHTCHANGE")
	    report $MERGE $RIGHT "$RIGHTREVERT"
	fi
    fi
done;
