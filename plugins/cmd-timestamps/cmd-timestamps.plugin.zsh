zmodload zsh/datetime
autoload -Uz add-zsh-hook

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

    # Color Format
    local color=2
    ((exit_code > 128)) && color=3 # yellow - interrupted
    (( exit_code > 0 && exit_code <=128 )) && color=1 #red - failed

    # Print timestamp
    print -rP "%F{8}◆ Completed at: [$finished] — %f%B%F{27}${__ts_cmd}%f%b%F{8} — took ${dur_fmt}s — %F{$color}${status_label}%F{8}%f"
  fi
  unset __ts_start __ts_cmd
}



add-zsh-hook preexec _ts_preexec
add-zsh-hook precmd  _ts_precmd

