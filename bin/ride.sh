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

is-docker-host-mac() {
  # get-os is unreliable for this: it asks a *container* for its uname,
  # which is always Linux even under Docker Desktop for Mac. What matters
  # here is the machine actually running this script (the docker CLI host).
  [ "`uname -s 2>/dev/null`" = "Darwin" ]
}

is-docker-host-colima() {
  [ "`docker context show 2>/dev/null`" = "colima" ]
}

use-gpg-agent-if-exists() {
  # gpg-agent (and its ssh-agent emulation) are only reachable via a real
  # Unix-domain-socket bind mount. Docker Desktop for Mac's file sharing
  # (osxfs/virtiofs/sshfs) only forwards regular file I/O, not socket
  # semantics - a bind-mounted gpg-agent socket there is just an inert file
  # gpg can't connect() to - so this only works when the docker host is
  # actually Linux. See use-mac-ssh-agent-if-exists for the Docker-Desktop-
  # on-Mac equivalent, and use-colima-gpg-agent-if-exists for Colima, which
  # doesn't have this limitation (containers run inside a real Lima Linux
  # VM, so a socket that's actually inside that VM can be bind-mounted
  # normally - getting it into the VM in the first place is what
  # use-colima-gpg-agent-if-exists is for).
  is-docker-host-mac && return

  command -v gpgconf >/dev/null 2>&1 || return

  local agent_socket ssh_socket gnupg_dir
  agent_socket=`gpgconf --list-dir agent-socket 2>/dev/null`
  [ -S "$agent_socket" ] || return

  gnupg_dir=`dirname "$agent_socket"`
  ssh_socket=`gpgconf --list-dir agent-ssh-socket 2>/dev/null`

  echo \
    -v "$gnupg_dir":"$gnupg_dir" \
    $([ -S "$ssh_socket" ] && echo "-e SSH_AUTH_SOCK=$ssh_socket")
}

use-mac-ssh-agent-if-exists() {
  # Docker Desktop for Mac proxies whatever the host's current SSH_AUTH_SOCK
  # points at (system ssh-agent, or gpg-agent if ssh-support + SSH_AUTH_SOCK
  # are set up on the Mac, 1Password, etc.) through a real socket relay at
  # this fixed path - unlike a plain bind mount, so it actually works. This
  # is the Docker-Desktop equivalent of use-gpg-agent-if-exists'
  # SSH_AUTH_SOCK forwarding; it does not give plain gpg (signing/
  # decrypting) a working host-agent connection on Mac, only ssh.
  #
  # This path is a Docker-Desktop-only feature - Colima doesn't provide it,
  # so skip if Colima is the docker host (see use-colima-gpg-agent-if-exists).
  is-docker-host-mac || return
  is-docker-host-colima && return

  echo \
    -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
    -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock
}

