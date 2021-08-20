# Shotwell Photo Organizer

A collection of scripts that implement batch processing functions for features which are not available in Shotwell

* remove raw CR2 files for photos with low rating
* rename photo directories to include the name of the event in Shotwell

## Setup

### Install Shotwell via Flatpack

* Default: https://flathub.org/apps/details/org.gnome.Shotwell
* With an [alternative database path](http://shotwell-project.org/doc/html/other-multiple.html)
    * `/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=shotwell --filesystem=home --file-forwarding org.gnome.Shotwell @@u %U @@ -d ~/.shotwell_canon`

### Script Installation

...

## Helpful Tricks

### Organize Photos in Subdirectories by Date

```exiftool -d "%Y-%m-%d" "-directory<DateTimeOriginal" *.{JPG,CR2}```

## List Photos with low Shotwell Rating (1-3) in current folder

`sqlite3 ~/.shotwell/data/photo.db "SELECT filename FROM PhotoTable WHERE filename LIKE '$(pwd)%' AND rating in (1,2,3);"`
