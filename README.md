# Fred Wu's Dot Files

![](screenshot.png)

## Prerequisites

For OS X, either Xcode or [Command Line Tools](https://developer.apple.com/downloads/).

For Linux, only Ubuntu is supported.

## Installation

    git clone git://github.com/fredwu/dotfiles ~/.dotfiles
    cd ~/.dotfiles
    ./install.sh

After the installation you might want to set the default login shell to zsh:

    chsh -s /bin/zsh

## Custom Configuration

- Make changes to `~/.zsh_custom`
- Use the command `sr` to reload the `.zshrc` source

## Features

- [Prezto](https://github.com/sorin-ionescu/prezto)
- [Spaceship ZSH](https://github.com/denysdovhan/spaceship-prompt/)
- [spf13-vim](https://github.com/spf13/spf13-vim)
- [direnv](https://github.com/zimbatm/direnv)
- [fasd](https://github.com/clvv/fasd)
- .ackrc
- .gemrc
- .gitconfig
- .railsrc
- .vimrc.after
- .vimrc.before
- .zshrc
