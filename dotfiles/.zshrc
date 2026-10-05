typeset -U path cdpath fpath manpath

HISTSIZE="10000"
SAVEHIST="10000"
HISTFILE="$HOME/.zsh_history"

setopt HIST_FCNTL_LOCK
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

setopt AUTO_CD

export GPG_TTY="$(tty)"

PROMPT="%~ ${${SHLVL:#1}:+[$((SHLVL-1))] }λ "

autoload -U compinit

() {
    setopt LOCAL_OPTIONS EXTENDED_GLOB
    if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
        compinit
    else
        compinit -C
    fi
}

if (( $+commands[direnv] )); then
    eval "$(direnv hook zsh)"
fi

if (( $+commands[fzf] )); then
    source <(fzf --zsh)
fi

# Has to be sourced last
zsh_hl="$HOME/.guix-home/profile/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -r "$zsh_hl" ]] && source "$zsh_hl"
unset zsh_hl
