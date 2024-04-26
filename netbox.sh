#!/bin/bash

# Name of the virtual machine
VM_NAME="netbox"

SOURCE_IMAGE="/var/lib/libvirt/images/jammy-server-cloudimg-amd64-disk-kvm.img"
IMAGE="/var/lib/libvirt/images/$VM_NAME.img"
CLOUD_INIT="$PWD/$VM_NAME-cloud-init.yaml"
CLOUD_INIT_TEMPLATE="cloud-init.yaml.j2"
USER_PUBLIC_KEY="/etc/ssh/ssh_host_ed25519_key.pub"

/usr/bin/python3 utility/generate_cloud_init.py \
    --key $USER_PUBLIC_KEY \
    --template $CLOUD_INIT_TEMPLATE \
    --output $CLOUD_INIT \
    --vmname $VM_NAME

# Check if the VM is running and shut it down
if virsh list --name | grep -q "$VM_NAME"; then
    echo "Shutting down $VM_NAME..."
    #virsh shutdown "$VM_NAME"
    virsh destroy  "$VM_NAME"
    # Wait for the VM to shut down
    while virsh list --name | grep -q "$VM_NAME"; do
        sleep 1
    done
    echo "$VM_NAME has been shut down."
else
    echo "$VM_NAME is not running or does not exist."
fi

# Delete the VM
if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "Deleting $VM_NAME..."
    virsh undefine "$VM_NAME" --remove-all-storage
    echo "$VM_NAME has been deleted."
else
    echo "No VM named $VM_NAME exists."
fi


if [ -f IMAGE ]; then
  rm IMAGE
fi

qemu-img create -b  "$SOURCE_IMAGE" -f qcow2 -F qcow2 "$IMAGE" 10G

virt-install \
        --name $VM_NAME \
        --memory 4096 \
        --vcpus 2\
        --os-variant detect=on,name=ubuntu22.10 \
        --cloud-init user-data="$CLOUD_INIT" \
        --disk=size=10,backing_store="$IMAGE" \
        --network bridge=br0,model=virtio \
        --graphics vnc,listen=0.0.0.0 \
        --noautoconsole