use-colima-gpg-agent-if-exists() {
  # Colima runs containers inside a real Lima-managed Linux VM. Once a
  # socket actually lives inside that VM, bind-mounting it into a container
  # is a normal same-OS Linux mount - no osxfs/virtiofs limitation at all.
  # Getting the socket from the Mac into the VM in the first place is a
  # separate step done via Lima's own socket-level forwarding (portForwards
  # with hostSocket/guestSocket in the colima/lima config), not by this
  # script - see the README for the exact config this expects:
  #   guestSocket: /run/user/{{.UID}}/ride-gnupg-forward/S.gpg-agent      (gpg ops)
  #   guestSocket: /run/user/{{.UID}}/ride-gnupg-forward/S.gpg-agent.ssh  (ssh, optional)
  # forwarding the host's *extra* socket (hostSocket: .../S.gpg-agent.extra)
  # rather than the full agent-socket, since extra is deliberately
  # restricted (sign/decrypt/encrypt only, no key management) - more
  # appropriate to expose to a disposable container.
  #
  # The guest directory is deliberately NOT /run/user/{{.UID}}/gnupg: many
  # Ubuntu (Lima's default guest OS) images run a systemd-socket-activated
  # gpg-agent of their own in the VM's user session, permanently bound to
  # that conventional path - Lima's forward would just lose that race. A
  # distinct guest path sidesteps the collision entirely; the container
  # side is still mounted at its own conventional /run/user/<uid>/gnupg
  # (safe there - containers don't run systemd user sessions).
  #
  # Mounts the whole directory rather than individual socket files:
  # bind-mounting individual files makes docker synthesize the missing
  # parent directories as root-owned, and gpg's socket-directory safety
  # check rejects a runtime dir it doesn't own, silently falling back to
  # ~/.gnupg (read-only) regardless of the socket file itself being
  # reachable. Mounting the directory as a whole preserves its real
  # ownership from the VM side instead. Note the guest-side file is named
  # plain S.gpg-agent (not .extra): gpg only auto-discovers that name, and
  # a directory mount can't rename files inside it, so it must already have
  # its final name on the Colima VM side.
  #
  # {{.UID}} is assumed to render to the same uid as this Mac user (Lima's
  # default behavior), matching the uid the ride container is mapped to.
  is-docker-host-colima || return

  local uid gnupg_guest_dir gnupg_container_dir
  uid=`id -u`
  gnupg_guest_dir="/run/user/${uid}/ride-gnupg-forward"
  gnupg_container_dir="/run/user/${uid}/gnupg"

  colima ssh -- test -S "${gnupg_guest_dir}/S.gpg-agent" 2>/dev/null || return

  echo \
    -v "$gnupg_guest_dir":"$gnupg_container_dir" \
    $(colima ssh -- test -S "${gnupg_guest_dir}/S.gpg-agent.ssh" 2>/dev/null && echo "-e SSH_AUTH_SOCK=${gnupg_container_dir}/S.gpg-agent.ssh")
}

use-gpg-keyring-if-exists() {
  # Public keyring + trustdb + secret-key stubs (the stubs are all that's on
  # disk for smartcard-backed keys; the actual key material never leaves the
  # card). Mounted read-only so a stale/disposable container can't corrupt
  # the host's trustdb. Actual signing/decryption still happens on the host
  # via the forwarded agent socket from use-gpg-agent-if-exists, including
  # any smartcard prompts (PIN entry, card I/O) - that all runs host-side.
  # (On Mac this only gets you `gpg -k`/-K style listing off the mounted
  # keyring - see use-gpg-agent-if-exists for why signing/decrypting can't
  # reach the host agent there. Regular file mounts work fine on Mac, so
  # there's no Mac-host skip here.)
  #
  # Mounted at /home/ride/.gnupg without an explicit GNUPGHOME on purpose:
  # that's already gpg's default homedir for the ride user, and setting
  # GNUPGHOME explicitly makes gpg treat it as a non-standard homedir, which
  # makes it look for the agent socket *inside* it (read-only, no socket
  # there) instead of the real forwarded socket from use-gpg-agent-if-exists.
  local host_gnupghome="${GNUPGHOME:-$HOME/.gnupg}"
  [ -d "$host_gnupghome" ] || return

  echo \
    -v "$host_gnupghome":/home/ride/.gnupg:ro
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
    `# keep Neovim config from the image; cache/state persist under ~/.ride`\
    \
    `# git`\
    $(use-gitconfig-if-exists) \
    \
    `# gpg-agent socket (its ssh-agent emulation also covers ssh, if enabled on host)`\
    $(use-gpg-agent-if-exists) \
    `# Docker-Desktop-on-Mac equivalent of the ssh-agent forwarding above (real socket bind mounts don't work there)`\
    $(use-mac-ssh-agent-if-exists) \
    `# Colima equivalent, covering both gpg ops and ssh via its own portForwards socket relay`\
    $(use-colima-gpg-agent-if-exists) \
    `# gpg keyring/trustdb, so keys map to the smartcard-backed grips the host agent knows`\
    $(use-gpg-keyring-if-exists) \
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


