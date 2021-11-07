#!/bin/bash

# Rename the specified directory with images using the shotwell folder name.

# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/

function usage {
        echo "Usage: $(basename $0) <options> <directory>" 2>&1
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

while getopts "d:r:vth" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    r)  rating=$OPTARG  # shotwell image rating
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


# first regular parameter is directory
dir=$1; shift

realdir=$(realpath "$dir")

# check if directory exists
[ ! -d "$realdir/" ] && echo "Dir does not exist! - '$realdir'" && exit 1

echo "TARGET PATH: '$realdir'"


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

# ------------------


# get all event names
event_names=$(sqlite3 $DB "SELECT DISTINCT name FROM PhotoTable pt JOIN EventTable et ON pt.event_id = et.id WHERE filename LIKE '$(sql_safe "$realdir")%' AND name is not NULL;")

# SQL result may contain SPACE - don't split
IFS=$'\n'

COUNT=0
COUNT_BACKING=0

for e in $event_names; do

    if [ "$verbose" -ne "0" ];then
        echo "PROCESSING EVENT: '$e'"
    fi

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

    if [ "$verbose" -ne "0" ];then
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

    if [ "$dryrun" -eq "0" ];then
        mkdir -p "$newdir"
    fi

    # get images for event and update database entry
    for img in $(sqlite3 $DB "SELECT filename FROM PhotoTable pt JOIN EventTable et ON pt.event_id = et.id WHERE filename LIKE '$(sql_safe "$realdir")%' AND name = '$(sql_safe "$e")' ORDER BY filename;"); do
        file=${img##*/}
        new_img="$newdir/$file"

        if [ "$verbose" -ne "0" ];then
            echo "PROCESSING '$img'"
        fi

        if [ "$dryrun" -eq "0" ];then
            # move the file
            mv "$img" "$new_img"

            # first update filename in backing table if there is a developed image version
            img_bk=$(sqlite3 $DB "SELECT filepath FROM BackingPhotoTable bpt JOIN PhotoTable pt ON bpt.id = pt.develop_camera_id WHERE filename = '$(sql_safe "$img")'";)
            if [ ! -z "$img_bk" ]; then
                file_bk=${img_bk##*/}
                new_img_bk="$newdir/$file_bk"

                # finally move the file
                mv "$img_bk" "$new_img_bk"

                sqlite3 $DB "UPDATE BackingPhotoTable SET filepath='$(sql_safe "$new_img_bk")' WHERE filepath = '$(sql_safe "$img_bk")';"
                (( COUNT_BACKING++ ))

                if [ "$verbose" -ne "0" ];then
                    echo "B=> $new_img_bk"
                fi
            fi

            # then update filename in photo table
            sqlite3 $DB "UPDATE PhotoTable SET filename='$(sql_safe "$new_img")' WHERE filename = '$(sql_safe "$img")';"
            (( COUNT++ ))
        fi

        if [ "$verbose" -gt "1" ];then
            echo "--> '$new_img'"
        fi

    done

done

# Now do the same for the videos

# get all event names
event_names=$(sqlite3 $DB "SELECT DISTINCT name FROM VideoTable vt JOIN EventTable et ON vt.event_id = et.id WHERE filename LIKE '$(sql_safe "$realdir")%' AND name is not NULL;")

for e in $event_names; do

    if [ "$verbose" -ne "0" ];then
        echo "PROCESSING (VIDEO) EVENT: '$e'"
    fi

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

    if [ "$verbose" -ne "0" ];then
        echo "NEW: $newdir"
    fi

    if [ "$dryrun" -eq "0" ];then
        mkdir -p "$newdir"
    fi

    # get videos for event and update database entry
    for vid in $(sqlite3 $DB "SELECT filename FROM VideoTable vt JOIN EventTable et ON vt.event_id = et.id WHERE filename LIKE '$(sql_safe "$realdir")%' AND name = '$(sql_safe "$e")' ORDER BY filename;"); do
        file=${vid##*/}
        new_vid="$newdir/$file"

        if [ "$verbose" -ne "0" ];then
            echo "PROCESSING '$vid'"
        fi

        if [ "$dryrun" -eq "0" ];then
            # move the file
            mv "$vid" "$new_vid"

            # then update filename in photo table
            sqlite3 $DB "UPDATE VideoTable SET filename='$(sql_safe "$new_vid")' WHERE filename = '$(sql_safe "$vid")';"
            (( COUNT++ ))
        fi

        if [ "$verbose" -gt "1" ];then
            echo "--> '$new_vid'"
        fi

    done

done


unset IFS

echo "DONE: $COUNT photos/videos updated (+$COUNT_BACKING backing photos)"

