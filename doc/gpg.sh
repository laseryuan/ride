# Setup environment
gpg -k # initiate the environment if there is none
rm -f ~/.gnupg/S.gpg-agent # remove outdated socket

# Optional: get the agent socket path: /Users/laseryuan/.gnupg/S.gpg-agent
sshhost
gpgconf --list-dirs agent-ssh-socket

# Mount host's agent to local
ssh -L ~/.gnupg/S.gpg-agent:/Users/laseryuan/.gnupg/S.gpg-agent laseryuan@host.docker.internal # in a new terminal
sshhost --ssh "-L ~/.gnupg/S.gpg-agent:/Users/laseryuan/.gnupg/S.gpg-agent" # in a new terminal
ls ~/.gnupg # Should see S.gpg-agent

# Build public keyring
gpg --card-edit
fetch
quit

# Test
echo hello | gpg --clearsign
