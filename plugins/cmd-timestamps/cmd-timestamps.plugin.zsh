zmodload zsh/datetime
autoload -Uz add-zsh-hook

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

    local dur_fmt
    printf -v dur_fmt "%.3f" "$dur"


    # Print timestamp
    print -P "%F{8}◆ [$finished] — ${__ts_cmd} — took ${dur_fmt}s — exit ${exit_code}%f"
  fi
  unset __ts_start __ts_cmd
}

add-zsh-hook preexec _ts_preexec
add-zsh-hook precmd  _ts_precmd
