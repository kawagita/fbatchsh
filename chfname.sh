#!/bin/sh
#
# Change the name of files or directories.
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
AWKCASECHANGED=0

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
  AWKCASECHANGED=1
  if which cygpath > /dev/null 2>&1 || \
     which wslpath > /dev/null 2>&1; then
    FILECASESENSITIVE=0
  fi
fi

DATEREFTIME=0

STATREFTIME=0
STAT=""

if stat -f '%Sm' / > /dev/null 2>&1; then
  DATEREFTIME=1
  STATREFTIME=1
  STAT='stat -f %Sm -t'
elif date -r / > /dev/null 2>&1; then
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
  echo 'Set the name of files or directories in each DIR(s) by standard Unix commands.'
  echo
  echo '  -c, --no-change            do not change any files or directories'
  echo '      --capitalize=REGEX     capitalize all matches of REGEX'
  echo '  -d FORMAT                  append the modification time output with FORMAT'
  echo '  -e EXPRESSION              use EXPRESSION to replace file names'
  echo '  -f                         change the name of only files'
  echo '  -h                         change the name of symbolic links'
  echo '  -i, --interactive          prompt before change'
  echo '  -I, --ignore-extension     ignore file extension when the name is changed'
  echo '  -l, --link                 follow the symbolic link (with -R)'
  echo '  -n, --numbering            append sequential number'
  echo '  -N                         append sequential number for the same name'
  echo '      --number-start=NUM     use NUM for starting number instead of 1'
  echo '      --number-padding=NUM   use NUM for the maximum padding zeros'
  echo '  -p EXPRESSION              use EXPRESSION after adding date or number string'
  echo '  -R, --recursive            change the name in directories recursively'
  echo '  -S, --start-from PATH      resume traversing directories from PATH (with -R)'
  echo "      --skip-error           skip target's error in directory"
  echo '  -T REGEX                   find targets whose name matches REGEX in directory'
  echo '      --to-lowercase         convert whole name to lowercase'
  echo '      --to-uppercase         convert whole name to uppercase'
  echo '  -v, --verbose              show the list of targets in each directory'
  echo '      --help                 display this help and exit'
  echo '      --version              output version information and exit'
  echo
  echo 'REGEX is used by match function of awk script. FORMAT or EXPRESSION is followed'
  echo 'by -d or -e option of date or sed command. In details, see the manual.'
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
# $1 - the pathname of directory from which the traversal is started
# $2 - subdirectory patterns which end with a slash separated by spaces
# process the target in each directory by dirmain function with 0,
# move to subdirectories matching with the specified pattern and
# to the parent directory after calling dirmain function with 1,
# and return 1 or 2 if can't start or fail the traversal, otherwise, 0

travfirstpath=""
travlinkfollowed=0

