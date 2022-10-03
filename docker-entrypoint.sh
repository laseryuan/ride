#!/bin/bash
# vim: set noswapfile :
set -e

main() {
  case "$1" in
    ride)
      enable-docker.sh
      user-mapping.sh

      if [[ ${HOST_USER_NAME} == "root" || ${HOST_USER_ID} == 0} ]]; then
        CHANGE_USER=""
      else
        CHANGE_USER="gosu ride"
      fi

      ${CHANGE_USER} open_tmux_vim.sh

      shift
      [ -n "$1" ] && { ${CHANGE_USER} "$@"; true; } || ${CHANGE_USER} tmux attach
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
