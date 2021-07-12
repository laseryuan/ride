#!/bin/bash
# vim: set noswapfile :
set -e

main() {
  case "$1" in
    ride)
      if [[ ${HOST_USER_NAME} == "root" || ${HOST_USER_ID} == 0} ]]; then
        /user-mapping.sh
        open_tmux_vim.sh
      else
        /user-mapping.sh
        gosu ride open_tmux_vim.sh
      fi
      shift
      [ -n "$1" ] && { gosu ride "$@"; true; } || gosu ride tmux attach
      ;;
    help)
      cat /README.md
      ;;
    install)
      shift
      /doc/install.sh "$@"
      ;;
    *)
      exec "$@"
      ;;
  esac
}

main "$@"
