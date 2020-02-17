#!/bin/sh
#
# Change the access or modification time of files and subdirectories.
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
PROGRAM='chftime'
VERSION='1.0'

unalias -a

AWKSTDOUT='/dev/tty'
AWKSTDERR='/dev/tty'
AWKUSEHEXEXPR=0

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

TIMEDATAFORMAT='%04d %02d %02d %02d %02d %02d %09d'
TIMEOUTFORMAT='%04d-%02d-%02d %02d:%02d:%02d'
TIMEABRESTFORMAT='%04d/%02d/%02d %02d:%02d'
TIMESEPARATOR='/'

DATEREFTIME=0
DATEFORMAT='%Y %m %d %H %M %S 000000000'
DATETZNUM=$(date +%z 2> /dev/null | awk '{ sub(/^%?z$/, ""); print }')
DATETZNAME=$(date +%Z 2> /dev/null | awk '{ sub(/^%?Z$/, ""); print }')

TOUCHTIMEOPT=' -t'
TOUCHFORMAT='%04d%02d%02d%02d%02d.%02d'
TOUCHSETTZ=0
TOUCHSETNSEC=0

if touch -d '2020-01-01T00:00:00Z' -c /tmp/test 2> /dev/null; then
  TOUCHTIMEOPT=' -d'
  TOUCHFORMAT='%04d-%02d-%02dT%02d:%02d:%02d'
  TOUCHSETTZ=1
  if expr $(date '+%N') : '[0-9][0-9]*$' > /dev/null 2>&1 && \
     touch -d '2020-01-01T00:00:00.1' -c /tmp/test 2> /dev/null; then
    DATEFORMAT=${DATEFORMAT% 0*}' %N'
    TOUCHFORMAT=${TOUCHFORMAT}'.%d'
    TOUCHSETNSEC=1
  fi
fi

STATREFTIME=0
STAT=""
STATATIMEFORMAT=""
STATMTIMEFORMAT=""

REPLACEDELIMTOSPC=""

if stat -c '%y' / > /dev/null 2>&1; then
  DATEREFTIME=1
  STATREFTIME=1
  STAT='stat -c'
  STATATIMEFORMAT='%x'
  STATMTIMEFORMAT='%y'
  REPLACEDELIMTOSPC=" | sed 's/[^0-9/]/ /g; s/  [0-9][0-9][0-9][0-9]//g'"
elif stat -f '%Sm' / > /dev/null 2>&1; then
  DATEREFTIME=1
  STATREFTIME=1
  STAT="stat -t +'$DATEFORMAT' -f"
  STATATIMEFORMAT='%Sa'
  STATMTIMEFORMAT='%Sm'
elif date -r / "+$DATEFORMAT" > /dev/null 2>&1; then
  DATEREFTIME=1
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
  echo "Usage: $PROGRAM [OPTION] DIR..."
  if [ $STATREFTIME != 0 ]; then
    echo 'Set the access or modification time of files or subdirectories in each DIR(s)'
  else
    echo 'Set the modification time of files or subdirectories in each DIR(s)'
  fi
  echo 'to the specified time by Unix commands.'
  echo
  if [ $STATREFTIME != 0 ]; then
    echo '  -a                         change only the access time'
  fi
  echo '      --abreast              print changed time of each target in a line'
  echo '  -c, --no-change            do not change any files or directories'
  echo '  -d DATETIME                use DATETIME for specifying the time'
  echo '  -D STRING                  parse STRING and move file or directory time'
  echo '  -f                         change the time of items except for directory'
  echo '  -h                         change the time of symbolic links'
  echo '  -i, --interactive          prompt before change'
  echo '  -l, --link                 follow the symbolic link (with -R)'
  echo '  -m                         change only the modification time'
  echo '      --parent-recently      set the parent time to most recently modified file'
  echo "  -r, --reference            use each file's time for specifying the time"
  echo '  -R, --recursive            change the time in directories recursively'
  echo '  -S, --start-from PATH      resume traversing directories from PATH (with -R)'
  echo "      --skip-error           skip target's error in directory"
  echo '  -t STAMP                   use STAMP for specifying the time'
  echo '  -T REGEX                   find targets whose name matches REGEX in directory'
  if [ $TOUCHSETTZ != 0 ]; then
    echo '      --utc                  set Coordinated Universal Time (UTC)'
  fi
  echo '  -v, --verbose              show the list of targets in each directory'
  echo '      --help                 display this help and exit'
  echo '      --version              output version information and exit'
  echo
  echo 'DATETIME or STAMP must be specified with YYYY-MM-DDThh:mm:ss[.frac] of ISO 8601'
  echo 'format or YYYYMMDDhhmm[.ss] used by -t option of touch command.'
  echo
  echo '-D option accept STRING as only relative items used by -d option of GNU touch.'
  echo "Those are ordinal words like 'last', 'this', 'next', 'first', ..., 'twelfth',"
  echo "or signed integers with duration words like 'fortnight', 'week', 'year', ...,"
  echo "'second', 'nanosecond' (followed by 'ago' if back). In addition, 'yesterday',"
  echo "'today', 'now', and 'tomorrow' can be specified without other modifiers."
  echo
  echo 'REGEX is used by match function of awk script. In details, see the manual.'
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
travsubdir=""
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
   if [ -n "$travsubdir" ] && \
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
     set -- $travsubdir / "$@"

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

