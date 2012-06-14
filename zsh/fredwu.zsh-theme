#!/usr/bin/env zsh

setopt prompt_subst
autoload colors
colors
autoload -U add-zsh-hook

cyan="$fg_bold[cyan]"
yellow="$fg_bold[yellow]"
magenta="$fg_bold[magenta]"
red="$fg_bold[red]"
green="$fg_bold[green]"
blue="$fg_bold[blue]"

ZSH_THEME_GIT_PROMPT_PREFIX="$green("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
ZSH_THEME_GIT_PROMPT_CLEAN=" ✔ "
ZSH_THEME_GIT_PROMPT_DIRTY=" $red✗$green "

PROMPT='$red%n@%m $blue➜ [ $red%~ $green$(git_prompt_info)$yellow$(rvm_prompt_info)$blue ]$reset_color
$blue $ $reset_color'
