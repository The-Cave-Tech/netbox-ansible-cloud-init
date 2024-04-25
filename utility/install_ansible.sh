#!/bin/bash

# Update the system
sudo apt update

# Install software-properties-common
sudo apt install software-properties-common

# Add the Ansible PPA
sudo apt-add-repository --yes --update ppa:ansible/ansible

# Install Ansible
sudo apt install ansible
