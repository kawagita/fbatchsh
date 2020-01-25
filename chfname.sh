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
  echo 'Set the name of files or directories in each DIR(s) by some commands.'
  echo
  echo '  -c, --no-change            do not change any files'
  echo '  -C REGEX                   capitalize the match of REGEX'
  echo '  -d FORMAT                  append the modification time output with FORMAT'
  echo '  -e EXPRESSION              use EXPRESSION to replace file names'
  echo '  -f                         change the name of only files'
  echo '  -i, --interactive          prompt before changing file names'
  echo '  -I, --ignore-extension     ignore file extension when the name is changed'
  echo '  -l, --link                 follow the symbolic link (with -R or -r)'
  echo '  -n, --numbering            append sequential number'
  echo '  -N                         append sequential number for the same name'
  echo '      --number-start=NUM     use NUM for starting number instead of 1'
  echo '      --padding=WIDTH        set padding zeros with maximum WIDTH'
  echo '  -p, --pattern=PATTERN      change for files whose name matches PATTERN'
  echo '  -P EXPRESSION              use EXPRESSION after adding date or number string'
  echo '  -R, -r                     change in the directory recursively'
  echo '      --to-lowercase REGEX   convert the match of REGEX to lowercase'
  echo '      --to-uppercase REGEX   convert the match of REGEX to uppercase'
  echo '      --help                 display this help and exit'
  echo '      --version              output version information and exit'
  echo
  echo 'REGEX is used by match function of awk script. FORMAT or EXPRESSION is followed'
  echo 'by -d or -e switch of date or sed command. In details, see the manual.'
  echo
  echo 'PATTEN is matched with file or directory names in the bourne shell. This is not'
  echo 'parsed as regular expression. ? match any character and * is used as wildcard.'
  echo 'The match of characters or ranges can be specified between [ and ].'
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

# Traverse the directory recursively
#
# $1 - non-zero if the symbolic link to is followed, otherwise, zero
# $2 - the pathname of directory from which the traversal is started
# $3 - subdirectory patterns which end with a slash separated by spaces
# process the target in each directory by dirmain function with 0,
# move to subdirectories matching with the specified pattern and
# to the parent directory after calling dirmain function with 1,
# and return 1 or 2 if can't start or fail the traversal, otherwise, 0

