#!/bin/sh
#
# List the time information about directory contents.
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
PROGRAM='lsftime'
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
TIMESHORTFORMAT='%04d-%02d-%02dT%02d:%02d'
TIMESEPARATOR='/'

FIELDTIMEFORMAT='%04d %02d %02d %02d %02d %02d 000000000'
FIELDTIMEZERO=$(printf "$FIELDTIMEFORMAT" 0 0 0 0 0 0)
FIELDSEPARATOR=','
FIELDMTIME=1
FIELDATIME=2
FIELDCTIME=3
FIELDBTIME=0
FIELDTIMECHARS='mac'

DATEREFTIME=0
DATEREFNSEC=0
DATEFORMAT='%Y %m %d %H %M %S 000000000'
DATETZNUM=$(date +%z 2> /dev/null | sed '/^[-+][0-9][0-9][0-9][0-9]$/!d')

if date -r / "+$DATEFORMAT" > /dev/null 2>&1; then
  DATEREFTIME=1
fi
if expr $(date '+%N') : '[0-9][0-9]*$' > /dev/null 2>&1; then
  DATEREFNSEC=1
  DATEFORMAT=${DATEFORMAT% 0*}' %N'
fi

STATREFTIME=0
STATREFBTIME=0
STAT=""
STATFILTER=""

if which stat > /dev/null 2>&1; then
  STATREFTIME=1
  if stat -c '%y' / > /dev/null 2>&1; then
    STAT='stat -c '$(printf "%s$FIELDSEPARATOR" '%y' '%x' '%z')
    if stat -c '%w' / | awk '$0 == "-" { exit 1 }'; then
      STATREFBTIME=1
      STAT=$STAT'%w'$FIELDSEPARATOR
    fi
    STAT=$STAT'%F'
    STATFILTER=" | sed 's/ [-+][0-9][0-9][0-9][0-9]//g; s/[-.:]/ /g'"
  elif stat -f '%Sm' / > /dev/null 2>&1; then
    STAT="stat -t +'$DATEFORMAT' -f "
    STAT=$STAT$(printf "%s$FIELDSEPARATOR" '%Sm' '%Sa' '%Sc')
    if stat -f '%SB' / > /dev/null 2>&1; then
      STATREFBTIME=1
      STAT=$STAT'%SB'$FIELDSEPARATOR
    fi
    STAT=$STAT'%HT'
  fi
fi

LSREFTIME=0
LSOPTION=""
LSTIMEOPTCHARS='c u a'
LSFILTER=" | sed 's/ [-+][0-9][0-9][0-9][0-9].*//'"

if ls --full-time / > /dev/null 2>&1; then
  LSREFTIME=1
  LSOPTION=' --full-time -dq'
elif ls -E / > /dev/null 2>&1; then
  LSREFTIME=1
  LSOPTION=' -Edq'
fi

if [ ${DEBUGFBATCHSH:-0} -ge 2 ]; then
  STATREFTIME=0
  if [ ${DEBUGFBATCHSH:-0} -ge 3 ]; then
    LSREFTIME=0
  fi
fi

if [ $STATREFTIME != 0 ]; then
  if [ $STATREFBTIME != 0 ]; then
    FIELDBTIME=4
    FIELDTIMECHARS='macb'
  fi
  DATEREFTIME=0
elif [ $LSREFTIME != 0 ]; then
  DATEREFTIME=0
