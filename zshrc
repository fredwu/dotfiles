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

. ~/.dotfiles/zsh/environment
. ~/.dotfiles/zsh/zsh-tweaks
. ~/.dotfiles/zsh/chruby
. ~/.dotfiles/zsh/rubies
. ~/.dotfiles/zsh/travis
. ~/.dotfiles/zsh/aliases
. ~/.dotfiles/zsh/post-hooks
. ~/.zsh_custom
