# Tiny assertion harness for the plugin tests. Pure zsh, no dependencies.
#
# A test file sources this, loads a plugin, makes assertions, and ends with
# `summary`. Each file runs in its own `zsh -f`, so nothing leaks between them.

setopt extended_glob

_T_ROOT=${${(%):-%x}:A:h:h}
typeset -g _T_PASS=0 _T_FAIL=0 _T_TODO=0 _T_SKIP=0

if [[ -t 1 ]]; then
  _T_GREEN=$'\e[32m' _T_RED=$'\e[31m' _T_YELLOW=$'\e[33m' _T_DIM=$'\e[2m' _T_OFF=$'\e[0m'
else
  _T_GREEN='' _T_RED='' _T_YELLOW='' _T_DIM='' _T_OFF=''
fi

# --- reporting ---------------------------------------------------------------

describe() { print -r -- "  ${_T_DIM}$1${_T_OFF}" }

_t_pass() { (( _T_PASS++ )); print -r -- "    ${_T_GREEN}ok${_T_OFF}    $1" }

_t_fail() {
  (( _T_FAIL++ ))
  print -r -- "    ${_T_RED}FAIL${_T_OFF}  $1"
  print -r -- "            expected: ${(qq)2}"
  print -r -- "            actual:   ${(qq)3}"
}

skip() { (( _T_SKIP++ )); print -r -- "    ${_T_YELLOW}skip${_T_OFF}  $1 ${_T_DIM}($2)${_T_OFF}" }

summary() {
  print -r -- ""
  print -r -- "  ${_T_PASS} passed, ${_T_FAIL} failed, ${_T_TODO} known-fail, ${_T_SKIP} skipped"
  (( _T_FAIL )) && exit 1
  exit 0
}

# --- assertions --------------------------------------------------------------

assert_eq() {  # desc expected actual
  [[ $3 == "$2" ]] && _t_pass "$1" || _t_fail "$1" "$2" "$3"
}

assert_match() {  # desc zsh-glob actual
  [[ $3 == $~2 ]] && _t_pass "$1" || _t_fail "$1" "matching $2" "$3"
}

assert_contains() {  # desc needle haystack
  [[ $3 == *"$2"* ]] && _t_pass "$1" || _t_fail "$1" "containing $2" "$3"
}

assert_true() {  # desc command...
  local desc=$1; shift
  if "$@"; then _t_pass "$desc"; else _t_fail "$desc" "true" "false: $*"; fi
}

# A behaviour that is documented but does not work yet. Reported, never fatal,
# so a known bug can have a test before it has a fix. If it starts passing the
# output says so — promote it to assert_eq then.
todo_eq() {  # desc expected actual
  (( _T_TODO++ ))
  if [[ $3 == "$2" ]]; then
    print -r -- "    ${_T_YELLOW}TODO${_T_OFF}  $1 ${_T_DIM}(now passes — promote to assert_eq)${_T_OFF}"
  else
    print -r -- "    ${_T_YELLOW}todo${_T_OFF}  $1 ${_T_DIM}(known failure)${_T_OFF}"
    print -r -- "            expected: ${(qq)2}"
    print -r -- "            actual:   ${(qq)3}"
  fi
}

# --- helpers -----------------------------------------------------------------

load_plugin() { source $_T_ROOT/plugins/$1/$1.plugin.zsh }

strip_ansi() { print -r -- "${1//$'\e'\[[0-9;]#m/}" }

# A throwaway $HOME, so tests never touch the real ~/.local/state/zsh/cmd_log.
fresh_home() {
  _T_HOME=$(mktemp -d -t zsh-cust-test)
  export HOME=$_T_HOME
  trap '[[ $_T_HOME == *zsh-cust-test* ]] && rm -rf -- $_T_HOME' EXIT INT TERM
}
