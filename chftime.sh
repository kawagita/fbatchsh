#!/bin/sh
#
# Change the modification or access time of files and subdirectories.
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

TIMEFORMAT='%04d-%02d-%02d %02d:%02d:%02d'
TIMESHORTFORMAT='%04d/%02d/%02dT%02d:%02d'
TIMESEPARATOR='/'

FIELDTIMEFORMAT='%04d %02d %02d %02d %02d %02d %09d'
FIELDTIMEZERO=$(printf "$FIELDTIMEFORMAT" 0 0 0 0 0 0)
FIELDSEPARATOR=','
FIELDMTIME=1
FIELDATIME=2
FIELDTIMECHARS='ma'

DATEREFTIME=0
DATEREFNSEC=0
DATEFORMAT='%Y %m %d %H %M %S 000000000'
DATEYEARREGEX='(19|[2-9][0-9])[0-9][0-9]'
DATETZREGEX='[-+][0-9][0-9][0-9][0-9]'
DATETZ=$(date +%z 2> /dev/null | sed "/^${DATETZREGEX}\$/!d")
DATETZNAME=$(date +%Z 2> /dev/null | sed '/^[A-Z][A-Z][A-Z][A-Z]*$/!d')

TOUCHTIMEOPTION=' -t'
TOUCHTIMEFORMAT='%04d%02d%02d%02d%02d.%02d'
TOUCHSETTZ=0

if date -r / "+$DATEFORMAT" > /dev/null 2>&1; then
  DATEREFTIME=1
fi
if touch -d '2020-01-01T00:00:00Z' -c /tmp/test 2> /dev/null; then
  TOUCHTIMEOPTION=' -d'
  TOUCHTIMEFORMAT='%04d-%02d-%02dT%02d:%02d:%02d'
  TOUCHSETTZ=1
  if expr $(date '+%N') : '[0-9][0-9]*$' > /dev/null 2>&1 && \
     touch -d '2020-01-01T00:00:00.1' -c /tmp/test 2> /dev/null; then
    DATEREFNSEC=1
    DATEFORMAT=${DATEFORMAT% 0*}' %N'
    TOUCHTIMEFORMAT=$TOUCHTIMEFORMAT'.%09d'
  fi
fi

STATREFTIME=0
STAT=""
STATMTIME=""
STATFILTER=""
STATTIMEFILTER=""
STATNOTIMEFILTER=""

if stat -c '%y' / > /dev/null 2>&1; then
  STATREFTIME=1
  STAT="stat -c '%A %u %g$FIELDSEPARATOR%y$TIMESEPARATOR%x'"
  STATMTIME='stat -c %y'
  STATFILTER=" | sed -e 's/ $DATETZREGEX//g'"
elif stat -f '%Sm' / > /dev/null 2>&1; then
  STATREFTIME=1
  STAT="stat -t '$DATEFORMAT' -f"
  STATMTIME=$STAT' %Sm'
  STAT=$STAT" '%Sp %6Du %6Dg$FIELDSEPARATOR%Sm$TIMESEPARATOR%Sa'"
fi

LSREFTIME=0
LS='ls -fdnql'
LSOPTION=""
LSTIMEOPTCHARS=""
LSFILTER=" | sed -e 's/[1-9][0-9]*//' -e 's/[0-9][0-9]* /$FIELDSEPARATOR/3'"
LSTIMEFILTER=" -e 's/ $DATETZREGEX .*//' -e 's/  *//3'"
LSNOTIMEFILTER=" -e 's/ *$FIELDSEPARATOR.*$/$FIELDSEPARATOR/'"
LSNOMODEFILTER=" -e 's/^[-A-Za-z][-+A-Za-z]* [ 0-9]*$FIELDSEPARATOR//'"

if ls --full-time / > /dev/null 2>&1; then
  LSREFTIME=1
  LSOPTION=' --full-time'
  LSTIMEOPTCHARS='u'
elif ls -E / > /dev/null 2>&1; then
  LSREFTIME=1
  LSOPTION=' -E'
  LSTIMEOPTCHARS='u'
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
  else
    FIELDATIME=0
    FIELDTIMECHARS='m'
  fi
  STAT=$LS$LSOPTION
  STATFILTER=$LSFILTER
  STATTIMEFILTER=$LSTIMEFILTER
  STATNOTIMEFILTER=$LSNOTIMEFILTER
fi

GETTIME=""
GETTIMEFILTER=""

