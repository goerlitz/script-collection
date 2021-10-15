#!/bin/bash

# Move a specified image directory to a new location.

# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/

function usage {
        echo "Usage: $(basename $0) <source directory> <dest directory>" 2>&1
        echo '   -v   verbose'
        echo '   -t   test (dry run)'
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

## use source dir name as new dst subfolder
#real_dst_dir="$real_dst_dir/$src_dir"

# check if directories exists
[ ! -d "$real_src_dir/" ] && echo "Source dir does not exist! - $real_src_dir" && exit 1
[ ! -d "$real_dst_dir/" ] && echo "Destination dir does not exist! - $real_dst_dir" && exit 1


# set variables
verbose=0
dryrun=0

OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "r:d:vth" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    v)  verbose=1
        ;;
    t)  dryrun=1
        ;;
    h)  usage
        ;;
    esac
done

shift $((OPTIND-1))

# ------------------

if [ "$dryrun" -eq "1" ];then
    echo "executing DRY RUN!"
fi

if [ "$verbose" -eq "1" ];then
    echo "SRC>>> $real_src_dir"
    echo "DST>>> $real_dst_dir"
fi


# -----------------

# SQL result may contain SPACE - don't split
IFS=$'\n'

COUNT=0
COUNT_BACKING=0

COUNT_MISSING=0

# update database entry for every image in directory
for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable WHERE filename LIKE '$real_src_dir%'";); do

    new_img=${img/$real_src_dir/$real_dst_dir}

    # check if new file exists
    if [ ! -e "$new_img" ]; then
        (( COUNT_MISSING++ ))
        echo "MISSING--> $new_img"
        continue
    fi


    # first update filename in backing table if there is a developed image version
    img_bk=$(sqlite3 $DB "SELECT filepath FROM BackingPhotoTable bpt JOIN PhotoTable pt ON bpt.id = pt.develop_camera_id WHERE filename = '$img'";)
    if [ ! -z "$img_bk" ]; then

        new_img_bk=${img_bk/$real_src_dir/$real_dst_dir}

        # check if new file exists
        if [ ! -e "$new_img_bk" ]; then
            (( COUNT_MISSING++ ))
            continue
        fi

        # update backing photo
        if [ "$dryrun" -eq "0" ];then
            sqlite3 $DB "UPDATE BackingPhotoTable SET filepath='$new_img_bk' WHERE filepath = '$img_bk';"
            (( COUNT_BACKING++ ))
        fi

        if [ "$verbose" -eq "1" ];then
            echo "B=> $new_img_bk"
        fi
    fi

    # update primary photo
    if [ "$dryrun" -eq "0" ];then
        sqlite3 $DB "UPDATE PhotoTable SET filename='$new_img' WHERE filename = '$img';"
        (( COUNT++ ))
    fi

    if [ "$verbose" -eq "1" ];then
        echo "--> $new_img"
    fi
done

# update database entry for every video in directory
for vid in $(sqlite3 $DB "SELECT filename FROM VideoTable WHERE filename LIKE '$real_src_dir%'";); do

    new_vid=${vid/$real_src_dir/$real_dst_dir}

    # check if new file exists
    if [ ! -e "$new_vid" ]; then
        (( COUNT_MISSING++ ))
        continue
    fi

    # update video
    if [ "$dryrun" -eq "0" ];then
        sqlite3 $DB "UPDATE VideoTable SET filename='$new_vid' WHERE filename = '$vid';"
        (( COUNT++ ))
    fi

    if [ "$verbose" -eq "1" ];then
        echo "--> $new_vid"
    fi
done


unset IFS

echo "MISSING $COUNT_MISSING photos"

echo "DONE: $COUNT photos/videos updated (+$COUNT_BACKING backing photos)"

