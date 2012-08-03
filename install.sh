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


if ! feature_exist "RVM" ".rvm" ; then
  curl -L get.rvm.io | bash -s head
fi

if ! feature_exist "Oh-my-zsh" ".oh-my-zsh" ; then
  curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh
fi

if ! feature_exist "Zsh-syntax-highlighting" \
  ".oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ; then
  git clone git://github.com/zsh-users/zsh-syntax-highlighting.git \
  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

if ! feature_exist "Custom oh-my-zsh theme" \
  ".oh-my-zsh/custom/fredwu.zsh-theme" ; then
  ln -s $PWD/zsh/fredwu.zsh-theme ~/.oh-my-zsh/custom/
fi

if ! feature_exist "Janus" ".vim/janus" ; then
  curl -Lo- http://bit.ly/janus-bootstrap | bash
fi

if ! feature_exist "Custom ZSH variables" ".zsh_custom" ; then
  cp $PWD/zsh/custom.example ~/.zsh_custom
fi

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
