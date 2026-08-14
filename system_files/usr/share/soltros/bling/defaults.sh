#!/usr/bin/env sh

# Determine shell
[ -n "$BASH_VERSION" ] && shell="bash"
[ -n "$ZSH_VERSION" ] && shell="zsh"

# Setup editor in order of priority
for cmd in nvim vim vi nano ; do
  command -v "$cmd" >/dev/null && {
    export EDITOR=$cmd
    break
  }
done

# Shell-specific configurations
case "$shell" in
bash)
  [ -f "/usr/share/bash-prexec" ] && . "/usr/share/bash-prexec"
  ;;
zsh)
  [ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && . "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ;;
esac
