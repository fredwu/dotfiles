HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=HISTSIZE

export GPG_TTY=$(tty)

export EDITOR=vim
export BUNDLER_EDITOR=code
export JULIA_EDITOR=code

export NODE_PATH=/usr/local/lib/node_modules

export RUBY_GC_MALLOC_LIMIT=90000000
export RUBY_GC_HEAP_FREE_SLOTS=200000
export JRUBY_OPTS=-J-Xmx2048m

export ERL_AFLAGS="-kernel shell_history enabled"
