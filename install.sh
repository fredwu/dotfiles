#!/bin/bash

feature_exist() {
  local label=$1
  local feature=$2

  if [[ -e ~/$feature ]]; then
    echo "$label exists, ignored."
    true
  else
    echo "Installing $label ..."
    false
  fi
}

homebrew_exist() {
  which brew &> /dev/null
}

backup_and_link_file() {
  local file=$1
  local filename="$(basename $file)"
  local target_file=~/.$filename

  if [[ -e $target_file ]]; then
    if [[ -h $target_file ]] && cmp $target_file $file ; then
      echo ".$filename is identical, ignored."
    else
      mv $target_file "$target_file.backup.$(date +%s)"
      echo ".$filename is backed up."
    fi
  fi

  if [[ ! -e ~/.$filename ]]; then
    ln -s $PWD/$filename ~/.$filename
    echo ".$filename is linked."
  fi
}

element_in_array() {
  local e
  for e in "${@:2}"; do [[ "$e" = "$1" ]] && return 0; done
  return 1
}

if homebrew_exist ; then
  brew install chruby
  brew install ruby-install
  brew install direnv
else
  if ! feature_exist "chruby" ".chruby" ; then
    git clone git@github.com:postmodern/chruby.git ~/.chruby
    cd ~/.chruby
    make install
  fi

  if ! feature_exist "ruby-install" ".ruby-install" ; then
    git clone git@github.com:postmodern/ruby-install.git ~/.ruby-install
    cd ~/.ruby-install
    make install

    ruby-install ruby 2.1
  fi

  if ! feature_exist "direnv" ".direnv" ; then
    wget https://go.googlecode.com/files/go1.2.linux-386.tar.gz
    tar -C /usr/local -xzf go1.2.linux-386.tar.gz

    git clone git@github.com:zimbatm/direnv.git ~/.direnv
    cd ~/.direnv
    make install
  fi

  cd ~
fi

if ! feature_exist "Prezto" ".zprezto" ; then
  git clone --recursive git@github.com:sorin-ionescu/prezto.git ~/.zprezto
fi

if ! feature_exist "Custom Prezto theme" \
  ".zprezto/modules/prompt/functions/prompt_fredwu_setup" ; then
  ln -s $PWD/zsh/prompt_fredwu_setup ~/.zprezto/modules/prompt/functions/
fi

if ! feature_exist "spf13-vim" ".spf13-vim-3" ; then
  curl http://j.mp/spf13-vim3 -L -o - | bash
fi

if ! feature_exist "Custom ZSH variables" ".zsh_custom" ; then
  cp $PWD/zsh/custom.example ~/.zsh_custom
fi

if ! feature_exist "SSH config" ".ssh/config" ; then
  ln -s $PWD/ssh/config ~/.ssh/config
fi

touch ~/.zsh_pre_custom

cd ~/.dotfiles

for f in $PWD/*; do
  filename="$(basename $f)"
  files_to_ignore=(".git" "install.sh" "README.md")

  if [[ -f $filename ]] \
    && ! element_in_array $filename "${files_to_ignore[@]}" ; then
    backup_and_link_file $f
  fi
done

/bin/zsh
source ~/.zshrc
chsh -s /bin/zsh
