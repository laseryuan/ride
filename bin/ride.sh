#!/bin/bash

ifup() {
  echo 'Returns true if iface exists and is up, otherwise false.' >&2

  typeset output
  output=$(ip link show "$1" up) && [[ -n $output ]]
}

get-folder() {

  ret="$1"
  [ -L "$ret" ] && ret=`realpath "$ret"`
  [ -d "$ret" ] || {
    echo "Creating directory: $ret" >&2
    mkdir "$ret"
  }
  echo $ret
}

get-mount-path() {
  folder_name=${PWD##*/}
  ret="/home/ride/projects"

  if [ "${folder_name}" != "projects" ]; then
    ret="${ret}/${folder_name}"
  fi

  echo "$ret"
}

map-user() {
  # No need to remap user for Mac https://www.joyfulbikeshedding.com/blog/2021-03-15-docker-and-the-host-filesystem-owner-matching-problem.html
  if [ `get-os` = "Mac" ]; then
    echo \
      --env HOST_USER_NAME=$(id -u -n) --env HOST_USER_ID=1000 --env HOST_USER_GID=1000
  else
    echo \
      --env HOST_USER_NAME=$(id -u -n) --env HOST_USER_ID=$(id -u) --env HOST_USER_GID=$(id -g)
  fi
}

use-gitconfig-if-exists() {
  if [[ -f "$HOME/.gitconfig" ]]; then
    echo \
      -v "$HOME/.gitconfig":/home/ride/.gitconfig
  fi
}

is-mac() {
  [ "$(uname -s)" = "Darwin" ]
}

is-colima() {
  [[ "$(docker context show 2>/dev/null)" == colima* ]]
}

colima-ssh-agent-forwarded() {
  is-mac || return 1
  is-colima || return 1
  command -v colima >/dev/null 2>&1 || return 1

  # Colima forwards the host ssh-agent (when started with --ssh-agent) into
  # the VM at the same path Docker Desktop uses, making it reachable from
  # containers via a plain bind mount.
  colima ssh -- test -S /run/host-services/ssh-auth.sock 2>/dev/null
}

use-host-ssh-auth-sock-if-available() {
  [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" ]] && \
    echo \
      -v "$SSH_AUTH_SOCK":"$SSH_AUTH_SOCK" \
      -e SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
}

use-forwarded-ssh-agent-if-available() {
  if colima-ssh-agent-forwarded; then
    echo \
      -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
      -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock
  else
    use-host-ssh-auth-sock-if-available
  fi
}

user-docker-option-if-exists() {
  [ -z "$docker_option" ] || {
    echo "$docker_option"
  }
}

debug-mode() {
  [ $debug_mode ] && {
    echo "echo"
  }
}

docker-option-mount-projects() {
  if [ "$1" != "sshyou" ]; then
    echo \
      --mount type=bind,src=$(pwd),dst="${mount_path}" \
      --workdir="${mount_path}"
  fi
}

get-ride-name() {
  echo ride-${PWD##*/}
}

get-os() {
  unameOut="$( docker run --rm -it alpine uname -s )" 
  case "${unameOut}" in
      Linux*)     machine=Linux;;
      Darwin*)    machine=Mac;;
      CYGWIN*)    machine=Cygwin;;
      MINGW*)     machine=MinGw;;
      *)          machine="UNKNOWN:${unameOut}"
  esac
  echo ${machine}
}

get-docker-group-id() {
  if [ `get-os` = "Mac" ]; then
    echo
  else
    # mount socket file from host machine and get group id of this file.
    # the host machine is the machine running docker daemon, so it's not necessary
    # the local machine
    docker run --rm -i -v /var/run/docker.sock:/tmp/docker.sock alpine stat -c %g /tmp/docker.sock
    # echo `sed -nr "s/^docker:.*:([0-9]+):.*/\1/p" /etc/group`
  fi
}

get-docker-socket() {
  docker context inspect --format '{{.Endpoints.docker.Host}}' | sed 's/^unix:\/\///'
}

