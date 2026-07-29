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
Behavior differs by docker host, because Docker Desktop for Mac's file
sharing (osxfs/virtiofs/sshfs) only forwards regular file I/O, not Unix
socket semantics - a bind-mounted agent socket is just an inert file there,
so plain bind mounts of live sockets only work when the docker host is
actually Linux (including a Linux VM, e.g. Colima's).

**Linux docker host:** if the host has a `gpg-agent` running (`gpgconf`
installed and its `agent-socket` reachable), `bin/ride.sh` bind-mounts the
agent's runtime socket directory into the container so `gpg` inside `ride`
talks to the host's agent. If the host agent also has ssh-support enabled
(its `agent-ssh-socket` exists), `SSH_AUTH_SOCK` is pointed at it too, so
`ssh` inside the container authenticates through the host's gpg-agent
instead of raw key files.

**Docker Desktop for Mac:** the direct socket mount above is skipped (see
why above). Instead, `SSH_AUTH_SOCK` is pointed at
`/run/host-services/ssh-auth.sock` - a real socket relay Docker Desktop for
Mac provides to proxy whatever the host's current `SSH_AUTH_SOCK` is (system
ssh-agent, gpg-agent if you've set up ssh-support + `SSH_AUTH_SOCK` on the
Mac side, 1Password, etc.), so `ssh` in the container still works through
the host's agent. Plain `gpg` (signing/decrypting) has no such relay
available on Docker Desktop, so it can't reach the host's agent there - see
the keyring paragraph below for what does still work.

**Colima:** unlike Docker Desktop, Colima runs containers inside a real
Lima-managed Linux VM, so once a socket is actually inside that VM, bind-
mounting it into the container is a normal same-OS Linux mount - the same
limitation Docker Desktop has doesn't apply. Getting the socket from the
Mac into the VM in the first place is Lima's job, via a `portForwards`
entry proxying it at the socket level (not a filesystem share) - add this
to your Colima config (`colima start --edit`, default profile):
```yaml
portForwards:
- guestSocket: "/run/user/{{.UID}}/gnupg/S.gpg-agent"
  hostSocket: "{{.Home}}/.gnupg/S.gpg-agent.extra"
- guestSocket: "/run/user/{{.UID}}/gnupg/S.gpg-agent.ssh"   # optional, for ssh
  hostSocket: "{{.Home}}/.gnupg/S.gpg-agent.ssh"
```
This forwards gpg-agent's *extra* socket (`hostSocket`) rather than the full
`agent-socket` - extra is deliberately restricted (sign/decrypt/encrypt
only, no key management), which is more appropriate to expose to a
disposable container. Note the guest side is named plain `S.gpg-agent`, not
`.extra`: gpg only auto-discovers that name, and (see below) the directory
containing it has to be mounted as a whole, so it can't be renamed on the
way into the container - it has to already have its final name on the
Colima VM side.

`bin/ride.sh` detects this (via `docker context show` = `colima`) and, if
`/run/user/<uid>/gnupg/S.gpg-agent` is live (checked with `colima ssh`),
bind-mounts that whole directory into the container - not the individual
socket file. Bind-mounting an individual file makes docker synthesize the
missing parent directories as root-owned, and gpg's socket-directory safety
check rejects a runtime dir it doesn't own, silently falling back to
`~/.gnupg` (read-only) even though the socket file itself is reachable;
mounting the directory as a whole preserves its real ownership from the VM
side instead. `SSH_AUTH_SOCK` is pointed at the `.ssh` socket in the same
directory if that one's live too. `{{.UID}}` is assumed to render to the
same uid as the Mac user, which is Lima's default behavior and matches the
uid `ride` maps the container user to.

Separately, if the host's `$GNUPGHOME` (default `~/.gnupg`) exists, it's
bind-mounted read-only into the container at `/home/ride/.gnupg` - gpg's
default homedir there, so this doesn't need (and must not set) an explicit
`GNUPGHOME`; that would make gpg look for the agent socket inside this
read-only mount instead of the real forwarded one. On Linux and Colima,
this is what lets a smartcard-backed key work from inside the container:
the stub tells `gpg` which keygrip to ask for, and the actual
signing/decryption - including any PIN prompt and card I/O - is carried out
by the host's `gpg-agent`/`scdaemon` over the forwarded agent socket, never
inside the container. On Docker Desktop, without a working agent socket,
this mount only gets you key listing (`gpg -k`/`-K`); it can't sign or
decrypt via a smartcard. The mount is read-only in all cases, so a
disposable container can't corrupt the host's trustdb.

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
