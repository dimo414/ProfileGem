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

# Shell and environmnet validation
# :? does not exit from interactive shells, so we can't use it here.
if [[ -z "$BASH_VERSION" ]]; then
  echo "Invalid shell detected, must run as bash" >&2
  return 1 2>/dev/null || exit 1
elif [[ -n "$POSIXLY_CORRECT" ]]; then
  echo "ProfileGem is not POSIX-compatible, must run as bash" >&2
  return 1 2>/dev/null || exit 1
elif ! [[ -e "${BASH_SOURCE[0]}" ]]; then
  echo "Could not determine install directory" >&2
  return 1 2>/dev/null || exit 1
fi

_PGEM_LOC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" # can't use pg::realpath yet
PGEM_VERSION=(0 12 0)
_PGEM_LAST_UPDATE_MARKER="$_PGEM_LOC/.last_updated"

_PRE_PGEM_PWD="$PWD"
_PRE_PGEM_PATH="$PATH"
[[ -n "$PS1" ]] && _PRE_PGEM_PS1="$PS1"
[[ -n "$PROMPT_COMMAND" ]] && _PRE_PGEM_PROMPT_COMMAND="$PROMPT_COMMAND"

# TODO do we actually need this cd at all?
cd "$_PGEM_LOC" || return 2>/dev/null || exit

source "$PWD/bash-cache.sh"
source "$PWD/getopts.sh"
source "$PWD/private.sh"
source "$PWD/gemFunctions.sh"
source "$PWD/utilityFunctions.sh"

# Decorate the source and . builtins in order to resolve absolute paths before
# sourcing, thereby enabling more informative traces. Temporarily gated to
# easily disable if this causes problems.
# To disable set PGEM_DECORATE_SOURCE=false before sourcing this script.
# Please also file a bug at https://github.com/dimo414/ProfileGem if you need to
# do so, as this gate may be removed in the future.
if "${PGEM_DECORATE_SOURCE:-true}" && [[ "$(type -t source)" == "builtin" ]]; then
  source() {
    if (( $# < 1 )); then
      command source "$@"; return # use source's error message if no args
    fi
    local file=$1; shift
    # if file looks like a path, make it absolute. Since source first searches the PATH it's not
    # safe to just check [[ -e "$file" ]] because it might be shadowing something on the PATH.
    # Avoid resolving named pipes (e.g. `source <(echo true)`) which do not point to real paths.
    if [[ "$file" == */* ]] && ! [[ -p "$file" ]]; then
      file=$(pg::realpath "$file")
    fi
    command source "$file" "$@"
  }
  .() { source "$@"; }
fi

# Populate the list of enabled gems
_GEMS=()
while IFS= read -r gem; do
    _GEMS+=("$gem")
done < <(grep '^#GEM' "${_PGEM_LOC}/$(pg::_configFile)" | awk '{ print $2 ".gem" }')
pg::log "About to load gems: ${_GEMS[*]}"
unset gem

# TODO add a cleanup.sh script which is invoked by pgem_reload (but not load.sh) before anything else.
pg::_eachGem pg::_loadBase      # initialize environment, executed before config file is parsed
pg::_evalConfig                 # executes the commands in the config file
# TODO perhaps there should be a separate step between base.conf.sh and environment.sh
# so that all gems, not just earlier gems, can configure each other
pg::_eachGem pg::_loadEnv       # set environment variables
pg::_eachGem pg::_loadAlias     # create aliases
pg::_eachGem pg::_loadFuncs     # define functions
pg::_eachGem pg::_loadScripts   # add scripts to path

if [[ -n "$PS1" ]]; then        # interactive shell
  pg::_check_out_of_date
  if "${PGEM_INFO_ON_START:=false}"; then
    pgem_info
  fi
  pg::_eachGem pg::_loadCmds    # run interactive commands
fi
pg::log # for newline

# Attempt to get back to the initial PWD, but disregard errors if it fails
cd "$_PRE_PGEM_PWD" 2>/dev/null || true

# Enable running a command in ProfileGem's scope
# Useful when we aren't in an interactive shell, such as cron
# Note aliases are not accessible if it's not an interactive shell
if (( $# )); then
  # It'd be cleaner to use "${*@Q}", introduced in Bash 4.4
  eval "$(printf '%q ' "$@")"
else
  _PGEM_LOAD_EXIT_CODE=${_PGEM_EACHGEM_EXIT_CODE:-0}
  unset _PGEM_EACHGEM_EXIT_CODE
  return "$_PGEM_LOAD_EXIT_CODE" 2>/dev/null || exit "$_PGEM_LOAD_EXIT_CODE"
fi
