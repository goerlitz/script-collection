# Shotwell Photo Organizer

Shotwell is a great tool for organizing a large personal photo collection. However, when managing JPG+CR2 photos, things can get complicated.

Some useful operations can only be achieved by directly modifying the entries in the Shotwell database, e.g.

- for JPG+CR2 photos with low rating, remove the CR2 file but keep the JPG file
- rename folders on disk to match the event name in Shotwell
- move a photo directory to a different location (a bug in Shotwell messes up the CR2 images)

This script collection implements the above points as batch processing functions. All off them modify the Shotwell database. Use with care and always make a backup of your database file.

Similar tools:

- <https://github.com/fdlm/shotwell-db-org> "reorganise shotwell's photo directory structure"
- <https://github.com/emil-genov/shotwell-export>

## Setup

### Install Shotwell via Flatpack

- Default: <https://flathub.org/apps/details/org.gnome.Shotwell>
- With an [alternative database path](http://shotwell-project.org/doc/html/other-multiple.html)
  - add `-d <path>` to flatpack shotwell command: `/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=shotwell --filesystem=home --file-forwarding org.gnome.Shotwell @@u %U @@ -d ~/.shotwell_2`

### Script Installation

- Link a script directly into the system bin folder
  `sudo ln -s script-collection/shotwell/shotwell_rename_folder.sh /usr/bin/shotwell_rename_folder.sh`
- Set environment variable with path to Shotwell DB
  `export SHOTWELL_DB=<file_path>`

## Workflow

- Copy/import photos from camera (usually all in one folder)
- Move photos into directories based on date photos were taken
  `exiftool -d "%Y-%m-%d" "-directory<DateTimeOriginal" *.{JPG,CR2}`
- Import photos in Shotwell
- Organize date-based events (split, merge) and give them labels
- Apply ratings to photos
- Delete CR2 files for photos with max rating of 3
  `shotwell_remove_cr2.sh -r 3 <directory>`
- Rename folders
  `shotwell_rename_folder.sh <directory>`
- Copy foder to a different location
- Update location of photos to match new folder
  `shotwell_move_folder.sh old_directory new_directory`

## Helpful Tricks

- List Photos with low Shotwell Rating (1-3) in current folder

  `sqlite3 ~/.shotwell/data/photo.db "SELECT filename FROM PhotoTable WHERE filename LIKE '$(pwd)%' AND rating in (1,2,3);"`

- Get First and Last Date of Photos in Shotwell Database

  `sqlite3 ~/.shotwell/data/photo.db "SELECT min(Date(timestamp, 'unixepoch')), max(Date(timestamp, 'unixepoch')) FROM PhotoTable LIMIT 10;"`

### Copy photos and videos from one database to one other

    attach '/home/.../data/photo.db' as db2;

    # copy events
    INSERT INTO EventTable (name, primary_photo_id, time_created, primary_source_id, comment) SELECT name, primary_photo_id, time_created, primary_source_id, comment FROM db2.EventTable WHERE name NOT IN (SELECT name from EventTable);

    # copy videos with updated event reference
    INSERT INTO VideoTable (filename, width, height, clip_duration, is_interpretable, filesize, timestamp, exposure_time, import_id, event_id, md5, time_created, rating, title, backlinks, time_reimported, flags, comment) SELECT filename, width, height, clip_duration, is_interpretable, filesize, timestamp, exposure_time, import_id, et.id, md5, vt2.time_created, rating, title, backlinks, time_reimported, flags, vt2.comment FROM db2.VideoTable vt2 JOIN db2.EventTable et2 ON vt2.event_id = et2.id JOIN EventTable et ON et.name = et2.name;

    # copy photos with updated event reference
    INSERT INTO PhotoTable (filename, width, height, filesize, timestamp, exposure_time, orientation, original_orientation, import_id, event_id, transformations, md5, thumbnail_md5, exif_md5, time_created, flags, rating, file_format, title, backlinks, time_reimported, editable_id, metadata_dirty, developer, develop_shotwell_id, develop_camera_id, develop_embedded_id, comment) SELECT filename, width, height, filesize, timestamp, exposure_time, orientation, original_orientation, import_id, et.id, transformations, md5, thumbnail_md5, exif_md5, pt2.time_created, flags, rating, file_format, title, backlinks, time_reimported, editable_id, metadata_dirty, developer, develop_shotwell_id, develop_camera_id, develop_embedded_id, pt2.comment FROM db2.PhotoTable pt2 JOIN db2.EventTable et2 ON pt2.event_id = et2.id JOIN EventTable et ON et.name = et2.name;

## FAQ

- <https://wiki.gnome.org/Apps/Shotwell/FAQ>
- <https://askubuntu.com/questions/111290/how-can-i-export-my-shotwell-gallery>

### I just imported a RAW photo into Shotwell and it looks overexposed or underexposed, why is this and how can I fix it?

> Shotwell renders RAW images by picking some default tone mapping curves that work in most cases, but not all. If you shoot RAW+JPEG or even just plain RAW, your camera probably produces its own JPEG development of your RAW photo at exposure time, either as an associated JPEG file (in the RAW+JPEG case) or embedded in the RAW file itself (in the plain RAW) case. Since your camera presumably knows more about its CCD and the lighting conditions under which your photo was taken than Shotwell does, it’s development will likely look better than Shotwell’s. To switch your RAW Developer to your camera, if available, open the image you want to work with in single-photo mode by double-clicking on it. Then, under the “Developer” submenu of the “Photo” menu choose “Camera.” Due to a known issue with Shotwell 0.11.x and 0.12.x, if “Camera” is already selected you might have to first switch the developer to “Shotwell” and then back to “Camera” again to force the change to take effect.

## Miscellaneous

### Database path when using Flatpack

`~/.var/app/org.gnome.Shotwell/data/shotwell/data/photo.db`

### Merging two SQLite Databases

<https://stackoverflow.com/questions/19968847/merging-two-sqlite-databases-which-both-have-junction-tables>

### Photo Table Schema

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

    CREATE TABLE VideoTable (
        id INTEGER PRIMARY KEY,
        filename TEXT UNIQUE NOT NULL,
        width INTEGER, height INTEGER,
        clip_duration REAL,
        is_interpretable INTEGER,
        filesize INTEGER,
        timestamp INTEGER,
        exposure_time INTEGER,
        import_id INTEGER,
        event_id INTEGER,
        md5 TEXT,
        time_created INTEGER,
        rating INTEGER DEFAULT 0,
        title TEXT,
        backlinks TEXT,
        time_reimported INTEGER,
        flags INTEGER DEFAULT 0,
        comment TEXT );
    CREATE INDEX VideoEventIDIndex ON VideoTable (event_id);

    CREATE TABLE EventTable (
        id INTEGER PRIMARY KEY,
        name TEXT,
        primary_photo_id INTEGER,
        time_created INTEGER,
        primary_source_id TEXT,
        comment TEXT);

### Shotwell Alternatives

- <https://www.digikam.org/>
- <https://www.xnview.com/en/xnviewmp/>
