unsetopt correct
unsetopt correct_all

if command -v direnv >/dev/null; then
  eval "$(direnv hook zsh)"
fi

if command -v rts >/dev/null; then
  eval "$(~/bin/rtx activate zsh)"
fi

eval "$(fasd --init auto)"
eval "$(ssh-agent -s)" &>/dev/null
grep -slR "PRIVATE" ~/.ssh | xargs ssh-add &>/dev/null

[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc
