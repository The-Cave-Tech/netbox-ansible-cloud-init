#!/bin/bash

# Name of the virtual machine
VM_NAME="node1"

SOURCE_IMAGE="/var/lib/libvirt/images/noble-server-cloudimg-amd64.img"
IMAGE="/var/lib/libvirt/images/$VM_NAME.img"
CLOUD_INIT="$PWD/$VM_NAME-cloud-init.yaml"
CLOUD_INIT_TEMPLATE="$PWD/cloud-init.yaml.j2"
#USER_PUBLIC_KEY=$(cat "/etc/ssh/ssh_host_ed25519_key.pub")
USER_PUBLIC_KEY=$(cat "$HOME/.ssh/id_ed25519.pub")

LVM_VG_NAME="ubuntu-vg"
LVM_LV_NAME="$VM_NAME"
LVM_SIZE="100G"

VM_RAM=32768
VM_VCPUS=8

echo $CLOUD_INIT_TEMPLATE
/usr/bin/python3 generate_cloud_init.py \
    --ssh_key "$USER_PUBLIC_KEY" \
    --template "$CLOUD_INIT_TEMPLATE" \
    --output "$CLOUD_INIT" \
    --vmname "$VM_NAME" 

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

lvremove -f "$LVM_VG_NAME/$LVM_LV_NAME"

lvcreate -L "$LVM_SIZE" -n "$LVM_LV_NAME" "$LVM_VG_NAME"
lvchange -a y "$LVM_VG_NAME/$LVM_LV_NAME"

qemu-img create -b  "$SOURCE_IMAGE" -f qcow2 -F qcow2 "$IMAGE" 10G

virt-install \
        --name $VM_NAME \
        --memory $VM_RAM \
        --vcpus $VM_VCPUS \
        --os-variant detect=on,name=ubuntu24.04 \
        --cloud-init user-data="$CLOUD_INIT" \
        --disk=size=10,backing_store="$IMAGE" \
        --disk path="/dev/$LVM_VG_NAME/$LVM_LV_NAME" \
        --network bridge=br0,model=virtio \
        --graphics vnc,listen=0.0.0.0 \
        --noautoconsole

