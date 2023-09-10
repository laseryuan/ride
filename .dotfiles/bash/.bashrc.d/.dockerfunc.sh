#!/usr/bin/env bash
# Bash wrappers for docker run commands
# docker run --rm -it \
    # --entrypoint=/bin/bash \

#
# Setup environment
#
setupenv(){
  export RIDE_CONFIG=$HOST_HOME/.ride
  export DOCKER_REPO_PREFIX=jess
  export MY_DOCKER_REPO_PREFIX=lasery
  export RESOLUTION_S=600x1165
  export RESOLUTION_M=1280x720
  export RESOLUTION_L=1920x1080

  [ -z "$RIDE_USER" ] || {
    export RIDE_NETWORK=${RIDE_NETWORK:-"ride_network"}
    export DISPLAY=${DISPLAY:-"unix:1"}
  }

  [ -z "$GITHUB_ACTIONS" ] || {
    echo "setup environment specific for github"
  }
}
setupenv

loadenv () {
  if [[ -f ".env.sh" ]]; then
    # Show env vars
    grep -v '^#' .env.sh

    # Export env vars
    set -o allexport
    source .env.sh
    set +o allexport
  fi
}

get_ride_path () {
  local folder_name=${HOST_pwd##*/};
  local ride_path
  if [[ "$folder_name" == "projects" ]]; then
    ride_path=/home/ride/projects;
  else
    ride_path=/home/ride/projects/${folder_name};
  fi
  echo $ride_path
}

get_host_pwd () {
  if [[ "${PWD}" =~ "/home/ride/.ride" ]]; then
    echo ${PWD/\/home\/ride/$HOST_HOME}
  else
    local rel_path=$(realpath --relative-to=$(get_ride_path) "${PWD}");
    echo ${HOST_pwd}/${rel_path}
  fi
}

get_folder() {
  ret="$1"
  [ -L "$ret" ] && ret=`realpath "$ret"`
  [ -d "$ret" ] || {
    echo "Creating directory: $ret" >> /tmp/ride.log
    mkdir -p "$ret"
  }
  echo $ret
}

get_app_host_config_path() {
  local default_path=$(get_folder /home/ride/.ride/$1)
  local tmp=$(get_folder $default_path)
  local config_name=config_${1}
  local ret=${!config_name:-"${RIDE_CONFIG}/$1"};
  echo $ret
}

use-sound-device-if-exists() {
  if [[ -f "/dev/snd" ]]; then
    relies_on pulseaudio
  fi
}

#
# Helper Functions
#
dcleanup(){
  local containers
  mapfile -t containers < <(docker ps -aq 2>/dev/null)
  docker rm "${containers[@]}" 2>/dev/null
  local volumes
  mapfile -t volumes < <(docker ps --filter status=exited -q 2>/dev/null)
  docker rm -v "${volumes[@]}" 2>/dev/null
  local images
  mapfile -t images < <(docker images --filter dangling=true -q 2>/dev/null)
  docker rmi "${images[@]}" 2>/dev/null
}
del_stopped(){
  local name=$1
  local state
  state=$(docker inspect --format "{{.State.Running}}" "$name" 2>/dev/null)

  if [[ "$state" == "false" ]]; then
    docker rm "$name"
  fi
}
rmctr(){
  # shellcheck disable=SC2068
  docker rm -f $@ 2>/dev/null || true
}

wait_for(){
  local container="$1"
  local container_health
  until [[ "$container_health" == '"healthy"' ]]
  do
    echo "desktop not ready ..."
    sleep 5
    container_health=`docker inspect --format='{{json .State.Health.Status}}' $container`
  done
}

relies_on(){
  for container in "$@"; do
    local state
    state=$(docker inspect --format "{{.State.Running}}" "$container" 2>/dev/null)

    if [[ "$state" == "false" ]] || [[ "$state" == "" ]]; then
      echo "$container is not running, starting it for you."
      $container
      if [[ "$container" == "desktop" ]]; then
        wait_for $container
      fi
    fi
  done
}

if_debug_mode() {
  [ $debug_mode ] && {
    echo "echo"
  }
}
#
# Container Options
#
parse_arg(){
  local use_host_x11
  local use_display
  local use_docker
  local network=${RIDE_NETWORK}
  local user="${HOST_USER_ID}:${HOST_USER_GID}"
  local app_name
  local host_share_path
  local mount_path

  while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p) docker_option+=" -p $2 "; shift ;;
        -v) docker_option+=" -v $2 "; shift ;;
        --docker) docker_option+=" $2 "; shift ;;
        --network) network="$2"; shift ;;
        --user) user="$2"; shift ;;
        --name) app_name="$2"; shift ;;
        --config) config_path="$2"; shift ;;
        --share) host_share_path="$2"; shift ;;
        --mount) mount_path="$2"; shift ;;
        --dc) use_docker=0 ;;
        --display) use_display=0 ;;
        --debug) debug_mode=0 ;;
        --host) use_host_x11=0 ;;
        *) break ;;
    esac
    shift
  done

  if [ "$user" != "no" ]; then
    DOCKERAPP_HOME="/tmp"
    docker_option+=" --user=${user} -e HOME=/tmp "
    docker_option+=" -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro "
  fi

  if [ $app_name ]; then
    docker_option+=" --name=${app_name} "
    if [ $config_path ]; then
      local config_host=$(get_app_host_config_path ${app_name})
      docker_option+=" -v ${config_host}:${config_path} "
    fi
  fi

  if [ $host_share_path ]; then
    docker_option+=" -v ${RIDE_CONFIG}/Share:${host_share_path} "
  fi

  if [ $mount_path ]; then
    docker_option+=" -v $(get_host_pwd):${mount_path} "
    docker_option+=" --workdir=${mount_path} "
  fi

  if [ "$network" != "no" ]; then
    docker_option+=" --network=${network} "
  fi

  if [ $use_display ]; then
    docker_option+=" --group-add audio --group-add video "
    docker_option+=" -v /etc/localtime:/etc/localtime:ro "
    docker_option+=" -e TZ=Asia/Hong_Kong "
    docker_option+=" -e GDK_SCALE -e GDK_DPI_SCALE "

    if [ $use_host_x11 ]; then
      docker_option+=$(docker_X11_host)
    else
      docker_option+=$(docker_X11)
      if ! [ $debug_mode ]; then
          relies_on desktop
      fi
    fi
  fi

  if [ $use_docker ]; then
    docker_option+=" $(docker_command) "
  fi

  other_args="$@"
}

