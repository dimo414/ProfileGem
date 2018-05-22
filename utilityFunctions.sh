#
# ProfileGem Utility Functions
# A collection of helper functions that are intended to be used by Gems
#

# Print a message to stderr
pgem_err() { echo "$@" >&2; }
# Print a message to stderr if debug logging enabled
pgem_log() { "$_PGEM_DEBUG" && pgem_err "$@"; }
# Prints a stack trace to stderr
# pass "$@" to include the current functions arguments in the trace
pgem_trace() { _pgem_trace_impl "$@"; }
# Prints a stack trace to stderr if debug logging enabled
# pass "$@" to include the current functions arguments in the trace
pgem_debug_trace() { "$_PGEM_DEBUG" && _pgem_trace_impl "$@"; }

# Prints a stack trace trimming the first two frames, as this will be called by
# pgem_trace or pgem_debug_trace.
_pgem_trace_impl() {
  local skip_frames=2
  local cmd="${FUNCNAME[$skip_frames]}"
  (( $# )) && cmd="${cmd}$(printf " %q" "$@")"
  pgem_err 'Stack trace while executing command: `'"$cmd"'`';
  local i
  for (( i=$skip_frames; i<${#FUNCNAME[@]}; i++ )); do
    pgem_err $'\t'"${FUNCNAME[$i]} at ${BASH_SOURCE[$i]}:${BASH_LINENO[$i]/#0/??}";
  done
}

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
  if declare -F "${prefix}${func}" &> /dev/null; then
    # This function has previously been decorated; restore the original version
    bc::copy_function "${prefix}${func}" "${func}"
  fi
  bc::copy_function "${func}" "${prefix}${func}"
}

# Given a name and an existing function, create a new function called name that
# executes the same commands as the initial function.
# Scheduled for removal in Aug 2018
copy_function() {
  pgem_log "copy_function is deprecated, please use bc::copy_function instead"
  bc::copy_function "$@"
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

# Installs a stub function named $1 if no such command is installed. The stub
# will prompt the user to install the missing command. This isn't generally
# necessary, but can be helpful when the command is used indirectly by a
# function provided by a gem and you can provide more details than the shell's
# built in command-not-found message.
#
# For example, if a function depends on ag the gem could add the following to
# its command.sh to point users in the right direction:
#    pgem_require ag 'Install via https://github.com/ggreer/the_silver_searcher'
#
# Once the command is installed the stub function removes itself.
pgem_require() {
  local cmd="${1:?cmd}"
  local msg="${2:?msg}"

  # This early check might increase startup time, especially if a gem calls
  # pgem_require many times. It might be better to remove it so the function
  # is always eval'ed - it will transparently remove itself upon being called.
  which "$cmd" &> /dev/null && return # already installed

  eval "$(cat <<EOF
    $cmd() {
      if which $cmd &> /dev/null; then
        unset -f $cmd
        $cmd "\$@"
        return
      fi

      printf '%s not available\n%s\n' $cmd '$msg' >&2
      return 127
    }
EOF
  )"
}
