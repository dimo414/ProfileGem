#
# ProfileGem Functions
# Used internally to prepare the profile, not meant to be called by the user
#

#
# User Functions
#

pgem_reload()
{
    PATH="$_PRE_PGEM_PATH"
    pushd "$_PGEM_LOC" > /dev/null
    . ./load.sh
    popd > /dev/null
}

pgem_update()
{
    echo "Updating ProfileGem"
    pushd "$_PGEM_LOC" > /dev/null
    _eachGem _updateGem
    hg pull -u
    popd > /dev/null
    pgem_reload
}

#
# Private Functions
#

# Expects a path argument and outputs the full path, with the path to ProfileGem stripped off
# e.g. dispPath /home/username/ProfileGem/my.gem => my.gem
_dispPath()
{
  echo $(realpath "$@") | sed 's`^'"$_PGEM_LOC"'``'
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
      pushd $gem > /dev/null
      "$@"
      popd > /dev/null
    elif $_PGEM_DEBUG
    then
      echo $gem is not a directory.
      _GEM_LIST=$(echo $_GEM_LIST | sed 's`'$gem'``')
    fi
  done
}

# Updates the gem from the parent repository or other update script
_updateGem()
{
    echo Updating $(_dispPath $(pwd))
    if [ -f update.sh ]
    then
        ./update.sh
    else
        hg pull -u
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

# Run commands
_runCmd()
{
  _srcIfExist commands.sh
}
