#!/usr/bin/env zsh
# Tests for plugins/cmd-timestamps. Run via tests/run.zsh, or directly:
#   zsh -f tests/cmd-timestamps.test.zsh

source ${0:A:h}/_harness.zsh
load_plugin cmd-timestamps

# Remember what the plugin ships with, then pin the limits: the rules below are
# what is under test, not whichever numbers happen to be the defaults today.
typeset -A SHIPPED
for v in TS_CMD_MAX_WORDS TS_CMD_MAX_WORD_LEN TS_CMD_MAX_LEN; do SHIPPED[$v]=${(P)v}; done
TS_CMD_MAX_WORDS=6 TS_CMD_MAX_WORD_LEN=24 TS_CMD_MAX_LEN=72

# --- status labels -----------------------------------------------------------

describe "_ts_status_label"
assert_eq "exit 0 reads as done"            "done"                 "$(_ts_status_label 0)"
assert_eq "exit 1 reports the code"         "failed (exit 1)"      "$(_ts_status_label 1)"
assert_eq "exit 127 reports the code"       "failed (exit 127)"    "$(_ts_status_label 127)"
assert_eq "exit 128 is still a failure"     "failed (exit 128)"    "$(_ts_status_label 128)"
assert_eq "130 names SIGINT (Ctrl-C)"       "interrupted SIG(INT)" "$(_ts_status_label 130)"
assert_eq "143 names SIGTERM"               "interrupted SIG(TERM)" "$(_ts_status_label 143)"

# --- command shortening ------------------------------------------------------

describe "_ts_truncate_command: short commands are left alone"
assert_eq "a bare command"      "ls"                  "$(_ts_truncate_command 'ls')"
assert_eq "a command with args" "git status --short"  "$(_ts_truncate_command 'git status --short')"
assert_eq "a trailing & is not a cut point" "sleep 5 &" "$(_ts_truncate_command 'sleep 5 &')"

describe "_ts_truncate_command: rule 1 — cut at the first separator"
assert_eq "a pipe"        "npm test …"   "$(_ts_truncate_command 'npm test | tee out.log')"
assert_eq "a pipe-with-stderr" "npm test …" "$(_ts_truncate_command 'npm test |& tee out.log')"
assert_eq "an and-list"   "make build …" "$(_ts_truncate_command 'make build && make deploy')"
assert_eq "an or-list"    "make build …" "$(_ts_truncate_command 'make build || echo failed')"
assert_eq "a semicolon"   "cd /tmp …"    "$(_ts_truncate_command 'cd /tmp; ls -la')"
assert_eq "a newline"     "echo one …"   "$(_ts_truncate_command $'echo one\necho two')"
assert_eq "a leading pipe is not a cut point" "| wc -l" "$(_ts_truncate_command '| wc -l')"

describe "_ts_truncate_command: rule 2 — keep the first few words"
assert_eq "six words is the budget" \
  "docker build -t app:1.2 --build-arg X=1 …" \
  "$(_ts_truncate_command 'docker build -t app:1.2 --build-arg X=1 -f Dockerfile .')"
assert_eq "exactly six words is untouched" \
  "docker build -t app:1.2 --build-arg X=1" \
  "$(_ts_truncate_command 'docker build -t app:1.2 --build-arg X=1')"
assert_eq "a quoted argument counts as one word" \
  'git commit -m "short msg" --amend' \
  "$(_ts_truncate_command 'git commit -m "short msg" --amend')"

describe "_ts_truncate_command: rule 3 — shorten over-long single words"
assert_eq "a long commit message keeps its quotes" \
  'git commit -m "fix: rework the auth r…"' \
  "$(_ts_truncate_command 'git commit -m "fix: rework the auth refactor"')"
assert_eq "--flag=\"...\" form is shortened too" \
  'git commit --message="fix: a reall…"' \
  "$(_ts_truncate_command 'git commit --message="fix: a really long commit message"')"
assert_eq "single quotes are preserved" \
  "echo 'aaaaaaaaaaaaaaaaaaaaaa…'" \
  "$(_ts_truncate_command "echo 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'")"
