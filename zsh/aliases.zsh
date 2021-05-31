alias rm="rm"
alias mv="mv"

alias x86="arch -x86_64 zsh"
alias arm="arch -arm64 zsh"

alias ibrew="arch -x86_64 /usr/local/bin/brew"

alias se="vim ~/.zshrc"
alias sr="source ~/.zshrc && echo '.zshrc reloaded!'"
alias zr="cd $ZPREZTODIR && git pull && git submodule update --init --recursive"

alias updatedb="sudo /usr/libexec/locate.updatedb"

alias now="date +%FT%T%z"
alias nowu="date -u +%FT%TZz"

alias l="ll"
alias la="ll -a"
alias time="command time"
alias pwdd="pwd | pbcopy"

alias aa="atom ."
alias aaa="atom-beta ."
alias vs="code ."

alias mt="mix test"
alias mtt="mix test --trace"
alias mttt="iex -S mix test --trace"
alias md="mix deps.get --all"
alias mdu="mix deps.update --all"
alias mdn="mix deps.unlock --all"

alias b="bundle"
alias bb="bundle install --jobs 8"
alias bo="bundle open"
alias bu="bundle update"

alias g="git"
alias ga="git add"
alias gba="git branch --all"
alias gbi="git bisect"
alias gcp="git cherry-pick"
alias gd="git diff"
alias gdc="git diff --cached"
alias gl="git pull"
alias glr="git pull --rebase"
alias glog='git log --pretty="format:%C(yellow)%h%C(green)%d %C(white)%s %C(cyan)%an, %ar %Creset"'
alias gll="glog --graph"
alias glla="gll --all"
alias glll='git log --pretty="format:%C(yellow)%H%C(green)%d %C(white)%s %C(cyan)%an, %ar %Creset" --graph'
alias gllla="glll --all"
alias gmm="git merge master --ff-only"
alias gpn="git_push_set_upstream"
alias gra="git rebase --abort"
alias grc="git rebase --continue"
alias gri="git rebase -i"
alias grm="git rebase master"
alias gst="git status"
alias gsu="git stash -u"
alias gsp="git stash pop"
alias gsl="git stash list"

# Clean up deleted remote branches references
alias gcco="git remote prune origin"
# Remove local fully merged branches
alias gccl="git branch --merged master | grep -v 'master$' | grep -v 'production$' | xargs git branch -d"
# Remove remote fully merged branches
alias gccm="git fetch && git remote prune origin && git branch -r --merged master | sed 's/ *origin\///' | grep -v 'master$' | grep -v 'production$' |xargs -I% git push origin :%"
# Remove all remote branches
alias gccc="git fetch && git remote prune origin && git branch -r | sed 's/ *origin\///' | grep -v 'master$' | grep -v 'production$' | xargs -I% git push origin :%"

alias st="subl"
alias stt="subl ."

alias be="bundle exec"

alias rr="NO_COV=1 bundle exec rspec"
alias rrf="NO_COV=1 bundle exec rspec --fail-fast"
alias rrr="RAILS_ENV=test bundle exec rake app:reset && NO_COV=1 bundle exec rspec"
alias rrrf="RAILS_ENV=test bundle exec rake app:reset && NO_COV=1 bundle exec rspec --fail-fast"
alias crr="COV=1 bundle exec rspec"

alias r="bundle exec rails"
alias rc="r c"
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
alias ret="RAILS_ENV=test"
alias red="RAILS_ENV=development"
alias rar="bundle exec rake app:reset"
alias rarr="RAILS_ENV=development bundle exec rake app:reset && bundle exec RAILS_ENV=test rake app:reset && annotate"
alias rarrr="rarr && rs"
alias rarrr2="rarr && rs2"
alias rarrr3="rarr && rs3"
alias rdm="bundle exec rake db:migrate"
alias rdr="bundle exec rake db:rollback"
alias rg="r g"
alias rpp="bundle exec rake parallel:prepare"
alias rp="bundle exec rake parallel"
alias rppp="bundle exec rake parallel:prepare parallel"

alias p="padrino"

alias q="bundle exec rake quality"

alias rbp="rails_best_practices"

alias pryr="pry -r ./config/environment -r rails/console/app -r rails/console/helpers"

alias ct="ctags -R -f .tags --exclude='*.min.js' --exclude='*.pack.js'"

alias "awsls"="aws ec2 describe-instances --query 'Reservations[].Instances[].[ [Tags[?Key==\`Name\`].Value][0][0],PrivateIpAddress,State.Name]' --output table"
alias "awslsp"="aws ec2 describe-instances --query 'Reservations[].Instances[].[ [Tags[?Key==\`Name\`].Value][0][0],PublicIpAddress,State.Name]' --output table"
