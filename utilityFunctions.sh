#
# ProfileGem Utility Functions
# A collection of helper functions that are intended to be used by Gems
#

# Print a message to stderr
pg::err() { printf '\e[1;31m%s\e[0m\n' "$*" >&2; }
# Print a message to stderr if debug logging enabled
pg::log() { "$_PGEM_DEBUG" && printf '\e[35m%s\e[0m\n' "$*" >&2; }
# Prints a stack trace to stderr
# pass "$@" to include the current function's arguments in the trace
pg::trace() { pg::_trace_impl "$@"; }
# Prints a stack trace to stderr if debug logging enabled
# pass "$@" to include the current functions arguments in the trace
pg::debug_trace() { "$_PGEM_DEBUG" && pg::_trace_impl "$@"; }

# Prints a stack trace trimming the first two frames, as this will be called by
# pg::trace or pg::debug_trace.
pg::_trace_impl() {
  local skip_frames=2
  local cmd="${FUNCNAME[$skip_frames]}"
  (( $# )) && cmd="${cmd}$(printf " %q" "$@")"
  pg::err 'Stack trace while executing command: `'"$cmd"'`';
  local i
  for (( i=$skip_frames; i<${#FUNCNAME[@]}; i++ )); do
    pg::err $'\t'"${FUNCNAME[i]} at ${BASH_SOURCE[i]}:${BASH_LINENO[i-1]/#0/??}";
  done
}

# Adds a directory to the front of PATH, allowing ProfileGem to manage PATH
# rather than each gem doing so individually.
pg::add_path() {
  if [[ -d "${1:?Must specify a path to add}" ]]; then
    if echo $PATH | grep -q '^\(.*:\)*'"$1"'\(:.*\)*$'; then
      pg::log "$1 is already on the PATH, not adding..."
      return 2
    fi
    local absPath=$1
    # don't resolve symlinks unless the user provides a relative path
    if [[ "${absPath:0:1}" != "/" ]]; then
      absPath=$(pg::_realpath "$1")
  fi
    pg::log "Adding $absPath to the PATH"
    export PATH="$absPath:$PATH"
  else
    pg::err "$1 is not a directory, cannot add to PATH."
    return 1
  fi
}

# Copies a function f to pg::decorated::f, letting callers redefine but still call into (or
# decorate) the original function. This function is idempotent, in that repeated calls will not
# recursively decorate the original function.
#
# Note that if this function is called again the original function definition is restored to
# pg::decorated::f, *even if* subsequently f is redefined (e.g. during pgem_reload).
#
# TODO consider inspecting f's declaration for "pg::decorated" calls, and only treating functions
# that reference this string as decorations. This would allow pg::decorate to distinguish between
# still-decorated functions and redefined functions. Need to first convince myself this distinction
# is correct.
#
# Suggested usage (where func was originally defined elsewhere):
#
#   pg::decorated func &&
#   func() {
#     ...
#     pg::decorated::func ...
#   }
#
# Using && prevents func from being (re)defined if it didn't previously exist.
pg::decorate() {
  local func="${1:?"Must provide a function name to decorate"}"
  if declare -F "pg::decorated::${func}" &> /dev/null; then
    # This function has previously been decorated; restore the original version
    bc::copy_function "pg::decorated::${func}" "${func}"
  fi
  bc::copy_function "${func}" "pg::decorated::${func}"

  # Safe to delete after Oct 10, log -> err after Aug 10
  eval "_orig_${func}() {
    pg::log '${2:-"_orig_"}${func} is deprecated; use pg::::decorated::${func} instead'
    pg::debug_trace "'"$@"'"
    pg::decorated::${func} "'"$@"'"
  }"
}

# Prompt the user to confirm (y/n), defaulting to no.
# Returns a non-zero exit code on no.
pg::confirm() {
  local response
  read -r -p "${*:-"Are you sure you'd like to continue?"} [y/N] " response
  [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

# Prompt the user to confirm (y/n), defaulting to yes.
# Returns a non-zero exit code on no.
pg::confirm_no() {
  local response
  read -r -p "${*:-"Would you like to continue?"} [Y/n] " response
  ! [[ "$response" =~ ^([nN][oO]|[nN])$ ]]
}

# Defines a stub function named $1 if no such command is installed. The stub
# will prompt the user to install the missing command. This isn't generally
# necessary, but can be helpful when the command is used indirectly by a
# function provided by a gem and you can provide more details than the shell's
# built in command-not-found message.
#
# For example, if a function depends on ag the gem could add the following to
# its command.sh to point users in the right direction:
#    pg::require ag 'Install via https://github.com/ggreer/the_silver_searcher'
#
# Once the command is installed the stub function removes itself.
pg::require() {
  local cmd="${1:?cmd}"
  local msg="${2:?msg}"

  # This early check might increase startup time, especially if a gem calls
  # pg::require many times. It might be better to remove it so the function
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

# Deprecated function names - gems may still be calling these
# Safe to delete after October 10, log -> err after Aug 10
for f in pgem_err pgem_log pgem_trace pgem_debug_trace pgem_add_path pgem_decorate pgem_confirm \
    pgem_confirm_no pgem_require; do
  eval "$f() {
    pg::log '$f is deprecated; use pg::${f#pgem_} instead'
    pg::debug_trace "'"$@"'"
    pg::${f#pgem_} "'"$@"'"
  }"
done
_pgem_trace_impl() { pg::err '_pgem_trace_impl is deprecated'; pg::_trace_impl "$@"; }

# Scheduled for removal in Aug 2018
copy_function() {
  pg::err "copy_function is deprecated, please use bc::copy_function instead"
  bc::copy_function "$@"
}