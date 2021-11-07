#!/bin/bash

# Remove raw CR2 images for images that have a low rating.
# Will only be applied for images with CR2 and JPG file with the same name.
# image entry in shotwell database will be updated from CR2->JPG.

function usage {
        echo "Usage: $(basename $0) <options> <directory>" 2>&1
        echo '   -r   highest image rating (default=3)'
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

# default rating is 3
rating=3

# shotwell database to use (env variable)
DB=$SHOTWELL_DB

OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "r:vth" opt; do
    case "$opt" in
    h)  usage
        ;;
    r)  rating=$OPTARG  # shotwell image rating
        ;;
    t)  dryrun=1;verbose=1
        ;;
    v)  (( verbose++ ))
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


# first regular parameter is directory
dir=$1; shift

realdir=$(realpath "$dir")

if [ -z "$realdir" ];then
    echo "ERROR: path '$dir' does not exist!"
    exit 1
else
    echo "TARGET PATH: '$realdir'"
fi

echo "using max image rating $rating"

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

# SQL result may contain SPACE - don't split
IFS=$'\n'

COUNT=0

# process all images that have the specified max rating (default=3)
for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable WHERE filename LIKE '$(sql_safe "$realdir")%' AND filename LIKE '%.CR2' AND rating > 0 AND rating <= $rating ORDER BY 1";); do

    if [ "$verbose" -ne "0" ];then
        echo "PROCESSING '$img'"
    fi

    # looking for camera-developed image in backing files
    devcamid=$(sqlite3 $DB "SELECT develop_camera_id FROM PhotoTable WHERE filename='$(sql_safe "$img")'";)
    if [ -z $devcamid ]; then
        echo "ERROR: no entry for $img"
    else
        # get backing file information
        backing=$(sqlite3 $DB "SELECT * FROM BackingPhotoTable WHERE id=$devcamid";)
        if [ -z $backing ]; then
            echo "ERROR: No backing entry for $img"
        else
            # split SQL result
            readarray -d \| -t split<<< "$backing"
            filepath=${split[1]}
            timestamp=${split[2]}
            filesize=${split[3]}
            width=${split[4]}
            height=${split[5]}
            original_orientation=${split[6]}
            file_format=${split[7]}
            time_created=${split[8]}
            md5=$(md5sum "$filepath" | cut -d" " -f1)

            if [ "$verbose" -gt "1" ];then
                echo "CR2->JPG: ts=$timestamp fs=$filesize w=$width h=$height fmt=$file_format md5=$md5"
            fi

            if [ "$dryrun" -eq "0" ];then
                # replace CR2 with backing photo
                sqlite3 $DB "UPDATE PhotoTable SET filename='$(sql_safe "$filepath")', width=$width, height=$height, filesize=$filesize, timestamp=$timestamp, time_created=$time_created, md5='$md5', file_format=$file_format, developer='SHOTWELL', develop_camera_id=-1 WHERE filename = '$(sql_safe "$img")';"

                # remove backing photo
                sqlite3 $DB "DELETE FROM BackingPhotoTable WHERE id=$devcamid;"

                mv "$img" .

               (( COUNT++ ))
            fi

        fi
    fi

done

unset IFS

echo "DONE: $COUNT CR2 photos removed"

