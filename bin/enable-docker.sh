#!/bin/bash

# if specify host docker group id we add user to this group
if [ -n "${HOST_DOCKER_ID}" ]; then
    # echo "Adding user to host docker group id" >> /tmp/ride.log;
    groupadd --force --gid $HOST_DOCKER_ID docker
    usermod -a -G $HOST_DOCKER_ID ride
else
    # macos docker user is root
    # https://github.com/docker/for-mac/issues/5072
    groupadd docker
    usermod -aG docker ride 
    chgrp docker /var/run/docker.sock
    chmod g+w /var/run/docker.sock
fi
