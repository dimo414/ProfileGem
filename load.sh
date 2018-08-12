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
_PGEM_LOC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" # can't use pg::_realpath yet
_PGEM_LAST_UPDATE_MARKER="$_PGEM_LOC/.last_updated"

pushd "$_PGEM_LOC" > /dev/null

source "$PWD/bash-cache.sh"
source "$PWD/private.sh"
source "$PWD/gemFunctions.sh"
source "$PWD/utilityFunctions.sh"

# Populate the list of enabled gems
_GEMS=()
for gem in $(grep '^#GEM' "$_PGEM_LOC/$(pg::_configFile)" | awk '{ print $2 ".gem" }'); do
  _GEMS+=($gem)
done
pg::log "About to load gems: ${_GEMS[@]}"

# TODO add a cleanup.sh script which is invoked by pgem_reload (but not load.sh) before anything else.
pg::_eachGem pg::_loadBase      # initialize environment, executed before config file is parsed
pg::_evalConfig                 # executes the commands in the config file
# TODO perhaps there should be a separate step between base.conf.sh and environment.sh
# so that all gems, not just earlier gems, can configure each other
pg::_eachGem pg::_loadEnv       # set environment variables
pg::_eachGem pg::_loadAlias     # create aliases
pg::_eachGem pg::_loadFuncs     # define functions
pg::_eachGem pg::_loadScripts   # add scripts to path

if [[ ! -z "$PS1" ]]; then      # interactive shell
  pg::_check_out_of_date
  if $PGEM_INFO_ON_START; then
    pgem_info
  fi
  pg::_eachGem pg::_loadCmds    # run interactive commands
fi
pg::log # for newline

popd > /dev/null

if [[ -n "$START_DIR" ]]
then
  if [[ -d "$START_DIR" ]]
  then
    pg::log "Switching from $(pwd) to $START_DIR"
    pg::log
    # cd . sets $OLDPWD to the starting directory, usually $HOME
    cd . || pg::err "Could not cd to $_PRE_PGEM_PWD ...?"
    cd "$START_DIR" || pg::err "Could not cd to START_DIR $START_DIR"
  else
    pg::err "Start dir $START_DIR does not exist!"
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
