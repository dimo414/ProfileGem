#
# ProfileGem Functions
# These are public functions users are expected to call
#

# Reloads ProfileGem and all gems. If the set of gems hasn't changed this
# should be a no-op. In some cases (such as installing a new gem) it's
# possible reloading will not be sufficient and it will be necessary to
# relaunch the shell.
pgem_reload() {
  $_PGEM_DEBUG && set | sort > /tmp/pgem_pre.env
  export PATH="$_PRE_PGEM_PATH"
  export PS1="$_PRE_PGEM_PS1"
  export PROMPT_COMMAND="$_PRE_PGEM_PROMPT_COMMAND"

  pushd "$_PRE_PGEM_PWD" > /dev/null
  . "${_PGEM_LOC}/load.sh"
  local ret=$?
  popd > /dev/null

  if $_PGEM_DEBUG
  then
    set | sort > /tmp/pgem_post.env
    echo Environment Changes:
    comm -3 /tmp/pgem_pre.env /tmp/pgem_post.env |
      sed -e 's|^[^\t]|- \0|' -e 's|^\t|+ |'
  fi
  unset _PGEM_LOAD_EXIT_CODE
  return $ret
}

# Pulls in updates to ProfileGem and all gems, then reloads them.
pgem_update() {
  _PGEM_LOAD_EXIT_CODE=0
  pushd "$_PGEM_LOC" > /dev/null
  _eachGem _updateRepo
  _updateRepo # update ProfileGem
  popd > /dev/null
  pgem_reload
}

# Prints a high-level summary of all installed gems.
pgem_info() {
  if (($#)); then
    local gem="${1%.gem}.gem" # supports "foo" or "foo.gem"
    if [[ -d "$_PGEM_LOC/$gem" ]]; then
      pushd "$_PGEM_LOC/$gem" > /dev/null
      _incomingRepo
      _printDoc
      popd > /dev/null
    else
      pgem_err "No such gem $gem"
      return 1
    fi
  else
    pushd "$_PGEM_LOC" > /dev/null
    echo "ProfileGem v${PGEM_VERSION[0]}.${PGEM_VERSION[1]}.${PGEM_VERSION[2]}"
    _incomingRepo
    _eachGem _printDocLead
    popd > /dev/null
  fi
}

# TODO
#pgem_help() {
#  _eachGem _printDoc info.txt
#  echo
#  _eachGem _printDoc help.txt
#}
