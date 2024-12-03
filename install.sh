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
  which brew &>/dev/null
}

apt_get_exist() {
  which apt-get &>/dev/null
}

backup_and_link_file() {
  local file=$1
  local filename="$(basename $file)"
  local target_file=~/.$filename

  if [[ -e $target_file ]]; then
    if [[ -L $target_file ]] && cmp $target_file $file; then
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

if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! homebrew_exist; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  brew install git vim direnv fzf zoxide gpg openssl libyaml mise
  brew install font-hack-nerd-font
else
  if apt_get_exist; then
    sudo apt-get update
    sudo apt-get install -y git zsh vim software-properties-common build-essential gnupg-agent direnv libz-dev libssl-dev libffi-dev libyaml-dev
  fi

  mkdir -p ~/.local/share/fonts
  cd ~/.local/share/fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf

  cd ~
fi

if ! feature_exist "Prezto" ".zprezto"; then
  git clone --recursive https://github.com/sorin-ionescu/prezto.git ~/.zprezto
fi

if ! feature_exist "Prezto" ".zprezto/contrib"; then
  cd ~/.zprezto
  git clone --recurse-submodules https://github.com/belak/prezto-contrib contrib
fi

if ! feature_exist "spf13-vim" ".spf13-vim-3"; then
  curl http://j.mp/spf13-vim3 -L -o - | bash
fi

if ! feature_exist "Custom ZSH variables" ".zsh_custom"; then
  cp ~/.dotfiles/zsh/custom.example ~/.zsh_custom
fi

if ! feature_exist "SSH config" ".ssh/config"; then
  ln -s ~/.dotfiles/templates/ssh/config ~/.ssh/config
fi

if feature_exist "PGP Agent" ".gnupg/gpg.conf"; then
  sed -i -e 's/^# use-agent/use-agent/g' ~/.gnupg/gpg.conf
fi

touch ~/.zsh_pre_custom

cd ~/.dotfiles/templates

for f in ~/.dotfiles/templates/*; do
  filename="$(basename $f)"

  if [[ -f $filename ]]; then
    backup_and_link_file $f
  fi
done

cd ~/.dotfiles

/bin/zsh
source ~/.zshrc
chsh -s /bin/zsh
