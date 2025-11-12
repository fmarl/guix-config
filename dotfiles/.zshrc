typeset -U path cdpath fpath manpath

autoload -U compinit && compinit
HISTSIZE="10000"
SAVEHIST="10000"

HISTFILE="/home/marrero/.zsh_history"

enabled_opts=(
  HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY autocd
)
for opt in "${enabled_opts[@]}"; do
  setopt "$opt"
done
unset opt enabled_opts

disabled_opts=(
  APPEND_HISTORY EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS
  HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS
)
for opt in "${disabled_opts[@]}"; do
  unsetopt "$opt"
done
unset opt disabled_opts

. $HOME/.profile

eval "$(starship init zsh)"
eval "$(direnv hook zsh)"
source <(fzf --zsh)
