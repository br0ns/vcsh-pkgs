#!/bin/sh
cd "$(dirname "$(realpath "$0")")"
sudo pip install --upgrade -r pip.pkgs
sudo pip3 install --upgrade -r pip3.pkgs
