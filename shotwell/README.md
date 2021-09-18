# Shotwell Photo Organizer

A collection of scripts that implement batch processing functions for features which are not available in Shotwell

* remove raw CR2 files for photos with low rating
* rename photo directories to include the name of the event in Shotwell

## Setup

### Install Shotwell via Flatpack

* Default: https://flathub.org/apps/details/org.gnome.Shotwell
* With an [alternative database path](http://shotwell-project.org/doc/html/other-multiple.html)
    * add `-d <path>` to flatpack shotwell command: `/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=shotwell --filesystem=home --file-forwarding org.gnome.Shotwell @@u %U @@ -d ~/.shotwell_2`

### Script Installation

...

## Helpful Tricks

### Organize Photos in Subdirectories by Date

```exiftool -d "%Y-%m-%d" "-directory<DateTimeOriginal" *.{JPG,CR2}```

### List Photos with low Shotwell Rating (1-3) in current folder

`sqlite3 ~/.shotwell/data/photo.db "SELECT filename FROM PhotoTable WHERE filename LIKE '$(pwd)%' AND rating in (1,2,3);"`

### Get First and Last Date of Photos in Shotwell Database

`sqlite3 ~/.shotwell/data/photo.db "SELECT min(Date(timestamp, 'unixepoch')), max(Date(timestamp, 'unixepoch')) FROM PhotoTable LIMIT 10;"`

## FAQ

* https://wiki.gnome.org/Apps/Shotwell/FAQ
* https://askubuntu.com/questions/111290/how-can-i-export-my-shotwell-gallery

### I just imported a RAW photo into Shotwell and it looks overexposed or underexposed, why is this and how can I fix it?

> Shotwell renders RAW images by picking some default tone mapping curves that work in most cases, but not all. If you shoot RAW+JPEG or even just plain RAW, your camera probably produces its own JPEG development of your RAW photo at exposure time, either as an associated JPEG file (in the RAW+JPEG case) or embedded in the RAW file itself (in the plain RAW) case. Since your camera presumably knows more about its CCD and the lighting conditions under which your photo was taken than Shotwell does, it’s development will likely look better than Shotwell’s. To switch your RAW Developer to your camera, if available, open the image you want to work with in single-photo mode by double-clicking on it. Then, under the “Developer” submenu of the “Photo” menu choose “Camera.” Due to a known issue with Shotwell 0.11.x and 0.12.x, if “Camera” is already selected you might have to first switch the developer to “Shotwell” and then back to “Camera” again to force the change to take effect. 

## Miscellaneous

```
sqlite> .schema PhotoTable
CREATE TABLE PhotoTable (
    id INTEGER PRIMARY KEY,
    filename TEXT UNIQUE NOT NULL,
    width INTEGER,
    height INTEGER,
    filesize INTEGER,
    timestamp INTEGER,
    exposure_time INTEGER,
    orientation INTEGER,
    original_orientation INTEGER,
    import_id INTEGER,
    event_id INTEGER,
    transformations TEXT,
    md5 TEXT,
    thumbnail_md5 TEXT,
    exif_md5 TEXT,
    time_created INTEGER,
    flags INTEGER DEFAULT 0,
    rating INTEGER DEFAULT 0,
    file_format INTEGER DEFAULT 0,
    title TEXT,
    backlinks TEXT,
    time_reimported INTEGER,
    editable_id INTEGER DEFAULT -1,
    metadata_dirty INTEGER DEFAULT 0,
    developer TEXT,
    develop_shotwell_id INTEGER DEFAULT -1,
    develop_camera_id INTEGER DEFAULT -1,
    develop_embedded_id INTEGER DEFAULT -1,
    comment TEXT);
```
