#!/bin/sh
#
# Change the name of files and subdirectories.
# Copyright (C) 2020 Yoshinori Kawagita.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

PACKAGE='fbatchsh'
PROGRAM='chfname'
VERSION='1.0'

unalias -a

AWKSTDOUT='/dev/tty'
AWKSTDERR='/dev/tty'
AWKUSEHEXEXPR=0
AWKCAPITALIZED=0

FILEUPPERCASE='A-Z'
FILELOWERCASE='a-z'
FILECASESENSITIVE=1

if awk 'BEGIN { print > "/dev/stderr" }' 2> /dev/null; then
  AWKSTDOUT='/dev/stdout'
  AWKSTDERR='/dev/stderr'
fi
if awk 'BEGIN { if ("!" !~ /\x21/) { exit 1; } }' 2> /dev/null; then
  AWKUSEHEXEXPR=1
  if awk -b 'BEGIN { }' 2>&1 | awk '$0 != "" { exit 1 }'; then
    alias awk='awk -b'
  fi
fi
if awk 'BEGIN { toupper(""); tolower("") }' 2> /dev/null; then
  AWKCAPITALIZED=1
  if which cygpath > /dev/null 2>&1 || \
     which wslpath > /dev/null 2>&1; then
    FILECASESENSITIVE=0
  fi
fi

FIELDSEPARATOR=','

DATEREFTIME=0

if date -r / > /dev/null 2>&1; then
  DATEREFTIME=1
fi

STATREFTIME=0
STAT=""
STATTIMEFORMAT=""
STATTIMESTYLEOPTION=' -t'
STATTIMESTYLEFORMAT='%s'
STATFILTER=""
STATTIMEFILTER=""
STATNOTIMEFILTER=""

if stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' / > /dev/null 2>&1; then
  STATREFTIME=1
  STAT="stat -f '%Sp %6Du %6Dg$FIELDSEPARATOR'"
  STATTIMEFORMAT='%Sm'
fi

LSREFTIME=0
LS='ls -fdnql'
LSTIMESTYLEOPTION=' --time-style'
LSTIMESTYLEFORMAT='+%s%%t'
LSFILTER=" | sed -e 's/[1-9][0-9]*//' -e 's/[0-9][0-9]* /$FIELDSEPARATOR/3'"
LSTIMEFILTER=" -e 's/\\\\t.*$//' -e 's/  *//3'"
LSNOTIMEFILTER=" -e 's/ *$FIELDSEPARATOR.*$/$FIELDSEPARATOR/'"

if ls --time-style '+%Y-%m-%dT%H:%M:%S' / > /dev/null 2>&1; then
  LSREFTIME=1
fi

if [ ${FBATCHSHDEBUG:-0} -ge 2 ]; then
  STATREFTIME=0
  if [ ${FBATCHSHDEBUG:-0} -ge 3 ]; then
    LSREFTIME=0
  fi
fi

if [ $STATREFTIME != 0 ]; then
  LSREFTIME=0
  DATEREFTIME=0
else
  if [ $LSREFTIME != 0 ]; then
    DATEREFTIME=0
    STATTIMESTYLEOPTION=$LSTIMESTYLEOPTION
    STATTIMESTYLEFORMAT=$LSTIMESTYLEFORMAT
  fi
  STAT=$LS
  STATFILTER=$LSFILTER
  STATTIMEFILTER=$LSTIMEFILTER
  STATNOTIMEFILTER=$LSNOTIMEFILTER
fi

# Print the usage
#
# $1 - the exit status
# exit with the status

