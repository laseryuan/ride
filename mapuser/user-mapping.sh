#!/bin/bash
# vim: set noswapfile :

# credit: https://gist.github.com/renzok/29c9e5744f1dffa392cf

if [ -z "${RIDE_USER}" ]; then
  echo "We need RIDE_USER to be set!"; exit 100
fi

# if host has docker group we add user to this group
if [ -n "${HOST_DOCKER_ID}" ]; then
    echo "Adding user to host docker group" ;
    groupadd --force --gid $HOST_DOCKER_ID docker
    usermod -a -G docker ride
fi

# if both not set we do not need to do anything
if [ -z "${HOST_USER_ID}" -a -z "${HOST_USER_GID}" ]; then
    echo "Nothing to do here." ; exit 0
fi

if [[ ${HOST_USER_NAME} == "root" || ${HOST_USER_ID} == 0} ]]; then
  echo "Changing root home directory ..."
  sed -i -e '/root/s!\(.*:\).*:\(.*\)!\1/home/ride:\2!' /etc/passwd
else
  # reset user_?id to either new id or if empty old (still one of above
  # might not be set)
  RIDE_USER_ID=${HOST_USER_ID:=$RIDE_USER_ID}
  RIDE_USER_GID=${HOST_USER_GID:=$RIDE_USER_GID}

  LINE=$(grep -F "${RIDE_USER}" /etc/passwd)
  sed -i -e "s/^${RIDE_USER}:\([^:]*\):[0-9]*:[0-9]*/${RIDE_USER}:\1:${RIDE_USER_ID}:${RIDE_USER_GID}/"  /etc/passwd
  # replace all ':' with a space and create array
  array=( ${LINE//:/ } )

  # home is 5th element
  RIDE_USER_HOME=${array[4]}

  sed -i -e "s/^${RIDE_USER}:\([^:]*\):[0-9]*:[0-9]*/${RIDE_USER}:\1:${RIDE_USER_ID}:${RIDE_USER_GID}/"  /etc/passwd
  sed -i -e "s/^${RIDE_USER}:\([^:]*\):[0-9]*/${RIDE_USER}:\1:${RIDE_USER_GID}/"  /etc/group

  chown ${RIDE_USER_ID}:${RIDE_USER_GID} ${RIDE_USER_HOME}
fi
