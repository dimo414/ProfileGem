source "$BATS_TEST_DIRNAME/../getopts.sh"
pg::err() { printf '%s\n' "$*" >&2; }

expect_eq() {
  (( $# == 2 )) || { echo "Invalid inputs $*"; return 127; }
  if [[ "$1" != "$2" ]]; then
    echo "Actual:   '$1'"
    echo "Expected: '$2'"
    return 1
  fi
}

@test "pg::getopts basic usage" {
  basic() {
    _usage="It's pretty basic..."
    eval "$(pg::getopts abc:d:)"
    echo "a=${a} b=${b} c=${c} d=${d} -- $#: $*"
  }

  run basic
  (( status == 0 ))
  expect_eq "$output" 'a=0 b=0 c= d= -- 0: '

  run basic -d foo -cbar -a -b 'hello world'
  (( status == 0 ))
  expect_eq "$output" 'a=1 b=1 c=bar d=foo -- 1: hello world'

  run basic -d foo -d bar -d baz biff
  (( status == 0 ))
  expect_eq "$output" 'a=0 b=0 c= d=baz -- 1: biff'

  run basic -v
  (( status != 0 ))
  expect_eq "$output" $'Unknown option \'-v\'\nUsage: It\'s pretty basic...'

  run basic -c
  (( status != 0 ))
  expect_eq "$output" $'Option \'-c\' requires an argument\nUsage: It\'s pretty basic...'
}

@test "pg::getopts numeric args" {
  num() {
    eval "$(pg::getopts 012:a)"
    echo "0=${o0} 1=${o1} 2=${o2} a=${a} -- $#: $*"
  }

  run num
  (( status == 0 ))
  expect_eq "$output" '0=0 1=0 2= a=0 -- 0: '

  run num -a -2 foo -1 -0 bar
  (( status == 0 ))
  expect_eq "$output" '0=1 1=1 2=foo a=1 -- 1: bar'
}

@test "pg::getopts min_args" {
  min() {
    eval "$(pg::getopts abc:d: 2)"
    echo "a=${a} b=${b} c=${c} d=${d} -- $#: $*"
  }

  run min
  (( status != 0 ))
  expect_eq "$output" 'Insufficient arguments; minimum 2'

  run min -a -b -c foo -d bar
  (( status != 0 ))
  expect_eq "$output" 'Insufficient arguments; minimum 2'

  run min foo
  (( status != 0 ))
  expect_eq "$output" 'Insufficient arguments; minimum 2'

  run min foo bar
  (( status == 0 ))
  expect_eq "$output" 'a=0 b=0 c= d= -- 2: foo bar'

  run min -a -b foo bar baz
  (( status == 0 ))
  expect_eq "$output" 'a=1 b=1 c= d= -- 3: foo bar baz'
}

@test "pg::getopts max_args" {
  max() {
    eval "$(pg::getopts abc:d: 0 2)"
    echo "a=${a} b=${b} c=${c} d=${d} -- $#: $*"
  }

  run max
  (( status == 0 ))
  expect_eq "$output" 'a=0 b=0 c= d= -- 0: '

  run max -a -b -c foo -d bar
  (( status == 0 ))
  expect_eq "$output" 'a=1 b=1 c=foo d=bar -- 0: '

  run max foo
  (( status == 0 ))
  expect_eq "$output" 'a=0 b=0 c= d= -- 1: foo'

  run max foo bar
  (( status == 0 ))
  expect_eq "$output" 'a=0 b=0 c= d= -- 2: foo bar'

  run max -a -b foo bar baz
  (( status != 0 ))
  expect_eq "$output" 'Too many arguments; maximum 2'
}

@test "pg::getopts invalid optstring" {
  invalid() { eval "$(pg::getopts '@invalid')"; echo "not reached"; }
  run invalid
  (( status == 2 ))
  expect_eq "$output" 'Invalid optstring: @invalid'
}

@test "pg::getopts positional only" {
  pos() {
    eval "$(pg::getopts '' 2 2)"; echo "args:$#"
  }

  run pos
  (( status == 2 ))
  expect_eq "$output" 'Insufficient arguments; minimum 2'

  run pos 1
  (( status == 2 ))
  expect_eq "$output" 'Insufficient arguments; minimum 2'

  run pos 1 2
  (( status == 0 ))
  expect_eq "$output" 'args:2'

  run pos 1 2 3
  (( status == 2 ))
  expect_eq "$output" 'Too many arguments; maximum 2'
}
