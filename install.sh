#!/bin/sh

DIR=$1
if [ "$DIR" = "" ]; then
  DIR=/usr/local/bin
elif ! [ -d "$DIR" ]; then
  echo 'fbatchsh: No install directory.'
  exit
fi

LIB=$2
if [ "$LIB" = "" ]; then
  LIB=/usr/lib
elif ! [ -d "$LIB" ]; then
  echo 'fbatchsh: No library directory.'
  exit
fi

if [ -f ./chfname.sh ]; then
  mkdir -p ${LIB}/fbatchsh
  cp -f ./chfname.sh ${LIB}/fbatchsh/chfname.sh
  chmod 755 ${LIB}/fbatchsh/chfname.sh
  if ! [ -h ${DIR}/chfname ]; then
    ln -s ${LIB}/fbatchsh/chfname.sh ${DIR}/chfname
  fi
fi
