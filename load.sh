#!/bin/bash

#
# ProfileGem
#
# ProfileGem enables compartmentalized control of your terminal
# with minimal configuration by loading environment settings,
# aliases, functions, and scripts from a series of "gems"
# you can customize and use independently. By loading different
# gems depending on your environment you can create a custom but
# familiar shell everywhere you go.
#


_PRE_PGEM_PWD="$PWD"
_PRE_PGEM_PATH="$PATH"
[[ -n "$PS1" ]] && _PRE_PGEM_PS1="$PS1"
[[ -n "$PROMPT_COMMAND" ]] && _PRE_PGEM_PROMPT_COMMAND="$PROMPT_COMMAND"

START_DIR=
PGEM_VERSION=(0 10 0)

[[ -z "$PGEM_INFO_ON_START" ]] && PGEM_INFO_ON_START=false
[[ -z "$_PGEM_DEBUG" ]] && _PGEM_DEBUG=false
[[ -z "$_PGEM_LOAD_EXIT_CODE" ]] && _PGEM_LOAD_EXIT_CODE=0
_PGEM_LOC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" # can't use _realpath yet
_PGEM_LAST_UPDATE_MARKER="$_PGEM_LOC/.last_updated"

pushd "$_PGEM_LOC" > /dev/null

source ./bash-cache.sh
source ./privateGemFunctions.sh
source ./gemFunctions.sh
source ./utilityFunctions.sh

# Populate the list of enabled gems
_GEMS=()
for gem in $(grep '^#GEM' "$_PGEM_LOC/$(_configFile)" | awk '{ print $2 ".gem" }'); do
  _GEMS+=($gem)
done
pgem_log "About to load gems: ${_GEMS[@]}"

# TODO add a cleanup.sh script which is invoked by pgem_reload (but not load.sh) before anything else.
_eachGem _loadBase          # initialize environment, executed before config file is parsed
_evalConfig                 # executes the commands in the config file
# TODO perhaps there should be a separate step between base.conf.sh and environment.sh
# so that all gems, not just earlier gems, can configure each other
_eachGem _loadEnv           # set environment variables
_eachGem _loadAlias         # create aliases
_eachGem _loadFuncs         # define functions
_eachGem _loadScripts       # add scripts to path

if [[ ! -z "$PS1" ]]; then  # interactive shell
  _check_out_of_date
  if $PGEM_INFO_ON_START; then
    pgem_info
  fi
  _eachGem _loadCmds        # run interactive commands
fi
pgem_log # for newline

popd > /dev/null

if [[ -n "$START_DIR" ]]
then
  if [[ -d "$START_DIR" ]]
  then
    pgem_log "Switching from $(pwd) to $START_DIR"
    pgem_log
    # cd . sets $OLDPWD to the starting directory, usually $HOME
    cd . || pgem_err "Could not cd to $_PRE_PGEM_PWD ...?"
    cd "$START_DIR" || pgem_err "Could not cd to START_DIR $START_DIR"
  else
    pgem_err "Start dir $START_DIR does not exist!"
  fi
fi

# Enable running a command in ProfileGem's scope
# Useful when we aren't in an interactive shell, such as cron
# Note aliases are not accessible if it's not an interactive shell
if (($#)); then
  eval "$@"
else
  return $_PGEM_LOAD_EXIT_CODE 2>/dev/null || exit $_PGEM_LOAD_EXIT_CODE
fi
