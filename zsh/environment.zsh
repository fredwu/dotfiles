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
export KERL_CONFIGURE_OPTIONS="--disable-debug --disable-silent-rules --enable-dynamic-ssl-lib --disable-hipe --enable-shared-zlib --enable-smp-support --enable-threads --enable-wx --with-odbc=/usr/local/opt/unixodbc --with-ssl=/usr/local/opt/openssl@3 --without-javac --enable-darwin-64bit --enable-kernel-poll --with-dynamic-trace=dtrace"

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

export PATH="./bin:/opt/venv/bin:/usr/local/opt/postgresql@15/bin:/usr/local/opt/python/libexec/bin:/usr/local/opt/openjdk/bin:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:/usr/local/sbin:/usr/local/bin:$PATH"
