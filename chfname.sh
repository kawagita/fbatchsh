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

AWKTOCASE=$(! awk 'BEGIN { toupper(""); tolower("") }' 2> /dev/null; echo $?)
AWKMATCHBYTES=$(! awk -b 'BEGIN { }' 2>&1 | awk '$0 != "" { exit 1 }'; echo $?)

DATEREFTIME=$(! date -r / > /dev/null 2>&1; echo $?)

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
  echo '  -b, --rollback-directory   reverse changes in directory when target failed'
  echo '  -c, --no-change            do not change any files or directories'
  echo '      --capitalize=REGEX     capitalize the match of REGEX'
  echo '  -d FORMAT                  append the modification time output with FORMAT'
  echo '  -e EXPRESSION              use EXPRESSION to replace file names'
  echo '  -f                         change the name of only files'
  echo '  -h                         change the name of symbolic links'
  echo '  -i, --interactive          prompt before change'
  echo '  -I, --ignore-extension     ignore file extension when the name is changed'
  echo '  -k, --keep-running         continue to traverse directories as possible'
  echo '  -l, --link                 follow the symbolic link (with -R)'
  echo '  -n, --numbering            append sequential number'
  echo '  -N                         append sequential number for the same name'
  echo '      --number-start=NUM     use NUM for starting number instead of 1'
  echo '      --number-padding=NUM   use NUM for the maximum padding zeros'
  if [ $AWKMATCHBYTES != 0 ]; then
    echo '  -M, --multibyte            arrange the output of multibyte encodings'
  fi
  echo '  -p EXPRESSION              use EXPRESSION after adding date or number string'
  echo '  -R, --recursive            change the name in directories recursively'
  echo "      --skip-error           skip target's error in directory"
  echo '  -T PATTERN(s)              find targets whose name matches a PATTERN'
  echo '      --to-lowercase=REGEX   convert the match of REGEX to lowercase'
  echo '      --to-uppercase=REGEX   convert the match of REGEX to uppercase'
  echo '  -v, --verbose              show all targets whose name is changed or not'
  echo '      --help                 display this help and exit'
  echo '      --version              output version information and exit'
  echo
  echo 'REGEX is used by match function of awk script. FORMAT or EXPRESSION is followed'
  echo 'by -d or -e option of date or sed command. In details, see the manual.'
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

travlinefeed=""
travstopped=1

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
     if ! dirmain 0 && [ $travstopped != 0 ]; then
       exit 2
     fi
     shift
     set -- $subdir / "$@"
     travlinefeed='\n'

     while true
     do
       if [ "$1" = '/' ]; then
         if ! dirmain 1 && [ $travstopped != 0 ]; then
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

EXECUTEDMARK='!'
UNCHANGEDMARK='+'
PROMPTMARK='?'
VERBOSEMARK='-'
ERRORMARK='E'

target=""
targetunchanged=0
targetprompt=0
targetverbose=0
targetrollback=0
targetsymlink=0
testopt='-e'
extignored=0
regexcapital=""
regextoupper=""
regextolower=""
sedexpr=""
postexpr=""
datefmt=""
numfmt=""
numsamenamed=0
numstart=0
multibyte=0
errskipped=0
errdisposition='exit 1'