else
  FIELDATIME=0
  FIELDCTIME=0
  FIELDTIMECHARS='m'
  LSOPTION=' -ldq'
  LSTIMEOPTCHARS='a'
  LSFILTER=" | sed 's/ .*$//'"
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
  echo 'List the time information about contents in each DIR(s) by Unix commands.'
  echo
  echo '  -a, --all                  do not ignore entries starting with .'
  echo '  -A, --almost-all           do not list implied . and ..'
  if [ $FIELDBTIME != 0 ]; then
    echo '  -b INTERVAL                find entries which were created between INTERVAL'
  fi
  if [ $FIELDCTIME != 0 ]; then
    echo '  -c INTERVAL                find entries whose status was changed lastly'
    echo '                               between INTERVAL'
  fi
  echo '  -f                         list time information of only regular files'
  echo '  -F, --classify             append indicator (one of */=@|) to entries'
  echo '  -h                         list time information of symbolic links'
  echo '  -i, --interactive          prompt after list in each directory'
  echo '  -l, --link                 follow the symbolic link (with -R)'
  echo '  -m INTERVAL                find entries which were modified between INTERVAL'
  if [ $FIELDATIME != 0 ]; then
    echo '      --order=CHARS          show times in order specified by CHARS:'
    echo '                               m (modify time); a (access time);'
    if [ $FIELDBTIME != 0 ]; then
      echo '                               c (status change time); b (birth time)'
    else
      echo '                               c (status change time)'
    fi
  fi
  echo '  -r, --reverse              reverse order while sorting'
  echo '  -R, --recursive            list subdirectories recursively'
  echo '  -S, --resume-from=PATH     resume traversing directories from PATH (with -R)'
  echo '  -t                         sort by a time following the name, newest first'
  echo '  -T REGEX                   target directory entries whose names match REGEX'
  if [ $FIELDATIME != 0 ]; then
    echo '  -u INTERVAL                find entries which were accessed between INTERVAL'
  fi
  echo '      --utc                  list Coordinated Universal Time (UTC)'
  echo '  -v, --verbose              print subdirectories without target'
  echo '  -1                         print time information per line'
  echo '      --help                 display this help and exit'
  echo '      --version              output version information and exit'
  echo
  echo 'INTERVAL is the time interval which consists of start and end times separated'
  echo 'by a slash. If its are not empty, must be specified with YYYY-MM-DDThh:mm:ss of'
  echo 'ISO 8601 format. However, lower order elements can be omitted and any elements'
  echo 'missing from end value is the same as start.'
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
targetall=0
targetprompt=0
targetverbose=0
targetdir=1
targetsymlink=0
targetclassify=0
timeutc=0
timelined=0
timeorder=${FIELDTIMECHARS%b}
timesort=0
timereverse=0
mtimeinteval=""
atimeinteval=""
ctimeinteval=""
btimeinteval=""
termcols=$(tput cols)
errstopped=1

