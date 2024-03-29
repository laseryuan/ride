#!/bin/bash
# vim: set noswapfile :

# credit: https://gist.github.com/renzok/29c9e5744f1dffa392cf

if [ -z "${RIDE_USER}" ]; then
  echo "We need RIDE_USER to be set!"; exit 100
fi

# if both not set we do not need to do anything
if [ -z "${HOST_USER_ID}" -a -z "${HOST_USER_GID}" ]; then
    echo "Nothing to do here." ; exit 0
fi

# if host user id is the same as ride  we do not need to do anything
if [[ ${HOST_USER_ID} == 1000 || ${HOST_USER_GID} == 1000} ]]; then
    # echo "Ride has the Same user id as host." >> /tmp/ride.log
    exit 0
fi

if [[ ${HOST_USER_NAME} == "root" || ${HOST_USER_ID} == 0} ]]; then
  echo "Changing root home directory ..."
  sed -i -e '/root/s!\(.*:\).*:\(.*\)!\1/home/ride:\2!' /etc/passwd
  chown -R root:root /home/ride/.ssh
else
  echo "Remapping user and home directory ..."
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

  chown ${RIDE_USER_ID}:${RIDE_USER_GID} ${RIDE_USER_HOME} /tmp/ride.log
fi
