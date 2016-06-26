#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...

. ~/.zsh_pre_custom
. ~/.dotfiles/zsh/environment.zsh
. ~/.dotfiles/zsh/pgp.zsh
. ~/.dotfiles/zsh/zsh-tweaks.zsh

if [[ -s ~/.chruby ]] || [[ -s ~/.rubies ]]; then
  . ~/.dotfiles/zsh/chruby.zsh
  . ~/.dotfiles/zsh/rubies.zsh
fi

. ~/.dotfiles/zsh/travis.zsh
. ~/.dotfiles/zsh/git.zsh
. ~/.dotfiles/zsh/aliases.zsh
. ~/.dotfiles/zsh/post-hooks.zsh
. ~/.zsh_custom
