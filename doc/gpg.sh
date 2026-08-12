# Setup environment
gpg -k # initiate the environment if there is none

# Optional: get the agent socket path: /Users/laseryuan/.gnupg/S.gpg-agent
sshhost
gpgconf --list-dirs agent-socket
gpgconf --list-dirs agent-extra-socket # for safty
gpgconf --list-dirs agent-ssh-socket # for ssh agent. see below

# Mount host's agent socket to local
rm -f ~/.gnupg/S.gpg-agent* # make sure the socket file is not occupied
sshhost --ssh "-L ~/.gnupg/S.gpg-agent:${HOST_HOME}/.gnupg/S.gpg-agent.extra" # in a new terminal
ls ~/.gnupg # Should see S.gpg-agent

# Build public keyring
gpg --fetch-keys https://github.com/laseryuan.gpg
# Or, use public key url in the card
gpg --card-edit
fetch
quit

# Test
echo hello | gpg -u "Laser Yuan" --clearsign
echo "secret" | gpg -e -r "laser.yuan@gmail.com"

# For ssh login
# Option 1: Mount host's agent socket to local through ssh
sshhost --ssh "-L ~/.gnupg/S.gpg-agent.ssh:${HOST_HOME}/.gnupg/S.gpg-agent.ssh" # in a new terminal

# Option 2: set SSH_AUTH_SOCK before ride
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
echo $SSH_AUTH_SOCK

# Test
ssh-add -L
ssh -T git@github.com
