#
# ProfileGem Utility Functions
# A collection of helper functions that are intended to be used by Gems
#

# Print a message to stderr
pg::err() { printf '\e[1;31m%s\e[0m\n' "$*" >&2; }
# Print a message to stderr if debug logging enabled
pg::log() { if "${_PGEM_DEBUG:-false}"; then printf '\e[35m%s\e[0m\n' "$*" >&2; fi; }
# Prints a stack trace to stderr
# pass "$@" to include the current function's arguments in the trace
pg::trace() { pg::_trace_impl "$@"; }
# Prints a stack trace to stderr if debug logging enabled
# pass "$@" to include the current functions arguments in the trace
pg::debug_trace() { if "${_PGEM_DEBUG:-false}"; then pg::_trace_impl "$@"; fi; }

# Prints a stack trace trimming the first two frames, as this will be called by
# pg::trace or pg::debug_trace. If run in extdebug mode trace will include
# function arguments.
#
# This could potentially use the caller builtin (https://unix.stackexchange.com/a/571421/19157)
# but handling the separate variables gives a bit more flexibilty, and we need
# to do it anyways in order to access the BASH_ARGV/BASH_ARGC vars.
pg::_trace_impl() {
  local skip_frames=2
  local cmd="${FUNCNAME[$skip_frames]}"
  (( $# )) && cmd="${cmd}$(printf " %q" "$@")"
  pg::err 'Stack trace while executing command: `'"$cmd"$'`\n  \t'"at ${BASH_SOURCE[2]}:${BASH_LINENO[1]/#0/??}"
  local i args
  for (( i=skip_frames; i<${#FUNCNAME[@]}; i++ )); do
    args=$(pg::_trace_args "$i")
    pg::err "  ${FUNCNAME[i]}${args}"$'\n  \t'"at ${BASH_SOURCE[i+1]:-}:${BASH_LINENO[i]/#0/??}"
  done
}

# Extract arguments from BASH_ARGV for a given stack frame - if extdebug is set
pg::_trace_args() {
  local skip_frames=$(( ${1:?frames} + 1)) i arg_idx=0 args=()
  for (( i=0; i<skip_frames; i++ )); do
    (( arg_idx += ${BASH_ARGC[$i]:-0} ))
  done
  for (( i=0; i<${BASH_ARGC[skip_frames]:-0}; i++ )); do
    args=("${BASH_ARGV[$(( arg_idx+i ))]}" "${args[@]}")
  done
  if (( ${#args[@]} )); then
    printf ' %q' "${args[@]}"
  fi
}

# Given a relative path, resolves symlinks and prints an absolute path.
# Many systems provide a realpath command or support readlink -f, but not all.
if command -v realpath &> /dev/null; then
  pg::realpath() { realpath "$1"; }
elif readlink -f / &> /dev/null; then
  pg::realpath() { readlink -f "$1"; }
else
  # readlink -f doesn't exist on OSX, need to implement manually
  pg::realpath() {
    if [[ -d "${1:?}" ]]; then
      (cd "$1" && pwd -P)
    else
      echo "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
    fi
  }
fi
# Legacy name, safe to delete
pg::_realpath() { pg::log 'pg::_realpath has been renamed pg::realpath'; pg::realpath "$@"; }

# Returns an absolute path, but not necesarilly a canonical path (e.g. may
# contain /.. or /. segments, or symlinks). Should be faster than pg::realpath
# as it doesn't need to touch the file system.
pg::absolute_path() {
  if [[ "${1:?}" == /* ]]; then
    echo "$1"
  else
    printf '%s/%s\n' "$PWD" "$1"
  fi
}

# Restructures a path to be relative to the given location, PWD if unspecified
# See (way too many) approaches in https://stackoverflow.com/q/2564634/113632
# The most reasonable approach seems to be delegating to python:
# https://stackoverflow.com/a/31236568/113632
# Note that realpath --relative-to requires paths exist, which we don't need.
pg::relative_path() {
  python -c 'import os,sys; print(os.path.relpath(*(sys.argv[1:])))' \
    "${1:?}" "${2:-$PWD}"
}

# Adds a directory to the front of PATH, allowing ProfileGem to manage PATH
# rather than each gem doing so individually.
pg::add_path() {
  if [[ -d "${1:?Must specify a path to add}" ]]; then
    if grep -q '^\(.*:\)*'"$1"'\(:.*\)*$' <<<"$PATH"; then
      pg::log "$1 is already on the PATH, not adding..."
      return 2
    fi
    local absPath=$1
    # don't resolve symlinks unless the user provides a relative path
    if [[ "$absPath" != /* ]]; then
      absPath=$(pg::realpath "$1")
  fi
    pg::log "Adding ${absPath} to the PATH"
    export PATH="${absPath}:${PATH}"
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
#   pg::decorate func &&
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
      if which "$cmd" &> /dev/null; then
        unset -f "$cmd"
        "$cmd" "\$@"
        return
      fi

      printf '%s not available\n%s\n' "$cmd" "$(printf %q "$msg")" >&2
      return 127
    }
EOF
  )"
}
