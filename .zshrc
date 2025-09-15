export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="simple" 
DISABLE_LS_COLORS="true"

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

alias python="python3"
alias pip="pip3"

alias tmux='tmux -u'

bindkey '^L' autosuggest-accept
