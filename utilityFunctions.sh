#
# ProfileGem Utility Functions
# A collection of helper functions that are intended to be used by Gems
#

# Print a message to stderr
pgem_err() { echo "$@" >&2; }
# Print a message to stderr if debug logging enabled
pgem_log() { $_PGEM_DEBUG && pgem_err "$@"; }

# Adds a directory to the front of PATH, allowing ProfileGem to manage PATH
# rather than each gem doing so individually.
pgem_add_path() {
  if [[ -d "${1:?Must specify a path to add}" ]]; then
    if echo $PATH | grep -q '^\(.*:\)*'"$1"'\(:.*\)*$'; then
      pgem_log "$1 is already on the PATH, not adding..."
      return 2
    fi
    local absPath=$1
    # don't resolve symlinks unless the user provides a relative path
    if [[ "${absPath:0:1}" != "/" ]]; then
      absPath=$(_realpath "$1")
  fi
    pgem_log "Adding $absPath to the PATH"
    export PATH="$absPath:$PATH"
  else
    pgem_err "$1 is not a directory, cannot add to PATH."
    return 1
  fi
}

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
pgem_decorate() {
  local func="${1:?"Must provide a function name to decorate"}"
  local prefix="${2:-"_orig_"}"
  if declare -F ${prefix}${func} >& /dev/null; then
    # This function has previously been decorated; restore the original version
    copy_function "${prefix}${func}" "${func}"
  fi
  copy_function "${func}" "${prefix}${func}"
}

# Given a name and an existing function, create a new function called name that
# executes the same commands as the initial function.
# Used by pgem_decorate.
copy_function() {
  local function="${1:?Missing function}"
  local new_name="${2:?Missing new function name}"
  declare -F "$function" >& /dev/null || { echo "No such function $1"; return 1; }
  eval "$(echo "${new_name}()"; declare -f "${1}" | tail -n +2)"
}


# Prompt the user to confirm (y/n), defaulting to no.
# Returns a non-zero exit code on no.
pgem_confirm() {
  local response
  read -r -p "${*:-"Are you sure you'd like to continue?"} [y/N] " response
  [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

# Prompt the user to confirm (y/n), defaulting to yes.
# Returns a non-zero exit code on no.
pgem_confirm_no() {
  local response
  read -r -p "${*:-"Would you like to continue?"} [Y/n] " response
  ! [[ "$response" =~ ^([nN][oO]|[nN])$ ]]
}
