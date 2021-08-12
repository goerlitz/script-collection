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
echo "path is $realdir"

verbose=0


OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "r:d:v" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    v)  verbose=1
        ;;
    esac
done

shift $((OPTIND-1))

# ------------------

# get the event name for all images in the folder (if multiple events, use most frequent)
event_name=$(sqlite3 ~/.shotwell_canon/data/photo.db "SELECT name FROM PhotoTable pt JOIN EventTable et ON pt.event_id = et.id WHERE filename LIKE '$realdir%' AND name is not NULL GROUP BY 1 ORDER BY count(*) desc LIMIT 1;")

# events start with the date - remove it, we only want the description
event_name=${event_name#*20?? }

# check that event name is not empty
if [ -z "$event_name" ]; then
    echo "event name is empty"
    exit 1
fi

newdir="$realdir $event_name"
echo "new dir $newdir"

mv "$realdir" "$newdir"

# -----------------

# SQL result may contain SPACE - don't split
IFS=$'\n'

# update database entry for every image in directory
for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable WHERE filename LIKE '$realdir%'";); do
    path=${img%/*}
    file=${img##*/}
    new_img="$path $event_name/$file"

    echo "-> $new_img"

    # update filename in photo table
    sqlite3 $DB "UPDATE PhotoTable SET filename='$new_img' WHERE filename = '$img';"

    # update filename in backing table if there is a developed image version
    img_bk=$(sqlite3 $DB "SELECT filepath FROM BackingPhotoTable bpt JOIN PhotoTable pt ON bpt.id = pt.develop_camera_id WHERE filename = '$img'";)
    if [ ! -z "$img_bk" ]; then
        path_bk=${img_bk%/*}
        file_bk=${img_bk##*/}
        new_img_bk="$path_bk $event_name/$file_bk"
        echo "=> $new_img_bk"
        sqlite3 $DB "UPDATE BackingPhotoTable SET filepath='$new_img_bk' WHERE filepath = '$img_bk';"
    fi
done

unset IFS

