#!/bin/bash

VERSION="$1"
OUTPUT="$2"

if [[ $VERSION == "" ]]
then
    echo "First argument to script must be a template version directory name"
    exit 1
fi

SELF=`readlink -f $0`
BASE="$( dirname $SELF )"
TEMPLATE_DIR="$BASE/../templates/$VERSION"
FINAL_DIR="$BASE/../final/$VERSION"

FIND="find $TEMPLATE_DIR -maxdepth 1 -name '*.json' -exec $BASE/file_template_to_json.pl -i {} -o $FINAL_DIR \;"

if [ ! -d "$TEMPLATE_DIR" ]
then
    echo "Template dir for version '$VERSION' doesn't exist"
    exit 1
fi

if [ ! -d "$FINAL_DIR" ]
then
    mkdir -p "$FINAL_DIR"
fi

$( eval $FIND )

$BASE/json_files_to_json_dictionary.pl -i $FINAL_DIR -o "$OUTPUT"