targetregex=""
targetnochange=0
targetprompt=0
targetverbose=0
targetdir=1
targetsymlink=0
timeabreast=0
timespec=""
reltimespec='0 0 0 0 0 0 0'
atimeset=1
mtimeset=1
utcset=0
parentrecently=0
errstopped=1

dirmain(){
  case $1 in
  0)
    set -- *
    awk -v dircount=$count -v dirdepth=$depth -v targetregex="$targetregex" \
        -v timespec="$timespec" -v reltimespec="$reltimespec" '
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
      function timevalprintf(tm, tmfmt) {
        if (tmfmt == "") {
          tmfmt = "'"$TIMEDATAFORMAT$TIMESEPARATOR"'";
        }
        return sprintf(tmfmt, tm[1], tm[2], tm[3], tm[4], tm[5], tm[6], tm[7]);
      }
      function timeprintf(tmstr, tmfmt,  tm) {
        split(tmstr, tm);
        if (tmfmt == "") {
          tmfmt = "'"$TIMEABRESTFORMAT"'";
        } else {
          if ('$TOUCHSETNSEC') {
            tmfmt = tmfmt ".%s";
          }
          if ('$utcset') {
            tmfmt = tmfmt " +0000";
          } else {
            tmfmt = tmfmt " " "'$DATETZNUM'";
          }
        }
        return timevalprintf(tm, tmfmt);
      }
      function showtarget(mark, width, target, num, tmstrs, tmtypes, device,
                          str, margin) {
        margin = width - dispwidth(target);
        gsub(/\n/, "&  ", target);
        str = sprintf("%s %s", mark, target);
        if (num > 0) {
          str = str sprintf("%" margin "s ->", "");
          do {
            if ('$timeabreast') {
              str = str " " timeprintf(tmstrs[num]);
            } else {
              if (str !~ /->$/) {
                str = str sprintf("\n  %" width "s   ", "");
              }
              str = str " " tmtypes[num] ": " \
                            timeprintf(tmstrs[num], "'"$TIMEOUTFORMAT"'");
            }
          } while (--num > 0);
        }
        print str > device;
      }
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function gettime(target, datefmt,  datecmd, cmdfmt, cmdtz) {
        if ('$STATREFTIME') {
          if ('$utcset') {
            cmdtz = "TZ= ";
          }
          cmdfmt = cmdtz "'"$STAT"' " datefmt "%s";
        } else {
          if ('$utcset') {
            cmdtz = " -u";
          }
          cmdfmt = "date" cmdtz " -r%s '\''+" datefmt "'\''";
        }
        gsub(/%[^s]/, "%&", cmdfmt);
        datecmd = sprintf(cmdfmt, cmdparam(target)) "'"$REPLACEDELIMTOSPC"'";
        datecmd | getline;
        close(datecmd);
        return $0;
      }
      function settime(target, touchopt, tmstr,  tmfmt) {
        if (touchopt != "") {
          if ('$targetsymlink') {
            touchopt = touchopt " -h";
          }
          tmfmt = "'$TOUCHFORMAT'";
          if ('$utcset') {
            tmfmt = tmfmt "Z";
          }
          return system("touch" touchopt "'"$TOUCHTIMEOPT"'" \
                        " " timeprintf(tmstr, tmfmt) " --" cmdparam(target));
        }
        return 0;
      }
      function mdays(y, m) {
        if (m == 2) {
          if (y % 4 > 0 || (y % 100 == 0 && y % 400 > 0)) {
            return 28;
          }
          return 29;
        } else if (m == 4 || m == 6 || m == 9 || m == 11) {
          return 30;
        }
        return 31;
      }
      function maxtimeval(tm, ind) {
        if (ind == 2) {
          return 12;
        } else if (ind == 3) {
          return mdays(tm[1], tm[2]);
        } else if (ind == 4) {
          return 24;
        } else if (ind == 5 || ind == 6) {
          return 60;
        }
        return 1000000000;
      }
      function calctime(tm, tmind, val,  maxval, ind, down) {
        ind = tmind;
        do {
          tm[ind] += val;
          val = 0;
          if (ind > 1) {
            if (tm[ind] < 0 || (tm[ind] == 0 && ind <= 3)) {
              val = -1;
              down--;
            } else {
              maxval = maxtimeval(tm, ind);
              if (tm[ind] > maxval || (tm[ind] == maxval && ind >= 4)) {
                tm[ind] -= maxval;
                val = 1;
              }
            }
            if (val != 0) {
              ind--;
              continue;
            }
          }
          ind++;
          if (down < 0) {
            val = maxtimeval(tm, ind);
            down++;
          }
        } while (ind <= tmind);
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
        touchsize = 0;
        if ('$mtimeset') {
          if ('$STATREFTIME') {
            datefmt = "'"$STATMTIMEFORMAT$TIMESEPARATOR"'";
          } else {
            datefmt = "'"$DATEFORMAT$TIMESEPARATOR"'";
          }
          touchopts[++touchsize] = " -m";
          desttime = timespec "'$TIMESEPARATOR'";
          timesetspec = "Modify ";
        }
        if ('$atimeset') {
          datefmt = datefmt "'"$STATATIMEFORMAT$TIMESEPARATOR"'";
          if (timespec != "" && '$mtimeset') {
            touchopts[1] = " -ma";
          } else {
            touchopts[++touchsize] = " -a";
          }
          desttime = desttime timespec "'$TIMESEPARATOR'";
          timesetspec = timesetspec "Access ";
        }
        split(timesetspec, timetypes);
        split(reltimespec, reltimeval);
        if ('$targetverbose') {
          devout = "'$AWKSTDOUT'";
        } else {
          devout = "/dev/null";
        }
        delete ARGV[1];
        targetwidth = 0;
        targetsize = 0;
        for (i = 2; i < ARGC; i++) {
          fname = ARGV[i];
          if (fname ~ targetregex && \
              (fname != "*" || system("test -e" cmdparam("*")) == 0) && \
              ('$targetdir' || system("test ! -d" cmdparam(fname)) == 0) && \
              ('$targetsymlink' || system("test ! -h" cmdparam(fname)) == 0)) {
            targetnames[targetsize] = fname;
            targettimes[targetsize] = gettime(fname, datefmt);
            if (++targetsize > 1) {
              pl = "s";
            }
            width = dispwidth(fname);
            if (targetwidth < width) {
              targetwidth = width;
            }
          }
          delete ARGV[i];
        }
        printf dirbreak "%s:\n%d target%s\n", dirpath, targetsize, pl > devout;
        targetstopped = 0;
        targetasked = 0;
        for (i = 0; i < targetsize; i++) {
          targetname = targetnames[i];
          targettime = targettimes[i];
          if (system("test -w" cmdparam(targetname)) != 0) {
            targetmarks[i] = ERRORMARK;
            targetstopped = '$errstopped';
            continue;
          }
          if (timespec == "" || i < 1) {
            if (timespec == "") {
              desttime = targettime;
            }
            timenum = split(desttime, timestrs, "'$TIMESEPARATOR'") - 1;
            desttime = "";
            while (timenum > 0) {
              split(timestrs[timenum--], timeval);
              for (j = 1; j <= 7; j++) {
                calctime(timeval, j, reltimeval[j]);
              }
              desttime = timevalprintf(timeval) desttime;
            }
          }
          if (desttime == targettime) {
            targetmarks[i] = UNCHANGEDMARK;
            continue;
          }
          desttimes[i] = desttime;
          if (desttime ~ /(^|\/)(0|1[0-8]|[1-9][0-9][0-9][0-9][0-9]+)/) {
            targetmarks[i] = ERRORMARK;
            targetstopped = '$errstopped';
            continue;
          } else if ('$targetnochange') {
            targetmarks[i] = CHANGECANDMARK;
          } else if ('$targetprompt') {
            targetmarks[i] = QUESTIONMARK;
            targetasked = 1;
          } else {
            targetmarks[i] = EXECUTEDMARK;
          }
        }
        action = "Changed";
        status = 0;
        size = 0;
        if (targetstopped) {
          action = "Canceled";
          status = 1;
        } else if (targetasked) {
          for (i = 0; i < targetsize; i++) {
            targetmark = targetmarks[i];
            if (targetmark != "") {
              if (targetmark == QUESTIONMARK) {
                targetmarks[i] = EXECUTEDMARK;
              }
              timenum = split(desttimes[i], timestrs, "'$TIMESEPARATOR'") - 1;
              showtarget(targetmark, targetwidth, targetnames[i],
                         timenum, timestrs, timetypes, "'$AWKSTDERR'");
            }
          }
          printf "Change the above file times ? (y/n): " > "'$AWKSTDERR'";
          status = system("read ans; case $ans in [Yy]);; *) exit 1;; esac");
          if (status != 0) {
            if (status > 1) {
              print "" > "'$AWKSTDERR'";
            }
            exit status;
          }
        }
        for (i = 0; i < targetsize; i++) {
          targetmark = targetmarks[i];
          if (targetmark != "") {
            targetname = targetnames[i];
            timenum = split(desttimes[i], timestrs, "'$TIMESEPARATOR'") - 1;
            if (targetmark == EXECUTEDMARK) {
              if (status == 0) {
                for (j = 1; j <= touchsize; j++) {
                  if (settime(targetname, touchopts[j], timestrs[j]) != 0) {
                    status = 1;
                    break;
                  }
                }
                if (status != 0) {
                  if (size > 0) {
                    while (--i >= 0) {
                      targetname = targetnames[i];
                      if (targetname != "") {
                        split(targettimes[i], timestrs, "'$TIMESEPARATOR'");
                        num = 1;
                        if ('$mtimeset') {
                          settime(targetname, " -m", timestrs[num++]);
                        }
                        if ('$atimeset') {
                          settime(targetname, " -a", timestrs[num]);
                        }
                      }
                    }
                    action = "Rolled back";
                  }
                  break;
                }
              }
              size++;
            } else {
              targetnames[i] = "";
            }
            showtarget(targetmark, targetwidth, targetname,
                       timenum, timestrs, timetypes, devout);
          }
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
    if [ $parentrecently = 0 ]; then
      return 0
    fi
    set -- "$(ls -t | sed '1p; d')"*
    awk -v tzname=${DATETZNAME:-???} '
      function timevalprintf(tm, tmfmt) {
        return sprintf(tmfmt, tm[1], tm[2], tm[3], tm[4], tm[5], tm[6], tm[7]);
      }
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function gettime(target,  datecmd, cmdfmt, cmdtz) {
        if ('$STATREFTIME') {
          if ('$utcset') {
            cmdtz = "TZ= ";
          }
          cmdfmt = cmdtz "'"$STAT $STATMTIMEFORMAT"' %s";
        } else {
          if ('$utcset') {
            cmdtz = " -u";
          }
          cmdfmt = "date" cmdtz " -r%s '\'"+$DATEFORMAT"\''";
        }
        gsub(/%[^s]/, "%&", cmdfmt);
        datecmd = sprintf(cmdfmt, cmdparam(target)) "'"$REPLACEDELIMTOSPC"'";
        datecmd | getline;
        close(datecmd);
        return $0;
      }
      function settime(target, touchopt, tm,  tmfmt) {
        if ('$targetsymlink') {
          touchopt = touchopt " -h";
        }
        tmfmt = "'$TOUCHFORMAT'";
        if ('$utcset') {
          tmfmt = tmfmt "Z";
        }
        return system("touch" touchopt "'"$TOUCHTIMEOPT"'" \
                      " " timevalprintf(tm, tmfmt) " --" cmdparam(target));
      }
      function cmptime(tm1, tm2,  val, ind) {
        for (ind = 1; ind <= 7; ind++) {
          val = tm1[ind] - tm2[ind];
          if (val != 0) {
            return val;
          }
        }
        return 0;
      }
      BEGIN {
        month[1] = "Jan"; month[2] = "Feb"; month[3] = "Mar";
        month[4] = "Apr"; month[5] = "May"; month[6] = "Jun";
        month[7] = "Jul"; month[8] = "Aug"; month[9] = "Sep";
        month[10] = "Oct"; month[11] = "Nov"; month[12] = "Dec";
        dirpath = ARGV[1];
        dirwrite = system("test ! -w ./");
        if (! dirwrite) {
          printf "Permission denied -- %s\n", dirpath;
          exit;
        }
        parentpath = ARGV[2];
        for (i = 3; i < ARGC; i++) {
          if (ARGV[i] != "*" || system("test -e" cmdparam("*")) == 0) {
            split(gettime(ARGV[i]), timeval);
            if (cmptime(mostrecent, timeval) < 0) {
              for (j = 1; j <= 7; j++) {
                mostrecent[j] = timeval[j];
              }
            }
          }
        }
        if (mostrecent[1] > 0) {
          if (settime(parentpath, " -m", mostrecent) != 0) {
            exit 1;
          }
          if ('$utcset') {
            tzname = "UTC";
          }
          printf "Modified at %s %2d %02d:%02d:%02d %s %4d -- %s\n",
                 month[int(mostrecent[2])], mostrecent[3], mostrecent[4],
                 mostrecent[5], mostrecent[6], tzname, mostrecent[1], dirpath;
        }
      }' "${path%/}" "$(pwd -L)" "$@"
    ;;
  esac

  return $?
}

# Check the string and output the date and time separated by spaces. Those are
# year, month, day, hour, minute, second, and nanosecond number.
#
# $1 - 1 if the time is specified with ISO 8601 format, otherwise, 0
# $2 - the date and time string

gettime(){
  awk '
    function mdays(y, m) {
      if (m == 2) {
        if (y % 4 > 0 || (y % 100 == 0 && y % 400 > 0)) {
          return 28;
        }
        return 29;
      } else if (m == 4 || m == 6 || m == 9 || m == 11) {
        return 30;
      }
      return 31;
    }
    BEGIN {
      REGEXYEAR = "[0-9][0-9][0-9][0-9]";
      REGEXMONTH = "(0[1-9]|1[0-2])";
      REGEXDAY = "[0-3][0-9]";
      REGEXHOUR = "([0-1][0-9]|2[0-3])";
      REGEXMINUTE = "[0-5][0-9]";
      REGEXSEC = "[0-5][0-9]";
      if ('$1') {
        regextime = "^" REGEXYEAR "-" REGEXMONTH "-" REGEXDAY \
                    "[T ]" REGEXHOUR ":" REGEXMINUTE ":" REGEXSEC;
        regexsec = "^[.,][0-9]+$";
      } else {
        regextime = "^" REGEXYEAR REGEXMONTH REGEXDAY REGEXHOUR REGEXMINUTE;
        regexsec = "^\\.[0-5][0-9]$";
      }
      if (match(ARGV[1], regextime)) {
        timeargv = substr(ARGV[1], 1, RLENGTH);
        secargv = substr(ARGV[1], RLENGTH + 1);
        if (secargv != "") {
          if (secargv !~ regexsec) {
            exit;
          }
          if ('$1') {
            secargv = secargv "00000000";
            if (length(secargv) > 10) {
              secargv = substr(secargv, 1, 10);
            }
          }
        }
        timeval[1] += substr(timeargv, 1, 4);
        timeargv = substr(timeargv, 5);
        i = 2;
        while (match(timeargv, /[0-9][0-9]/)) {
          timeval[i++] += substr(timeargv, RSTART, 2);
          timeargv = substr(timeargv, RSTART + 2);
        }
        timeval[i] += substr(secargv, 2);
        if (timeval[3] >= 1 && timeval[3] <= mdays(timeval[1], timeval[2])) {
          printf "'"$TIMEDATAFORMAT"'", timeval[1], timeval[2], timeval[3],
                 timeval[4], timeval[5], timeval[6], timeval[7];
        }
      }
    }' "$2"
}

# Parse the string as relative date or time and output the sequence of integers
# separated by spaces. Those are year, month, day, hour, minute, second, and
# nanosecond number which preceded by a hyphen if the value is negative.
#
# $1 - the relative date or time string

getreltime(){
  printf '%s' "$1" | \
  tr 'A-Z\n\t' 'a-z  ' | \
  sed 's/[-+]/ &/g
       s/[0-9][0-9]*/ &/g
       s/[a-z][a-z]*/ &/g
       s/  */ /g
       s/- \([0-9]\)/-\1/g' | \
  awk -v val=1 -v ordinal=0 -v error=0 '
    BEGIN {
      ordval["last"] = -1;
      ordval["next"] = 1;
      ordval["first"] = 1;
      ordval["third"] = 3;
      ordval["fourth"] = 4;
      ordval["fifth"] = 5;
      ordval["sixth"] = 6;
      ordval["seventh"] = 7;
      ordval["eighth"] = 8;
      ordval["ninth"] = 9;
      ordval["tenth"] = 10;
      ordval["eleventh"] = 11;
      ordval["twelfth"] = 12;
      dayval["yesterday"] = -1;
      dayval["tomorrow"] = 1;
    }
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^(year|month|day|hour|min(ute)?|sec(ond)?)s?$/ || \
            $i ~ /^(nsec|nanosec(ond)?)s?$/ || $i ~ /^(fortnight|week)s?$/) {
          duration = $i;
          sub(/s$/, "", duration);
          if (i <= NF - 1 && $(i + 1) == "ago") {
            i++;
            val *= -1;
          }
        } else if (!ordinal) {
          if (match($i, /^-?[0-9]+$/) || \
              $i == "last" || $i == "this" || $i == "next" || \
              $i == "first" || $i == "third" || $i == "fourth" || \
              $i == "fifth" || $i == "sixth" || $i == "seventh" || \
              $i == "eighth" || $i == "ninth" || $i == "tenth" || \
              $i == "eleventh" || $i == "twelfth") {
            if (RLENGTH > 0) {
              val = $i;
            } else {
              val = ordval[$i];
            }
            ordinal = 1;
            continue;
          } else if ($i == "-" || $i == "+") {
            continue;
          } else if ($i == "yesterday" || $i == "today" || $i == "now" || \
                     $i == "tomorrow") {
            duration = "day";
            val = dayval[$i];
          }
        } else {
          error = 1;
          exit;
        }
        relval[duration] += val;
        val = 1;
        ordinal = 0;
      }
    }
    END {
      if (!error) {
        if (ordinal) {
          relval["s"] += val;
        }
        relval["day"] += relval["fortnight"] * 14 + relval["week"] * 7;
        relval["min"] += relval["minute"];
        relval["sec"] += relval["second"];
        relval["nsec"] += relval["nanosec"] + relval["nanosecond"];
        printf "%d %d %d %d %d %d %d",
               relval["year"], relval["month"], relval["day"],
               relval["hour"], relval["min"], relval["sec"], relval["nsec"];
      }
    }'
}

