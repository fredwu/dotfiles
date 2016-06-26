function git_push_set_upstream {
  branch_name="$(git symbolic-ref --short -q HEAD)"

  remote_name=${1:-origin}

  git push --set-upstream ${remote_name} ${branch_name}
}
