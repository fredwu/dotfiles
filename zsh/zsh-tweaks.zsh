# Git branch autocompletion: only autocomplete local branches
# http://stackoverflow.com/questions/12175277/disable-auto-completion-of-remote-branches-in-zsh
zstyle :completion::complete:git-checkout:argument-rest:headrefs command "git for-each-ref --format='%(refname)' refs/heads 2>/dev/null"

# History Substring Search
zstyle ':prezto:module:history-substring-search' color 'yes'

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# https://github.com/zsh-users/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