dirmain(){
  case $1 in
  0)
    set -- $targetentries
    awk -v dircount=$count -v dirdepth=$depth -v targetregex="$targetregex" \
        -v timechars=$FIELDTIMECHARS -v timeorder=$timeorder -v timeperline=1 \
        -v atimeinteval="$atimeinteval" -v mtimeinteval="$mtimeinteval" \
        -v ctimeinteval="$ctimeinteval" -v btimeinteval="$btimeinteval" \
        -v maxwidth=${termcols:-80} -v devout=$AWKSTDOUT -v deverr=$AWKSTDERR '
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
            tmfmt = tmfmt " " "'$DATETZNUM'";
          }
          tmfmt = sprintf(" %-6s: ", tmlabel) tmfmt;
        }
        split(tmstr, tm);
        return sprintf(tmfmt, tm[1], tm[2], tm[3], tm[4], tm[5], tm[6], tm[7]);
      }
      function disptarget(width, target, tmcols, tmstrs,  str, margin, num) {
        TIMELABEL['$FIELDMTIME'] = "Modify";
        TIMELABEL['$FIELDATIME'] = "Access";
        TIMELABEL['$FIELDCTIME'] = "Change";
        TIMELABEL['$FIELDBTIME'] = "Birth";
        margin = width - dispwidth(target);
        if (margin < 0) {
          margin = 0;
        }
        str = target sprintf("%" margin "s ", "");
        num = 1;
        while (tmcols[num] != "") {
          if (! '$timelined' && str !~ / $/) {
            str = str sprintf("\n%" width "s ", "");
          }
          str = str disptime('$timelined',
                             tmstrs[tmcols[num]], TIMELABEL[tmcols[num]]);
          num++;
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
      function getstat(data, statargv,  statcmd, size) {
        statcmd = "LANG= '"$STAT"' --" statargv "'"$STATFILTER"'";
        if ('$timeutc') {
          statcmd = "TZ= " statcmd;
        }
        size = 1;
        while (statcmd | getline) {
          data[size++] = $0;
        }
        close(statcmd);
      }
      function getls(data, lsargv,  lscmd, tmoptc, tmstr, size, num) {
        num = split("'"$LSTIMEOPTCHARS"'", tmoptc);
        while (tmoptc[num] != "") {
          lscmd = "ls'"$LSOPTION"'" tmoptc[num--] " --" lsargv "'"$LSFILTER"'";
          if ('$timeutc') {
            lscmd = "TZ= " lscmd;
          }
          size = 1;
          while (lscmd | getline) {
            if (NF > 1) {
              tmstr = $(NF - 1) " " $NF;
              gsub(/[-:.]/, " ", tmstr);
              data[size] = data[size] tmstr "'$FIELDSEPARATOR'";
            }
            if (num == 0) {
              data[size] = data[size] substr($1, 1, 1);
            }
            size++;
          }
          close(lscmd);
        }
      }
      function getdate(dateargv,  datecmd, datetime) {
        datecmd = "date";
        if ('$timeutc') {
          datecmd = datecmd " -u";
        }
        datecmd = cmdnoerror(datecmd " -r" dateargv " '\'+"$DATEFORMAT"\''");
        if (datecmd | getline) {
          datetime = $0;
        } else {
          datetime = "'"$FIELDTIMEZERO"'";
        }
        close(datecmd);
        return datetime "'$FIELDSEPARATOR'";
      }
      function cmptime(tm, tmstr, val,  tm2, ind) {
        if (split(tmstr, tm2) > 0) {
          for (ind = 1; ind <= 7; ind++) {
            val = int(tm[ind]) - int(tm2[ind]);
            if (val != 0) {
              break;
            }
          }
        }
        return val;
      }
      BEGIN {
        dirpath = ARGV[1];
        if (dircount > 1 || dirdepth > 0) {
          dirbreak = "\n";
        }
        timecolsize = length(timeorder);
        for (i = 1; i <= timecolsize; i++) {
          timecolumns[i] = index(timechars, substr(timeorder, i, 1));
        }
        timeintevals['$FIELDMTIME'] = mtimeinteval;
        timeintevals['$FIELDATIME'] = atimeinteval;
        timeintevals['$FIELDCTIME'] = ctimeinteval;
        timeintevals['$FIELDBTIME'] = btimeinteval;
        timewidth = length(disptime('$timelined', "0 0 0 0 0 0 000000000"));
        if ('$timelined') {
          timeperline = timecolsize;
        }
        maxwidth -= timewidth * timeperline + 2;
        fieldsize = length(timechars) + 1;
        delete ARGV[1];
        targetwidth = 0;
        targetsize = 0;
        for (i = 2; i < ARGC; i++) {
          if (ARGV[i] ~ targetregex && \
              ((ARGV[i] != "." && ARGV[i] != "..") || '$targetall') && \
              (ARGV[i] != "*" || system("test -e" cmdparam("*")) == 0)) {
            fnames[++fsize] = ARGV[i];
          }
          delete ARGV[i];
        }
        if (fsize > 0) {
          for (i = 1; i <= fsize; i++) {
            cmdargv = cmdargv cmdparam(fnames[i]);
          }
          if ('$STATREFTIME') {
            getstat(fdata, cmdargv);
          } else {
            getls(fdata, cmdargv);
          }
          for (i = 1; i <= fsize; i++) {
            fname = fnames[i];
            delete fnames[i];
            if ('$DATEREFTIME') {
              fdata[i] = getdate(cmdparam(fname)) fdata[i];
            }
            if ('${DEBUGFBATCHSH:-0}') {
              printf "%-'${termcols:-80}'s%s\n", fdata[i] "  ", fname > deverr;
            }
            if (sub(/([Dd]irectory|d)$/, "/", fdata[i])) {
              if (! '$targetdir') {
                continue;
              }
            } else if (sub(/([Ss]ymbolic [Ll]ink|l)$/, "@", fdata[i])) {
              if (! '$targetsymlink' || \
                  (! '$targetdir' && system("test -d" cmdparam(fname)) == 0)) {
                continue;
              }
            } else if (! sub(/([Rr]egular .*|-)$/, "", fdata[i])) {
              if (! '$targetall') {
                continue;
              }
              sub(/([Ss]ocket|s)$/, "=", fdata[i]);
              sub(/([Ff][Ii][Ff][Oo]|p)$/, "|", fdata[i]);
              sub(/[^'$FIELDSEPARATOR']+$/, "", fdata[i]);
            }
            split(fdata[i], fieldinfo, "'$FIELDSEPARATOR'");
            timeover = 0;
            for (field = 1; field < fieldsize; field++) {
              split(fieldinfo[field], timeval);
              split(timeintevals[field], timerange, "'$TIMESEPARATOR'");
              if (cmptime(timeval, timerange[1], 1) < 0 || \
                  cmptime(timeval, timerange[2], -1) > 0) {
                timeover = 1;
                break;
              }
            }
            if (! timeover) {
              ftime = fieldinfo[1];
              for (field = 2; field < fieldsize; field++) {
                ftime = ftime "'$TIMESEPARATOR'" fieldinfo[field];
              }
              ftype = fieldinfo[fieldsize];
              targetnames[targetsize] = fname;
              targettimes[targetsize] = ftime;
              targetindicators[targetsize] = ftype;
              if (++targetsize > 1) {
                pl = "s";
              }
              if ('$targetclassify') {
                fname = fname ftype;
              }
              width = dispwidth(fname);
              if (targetwidth < width) {
                if (width > maxwidth) {
                  targetwidth = maxwidth;
                } else {
                  targetwidth = width;
                }
              }
            }
          }
        }
        if (targetsize == 0 && ! '$targetverbose') {
          exit 0;
        }
        printf dirbreak "%s:\n%d target%s\n", dirpath, targetsize, pl;
        if ('$timesort') {
          sortfield = timecolumns[1];
          sortindexes[0] = 0;
          for (targetindex = 1; targetindex < targetsize; targetindex++) {
            split(targettimes[targetindex], timestrs, "'$TIMESEPARATOR'");
            split(timestrs[sortfield], timeval);
            for (i = 0; i < targetindex; i++) {
              split(targettimes[sortindexes[i]], timestrs, "'$TIMESEPARATOR'");
              if ('$timereverse') {
                if (cmptime(timeval, timestrs[sortfield]) < 0) {
                  break;
                }
              } else if (cmptime(timeval, timestrs[sortfield]) > 0) {
                break;
              }
            }
            for (lowerindex = targetindex - 1; lowerindex >= i; lowerindex--) {
              sortindexes[lowerindex + 1] = sortindexes[lowerindex];
            }
            sortindexes[i] = targetindex;
          }
        }
        for (i = 0; i < targetsize; i++) {
          if ('$timesort') {
            targetindex = sortindexes[i];
          } else {
            targetindex = i;
          }
          targetname = targetnames[targetindex];
          split(targettimes[targetindex], timestrs, "'$TIMESEPARATOR'");
          if ('$targetclassify') {
            targetname = targetname targetindicators[targetindex];
          }
          print disptarget(targetwidth, targetname, timecolumns, timestrs);
        }
        if ('$targetprompt') {
          printf "Continue to list the file times ? (y/n): " > deverr;
          status = system("read ans; case $ans in [Yy]);; *) exit 1;; esac");
          if (status != 0) {
            if (status > 1) {
              print "" > deverr;
            }
            exit status;
          }
        }
      }' "${path%/}" "$@"
    ;;
  1)
    ;;
  esac

  return $?
}