docker_mount_os(){
  echo \
    --network="${RIDE_NETWORK}" \
    -u "${HOST_USER_ID}:${HOST_USER_GID}" \
    -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
    -v "$(get_host_pwd)":/tmp/data -e HOME=/tmp --workdir=/tmp/data \
    -v /etc/localtime:/etc/localtime:ro
}

docker_command(){
  echo \
    -v "$(command -v docker)":/usr/bin/docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOST_HOME/.docker/":"$DOCKERAPP_HOME/.docker/" \
    --group-add "$HOST_DOCKER_ID"
}

docker_locale(){
  echo \
    "-e XMODIFIERS=@im=ibus" \
    -e GTK_IM_MODULE=ibus \
    -e QT_IM_MODULE=ibus \
    -e LANG="en_US.UTF-8" \
    -e LC_CTYPE="zh_CN.UTF-8"
}

docker_X11(){
  echo \
    --ipc=container:desktop \
    -e DISPLAY=unix:1 --volumes-from desktop \
    -e PULSE_SERVER=pulseaudio \
    $(docker_locale)
}

docker_X11_host(){
  echo \
    -v /dev/shm:/dev/shm \
    -v /usr/share/fonts:/usr/share/fonts \
    -v /usr/lib/locale:/usr/lib/locale \
    -v /usr/share/zoneinfo:/usr/share/zoneinfo \
    -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
    $(docker_locale)
}
#
# Container Aliases
#

alias yt='docker run --rm -u $(id -u):$(id -g) -v $PWD:/data vimagick/youtube-dl'
# alias mustache='docker run -v `pwd`:/data --rm coolersport/mustache'

adobe(){
  relies_on desktop

  del_stopped adobe

  local docker_option+=$(docker_X11)

  docker run  \
    -d \
    -v "${RIDE_CONFIG}/Share":/home/acroread/Documents \
    -e uid=${HOST_USER_ID} \
    -e gid=${HOST_USER_GID} \
    --name adobe \
    ${docker_option} \
    chrisdaish/acroread
}

apt_file(){
  docker run --rm -it \
    --name apt-file \
    ${DOCKER_REPO_PREFIX}/apt-file
}
alias apt-file="apt_file"
audacity(){
  del_stopped audacity

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -e QT_DEVICE_PIXEL_RATIO \
    --device /dev/snd \
    --group-add audio \
    --name audacity \
    ${DOCKER_REPO_PREFIX}/audacity
}

aws () {
  del_stopped aws;
  local config_host=$(get_app_host_config_path aws)
  docker run --rm -it `docker_mount_os` -v "${config_host}":/tmp/.aws --name aws --entrypoint='' amazon/aws-cli bash
}

az(){
  docker run -it --rm \
    -v "${HOME}/.azure:/root/.azure" \
    --log-driver none \
    ${DOCKER_REPO_PREFIX}/azure-cli "$@"
}
bees(){
  docker run -it --rm \
    -e NOTARY_TOKEN \
    -v "${HOME}/.bees:/root/.bees" \
    -v "${HOME}/.boto:/root/.boto" \
    -v "${HOME}/.dev:/root/.ssh:ro" \
    --log-driver none \
    --name bees \
    ${DOCKER_REPO_PREFIX}/beeswithmachineguns "$@"
}
cadvisor(){
  docker run -d \
    --restart always \
    -v /:/rootfs:ro \
    -v /var/run:/var/run:rw \
    -v /sys:/sys:ro  \
    -v /var/lib/docker/:/var/lib/docker:ro \
    -p 1234:8080 \
    --name cadvisor \
    google/cadvisor

  hostess add cadvisor "$(docker inspect --format '{{.NetworkSettings.Networks.bridge.IPAddress}}' cadvisor)"
  browser-exec "http://cadvisor:8080"
}

cheese(){
  del_stopped cheese

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -v "${HOME}/Pictures:/root/Pictures" \
    --device /dev/video0 \
    --device /dev/snd \
    --device /dev/dri \
    --name cheese \
    ${DOCKER_REPO_PREFIX}/cheese
}

chrome(){
    local docker_option
    local debug_mode
    local other_args
    parse_arg --display --name chrome --config /home --share /home/Downloads "$@"

    if ! [ $debug_mode ]; then
      del_stopped chrome
    fi

  # add flags for proxy if passed
  if [[ "$1" == "tor" ]]; then
    relies_on torproxy

    local proxy=
    local map
    local args=$*
    map="MAP * ~NOTFOUND , EXCLUDE torproxy"
    proxy="socks5://torproxy:9050"
    args="https://check.torproject.org/api/ip ${*:2}"
  fi

  docker_option+=" \
    --security-opt seccomp:unconfined \
    -e HOME=/home \
  "

  $(if_debug_mode) docker run -d \
    ${docker_option} \
    "$DOCKER_REPO_PREFIX"/chrome \
    --proxy-server="$proxy" \
    --host-resolver-rules="$map" "$other_args"
}

consul(){
  del_stopped consul

  # check if we passed args and if consul is running
  local state
  state=$(docker inspect --format "{{.State.Running}}" consul 2>/dev/null)
  if [[ "$state" == "true" ]] && [[ "$*" != "" ]]; then
    docker exec -it consul consul "$@"
    return 0
  fi

  docker run -d \
    --restart always \
    -v "${HOME}/.consul:/etc/consul.d" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --net host \
    -e GOMAXPROCS=2 \
    --name consul \
    ${DOCKER_REPO_PREFIX}/consul agent \
    -bootstrap-expect 1 \
    -config-dir /etc/consul.d \
    -data-dir /data \
    -encrypt "$(docker run --rm ${DOCKER_REPO_PREFIX}/consul keygen)" \
    -ui-dir /usr/src/consul \
    -server \
    -dc neverland \
    -bind 0.0.0.0

  hostess add consul "$(docker inspect --format '{{.NetworkSettings.Networks.bridge.IPAddress}}' consul)"
  browser-exec "http://consul:8500"
}
dcos(){
  docker run -it --rm \
    -v "${HOME}/.dcos:/root/.dcos" \
    -v "$(pwd):/root/apps" \
    -w /root/apps \
    ${DOCKER_REPO_PREFIX}/dcos-cli "$@"
}

