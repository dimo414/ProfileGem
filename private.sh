#
# ProfileGem Private Functions
# Used internally to prepare the profile, not meant to be called by the user
#

# Given a relative path, prints an absolute path
if command -v realpath &> /dev/null; then
  pg::_realpath() { realpath "$1"; }
elif readlink -f / &> /dev/null; then
  pg::_realpath() { readlink -f "$1"; }
else
  # readlink -f doesn't exist on OSX, need to implement manually
  pg::_realpath() {
    if [[ -d "${1:?}" ]]; then
      (cd "$1" && pwd -P)
    else
      echo "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
    fi
  }
fi

# Expects a path argument and outputs the full path, with the path to ProfileGem stripped off
# e.g. dispPath /home/username/ProfileGem/my.gem => my.gem
pg::_dispPath() {
  pg::_realpath "$@" | sed 's|^'"$_PGEM_LOC/"'||'
}

# Print a warning if ProfileGem hasn't been updated recently
pg::_check_out_of_date() {
  [[ -e "$_PGEM_LAST_UPDATE_MARKER" ]] || { touch "$_PGEM_LAST_UPDATE_MARKER" && return; }
  if [[ "$(find "$_PGEM_LOC" -maxdepth 1 -path "$_PGEM_LAST_UPDATE_MARKER" -newermt '-1 month')" == "" ]]; then
    pg::err 'ProfileGem is more than a month out of date; run `pgem_update` to update.'
    pg::err '  Or run `pgem_snooze_update` to snooze this message.'
    pgem_snooze_update() {
      touch "$_PGEM_LAST_UPDATE_MARKER"
      unset -f pgem_snooze_update
    }
  fi
}

# Checks that the config file exists, and returns its name
pg::_configFile() {
  local conf_file='local.conf.sh'
  echo "$conf_file"
  if ! [[ -f "$conf_file" ]]; then
    pg::err "No ${conf_file} file found."
    return 1
  fi
}

# Run "$@" in each gem - should generally be a function
pg::_eachGem() {
  pushd "$_PGEM_LOC" > /dev/null
  local i
  for i in "${!_GEMS[@]}"; do
    local gem="${_GEMS[$i]}"
    if [[ -d "$gem" ]]; then
      pushd "$gem" > /dev/null
      "$@"
      local exit=$?
      if [[ $exit != 0 ]]; then
        _PGEM_LOAD_EXIT_CODE=$exit
        pg::err "'$*' failed in $gem"
      fi
      popd > /dev/null
    else
      pg::log "$gem is not a directory."
      # http://wiki.bash-hackers.org/syntax/arrays
      unset -v '_GEMS['"$i"']'
      _PGEM_LOAD_EXIT_CODE=10
    fi
  done
  popd > /dev/null
}

# Prints a line describing the status of a local repo vs. its remote source.
# No output means no (known) changes to pull.
# Currently only supports hg
pg::_incomingRepo() {
  local dir
  dir=$(basename "$PWD")
  if [[ -d ".hg" ]]; then
    local incoming
    incoming=$(hg incoming -q | wc -l)
    if (( incoming > 0 )); then
      echo "$dir is $incoming change(s) behind."
    fi
  fi
} && bc::cache pg::_incomingRepo PWD

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
    _PGEM_DEBUG=$_PGEM_DEBUG ./update.sh
  elif [[ -d ".hg" ]]; then
    # separate steps, so that we update even if pull doesn't
    # find anything (i.e. someone pushed to this repo)
    # TODO this should alert more clearly if the user needs to merge heads
    hg pull > /dev/null
    hg update -c tip > /dev/null
  elif [[ -d ".git" ]]; then
    # TODO are there failure modes for this?
    git pull --rebase > /dev/null
  else
    pg::err "Could not update $dir"
    return 1
  fi
}

# Sources a file if it exists, skips if not
pg::_srcIfExist() {
  if [[ -f "$1" ]];  then
    pg::log "Including $(pg::_dispPath "$1")"
    # shellcheck disable=SC1090
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
  echo "$(basename $PWD)"
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