if [ $STATREFTIME != 0 ]; then
  DATEREFTIME=0
  GETTIME=$STATMTIME
  GETTIMEFILTER=$STATFILTER
elif [ $LSREFTIME != 0 ]; then
  DATEREFTIME=0
  GETTIME=$LS$LSOPTION
  GETTIMEFILTER=$LSFILTER$LSTIMEFILTER$LSNOMODEFILTER" -e 's/[-.:]/ /g'"
else
  FIELDATIME=0
  FIELDTIMECHARS='m'
  LSFILTER=" | sed 's/ .*$/$FIELDSEPARATOR/'"
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
  if [ $FIELDATIME != 0 ]; then
    echo 'Set the modification or access time of files or subdirectories in each DIR(s)'
    echo 'by Unix commands. If no DIR, change in the current directory.'
  else
    echo 'Set the modification time of files or subdirectories in each DIR(s) by Unix'
    echo 'commands. If no DIR, change in the current directory.'
  fi
  echo
  echo '  -A, --all                  do not ignore entries starting with .'
  if [ $FIELDATIME != 0 ]; then
    echo '  -a                         change only the access time'
  fi
  echo '  -c, --no-change            do not change any files or subdirectories'
  echo '  -d DATETIME                use DATETIME to set file time'
  echo '  -D STRING                  parse STRING and move specified time'
  echo '  -f                         change the time of only regular files'
  echo '  -F, --classify             show file or directory indicator (one of */@)'
  echo '  -h                         change the time of symbolic links'
  echo '  -i, --interactive          prompt before change in each directory'
  echo '  -l, --link                 follow the symbolic link (with -R)'
  echo '  -m                         change only the modification time'
  echo '      --parent-recently      set the parent time to most recently modified file'
  echo '      --quiet                do not list targets in each directory'
  echo "  -r, --reference            move each file's time (with -d)"
  echo '  -R, --recursive            change the time in directories recursively'
  echo '  -S, --resume-from=PATH     resume traversing directories from PATH'
  echo "      --skip-error           skip target's error in directory"
  echo '  -t STAMP                   use STAMP to set file time'
  echo '  -T REGEX                   target directory entries whose names match REGEX'
  if [ $TOUCHSETTZ != 0 ]; then
    echo '      --utc                  set file time as UTC time zone'
  fi
  echo '  -v, --verbose              print subdirectories without target'
  echo '  -1                         print time information per line'
  echo '      --help                 display this help and exit'
  echo '      --version              output version information and exit'
  echo
  echo 'DATETIME or STAMP must be specified with YYYY-MM-DDThh:mm:ss[.frac] of ISO 8601'
  echo 'format or YYYYMMDDhhmm[.ss] used by -d or -t option of touch command.'
  echo
  echo '-D option accept STRING as only relative items used by -d option of GNU touch.'
  echo "These are ordinal words like 'last', 'this', 'next', 'first', ..., 'twelfth',"
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
timeutc=0
timelined=0
timeorder=${FIELDTIMECHARS%b}
timespec=""
reltimespec='0 0 0 0 0 0 0'
userid=$(id -u)
groupid=$(id -g)
termcols=$(tput cols)
errstopped=1
parentrecently=0