desktop(){
  local docker_option
  local debug_mode
  local other_args

  local RESOLUTION=${RESOLUTION:-"1920x1080"}
  local VNC_PASSWORD=${VNC_PASSWORD:-"ride"}

  while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s) RESOLUTION="${RESOLUTION_M}" ;;
        *) break ;;
    esac
    shift
  done

  parse_arg --user no --name desktop --config /home/headless/.config \
      --share /home/headless/Share "$@"

  del_stopped desktop

  $(if_debug_mode) docker run -d \
    ${docker_option} \
    $(docker_command) \
    --privileged \
    --shm-size=1g \
    --ipc=shareable \
    -e VNC_RESOLUTION="${RESOLUTION}" \
    -e VNC_PW="${VNC_PASSWORD}" \
    -e VNC_PORT=5900 \
    -u "${HOST_USER_ID}":"${HOST_USER_GID}" \
    -v /usr/share/fonts \
    -v /usr/lib/locale \
    -v /usr/share/zoneinfo \
    -e LANG=en_US.UTF-8 \
    -e LC_ALL=en_US.UTF-8 \
    ${MY_DOCKER_REPO_PREFIX}/vnc-desktop
}

desktop_dorowu(){
  RESOLUTION=${RESOLUTION:-"1280x720"}
  VNC_PASSWORD=${VNC_PASSWORD:-"ride"}
  del_stopped desktop

  docker run -d \
    --network="${RIDE_NETWORK}" \
    --privileged \
    --ipc=shareable \
    -e RESOLUTION="${RESOLUTION}" \
    -e VNC_PASSWORD="${VNC_PASSWORD}" \
    -e USER=${HOST_USER_NAME} \
    --name desktop \
    -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$(command -v docker):/usr/bin/docker" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v desktop:/tmp/.X11-unix \
    -v "${RIDE_CONFIG}/Share":"/home/${HOST_USER_NAME}/Share" \
    ${MY_DOCKER_REPO_PREFIX}/vnc-desktop
}

devlang(){
    local lang="$1"

    local docker_option
    local debug_mode
    local config_host
    local other_args

    parse_arg --name "dev$lang" --mount /tmp/data "$@"

    if ! [ $debug_mode ]; then
      del_stopped "dev$lang"
    fi

    $(if_debug_mode) docker run -it \
      ${docker_option} \
      ${MY_DOCKER_REPO_PREFIX}/"dev$lang" \
      bash -l
}

devcpp(){
    devlang cpp
}

devsh(){
    devlang sh
}

devpy(){
    devlang py
}

scrcpy(){
  local config_host=$(get_app_host_config_path android)
  del_stopped scrcpy
  relies_on desktop

  local docker_option+=$(docker_X11)

  docker_option+=" \
    --network="${RIDE_NETWORK}" \
  "

  docker run --rm -it \
    -v ${config_host}:/home/scrcpy/.android \
    ${docker_option} \
    --name scrcpy \
    lasery/scrcpy \
    bash
}

firefox(){
  local docker_option
  local debug_mode
  local config_host
  local other_args
  parse_arg --display --name firefox --config /home --share /home/Share "$@"

  del_stopped firefox

  use-sound-device-if-exists

  local docker_option+=" \
    -e HOME=/home \
  "

  $(if_debug_mode) docker run -d \
    ${docker_option} \
    ${MY_DOCKER_REPO_PREFIX}/firefox
}

firefox_jess(){
  del_stopped firefox

  docker run -d \
    --memory 2gb \
    --net host \
    --cpuset-cpus 0 \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "${HOME}/.firefox/cache:/root/.cache/mozilla" \
    -v "${HOME}/.firefox/mozilla:/root/.mozilla" \
    -v "${HOME}/Downloads:/root/Downloads" \
    -v "${HOME}/Pictures:/root/Pictures" \
    -v "${HOME}/Torrents:/root/Torrents" \
    -e "DISPLAY=unix${DISPLAY}" \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    --device /dev/snd \
    --device /dev/dri \
    --name firefox \
    ${DOCKER_REPO_PREFIX}/firefox "$@"

  # exit current shell
  exit 0
}
fleetctl(){
  docker run --rm -it \
    --entrypoint fleetctl \
    -v "${HOME}/.fleet://.fleet" \
    r.j3ss.co/fleet "$@"
}
gcalcli(){
  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/.gcalcli/home:/home/gcalcli/home" \
    -v "${HOME}/.gcalcli/work/oauth:/home/gcalcli/.gcalcli_oauth" \
    -v "${HOME}/.gcalcli/work/gcalclirc:/home/gcalcli/.gcalclirc" \
    --name gcalcli \
    ${DOCKER_REPO_PREFIX}/gcalcli "$@"
}

gcloud(){
  local docker_option
  local debug_mode
  local config_host
  local other_args

  parse_arg --name gcloud --config /tmp/.config/gcloud --mount /tmp/data "$@"
  docker_option+=" -e CLOUDSDK_CONFIG=/tmp/.config/gcloud "
  [ -z "${other_args}" ] && { set -- bash; } || set -- gcloud "${other_args}"
  del_stopped gcloud
  $(if_debug_mode) docker run -it --rm \
    ${docker_option} \
    google/cloud-sdk \
    "$@"
}

