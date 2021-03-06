#!/bin/bash

ifup() {
  echo 'Returns true if iface exists and is up, otherwise false.' >&2

  typeset output
  output=$(ip link show "$1" up) && [[ -n $output ]]
}

get-folder() {
  echo 'Returns directory real path; Create the directory if it was not there.' >&2

  ret="$1"
  [ -L "$ret" ] && ret=`realpath "$ret"`
  [ -d "$ret" ] || mkdir "$ret"
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
    echo "--add-host $(hostname):${address}"
  fi
}

create-ride() {
  mount_path=`get-mount-path`

  docker run --rm --name=`get-ride-name` -it \
    --network ride_network \
    `# environment virable`\
    -e DISPLAY \
    -e TERM \
    -e HOST_pwd=$(pwd) \
    -e HOST_HOME=$HOME \
    -e HOST_NAME=$(hostname | cut -c -10) \
    \
    `# mount data`\
    $(docker-option-mount-projects "$@") \
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
    `# docker in docker`\
    -e HOST_DOCKER_ID=`get-docker-group-id` \
    -v `get-folder "$HOME/.docker"`:/home/ride/.docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $(add-host-ip) \
    \
    lasery/ride \
    ride "$@"
}

attach-ride() {
  docker exec -u ride -it ride-${PWD##*/} tmux a
}

ceate-ride-network-ifnotexist() {
  docker network inspect ride_network >/dev/null 2>&1 || \
      docker network create ride_network
}

main() {
  ceate-ride-network-ifnotexist

  ride_name=`get-ride-name`

  if [ ! "$(docker ps -q -f name=${ride_name})" ]; then
      if [ "$(docker ps -aq -f status=exited -f name=${ride_name})" ]; then
          echo "cleanup stopped container"
          docker rm ${ride_name}
      fi
      create-ride "$@"
  else
    attach-ride
  fi
}

main "$@"

