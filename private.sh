#
# ProfileGem Private Functions
# Used internally to prepare the profile, not meant to be called by the user
#

# Print a warning if ProfileGem hasn't been updated recently
pg::_check_out_of_date() {
  [[ -e "$_PGEM_LAST_UPDATE_MARKER" ]] || { touch "$_PGEM_LAST_UPDATE_MARKER" && return; }
  if [[ "$(find "$_PGEM_LOC" -maxdepth 1 -path "$_PGEM_LAST_UPDATE_MARKER" -newermt '-1 month')" == "" ]]; then
    pg::err "ProfileGem is more than a month out of date; run 'pgem_update' to update."
    pg::err "  Or run 'pgem_snooze_update' to snooze this message."
    pgem_snooze_update() {
      touch "$_PGEM_LAST_UPDATE_MARKER"
      unset -f pgem_snooze_update
    }
  fi
}

# Creates the config file if it doesn't exist, and returns its name.
# The auto-generated gem ordering may not be ideal, but this at least gets things set up.
pg::_configFile() {
  local conf_file='local.conf.sh'
  if ! [[ -f "$conf_file" ]]; then
    # if it doesn't exist, create it
    local gems=(*.gem)
    {
      printf '# %s\n' \
        'ProfileGem configuration' '' \
        '"#GEM ..." directives configure which .gems will be loaded, and in what order.' \
        'You may need to re-order these directives to allow dependent gems to interact.' '' \
        'Many gems support customizations which can be configured here as well.' \
        "See each gem's documentation or base.conf.sh for details."
      echo
      printf '#GEM %s\n' "${gems[@]%.gem}"
    } > "$conf_file"
  fi
  echo "$conf_file"
}

# Run "$@" in each gem - should generally be a function
# Sets _PGEM_EACHGEM_EXIT_CODE (to a non-zero value) if the command fails in one or more gems, which will cause load.sh
# to return a non-zero exit code.
pg::_eachGem() {
  local i gem gem_dir exit oldpwd="$PWD"
  for i in "${!_GEMS[@]}"; do
    gem="${_GEMS[$i]}"
    gem_dir="${_PGEM_LOC}/${gem}"
    if [[ -d "$gem_dir" ]]; then
      cd "$gem_dir" || continue
      "$@"
      exit=$?
      if (( exit != 0 )); then
        _PGEM_EACHGEM_EXIT_CODE=$exit
        pg::err "'$*' failed in ${gem}"
      fi
    else
      pg::log "${gem} is not a directory."
      # http://wiki.bash-hackers.org/syntax/arrays
      unset -v "_GEMS[$i]"
      _PGEM_EACHGEM_EXIT_CODE=10
    fi
  done
  # something will probably blow up if we can't cd back, but there's not a lot we can do
    # shellcheck disable=SC2164
  cd "$oldpwd"
  return "${_PGEM_EACHGEM_EXIT_CODE:-0}"
}

# Prints a line describing the status of a local repo vs. its remote source.
# No output means no (known) changes to pull.
pg::_incomingRepo() {
  local dir
  dir=$(basename "$PWD")
  local incoming=0
  if [[ -d ".hg" ]]; then
    incoming=$(hg incoming -q | wc -l)
  elif [[ -d ".git" ]]; then
    incoming=$(git fetch >& /dev/null && git log '..@{u}' --format=tformat:%h 2> /dev/null | wc -l)
  fi
  if (( incoming > 0 )); then
    echo "$dir is $incoming change(s) behind."
  fi
} && bc::cache pg::_incomingRepo 5m 10s PWD

# Pulls in updates for the current directory, currently aware of Mercurial and Git
# Alternatively create an update.sh script in the current directory to specify
# custom update behavior
pg::_updateRepo() {
  local dir
  dir=$(basename "$PWD")
  if [[ -f "noupdate" ]]; then
    echo "Not updating $dir"
    return
  fi
  echo "Updating $dir"
  if [[ -f "update.sh" ]]; then
    _PGEM_DEBUG="${_PGEM_DEBUG:-false}" ./update.sh
  elif [[ -d ".hg" ]]; then
    # separate steps, so that we update even if pull doesn't
    # find anything (i.e. someone pushed to this repo)
    # TODO this should alert more clearly if the user needs to merge heads
    hg pull > /dev/null
    hg update -c tip > /dev/null
  elif [[ -d ".git" ]]; then
    # TODO are there failure modes for this?
    git pull --quiet --rebase > /dev/null
  else
    pg::err "Could not update $dir"
    return 1
  fi
}

# Migrates a repo from Mercurial to Git/GitHub if a gh_migrate file is found
pg::_gh_migrate() {
  if ! [[ -f gh_migrate ]] || ! [[ -d .hg ]]; then
    pg::log "Not migrating $(basename "$PWD")"
    return
  fi
  if hg outgoing -q; then
    pg::err "'hg outgoing -R ${PWD}' reports outgoing changes that will be lost; not migrating"
    return 1
  fi
  # Use a subdirectory, rather than /tmp, so git's filesystem heuristics don't
  # get confused (e.g. to configure https://stackoverflow.com/a/2518917/113632)
  local tmp_loc="${PWD}/safe_to_delete_${RANDOM}"
  git clone --quiet "$(cat gh_migrate)" "$tmp_loc" &&
    mv "$tmp_loc/.git" . &&
    rm gh_migrate &&
    mv .hg "$tmp_loc" &&
    rm -rf "$tmp_loc" &&
    git checkout --theirs -- . &&
    echo "Migrated $(basename "$PWD") to git"
}

# Sources a file if it exists, skips if not
pg::_srcIfExist() {
  if [[ -f "${1:?}" ]];  then
    pg::log "Including $(pg::relative_path "$1" "$_PGEM_LOC")"
    source "$1"
  fi
}

# Initialize environment
pg::_loadBase() {  pg::_srcIfExist "base.conf.sh"; }

# Evaluates the config file - not called by pg::_eachGem
pg::_evalConfig() {  pg::_srcIfExist "$(pg::_configFile)"; }

# Set environment variables
pg::_loadEnv() {  pg::_srcIfExist "environment.sh"; }

# Load aliases
pg::_loadAlias() { pg::_srcIfExist "aliases.sh"; }

# Define functions
pg::_loadFuncs() { pg::_srcIfExist "functions.sh"; }

# Add scripts directory to PATH
pg::_loadScripts() {
  if [[ -d "scripts" ]]; then
    pg::add_path "scripts"
  fi
}

# Run commands
pg::_loadCmds() { pg::_srcIfExist "commands.sh"; }

# Output first paragraph of info.txt, indented
pg::_printDocLead() {
  basename "$PWD"
  if [[ -f "info.txt" ]]; then
    # http://stackoverflow.com/a/1603584/113632
    # BSD sed (OSX) lacks the q and Q flags mentioned in some other answers
    awk -v 'RS=\n\n' '1;{exit}' info.txt | sed 's/^/  /'
    echo
  fi
}

# Output info.txt and check for incoming changes
pg::_printDoc() {
  if [[ -f "info.txt" ]]; then
    cat "info.txt"
  fi
}