gimp(){
  del_stopped gimp

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -v "${HOME}/Pictures:/root/Pictures" \
    -v "${HOME}/.gtkrc:/root/.gtkrc" \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    --name gimp \
    ${DOCKER_REPO_PREFIX}/gimp
}
gitsome(){
  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    --name gitsome \
    --hostname gitsome \
    -v "${HOME}/.gitsomeconfig:/home/anon/.gitsomeconfig" \
    -v "${HOME}/.gitsomeconfigurl:/home/anon/.gitsomeconfigurl" \
    ${DOCKER_REPO_PREFIX}/gitsome
}
hollywood(){
  docker run --rm -it \
    --name hollywood \
    ${DOCKER_REPO_PREFIX}/hollywood
}
htop(){
  docker run --rm -it \
    --pid host \
    --net none \
    --name htop \
    ${DOCKER_REPO_PREFIX}/htop
}
htpasswd(){
  docker run --rm -it \
    --net none \
    --name htpasswd \
    --log-driver none \
    ${DOCKER_REPO_PREFIX}/htpasswd "$@"
}
http(){
  docker run -t --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --log-driver none \
    ${DOCKER_REPO_PREFIX}/httpie "$@"
}
imagemin(){
  local image=$1
  local extension="${image##*.}"
  local filename="${image%.*}"

  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/Pictures:/root/Pictures" \
    ${DOCKER_REPO_PREFIX}/imagemin sh -c "imagemin /root/Pictures/${image} > /root/Pictures/${filename}_min.${extension}"
}
irssi() {
  del_stopped irssi
  # relies_on notify_osd

  docker run --rm -it \
    --user root \
    -v "${HOME}/.irssi:/home/user/.irssi" \
    ${DOCKER_REPO_PREFIX}/irssi \
    chown -R user /home/user/.irssi

  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/.irssi:/home/user/.irssi" \
    --read-only \
    --name irssi \
    ${DOCKER_REPO_PREFIX}/irssi
}
john(){
  local file
  file=$(realpath "$1")

  docker run --rm -it \
    -v "${file}:/root/$(basename "${file}")" \
    ${DOCKER_REPO_PREFIX}/john "$@"
}
kernel_builder(){
  docker run --rm -it \
    -v /usr/src:/usr/src \
    -v /lib/modules:/lib/modules \
    -v /boot:/boot \
    --name kernel-builder \
    ${DOCKER_REPO_PREFIX}/kernel-builder
}
keypassxc(){
  del_stopped keypassxc

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /usr/share/X11/xkb:/usr/share/X11/xkb:ro \
    -e "DISPLAY=unix${DISPLAY}" \
    -v /etc/machine-id:/etc/machine-id:ro \
    --name keypassxc \
    ${DOCKER_REPO_PREFIX}/keepassxc
}
kicad(){
  del_stopped kicad

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -v "${HOME}/kicad:/root/kicad" \
    -v "${HOME}/.cache/kicad:/root/.cache/kicad" \
    -v "${HOME}/.config/kicad:/root/.config/kicad" \
    -e QT_DEVICE_PIXEL_RATIO \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    --device /dev/dri \
    --name kicad \
    ${DOCKER_REPO_PREFIX}/kicad
}
kvm(){
  del_stopped kvm
  relies_on pulseaudio

  # modprobe the module
  modprobe kvm

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /run/libvirt:/var/run/libvirt \
    -e "DISPLAY=unix${DISPLAY}" \
    --link pulseaudio:pulseaudio \
    -e PULSE_SERVER=pulseaudio \
    --group-add audio \
    --name kvm \
    --privileged \
    ${DOCKER_REPO_PREFIX}/kvm
}
libreoffice(){
  del_stopped libreoffice

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -v "${HOME}/slides:/root/slides" \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    --name libreoffice \
    ${DOCKER_REPO_PREFIX}/libreoffice
}
lpass(){
  docker run --rm -it \
    -v "${HOME}/.lpass:/root/.lpass" \
    --name lpass \
    ${DOCKER_REPO_PREFIX}/lpass "$@"
}
lynx(){
  docker run --rm -it \
    --name lynx \
    ${DOCKER_REPO_PREFIX}/lynx "$@"
}
masscan(){
  docker run -it --rm \
    --log-driver none \
    --net host \
    --cap-add NET_ADMIN \
    --name masscan \
    ${DOCKER_REPO_PREFIX}/masscan "$@"
}
mc(){
  cwd="$(pwd)"
  name="$(basename "$cwd")"

  docker run --rm -it \
    --log-driver none \
    -v "${cwd}:/home/mc/${name}" \
    --workdir "/home/mc/${name}" \
    ${DOCKER_REPO_PREFIX}/mc "$@"
}
mpd(){
  del_stopped mpd

  # adding cap sys_admin so I can use nfs mount
  # the container runs as a unpriviledged user mpd
  docker run -d \
    --device /dev/snd \
    --cap-add SYS_ADMIN \
    -e MPD_HOST=/var/lib/mpd/socket \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/exports:/etc/exports:ro \
    -v "${HOME}/.mpd:/var/lib/mpd" \
    -v "${HOME}/.mpd.conf:/etc/mpd.conf" \
    --name mpd \
    ${DOCKER_REPO_PREFIX}/mpd
}
mutt(){
  # subshell so we dont overwrite variables
  (
  local account=$1
  export IMAP_SERVER
  export SMTP_SERVER

  if [[ "$account" == "riseup" ]]; then
    export GMAIL=$MAIL_RISEUP
    export GMAIL_NAME=$MAIL_RISEUP_NAME
    export GMAIL_PASS=$MAIL_RISEUP_PASS
    export GMAIL_FROM=$MAIL_RISEUP_FROM
    IMAP_SERVER=mail.riseup.net
    SMTP_SERVER=$IMAP_SERVER
  fi

  docker run -it --rm \
    -e GMAIL \
    -e GMAIL_NAME \
    -e GMAIL_PASS \
    -e GMAIL_FROM \
    -e GPG_ID \
    -e IMAP_SERVER \
    -e SMTP_SERVER \
    -v "${HOME}/.gnupg:/home/user/.gnupg:ro" \
    -v /etc/localtime:/etc/localtime:ro \
    --name "mutt-${account}" \
    ${DOCKER_REPO_PREFIX}/mutt
  )
}
ncmpc(){
  del_stopped ncmpc

  docker run --rm -it \
    -v "${HOME}/.mpd/socket:/var/run/mpd/socket" \
    -e MPD_HOST=/var/run/mpd/socket \
    --name ncmpc \
    ${DOCKER_REPO_PREFIX}/ncmpc "$@"
}
neoman(){
  del_stopped neoman

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    --device /dev/bus/usb \
    --device /dev/usb \
    --name neoman \
    ${DOCKER_REPO_PREFIX}/neoman
}
nes(){
  del_stopped nes
  local game=$1

  docker run -d \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    --device /dev/dri \
    --device /dev/snd \
    --name nes \
    ${DOCKER_REPO_PREFIX}/nes "/games/${game}.rom"
}
netcat(){
  docker run --rm -it \
    --net host \
    ${DOCKER_REPO_PREFIX}/netcat "$@"
}
nginx(){
  del_stopped nginx

  docker run -d \
    --restart always \
    -v "${HOME}/.nginx:/etc/nginx" \
    --net host \
    --name nginx \
    nginx

  # add domain to hosts & open nginx
  sudo hostess add jess 127.0.0.1
}
nmap(){
  docker run --rm -it \
    --net host \
    ${DOCKER_REPO_PREFIX}/nmap "$@"
}

