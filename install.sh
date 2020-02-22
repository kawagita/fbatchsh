#!/bin/sh

DIR=$1
if [ "$DIR" = "" ]; then
  DIR=/usr/local/bin
elif ! [ -d "$DIR" ]; then
  printf 'fbatchsh: %d: No such directory.\n' "$DIR"
  exit
fi

LIB=$2
if [ "$LIB" = "" ]; then
  LIB=/usr/lib
elif ! [ -d "$LIB" ]; then
  printf 'fbatchsh: %d: No such directory.\n' "$LIB"
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

if [ -f ./chftime.sh ]; then
  mkdir -p ${LIB}/fbatchsh
  cp -f ./chftime.sh ${LIB}/fbatchsh/chftime.sh
  chmod 755 ${LIB}/fbatchsh/chftime.sh
  if ! [ -h ${DIR}/chftime ]; then
    ln -s ${LIB}/fbatchsh/chftime.sh ${DIR}/chftime
  fi
fi

if [ -f ./lsftime.sh ]; then
  mkdir -p ${LIB}/fbatchsh
  cp -f ./lsftime.sh ${LIB}/fbatchsh/lsftime.sh
  chmod 755 ${LIB}/fbatchsh/lsftime.sh
  if ! [ -h ${DIR}/lsftime ]; then
    ln -s ${LIB}/fbatchsh/lsftime.sh ${DIR}/lsftime
  fi
fi
