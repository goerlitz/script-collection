#!/bin/bash

# Move a specified image directory to a new location.

# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/

function usage {
        echo "Usage: $(basename $0) <options> <source directory> <dest directory>" 2>&1
        echo '   -v   verbose, add more -v to increase verbosity'
        echo '   -t   test (dry run)'
        echo '   -h   help (this text)'
        exit 1
}

# check if no parameters provided -> show usage/help
if [[ ${#} -eq 0 ]]; then
   usage
fi

verbose=0
dryrun=0

# shotwell database to use (env variable)
DB=$SHOTWELL_DB

OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "d:vth" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    t)  dryrun=1;verbose=1
        ;;
    v)  (( verbose++ ))
        ;;
    h)  usage
        ;;
    esac
done

shift $((OPTIND-1))

# ------------------

# check if shotwell database was set
if [ -z $DB ];then
    echo "ERROR: please specify shotwell database in env 'SHOTWELL_DB'!"
    exit 1
fi

echo "SHOTWELL DB: '$DB'"




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


if [ "$verbose" -ne "0" ];then
    echo "SRC>>> $real_src_dir"
    echo "DST>>> $real_dst_dir"
fi

if [ "$dryrun" -eq "1" ];then
    echo ">>> ---DRY RUN--- <<<"
fi

# function to prepare SQL path strings
sql_safe() {
    local tmp

    # duplicate single quotes (otherwise error)
    tmp=${1//\'/\'\'} # replace '
    echo $tmp
}


# -----------------

# SQL result may contain SPACE - don't split
IFS=$'\n'

COUNT=0
COUNT_BACKING=0
COUNT_MISSING=0

# update database entry for every image in directory
for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable WHERE filename LIKE '$(sql_safe "$real_src_dir")%'";); do

    if [ "$verbose" -ne "0" ];then
        echo "PROCESSING '$img'"
    fi

    new_img=${img/$real_src_dir/$real_dst_dir}

    # check if new file exists
    if [ ! -e "$new_img" ]; then
        (( COUNT_MISSING++ ))
        echo "MISSING--> '$new_img'"
        continue
    fi


    # first update filename in backing table if there is a developed image version
    img_bk=$(sqlite3 $DB "SELECT filepath FROM BackingPhotoTable bpt JOIN PhotoTable pt ON bpt.id = pt.develop_camera_id WHERE filename = '$(sql_safe "$img")'";)
    if [ ! -z "$img_bk" ]; then

        new_img_bk=${img_bk/$real_src_dir/$real_dst_dir}

        # check if new file exists
        if [ ! -e "$new_img_bk" ]; then
            (( COUNT_MISSING++ ))
            continue
        fi

        # update backing photo
        if [ "$dryrun" -eq "0" ];then
            sqlite3 $DB "UPDATE BackingPhotoTable SET filepath='$(sql_safe "$new_img_bk")' WHERE filepath = '$(sql_safe "$img_bk")';"
            (( COUNT_BACKING++ ))
        fi

        if [ "$verbose" -gt "1" ];then
            echo "B=> $new_img_bk"
        fi
    fi

    # update primary photo
    if [ "$dryrun" -eq "0" ];then
        sqlite3 $DB "UPDATE PhotoTable SET filename='$(sql_safe "$new_img")' WHERE filename = '$(sql_safe "$img")';"
        (( COUNT++ ))
    fi

    if [ "$verbose" -gt "1" ];then
        echo "--> $new_img"
    fi
done

# update database entry for every video in directory
for vid in $(sqlite3 $DB "SELECT filename FROM VideoTable WHERE filename LIKE '$(sql_safe "$real_src_dir")%'";); do

    if [ "$verbose" -ne "0" ];then
        echo "PROCESSING '$vid'"
    fi

    new_vid=${vid/$real_src_dir/$real_dst_dir}

    # check if new file exists
    if [ ! -e "$new_vid" ]; then
        (( COUNT_MISSING++ ))
        continue
    fi

    # update video
    if [ "$dryrun" -eq "0" ];then
        sqlite3 $DB "UPDATE VideoTable SET filename='$(sql_safe "$new_vid")' WHERE filename = '$(sql_safe "$vid")';"
        (( COUNT++ ))
    fi

    if [ "$verbose" -gt "1" ];then
        echo "--> $new_vid"
    fi
done


unset IFS

echo "MISSING $COUNT_MISSING photos"

echo "DONE: $COUNT photos/videos updated (+$COUNT_BACKING backing photos)"