dirtrav(){
  (if [ -n "$1" ]; then
     if ! cd -L -- "$1" 2> /dev/null; then
       exit 1
     fi
     path=${1%/}/
   else
     path='./'
   fi
   if cmpstr "$(pwd -L)" "$travfirstpath"; then
     travfirstpath=""
   fi
   depth=0
   subdir=$2
   set -- "$path"

   while true
   do
     if [ -z "$travfirstpath" ] && ! dirmain 0; then
       exit 2
     fi
     shift
     set -- $subdir / "$@"

     while true
     do
       if [ "$1" = '/' ]; then
         if [ -z "$travfirstpath" ] && ! dirmain 1; then
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
             if cmpstr "$(pwd -L)" "$travfirstpath"; then
               travfirstpath=""
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
# $depth - the depth of the current directory from the root of traversing
# $path - the pathname to the current directory
# return non-zero if can't process the target, otherwise, zero

targetregex=""
targetnochange=0
targetprompt=0
targetverbose=0
targetdir=1
targetsymlink=0
extignored=0
caseconv=0
capsregex=""
sedexpr=""
postexpr=""
datefmt=""
numfmt=""
numsamenamed=0
numstart=0
errstopped=1

dirmain(){
  case $1 in
  0)
    set -- *
    awk -v dirdepth=$depth -v targetregex="$targetregex" \
        -v caseconv=$caseconv -v capsregex="$capsregex" -v datefmt="$datefmt" \
        -v numfmt="$numfmt" -v numstart=$numstart '
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
      function showtarget(mark, width, target, dest, dev,  str, margin) {
        margin = width - dispwidth(target);
        gsub(/\n/, "&  ", target);
        str = sprintf("%s %s", mark, target);
        if (dest != "") {
          gsub(/\n/, "&" sprintf("  %" width "s    ", ""), dest);
          str = str sprintf("%" margin "s -> %s", "", dest);
        }
        print str > dev;
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
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function getdate(target, datefmt,  datecmd) {
        if (datefmt != "") {
          if ('$STATREFTIME') {
            datecmd = "'"$STAT"'" cmdparam(datefmt) cmdparam(target);
          } else {
            datecmd = "date -r" cmdparam(target) cmdparam("+" datefmt);
          }
          datecmd | getline;
          close(datecmd);
          return $0;
        }
        return "";
      }
      function setname(target, mvopt, dest) {
        return system("mv" mvopt " --" cmdparam(target) cmdparam(dest));
      }
      function rename(name, sedexpr,  sedcmd) {
        if (sedexpr != "") {
          sedcmd = "printf '\'%s\''" cmdparam(name) " | sed " cmdparam(sedexpr);
          sedcmd | getline name;
          while (sedcmd | getline) {
            name = name "\n" $0;
          }
          close(sedcmd);
        }
        return name;
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
        if (dirdepth > 0) {
          dirbreak = "\n";
        }
        dirwrite = system("test ! -w ./");
        num = numstart;
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
              ('$targetdir' || system("test -f" cmdparam(fname)) == 0) && \
              ('$targetsymlink' || system("test ! -h" cmdparam(fname)) == 0)) {
            targetnames[targetsize] = fname;
            targetindexes[targetsize] = i;
            if (++targetsize > 1) {
              pl = "s";
            }
            width = dispwidth(fname);
            if (targetwidth < width) {
              targetwidth = width;
            }
          }
        }
        printf dirbreak "%s:\n%d target%s\n", dirpath, targetsize, pl > devout;
        targetstopped = 0;
        targetasked = 0;
        for (i = 0; i < targetsize; i++) {
          targetname = targetnames[i];
          targetindex = targetindexes[i];
          delete targetindexes[i];
          if (! dirwrite) {
            targetmarks[i] = ERRORMARK;
            targetstopped = '$errstopped';
            continue;
          }
          if ('$extignored' && \
              match(targetname, /(\.[0-9A-Za-z]+)?\.[0-9A-Za-z]+$/) && \
              RSTART > 1) {
            name = substr(targetname, 1, RSTART - 1);
            ext = substr(targetname, RSTART);
          } else {
            name = targetname;
            ext = "";
          }
          name = rename(name, "'"$sedexpr"'");
          if (caseconv > 0) {
            name = toupper(name);
          } else if (caseconv < 0) {
            name = tolower(name);
          }
          name = capitalize(name, capsregex) getdate(targetname, datefmt);
          if (numfmt != "") {
            if ('$numsamenamed') {
              num = filenum[name];
              if (num == "") {
                num = numstart;
              }
              num++;
              filenum[name] = num;
            } else {
              num++;
            }
            name = name sprintf(numfmt, num);
          }
          destname = rename(name, "'"$postexpr"'") ext;
          if (destname == targetname) {
            targetmarks[i] = UNCHANGEDMARK;
            continue;
          }
          destindex = indexof(destnames, destname);
          fileindex = indexof(ARGV, destname);
          destnames[i] = destname;
          if (index(destname, "/") > 0 || \
              destindex > 0 || (fileindex > 0 && fileindex != targetindex)) {
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
          delete ARGV[targetindex];
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
              showtarget(targetmark, targetwidth, targetnames[i],
                         destnames[i], "'$AWKSTDERR'");
            }
          }
          printf "Change the above file names ? (y/n): " > "'$AWKSTDERR'";
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
            destname = destnames[i];
            if (targetmark == EXECUTEDMARK) {
              if (status == 0 && setname(targetname, "", destname) != 0) {
                if (size > 0) {
                  while (--i >= 0) {
                    if (targetnames[i] != "") {
                      setname(destnames[i], " -f", targetnames[i]);
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
            showtarget(targetmark, targetwidth, targetname, destname, devout);
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
    ;;
  esac

  return $?
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

padding=0
subdir=""
optchars='cd:e:fhiIlnNp:RS:T:v'
longopts='no-change,capitalize:,interactive,ignore-extension,link,numbering,number-start:,number-padding:,recursive,start-from:,skip-error,to-lowercase,to-uppercase,verbose,help,version'
argval=$(getopt "$optchars" "$longopts" "$@")
eval set -- "$argval"

while [ $# != 0 ]
do
  case ${1%%=*} in
  c|no-change)
    targetnochange=1
    ;;
  capitalize)
    if [ $AWKCASECHANGED = 0 ]; then
      error 0 'the function to uppercase or lowercase is unsupported'
      usage 1
    fi
    capsregex=$(escbslash "${1#*=}")
    if ! (awk -v r="$capsregex" 'BEGIN { match("", r) }' 2>&1 | \
          awk '{ exit 1 }'); then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    ;;
  d)
    if [ $DATEREFTIME = 0 ]; then
      error 0 'the reference of file date is unsupported'
      usage 1
    elif [ -n "${1#*=}" ]; then
      datefmt=$(escbslash "${1#*=}")
      if ! awk '
             function cmdparam(param) {
               gsub(/'\''/, "'\''\\\\&'\''", param);
               return " '\''" param "'\''";
             }
             BEGIN {
               if ('$STATREFTIME') {
                 datecmd = "'"$STAT"'" cmdparam(ARGV[1]) " /";
               } else {
                 datecmd = "date -r / " cmdparam("+" ARGV[1]);
               }
               if (! (datecmd | getline) || (datecmd | getline)) {
                 exit 1;
               }
             }' "$datefmt" 2> /dev/null; then
        error 0 "unsupported date format '${1#*=}'"
        usage 1
      fi
    fi
    ;;
  e)
    if ! (echo | sed "${1#*=}" > /dev/null 2>&1); then
      error 0 "unsupported sed expression '${1#*=}'"
      usage 1
    fi
    sedexpr=$(escbslash "${1#*=}")
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
  I|ignore-extension)
    extignored=1
    ;;
  l|link)
    travlinkfollowed=1
    ;;
  n|numbering)
    numfmt='%d'
    ;;
  N)
    numsamenamed=1
    numfmt='%d'
    ;;
  number-start)
    if [ "${1#*=}" != 0 ] && \
       ! expr "${1#*=}" : '[1-9][0-9]*$' > /dev/null 2>&1; then
      error 0 "invalid number start '${1#*=}'"
      usage 1
    fi
    numstart=$((${1#*=} - 1))
    ;;
  number-padding)
    if [ "${1#*=}" != 0 ] && \
       ! expr "${1#*=}" : '[1-9][0-9]*$' > /dev/null 2>&1; then
      error 0 "invalid padding width '${1#*=}'"
      usage 1
    fi
    padding=${1#*=}
    ;;
  p)
    if ! (echo | sed "${1#*=}" > /dev/null 2>&1); then
      error 0 "unsupported sed expression '${1#*=}'"
      usage 1
    fi
    postexpr=$(escbslash "${1#*=}")
    ;;
  R|recursive)
    subdir='*/'
    ;;
  S|start-from)
    travfirstpath=$(if cd "${1#*=}" 2> /dev/null; then
                      pwd -L
                    fi)
    if [ -z "$travfirstpath" ]; then
      error 1 "${1#*=}: No such directory"
    fi
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
    if [ $AWKCASECHANGED = 0 ]; then
      error 0 'the function to uppercase or lowercase is unsupported'
      usage 1
    fi
    caseconv=-1
    ;;
  to-uppercase)
    if [ $AWKCASECHANGED = 0 ]; then
      error 0 'the function to uppercase or lowercase is unsupported'
      usage 1
    fi
    caseconv=1
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

if [ "$numfmt" != "" -a $padding != 0 ]; then
  numfmt="%0${padding}d"
fi

# Exit if one of rename options is specified

if [ $caseconv = 0 -a -z "$capsregex" -a -z "$sedexpr" -a -z "$postexpr" -a \
     -z "$datefmt" -a -z "$numfmt" ]; then
  exit
fi

# Change the name of files or directories

while [ $# != 0 ]
do
  if [ -d "$1" -o -z "${1%%*/}" ]; then
    dirtrav "$1" "$subdir"
    status=$?
    case $status in
    0) ;;
    1) error 0 "${1%/}: Permission denied";;
    *) exit $status;;
    esac
  else
    error 1 "$1: Is not a directory"
  fi
  shift
done
