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

START_DIR=

_PRE_PGEM_PATH="$PATH"
_PRE_PGEM_PS1="$PS1"
_PRE_PGEM_PROMPT_COMMAND="$PROMPT_COMMAND"

[[ -z "$PGEM_INFO_ON_START" ]] && PGEM_INFO_ON_START=false
[[ -z "$_PGEM_DEBUG" ]] && _PGEM_DEBUG=false
[[ -z "$_PGEM_LOAD_EXIT_CODE" ]] && _PGEM_LOAD_EXIT_CODE=0
_PGEM_LOC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" # can't use _realpath yet

# TODO these should probably be moved to privateGemFunctions.sh and renamed
err() { echo "$@" >&2; }
log() { $_PGEM_DEBUG && err "$@"; }

pushd "$_PGEM_LOC" > /dev/null

source ./privateGemFunctions.sh
source ./gemFunctions.sh
source ./utilityFunctions.sh

_GEM_LIST=$(_gemList)   # populates the list of gems

_eachGem _loadBase      # initialize environment, executed before config file is parsed
_evalConfig             # executes the commands in the config file
_eachGem _loadEnv       # set environment variables
_eachGem _loadAlias     # create aliases
_eachGem _loadFuncs     # define functions
_eachGem _loadScripts   # add scripts to path

if [[ ! -z "$PS1" ]]      # interactive shell
then
  if $PGEM_INFO_ON_START
  then
    pgem_info
  fi
  _eachGem _loadCmds    # run interactive commands
fi
$_PGEM_DEBUG && echo

popd > /dev/null

if [[ -n "$START_DIR" ]]
then
  # shellcheck disable=SC2164
  if [[ -d "$START_DIR" ]]
  then
    log -e "Switching from $(pwd) to $START_DIR\n"
    cd . # sets $OLDPWD to the starting directory, usually ~
    cd $START_DIR
  else
    err "Start dir $START_DIR does not exist!"
  fi
fi

# Enable running a command in ProfileGem's scope
# Useful when we aren't in an interactive shell, such as cron
# Note aliases are not accessible if it's not an interactive shell
if [[ $# -gt 0 ]]
then
  eval "$@"
else
  return $_PGEM_LOAD_EXIT_CODE 2>/dev/null || exit $_PGEM_LOAD_EXIT_CODE
fi