node(){
  local docker_option+=`docker_mount_os`

  docker run --rm -it \
      ${docker_option} \
      --name node \
      node bash
}

notify_osd(){
  del_stopped notify_osd

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    --net none \
    -v /etc \
    -v /home/user/.dbus \
    -v /home/user/.cache/dconf \
    -e "DISPLAY=unix${DISPLAY}" \
    --name notify_osd \
    ${DOCKER_REPO_PREFIX}/notify-osd
}
alias notify-send=notify_send
notify_send(){
  relies_on notify_osd
  local args=${*:2}
  docker exec -i notify_osd notify-send "$1" "${args}"
}
now(){
  docker run -it --rm \
    -v "${HOME}/.now:/root/.now" \
    -v "$(pwd):/usr/src/repo:ro" \
    --workdir /usr/src/repo \
    --log-driver none \
    ${DOCKER_REPO_PREFIX}/now "$@"
}
openscad(){
  del_stopped openscad

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -v "${HOME}/openscad:/root/openscad" \
    -v "${HOME}/.config/OpenSCAD:/root/.config/OpenSCAD" \
    -e QT_DEVICE_PIXEL_RATIO \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    --device /dev/dri \
    --name openscad \
    ${DOCKER_REPO_PREFIX}/openscad
}
opensnitch(){
  del_stopped opensnitchd
  del_stopped opensnitch

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    --net host \
    --cap-add NET_ADMIN \
    -v /etc/machine-id:/etc/machine-id:ro \
    -v /var/run/dbus:/var/run/dbus \
    -v /usr/share/dbus-1:/usr/share/dbus-1 \
    -v "/var/run/user/$(id -u):/var/run/user/$(id -u)" \
    -e DBUS_SESSION_BUS_ADDRESS \
    -e XAUTHORITY \
    -v "${HOME}/.Xauthority:$HOME/.Xauthority" \
    -v /tmp:/tmp \
    --name opensnitchd \
    ${DOCKER_REPO_PREFIX}/opensnitchd

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -v /usr/share/X11:/usr/share/X11:ro \
    -v /usr/share/dbus-1:/usr/share/dbus-1 \
    -v /etc/machine-id:/etc/machine-id:ro \
    -v /var/run/dbus:/var/run/dbus \
    -v "/var/run/user/$(id -u):/var/run/user/$(id -u)" \
    -e DBUS_SESSION_BUS_ADDRESS \
    -e XAUTHORITY \
    -v "${HOME}/.Xauthority:$HOME/.Xauthority" \
    -e HOME \
    -e QT_DEVICE_PIXEL_RATIO \
    -e XDG_RUNTIME_DIR \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /tmp:/tmp \
    -u "$(id -u)" -w "$HOME" \
    --net host \
    --name opensnitch \
    ${DOCKER_REPO_PREFIX}/opensnitch
}
osquery(){
  rmctr osquery

  docker run -d --restart always \
    -v /etc/localtime:/etc/localtime:ro \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /etc/os-release:/etc/os-release:ro \
    --net host \
    --ipc host \
    --pid host \
    -e OSQUERY_ENROLL_SECRET \
    --name osquery \
    --privileged \
    ${DOCKER_REPO_PREFIX}/osquery \
    --verbose \
    --enroll_secret_env=OSQUERY_ENROLL_SECRET \
    --docker_socket=/var/run/docker.sock \
    --host_identifier=hostname \
    --tls_hostname="${OSQUERY_DOMAIN}" \
    --enroll_tls_endpoint=/api/v1/osquery/enroll \
    --config_plugin=tls \
    --config_tls_endpoint=/api/v1/osquery/config \
    --config_tls_refresh=10 \
    --disable_distributed=false \
    --distributed_plugin=tls \
    --distributed_interval=10 \
    --distributed_tls_max_attempts=3 \
    --distributed_tls_read_endpoint=/api/v1/osquery/distributed/read \
    --distributed_tls_write_endpoint=/api/v1/osquery/distributed/write \
    --logger_plugin=tls \
    --logger_tls_endpoint=/api/v1/osquery/log \
    --logger_tls_period=10
}
pandoc(){
  local file=${*: -1}
  local lfile
  lfile=$(readlink -m "$(pwd)/${file}")
  local rfile
  rfile=$(readlink -m "/$(basename "$file")")
  local args=${*:1:${#@}-1}

  docker run --rm \
    -v "${lfile}:${rfile}" \
    -v /tmp:/tmp \
    --name pandoc \
    ${DOCKER_REPO_PREFIX}/pandoc "${args}" "${rfile}"
}
pivman(){
  del_stopped pivman

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    --device /dev/bus/usb \
    --device /dev/usb \
    --name pivman \
    ${DOCKER_REPO_PREFIX}/pivman
}
pms(){
  del_stopped pms

  docker run --rm -it \
    -v "${HOME}/.mpd/socket:/var/run/mpd/socket" \
    -e MPD_HOST=/var/run/mpd/socket \
    --name pms \
    ${DOCKER_REPO_PREFIX}/pms "$@"
}
pond(){
  del_stopped pond
  relies_on torproxy

  docker run --rm -it \
    --net container:torproxy \
    --name pond \
    ${DOCKER_REPO_PREFIX}/pond
}
privoxy(){
  del_stopped privoxy
  relies_on torproxy

  docker run -d \
    --restart always \
    --link torproxy:torproxy \
    -v /etc/localtime:/etc/localtime:ro \
    -p 8118:8118 \
    --name privoxy \
    ${DOCKER_REPO_PREFIX}/privoxy

  hostess add privoxy "$(docker inspect --format '{{.NetworkSettings.Networks.bridge.IPAddress}}' privoxy)"
}
pulseaudio(){
  del_stopped pulseaudio

  docker run -d \
    --network="${RIDE_NETWORK}" \
    -u "${HOST_USER_ID}:${HOST_USER_GID}" \
    -e HOME=/tmp \
    -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
    -p 4713:4713 \
    --restart unless-stopped \
    -v /etc/localtime:/etc/localtime:ro \
    --device /dev/snd \
    --group-add audio \
    --name pulseaudio \
    ${DOCKER_REPO_PREFIX}/pulseaudio
}

rainbowstream(){
  docker run -it --rm \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/.rainbow_oauth:/root/.rainbow_oauth" \
    -v "${HOME}/.rainbow_config.json:/root/.rainbow_config.json" \
    --name rainbowstream \
    ${DOCKER_REPO_PREFIX}/rainbowstream
}
registrator(){
  del_stopped registrator

  docker run -d --restart always \
    -v /var/run/docker.sock:/tmp/docker.sock \
    --net host \
    --name registrator \
    gliderlabs/registrator consul:
}

remmina(){
  del_stopped remmina

  local config_host=$(get_app_host_config_path remmina)

  docker run -d \
      --network="${RIDE_NETWORK}" \
      -v /etc/localtime:/etc/localtime:ro \
      -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
      -e GDK_SCALE \
      -e GDK_DPI_SCALE \
      --name remmina \
      -u "${HOST_USER_ID}:${HOST_USER_GID}" \
      -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
      -v "${config_host}":/home/data -e HOME=/home/data --workdir=/home/data \
      -v "${RIDE_CONFIG}/Share":/home/Share \
      ${MY_DOCKER_REPO_PREFIX}/remmina \
      remmina
}

ricochet(){
  del_stopped ricochet

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    -e QT_DEVICE_PIXEL_RATIO \
    --device /dev/dri \
    --name ricochet \
    ${DOCKER_REPO_PREFIX}/ricochet
}
rstudio(){
  del_stopped rstudio

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "${HOME}/fastly-logs:/root/fastly-logs" \
    -v /dev/shm:/dev/shm \
    -e "DISPLAY=unix${DISPLAY}" \
    -e QT_DEVICE_PIXEL_RATIO \
    --device /dev/dri \
    --name rstudio \
    ${DOCKER_REPO_PREFIX}/rstudio
}
s3cmdocker(){
  del_stopped s3cmd

  docker run --rm -it \
    -e AWS_ACCESS_KEY="${DOCKER_AWS_ACCESS_KEY}" \
    -e AWS_SECRET_KEY="${DOCKER_AWS_ACCESS_SECRET}" \
    -v "$(pwd):/root/s3cmd-workspace" \
    --name s3cmd \
    ${DOCKER_REPO_PREFIX}/s3cmd "$@"
}
samba(){
  del_stopped samba
  cwd="/mnt/ntfs"

  docker run -d \
    -p 139:139 -p 445:445 \
    -v ${cwd}:/mount/samba \
    --restart unless-stopped \
    --workdir "/home/mc/${name}" \
    -e "USERID=1000" \
    -e "GROUPID=1000" \
    --name samba \
    ${MY_DOCKER_REPO_PREFIX}/samba \
    -s "public;/mount/samba;yes;no" \
    -S

  # exit current shell
  exit 0
}
scudcloud(){
  del_stopped scudcloud

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -v /etc/machine-id:/etc/machine-id:ro \
    -v /var/run/dbus:/var/run/dbus \
    -v "/var/run/user/$(id -u):/var/run/user/$(id -u)" \
    -e TERM \
    -e XAUTHORITY \
    -e DBUS_SESSION_BUS_ADDRESS \
    -e HOME \
    -e QT_DEVICE_PIXEL_RATIO \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -u "$(whoami)" -w "$HOME" \
    -v "${HOME}/.Xauthority:$HOME/.Xauthority" \
    -v "${HOME}/.scudcloud:/home/jessie/.config/scudcloud" \
    --device /dev/snd \
    --name scudcloud \
    ${DOCKER_REPO_PREFIX}/scudcloud

  # exit current shell
  exit 0
}
shorewall(){
  del_stopped shorewall

  docker run --rm -it \
    --net host \
    --cap-add NET_ADMIN \
    --privileged \
    --name shorewall \
    ${DOCKER_REPO_PREFIX}/shorewall "$@"
}
skype(){
  del_stopped skype
  relies_on pulseaudio

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    --link pulseaudio:pulseaudio \
    -e PULSE_SERVER=pulseaudio \
    --security-opt seccomp:unconfined \
    --device /dev/video0 \
    --group-add video \
    --group-add audio \
    --name skype \
    ${DOCKER_REPO_PREFIX}/skype
}
slack(){
  del_stopped slack

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    --device /dev/snd \
    --device /dev/dri \
    --device /dev/video0 \
    --group-add audio \
    --group-add video \
    -v "${HOME}/.slack:/root/.config/Slack" \
    --ipc="host" \
    --name slack \
    ${DOCKER_REPO_PREFIX}/slack "$@"
}
spotify(){
  del_stopped spotify

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -e QT_DEVICE_PIXEL_RATIO \
    --security-opt seccomp:unconfined \
    --device /dev/snd \
    --device /dev/dri \
    --group-add audio \
    --group-add video \
    --name spotify \
    ${DOCKER_REPO_PREFIX}/spotify
}
ssh2john(){
  local file
  file=$(realpath "$1")

  docker run --rm -it \
    -v "${file}:/root/$(basename "${file}")" \
    --entrypoint ssh2john \
    ${DOCKER_REPO_PREFIX}/john "$@"
}
sshb0t(){
  del_stopped sshb0t

  if [[ ! -d "${HOME}/.ssh" ]]; then
    mkdir -p "${HOME}/.ssh"
  fi

  if [[ ! -f "${HOME}/.ssh/authorized_keys" ]]; then
    touch "${HOME}/.ssh/authorized_keys"
  fi

  GITHUB_USER=${GITHUB_USER:=jessfraz}

  docker run --rm -it \
    --name sshb0t \
    -v "${HOME}/.ssh/authorized_keys:/root/.ssh/authorized_keys" \
    r.j3ss.co/sshb0t \
    --user "${GITHUB_USER}" --keyfile /root/.ssh/authorized_keys --once
}
steam(){
  del_stopped steam
  relies_on pulseaudio

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/machine-id:/etc/machine-id:ro \
    -v /var/run/dbus:/var/run/dbus \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "${HOME}/.steam:/home/steam" \
    -e "DISPLAY=unix${DISPLAY}" \
    --link pulseaudio:pulseaudio \
    -e PULSE_SERVER=pulseaudio \
    --device /dev/dri \
    --name steam \
    ${DOCKER_REPO_PREFIX}/steam
}
t(){
  docker run -t --rm \
    -v "${HOME}/.trc:/root/.trc" \
    --log-driver none \
    ${DOCKER_REPO_PREFIX}/t "$@"
}
tarsnap(){
  docker run --rm -it \
    -v "${HOME}/.tarsnaprc:/root/.tarsnaprc" \
    -v "${HOME}/.tarsnap:/root/.tarsnap" \
    -v "$HOME:/root/workdir" \
    ${DOCKER_REPO_PREFIX}/tarsnap "$@"
}
telnet(){
  docker run -it --rm \
    --log-driver none \
    ${DOCKER_REPO_PREFIX}/telnet "$@"
}
termboy(){
  del_stopped termboy
  local game=$1

  docker run --rm -it \
    --device /dev/snd \
    --name termboy \
    ${DOCKER_REPO_PREFIX}/nes "/games/${game}.rom"
}
terraform(){
  docker run -it --rm \
    -v "${HOME}:${HOME}:ro" \
    -v "$(pwd):/usr/src/repo" \
    -v /tmp:/tmp \
    --workdir /usr/src/repo \
    --log-driver none \
    -e GOOGLE_APPLICATION_CREDENTIALS \
    -e SSH_AUTH_SOCK \
    ${DOCKER_REPO_PREFIX}/terraform "$@"
}
tor(){
  del_stopped tor

  docker run -d \
    --net host \
    --name tor \
    ${DOCKER_REPO_PREFIX}/tor

  # set up the redirect iptables rules
  sudo setup-tor-iptables

  # validate we are running through tor
  browser-exec "https://check.torproject.org/"
}
torbrowser(){
  del_stopped torbrowser

    # --privileged \
    # -v /dev:/dev \
  docker run -d \
    -v tor-browser-config:/usr/local/bin/Browser/TorBrowser/Data \
    -v /etc/localtime:/etc/localtime:ro \
    -e "DISPLAY=unix${DISPLAY}" -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e PULSE_SERVER=unix:/run/user/1000/pulse/native -v /run/user/1000/pulse:/run/user/1000/pulse \
    -v /dev/shm:/dev/shm \
    --name torbrowser \
    ${MY_DOCKER_REPO_PREFIX}/tor-browser
}
tormessenger(){
  del_stopped tormessenger

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    --device /dev/snd \
    --name tormessenger \
    ${DOCKER_REPO_PREFIX}/tor-messenger

  # exit current shell
  exit 0
}
torproxy(){
  del_stopped torproxy

  docker run -d \
    --restart always \
    -v /etc/localtime:/etc/localtime:ro \
    -p 9050:9050 \
    --name torproxy \
    ${DOCKER_REPO_PREFIX}/tor-proxy

  sudo env "PATH=$PATH" hostess add torproxy "$(docker inspect --format '{{.NetworkSettings.Networks.bridge.IPAddress}}' torproxy)"
}
traceroute(){
  docker run --rm -it \
    --net host \
    ${DOCKER_REPO_PREFIX}/traceroute "$@"
}
transmission(){
  del_stopped transmission

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/Torrents:/transmission/download" \
    -v "${HOME}/.transmission:/transmission/config" \
    -p 9091:9091 \
    -p 51413:51413 \
    -p 51413:51413/udp \
    --name transmission \
    ${DOCKER_REPO_PREFIX}/transmission


  hostess add transmission "$(docker inspect --format '{{.NetworkSettings.Networks.bridge.IPAddress}}' transmission)"
  browser-exec "http://transmission:9091"
}
travis(){
  docker run -it --rm \
    -v "${HOME}/.travis:/root/.travis" \
    -v "$(pwd):/usr/src/repo:ro" \
    --workdir /usr/src/repo \
    --log-driver none \
    ${DOCKER_REPO_PREFIX}/travis "$@"
}

docker_run(){
  local docker_option
  local debug_mode
  local config_host
  local other_args

  while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d) docker_option+=" -d " ;;
        --rm) docker_option+=" --rm " ;;
        -r|--reset) docker_option+=" --entrypoint= " ;;
        *) break ;;
    esac
    shift
  done

  parse_arg --name docker_run --mount /tmp/data "$@"

  del_stopped docker_run 
  use-sound-device-if-exists

  set -- $other_args
  $(if_debug_mode) docker run -it \
    ${docker_option} \
    "$@"
}

