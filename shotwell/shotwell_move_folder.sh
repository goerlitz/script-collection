#!/bin/bash

# Move a specified image directory to a new locaion.

# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/

function usage {
        echo "Usage: $(basename $0) <source directory> <dest directory>" 2>&1
        echo '   -v   verbose'
        echo '   -h   help (this text)'
        exit 1
}

# check if no parameters provided -> show usage/help
if [[ ${#} -lt 2 ]]; then
   usage
fi


# shotwell database to use (env variable)
DB=$SHOTWELL_DB


# first parameter is orginal directory
src_dir=$1; shift
real_src_dir=$(realpath "$src_dir")

# second parameter is destination directory
dst_dir=$1; shift
real_dst_dir=$(realpath "$dst_dir")

# use source dir name as new dst subfolder
real_dst_dir="$real_dst_dir/$src_dir"

# check if directories exists
[ ! -d "$real_src_dir/" ] && echo "Source dir does not exist! - $real_src_dir" && exit 1
[ ! -d "$real_dst_dir/" ] && echo "Destination dir does not exist! - $real_dst_dir" && exit 1


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
    echo "source path is $real_src_dir"
    echo "dest path is $real_dst_dir"
fi


# -----------------

# SQL result may contain SPACE - don't split
IFS=$'\n'

COUNT=0
COUNT_BACKING=0

# update database entry for every image in directory
for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable WHERE filename LIKE '$real_src_dir%'";); do
    file=${img##*/}
    new_img="$real_dst_dir/$file"

    # first update filename in backing table if there is a developed image version
    img_bk=$(sqlite3 $DB "SELECT filepath FROM BackingPhotoTable bpt JOIN PhotoTable pt ON bpt.id = pt.develop_camera_id WHERE filename = '$img'";)
    if [ ! -z "$img_bk" ]; then
        file_bk=${img_bk##*/}
        new_img_bk="$real_dst_dir/$file_bk"

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

unset IFS

echo "DONE: $COUNT photos updated (+$COUNT_BACKING backing photos)"

