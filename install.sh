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

apt_get_exist() {
  which apt-get &> /dev/null
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
    ln -s ~/.dotfiles/templates/$filename ~/.$filename
    echo ".$filename is linked."
  fi
}

element_in_array() {
  local e
  for e in "${@:2}"; do [[ "$e" = "$1" ]] && return 0; done
  return 1
}

if [[ "$(uname -s)" == "Darwin" ]] ; then
  if ! homebrew_exist ; then
    ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
  fi

  brew install git zsh vim chruby ruby-install direnv fasd gpg gpg-agent
else
  if apt_get_exist ; then
    sudo apt-get update
    sudo apt-get install -y git zsh vim python-software-properties build-essential gnupg-agent
  fi

  if ! feature_exist "chruby" ".chruby" ; then
    git clone https://github.com/postmodern/chruby.git ~/.chruby
    cd ~/.chruby
    make install
  fi

  if ! feature_exist "ruby-install" ".ruby-install" ; then
    git clone https://github.com/postmodern/ruby-install.git ~/.ruby-install
    cd ~/.ruby-install
    make install

    ruby-install ruby 2.6
  fi

  if ! feature_exist "direnv" ".direnv" ; then
    wget https://go.googlecode.com/files/go1.2.linux-386.tar.gz
    tar -C /usr/local -xzf go1.2.linux-386.tar.gz

    git clone https://github.com/zimbatm/direnv.git ~/.direnv
    cd ~/.direnv
    make install
  fi

  cd ~
fi

if ! feature_exist "Prezto" ".zprezto" ; then
  git clone --recursive https://github.com/sorin-ionescu/prezto.git ~/.zprezto
fi

if ! feature_exist "Custom Prezto theme" \
  ".zprezto/modules/prompt/functions/prompt_fredwu_setup" ; then
  ln -s ~/.dotfiles/templates/zprezto/prompt_fredwu_setup ~/.zprezto/modules/prompt/functions/
fi

if ! feature_exist "spf13-vim" ".spf13-vim-3" ; then
  curl http://j.mp/spf13-vim3 -L -o - | bash
fi

if ! feature_exist "Custom ZSH variables" ".zsh_custom" ; then
  cp ~/.dotfiles/zsh/custom.example ~/.zsh_custom
fi

if ! feature_exist "SSH config" ".ssh/config" ; then
  ln -s ~/.dotfiles/templates/ssh/config ~/.ssh/config
fi

if feature_exist "PGP Agent" ".gnupg/gpg.conf" ; then
  sed -i -e 's/^# use-agent/use-agent/g' ~/.gnupg/gpg.conf
fi

if ! feature_exist "PGP Agent Config" ".gnupg/gpg-agent.conf" ; then
  ln -s ~/.dotfiles/templates/gnupg/gpg-agent.conf ~/.gnupg/gpg-agent.conf
fi

touch ~/.zsh_pre_custom

cd ~/.dotfiles/templates

for f in ~/.dotfiles/templates/*; do
  filename="$(basename $f)"

  if [[ -f $filename ]] ; then
    backup_and_link_file $f
  fi
done

cd ~/.dotfiles

/bin/zsh
source ~/.zshrc
chsh -s /bin/zsh
