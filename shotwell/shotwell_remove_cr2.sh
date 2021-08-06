#!/bin/bash

# Remove CR2 images for images with a low rating.
# Will only be applied for images with CR2 and JPG file with the same name.
# image entry in shotwell database will be updated from CR2->JPG.


# shotwell database to use (env variable)
DB=$DB_SHOTWELL

# default rating is 3
rating=3

verbose=0


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "r:d:v" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    r)  rating=$OPTARG  # shotwell image rating
        ;;
    v)  verbose=1
        ;;
    esac
done

shift $((OPTIND-1))


echo "using max image rating $rating"

for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable WHERE filename LIKE '$(pwd)%' AND filename LIKE '%.CR2' AND rating > 0 AND rating <= $rating ORDER BY 1";); do

    JPG=${img/%.CR2/.JPG}
    if [ ! -f $JPG ];then
        echo "no JPG file for $img"
    else

        SIZE=$(identify -format "%w %h\n" "$JPG")
        WIDTH=${SIZE% *}
        HEIGHT=${SIZE#* }
        MD5=$(md5sum "$JPG")
        MD5=${MD5%% *}
        FILESIZE=$(du -b "$JPG" | cut -f1)
        
        echo UPDATING... $JPG

        if [ "$verbose" -eq "1" ];then
            echo \> $WIDTH, $HEIGHT, $FILESIZE, $MD5
        fi

        sqlite3 $DB "UPDATE PhotoTable SET filename='$JPG', width=$WIDTH, height=$HEIGHT, filesize=$FILESIZE, md5='$MD5', file_format=0, developer='SHOTWELL', develop_camera_id=-1 WHERE filename = '$img';"
        mv "$img" ..
    fi

done

