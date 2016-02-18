#
# ProfileGem Functions
#

#
# Core functionality
#

# Reloads ProfileGem and all gems. As long as the set of gems to load hasn't
# changed this should be idempotent.
pgem_reload()
{
  $_PGEM_DEBUG && set | sort > /tmp/pgem_pre.env
  PATH="$_PRE_PGEM_PATH"
  PS1="$_PRE_PGEM_PS1"
  PROMPT_COMMAND="$_PRE_PGEM_PROMPT_COMMAND"
  
  pushd "$_PGEM_LOC" > /dev/null
  . ./load.sh
  local ret=$?
  popd > /dev/null
  
  if $_PGEM_DEBUG
  then
    set | sort > /tmp/pgem_post.env
    echo Environment Changes:
    comm -3 /tmp/pgem_pre.env /tmp/pgem_post.env |
      sed -e 's`^[^\t]`- \0`' -e 's`^\t`+ `'
  fi
  unset _PGEM_LOAD_EXIT_CODE
  return $ret
}

# Pulls in updates to ProfileGem and all gems, then reloads them.
pgem_update()
{
  _PGEM_LOAD_EXIT_CODE=0
  pushd "$_PGEM_LOC" > /dev/null
  _eachGem _updateRepo
  _updateRepo # update ProfileGem
  popd > /dev/null
  pgem_reload
}

# Prints a usage summary of all installed gems.
# TODO improve this
pgem_info()
{
  echo Useful Commands:
  _eachGem _printDoc info.txt
  #echo 'Run `pgem_help` for more'
}

# TODO
#pgem_help()
#{
#  _eachGem _printDoc info.txt
#  echo
#  _eachGem _printDoc help.txt
#}

# Cron Functions
# In Beta; likely to be redesigned

# Writes a crontab file to stdout
pgem_cron_out()
{
  local load="$_PGEM_LOC/load.sh"
  cronFile()
  {
    local file="jobs.txt"
    if [ -f $file ]
    then
      echo -f $(_realpath $file)
    fi
  }
  local files=$(_eachGem cronFile)
  $_PGEM_LOC/cronBuild.py -p "$load" $files $@ $PGEM_JOBS
}

# Prints information about the available jobs
pgem_cron_info()
{
  pgem_cron_out -i
}

# Overwrites the user crontab with the ProfileGem crontab
pgem_cron_user()
{
  pgem_cron_out | crontab && echo "Successfully installed user crontab"
}

# Writes the ProfileGem crontab to /etc/cron.d
pgem_cron_etc()
{
  if [ -z $1 ]
  then
    local path=/etc/cron.d/profileGem
  else
    local path=$1
  fi
  pgem_cron_out -u - > $path && echo "Successfully installed system crontab to $path"
}

#
# Gem Utilities
#

# Copies a function f to _orig_f, letting callers redefine (or decorate) f
# http://stackoverflow.com/q/1203583
#
# Suggested usage:
#
#   pgem_decorate func &&
#   func() {
#     ...
#   }
#
# The && prevents func from being (re)defined if it didn't previously exist.
pgem_decorate()
{
  local func="${1:?Must provide a function name to decorate}"
  local prefix="${2:-_orig_}"
if declare -F ${prefix}${func} >& /dev/null
  then
    # This function has previously been decorated; restore the original version
    _copy_function ${prefix}${func} ${func}
  fi
  _copy_function ${func} ${prefix}${func}
}

