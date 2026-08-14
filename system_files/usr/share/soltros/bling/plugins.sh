#!/usr/bin/env sh

# Determine shell
[ -n "$BASH_VERSION" ] && shell="bash"
[ -n "$ZSH_VERSION" ] && shell="zsh"

# Common tool initialization
for tool in starship atuin zoxide thefuck; do
  command -v "$tool" >/dev/null && {
    case "$tool" in
    atuin)
      eval "$("$tool" init "$shell" --disable-up-arrow)"
      ;;
    starship | zoxide)
      eval "$("$tool" init "$shell")"
      ;;
    thefuck)
      eval "$(thefuck --alias)"
      ;;
    esac
  }
done
