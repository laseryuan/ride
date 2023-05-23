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

use-gitconfig-if-exists() {
  if [[ -f "$HOME/.gitconfig" ]]; then
    echo \
      -v "$HOME/.gitconfig":/home/ride/.gitconfig
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
  unameOut="$(uname -s)"
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
    echo `sed -nr "s/^docker:.*:([0-9]+):.*/\1/p" /etc/group`
  fi
}

add-host-ip() {
  if  ( ifconfig docker0 | head -1 | grep UP ) > /dev/null 2>& 1
  then
    local address=`ifconfig docker0 | grep 'inet' | cut -d: -f2 | awk '{print $2}'`
    echo "--add-host $(get-host-name):${address}"
  fi
}

get-host-name() {
  hostname | cut -c -10
}

create-ride() {
  local docker_option
  while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--docker) docker_option+=" $2 "; shift ;;
        -p) docker_option+=" -p $2 "; shift ;;
        -v) docker_option+=" -v $2 "; shift ;;
        -d) docker_option+=" -d " ;;
        -f|--forward) docker_option+=" -p 12341-12345:12341-12345 -p 22222:22 " ;;
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
    `# network`\
    --network ride_network \
    `# environment virable`\
    -e DISPLAY \
    -e TERM \
    -e TZ=Asia/Hong_Kong \
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
    -e HOST_USER_NAME=$(id -u -n) -e HOST_USER_ID=$(id -u) -e HOST_USER_GID=$(id -g) \
    \
    `# persist ssh config on host`\
    -v `get-folder "$HOME/.ssh"`:/home/ride/.ssh \
    -v `get-folder "$HOME/.kr"`:/home/ride/.kr \
    \
    `# git`\
    $(use-gitconfig-if-exists) \
    \
    `# additonal docker options`\
    $(user-docker-option-if-exists) \
    \
    `# docker in docker`\
    -e HOST_DOCKER_ID=`get-docker-group-id` \
    -v `get-folder "$HOME/.docker"`:/home/ride/.docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$(command -v docker-compose)":/usr/local/bin/docker-compose \
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


