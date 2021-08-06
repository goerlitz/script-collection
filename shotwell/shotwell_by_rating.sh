#!/bin/bash

# get images in local folder with specified rating
#
# * all images with rating (default)
# * all images with min rating (-r 5)
# * all images with max rating (-r 4 -a)
# * all images without rating (-r 0)
# default: all images with a rating (ignore images without rating)


# shotwell database to use (env variable)
DB=$DB_SHOTWELL

# default is min=1
rating=1
above=1

# parse options
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "r:d:a" opt; do
    case "$opt" in
    d)  DB=$OPTARG      # shotwell database
        ;;
    r)  rating=$OPTARG  # shotwell image rating
        ;;
    a)  above=0  # shotwell min or max rating?
        ;;
    esac
done

shift $((OPTIND-1))


# query images

if [ "$rating" -eq "0" ]
then
    sqlite3 $DB "SELECT filename, rating FROM PhotoTable WHERE filename LIKE '$(pwd)%' AND rating = 0";
else
    if [ "$above" -eq "0" ]
    then
        sqlite3 $DB "SELECT filename, rating FROM PhotoTable WHERE filename LIKE '$(pwd)%' AND rating > 0 AND rating <= $rating";
    else
        sqlite3 $DB "SELECT filename, rating FROM PhotoTable WHERE filename LIKE '$(pwd)%' AND rating >= $rating";
    fi
fi