assert_eq "a long unquoted word gets no quote" \
  "curl https://example.com/som…" \
  "$(_ts_truncate_command 'curl https://example.com/some/very/long/path')"
assert_eq "a word of exactly the limit is untouched" \
  "echo aaaaaaaaaaaaaaaaaaaaaaaa" \
  "$(_ts_truncate_command 'echo aaaaaaaaaaaaaaaaaaaaaaaa')"

describe "_ts_truncate_command: rule 4 — hard cap on the whole line"
long_line=$(_ts_truncate_command 'echo aaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbb cccccccccccccccccccc dddddddddddddddddddd eeeeeeeeeeeeeeeeeeee')
assert_eq "never exceeds TS_CMD_MAX_LEN" 72 ${#long_line}
assert_match "ends with the ellipsis" '*…' "$long_line"

describe "_ts_truncate_command: edge cases"
assert_eq "an empty command"            ""          "$(_ts_truncate_command '')"
assert_eq "an unbalanced quote survives" 'echo "oops' "$(_ts_truncate_command 'echo "oops')"
assert_eq "a loop is cut at its semicolon" "for f in *.txt …" "$(_ts_truncate_command 'for f in *.txt; do echo $f; done')"

describe "the shipped defaults are documented in the README"
for v in TS_CMD_MAX_WORDS TS_CMD_MAX_WORD_LEN TS_CMD_MAX_LEN; do
  assert_eq "README records $v=$SHIPPED[$v]" \
    "$v=$SHIPPED[$v]" "$(grep -o "^$v=[0-9]*" $_T_ROOT/README.md | head -1)"
done

describe "_ts_truncate_command: the limits are tunable"
TS_CMD_MAX_WORDS=2
assert_eq "TS_CMD_MAX_WORDS"    "git status …" "$(_ts_truncate_command 'git status --short --branch')"
TS_CMD_MAX_WORDS=6
TS_CMD_MAX_WORD_LEN=8
assert_eq "TS_CMD_MAX_WORD_LEN" "echo aaaaaaa…" "$(_ts_truncate_command 'echo aaaaaaaaaaaaaaaa')"
TS_CMD_MAX_WORD_LEN=24
TS_ELLIPSIS='...'
assert_eq "TS_ELLIPSIS"         "npm test ..."  "$(_ts_truncate_command 'npm test | wc -l')"
TS_ELLIPSIS='…'

# --- the rendered summary line ----------------------------------------------

# Stand in for one prompt cycle: preexec, the command's exit status, precmd.
render() { _ts_preexec "$1"; (exit ${2:-0}); _ts_precmd }

describe "the summary line"
line=$(strip_ansi "$(render 'npm test')")
assert_match "opens with the marker and a timestamp" \
  '◆ Completed at: \[[0-9](#c4)-[0-9](#c2)-[0-9](#c2) [0-9](#c2):[0-9](#c2):[0-9](#c2) *\] *' "$line"
assert_contains "names the command"       "— npm test —"   "$line"
assert_match    "reports a duration"      '*— took [0-9]##.[0-9](#c3)s —*' "$line"
assert_match    "ends with the status"    '*— done'        "$line"
assert_contains "a failure shows the exit code" "failed (exit 2)" "$(strip_ansi "$(render 'false' 2)")"
assert_contains "an interrupt names the signal" "interrupted SIG(INT)" "$(strip_ansi "$(render 'sleep 99' 130)")"
assert_contains "the command is shortened in place" 'git commit -m "fix: rework the auth r…"' \
  "$(strip_ansi "$(render 'git commit -m "fix: rework the auth refactor"')")"

describe "the summary line: % in a command is not a prompt escape"
# How many ESC characters the line contains — one per colour change the plugin
# itself asked for. A %F in the command must not add any.
esc_count() { local bare=${1//[^$'\e']/}; print -r -- ${#bare} }

pct=$(render 'git log --format=%F{red}%h')
assert_contains "the literal text survives" 'git log --format=%F{red}%h' "$(strip_ansi "$pct")"
assert_eq "it emits no colour of its own" \
  "$(esc_count "$(render 'git log')")" "$(esc_count "$pct")"

summary