usage(){
  if [ $1 != 0 ]; then
    echo "Try \`$PROGRAM --help' for more information." 1>&2
    exit $1
  fi
  echo "Usage: $PROGRAM [OPTION] [DIR...]"
  echo 'Set the name of files and subdirectories in each DIR(s) by Unix commands.'
  echo 'If no DIR, change in the current directory.'
  echo
  echo '  -A, --almost-all           do not change implied . and ..'
  echo '  -c, --no-change            do not change any files or subdirectories'
  if [ $AWKCAPITALIZED != 0 ]; then
    echo '      --capitalize=REGEX     capitalize all matches of REGEX'
  fi
  if [ $STATREFTIME != 0 -o $LSREFTIME != 0 -o $DATEREFTIME != 0 ]; then
    echo '  -d FORMAT                  append date string with FORMAT to file name'
  fi
  echo '  -f                         change the name of only regular files'
  echo '  -F, --classify             show file or directory indicator (one of */@)'
  echo '  -h                         change the name of symbolic links'
  echo '  -i, --interactive          prompt before change in each directory'
  echo '  -I, --ignore-extension     ignore file extension when the name is changed'
  echo '  -l, --link                 follow the symbolic link (with -R)'
  echo '  -n  FORMAT                 append number string with FORMAT to file name'
  echo '  -N                         set sequential number for the same name (with -n)'
  echo '      --number-start=NUM     start adding number string from NUM instead of 1'
  if [ $STATREFTIME != 0 -o $LSREFTIME != 0 -o $DATEREFTIME != 0 ]; then
    echo '  -p EXPRESSION              use EXPRESSION after adding date or number string'
  else
    echo '  -p EXPRESSION              use EXPRESSION after adding number string'
  fi
  echo '      --quiet                do not list targets in each directory'
  echo '  -R, --recursive            change the name in directories recursively'
  echo '  -s EXPRESSION              use EXPRESSION to replace file name'
  echo '  -S, --resume-from=PATH     resume traversing directories from PATH'
  echo "      --skip-error           skip target's error in directory"
  echo '  -T REGEX                   target directory entries whose names match REGEX'
  echo '      --to-lowercase         convert whole name to lowercase'
  echo '      --to-uppercase         convert whole name to uppercase'
  if [ $STATREFTIME != 0 -o $LSREFTIME != 0 -o $DATEREFTIME != 0 ]; then
    echo '      --utc                  set date string as UTC time zone (with -d)'
  fi
  echo '  -v, --verbose              print subdirectories without target'
  echo '  -y EXPRESSION              use EXPRESSION to translate file name characters'
  echo '      --help                 display this help and exit'
  echo '      --version              output version information and exit'
  echo
  echo 'REGEXs are the regular expression of awk script. EXPRESSIONs are a pattern and'
  echo 'replacement delimited by the same three characters (usually slashes) with flags'
  echo 'which used by the substitution of sed script.'
  echo
  if [ $STATREFTIME != 0 -o $LSREFTIME != 0 -o $DATEREFTIME != 0 ]; then
    echo '-d or -n option accept FORMAT of date or printf command. These strings include'
    echo '% followed by a character to output time elements or a number. In details, see'
    echo 'the manual.'
  else
    echo '-n option accept FORMAT of printf command. These string includes % followed by'
    echo 'a character to output a number. In details, see the manual.'
  fi
  exit 0
}

# Print the version
#
# exit with zero

version(){
  echo "$PROGRAM ($PACKAGE) $VERSION"
  echo 'Copyright (C) 2020 Yoshinori Kawagita.'
  echo 'This is free software; see the source for copying conditions.'
  echo 'There is NO warranty; not even for MERCHANTABILITY or FITNESS'
  echo 'FOR A PARTICULAR PURPOSE.'
  exit 0
}

# Print the error message
#
# $1 - the error status
# $2 - an error message
# exit with the status if non-zero

error(){
  printf '%s\n' "$PROGRAM: $2" 1>&2
  if [ $1 != 0 ]; then
    exit $1
  fi
}

# Parse parameters as the option, argument, and others
#
# $1 - the string of option characters
# $2 - the string of long options separated by commas
# $* - parameters which were given to the program
# print the option and argument separated by '=' and others,
# remove '-' and "--" from the head of all options,
# add '?' to the head of unknown options,
# add '-' to the head of option which needs an argument,
# add '+' to the head of option which has more argument,
# and print "--" between the last option and others

getopt(){
  export LC_CTYPE=C
  (printf '%s\0,%s,\0' "$1" "$2"
   shift 2
   printf '%s\0' "$@" --) | \
  tr '\n\0' '\0\n' | \
  sed '1 {
         s/[^0-9A-Za-z:]:*//g
         N
         s/\n//
         x
         d
       }
       x
       /^--$/! {
         x
         /^--$/ {
           h
           b
         }
         /^-./ {
           G
           s/^--\([0-9A-Za-z][-0-9A-Za-z]*\)\n.*,\1:,.*/-\1/; t SETARG
           /^--\([0-9A-Za-z][-0-9A-Za-z]*\)=.*\n.*,\1:,/b OPTARG
           s/^--\([0-9A-Za-z][-0-9A-Za-z]*\)\n.*,\1,.*/\1/; t
           s/^--\([0-9A-Za-z][-0-9A-Za-z]*\)=.*\n.*,\1,.*/+\1/; t
           s/^--/?/; t SETARG
           s/^-//
         :OPTSTR
           /^\n/! {
             /^.\n /! {
               s/^./&\
 /; t OPTSTR
             }
             s/^\([0-9A-Za-z]\)\n \n[0-9A-Za-z:]*\1:.*/-\1/; t SETARG
             /^\([0-9A-Za-z]\).*\n[0-9A-Za-z:]*\1:/ {
               s/\n /=/; t OPTARG
             }
             /^\([0-9A-Za-z]\).*\n[0-9A-Za-z:]*\1/! {
               s/^'\''/?\\&/; t OPTCHAR
               s/^.\n/'\''&/
               s/\n/'\''&/
               s/^/?/
             }
           :OPTCHAR
             P
             s/^.*\n //; t OPTSTR
           }
           d
         :OPTARG
           s/^--//
         :SETARG
           s/\n.*//
           /^-/ {
             N
             $b
             s/^-//
             s/\n/=/
           }
           b QUOTE
         }
         x
         s/.*/--/
         p
       }
       $d
       x
       s/^/ /
     :QUOTE
       s/'\''/'\'\\\\\'\''/g
       s/[ =?]/&'\''/
       s/$/'\''/
       s/^ //' | \
  tr '\0\n' '\n '
}

