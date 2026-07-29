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

host-ssh-directory-options() {
  local ssh_directory

  # Keep the existing SSH behavior: share config, known_hosts, and ordinary
  # private keys from the host. GPG-managed SSH keys use the agent socket below.
  ssh_directory=$(get-folder "$HOME/.ssh")
  echo --mount \
    "type=bind,src=${ssh_directory},dst=/home/ride/.ssh"
}

host-gnupg-directory-options() {
  if [[ -d "$HOME/.gnupg" ]]; then
    echo --mount \
      "type=bind,src=${HOME}/.gnupg,dst=/home/ride/.gnupg-host" \
      --env RIDE_HOST_GNUPGHOME=/home/ride/.gnupg-host
  fi
}

get-host-gpg-socket() {
  local socket_name="$1"
  local socket_path

  command -v gpgconf >/dev/null 2>&1 || return 1
  socket_path=$(gpgconf --list-dirs "$socket_name" 2>/dev/null) || return 1
  [[ -S "$socket_path" ]] || return 1

  echo "$socket_path"
}

host-gpg-socket-options() {
  local extra_socket ssh_socket

  if [[ $(get-os) == Mac ]]; then
    cat >&2 <<'EOF'
Ride: GPG smart-card forwarding is not active on Docker Desktop for Mac.
Ride cannot bind-mount a macOS GPG-agent socket into its Linux container.
Inside Ride, gpg-connect-agent may start a new container-local agent, but that
agent cannot see the YubiKey attached to the Mac and will report "No SmartCard daemon".
Run 'ride gpg-check' on the Mac for details.
EOF
    echo --env RIDE_GPG_FORWARDING=unsupported-macos
    return 0
  fi

  # Use gpg-agent's restricted remote-use endpoint rather than exposing its
  # unrestricted administrative socket to the container.
  if extra_socket=$(get-host-gpg-socket agent-extra-socket); then
    echo --mount \
      "type=bind,src=${extra_socket},dst=/home/ride/.gnupg/S.gpg-agent" \
      --env RIDE_GPG_FORWARDING=restricted-extra
  else
    echo --env RIDE_GPG_FORWARDING=unavailable
  fi

  if ssh_socket=$(get-host-gpg-socket agent-ssh-socket); then
    echo --mount \
      "type=bind,src=${ssh_socket},dst=/home/ride/.gnupg/S.gpg-agent.ssh" \
      --env SSH_AUTH_SOCK=/home/ride/.gnupg/S.gpg-agent.ssh
  fi
}

check-host-gpg-forwarding() {
  local host_os extra_socket

  host_os=$(get-os)
  echo "Host OS: ${host_os}"

  if [[ "$host_os" == Mac ]]; then
    echo "Direct GPG-agent socket forwarding: unsupported by Docker Desktop for Mac" >&2
    echo "Ride will not mount the macOS socket into its Linux VM." >&2
    return 1
  fi

  if ! extra_socket=$(get-host-gpg-socket agent-extra-socket); then
    echo "Restricted GPG-agent forwarding: unavailable (no live extra socket)" >&2
    return 1
  fi

  echo "Host agent extra socket: ${extra_socket}"
  echo "Restricted GPG-agent forwarding: supported"
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
  # Inspect the client host, not a Linux container. The latter always reports
  # Linux and caused macOS-only socket mounts to be treated as usable.
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
    stat -c %g "$(get-docker-socket)"
  fi
}

get-docker-socket() {
  docker context inspect --format '{{.Endpoints.docker.Host}}' | sed 's/^unix:\/\///'
}

is-docker-socket-available() {
  [[ -S "$1" ]]
}

docker-socket-options() {
  local socket_path
  socket_path=$(get-docker-socket) || return 1

  if ! is-docker-socket-available "$socket_path"; then
    echo "Ride: Docker context socket is unavailable: ${socket_path}" >&2
    return 1
  fi

  echo --mount \
    "type=bind,src=${socket_path},dst=/var/run/docker.sock"
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
    `# host SSH config, known_hosts, and ordinary key files`\
    $(host-ssh-directory-options) \
    `# host GPG keyring files; agent sockets are handled separately below`\
    $(host-gnupg-directory-options) \
    \
    `# keep Neovim config from the image; cache/state persist under ~/.ride`\
    \
    `# git`\
    $(use-gitconfig-if-exists) \
    `# use the host GPG agent for signing and SSH when its sockets are available`\
    $(host-gpg-socket-options) \
    \
    `# additonal docker options`\
    $(user-docker-option-if-exists) \
    \
    `# docker in docker`\
    -e HOST_DOCKER_ID=`get-docker-group-id` \
    -v `get-folder "$HOME/.docker/"`:/home/ride/.docker/ \
    $(docker-socket-options) \
    $(add-host-ip) \
    \
    lasery/ride \
    ride "$@"
}

test() {
  get-folder() {
    echo "$1"
  }

  get-host-gpg-socket() {
    case "$1" in
      agent-extra-socket) echo /run/user/1000/gnupg/S.gpg-agent.extra ;;
      agent-ssh-socket) echo /run/user/1000/gnupg/S.gpg-agent.ssh ;;
    esac
  }

  get-os() {
    echo Linux
  }

  get-docker-socket() {
    echo /Users/ride/.docker/run/docker.sock
  }

  is-docker-socket-available() {
    return 0
  }

  local options
  local ssh_options
  local gnupg_options
  ssh_options=$(host-ssh-directory-options)
  [[ "$ssh_options" == *"src=${HOME}/.ssh,dst=/home/ride/.ssh"* ]]

  gnupg_options=$(host-gnupg-directory-options)
  [[ "$gnupg_options" == *"src=${HOME}/.gnupg,dst=/home/ride/.gnupg-host"* ]]
  [[ "$gnupg_options" == *"RIDE_HOST_GNUPGHOME=/home/ride/.gnupg-host"* ]]

  options=$(host-gpg-socket-options)
  [[ "$options" == *"src=/run/user/1000/gnupg/S.gpg-agent.extra,dst=/home/ride/.gnupg/S.gpg-agent"* ]]
  [[ "$options" == *"RIDE_GPG_FORWARDING=restricted-extra"* ]]
  [[ "$options" == *"src=/run/user/1000/gnupg/S.gpg-agent.ssh,dst=/home/ride/.gnupg/S.gpg-agent.ssh"* ]]
  [[ "$options" == *"SSH_AUTH_SOCK=/home/ride/.gnupg/S.gpg-agent.ssh"* ]]
  [[ $(check-host-gpg-forwarding) == *"Restricted GPG-agent forwarding: supported"* ]]
  [[ $(docker-socket-options) == *"src=/Users/ride/.docker/run/docker.sock,dst=/var/run/docker.sock"* ]]

  get-os() {
    echo Mac
  }
  options=$(host-gpg-socket-options 2>/dev/null)
  [[ "$options" == *"RIDE_GPG_FORWARDING=unsupported-macos"* ]]
  [[ "$options" != *"S.gpg-agent,dst="* ]]
  if check-host-gpg-forwarding >/dev/null 2>&1; then
    echo "TEST FAILURE: macOS preflight unexpectedly succeeded" >&2
    return 1
  fi
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

case "$1" in
  test) test ;;
  gpg-check) check-host-gpg-forwarding ;;
  *) main "$@" ;;
esac