# Escape backslashes for the specified format or expression if the character
# preceded by a backslash treat as one literal by awk command.
#
# $1 - the format or expression

bslash='\\\\'
if awk 'BEGIN { print "\(" }' 2> /dev/null | awk '$0 == "(" { exit 1 }'; then
  bslash='\\'
fi

escbslash(){
  printf '%s' "$1" | \
  sed 's/\\/\
/g
       s/\n\n/'"$bslash$bslash"'/g
       :ESCOCTAL
         /\n\([1-7]\)/ {
           s//\\\\\1/; t ESCOCTAL
         }
       s/\n/'"$bslash"'/g'
}


# Get options of this program

if [ $DATEREFTIME = 0 ]; then
  error 1 'this environment is unsupported because of not referencing file date'
fi

actime=0
modtime=0
reftime=0
optchars='cd:D:fhilmrRS:t:T:v'
longopts='abreast,no-change,interactive,link,parent-recently,reference,recursive,start-from:,skip-error,verbose,help,version'
if [ $STATREFTIME != 0 ]; then
  optchars=${optchars}'a'
fi
if [ $TOUCHSETTZ != 0 ]; then
  longopts=${longopts}',utc'
fi
argval=$(getopt "$optchars" "$longopts" "$@")
eval set -- "$argval"

