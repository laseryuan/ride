#!/bin/bash
# vim: set noswapfile :
set -e

main() {
  case "$1" in
    ride)
      /user-mapping.sh

      CHANGE_USER="gosu ride"
      if [[ ${HOST_USER_NAME} == "root" || ${HOST_USER_ID} == 0} ]]; then
        CHANGE_USER=""
      fi

      ${CHANGE_USER} open_tmux_vim.sh

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
