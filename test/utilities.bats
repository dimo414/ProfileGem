#!/usr/bin/env bats
#
# Unit tests for util.gem

touch "$BATS_TEST_DIRNAME/../local.conf.sh" # ensure local.conf.sh exists
source "$BATS_TEST_DIRNAME/../load.sh"

# TODO use bats-assert or another library
# see https://github.com/ztombol/bats-docs/issues/15
expect_eq() {
  (( $# == 2 )) || { echo "Invalid inputs $*"; return 127; }
  if [[ "$1" != "$2" ]]; then
    printf "Actual:   '%s'\nExpected: '%s'\n" "$1" "$2"
    return 1
  fi
}

expect_match() {
  (( $# == 2 )) || { echo "Invalid inputs $*"; return 127; }
  if ! [[ "$1" =~ ^$2$ ]]; then
    printf "Actual:   '%s'\nPattern: '^%s$'\n" "$1" "$2"
    return 1
  fi
}


@test "logging" {
  run pg::err hello world
  expect_eq "${output//$'\e'/\\e}" "\e[1;31mhello world\e[0m"
  run pg::log hello world
  expect_eq "${output//$'\e'/\\e}" ""

  _PGEM_DEBUG=true
  run pg::err hello world
  expect_eq "${output//$'\e'/\\e}" "\e[1;31mhello world\e[0m"
  run pg::log hello world
  expect_eq "${output//$'\e'/\\e}" "\e[35mhello world\e[0m"
}

@test "stack trace" {
  # disable pg::err's colorization
  pg::err() { printf '%s\n' "$*" >&2; }

  fn_start=$LINENO
  layer1() { layer2 one "$@" one; }
  layer2() { layer3 two "$@" two; }
  layer3() { pg::trace "$@"; echo layer3; }

  shopt -u extdebug
  run layer1 zero
  expect_eq "${lines[0]}" \
    'Stack trace while executing command: `layer3 two one zero one two`'
  expect_match "${lines[1]}" ".*:$((fn_start + 3))" # layer3 line no.
  expect_eq    "${lines[2]}" "  layer3"
  expect_match "${lines[3]}" ".*:$((fn_start + 2))" # layer2 line no.
  expect_eq    "${lines[4]}" "  layer2"
  expect_match "${lines[5]}" ".*:$((fn_start + 1))" # layer1 line no.
  expect_eq    "${lines[6]}" "  layer1"
  expect_eq    "${lines[8]}" "  run"

  # args are included in the trace if extdebug is set
  shopt -s extdebug
  run layer1 zero
  printf '# %s\n' "${lines[@]}"
  expect_eq "${lines[0]}" \
    'Stack trace while executing command: `layer3 two one zero one two`'
  expect_match "${lines[1]}" ".*:$((fn_start + 3))" # layer3 line no.
  expect_eq    "${lines[2]}" "  layer3 two one zero one two"
  expect_match "${lines[3]}" ".*:$((fn_start + 2))" # layer2 line no.
  expect_eq    "${lines[4]}" "  layer2 one zero one"
  expect_match "${lines[5]}" ".*:$((fn_start + 1))" # layer1 line no.
  expect_eq    "${lines[6]}" "  layer1 zero"
  expect_eq    "${lines[8]}" "  run layer1 zero"
}

@test "add path" {
  tmp_dir=$(cd "$(mktemp -d)" && pwd -P) # /tmp is a symlink on OSX
  mkdir "${tmp_dir}/bin"
  install /dev/null "${tmp_dir}/bin/cmd" # https://unix.stackexchange.com/a/47182/19157
  mkdir "${tmp_dir}/bin/sub"
  install /dev/null "${tmp_dir}/bin/sub/cmd"
  orig_PATH=$PATH

  # drop into a subshell just in case mucking with PATH confuses BATS at all
  # but alas, doing so confuses BATS line-blaming :(
  (
    # Don't use `run pg::add_path`, changes to PATH will not persist

    # error cases
    ! pg::add_path "${tmp_dir}/nonexistant"
    expect_eq "$PATH" "$orig_PATH" # unchanged
    ! pg::add_path "${tmp_dir}/bin/cmd" # don't use run - can't use subshells
    expect_eq "$PATH" "$orig_PATH" # unchanged

    # add path
    pg::add_path "${tmp_dir}/bin"
    expect_match "$PATH" "${tmp_dir}/bin.*"
    run which cmd
    expect_eq "$output" "${tmp_dir}/bin/cmd"
    new_PATH=$PATH
    # re-add is a no-op
    ! pg::add_path "${tmp_dir}/bin"
    expect_eq "$PATH" "$new_PATH" # unchanged on duplicate adds

    # add relative path
    cd "${tmp_dir}/bin/sub"
    pg::add_path .
    expect_match "$PATH" "${tmp_dir}/bin/sub.*"
    run which cmd
    expect_eq "$output" "${tmp_dir}/bin/sub/cmd"
  )
}

@test "decorate" {
  foo() { echo foo; }
  pg::decorate foo && foo() { printf "bar'%s'bar" "$(pg::decorated::foo)"; }

  run foo
  expect_eq "$output" "bar'foo'bar"

  # re-decorating doesn't overwrite pg::decorated
  pg::decorate foo
  run pg::decorated::foo
  expect_eq "$output" "foo"
}

@test "confirm" {
  ! pg::confirm <<<""
  pg::confirm <<<"y"
  pg::confirm <<<"YES"
  ! pg::confirm <<<"maybe"

  pg::confirm_no <<<""
  ! pg::confirm_no <<<"N"
  ! pg::confirm_no <<<"no"
  pg::confirm_no <<<"maybe"
}

@test "require" {
  tmp_dir=$(mktemp -d)
  printf '%s\n' '#!/usr/bin/env bash' 'echo hello world' > "${tmp_dir}/cmd"
  chmod +x "${tmp_dir}/cmd"

  ! command -v cmd # no cmd available yet
  pg::require cmd msg
  expect_eq "$(type -t cmd)" "function"
  ! which cmd

  export PATH="${tmp_dir}:${PATH}"
  which cmd
  expect_eq "$(type -t cmd)" "function"

  run cmd
  expect_eq "$output" "hello world"
  (( status == 0 ))
  cmd # need to invoke without run to clear the function definition
  expect_eq "$(type -t cmd)" "file"
  ! declare -F cmd
}