#!/bin/bash
# vim: set noswapfile :
set -e

start_tmux() {
  SESSION_NAME=${HOST_NAME:-0}
  ${CHANGE_USER} tmux new-session -d -s "$SESSION_NAME" -n home bash
}

prepare_workspace() {
  ${CHANGE_USER} tmux send-keys -t "$SESSION_NAME":home "vim" Enter
  sleep 3
  ${CHANGE_USER} tmux send-keys -t "$SESSION_NAME":home "C-g"
  ${CHANGE_USER} tmux attach 
}

main() {
  case "$1" in
    ride)
      shift
      enable-docker.sh
      user-mapping.sh

      if [[ ${HOST_USER_NAME} == "root" || ${HOST_USER_ID} == 0} ]]; then
        CHANGE_USER=""
      else
        CHANGE_USER="gosu ride"
      fi

      [ ${SSH_MODE} ] && {
        ${CHANGE_USER} sshstart
      }

      ${CHANGE_USER} config-home.sh

      start_tmux

      [ -n "$1" ] && { 
        ${CHANGE_USER} "$@"; true; 
      } || {
        prepare_workspace 
      }
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
