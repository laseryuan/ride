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
- **GPG agent:** the host `S.gpg-agent.extra` socket is mounted as the
  container's `/home/ride/.gnupg/S.gpg-agent`, where GPG expects its agent.
  This is the restricted endpoint intended for forwarding: it permits signing
  and decryption requests while blocking agent administration and direct card
  control. `SSH_AUTH_SOCK` points to the separately mounted GPG SSH-agent socket
  when it is available. Direct mounting is supported when Docker shares the
  host's Linux kernel and does not require a `socat` process.
- **GPG keyring:** the host's `~/.gnupg` is mounted at the separate
  `/home/ride/.gnupg-host` path. At startup, Ride links its persistent keyring,
  trust, revocation data, and private-key stub entries into the container's
  `~/.gnupg`. Agent sockets, lock files, and `random_seed` are deliberately not
  linked, and host configuration is kept separate because it may contain
  macOS-specific paths. This lets container GPG commands reuse the host keyring without
  mistaking a macOS agent socket for a usable Linux socket. Keyring changes made
  through those links write through to the host.

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

Ride exposes the host keyring read-write because key import, trust updates, and
other normal GPG operations update it. Only use Ride images and code that you
trust with those credentials. The directory is mounted at a staging path rather
than directly over `~/.gnupg`, so host agent sockets and transient files can be
excluded; private-key and smart-card operations still remain in the agent.

To use GPG-managed SSH keys, enable SSH support in the host agent (for example,
with `enable-ssh-support` in `~/.gnupg/gpg-agent.conf`) before launching Ride.

#### Test smart-card access

First, run the host-side preflight check before starting a new container:

```bash
ride gpg-check
```

On Linux, it must print a live host socket and `Restricted GPG-agent
forwarding: supported`. On macOS, it intentionally exits unsuccessfully and
reports that direct forwarding is unsupported; in that case the current Ride
implementation will not provide YubiKey access until a separate remote-agent
bridge is configured.

You can also inspect the forwarding mode from inside a newly started container:

```bash
ride-gpg-check
```

On Linux this checks the forwarded restricted agent. On macOS it exits with a
clear explanation. In particular, a successful
`gpg-connect-agent /bye` by itself is **not** proof of forwarding: when no host
socket is mounted, GnuPG can start a container-local agent. That local agent has
no access to the Mac's USB devices or `scdaemon`, which produces the exact
`No SmartCard daemon` error shown by `SCD SERIALNO` and `gpg --card-status`.

After a successful Linux preflight, start a fresh Ride container. The smart card
stays attached to the host. Run these checks inside Ride; the
mounted socket sends requests to the host agent, which talks to the host's card
and `scdaemon`:

```bash
# The first two commands verify that GPG sees the mounted host socket.
gpgconf --list-dirs agent-socket
test -S "$(gpgconf --list-dirs agent-socket)"
stat -c '%u:%g %A %n' ~/.gnupg "$(gpgconf --list-dirs agent-socket)"
id

# Verify the restricted agent connection.
gpg-connect-agent /bye
```

Do not use `SCD SERIALNO` or `gpg --card-status` as forwarding tests. The extra
socket intentionally denies smart-card administration and status operations.
Run those commands on the host when diagnosing its reader, card, or `scdaemon`.

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

The PIN prompt and private-key operation are handled by the host agent. The
decrypt command is the end-to-end test that the restricted socket, ciphertext
recipient, shared keyring, card, and PIN flow all match. Do not start a separate
`gpg-agent` in the container.

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
