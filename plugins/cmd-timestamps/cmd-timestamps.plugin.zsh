zmodload zsh/datetime
autoload -Uz add-zsh-hook

# How much of the command to keep in the summary line. Override in ~/.zshrc.
: ${TS_CMD_MAX_WORDS:=5}      # shell words kept before giving up
: ${TS_CMD_MAX_WORD_LEN:=20}  # longest single word (commit messages, URLs, paths)
: ${TS_CMD_MAX_LEN:=72}       # hard cap on the whole rendered command
: ${TS_ELLIPSIS:=…}

_ts_status_label() {
  local code=$1

  if ((code == 0)); then
    print -r -- "done"

  elif ((code > 128 )); then
    local sig_num=$((code - 128))
    local sig_name=$(kill -l "$sig_num" 2>/dev/null)

    print -r -- "interrupted SIG(${sig_name:-$sig_num})"

  else
    print -r -- "failed (exit ${code})"

  fi
}

# Shrink a command to something that still says what ran, without trying to be
# the command itself — the full text is one `history` away.
#
#   git commit -m "a very long message about the thing"
#       -> git commit -m "a very long messag…"
#   docker build -t app:latest --build-arg NODE_ENV=production -f ./docker/Dockerfile .
#       -> docker build -t app:latest --build-arg …
#   npm test | tee out.log
#       -> npm test …
_ts_truncate_command() {
  # Multi-line commands collapse onto one line; an unquoted newline reads as a
  # separator, so only the first line survives below.
  local cmd=${1//$'\n'/ ; }
  local -a words
  local trimmed='' out i w

  # Shell-word split: a quoted argument stays a single word, so a commit
  # message is shortened as one unit instead of by word count.
  words=( ${(z)cmd} )
  (( ${#words} )) || words=( ${=cmd} )   # fall back if (z) can't parse it

  # Stop at the first pipeline/list separator — the first stage carries the intent.
  for (( i = 1; i <= ${#words}; i++ )); do
    case ${words[i]} in
      '|'|'|&'|'||'|'&&'|';')
        (( i > 1 )) && { words=( ${words[1,i-1]} ); trimmed=$TS_ELLIPSIS }
        break
        ;;
    esac
  done

  if (( ${#words} > TS_CMD_MAX_WORDS )); then
    words=( ${words[1,TS_CMD_MAX_WORDS]} )
    trimmed=$TS_ELLIPSIS
  fi

  for (( i = 1; i <= ${#words}; i++ )); do
    w=${words[i]}
    (( ${#w} <= TS_CMD_MAX_WORD_LEN )) && continue

    # keep the closing quote so a clipped string still reads as a string
    local close=''
    [[ $w == *\" ]] && close='"'
    [[ $w == *\' ]] && close="'"

    words[i]="${w[1,TS_CMD_MAX_WORD_LEN-1]}${TS_ELLIPSIS}${close}"
  done

  out=${(j: :)words}
  [[ -n $trimmed ]] && out+=" $trimmed"

  # Last resort, whatever shape the command had.
  (( ${#out} > TS_CMD_MAX_LEN )) && out="${out[1,TS_CMD_MAX_LEN-1]}${TS_ELLIPSIS}"

  print -r -- "$out"
}


_ts_preexec() {
  __ts_start=$EPOCHREALTIME
  __ts_cmd=$1
}

_ts_precmd() {
  local exit_code=$?
  if [[ -n "$__ts_start" ]]; then
    local dur=$(( EPOCHREALTIME - __ts_start ))
    local finished
    strftime -s finished "%Y-%m-%d %H:%M:%S %Z" $EPOCHSECONDS

    # Duration Format
    local dur_fmt
    printf -v dur_fmt "%.3f" "$dur"

    # Status Label
    local status_label
    status_label=$(_ts_status_label "$exit_code")

    # Command, shortened — and with % escaped, since print -P would otherwise
    # read a `%F`/`%B` in the command itself as a prompt escape.
    local cmd_short
    cmd_short=$(_ts_truncate_command "$__ts_cmd")
    cmd_short=${cmd_short//\%/%%}

    # Color Format
    local color=2
    (( exit_code > 128 )) && color=3 # yellow - interrupted
    (( exit_code > 0 && exit_code <=128 )) && color=1 #red - failed

    # Print timestamp
    print -rP "%F{8}◆ Completed at: [$finished] — %f%B%F{27}${cmd_short}%f%b%F{8} — took ${dur_fmt}s — %F{$color}${status_label}%F{8}%f"
  fi
  unset __ts_start __ts_cmd
}




add-zsh-hook preexec _ts_preexec
add-zsh-hook precmd  _ts_precmd
