# based on https://github.com/robbyrussell/oh-my-zsh/blob/master/plugins/chruby/chruby.plugin.zsh

alias rubies='chruby'

function current_ruby() {
  local _ruby
  _ruby="$(chruby |grep \* |tr -d '* ')"
  if [[ $(chruby |grep -c \*) -eq 1 ]]; then
    echo ${_ruby}
  else
    echo "system"
  fi
}

function chruby_prompt_info() {
  echo "$(current_ruby)"
}

source /usr/local/share/chruby/chruby.sh
