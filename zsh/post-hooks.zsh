unsetopt correct
unsetopt correct_all

if command -v direnv >/dev/null; then
  eval "$(direnv hook zsh)"
fi

if command -v mise >/dev/null; then
  eval "$(mise activate zsh --shims)"
fi

if command -v brew >/dev/null; then
  eval "$(brew shellenv)"
fi

if command -v fzf >/dev/null; then
  source <(fzf --zsh)
fi

if command -v zoxide >/dev/null; then
  eval "$(zoxide init zsh)"
fi

if command -v ssh-agent >/dev/null; then
  eval "$(ssh-agent -s)" &>/dev/null
  grep -slR "PRIVATE" ~/.ssh | xargs ssh-add &>/dev/null
fi
