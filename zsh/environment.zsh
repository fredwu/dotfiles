HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=HISTSIZE

export GPG_TTY=$(tty)

export EDITOR=vim
export BUNDLER_EDITOR=code
export JULIA_EDITOR=code

export NODE_PATH=/usr/local/lib/node_modules

export KERL_BUILD_DOCS="yes"
export KERL_BUILD_PLT="yes"
export KERL_CONFIGURE_OPTIONS="--disable-debug --disable-silent-rules --enable-dynamic-ssl-lib --enable-hipe --enable-shared-zlib --enable-smp-support --enable-threads --enable-wx --with-ssl=/opt/homebrew/opt/openssl@1.1 --without-javac --without-odbc --enable-darwin-64bit --enable-kernel-poll --with-dynamic-trace=dtrace"

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

export PATH="/opt/homebrew/opt/python@3.9/libexec/bin:/opt/homebrew/opt/openjdk/bin:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:/opt/homebrew/opt/node@18/bin:/opt/homebrew/sbin:/opt/homebrew/bin:$PATH"