virsh(){
  relies_on kvm

  docker run -it --rm \
    -v /etc/localtime:/etc/localtime:ro \
    -v /run/libvirt:/var/run/libvirt \
    --log-driver none \
    --net container:kvm \
    ${DOCKER_REPO_PREFIX}/libvirt-client "$@"
}
virtualbox(){
  del_stopped virtualbox

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    --privileged \
    --name virtualbox \
    ${DOCKER_REPO_PREFIX}/virtualbox
}
virt_viewer(){
  relies_on kvm

  docker run -it --rm \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix  \
    -e "DISPLAY=unix${DISPLAY}" \
    -v /run/libvirt:/var/run/libvirt \
    -e PULSE_SERVER=pulseaudio \
    --group-add audio \
    --log-driver none \
    --net container:kvm \
    ${DOCKER_REPO_PREFIX}/virt-viewer "$@"
}
alias virt-viewer="virt_viewer"
visualstudio(){
  del_stopped visualstudio

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix  \
    -e "DISPLAY=unix${DISPLAY}" \
    --device /dev/dri \
    --name visualstudio \
    ${DOCKER_REPO_PREFIX}/vscode
}
alias vscode="visualstudio"
vlc(){
  del_stopped vlc
  relies_on pulseaudio

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    -e GDK_SCALE \
    -e GDK_DPI_SCALE \
    -e QT_DEVICE_PIXEL_RATIO \
    --link pulseaudio:pulseaudio \
    -e PULSE_SERVER=pulseaudio \
    --group-add audio \
    --group-add video \
    -v "${HOME}/Torrents:/home/vlc/Torrents" \
    --device /dev/dri \
    --name vlc \
    ${DOCKER_REPO_PREFIX}/vlc
}
watchman(){
  del_stopped watchman

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/Downloads:/root/Downloads" \
    --name watchman \
    ${DOCKER_REPO_PREFIX}/watchman --foreground
}

