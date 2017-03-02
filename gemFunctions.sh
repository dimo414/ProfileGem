#
# ProfileGem Functions
# These are public functions users are expected to call
#

# Reloads ProfileGem and all gems. If the set of gems hasn't changed this
# should be a no-op. In some cases (such as installing a new gem) it's
# possible reloading will not be sufficient and it will be necessary to
# relaunch the shell.
pgem_reload() {
  local ret=0 # set before populating pgem_pre.env
  $_PGEM_DEBUG && set | sort > /tmp/pgem_pre.env
  export PATH="$_PRE_PGEM_PATH"
  [[ -n "$_PRE_PGEM_PS1" ]] && export PS1="$_PRE_PGEM_PS1"
  [[ -n "$_PRE_PGEM_PROMPT_COMMAND" ]] &&
    export PROMPT_COMMAND="$_PRE_PGEM_PROMPT_COMMAND"

  pushd "$_PRE_PGEM_PWD" > /dev/null
  . "${_PGEM_LOC}/load.sh"
  ret=$?
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
    echo
    _incomingRepo
    _eachGem _printDocLead
    echo
    echo "Run pgem_help for ProfileGem usage, or pgem_info GEM_NAME for gem details."
    popd > /dev/null
  fi
}

pgem_help() {
  cat <<EOF
ProfileGem Usage

pgem_reload      re-invokes load.sh in the current shell, thereby picking up
                 changes to ProfileGem and installed gems without opening a new
	         shell. Generally this is an idempotent operation and can be
		 run repeatedly, however some changes such as disabling a gem
		 may necessitate opening a new terminal session.
pgem_update      pulls in updates to ProfileGem and all installed gems, then
                 invokes pgem_reload to pick up changes. Gems cloned from
		 Mercurial or Git repositories are supported natively,
		 otherwise ProfileGem will look for an update.sh script to
		 invoke.
pgem_info [gem]  lists the installed gems and a brief description of each, if
                 available. If an argument is provided the full description of
		 that gem is printed. Also checks for available updates, run
		 pgem_update to pull updates down.

Debug Mode

Setting _PGEM_DEBUG=true either in your .bashrc or your current terminal
enables debug output. pgem_reload provides more details about the reloading
process, and gems can provide their own debug output by calling pgem_log.

Creating a Gem

Copy the template directory to a new directory that ends in ".gem", then add a
"#GEM" line to local.conf.sh to pick up the new gem. For example to create a
gem for your personal preferences and functions you might do:

  $ cp -R template ${USER}.gem
  $ echo "#GEM ${USER}" >> local.conf.sh
  $ pgem_reload

See the README.md and per-file comments in the template directory for more.
EOF
}
