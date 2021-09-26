#!/bin/bash

# Rename the specified directory with images using the shotwell folder name.

# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/

function usage {
        echo "Usage: $(basename $0) <directory>" 2>&1
        echo '   -v   verbose'
        echo '   -h   help (this text)'
        exit 1
}

# check if no parameters provided -> show usage/help
if [[ ${#} -eq 0 ]]; then
   usage
fi


# shotwell database to use (env variable)
DB=$SHOTWELL_DB


# first parameters is directory
dir=$1; shift

realdir=$(realpath "$dir")


# check if directory exists
[ ! -d "$realdir/" ] && echo "Dir does not exist! - $realdir" && exit 1


# set variables
verbose=0

OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "r:d:vh" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    v)  verbose=1
        ;;
    h)  usage
        ;;
    esac
done

shift $((OPTIND-1))

# ------------------

if [ "$verbose" -eq "1" ];then
    echo "path is $realdir"
fi

# get all event names
event_names=$(sqlite3 $DB "SELECT DISTINCT name FROM PhotoTable pt JOIN EventTable et ON pt.event_id = et.id WHERE filename LIKE '$realdir%' AND name is not NULL;")


# SQL result may contain SPACE - don't split
IFS=$'\n'

COUNT=0
COUNT_BACKING=0

for e in $event_names; do

    # events start with the date - remove it (assuming year is last part), we only want the description
    event_name=${e#*20?? }

    # check that event name is not empty
    if [ -z "$event_name" ]; then
        echo "SKIP: event name is empty"
        continue
    fi

    # keep only date of currently processes directory
    dirname=${realdir##*/}
    dirdate=${dirname%% *}

    newdir="${realdir%/*}/$dirdate $event_name"

    if [ "$verbose" -eq "1" ];then
        echo "NEW: $newdir"
    fi

    if [ "$newdir" == "$realdir" ]; then
        echo "SKIP: new dir is the same - no need to rename!"
        continue
    fi

    if [ -d "$newdir" ]; then
        echo "SKIP: new dir already exists!"
        continue
    fi

    mkdir "$newdir"

    # get images for event and update database entry
    for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable pt JOIN EventTable et ON pt.event_id = et.id WHERE filename LIKE '$realdir%' AND name = '$e' ORDER BY filename;"); do
        file=${img##*/}
        new_img="$newdir/$file"

        # move the file
        mv "$img" "$new_img"

        # first update filename in backing table if there is a developed image version
        img_bk=$(sqlite3 $DB "SELECT filepath FROM BackingPhotoTable bpt JOIN PhotoTable pt ON bpt.id = pt.develop_camera_id WHERE filename = '$img'";)
        if [ ! -z "$img_bk" ]; then
            file_bk=${img_bk##*/}
            new_img_bk="$newdir/$file_bk"

            # finally move the file
            mv "$img_bk" "$new_img_bk"

            sqlite3 $DB "UPDATE BackingPhotoTable SET filepath='$new_img_bk' WHERE filepath = '$img_bk';"
            (( COUNT_BACKING++ ))

            if [ "$verbose" -eq "1" ];then
                echo "B=> $new_img_bk"
            fi
        fi

        # then update filename in photo table
        sqlite3 $DB "UPDATE PhotoTable SET filename='$new_img' WHERE filename = '$img';"
        (( COUNT++ ))

        if [ "$verbose" -eq "1" ];then
            echo "--> $new_img"
        fi

    done

done
unset IFS

echo "DONE: $COUNT photos updated (+$COUNT_BACKING backing photos)"

