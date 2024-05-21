#!/bin/bash

PREFIX_LENGTH="24"
DEFAULT_GATEWAY="10.2.100.1"
DNS_SERVER="10.2.100.2"
DOMAIN_NAME="netbox.local"

USER_PUBLIC_KEY=$(cat "/etc/ssh/ssh_host_ed25519_key.pub")

SOURCE_IMAGE="/var/lib/libvirt/images/noble-server-cloudimg-amd64.img"

LVM_VG_NAME="ubuntu-vg"
LVM_SIZE="30G"

VM_RAM=4096
VM_VCPUS=3
VM_DISK_SIZE=32

destroy_vm() {
    VM_NAME="$1"

    echo "Destroying $VM_NAME"

    sudo ssh-keygen -f "/root/.ssh/known_hosts" -R "$VM_NAME.$DOMAIN_NAME"

    IMAGE="/var/lib/libvirt/images/$VM_NAME.img"
    LVM_LV_NAME="$VM_NAME"

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

    wipefs -a "/dev/$LVM_VG_NAME/$LVM_LV_NAME"
    lvremove -f "$LVM_VG_NAME/$LVM_LV_NAME"
}

create_vm() {
    VM_NAME="$1"
    IP_ADDRESS="$2"

    echo "Destroying $VM_NAME"

    CLOUD_INIT="$PWD/$VM_NAME-cloud-init.yaml"
    IMAGE="/var/lib/libvirt/images/$VM_NAME.img"
    CLOUD_INIT_TEMPLATE="$PWD/cloud-init.yaml.j2"
    NETPLAN_PATH="/tmp/$VM_NAME.yaml"
    LVM_LV_NAME="$VM_NAME"

    
    echo $CLOUD_INIT_TEMPLATE
    /usr/bin/python3 utility/generate_cloud_init.py \
        --ssh_key "$USER_PUBLIC_KEY" \
        --template "$CLOUD_INIT_TEMPLATE" \
        --output "$CLOUD_INIT" \
        --vmname "$VM_NAME"

    cat <<EOF 
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      addresses: 
      - $IP_ADDRESS/$PREFIX_LENGTH
      routes: 
      - to: default
        via: $DEFAULT_GATEWAY
      nameservers:
        addresses:
        - $DNS_SERVER
        search:
        - $DOMAIN_NAME
EOF


    # Create the Netplan configuration file
    cat <<EOF | sudo tee "$NETPLAN_PATH" > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      addresses: 
      - $IP_ADDRESS/$PREFIX_LENGTH
      routes: 
      - to: default
        via: $DEFAULT_GATEWAY
      nameservers:
        addresses:
        - $DNS_SERVER
        search:
        - $DOMAIN_NAME
EOF

    lvcreate -L "$LVM_SIZE" -n "$LVM_LV_NAME" "$LVM_VG_NAME"
    lvchange -a y "$LVM_VG_NAME/$LVM_LV_NAME"

    qemu-img create -b  "$SOURCE_IMAGE" -f qcow2 -F qcow2 "$IMAGE" ${VM_DISK_SIZE}G

    virt-install \
            --name $VM_NAME \
            --memory $VM_RAM \
            --vcpus $VM_VCPUS \
            --os-variant detect=on,name=ubuntu24.04 \
            --cloud-init user-data="$CLOUD_INIT",network-config="$NETPLAN_PATH" \
            --disk=size=$VM_DISK_SIZE,backing_store="$IMAGE" \
            --disk path="/dev/$LVM_VG_NAME/$LVM_LV_NAME" \
            --network bridge=br0,model=virtio \
            --graphics vnc,listen=0.0.0.0 \
            --noautoconsole
}

destroy_vm "node1"
destroy_vm "node2"
destroy_vm "node3"
create_vm "node1" "$(dig +short node1.netbox.local)"
create_vm "node2" "$(dig +short node2.netbox.local)"
create_vm "node3" "$(dig +short node3.netbox.local)"
