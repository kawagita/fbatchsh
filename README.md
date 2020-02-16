fbatchsh
========

These shell scripts are batch utility for files or directories. Directory name is specified on the last of a command line. All items are targeted in that directory but its can be selected by name which matches the pattern with `-T`. And, subdirectories are traversed with `-R`. If an error occurred, this reverses all changes in directory and stops traversing but it can be resumed with `-S`. See the more information with `--help`.

#### chfname

`chfname.sh` is a converter of file and directory names. Changing a text by sed expression, adding the string by date format or sequential number, and capitalization by the regular expression of awk script is possible.

#### chftime

`chftime.sh` is a converter of file and directory times. Changing the access or modification time by a specific time or relative date string, and setting the parent time to the most recently modified fileor subdirectory is possible.

## License

This program is published under GPL v2.0.

