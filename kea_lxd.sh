#!/bin/bash

# Name of container
CONTAINER_NAME="kea"

SOURCE_IMAGE="/var/lib/libvirt/images/jammy-server-cloudimg-amd64-disk-kvm.img"
CLOUD_INIT="$PWD/$VM_NAME-cloud-init.yaml"
CLOUD_INIT_TEMPLATE="$PWD/cloud-init.yaml.j2"
USER_PUBLIC_KEY=$(cat "/etc/ssh/ssh_host_ed25519_key.pub")

/usr/bin/python3 utility/generate_cloud_init.py \
    --ssh_key "$USER_PUBLIC_KEY" \
    --template $CLOUD_INIT_TEMPLATE \
    --output $CLOUD_INIT \
    --vmname $VM_NAME

lxc launch ubuntu:22.04 $CONTAINER_NAME  -p default --config=user.user-data="$CLOUD_INIT"