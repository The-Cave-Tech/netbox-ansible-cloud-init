#!/bin/bash

# Update the system
sudo apt update

# Install software-properties-common
sudo apt install software-properties-common -y

# Add Ansible PPA
sudo add-apt-repository --yes --update ppa:ansible/ansible

# Install Ansible and Git
sudo apt install ansible git -y

# Create a temporary directory
temp_dir=$(mktemp -d -t ci-XXXXXXXXXX -p /tmp)

# Clone the GitHub repository into the temporary directory
git clone https://github.com/darrenstarr/cloud-init-ansible.git $temp_dir

# Run the Ansible playbook
ansible-playbook $temp_dir/netbox.yml

# Verify the installation
ansible --version
