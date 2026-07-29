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

### Host SSH and GPG access

When `ride` is launched through `bin/ride.sh`, it provides host credentials in
two separate ways:

- **SSH files:** the host's `~/.ssh` directory is mounted at `/home/ride/.ssh`.
  This supplies SSH configuration, `known_hosts`, and regular key files. Changes
  made in the container affect the host directory because it is a bind mount.
  On Linux, Ride maps its user to the host UID/GID, so the mounted files retain
  their host ownership while remaining accessible to the container user.
- **GPG agent:** available host `S.gpg-agent` and `S.gpg-agent.ssh` sockets are
  mounted directly under `/home/ride/.gnupg`, where GPG expects to find them.
  GPG operations can then talk to the host agent without mounting the host's
  entire GnuPG home. `SSH_AUTH_SOCK` points to the mounted GPG SSH-agent socket
  when it is available. This forwarding does not require a `socat` process and
  is supported when the Docker daemon shares the host's Linux kernel.

Docker Desktop for Mac cannot expose a macOS Unix socket to its Linux VM with a
**direct bind mount**. The mounted path can still pass `test -S` and show
matching numeric ownership, but connection attempts fail because the endpoint
belongs to the macOS kernel. Ride detects macOS and skips these misleading
mounts.

This does not mean that a container can never use a YubiKey attached to a Mac.
Keep `gpg-agent` and `scdaemon` on macOS and forward the agent protocol across a
real VM boundary transport—for example, OpenSSH Unix-socket forwarding from the
host agent's restricted `agent-extra-socket`, or a deliberately configured
host-side TCP bridge. The remote end should be exposed as the container's
`S.gpg-agent`. Merely starting `socat` inside the container against the
bind-mounted macOS socket cannot work, because it still connects to the same
cross-kernel endpoint. Ride does not configure a network bridge automatically,
because doing so requires an explicit authentication and exposure policy.

Mounting the whole host `.gnupg` directory is not recommended: it exposes the
host keyring, trust database, configuration, and lock files to container writes.
Import any required public keys into the container keyring instead; private-key
and smart-card operations remain in the host agent.

To use GPG-managed SSH keys, enable SSH support in the host agent (for example,
with `enable-ssh-support` in `~/.gnupg/gpg-agent.conf`) before launching Ride.

#### Test smart-card access

The smart card stays attached to the host. Run these checks inside Ride; the
mounted socket sends requests to the host agent, which talks to the host's card
and `scdaemon`:

```bash
# The first two commands verify that GPG sees the mounted host socket.
gpgconf --list-dirs agent-socket
test -S "$(gpgconf --list-dirs agent-socket)"
stat -c '%u:%g %A %n' ~/.gnupg "$(gpgconf --list-dirs agent-socket)"
id

# Verify the agent connection, then ask the host scdaemon for the card serial.
gpg-connect-agent /bye
gpg-connect-agent 'SCD SERIALNO' /bye

# This should print the card details and is the normal end-to-end check.
gpg --card-status
```

The socket normally has owner-only permissions, and the host agent also checks
the connecting user's identity. The numeric UID shown by `id` in Ride must match
the socket owner's numeric UID shown by `stat`. If they differ, fix Ride's host
user mapping rather than relaxing the socket permissions or adding a proxy.
If all ownership checks pass but `gpg-connect-agent /bye` fails on Docker
Desktop for Mac, the cross-kernel limitation above—not `.gnupg` ownership—is the
cause.

To test decryption, import only the public key if it is not already in the
container keyring, then decrypt a file addressed to that key:

```bash
gpg --import public-key.asc
gpg --decrypt encrypted-file.gpg > plaintext
```

The PIN prompt and private-key operation are handled by the host agent. A
successful `--card-status` proves card access, but the decrypt command is the
final test that the ciphertext recipient, container public key, card, and PIN
flow all match. Do not start a separate `gpg-agent` in the container.

## start ssh server
```
sudo /usr/sbin/sshd
```

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
