alias b="bundle"
alias be="bundle exec"

alias bo="brew outdated"
alias bu="brew update && brew upgrade"

alias c="codex"
alias cc="claude"

alias drm='docker rm -f $(docker ps -a -q) && docker rmi $(docker images -q)'

alias g="git"
alias ga="git add"
alias gba="git branch --all"
alias gbi="git bisect"
alias gcp="git cherry-pick"
alias gd="git diff"
alias gdc="git diff --cached"
alias gl="git pull"
alias gll="glog --graph"
alias glla="gll --all"
alias glll='git log --pretty="format:%C(yellow)%H%C(green)%d %C(white)%s %C(cyan)%an, %ar %Creset" --graph'
alias gllla="glll --all"
alias glog='git log --pretty="format:%C(yellow)%h%C(green)%d %C(white)%s %C(cyan)%an, %ar %Creset"'
alias glr="git pull --rebase"
alias gmm="git merge main --ff-only"
alias gpn="git_push_set_upstream"
alias gra="git rebase --abort"
alias grc="git rebase --continue"
alias gri="git rebase -i"
alias grm="git rebase main"
alias gsl="git stash list"
alias gsp="git stash pop"
alias gst="git status"
alias gsu="git stash -u"
alias gw="git worktree"
alias gwa="git worktree add"
alias gwl="git worktree list"
alias gwr="git worktree remove"
alias gwrf="git worktree remove -f"

# Clean up deleted remote branches references
alias gcco="git remote prune origin"
# Remove local fully merged branches
alias gccl="git branch --merged main | grep -v 'main$' | grep -v 'production$' | xargs git branch -d"
# Remove remote fully merged branches
alias gccm="git fetch && git remote prune origin && git branch -r --merged main | sed 's/ *origin\///' | grep -v 'main$' | grep -v 'production$' |xargs -I% git push origin :%"
# Remove all remote branches
alias gccc="git fetch && git remote prune origin && git branch -r | sed 's/ *origin\///' | grep -v 'main$' | grep -v 'production$' | xargs -I% git push origin :%"

alias l="ll"
alias la="ll -a"

alias mc="mix compile"
alias mcf="mix compile --force"
alias md="mix deps.get --all"
alias mdu="mix deps.update --all"
alias mdn="mix deps.unlock --all"
alias mf="mix format"
alias mft="mix full_test"
alias mr="mix ecto.reset && MIX_ENV=test mix ecto.reset"
alias ms="iex -S mix phx.server"
alias mt="mix format && mix test"
alias mtt="mix test --trace"
alias mttt="iex -S mix test --trace"

alias now="date +%FT%T%z"
alias nowu="date -u +%FT%TZz"

alias q="bundle exec rake quality"

alias r="bundle exec rails"
alias rar="bundle exec rake app:reset"
alias rarr="RAILS_ENV=development bundle exec rake app:reset && bundle exec RAILS_ENV=test rake app:reset && annotate"
alias rarrr="rarr && rs"
alias rarrr2="rarr && rs2"
alias rarrr3="rarr && rs3"
alias rc="r c"
alias rdm="bundle exec rake db:migrate"
alias rdr="bundle exec rake db:rollback"
alias red="RAILS_ENV=development"
alias ret="RAILS_ENV=test"
alias rg="r g"
alias rpp="bundle exec rake parallel:prepare"
alias rp="bundle exec rake parallel"
alias rppp="bundle exec rake parallel:prepare parallel"
alias rr="NO_COV=1 bundle exec rspec"
alias rrf="NO_COV=1 bundle exec rspec --fail-fast"
alias rrr="bundle exec rubocop -A"
alias rs="r s"
alias rs1="rs -p 3001"
alias rs2="rs -p 3002"
alias rs3="rs -p 3003"
alias rs4="rs -p 3004"
alias rs5="rs -p 3005"
alias rs6="rs -p 3006"
alias rs7="rs -p 3007"
alias rs8="rs -p 3008"
alias rs9="rs -p 3009"
alias rt="ruby -I'lib:test'"
alias rtt="testrbl -Itest"

alias sr="source ~/.zshrc && echo '.zshrc reloaded!'"
alias ss="skillshare"

alias tf="terraform"
alias time="command time"
alias tt="bin/test"

alias updatedb="sudo /usr/libexec/locate.updatedb"

alias vs="code ."

alias zr="(cd ~/.zprezto && git pull && git submodule update --init --recursive)"