add-host-ip() {
  echo "--add-host $(get-host-name):host-gateway"

  # local ip_address

  # if [ `get-os` = "Mac" ]; then
      # echo "--add-host $(get-host-name):host-gateway"
  # else
      # local interface="docker0"

      # local detail
      # if command -v ip > /dev/null; then
        # detail=$(ip addr show "$interface")
      # else
        # detail=$(ifconfig "$interface")
      # fi
      # ip_address=$(echo "$detail" | awk '/inet / {print $2}' | cut -d '/' -f 1)

      # echo "--add-host $(get-host-name):${ip_address}"
  # fi
}

get-host-name() {
  hostname | cut -c -10
}

get-host-timezone() {
    readlink /etc/localtime | awk -F'/' '{print $(NF-1)"/"$(NF)}'
}

create-ride() {
  local docker_option
  while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--docker) docker_option+=" $2 "; shift ;;
        -p) docker_option+=" -p $2 "; shift ;;
        -v) docker_option+=" -v $2 "; shift ;;
        -d) docker_option+=" -d " ;;
        -f|--forward) docker_option+=" -p 12341-12345:12341-12345 " ;;
        -s|--ssh) docker_option+=" -p 22222:22 "; SSH_MODE=0 ;;
        --debug) debug_mode=0 ;;
        *) break ;;
    esac
    shift
  done

  mount_path=`get-mount-path`

  $(debug-mode) docker run \
    -it --rm \
    --name=`get-ride-name` \
    `# avoid accident detach ride`\
    --detach-keys="ctrl-p,ctrl-z" \
    `# network`\
    --network ride_network \
    `# environment virable`\
    -e DISPLAY \
    -e TERM \
    -e TZ=$(get-host-timezone) \
    -e HOST_pwd=$(pwd) \
    -e HOST_HOME=$HOME \
    -e HOST_NAME=`get-host-name` \
    -e SSH_MODE=${SSH_MODE} \
    \
    `# mount data`\
    $(docker-option-mount-projects "$@") \
    -v `get-folder "$HOME/.ride"`:/home/ride/.ride \
    \
    `# as host user`\
    $(map-user) \
    \
    `# persist ssh config on host`\
    -v `get-folder "$HOME/.ssh"`:/home/ride/.ssh \
    \
    `# on Mac with Colima started using --ssh-agent, forward the host agent`\
    $(use-forwarded-ssh-agent-if-available) \
    \
    `# keep Neovim config from the image; cache/state persist under ~/.ride`\
    \
    `# git`\
    $(use-gitconfig-if-exists) \
    \
    `# additonal docker options`\
    $(user-docker-option-if-exists) \
    \
    `# docker in docker`\
    -e HOST_DOCKER_ID=`get-docker-group-id` \
    -v `get-folder "$HOME/.docker/"`:/home/ride/.docker/ \
    -v /var/run/docker.sock:"$(get-docker-socket)" \
    $(add-host-ip) \
    \
    lasery/ride \
    ride "$@"
}

ride-load() {
  docker exec -u ride -it ride-${PWD##*/} tmux a
}

ride-attach() {
  docker attach ride-${PWD##*/}
}

ceate-ride-network-ifnotexist() {
  docker network inspect ride_network >/dev/null 2>&1 || \
      docker network create ride_network
}

main() {
  ceate-ride-network-ifnotexist

  ride_name=`get-ride-name`

  if [ "$(docker ps -q -f name=${ride_name})" ]; then
    local choice
    read -p "Load existing ride? (y/n)" choice
    if [ "$choice" == "load" ]; then
      ride-load
      return
    elif [ "$choice" == "attach" ]; then
      ride-attach
      return
    else
      docker rm -f ${ride_name}
    fi
  fi

  if [ "$(docker ps -aq -f status=exited -f name=${ride_name})" ]; then
      echo "cleanup stopped container"
      docker rm ${ride_name}
  fi
  create-ride "$@"
}

main "$@"


