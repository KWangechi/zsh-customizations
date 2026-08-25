zmodload zsh/datetime
autoload -Uz add-zsh-hook

_CMDLOG="$HOME/.local/state/zsh/cmd_log"
mkdir -p "${_CMDLOG:h}"

_cmdlog_preexec() {
  __cmdlog_name=$1
  __cmdlog_dir=$PWD
}

_cmdlog_precmd() {
  local exit_code=$?
  if [[ -n "$__cmdlog_name" ]]; then
    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
      "$EPOCHSECONDS" "$exit_code" "$(id -un)" "$EUID" \
      "$__cmdlog_dir" "$__cmdlog_name" >> "$_CMDLOG"
  fi
  unset __cmdlog_name __cmdlog_dir
}

add-zsh-hook preexec _cmdlog_preexec
add-zsh-hook precmd  _cmdlog_precmd

history() {
  [[ -f "$_CMDLOG" ]] || return
  tail -r "$_CMDLOG" | while IFS=$'\x1f' read -r ts code who uid dir cmd; do
    local human
    strftime -s human "%Y-%m-%d %H:%M:%S %Z" "$ts"
    local label="$who"
    (( uid == 0 )) && label="${who} (root)"
    printf '%s  [exit %-3s]  %-12s  %-30s  %s\n' \
      "$human" "$code" "$label" "${dir/#$HOME/~}" "$cmd"
  done
}
