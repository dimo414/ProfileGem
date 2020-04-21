#
# ProfileGem Functions
# These are public functions users are expected to call
#

# Reloads ProfileGem and all gems. If the set of gems hasn't changed this
# should be a no-op. In some cases (such as installing a new gem) it's
# possible reloading will not be sufficient and it will be necessary to
# relaunch the shell.
pgem_reload() {
  local state_dir ret=0 # set before populating pgem_pre.env
  if "${_PGEM_DEBUG:-false}"; then
    state_dir=$(mktemp -d) || return
    set > "${state_dir}/pgem_pre.env"
  fi

  export PATH="$_PRE_PGEM_PATH"
  [[ -n "$_PRE_PGEM_PS1" ]] && PS1="$_PRE_PGEM_PS1"
  # Don't reset PROMPT_COMMAND if bash-preexec is detected; it will cause double-writes to preexec_functions
    # shellcheck disable=SC2154
  if [[ -n "$_PRE_PGEM_PROMPT_COMMAND" ]] && [[ -z "$__bp_imported" ]]; then
    PROMPT_COMMAND="$_PRE_PGEM_PROMPT_COMMAND"
  fi

  source "${_PGEM_LOC}/load.sh"
  ret=$?

  if "${_PGEM_DEBUG:-false}"; then
    set > "${state_dir}/pgem_post.env"
    echo "Environment Changes:"
    # '/^[^=]*$/q;p' prints until hitting a line without an equals sign, i.e. a function declaration
    # Use comm instead of diff to avoid headers and line numbers
    comm -3 \
        <(sed -n '/^[^=]*$/q;p' "${state_dir}/pgem_pre.env" | sort) \
        <(sed -n '/^[^=]*$/q;p' "${state_dir}/pgem_post.env" | sort) \
      | sed -e 's|^[^\t]|- \0|' -e 's|^\t|+ |'
  fi
  return "$ret"
}

# Pulls in updates to ProfileGem and all gems, then reloads them.
pgem_update() {
  (
    cd "$_PGEM_LOC" || return
    pg::_eachGem pg::_updateRepo
    pg::_updateRepo || _PGEM_EACHGEM_EXIT_CODE=$? # update ProfileGem
    touch "$_PGEM_LAST_UPDATE_MARKER"
    exit "${_PGEM_EACHGEM_EXIT_CODE:-0}" # exit subshell
  ) || _PGEM_EACHGEM_EXIT_CODE=$?
  unset -f pgem_snooze_update
  pgem_reload
}

# Migrates ProfileGem and any other gems with a documented migration path to
# GitHub. Looks for a gh_migrate file in the repo root.
pgem_migrate() {
  local backup
  backup=$(mktemp -d) || return
  cp -R "$_PGEM_LOC" "$backup"
  echo "Migrating repos off BitBucket and onto GitHub"
  echo "Existing ProfileGem install at ${PWD} copied to ${backup} in case of issues"
  (
    cd "$_PGEM_LOC" || return
    pg::_eachGem pg::_gh_migrate
    pg::_gh_migrate
  ) || return
  pgem_reload
}

# Prints a high-level summary of all installed gems.
pgem_info() {
  if (( $# )); then
    local gem="${1%.gem}.gem" # supports "foo" or "foo.gem"
    if [[ -d "${_PGEM_LOC}/${gem}" ]]; then
      (
        cd "${_PGEM_LOC}/${gem}" || return
        pg::_incomingRepo
        pg::_printDoc
      )
    else
      pg::err "No such gem $gem"
      return 1
    fi
  else
    (
      cd "$_PGEM_LOC" || return
      printf 'ProfileGem v%s.%s.%s\n\n' "${PGEM_VERSION[@]}"
      pg::_incomingRepo
      pg::_eachGem pg::_printDocLead
      printf '\nRun pgem_help for ProfileGem usage, or pgem_info GEM_NAME for gem details.\n'
    )
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
process, and gems can provide their own debug output by calling pg::log.

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
