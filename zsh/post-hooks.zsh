unsetopt correct
unsetopt correct_all

if command -v direnv >/dev/null; then
  eval "$(direnv hook zsh)"
fi

if command -v mise >/dev/null; then
  eval "$(mise activate zsh --shims)"
fi

source <(fzf --zsh)
eval "$(zoxide init zsh)"
eval "$(ssh-agent -s)" &>/dev/null
grep -slR "PRIVATE" ~/.ssh | xargs ssh-add &>/dev/null
