#
# ProfileGem Functions
# Used internally to prepare the profile, not meant to be called by the user
#

#
# User Functions
#

pgem_reload()
{
  $_PGEM_DEBUG && set | sort > /tmp/pgem_pre.env
  PATH="$_PRE_PGEM_PATH"
  \pushd "$_PGEM_LOC" > /dev/null
  . ./load.sh
  \popd > /dev/null
  if $_PGEM_DEBUG
  then
    set | sort > /tmp/pgem_post.env
    echo Environment Changes:
    diff /tmp/pgem_pre.env /tmp/pgem_post.env
  fi
}

pgem_update()
{
  \pushd "$_PGEM_LOC" > /dev/null
  _eachGem _updateRepo
  _updateRepo # update ProfileGem
  \popd > /dev/null
  pgem_reload
}

#
# Private Functions
#

# Given a relative path, prints the absolute path
_realpath()
{
  # realpath isn't standard on a lot of machines
  which realpath > /dev/null && realpath "$@" || echo $(cd "$@" && pwd -P)
}

# Expects a path argument and outputs the full path, with the path to ProfileGem stripped off
# e.g. dispPath /home/username/ProfileGem/my.gem => my.gem
_dispPath()
{
  echo $(_realpath "$@") | sed 's`^'"$_PGEM_LOC"'``'
}

# Output the list of gems to load, in order
# TODO could potentially construct some sort of gem dependancy graph, for now up to user to install and name in order
_gemList()
{
  ls "$_PGEM_LOC" | grep '.*\.gem$'
}

# Run "$@" in each gem
_eachGem()
{
  for gem in $_GEM_LIST
  do
    if [ -d $gem ]
    then
      \pushd $gem > /dev/null
      "$@"
      \popd > /dev/null
    elif $_PGEM_DEBUG
    then
      echo $gem is not a directory.
      _GEM_LIST=$(echo $_GEM_LIST | sed 's`'$gem'``')
    fi
  done
}

# Pulls in updates for the current directory, currently aware of Mercurial and Git
# Alternatively create an update.sh script in the current directory to specify
# custom update behavior
_updateRepo()
{
  dir=$(basename $(pwd))
  echo Updating $dir
  if [ -f update.sh ]
  then
    ./update.sh
  elif [ -d .hg ]
  then
    hg pull -u > /dev/null
  elif [ -d .git ]
  then
    git pull --rebase > /dev/null
  else
    echo "Could not update $dir" >&2
    return 1
  fi
}

# Sources a file, skips if not
_srcIfExist()
{
  if [ -f "$@" ]
  then
    $_PGEM_DEBUG && echo "Including $(_dispPath $@)"
    . "$@"
  fi
}

# Load a file before configuration files are processed
_loadPre()
{
  _srcIfExist pre.sh
}

# Parse configuration files
_parseConf()
{
  _srcIfExist base.conf.sh
  _srcIfExist hosts/${HOSTNAME}.conf.sh
  _srcIfExist users/${USER}.conf.sh
  _srcIfExist local.conf.sh
}

# Set environment variables
_loadEnv()
{
  _srcIfExist environment.sh
}

# Load aliases
_loadAlias()
{
  _srcIfExist aliases.sh
}

# Define functions
_loadFuncs()
{
  _srcIfExist functions.sh
}

# Add scripts directory to PATH
_loadScripts()
{
  if [ -d scripts ]
  then
    export PATH="$PATH:$(pwd)/scripts/"
  fi
}

# Run commands
_runCmd()
{
  _srcIfExist commands.sh
}
