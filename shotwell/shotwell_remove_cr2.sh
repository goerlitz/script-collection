#!/bin/bash

# Remove CR2 images for images with a low rating.
# Will only be applied for images with CR2 and JPG file with the same name.
# image entry in shotwell database will be updated from CR2->JPG.


function usage {
        echo "Usage: $(basename $0) <directory>" 2>&1
        echo '   -r   highest image rating (default=3)'
        echo '   -v   verbose'
        echo '   -h   help (this text)'
        exit 1
}

# check if no parameters provided -> show usage/help
if [[ ${#} -eq 0 ]]; then
   usage
fi


# first parameters is directory
dir=$1; shift

realdir=$(realpath "$dir")
echo "path is $realdir"


verbose=0

# default rating is 3
rating=3


OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "r:d:v" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    r)  rating=$OPTARG  # shotwell image rating
        ;;
    v)  verbose=1
        ;;
    h)  usage
        ;;
    esac
done

shift $((OPTIND-1))

# shotwell database to use (env variable)
DB=$SHOTWELL_DB

if [ -z $DB ];then
    echo "ERROR: please specify shotwell database in env 'SHOTWELL_DB'!"
    exit 1
fi

if [ "$verbose" -eq "1" ];then
    echo "USING SHOTWELL DB: $DB"
fi

echo "using max image rating $rating"

# SQL result may contain SPACE - don't split
IFS=$'\n'

COUNT=0

for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable WHERE filename LIKE '$realdir%' AND filename LIKE '%.CR2' AND rating > 0 AND rating <= $rating ORDER BY 1";); do

    # looking for camera-developed image in backing files
    devcamid=$(sqlite3 $DB "SELECT develop_camera_id FROM PhotoTable WHERE filename='$img'";)
    if [ -z $devcamid ]; then
        echo "ERROR: no entry for $img"
    else
        # get backing file information
        backing=$(sqlite3 $DB "SELECT * FROM BackingPhotoTable WHERE id=$devcamid";)
        if [ -z $backing ]; then
            echo "ERROR: No backing entry for $img"
        else
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

            if [ "$verbose" -eq "1" ];then
                echo \> $filepath
                echo \> ts=$timestamp fs=$filesize w=$width h=$height fmt=$file_format md5=$md5
            fi

            echo UPDATING... $filepath

            # replace CR2 with backing photo
            sqlite3 $DB "UPDATE PhotoTable SET filename='$filepath', width=$width, height=$height, filesize=$filesize, timestamp=$timestamp, time_created=$time_created, md5='$md5', file_format=$file_format, developer='SHOTWELL', develop_camera_id=-1 WHERE filename = '$img';"

            # remove backing photo
            sqlite3 $DB "DELETE FROM BackingPhotoTable WHERE id=$devcamid;"

            mv "$img" .

           (( COUNT++ ))
        fi
    fi

done

unset IFS

echo "DONE: $COUNT CR2 photos removed"

