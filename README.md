# zsh-customizations

A small collection of personal zsh plugins and themes.

## Layout

```
plugins/
  cmd-timestamps/     print timing info after every command
  cmd-history-log/    persistent, richer shell history
themes/               (empty for now)
```

## Plugins

### `cmd-timestamps`

After each command returns, prints a dim one-line summary: when it finished, what it was, how long it took, and its exit code.

```
◆ [21:04:37 EAT] — npm test — took 4.812s — exit 0
```

### `cmd-history-log`

Logs every command to `~/.local/state/zsh/cmd_log`, recording timestamp, exit
code, user (and whether it ran as root), and the working directory it ran in.
Overrides the `history` builtin to print that log newest-first:

```
2026-08-25 21:04:32 EAT  [exit 0  ]  wangechi        ~/projects/api                 npm test
```

Fields are stored separated by `\x1f` (unit separator), so commands containing
spaces, tabs, or newlines round-trip cleanly.

The log grows indefinitely — trim or rotate it yourself if that matters to you.

## Installation

Clone the repo somewhere, then source the plugins you want from `~/.zshrc`:

```sh
git clone https://github.com/<you>/zsh-customizations.git ~/.zsh-customizations

# in ~/.zshrc
source ~/.zsh-customizations/plugins/cmd-timestamps/cmd-timestamps.plugin.zsh
source ~/.zsh-customizations/plugins/cmd-history-log/cmd-history-log.plugin.zsh
```

Then reload:

```sh
source ~/.zshrc
```

### With oh-my-zsh

Symlink the plugin directories into your custom plugins folder and enable them
by name:

```sh
ln -s ~/.zsh-customizations/plugins/cmd-timestamps  ~/.oh-my-zsh/custom/plugins/cmd-timestamps
ln -s ~/.zsh-customizations/plugins/cmd-history-log ~/.oh-my-zsh/custom/plugins/cmd-history-log

# in ~/.zshrc
plugins=(... cmd-timestamps cmd-history-log)
```

## Requirements

- zsh with the `zsh/datetime` module (standard in most builds)
- `tail -r` for `cmd-history-log`'s reverse output — available on macOS/BSD; on GNU/Linux swap it for `tac`
