HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=HISTSIZE

export GPG_TTY=$(tty)

export EDITOR=nvim
export VISUAL=nvim
export BUNDLER_EDITOR=code
export JULIA_EDITOR=code

export HOMEBREW_NO_ASK=1

export NODE_PATH=/usr/local/lib/node_modules

export KERL_BUILD_DOCS="yes"
export KERL_BUILD_PLT="yes"
export KERL_CONFIGURE_OPTIONS="--disable-debug --disable-silent-rules --enable-dynamic-ssl-lib --disable-hipe --enable-shared-zlib --enable-smp-support --enable-threads --enable-wx --with-odbc=/opt/homebrew/opt/unixodbc --with-ssl=/opt/homebrew/opt/openssl@3 --without-javac --enable-darwin-64bit --enable-kernel-poll --with-dynamic-trace=dtrace"

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

export PATH="./bin:/opt/venv/bin:/opt/homebrew/opt/postgresql@17/bin:/opt/homebrew/opt/postgresql@16/bin:/opt/homebrew/opt/postgresql@15/bin:/opt/homebrew/opt/python/libexec/bin:/opt/homebrew/opt/openjdk/bin:$HOME/.local/bin:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:/usr/local/sbin:/usr/local/bin:$PATH"

# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:$HOME/.docker/bin"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity IDE
export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"

# Added by MTPLX.app — terminal command
export PATH="$HOME/.mtplx/bin:$PATH"

if [[ -f "$HOME/.local/bin/env" ]]; then
  . "$HOME/.local/bin/env"
fi
