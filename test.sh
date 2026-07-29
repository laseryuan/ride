#!/usr/bin/env bash

bash /usr/local/bin/sshstart test
/usr/local/bin/sshyou test
bash /usr/local/bin/ride.sh test
bash -n /usr/local/bin/ride-gpg-check
bash -n /usr/local/bin/link-host-gnupg-home
/home/ride/.dotfiles/bash/.bashrc.d/.dockerfunc.sh test

python3 -m pytest ./mbuild/utils/build.py
rm -rf /home/ride/mbuild/build