# Check the string and output a time interval which consists of start and end
# times separated by a slash. Time is elements of the date and time separated
# by spaces. Its numbers are year, month, day, hour, minute, and second.
#
# $1 - the date and time string of ISO 8601 format

REGEXYEAR='[0-9][0-9][0-9][0-9]'
REGEXMONTH='(0[1-9]|1[0-2])'
REGEXDAY='[0-3][0-9]'
REGEXHOUR='([0-1][0-9]|2[0-3])'
REGEXMINUTE='[0-5][0-9]'
REGEXSECOND='[0-5][0-9]'

getinterval(){
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
    function strtime(tm, val) {
      if (tm[1] != "") {
        if (tm[2] == "") {
          tm[2] = val;
        }
        if (tm[3] == "") {
          if (val == 1) {
            tm[3] = val;
          } else {
            tm[3] = mdays(int(tm[1]), int(tm[2]));
          }
        }
        return sprintf ("'"$FIELDTIMEFORMAT"'",
                        tm[1], tm[2], tm[3], tm[4], tm[5], tm[6]);
      }
      return "";
    }
    function cmptime(tmstr1, tmstr2, val,  tm1, tm2, ind) {
      if (split(tmstr1, tm1) > 0 && split(tmstr2, tm2) > 0) {
        for (ind = 1; ind <= 7; ind++) {
          val = int(tm1[ind]) - int(tm2[ind]);
          if (val != 0) {
            break;
          }
        }
      }
      return val;
    }
    function gettime(tmargv, tm, tmorg,  ind) {
      if (tmargv != "") {
        REGEXTIME[4] = "'$REGEXHOUR':'$REGEXMINUTE'(:'$REGEXSECOND')?";
        REGEXTIME[3] = "'$REGEXDAY'([T ]" REGEXTIME[4] ")?";
        REGEXTIME[2] = "'$REGEXMONTH'-" REGEXTIME[3];
        REGEXTIME[1] = "'$REGEXYEAR'(-'$REGEXMONTH'(-" REGEXTIME[3] ")?)?";
        FULLFORMAT[4] = "%s %s %s ";
        FULLFORMAT[3] = "%s %s ";
        FULLFORMAT[2] = "%s ";
        for (ind = 4; ind > 0; ind--) {
          if (tmargv ~ "^" REGEXTIME[ind] "$") {
            break;
          }
        }
        if (tmorg[ind] == "") {
          return 1;
        }
        gsub(/[^0-9]/, " ", tmargv);
        tmargv = sprintf(FULLFORMAT[ind], tmorg[1], tmorg[2], tmorg[3]) tmargv;
        split(tmargv, tm);
      }
      return 0;
    }
    BEGIN {
      timeval[1] = "2020";
      if (split(ARGV[1], timerange, "/") == 2 && \
          gettime(timerange[1], starttimeval, timeval) == 0 && \
          gettime(timerange[2], endtimeval, starttimeval) == 0) {
        starttime = strtime(starttimeval, 1);
        endtime = strtime(endtimeval, 12);
        if (cmptime(starttime, endtime, 0) <= 0) {
          printf "%s'$TIMESEPARATOR'%s", starttime, endtime;
        }
      }
    }' "$1"
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

dotfile=0
optchars='aAfFhilm:rRS:tT:v1'
longopts='all,almost-all,classify,interactive,link,reverse,recursive,resume-from:,utc,verbose,help,version'
if [ $FIELDATIME != 0 ]; then
  optchars=${optchars}'u:'
  longopts=${longopts}',order:'
fi
if [ $FIELDCTIME != 0 ]; then
  optchars=${optchars}'c:'
fi
if [ $FIELDBTIME != 0 ]; then
  optchars=${optchars}'b:'
fi
argval=$(getopt "$optchars" "$longopts" "$@")
eval set -- "$argval"

while [ $# != 0 ]
do
  case ${1%%=*} in
  a|all)
    targetall=1
    dotfile=1
    ;;
  A|almost-all)
    dotfile=1
    ;;
  b)
    btimeinteval=$(getinterval "${1#*=}")
    if [ -z "$btimeinteval" ]; then
      error 0 "invalid time interval -- ${1#*=}"
      usage 1
    fi
    ;;
  c)
    ctimeinteval=$(getinterval "${1#*=}")
    if [ -z "$ctimeinteval" ]; then
      error 0 "invalid time interval -- ${1#*=}"
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
  l|link)
    travlinkfollowed=1
    ;;
  m)
    mtimeinteval=$(getinterval "${1#*=}")
    if [ -z "$mtimeinteval" ]; then
      error 0 "invalid time interval -- ${1#*=}"
      usage 1
    fi
    ;;
  order)
    timeorder=$(awk '
                  BEGIN {
                    for (i = length(ARGV[1]); i > 0; i--) {
                      c = substr(ARGV[1], i, 1);
                      if (index("'$FIELDTIMECHARS'", c) == 0 || order[c] > 0) {
                        exit;
                      }
                      order[c] = i;
                    }
                    printf "%s", ARGV[1];
                  }' "${1#*=}")
    if [ -z "$timeorder" ]; then
      error 0 "invalid order characters -- ${1#*=}"
      usage 1
    fi
    ;;
  r|reverse)
    timesort=1
    timereverse=1
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
    ;;
  t)
    timesort=1
    ;;
  T)
    targetregex=$(escbslash "${1#*=}")
    if ! (awk -v r="$targetregex" 'BEGIN { match("", r) }' 2>&1 | \
          awk '{ exit 1 }'); then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    ;;
  u)
    atimeinteval=$(getinterval "${1#*=}")
    if [ -z "$atimeinteval" ]; then
      error 0 "invalid time interval -- ${1#*=}"
      usage 1
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

if [ $dotfile != 0 ]; then
  if [ -n "$travsubdirs" ]; then
    travsubdirs='.*/ '$travsubdirs
  fi
  targetentries='.* '$targetentries
fi

# List the time informaion about files and subdirectories

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
    1) error 1 "${1%/}: Permission denied";;
    *) exit $status;;
    esac
  else
    error 1 "$1: Is not a directory"
  fi
  shift
done