while [ $# != 0 ]
do
  case ${1%%=*} in
  a)
    actime=1
    ;;
  abreast)
    timeabreast=1
    ;;
  c|no-change)
    targetnochange=1
    parentrecently=0
    ;;
  d)
    timespec=$(gettime 1 "${1#*=}")
    if [ -z "$timespec" ]; then
      error 0 "invalid date format -- ${1#*=}"
      usage 1
    elif [ $TOUCHSETNSEC = 0 ] && \
         ! expr "${1#*=}" : '.*\.[0-9][0-9]*$' > /dev/null 2>&1; then
      error 1 'nanoseconds of file time is unsupported'
    fi
    ;;
  D)
    if [ -n "${1#*=}" ]; then
      reltimespec=$(getreltime "${1#*=}")
      if [ -z "$reltimespec" ]; then
        error 0 "invalid date format '${1#*=}'"
        usage 1
      elif [ $TOUCHSETNSEC = 0 ] && \
           ! (echo "$reltimespec" | awk '$7 !~ /^0+$/ { exit 1 }'); then
        error 1 'nanoseconds of file time is unsupported'
      fi
    else
      reltimespec=""
    fi
    ;;
  f)
    targetdir=0
    ;;
  h)
    targetsymlink=1
    ;;
  i|interactive)
    targetprompt=1
    ;;
  l|link)
    travlinkfollowed=1
    ;;
  m)
    modtime=1
    ;;
  parent-recently)
    if [ $targetnochange = 0 ]; then
      parentrecently=1
    fi
    ;;
  r|reference)
    reftime=1
    ;;
  R|recursive)
    travsubdir='*/'
    ;;
  S|start-from)
    travstartpath=$(if cd "${1#*=}" 2> /dev/null; then
                      pwd -L
                    fi)
    if [ -z "$travstartpath" ]; then
      error 1 "${1#*=}: No such directory"
    fi
    ;;
  skip-error)
    errstopped=0
    ;;
  t)
    timespec=$(gettime 0 "${1#*=}")
    if [ -z "$timespec" ]; then
      error 0 "invalid time format '${1#*=}'"
      usage 1
    fi
    ;;
  T)
    targetregex=$(escbslash "${1#*=}")
    if ! (awk -v r="$targetregex" 'BEGIN { match("", r) }' 2>&1 | \
          awk '{ exit 1 }'); then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    ;;
  utc)
    utcset=1
    ;;
  v|verbose)
    targetverbose=1
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
    error 0 "unknown option -- ${1#\?}"
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

if [ $actime != 0 ]; then
  if [ $modtime = 0 ]; then
    mtimeset=0
  fi
elif [ $modtime != 0 -o $STATREFTIME = 0 ]; then
  atimeset=0
fi

# Exit if one of specifying time options is specified

if [ $reftime = 0 -a -z "$timespec" ]; then
  exit 0
fi

# Change the access or modification time of files and subdirectories

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