dirmain(){
  case $1 in
  0)
    set -- *
    awk -v dircount=$count -v dirdepth=$depth -v targetregex="$targetregex" \
        -v timespec="$timespec" -v reltimespec="$reltimespec" \
        -v timechars=$FIELDTIMECHARS -v timeorder=$timeorder -v timeperline=1 \
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
      function disptime(tmlined, tmstr, tmlabel,  tmfmt, tm) {
        if (tmlined) {
          tmfmt = " '"$TIMESHORTFORMAT"'";
        } else {
          tmfmt = "'"$TIMEFORMAT"'";
          if ('$DATEREFNSEC') {
            tmfmt = tmfmt ".%s";
          }
          if ('$timeutc') {
            tmfmt = tmfmt " +0000";
          } else {
            tmfmt = tmfmt " " "'$DATETZ'";
          }
          tmfmt = sprintf(" %-6s: ", tmlabel) tmfmt;
        }
        split(tmstr, tm);
        return strtime(tm, tmfmt);
      }
      function disptarget(mark, width, target, tmcols, tmstrs,
                          str, margin, num) {
        TIMELABEL['$FIELDMTIME'] = "Modify";
        TIMELABEL['$FIELDATIME'] = "Access";
        margin = width - dispwidth(target);
        if (margin < 0) {
          margin = 0;
        }
        gsub(/\n/, "&  ", target);
        str = mark " " target;
        if (tmstrs[1] != "'"$FIELDTIMEZERO"'") {
          str = str sprintf("%" margin "s ->", "");
          num = 1;
          while (tmcols[num] != "") {
            if (! '$timelined' && str !~ /->$/) {
              str = str sprintf("\n  %" width "s   ", "");
            }
            str = str disptime('$timelined',
                               tmstrs[tmcols[num]], TIMELABEL[tmcols[num]]);
            num++;
          }
        }
        return str;
      }
      function cmdnoerror(cmd) {
        return "(" cmd " 2>&1;echo $?) | sed '\''${ /0/{ x; p; }; }; x; d'\''";
      }
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function getstat(data, statargv,  statcmd, tmutc, size) {
        if ('$timeutc') {
          tmutc = "TZ= ";
        }
        statcmd = tmutc "'"$STAT"' --" statargv "'"$STATFILTER"'";
        if (! '$DATEREFTIME') {
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
      function getls(data, lsargv,  lscmd, tmutc, tmoptc, size, num) {
        if ('$timeutc') {
          tmutc = "TZ= ";
        }
        split("'"$LSTIMEOPTCHARS"'", tmoptc);
        num = 1;
        while (tmoptc[num] != "") {
          lscmd = tmutc "'"$LS"'" tmoptc[num++] "'"$LSOPTION"' --" lsargv \
                        "'"$LSFILTER$LSTIMEFILTER$LSNOMODEFILTER"'";
          size = 1;
          while (lscmd | getline) {
            data[size] = data[size] "'$TIMESEPARATOR'" $0;
            size++;
          }
          close(lscmd);
        }
      }
      function getdate(dateargv,  datecmd, date) {
        date = "'"$FIELDTIMEZERO"'";
        datecmd = "date";
        if ('$timeutc') {
          datecmd = datecmd " -u";
        }
        datecmd = cmdnoerror(datecmd " -r" dateargv " '\'+"$DATEFORMAT"\''");
        datecmd | getline date;
        close(datecmd);
        return date;
      }
      function strfiletime(tmstrs, num,  tmfield) {
        while (num > 1) {
          tmfield = "'$TIMESEPARATOR'" tmstrs[num--] tmfield;
        }
        return tmstrs[1] tmfield;
      }
      function strtime(tm, tmfmt) {
        return sprintf(tmfmt, tm[1], tm[2], tm[3], tm[4], tm[5], tm[6], tm[7]);
      }
      function settime(target, tmoptc, tmcols, tmstrs,  tmln, tmfmt, tm, num) {
        if ('$targetsymlink') {
          tmln = "h";
        }
        tmfmt = "'$TOUCHTIMEFORMAT'";
        if ('$timeutc') {
          tmfmt = tmfmt "Z";
        }
        num = 1;
        while (tmoptc[num] != "") {
          if ('${FBATCHSHDEBUG:-0}') {
            printf "%s %s\n", tmoptc[num], tmstrs[tmcols[num]] > deverr;
          }
          split(tmstrs[tmcols[num]], tm);
          if (system("touch -" tmoptc[num] tmln "'"$TOUCHTIMEOPTION"'" \
                     " " strtime(tm, tmfmt) " --" cmdparam(target)) != 0) {
            return 1;
          }
          num++;
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
        if (dircount > 1 || dirdepth > 0 || '${FBATCHSHDEBUG:-0}') {
          dirbreak = "\n";
        }
        timenum = length(timechars);
        timecolsize = length(timeorder);
        timeoptc[1] = timechars;
        for (i = 1; i <= timecolsize; i++) {
          timechar = substr(timeorder, i, 1);
          if (timespec == "") {
            timeoptc[i] = timechar;
          }
          timecols[i] = index(timechars, timechar);
        }
        timewidth = length(disptime('$timelined', "'"$FIELDTIMEZERO"'"));
        if ('$timelined') {
          timeperline = timecolsize;
        }
        maxdispwidth -= timewidth * timeperline + 6;
        if ('$targetquiet') {
          devout = "/dev/null";
        }
        delete ARGV[1];
        for (i = 2; i < ARGC; i++) {
          if (ARGV[i] ~ targetregex && (ARGV[i] != "." && ARGV[i] != "..") && \
              (ARGV[i] != "*" || system("test -e" cmdparam("*")) == 0)) {
            fileindexes[++fsize] = i;
          }
        }
        targetwidth = 0;
        targetsize = 0;
        if (fsize > 0) {
          if ('${FBATCHSHDEBUG:-0}') {
            print "" > deverr;
          }
          for (i = 1; i <= fsize; i++) {
            fileargv = fileargv cmdparam(ARGV[fileindexes[i]]);
          }
          getstat(fdata, fileargv);
          if ('$LSREFTIME') {
            getls(fdata, fileargv);
          }
          for (i = 1; i <= fsize; i++) {
            fileindex = fileindexes[i];
            fname = ARGV[fileindex];
            delete fileindexes[i];
            if ('$DATEREFTIME') {
              fdata[i] = fdata[i] getdate(cmdparam(fname), datefmt);
            }
            if ('${FBATCHSHDEBUG:-0}') {
              printf "%-'${termcols:-80}'s%s\n", fdata[i] "  ", fname > deverr;
            }
            fdataindex = index(fdata[i], "'$FIELDSEPARATOR'");
            split(substr(fdata[i], 1, fdataindex - 1), fileinfo);
            fmode = fileinfo[1];
            fpermindex = 2;
            if (fileinfo[2] != userid) {
              fpermindex += 3;
              if (fileinfo[3] != groupid) {
                fpermindex += 3;
              }
            }
            fpermission = substr(fmode, fpermindex, 3);
            ftime = substr(fdata[i], fdataindex + 1);
            gsub(/[-:.]/, " ", ftime);
            delete fdata[i];
            indicator = "";
            if (index(fpermission, "w") == 0) {
              continue;
            } else if (fmode ~ /^d/) {
              if (! '$targetdir') {
                continue;
              }
              indicator = "/";
            } else if (fmode ~ /^l/) {
              if (! '$targetsymlink' || \
                  (! '$targetdir' && system("test -d" cmdparam(fname)) == 0)) {
                continue;
              }
              indicator = "@";
            } else if (fmode !~ /^-/) {
              continue;
            } else if (index(fmode, "x") > 0) {
              indicator = "*";
            }
            targetsize++;
            targetnames[targetsize] = fname;
            targettimes[targetsize] = ftime;
            targetindicators[targetsize] = indicator;
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
        targetstopped = 0;
        targetasked = 0;
        for (num = 1; num <= timenum; num++) {
          TIMEFIELDZEROS[num] = "'"$FIELDTIMEZERO"'";
          timefields[num] = timespec;
        }
        split(reltimespec, reltimeval);
        for (i = 1; i <= targetsize; i++) {
          if (targettimes[i] ~ /'"$FIELDTIMEZERO"'/) {
            targetmarks[i] = ERRORMARK;
            convtimes[i] = strfiletime(TIMEFIELDZEROS, timenum);
            continue;
          }
          if (timespec != "") {
            split(targettimes[i], convfields, "'$TIMESEPARATOR'");
            j = timecolsize;
            do {
              convfields[timecols[j]] = timefields[timecols[j]];
            } while (--j > 0);
            convtimes[i] = strfiletime(convfields, timenum);
            if (i > 1) {
              targetmarks[i] = targetmarks[1];
              continue;
            }
          } else {
            convtimes[i] = targettimes[i];
          }
          split(convtimes[i], timefields, "'$TIMESEPARATOR'");
          j = timecolsize;
          do {
            timefield = timefields[timecols[j]];
            split(timefield, timeval);
            for (k = 1; k <= 7; k++) {
              calctime(timeval, k, reltimeval[k]);
            }
            timefield = strtime(timeval, "'"$FIELDTIMEFORMAT"'");
            if (timefield !~ /^'"$DATEYEARREGEX"' /) {
              targetmarks[i] = ERRORMARK;
            }
            timefields[timecols[j]] = timefield;
          } while (--j > 0);
          convtimes[i] = strfiletime(timefields, timenum);
        }
        for (i = 1; i <= targetsize; i++) {
          if (targetmarks[i] != "") {
            targetstopped = '$errstopped';
          } else if (targettimes[i] == convtimes[i]) {
            targetmarks[i] = UNCHANGEDMARK;
          } else {
            if ('$targetnochange') {
              targetmarks[i] = CHANGECANDMARK;
            } else if ('$targetprompt') {
              targetmarks[i] = QUESTIONMARK;
              targetasked = 1;
            } else {
              targetmarks[i] = EXECUTEDMARK;
            }
            changedtimes[i] = convtimes[i];
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
            split(convtimes[i], timefields, "'$TIMESEPARATOR'");
            print disptarget(targetmark, targetwidth,
                             targetname, timecols, timefields) > deverr;
          }
          printf "Change the above file times ? (y/n): " > deverr;
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
            split(changedtimes[i], timefields, "'$TIMESEPARATOR'");
            if (status == 0 && \
                settime(targetname, timeoptc, timecols, timefields) != 0) {
              if (size > 0) {
                for (j = 1; j <= timecolsize; j++) {
                  timeoptc[j] = substr(timeorder, j, 1);
                }
                timeonceoptc[1] = timechars;
                while (--i > 0) {
                  targetname = targetnames[i];
                  if (targetname != "") {
                    split(targettimes[i], timefields, "'$TIMESEPARATOR'");
                    if (timefields[1] != timefields[2]) {
                      settime(targetname, timeoptc, timecols, timefields);
                    } else {
                      settime(targetname, timeonceoptc, timecols, timefields);
                    }
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
          split(convtimes[i], timefields, "'$TIMESEPARATOR'");
          print disptarget(targetmarks[i], targetwidth,
                           targetname, timecols, timefields) > devout;
          delete convtimes[i];
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
    awk -v tzname=${DATETZNAME:-???} -v deverr=$AWKSTDERR '
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function gefilename(nameoptc, namelen,  namecmd, name) {
        namecmd = "ls -tA" nameoptc;
        namecmd | getline name;
        if (namelen > 0) {
          while (namelen < length(name) && namecmd | getline) {
            name = name "\n" $0;
          }
        }
        close(namecmd);
        return name;
      }
      function gettime(target,  tmargv, tmcmd, tmutc, tmstr) {
        tmargv = cmdparam(target);
        tmstr = "'"$FIELDTIMEZERO"'";
        if ('$STATREFTIME' || '$LSREFTIME') {
          if ('$timeutc') {
            tmutc = "TZ= ";
          }
          tmcmd = tmutc "'"$GETTIME"' --" tmargv "'"$GETTIMEFILTER"'";
        } else {
          if ('$timeutc') {
            tmutc = " -u";
          }
          tmcmd = "date" tmutc " -r" tmargv " '\'+"$DATEFORMAT"\''";
        }
        tmcmd | getline tmstr;
        close(tmcmd);
        return tmstr;
      }
      function strtime(tm, tmfmt) {
        return sprintf(tmfmt, tm[1], tm[2], tm[3], tm[4], tm[5], tm[6], tm[7]);
      }
      function settime(target, tmoptc, tmstr,  tmargv, tmln, tmfmt, tm) {
        tmargv = cmdparam(parent);
        if (system("test -h " tmargv) == 0) {
          tmln = "h";
        }
        tmfmt = "'$TOUCHTIMEFORMAT'";
        if ('$timeutc') {
          tmfmt = tmfmt "Z";
        }
        split(tmstr, tm);
        return system("touch -" tmoptc tmln "'"$TOUCHTIMEOPTION"'" \
                      " " strtime(tm, tmfmt) " --" tmargv);
      }
      BEGIN {
        MONTH[1] = "Jan"; MONTH[2] = "Feb"; MONTH[3] = "Mar";
        MONTH[4] = "Apr"; MONTH[5] = "May"; MONTH[6] = "Jun";
        MONTH[7] = "Jul"; MONTH[8] = "Aug"; MONTH[9] = "Sep";
        MONTH[10] = "Oct"; MONTH[11] = "Nov"; MONTH[12] = "Dec";
        dirpath = ARGV[1];
        if (system("test -w ./") != 0) {
          printf "Permission denied -- %s\n", dirpath;
          exit;
        }
        parent = ARGV[2];
        fname = gefilename("q");
        if (index(fname, "?") > 0) {
          fname = gefilename("", length(fname));
        }
        ftime = gettime(fname);
        gsub(/[-:.]/, " ", ftime);
        if (ftime != "'"$FIELDTIMEZERO"'") {
          if ('${FBATCHSHDEBUG:-0}') {
            printf "%s  %s\n", ftime, fname > deverr;
          }
          if (settime(parent, "m", ftime) != 0) {
            exit 1;
          }
          if ('$timeutc') {
            tzname = "UTC";
          }
          split(ftime, timeval);
          printf "Modified at %s %2d %02d:%02d:%02d %s %4d -- %s\n",
                 MONTH[int(timeval[2])], timeval[3], timeval[4],
                 timeval[5], timeval[6], tzname, timeval[1], dirpath;
        }
      }' "${path%/}" "$(pwd -L)"
    ;;
  esac

  return $?
}

# Check the string and output elements of date and time separated by spaces.
# Its numbers are year, month, day, hour, minute, second, and nanosecond.
#
# $1 - 1 if the string is specified with ISO 8601 format, otherwise, 0
# $2 - the date and time string

REGEXYEAR=$DATEYEARREGEX
REGEXMONTH='(0[1-9]|1[0-2])'
REGEXDAY='[0-3][0-9]'
REGEXHOUR='([0-1][0-9]|2[0-3])'
REGEXMINUTE='[0-5][0-9]'
REGEXSECOND='[0-5][0-9]'

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
      if ('$1') {
        REGEXTIME = "^'$REGEXYEAR'-'$REGEXMONTH'-'$REGEXDAY'" \
                    "[T ]'$REGEXHOUR':'$REGEXMINUTE':'$REGEXSECOND'";
        REGEXSEC = "^[.,][0-9]+$";
      } else {
        REGEXTIME = "^'$REGEXYEAR$REGEXMONTH$REGEXDAY$REGEXHOUR$REGEXMINUTE'";
        REGEXSEC = "^\\.[0-5][0-9]$";
      }
      if (match(ARGV[1], REGEXTIME)) {
        timeargv = substr(ARGV[1], 1, RLENGTH);
        secargv = substr(ARGV[1], RLENGTH + 1);
        if (secargv != "") {
          if (secargv !~ REGEXSEC) {
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
          printf "'"$FIELDTIMEFORMAT"'", timeval[1], timeval[2], timeval[3],
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

# Return 0 if parameters are not empty and don't include LFs, otherwise, 1
#
# $@ - parameters checked whether are empty or include LFs

noemptylf(){
  return $( (echo 1; printf '%s\0' "$@") | \
            tr ' \0' '\t ' | \
            sed '1 { x; d; }; $ { /  / { x; p; }; d; }; x; q')
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

if [ $STATREFTIME = 0 -a $LSREFTIME = 0 -a $DATEREFTIME = 0 ]; then
  error 1 'this system is unsupported because of not referencing file date'
fi

actime=0
modtime=0
reftime=0
optchars='Acd:D:fFhilmrRS:t:T:v1'
longopts='all,no-change,classify,interactive,link,parent-recently,quiet,reference,recursive,resume-from:,skip-error,verbose,help,version'
if [ $FIELDATIME != 0 ]; then
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
  A|all)
    targetdot=1
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
    elif [ $DATEREFNSEC = 0 ] && \
         expr "${1#*=}" : '.*\.[0-9][0-9]*$' > /dev/null 2>&1; then
      error 1 'nanoseconds of file time is unsupported'
    fi
    ;;
  D)
    reltimespec=$(getreltime "${1#*=}")
    if [ -n "${1#*=}" ]; then
      if [ -z "$reltimespec" ]; then
        error 0 "invalid relative date string '${1#*=}'"
        usage 1
      elif [ $DATEREFNSEC = 0 ] && \
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
  F|classify)
    targetclassify=1
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
  quiet)
    targetquiet=1
    ;;
  r|reference)
    reftime=1
    ;;
  R|recursive)
    travsubdirs='*/'
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
  t)
    timespec=$(gettime 0 "${1#*=}")
    if [ -z "$timespec" ]; then
      error 0 "invalid time format '${1#*=}'"
      usage 1
    fi
    ;;
  T)
    targetregex=$(escbslash "${1#*=}")
    if [ -n "${1#*=}" ]; then
      if ! noemptylf "${1#*=}" || \
         ! awk -v r="$targetregex" 'BEGIN { match("", r) }' 2> /dev/null; then
        error 0 "unsupported awk's regular expression '${1#*=}'"
        usage 1
      fi
    fi
    ;;
  utc)
    timeutc=1
    ;;
  v|verbose)
    targetverbose=1
    ;;
  1)
    timelined=1
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

if [ $targetdot != 0 ]; then
  if [ -n "$travsubdirs" ]; then
    travsubdirs='.*/ '$travsubdirs
  fi
  targetentries='.* '$targetentries
fi

if [ $actime != 0 ]; then
  if [ $modtime = 0 ]; then
    timeorder='a'
  fi
elif [ $modtime != 0 ] || [ $DATEREFTIME != 0 ]; then
  timeorder='m'
fi

# Exit if no one of setting time options is specified

if [ $reftime = 0 -a -z "$timespec" ]; then
  exit 0
fi

# Change the modification or access time of files and subdirectories

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
