#!/usr/bin/env bash

/usr/local/bin/sshyou test
/home/ride/.dotfiles/bash/.bashrc.d/.dockerfunc.sh test
python3 -m pytest ./mbuild/utils/build.py
