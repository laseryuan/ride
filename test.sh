#!/usr/bin/env bash

bash /usr/local/bin/sshstart test
/usr/local/bin/sshyou test
/home/ride/.dotfiles/bash/.bashrc.d/.dockerfunc.sh test
python3 -m pytest ./mbuild/utils/build.py
