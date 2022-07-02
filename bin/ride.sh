#/bin/bash
# Dependency: ip command

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

create-ride() {
  mount_path=`get-mount-path`

  docker run --rm --name=ride-${PWD##*/} -it \
    `# environment virable`\
    -e TERM=$TERM \
    -e HOST_pwd=$(pwd) \
    -e HOST_HOME=$HOME \
    -e HOST_NAME=$(hostname) \
    \
    `# mount data`\
    $(docker-option-mount-projects "$@") \
    \
    `# as host user`\
    -e HOST_USER_NAME=$(id -u -n) -e HOST_USER_ID=$(id -u) -e HOST_USER_GID=$(id -g) \
    \
    `# use host ssh config or create new`\
    -v `get-folder "$HOME/.ssh"`:/home/ride/.ssh \
    -v `get-folder "$HOME/.kr"`:/home/ride/.kr \
    \
    `# git`\
    $(use-gitconfig-if-exists) \
    \
    `# docker in docker`\
    -e HOST_DOCKER_ID=`cut -d: -f3 < <(getent group docker)` \
    -v `get-folder "$HOME/.docker"`:/home/ride/.docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    `if ifup docker0; then echo "--add-host $(hostname):$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')"; fi` \
    \
    lasery/ride \
    ride "$@"
}

attach-ride() {
  docker attach ride-${PWD##*/}
}

main() {
  ride_name=ride-${PWD##*/}

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

