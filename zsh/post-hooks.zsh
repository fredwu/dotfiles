unsetopt correct
unsetopt correct_all

if [[ -s "which direnv" ]]; then
  eval "$(direnv hook zsh)"
fi

eval "$(fasd --init auto)"
eval "$(ssh-agent -s)" &> /dev/null
grep -slR "PRIVATE" ~/.ssh | xargs ssh-add &> /dev/null

[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc
