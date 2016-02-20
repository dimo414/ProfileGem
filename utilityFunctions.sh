#
# ProfileGem Utility Functions
# A collection of helper functions that are intended to be used by Gems
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
  local func="${1:?"Must provide a function name to decorate"}"
  local prefix="${2:-"_orig_"}"
if declare -F ${prefix}${func} >& /dev/null
  then
    # This function has previously been decorated; restore the original version
    _copy_function "${prefix}${func}" "${func}"
  fi
  _copy_function "${func}" "${prefix}${func}"
}

# Prompt the user to confirm (y/n), defaulting to no.
# Returns a non-zero exit code on no.
pgem_confirm()
{
  local response
  read -r -p "${*:-"Are you sure you'd like to continue?"} [y/N] " response
  [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

# Prompt the user to confirm (y/n), defaulting to yes.
# Returns a non-zero exit code on no.
pgem_confirm_no()
{
  local response
  read -r -p "${*:-"Would you like to continue?"} [Y/n] " response
  ! [[ "$response" =~ ^([nN][oO]|[nN])$ ]]
}
