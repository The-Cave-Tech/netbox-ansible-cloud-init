#!/bin/bash

# Update package lists
sudo apt update

# Install Ansible
sudo apt install -y ansible

# Install Python and Pip3
sudo apt install -y python3 python3-pip

# Upgrade Pip to the latest version
sudo -H pip3 install --upgrade pip

# Install Ansible Generator (assuming it's available via Pip)
sudo -H pip3 install ansible-generator

# Set Python and Pip alternatives to the latest versions
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

echo "Ansible, Python, Pip3, and Ansible Generator installed successfully."
echo "Python and Pip3 are set as the default versions."