wechat(){
  local config_host=$(get_app_host_config_path wechat)
  del_stopped wechat
  relies_on desktop

  use-sound-device-if-exists

  docker run -d \
    -e WINEARCH=win64 \
    -e WINEPREFIX=/home/data \
    -v "${config_host}":/home/data \
    -e HOME=/home/data --workdir=/home/data \
    --network="${RIDE_NETWORK}" \
    -u "${HOST_USER_ID}:${HOST_USER_GID}" \
    --ipc=container:desktop \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
    -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
    --name wechat \
    ${MY_DOCKER_REPO_PREFIX}/wine $(
      [ -z "$1" ] && {
        echo bash run.sh
      } || echo "$@"
    )
}

weematrix(){
  del_stopped weematrix

  docker run --rm -it \
    --user root \
    -v "${HOME}/.weechat:/home/user/.weechat" \
    ${DOCKER_REPO_PREFIX}/weechat-matrix \
    chown -R user /home/user/.weechat

  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/.weechat:/home/user/.weechat" \
    -e "TERM=screen" \
    --name weematrix \
    ${DOCKER_REPO_PREFIX}/weechat-matrix
}
weeslack(){
  del_stopped weeslack

  docker run --rm -it \
    --user root \
    -v "${HOME}/.weechat:/home/user/.weechat" \
    ${DOCKER_REPO_PREFIX}/wee-slack \
    chown -R user /home/user/.weechat

  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${HOME}/.weechat:/home/user/.weechat" \
    --name weeslack \
    ${DOCKER_REPO_PREFIX}/wee-slack
}
wg(){
  docker run -i --rm \
    --log-driver none \
    -v /tmp:/tmp \
    --cap-add NET_ADMIN \
    --net host \
    --name wg \
    ${DOCKER_REPO_PREFIX}/wg "$@"
}

