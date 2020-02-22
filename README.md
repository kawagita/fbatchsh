fbatchsh
========

These shell scripts are batch utility for files or directories. Directory name is specified on the last of command line. All entries are targeted in that directory but its can be selected by name which matches the extended regular expression with `-T`. And, subdirectories are traversed with `-R`. If an error occurred, these scripts reverse all changes in directory and stop traversing but it can be resumed with `-S` later. See the more information with `--help`.

#### chfname

`chfname.sh` is a converter of file and directory names. Changing a text by sed expression, adding the string by date format or sequential number, and capitalization by the regular expression of awk script is provided.

#### chftime

`chftime.sh` is a converter of file and directory times. Changing the modification or access time by a specific time or relative date string, and setting the parent time to the most recently modified file or subdirectory is provided.

#### lsftime

`lsftime.sh` is a script to list the time information of directory contents. Displaying the modification, access, status change, or birth (if possible) time between a specific interval is provided.

## License

This program is published under GPL v2.0.