dirmain(){
  case $1 in
  0)
    if [ $targetunchanged ]; then
      mark=$UNCHANGEDMARK
    elif [ $targetprompt ]; then
      mark=$PROMPTMARK
    else
      mark=$EXECUTEDMARK
    fi
    set -- ${target:-*}
    awk -v regexcapital="$regexcapital" \
        -v regextoupper="$regextoupper" \
        -v regextolower="$regextolower" \
        -v datefmt="$datefmt" -v numfmt="$numfmt" -v numstart=$numstart '
      function showtarget(mark, target, width, dest) {
        printf "%s %-" width "s", mark, target;
        if (dest != "") {
          printf " -> %s", dest;
          if (mark == "'$PROMPTMARK'") {
            printf "  (y/n): ";
            return;
          }
        }
        printf "\n";
      }
      function multilen(target) {
        if ('$multibyte') {
          return gsub(/[^\x01-\x7f]/, "&", target);
        }
      }
      function cmdparam(param) {
        gsub(/'\''/, "'\''\\\\&'\''", param);
        return " '\''" param "'\''";
      }
      function getdate(datetarget, datefmt,  datecmd) {
        if (datefmt != "") {
          datecmd = "date -r" datetarget cmdparam("+" datefmt);
          datecmd | getline;
          close(datecmd);
          return $0;
        }
        return "";
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
        dirpath = ARGV[1];
        dirwrite = system("test ! -w ./");
        num = numstart;
        targetmaxlen = 0;
        targetsize = 0;
        for (i = 2; i < ARGC; i++) {
          target = ARGV[i];
          cmdtarget = cmdparam(target);
          if (system("test '$testopt'" cmdtarget) == 0 && \
              ('$targetsymlink' || system("test ! -h" cmdtarget) == 0)) {
            if (++targetsize > 1) {
              pl = "s";
            }
            len = length(target) + multilen(target);
            if (len > targetmaxlen) {
              targetmaxlen = len;
            }
            targets[targetsize] = target;
          }
        }
        printf "'"$travlinefeed"'%s:\n%d target%s\n", dirpath, targetsize, pl;
        for (i = 1; i <= targetsize; i++) {
          target = targets[i];
          targetwidth = targetmaxlen - multilen(target);
          cmdtarget = cmdparam(target);
          cmdstatus = 0;
          if (dirwrite) {
            if ('$extignored' && \
                match(target, /(\.[0-9A-Za-z]+)?\.[0-9A-Za-z]+$/) && \
                RSTART > 1) {
              name = substr(target, 1, RSTART - 1);
              ext = substr(target, RSTART);
            } else {
              name = target;
              ext = "";
            }
            name = rename(name, "'"$sedexpr"'") getdate(cmdtarget, datefmt);
            name = tocase(0, name, regexcapital);
            name = tocase(-1, tocase(1, name, regextoupper), regextolower);
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
            if (destname == target) {
              if ('$targetverbose') {
                showtarget("'$VERBOSEMARK'", target);
              }
              continue;
            }
            cmddest = cmdparam(destname);
            if (system("test ! -e" cmddest) == 0) {
              showtarget("'$mark'", target, targetwidth, destname);
              ret = '$targetunchanged';
              if ('$targetprompt') {
                ret = system("read ans;case $ans in [Yy]);; *) exit 1;;esac");
                if (ret > 1) {
                  printf "\n";
                }
              }
              if (ret == 0) {
                ret = system("mv -f --" cmdtarget cmddest);
                if (ret == 0) {
                  cmddests[i] = cmddest;
                  continue;
                }
              } else if (ret == 1) {
                continue;
              }
              cmdstatus = ret;
            } else {
              showtarget("'$ERRORMARK'", target, targetwidth, destname);
            }
          } else {
            showtarget("'$ERRORMARK'", target);
          }
          if ('$targetrollback') {
            fsize = 0;
            pl = "";
            for (i = targetsize; i > 0; i--) {
              if (cmddests[i] != "") {
                if (system("mv -f --" cmddests[i] cmdparam(targets[i])) != 0) {
                  exit 1;
                } else if (++fsize > 1) {
                  pl = "s";
                }
              }
            }
            if (fsize > 0) {
              printf "Rolled back %d file%s.\n", fsize, pl;
            }
            exit 1;
          } else if (cmdstatus != 0) {
            exit cmdstatus;
          }
          '"$errdisposition"';
        }
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
link=0
subdir=""
optchars='bcd:e:E:fhiIklnNp:RT:v'
longopts='rollback-directory,no-change,capitalize:,interactive,ignore-extension,keep-running,link,numbering,number-start:,number-padding:,recursive,skip-error,target:,to-lowercase:,to-uppercase:,verbose,help,version'
if [ $AWKMATCHBYTES != 0 ]; then
  optchars=${optchars}'M'
  longopts=${longopts}',multibyte'
fi
argval=$(getopt "$optchars" "$longopts" "$@")
eval set -- "$argval"

while [ $# != 0 ]
do
  case ${1%%=*} in
  b|rollback-directory)
    if [ $errskipped = 0 ]; then
      targetrollback=1
    fi
    ;;
  c|no-change)
    targetunchanged=1
    targetprompt=0
    ;;
  capitalize)
    if [ $AWKTOCASE = 0 ]; then
      error 0 'the function to uppercase or lowercase is unsupported'
      usage 1
    elif ! awk -v r="${1#*=}" 'BEGIN { match("", r) }' > /dev/null 2>&1; then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    regexcapital=$(escbslash "${1#*=}")
    ;;
  d)
    if [ $DATEREFTIME = 0 ]; then
      error 0 'the reference of file date is unsupported'
      usage 1
    elif ! (date -r /dev/null "+${1#*=}" | \
            awk 'NR > 1 { exit 1 }') > /dev/null 2>&1; then
      error 0 "unsupported date format '${1#*=}'"
      usage 1
    fi
    datefmt=$(escbslash "${1#*=}")
    ;;
  e)
    if ! (echo | sed "${1#*=}" > /dev/null 2>&1); then
      error 0 "unsupported sed expression '${1#*=}'"
      usage 1
    fi
    sedexpr=$(escbslash "${1#*=}")
    ;;
  f)
    testopt='-f'
    ;;
  h)
    targetsymlink=1
    ;;
  i|interactive)
    if [ $targetunchanged = 0 ]; then
      targetprompt=1
    fi
    ;;
  I|ignore-extension)
    extignored=1
    ;;
  k|keep-running)
    travstopped=0
    ;;
  l|link)
    link=1
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
  M|multibyte)
    multibyte=1
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
  skip-error)
    errskipped=1
    errdisposition='continue'
    targetrollback=0
    ;;
  T)
    target=${1#*=}
    ;;
  to-lowercase)
    if [ $AWKTOCASE = 0 ]; then
      error 0 'the function to uppercase or lowercase is unsupported'
      usage 1
    elif ! awk -v r="${1#*=}" 'BEGIN { match("", r) }' > /dev/null 2>&1; then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    regextolower=$(escbslash "${1#*=}")
    ;;
  to-uppercase)
    if [ $AWKTOCASE = 0 ]; then
      error 0 'the function to uppercase or lowercase is unsupported'
      usage 1
    elif ! awk -v r="${1#*=}" 'BEGIN { match("", r) }' > /dev/null 2>&1; then
      error 0 "unsupported awk's regular expression '${1#*=}'"
      usage 1
    fi
    regextoupper=$(escbslash "${1#*=}")
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

# Change the name of files or directories

while [ $# != 0 ]
do
  if [ -d "$1" -o -z "${1%%*/}" ]; then
    dirtrav $link "$1" "$subdir"
    status=$?
    case $status in
    0) ;;
    1) error 0 "${1%/}: Permission denied";;
    *) exit $status;;
    esac
  else
    error 0 "$1: Is not a directory"
  fi
  shift
done