wine(){
  local config_host=$(get_app_host_config_path wine)
  del_stopped wine
  relies_on desktop

  use-sound-device-if-exists

  docker run -d \
    -e WINEARCH=win64 \
    -e WINEPREFIX=/home/data \
    -e LC_ALL=zh_CN.UTF-8 \
    -e LANG=zh_CN.UTF-8 \
    -e LANGUAGE=en_US.UTF-8 \
    -v "${config_host}":/home/data \
    -e HOME=/home/data --workdir=/home/data \
    --network="${RIDE_NETWORK}" \
    -u "${HOST_USER_ID}:${HOST_USER_GID}" \
    --ipc=container:desktop \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
    -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
    --name wine \
    ${MY_DOCKER_REPO_PREFIX}/wine $(
      [ -z "$1" ] && {
        echo tail -f
      } || echo "$@"
    )
}

wireshark(){
  del_stopped wireshark

  docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e "DISPLAY=unix${DISPLAY}" \
    --cap-add NET_RAW \
    --cap-add NET_ADMIN \
    --net host \
    --name wireshark \
    ${DOCKER_REPO_PREFIX}/wireshark
}
wrk(){
  docker run -it --rm \
    --log-driver none \
    --name wrk \
    ${DOCKER_REPO_PREFIX}/wrk "$@"
}
ykman(){
  del_stopped ykpersonalize

  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    --device /dev/usb \
    --device /dev/bus/usb \
    --name ykman \
    ${DOCKER_REPO_PREFIX}/ykman bash
}
ykpersonalize(){
  del_stopped ykpersonalize

  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    --device /dev/usb \
    --device /dev/bus/usb \
    --name ykpersonalize \
    ${DOCKER_REPO_PREFIX}/ykpersonalize bash
}

yubico_piv_tool(){
  del_stopped yubico-piv-tool

  docker run --rm -it \
    -v /etc/localtime:/etc/localtime:ro \
    --device /dev/usb \
    --device /dev/bus/usb \
    --name yubico-piv-tool \
    ${DOCKER_REPO_PREFIX}/yubico-piv-tool bash
}
alias yubico-piv-tool="yubico_piv_tool"

# ./.dockerfunc.sh test
if [[ "$1" = "test" ]]; then
  HOST_HOME=/home/user
  RIDE_NETWORK="ride_network"
  HOST_USER_ID=1000
  HOST_USER_GID=1000
  setupenv

  function get_host_pwd {
    echo "calling: get_host_pwd $@" >> /tmp/ride.log
    echo "/home/laser/projects/ride"
  }
  function docker {
    echo "calling: docker $@"
  }
  function docker_mount_os {
    return
  }

  if ! [[ $(devpy) =~ .*lasery/devpy ]]; then
    echo "TEST FAILURE: devpy"
    exit 1
  fi

  function get_folder {
    echo "/home/ride/.ride/aws"
  }

  if [[ $(get_app_host_config_path aws) != "/home/user/.ride/aws" ]]; then
    echo "TEST FAILURE: get_app_host_config_path aws"
    exit 1
  fi

  config_aws="/home/user/other"
  if [[ $(get_app_host_config_path aws) != "/home/user/other" ]]; then
    echo "TEST FAILURE: get_app_host_config_path aws: given config path"
    exit 1
  fi

  if ! [[ $(aws) =~ "/home/user/other:/tmp/.aws" ]]; then
    echo "TEST FAILURE: aws"
    exit 1
  fi

  if ! [[ $(chrome --docker docker_option --host --debug chrome_arg) =~ "docker run -d docker_option" ]]; then
    echo "TEST FAILURE: parse_arg"
    exit 1
  fi

  if [[ $(chrome --debug --network no) =~ "network" ]]; then
    echo "TEST FAILURE: parse_arg: network=no"
    exit 1
  fi

  unset docker_option
  parse_arg --user 0:0
  if ! [[ $docker_option =~ "--user=0:0" ]]; then
    echo "TEST FAILURE: parse_arg: user=no"
    exit 1
  fi

  unset docker_option
  parse_arg --mount /tmp/data

  unset docker_option
  if ! [[ $(docker_run -r repo bash) =~ "repo bash" ]]; then
    echo "TEST FAILURE: docker_run"
    exit 1
  fi

  echo TESTS succeed!

  unset docker_option
  # devcpp
  # gcloud --debug help
  # gcloud --dc
fi

  # debugger "$@"
  # echo $docker_option
  # echo "$@"
      # echo $user
  # echo $app_name
  # echo $host_share_path
  # echo $config_host
  # echo $config_path
  # echo $mount_path
  # echo $network
  # echo \
    # -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
    # [ $debug_control ] && echo "$@"
  # [ $debug_control ] && debugger "$#"
  # echo "$#"
  # echo "$@"
  # echo "$1"
  # echo "$2"
  # echo "$mount_path"

  # debugger "$@"
  # echo $other_args
  # [ $debug_control ] && debugger "$@"
  # echo $other_args
  # echo "$@"
  # debug_control=0
  # debugger "$@"
  # docker_run --debug
