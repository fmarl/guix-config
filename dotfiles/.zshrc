# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

typeset -U path cdpath fpath manpath

HISTSIZE="10000"
SAVEHIST="10000"
HISTFILE="$HOME/.zsh_history"

setopt HIST_FCNTL_LOCK
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY

setopt AUTO_CD

export GPG_TTY=$TTY

autoload -Uz vcs_info add-zsh-hook

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{blue}%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{blue}%b%f|%F{yellow}%a%f'

add-zsh-hook precmd vcs_info

setopt PROMPT_SUBST
PROMPT='${SSH_CONNECTION:+%m:}%~${vcs_info_msg_0_} '"${${SHLVL:#1}:+[$((SHLVL-1))] }"'%(?..%F{red}%? %f)%(!.%F{red}#%f.λ) '

fpath=(~/.guix-home/profile/share/zsh/site-functions $fpath)
autoload -U compinit

() {
    setopt LOCAL_OPTIONS EXTENDED_GLOB
    local dump=${ZDOTDIR:-$HOME}/.zcompdump
    if [[ -n $dump(#qN.mh+24) || ! -e $dump ]]; then
        compinit -d $dump
        touch $dump
    else
        compinit -C -d $dump
    fi
    [[ $dump.zwc -nt $dump ]] || zcompile $dump
}

eval "$(direnv hook zsh)"
source <(fzf --zsh)

# Has to be sourced last
source ~/.guix-home/profile/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
