#!/bin/bash

#
# ProfileGem
#
# ProfileGem enables highly granular control of your terminal 
# with minimal configuration by loading environment settings,
# aliases, functions, and scripts from a series of "gems"
# you can customize and use independantly.  Easily configure
# similar, yet application specific, profiles with everything
# you need immidiately on hand.
#

_PRE_PGEM_PATH="$PATH"

if [ -z "$_PGEM_DEBUG" ]; then _PGEM_DEBUG=false; fi
_PGEM_LOC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) # can't use _realpath yet

\pushd "$_PGEM_LOC" > /dev/null

. ./gemFunctions.sh

_GEM_LIST=$(_gemList)

_eachGem _loadPre       # load pre-config resources - intentionally not included in template

_eachGem _parseConf     # load config settings

_eachGem _loadEnv       # set environment variables
_eachGem _loadAlias     # create aliases
_eachGem _loadFuncs     # define functions
_eachGem _loadScripts   # add scripts to path

if [ ! -z "$PS1" ]      # interactive shell
then
  _eachGem _runCmd    # run interactive commands
fi
$_PGEM_DEBUG && echo

\popd > /dev/null

if [ ! -z "$START_DIR" ]
then
  if [ -d $START_DIR ]
  then
    $_PGEM_DEBUG && echo -e "Switching from $(pwd) to $START_DIR\n"
    cd $START_DIR
  else
    echo "Start Dir $START_DIR Does Not Exist"
  fi
fi

# Enable running a command in ProfileGem's scope
# Useful when we aren't in an interactive shell, such as cron
# Note aliases are not accessible if it's not an interactive shell
if [ $# -gt 0 ]
then
  eval "$@"
fi