dirtrav(){
  (link=$1
   if [ -n "$2" ]; then
     if ! cd -L -- "$2" 2> /dev/null; then
       exit 1
     fi
     path=${2%/}/
   else
     path=""
   fi
   subdir=$3
   set -- "$path"

   while true
   do
     if ! dirmain 0; then
       exit 2
     fi
     shift
     set -- $subdir / "$@"

     while true
     do
       if [ "$1" = '/' ]; then
         if ! dirmain 1; then
           exit 2
         fi
         path=/$path
         path=${path%/*/}/
         path=${path#/}
         if [ $# = 1 ]; then
           exit 0
         fi
         cd -L ..
       elif [ "$1" != './' -a "$1" != '../' ]; then
         if [ ! -h "${1%/}" ] || \
            ([ $link != 0 ] && \
             cd -- "$1" 2> /dev/null && \
             printf "%s\0" "$(pwd -P)" "$(pwd -L)" | \
             tr '\0\n' '\n\0' | \
             sed 'N
                  s/^\(.*\)\n\1\/.*$/1/; t
                  s/^.*$/0/' | \
             awk '{ exit $0 }'); then
           if cd -- "$1" 2> /dev/null; then
             path=$path$1
             break
           fi
         fi
       fi
       shift
     done
   done)

   return $?
}

# Process target files or subdirectories in the directory
#
# $1 - non-zero if called before return to the parent directory, otherwise, zero
# $path - the pathname to the current directory if called from dirtrav function
# return non-zero if can't process the target, otherwise, zero

target=""
targetopt='-e'
targetnoext=0
regexcapital=""
regextoupper=""
regextolower=""
sedexpr=""
postexpr=""
datefmt=""
numsameflag=0
numfmt=""
numstart=0
nochgflag=0
readflag=0

dirmain(){
  case $1 in
  0)
    ;;
  1)
    set -- ${target:-*}
    fnamelink=$(printf "%s/" "$@")
    awk -v path="${path#[.]/}" -v fnamelink="${fnamelink%/}" \
    -v regexcapital="$regexcapital" \
    -v regextoupper="$regextoupper" \
    -v regextolower="$regextolower" \
    -v datefmt="$datefmt" -v numfmt="$numfmt" -v numstart=$numstart \
    -v sedexpr="$sedexpr" -v postexpr="$postexpr" '
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function getdate(fname, datefmt,  datecmd) {
        if (datefmt != "") {
          datecmd = "date -r" cmdparam(fname) cmdparam("+" datefmt);
          datecmd | getline;
          close(datecmd);
          return $0;
        }
        return "";
      }
      function rename(name, sedexpr,  sedcmd) {
        if (sedexpr != "") {
          sedcmd = "echo" cmdparam(name) " | sed " cmdparam(sedexpr);
          sedcmd | getline name;
          while (sedcmd | getline) {
            name = name "\n" $0;
          }
          close(sedcmd);
        }
        return name;
      }
      function tocase(flag, name, regex,  rstr) {
        if (match(name, regex) && RLENGTH > 0) {
          rstr = substr(name, RSTART, RLENGTH);
          if (flag > 0) {
            rstr = toupper(rstr);
          } else if (flag < 0) {
            rstr = tolower(rstr);
          } else {
            rstr = toupper(substr(rstr, 1, 1)) tolower(substr(rstr, 2));
          }
          return substr(name, 1, RSTART - 1) rstr \
                 substr(name, RSTART + RLENGTH);
        }
        return name;
      }
      BEGIN {
        targetlen = 0;
        fnamelen = split(fnamelink, fnames, "/");
        for (i = 1; i <= fnamelen; i++) {
          if (system("test '$targetopt'" cmdparam(fnames[i])) == 0 &&
              system("test -w" cmdparam(fnames[i])) == 0) {
            targetlen++;
          } else {
            fnames[i] = "";
          }
        }
        if (targetlen == 0) {
          exit;
        } else if (path != "") {
          printf "%s:\n", path;
        }
        if ('$readflag' || '$nochgflag') {
          indicator = "->";
        } else {
          indicator = "=>";
        }
        num = numstart;
        for (i = 1; i <= fnamelen; i++) {
          fname = fnames[i];
          if (fname != "") {
            if ('$targetnoext' && match(fname, /\.[0-9A-Za-z]+$/)) {
              name = substr(fname, 1, RSTART - 1);
              ext = substr(fname, RSTART);
            } else {
              name = fname;
              ext = "";
            }
            name = rename(name, sedexpr) getdate(fname, datefmt);
            name = tocase(0, name, regexcapital);
            name = tocase(-1, tocase(1, name, regextoupper), regextolower);
            if (numfmt != "") {
              if ('$numsameflag') {
                num = numbers[name];
                if (num == "") {
                  num = numstart;
                }
                num++;
                numbers[name] = num;
              } else {
                num++;
              }
              name = name sprintf(numfmt, num);
            }
            name = rename(name, postexpr);
            printf "%s %s %s%s", fname, indicator, name, ext;
            ret = '$nochgflag';
            if ('$readflag') {
              printf " ? (y/n): ";
              ret = system("read a; case \"$a\" in [Yy]);; *) exit 1;; esac");
            } else {
              printf "\n";
            }
            if (ret == 0) {
              system("mv -i" cmdparam(fname) cmdparam(name ext));
            } else if (ret != 1) {
              exit 1;
            }
          }
        }
        printf "\n";
      }'
      if [ $? = 1 ]; then
        return 1
      fi
    ;;
  esac
}

# Escape backslashes for the specified format or expression if the character
# preceded by a backslash treat as one literal by awk command. In addition,
# \N (N from 1 to 9) of sed expression output as octal by dash is restored.
#
# $1 - the format or expression

bslash='\\\\'
if awk 'BEGIN { print "\(" }' 2> /dev/null | awk '$0 == "(" { exit 1 }'; then
  bslash='\\'
fi
skipsrc='t ESCBSLASH'
skipdest=':ESCBSLASH'
if [ $(echo "\41") = '!' ] && [ $(echo | sed 's/.*/\x21/') = '!' ]; then
  skipsrc=""
  skipdest=""
fi

escbslash(){
  echo "$1" | \
  sed 's/\\/\
/g
       s/\n\n/'"$bslash$bslash"'/g
       :ESCOCTAL
         /\n\([1-9]\)/ {
           s//\\\\\1/; t ESCOCTAL
         }
       '"$skipsrc"'
       s/\x01/\\\\1/g
       s/\x02/\\\\2/g
       s/\x03/\\\\3/g
       s/\x04/\\\\4/g
       s/\x05/\\\\5/g
       s/\x06/\\\\6/g
       s/\x07/\\\\7/g
       '"$skipdest"'
       s/\n/'"$bslash"'/g'
}


# Get options of this program

padding=0
link=0
subdir=""
param=$(getopt 'cC:d:e:E:fiIlnNp:P:Rr' 'no-change,interactive,ignore-extension,link,numbering,number-start:,padding:,pattern:,to-lowercase:,to-uppercase:,help,version' "$@")
eval set -- "$param"

while [ $# != 0 ]
do
  case ${1%%=*} in
  c|no-change)
    nochgflag=1
    readflag=0
    ;;
  C)
    if ! awk 'BEGIN { toupper(""); tolower("") }' > /dev/null 2>&1; then
      error 0 'the function to uppercase or lowercase is unsupported'
      usage 1
    elif ! awk 'BEGIN { match("",/'"${1#*=}"'/) }' > /dev/null 2>&1; then
      error 0 "unsupported regular expression of awk script -- ${1#*=}"
      usage 1
    fi
    regexcapital=$(escbslash "${1#*=}")
    ;;
  d)
    if ! date -r /dev/null > /dev/null 2>&1; then
      error 0 'the reference of file date is unsupported'
      usage 1
    elif ! (date -r /dev/null "+${1#*=}" | \
            awk 'NR > 1 { exit 1 }' > /dev/null 2>&1); then
      error 0 "unsupported date format -- ${1#*=}"
      usage 1
    fi
    datefmt=$(escbslash "${1#*=}")
    ;;
  e)
    if ! (echo | sed "${1#*=}" > /dev/null 2>&1); then
      error 0 "unsupported sed expression -- ${1#*=}"
      usage 1
    fi
    sedexpr=$(escbslash "${1#*=}")
    ;;
  f)
    targetopt='-f'
    ;;
  i|interactive)
    if [ $nochgflag = 0 ]; then
      readflag=1
    fi
    ;;
  I|ignore-extension)
    targetnoext=1
    ;;
  l|link)
    link=1
    ;;
  n|numbering)
    numfmt='%d'
    ;;
  N)
    numsameflag=1
    numfmt='%d'
    ;;
  number-start)
    if [ "${1#*=}" != 0 ] && \
       ! expr "${1#*=}" : '[1-9][0-9]*$' > /dev/null 2>&1; then
      error 0 "invalid number start -- ${1#*=}"
      usage 1
    fi
    numstart=$((${1#*=} - 1))
    ;;
  padding)
    if [ "${1#*=}" != 0 ] && \
       ! expr "${1#*=}" : '[1-9][0-9]*$' > /dev/null 2>&1; then
      error 0 "invalid padding width -- ${1#*=}"
      usage 1
    fi
    padding=${1#*=}
    ;;
  p|pattern)
    target=$target" ${1#*=}"
    ;;
  P)
    if ! (echo | sed "${1#*=}" > /dev/null 2>&1); then
      error 0 "unsupported sed expression -- ${1#*=}"
      usage 1
    fi
    postexpr=$(escbslash "${1#*=}")
    ;;
  R|r)
    subdir='*/'
    ;;
  to-lowercase)
    if ! awk 'BEGIN { tolower("") }' > /dev/null 2>&1; then
      error 0 'the function to lowercase is unsupported'
      usage 1
    elif ! awk 'BEGIN { match("",/'"${1#*=}"'/) }' > /dev/null 2>&1; then
      error 0 "unsupported regular expression of awk script -- ${1#*=}"
      usage 1
    fi
    regextolower=$(escbslash "${1#*=}")
    ;;
  to-uppercase)
    if ! awk 'BEGIN { toupper("") }' > /dev/null 2>&1; then
      error 0 'the function to uppercase is unsupported'
      usage 1
    elif ! awk 'BEGIN { match("",/'"${1#*=}"'/) }' > /dev/null 2>&1; then
      error 0 "unsupported regular expression of awk script -- ${1#*=}"
      usage 1
    fi
    regextoupper=$(escbslash "${1#*=}")
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

# Change the name of files or directories

while [ $# != 0 ]
do
  if [ -d "$1" -o -z "${1%%*/}" ]; then
    dirtrav $link "$1" "$subdir"
    status=$?
    case $status in
    0) ;;
    1) error 0 "cannot move to the directory -- $1";;
    *) exit $status;;
    esac
  else
    error 0 "cannot move to the regular file -- $1"
  fi
  shift
done
