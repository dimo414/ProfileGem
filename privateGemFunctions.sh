#
# ProfileGem Private Functions
# Used internally to prepare the profile, not meant to be called by the user
#

# Given a relative path, prints an absolute path
_realpath()
{
  if command -v realpath >& /dev/null
  then
    realpath "$@"
  else
    # readlink -f doesn't exist on OSX, so can't use readlink
    if [[ -d "$@" ]]; then
      (cd "$@" && pwd)
    else
      echo "$(cd "$(dirname "$@")" && pwd)/$(basename "$@")"
    fi
  fi
}
  

# Expects a path argument and outputs the full path, with the path to ProfileGem stripped off
# e.g. dispPath /home/username/ProfileGem/my.gem => my.gem
_dispPath()
{
  _realpath "$@" | sed 's|^'"$_PGEM_LOC/"'||'
}

# Identifies the config file to read
# Only one file is loaded, the first file that exists out of the below locations
_CONFIG_FILE_LOCS=(local.conf.sh "config.d/users/${USER}.sh" "config.d/hosts/${HOSTNAME}.sh")
_findConfigFile()
{
  local file
  for file in "${_CONFIG_FILE_LOCS[@]}"
  do
    [[ -f "$file" ]] && echo "$file" && return 0
  done
  echo "${_CONFIG_FILE_LOCS[0]}" # Fallback, for error handling
  err "Failed to find config file, looked in ${_CONFIG_FILE_LOCS[*]}"
  return 1
}
  

# Output the list of gems to load, in order
# TODO this should populate a global array rather than echo a space-delimited string
_gemList()
{
  grep '^#GEM' "$_PGEM_LOC/$(_findConfigFile)" | awk '{ print $2 ".gem" }'
}

# Run "$@" in each gem
_eachGem()
{
  pushd "$_PGEM_LOC" > /dev/null
  local gem
  for gem in $_GEM_LIST
  do
    if [[ -d "$gem" ]]
    then
      pushd "$gem" > /dev/null
      "$@"
      local exit=$?
      if [[ $exit != 0 ]]
      then
        _PGEM_LOAD_EXIT_CODE=$exit
        err "'$*' failed in $gem"
      fi
      popd > /dev/null
    elif $_PGEM_DEBUG
    then
      err "$gem is not a directory."
      _GEM_LIST=${_GEM_LIST//$gem/}
    fi
  done
  popd > /dev/null
}

# Pulls in updates for the current directory, currently aware of Mercurial and Git
# Alternatively create an update.sh script in the current directory to specify
# custom update behavior
_updateRepo()
{
  local dir
  dir=$(basename "$(pwd)")
  if [[ -f "noupdate" ]]
  then
    echo "Not updating $dir"
    return
  fi
  echo "Updating $dir"
  if [[ -f "update.sh" ]]
  then
    ./update.sh
  elif [[ -d ".hg" ]]
  then
    # separate steps, so that we update even if pull doesn't
    # find anything (i.e. someone pushed to this repo)
    # FIXME this doesn't correctly prompt/exit if conflicts
    hg pull > /dev/null
    hg up > /dev/null
  elif [[ -d ".git" ]]
  then
    git pull --rebase > /dev/null
  else
    err "Could not update $dir"
    return 1
  fi
}

# Sources a file if it exists, skips if not
_srcIfExist()
{
  if [[ -f "$1" ]]
  then
    log "Including $(_dispPath "$1")"
    # shellcheck disable=SC1090
    . "$1"
  fi
}

# Initialize environment
_loadBase()
{
  _srcIfExist "base.conf.sh"
}

# Evaluates the config file - not called by _eachGem
_evalConfig()
{
  _srcIfExist "$(_findConfigFile)"
}

# Set environment variables
_loadEnv()
{
  _srcIfExist "environment.sh"
}

# Load aliases
_loadAlias()
{
  _srcIfExist "aliases.sh"
}

# Define functions
_loadFuncs()
{
  _srcIfExist "functions.sh"
}

# Add scripts directory to PATH
_loadScripts()
{
  if [[ -d "scripts" ]]
  then
    log "Adding $(pwd)/scripts to \$PATH"
    # shellcheck disable=SC2155
    export PATH="$(pwd)/scripts:$PATH"
  fi
}

# Run commands
_loadCmds()
{
  _srcIfExist "commands.sh"
}

# Output doc file
_printDoc()
{
  if [[ -f "$1" ]]
  then
    $_PGEM_DEBUG && basename "$(pwd)"
    cat "$1"
  fi
}