# Compare the specified two string
#
# $1 - the first string
# $2 - the second string
# exit 0 if the first string is equal to the second, otherwise, 1

cmpstr() {
#  printf "%s\0" "$1" "$2" | \
#  tr '\0\n' '\n\0' | \
#  sed 'N
#       s/^\(.*\)\n\1\/.*$/0/; t
#       s/^.*$/1/' | \
#  awk '{ exit $0 }'
  awk '
    BEGIN {
      if (ARGV[1] != ARGV[2]) {
        exit 1;
      }
    }' "$1" "$2"
}

# Traverse the directory recursively
#
# $1 - the count of traversing directories
# $2 - the pathname of root directory to traverse subdirectories
# process the target in each directory by dirmain function with 0,
# move to subdirectories matching with the specified pattern and
# to the parent directory after calling dirmain function with 1,
# and return 1 or 2 if can't start or fail the traversal, otherwise, 0

travstartpath=""
travsubdirs=""
travlinkfollowed=0

dirtrav(){
  (count=$1
   if [ -n "$2" ]; then
     if ! cd -L -- "$2" 2> /dev/null; then
       exit 1
     fi
     path=${2%/}/
   else
     path='./'
   fi
   if [ -n "$travsubdirs" ] && \
      ! cmpstr "$(pwd -L)" "$travstartpath"; then
     startpath="$travstartpath"
   fi
   depth=0
   set -- "$path"

   while true
   do
     if [ -z "$startpath" ] && ! dirmain 0; then
       exit 2
     fi
     shift
     set -- $travsubdirs / "$@"

     while true
     do
       if [ "$1" = '/' ]; then
         if [ -z "$startpath" ] && ! dirmain 1; then
           exit 2
         fi
         path=/$path
         path=${path%/*/}/
         path=${path#/}
         depth=$(($depth - 1))
         if [ $# = 1 ]; then
           exit 0
         fi
         cd -L ..
       elif [ "$1" != './' -a "$1" != '../' ]; then
         if [ ! -h "${1%/}" ] || \
            ([ $travlinkfollowed != 0 ] && \
             cd -- "$1" 2> /dev/null && \
             ! cmpstr "$(pwd -L)" "$(pwd -P)"); then
           if cd -- "$1" 2> /dev/null; then
             path=$path$1
             if cmpstr "$(pwd -L)" "$startpath"; then
               startpath=""
             fi
             depth=$(($depth + 1))
             break
           fi
         fi
       fi
       shift
     done
   done)

  return $?
}

# Code points of Unicode characters formatted as full width
#
# 00A7..00A8   Latin-1 Supplement (SECTION SIGN..DIAERESIS,
# 00B0..00B1    DEGREE SIGN..PLUS-MINUS SIGN,
# 00B4          ACUTE ACCENT,
# 00B6          PILCROW SIGN,
# 00D7          MULTIPLICATION SIGN,
# 00F7          DIVISION SIGN)
# 2010         General Punctuation (HYPHEN,
# 2014..2016    EM DASH..DOUBLE VERTICAL LINE,
# 2018..2019    LEFT SINGLE QUOTATION MARK..RIGHT SINGLE QUOTATION MARK,
# 201C..201D    LEFT DOUBLE QUOTATION MARK..RIGHT DOUBLE QUOTATION MARK,
# 2020..2021    DAGGER..DOUBLE DAGGER,
# 2025..2026    TWO DOT LEADER..THREE DOT LEADER,
# 2030          PER MILLE SIGN,
# 2032..2033    PRIME..DOUBLE PRIME,
# 203B          REFERENCE MARK)
# 2100..22FF   Letterlike Symbols, Number Forms, Arrows, Mathematical Operators
# 2460..24FF   Enclosed Alphanumerics
# 25A0..27FF   Box Drawing, Miscellaneous Symbols, Supplemental Arrows-A
# 2E80..A4CF   CJK Radicals Supplement, Kangxi Radicals,
#              Ideographic Description Characters, CJK Symbols and Punctuation,
#              Hiragana, Katakana, Bopomofo, Hangul Compatibility Jamo, Kanbun,
#              Bopomofo Extended, CJK Strokes, Katakana Phonetic Extensions,
#              Enclosed CJK Letters and Months, CJK Compatibility,
#              CJK Unified Ideographs Extension A, Yijing Hexagram Symbols,
#              CJK Unified Ideographs, Yi Syllables, Yi Radicals
# AC00..D7AF   Hangul Syllables
# FF01..FF60   Halfwidth and Fullwidth Forms
#               (FULLWIDTH EXCLAMATION MARK..FULLWIDTH RIGHT WHITE PARENTHESIS)
# FFE0..FFE6   Halfwidth and Fullwidth Forms
#               (FULLWIDTH CENT SIGN..FULLWIDTH WON SIGN)
# F900..FAFF   CJK Compatibility Ideographs
# 1B000..1B2FF Kana Supplement, Kana Extended-A, Small Kana Extension, Nushu

LOCALECTYPE=$(locale | awk 'sub(/^LC_CTYPE="?/, "") { sub(/"$/, ""); print }')
LOCALEUTF8=0
LOCALEEASTASIAN=0

if echo $LOCALECTYPE | awk '$0 !~ /\.(UTF|utf)-?8/ { exit 1 }'; then
  LOCALEUTF8=1
  if echo $LOCALECTYPE | awk '$0 !~ /^(ja|ko|zh)_/ { exit 1 }'; then
    LOCALEEASTASIAN=1
  fi
fi

# Process target files or subdirectories in the directory
#
# $1 - 0 or 1 if called at the start or end of traversing subdirectories
# $count - the count of the current traversing
# $path - the pathname to the current directory
# $depth - the depth of the current directory from the root of traversing
# return non-zero if can't process the target, otherwise, zero

targetentries="*"
targetregex=""
targetnochange=0
targetprompt=0
targetverbose=0
targetquiet=0
targetdot=0
targetdir=1
targetsymlink=0
targetclassify=0
extignored=0
subexpr=""
postexpr=""
trexpr=""
trlf='\n'
fromcase="";
tocase="";
capsregex=""
datefmt=""
dateutc=0
numfmt=""
numstart=0
numsamename=0
userid=$(id -u)
groupid=$(id -g)
termcols=$(tput cols)
errstopped=1

dirmain(){
  case $1 in
  0)
    set -- $targetentries
    awk -v dircount=$count -v dirdepth=$depth -v targetregex="$targetregex" \
        -v subexpr="$subexpr" -v postexpr="$postexpr" -v trexpr="$trexpr" \
        -v fromcase="$fromcase" -v tocase="$tocase" -v capsregex="$capsregex" \
        -v datefmt="$datefmt" -v numfmt="$numfmt" -v numstart=$numstart \
        -v userid=$userid -v groupid=$groupid -v maxdispwidth=${termcols:-80} \
        -v devout=$AWKSTDOUT -v deverr=$AWKSTDERR '
      function dispwidth(s, len) {
        sub(/.*\n/, "", s);
        if ('$LOCALEUTF8' && '$AWKUSEHEXEXPR') {
          if ('$LOCALEEASTASIAN') {
            len += (gsub(/\xC2[\xA7\xA8\xB0\xB1\xB4\xB6]|\xC3[\x97\xB7]/, "", s) \
                    + gsub(/\xE2\x80[\x90\x94-\x96\x98\x99\x9C\x9D\xA0\xA1\xA5\xA6\xB0\xB2\xB3\xBB]/, "", s) \
                    + gsub(/\xE2[\x84-\x8B\x92\x93\x97-\x9E]./, "", s) \
                    + gsub(/\xE2[\x91\x96][\xA0-\xBF]/, "", s) \
                    + gsub(/\xE2[\xBA-\xBF].|[\xE3-\xE9]../, "", s) \
                    + gsub(/\xEA([\x80-\x92\xB0-\xBF].|\x93[\x80-\x8F])|[\xEB\xEC]../, "", s) \
                    + gsub(/\xED([\x80-\x9D].|\x9E[\x80-\xAF])/, "", s) \
                    + gsub(/\xEF([\xA4-\xAB\xBC].|\xBD[\x81-\xA0]|\xBF[\xA0-\xA6])/, "", s) \
                    + gsub(/\xF0\x9B[\x80-\x8B]./, "", s)) * 2;
          }
          len += gsub(/[\xC2-\xDE\xDF].|[\xE0-\xEF]..|[\xF0-\xF4].../, "", s);
        }
        return len + length(s);
      }
      function disptarget(mark, width, target, name,  str, margin) {
        margin = width - dispwidth(target);
        if (margin < 0) {
          margin = 0;
        }
        gsub(/\n/, "&  ", target);
        str = sprintf("%s %s", mark, target);
        if (name != "") {
          gsub(/\n/, "&" sprintf("  %" width "s    ", ""), name);
          str = str sprintf("%" margin "s -> %s", "", name);
        }
        return str;
      }
      function indexof(array, target,  ind) {
        for (ind in array) {
          if ('$FILECASESENSITIVE') {
            if (array[ind] == target) {
              return ind;
            }
          } else if (tolower(array[ind]) == tolower(target)) {
            return ind;
          }
        }
        return -1;
      }
      function cmdnoerror(cmd) {
        return "(" cmd " 2>&1;echo $?) | sed '\''${ /0/{ x; p; }; }; x; d'\''";
      }
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function getstat(data, statargv, datefmt,  statcmd, tmopt, tmutc, size) {
        if (datefmt != "" && ! '$DATEREFTIME') {
          tmopt = "'"$STATTIMEFORMAT$STATTIMESTYLEOPTION"'" \
                  cmdparam(sprintf("'$STATTIMESTYLEFORMAT'", datefmt));
        }
        if ('$dateutc') {
          tmutc = "TZ= ";
        }
        statcmd = tmutc "'"$STAT"'" tmopt " --" statargv "'"$STATFILTER"'";
        if (tmopt != "") {
          statcmd = statcmd "'"$STATTIMEFILTER"'";
        } else {
          statcmd = statcmd "'"$STATNOTIMEFILTER"'";
        }
        size = 1;
        while (statcmd | getline) {
          data[size++] = $0;
        }
        close(statcmd);
      }
      function getdate(dateargv, datefmt,  datecmd, date) {
        datecmd = "date";
        if ('$dateutc') {
          datecmd = datecmd " -u";
        }
        datecmd = cmdnoerror(datecmd " -r" dateargv cmdparam("+" datefmt));
        datecmd | getline date;
        close(datecmd);
        return date;
      }
      function setname(src, dest, opt) {
        return system("mv" opt " --" cmdparam(src) cmdparam(dest));
      }
      function rename(names, size, repexpr, set1, set2,  repargv, repcmd) {
        while (size > 0) {
          repargv = cmdparam(names[size--]) repargv;
        }
        repcmd = "printf" cmdparam("%s\\0") repargv " | " \
                 "tr" cmdparam("\n\\0") cmdparam("\\0\n");
        if (repexpr != "") {
          repcmd = repcmd " | sed -e " cmdparam("s" repexpr);
        }
        if (set1 != "" && set2 == "") {
          if (repexpr == "") {
            repcmd = repcmd " | sed ";
          }
          repcmd = repcmd " -e " cmdparam("y" set1);
          set1 = "";
        }
        repcmd = repcmd " | tr" cmdparam("/\\0" set1) cmdparam(" /" set2);
        size = 1;
        while (repcmd | getline) {
          sub(/\//, "'"$trlf"'");
          names[size++] = $0;
        }
        close(repcmd);
      }
      function capitalize(name, regex,  rstr) {
        rstr = name;
        name = "";
        do {
          if (! match(rstr, regex) || RLENGTH == 0) {
            return name rstr;
          }
          name = name substr(rstr, 1, RSTART - 1) \
                 toupper(substr(rstr, RSTART, 1)) \
                 tolower(substr(rstr, RSTART + 1, RLENGTH - 1));
          rstr = substr(rstr, RSTART + RLENGTH);
        } while (1);
      }
      BEGIN {
        EXECUTEDMARK = "!";
        CHANGECANDMARK = "+";
        QUESTIONMARK = "?";
        UNCHANGEDMARK = "-";
        ERRORMARK = "E";
        dirpath = ARGV[1];
        if (dircount > 1 || dirdepth > 0) {
          dirbreak = "\n";
        }
        if (system("test -w ./") != 0) {
          if ('$targetverbose') {
            print dirbreak dirpath ":\n0 target" > devout;
          }
          exit 0;
        }
        maxdispwidth = maxdispwidth / 2 - 8;
        if ('$targetquiet') {
          devout = "/dev/null";
        }
        delete ARGV[1];
        fsize = 0;
        for (i = 2; i < ARGC; i++) {
          if (ARGV[i] ~ targetregex && (ARGV[i] != "." && ARGV[i] != "..") && \
              (ARGV[i] != "*" || system("test -e" cmdparam("*")) == 0)) {
            fileindexes[++fsize] = i;
          }
        }
        if ('${FBATCHSHDEBUG:-0}') {
          printf dirbreak > deverr;
        }
        targetwidth = 0;
        targetsize = 0;
        if (fsize > 0) {
          for (i = 1; i <= fsize; i++) {
            fileargv = fileargv cmdparam(ARGV[fileindexes[i]]);
          }
          getstat(fdata, fileargv, datefmt);
          for (i = 1; i <= fsize; i++) {
            fileindex = fileindexes[i];
            fname = ARGV[fileindex];
            delete fileindexes[i];
            if (datefmt != "" && '$DATEREFTIME') {
              fdata[i] = fdata[i] getdate(cmdparam(fname), datefmt);
            }
            if ('${FBATCHSHDEBUG:-0}') {
              printf "%-'${termcols:-80}'s%s\n", fdata[i] "  ", fname > deverr;
            }
            fdataindex = index(fdata[i], "'$FIELDSEPARATOR'");
            split(substr(fdata[i], 1, fdataindex - 1), fileinfo);
            ftype = substr(fileinfo[1], 1, 1);
            fmode = substr(fileinfo[1], 2, 9);
            ftime = substr(fdata[i], fdataindex + 1);
            delete fdata[i];
            indicator = "";
            if (ftype == "d") {
              if (! '$targetdir') {
                continue;
              }
              indicator = "/";
            } else if (ftype == "l") {
              if (! '$targetsymlink' || \
                  (! '$targetdir' && system("test -d" cmdparam(fname)) == 0)) {
                continue;
              }
              indicator = "@";
            } else if (ftype != "-") {
              continue;
            } else if (index(fmode, "x") > 0) {
              indicator = "*";
            }
            targetsize++;
            targetnames[targetsize] = fname;
            targetindicators[targetsize] = indicator;
            targetindexes[targetsize] = fileindex;
            if ('$extignored' && \
                match(fname, /(\.[0-9A-Z_a-z]+)?\.[0-9A-Z_a-z]+$/) && \
                RSTART > 1) {
              convnames[targetsize] = substr(fname, 1, RSTART - 1);
              convexts[targetsize] = substr(fname, RSTART);
            } else {
              convnames[targetsize] = fname;
            }
            if (ftime != "") {
              convdates[targetsize] = ftime;
            }
            if (targetsize > 1) {
              pl = "s";
            }
            if ('$targetclassify') {
              fname = fname indicator;
            }
            width = dispwidth(fname);
            if (targetwidth < width) {
              if (width > maxdispwidth) {
                targetwidth = maxdispwidth;
              } else {
                targetwidth = width;
              }
            }
          }
        }
        if (targetsize == 0 && ! '$targetverbose') {
          exit 0;
        }
        printf dirbreak dirpath ":\n%d target%s\n", targetsize, pl > devout;
        if (subexpr != "" || fromcase != "") {
          rename(convnames, targetsize, subexpr, fromcase, tocase);
        }
        num = numstart;
        for (i = 1; i <= targetsize; i++) {
          convname = capitalize(convnames[i], capsregex);
          if (datefmt != "" && convdates[i] == "") {
            targetmarks[i] = ERRORMARK;
          } else {
            convname = convname convdates[i];
          }
          delete convdate[i];
          if (numfmt != "") {
            if ('$numsamename') {
              num = filenum[convname];
              if (num == "") {
                num = numstart - 1;
              }
              num++;
              filenum[convname] = num;
            } else {
              num++;
            }
            convname = convname sprintf(numfmt, num);
          }
          convnames[i] = convname;
        }
        if (postexpr != "" || trexpr != "") {
          rename(convnames, targetsize, postexpr, trexpr);
        }
        targetstopped = 0;
        targetasked = 0;
        for (i = 1; i <= targetsize; i++) {
          convnames[i] = convnames[i] convexts[i]
          delete convexts[i];
          if (targetmarks[i] != "") {
            targetstopped = '$errstopped';
          } else if (targetnames[i] == convnames[i]) {
            targetmarks[i] = UNCHANGEDMARK;
          } else if ((! '$targetdot' && convnames[i] ~ /^\./) || \
                     indexof(changednames, convnames[i]) > 0 || \
                     indexof(ARGV, convnames[i]) > 0) {
            targetmarks[i] = ERRORMARK;
            targetstopped = '$errstopped';
          } else {
            if ('$targetnochange') {
              targetmarks[i] = CHANGECANDMARK;
            } else if ('$targetprompt') {
              targetmarks[i] = QUESTIONMARK;
              targetasked = 1;
            } else {
              targetmarks[i] = EXECUTEDMARK;
            }
            changednames[i] = convnames[i];
            delete ARGV[targetindexes[i]];
          }
          delete targetindexes[i];
        }
        action = "Changed";
        status = 0;
        size = 0;
        if (targetstopped) {
          action = "Canceled";
          status = 1;
        } else if (targetasked) {
        for (i = 1; i <= targetsize; i++) {
            targetmark = targetmarks[i];
            if (targetmark == QUESTIONMARK) {
              targetmarks[i] = EXECUTEDMARK;
            }
            targetname = targetnames[i];
            if ('$targetclassify') {
              targetname = targetname targetindicators[i];
            }
            print disptarget(targetmark, targetwidth,
                             targetname, convnames[i]) > deverr;
          }
          printf "Change the above file names ? (y/n): " > deverr;
          status = system("read ans; case $ans in [Yy]);; *) exit 1;; esac");
          if (status != 0) {
            if (status > 1) {
              print "" > deverr;
            }
            exit status;
          }
        }
        for (i = 1; i <= targetsize; i++) {
          targetname = targetnames[i];
          if (targetmarks[i] == EXECUTEDMARK) {
            if (status == 0 && setname(targetname, changednames[i]) != 0) {
              if (size > 0) {
                while (--i >= 0) {
                  targetname = targetnames[i];
                  if (targetname != "") {
                    setname(changednames[i], targetname, " -f");
                  }
                }
                action = "Rolled back";
              }
              status = 1;
              break;
            }
            size++;
          } else {
            targetnames[i] = "";
          }
          if ('$targetclassify') {
            targetname = targetname targetindicators[i];
          }
          delete targetindicators[i];
          print disptarget(targetmarks[i], targetwidth,
                           targetname, convnames[i]) > devout;
          delete convnames[i];
        }
        if (size > 0) {
          if (size == 1) {
            pl = "";
          }
          printf "%s %d item%s -- %s\n", action, size, pl, dirpath;
        }
        exit status;
      }' "${path%/}" "$@"
    ;;
  1)
    ;;
  esac

  return $?
}

# Escape backslashes for the specified format or expression if the character
# preceded by a backslash treat as one literal by awk command.
#
# $1 - the format or expression
# $* - patterns following a backslash, which are unsupported by this script

bslash='\\\\'
if awk 'BEGIN { print "\(" }' 2> /dev/null | awk '$0 == "(" { exit 1 }'; then
  bslash='\\'
fi

escbslash(){
  printf '%s' "$1" | \
  sed -e 's/\\/\
/g
          s/\n\n/'"$bslash$bslash"'/g
          :ESCOCTAL
            /\n\([1-7]\)/ {
              s//\\\\\1/; t ESCOCTAL
            }' \
       -e "$(shift; if [ $# != 0 ]; then printf '/\\n%s/d;' "$@"; fi)" \
       -e 's/\n/'"$bslash"'/g'
}

escbslash0n(){
  escbslash "$1" 'n' 'o00[^1-7]' 'o0[^1-7]' 'o0$' 'x0[^1-9A-Fa-f]' 'x0$'
}

# Get options of this program

optchars='AcfFhiIln:Np:Rs:S:T:vy:'
longopts='almost-all,no-change,classify,interactive,ignore-extension,link,number-start:,quiet,recursive,resume-from:,skip-error,to-lowercase,to-uppercase,verbose,help,version'
if [ $AWKCAPITALIZED != 0 ]; then
  longopts=${longopts}',capitalize:'
fi
if [ $STATREFTIME != 0 -o $LSREFTIME != 0 -o $DATEREFTIME != 0 ]; then
  optchars=${optchars}'d:'
  longopts=${longopts}',utc'
fi
argval=$(getopt "$optchars" "$longopts" "$@")
eval set -- "$argval"

while [ $# != 0 ]
do
  case ${1%%=*} in
  A|almost-all)
    targetdot=1
    ;;
  c|no-change)
    targetnochange=1
    ;;
  capitalize)
    capsregex=$(escbslash "${1#*=}")
    if ! (awk -v r="$capsregex" 'BEGIN { match("", r) }' 2>&1 | \
          awk '{ exit 1 }'); then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    ;;
  d)
    datefmt=$(escbslash "${1#*=}")
    if [ -z "$datefmt" ] || \
       ! awk '
           function cmdparam(param) {
             gsub(/'\''/, "'\''\\\\&'\''", param);
             return " '\''" param "'\''";
           }
           BEGIN {
             datecmd = "date " cmdparam("+" ARGV[1]);
             if (! (datecmd | getline) || \
                 $0 ~ /\t|\// || (datecmd | getline)) {
               exit 1;
             }
           }' "$datefmt"; then
      error 0 "invalid date format '${1#*=}'"
      usage 1
    fi
    ;;
  f)
    targetdir=0
    ;;
  F|classify)
    targetclassify=1
    ;;
  h)
    targetsymlink=1
    ;;
  i|interactive)
    targetprompt=1
    ;;
  I|ignore-extension)
    extignored=1
    ;;
  l|link)
    travlinkfollowed=1
    ;;
  n)
    numfmt=$(escbslash0n "${1#*=}")
    if [ -z "$numfmt" ] || \
       ! (printf '%s' "${1#*=}" | \
          awk '{ sprintf($0, 0); if (NR > 1) { exit 1; } }') 2> /dev/null; then
      error 0 "invalid number format '${1#*=}'"
      usage 1
    fi
    ;;
  N)
    numsamename=1
    ;;
  number-start)
    if [ "${1#*=}" != 0 ] && \
       ! expr "${1#*=}" : '[1-9][0-9]*$' > /dev/null 2>&1; then
      error 0 "invalid number start '${1#*=}'"
      usage 1
    fi
    numstart=${1#*=}
    ;;
  p)
    postexpr=$(escbslash0n "${1#*=}")
    if [ -z "$postexpr" ] || \
       ! (printf '%s' "${1#*=}" | awk 'NR > 1 { exit 1 }') || \
       ! (echo | sed "s${1#*=}" > /dev/null 2>&1); then
      error 0 "unsupported sed expression '${1#*=}'"
      usage 1
    fi
    ;;
  quiet)
    targetquiet=1
    ;;
  R|recursive)
    travsubdirs='*/'
    ;;
  s)
    subexpr=$(escbslash0n "${1#*=}")
    if ! (echo | sed "s${1#*=}" > /dev/null 2>&1) || \
       [ -z "$subexpr" ] || ! (echo "$1" | awk 'NR > 1 { exit 1 }'); then
      error 0 "unsupported sed expression '${1#*=}'"
      usage 1
    fi
    ;;
  S|resume-from)
    travstartpath=$(if cd "${1#*=}" 2> /dev/null; then
                      pwd -L
                    fi)
    if [ -z "$travstartpath" ]; then
      error 1 "${1#*=}: No such directory"
    fi
    travsubdirs='*/'
    ;;
  skip-error)
    errstopped=0
    ;;
  T)
    targetregex=$(escbslash "${1#*=}")
    if ! (awk -v r="$targetregex" 'BEGIN { match("", r) }' 2>&1 | \
          awk '{ exit 1 }'); then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    ;;
  to-lowercase)
    fromcase=$FILEUPPERCASE$(escbslash0n "$FBATCHSHTRUPPERCASE")
    tocase=$FILELOWERCASE$(escbslash0n "$FBATCHSHTRLOWERCASE")
    ;;
  to-uppercase)
    fromcase=$FILELOWERCASE$(escbslash0n "$FBATCHSHTRLOWERCASE")
    tocase=$FILEUPPERCASE$(escbslash0n "$FBATCHSHTRUPPERCASE")
    ;;
  utc)
    dateutc=1
    ;;
  v|verbose)
    targetverbose=1
    ;;
  y)
    trexpr=$(escbslash0n "${1#*=}")
    if ! (echo | sed "y${1#*=}" > /dev/null 2>&1) || \
       [ -z "$trexpr" ] || ! (echo "$1" | awk 'NR > 1 { exit 1 }'); then
      error 0 "unsupported sed expression '${1#*=}'"
      usage 1
    fi
    ;;
  help)
    usage 0
    ;;
  version)
    version
    ;;
  --)
    shift
    break
    ;;
  \?*)
    error 0 "unknown option -- ${1#?}"
    usage 1
    ;;
  -*)
    error 0 "option requires an argument -- ${1#-}"
    usage 1
    ;;
  +*)
    error 0 "option doesn't take an argument -- ${1#+}"
    usage 1
    ;;
  esac
  shift
done

# Exit if no rename, date, and number option is specified

if [ -z "$subexpr" -a -z "$postexpr" -a -z "$trexpr" -a \
     -z "$fromcase" -a -z "$capsregex" -a -z "$datefmt" -a -z "$numfmt" ]; then
  exit
fi

if [ $targetdot != 0 ]; then
  if [ -n "$travsubdirs" ]; then
    travsubdirs='.*/ '$travsubdirs
  fi
  targetentries='.* '$targetentries
fi

if ! (escbslash0n | awk 'length($0) > 0 { exit 1 }'); then
  trlf="$FBATCHSHTRLF"
fi

# Change the name of files and subdirectories in each directory

if [ $# = 0 ]; then
  set -- ./
fi

dircount=0

while [ $# != 0 ]
do
  if [ -d "$1" -o -z "${1%%*/}" ]; then
    dircount=$(($dircount + 1))
    dirtrav $dircount "$1"
    status=$?
    case $status in
    0) ;;
    1) printf 'Permission denied -- %s\n' "${1%/}";;
    *) exit $status;;
    esac
  else
    error 1 "$1: Is not a directory"
  fi
  shift
done
