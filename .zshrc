export PATH="/usr/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/1000"
set -o emacs
alias r='fc -e -'
alias history='fc -l 1'
alias sudo=doas
HISTFILE=~/.histfile
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
export SRC_DIR="/home/rorka/rorkos/build-pkg/src"
export CHROOT_GLIBC="/home/rorka/rorkos/build-pkg/chroot-glibc"
export CHROOT_MUSL="/home/rorka/rorkos/build-pkg/chroot-musl"

_chroot-enter() {
    local root="$1"
    sudo mkdir -p "$root/build"  
    sudo mount --bind "$SRC_DIR" "$root/build" 2>/dev/null
    sudo mount --bind /dev "$root/dev" 2>/dev/null
    sudo mount --bind /dev/pts "$root/dev/pts" 2>/dev/null
    sudo mount -t proc proc "$root/proc" 2>/dev/null
    sudo mount -t sysfs sys "$root/sys" 2>/dev/null
    sudo mount --bind /tmp "$root/tmp" 2>/dev/null
    sudo chroot "$root" /bin/bash -c \
        "export HOME=/root TERM='$TERM' PATH=/bin:/sbin:/usr/bin:/usr/sbin; \
         PS1='(chroot) \w \\$ '; exec bash --norc --noprofile"
}

_chroot-exit-cleanup() {
    local root="$1"
    sudo umount -R "$root/dev" 2>/dev/null
    sudo umount "$root/proc" 2>/dev/null
    sudo umount "$root/sys" 2>/dev/null
    sudo umount "$root/tmp" 2>/dev/null
    sudo umount "$root/build" 2>/dev/null
}

chroot-glibc() {
    _chroot-enter "$CHROOT_GLIBC"
    _chroot-exit-cleanup "$CHROOT_GLIBC"
}

chroot-musl() {
    _chroot-enter "$CHROOT_MUSL"
    _chroot-exit-cleanup "$CHROOT_MUSL"
}

chroot-run-musl() {
    sudo mkdir -p "$CHROOT_MUSL/build"
    sudo mount --bind "$SRC_DIR" "$CHROOT_MUSL/build" 2>/dev/null
    sudo mount --bind /dev "$CHROOT_MUSL/dev" 2>/dev/null
    sudo mount -t proc proc "$CHROOT_MUSL/proc" 2>/dev/null
    sudo mount -t sysfs sys "$CHROOT_MUSL/sys" 2>/dev/null
    sudo chroot "$CHROOT_MUSL" /bin/bash -c "$1"
    _chroot-exit-cleanup "$CHROOT_MUSL"
}

chroot-run-glibc() {
    sudo mkdir -p "$CHROOT_GLIBC/build"
    sudo mount --bind "$SRC_DIR" "$CHROOT_GLIBC/build" 2>/dev/null
    sudo mount --bind /dev "$CHROOT_GLIBC/dev" 2>/dev/null
    sudo mount -t proc proc "$CHROOT_GLIBC/proc" 2>/dev/null
    sudo mount -t sysfs sys "$CHROOT_GLIBC/sys" 2>/dev/null
    sudo chroot "$CHROOT_GLIBC" /bin/bash -c "$1"
    _chroot-exit-cleanup "$CHROOT_GLIBC"
}
bindkey -e
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey '^[[C' forward-word
bindkey '^[[D' backward-word
bindkey '^H' backward-kill-word
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/compcache

autoload -Uz colors && colors
export LS_COLORS='di=34:ln=36:so=35:pi=33:ex=32:bd=1;33:cd=1;33:su=31:sg=31:tw=34:ow=34'

alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias cls='clear'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias top='htop 2>/dev/null || top'

setopt PROMPT_SUBST
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats ' %F{202}%b%f%F{250}%u%c%f'
zstyle ':vcs_info:git*' actionformats ' %F{208}%b%f(%F{196}%a%f)%F{250}%u%c%f'
zstyle ':vcs_info:git*' check-for-changes true
zstyle ':vcs_info:git*' unstagedstr '*'
zstyle ':vcs_info:git*' stagedstr '+'
precmd() { vcs_info }

_zsh_exit_code() {
    local ec=$?
    if (( ec == 0 )); then
        echo -n '%F{076}✓%f'
    else
        echo -n "%F{196}✗ $ec%f"
    fi
}

_zsh_git_branch() {
    [[ -n "${vcs_info_msg_0_}" ]] && echo -n "${vcs_info_msg_0_}"
    return 0 
}

PROMPT=$'%F{040}%n%f@%F{075}%m%f %F{045}%~%f$(_zsh_git_branch)\n%F{250}❯%f%F{040}❯%f '
RPROMPT=$'$(_zsh_exit_code)%F{240} %D{%H:%M:%S}%f'
if (( UID == 0 )); then
    PROMPT=$'%F{196}%n%f@%F{075}%m%f %F{045}%~%f$(_zsh_git_branch)\n%F{196}❯%f%F{208}❯%f '
fi

[[ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'

alias ls='eza --group-directories-first'
alias ll='eza -lah --group-directories-first --git'
alias la='eza -a --group-directories-first'
alias lt='eza -lah --tree --level=2 --group-directories-first'
alias lg='eza -lah --git --group-directories-first'

alias cat='bat'
alias catt='cat' 

export FZF_DEFAULT_OPTS='--height 40% --border --layout=reverse --color=fg:250,header:45,info:75,pointer:202,marker:202,prompt:75,hl:45,hl+:45'
bindkey '^R' fzf-history-widget
bindkey '^T' fzf-file-widget 2>/dev/null
_fzf_git_files() { local f; f=$(git ls-files 2>/dev/null | fzf); [[ -n "$f" ]] && LBUFFER="$LBUFFER$f"; }
zle -N _fzf_git_files
bindkey '^P' _fzf_git_files
unalias cat 2>/dev/null
cat() {
  for arg in "$@"; do
    if [ -f "$arg" ] && file --mime "$arg" 2>/dev/null | grep -q "binary"; then
      echo "=== $arg ($(file -b "$arg")) ==="
      xxd "$arg" | head -20
      echo "... ($(wc -c < "$arg") bytes total)"
    else
      command bat "$arg"
    fi
  done
}
export PATH="$HOME/.local/bin:$PATH"
export PATH=~/.npm-global/bin:$PATH
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=Fusion
export GTK_THEME=WhiteSur-Dark

alias opencode='nice -n 19 /home/rorka/.local/bin/opencode-dev'
alias ocd='nice -n 19 /home/rorka/.local/bin/opencode-dev'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"


alias agy="agy-run"
alias agy-warp="~/.local/bin/agy-warp"

[[ -o interactive ]] && fastfetch
