# Usage
start & install
```
docker run lasery/ride
docker run lasery/ride install | sh
```

custom usage
```
docker run --rm --name=ride -it \
  -e TERM=$TERM \
  -e HOST_pwd=$(pwd) \
  -e HOST_HOME=$HOME \
  -e HOST_NAME=$(hostname) \
  `# mount data`\
  -v $(pwd):/home/ride/projects/${PWD##*/} \
  --workdir=/home/ride/projects/${PWD##*/} \
  `# as host user`\
  -e HOST_USER_NAME=$(id -u -n) -e HOST_USER_ID=$(id -u) -e HOST_USER_GID=$(id -g) \
  `# use host ssh config`\
  `[ -d "$HOME/.ssh"  ] && echo -v $HOME/.ssh:/home/ride/.ssh` \
  `[ -d "$HOME/.kr"  ] && echo -v $HOME/.kr:/home/ride/.kr` \
  `# docker in docker`\
  -e HOST_DOCKER_ID=`cut -d: -f3 < <(getent group docker)` \
  `[ -d "$HOME/.docker"  ] && echo -v $HOME/.docker:/home/ride/.docker` \
  -v /var/run/docker.sock:/var/run/docker.sock \
  `if ifup docker0; then echo "--add-host $(hostname):$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')"; fi` \
  lasery/ride \
  ride
```

## start ssh server
```
sudo /usr/sbin/sshd
```

## gpg-agent forwarding
If the host has a Linux `gpg-agent` running (`gpgconf` installed and its
`agent-socket` reachable), `bin/ride.sh` bind-mounts the agent's runtime
socket directory into the container so `gpg` inside `ride` talks to the
host's agent. If the host agent also has ssh-support enabled (its
`agent-ssh-socket` exists), `SSH_AUTH_SOCK` is pointed at it too, so `ssh`
inside the container authenticates through the host's gpg-agent instead of
raw key files. Not available when the docker host is Mac, since a host
socket can't be bind-mounted through the Docker Desktop VM.

If the host's `$GNUPGHOME` (default `~/.gnupg`) exists, it's also
bind-mounted read-only into the container so `gpg` there sees the same
public keyring, trustdb, and secret-key stubs as the host. This is what
lets a smartcard-backed key work from inside the container: the stub tells
`gpg` which keygrip to ask for, and the actual signing/decryption -
including any PIN prompt and card I/O - is carried out by the host's
`gpg-agent`/`scdaemon` over the forwarded agent socket, never inside the
container. The mount is read-only so a disposable container can't corrupt
the host's trustdb.

# Development
dev docker functions
```
cd .dotfiles/bash/.bashrc.d/
devsh
./.dockerfunc.sh test
```

```
cd ~/projects/ride

  -e HOST_HOME=$HOST_HOME \
  -e HOST_pwd=$HOST_pwd \

docker run --rm --name=ride-dev -it \
  -e TERM=$TERM \
  -e HOST_NAME=$(hostname) \
  `# mount data`\
  -v $HOST_pwd:/home/ride/projects/ride \
  --workdir=/home/ride/projects/ride \
  `# as host user`\
  -e HOST_USER_NAME=$(id -u -n) -e HOST_USER_ID=$(id -u) -e HOST_USER_GID=$(id -g) \
  `# use host ssh config`\
  `[ -d "$HOME/.ssh"  ] && echo -v $HOST_HOME/.ssh:/home/ride/.ssh` \
  `[ -d "$HOME/.kr"  ] && echo -v $HOST_HOME/.kr:/home/ride/.kr` \
  `# docker in docker`\
  -e HOST_DOCKER_ID=$HOST_DOCKER_ID \
  `[ -d "$HOME/.docker"  ] && echo -v $HOST_HOME/.docker:/home/ride/.docker` \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ride:amd64 \
  ride
  bash
```

Test mbuild
```
python3 -m pytest ./mbuild/utils/build.py -s
```

Test container
```
  ride:amd64 \
```

Mount source code
- bash scripts
```
  -v $HOST_HOME/projects/ride/docker-entrypoint.sh:/docker-entrypoint.sh \
  -v $HOST_HOME/projects/ride/bin/:/usr/local/bin/ \
  -v $HOST_HOME/projects/ride/mapuser/user-mapping.sh:/user-mapping.sh \
```

- mbuild
```
  -v $HOST_HOME/projects/ride/mbuild:/home/ride/mbuild \
```

- dotfiles
```
  -v $HOST_HOME/projects/ride/.dotfiles/bash:/home/ride/.dotfiles/bash \
  -v $HOST_HOME/projects/ride/dotfiles/.bashrc:/home/ride/.bashrc \
```

Arm Runtime
```
  -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static `# Cross run` \

  ride:armv6l \
  ride:armv7l \
```

## Build image
1. Create builder image
```
python3 ~/mbuild/utils/build.py docker
python3 ~/mbuild/utils/build.py docker --bake-arg "--progress plain --set *.cache-from=lasery/ride:latest"
python3 ~/mbuild/utils/build.py push --only
python3 ~/mbuild/utils/build.py deploy --only
```
