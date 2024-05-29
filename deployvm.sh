#!/bin/bash

PREFIX_LENGTH="24"
DEFAULT_GATEWAY="10.2.100.1"
DNS_SERVER=""
DOMAIN_NAME="netbox.local"

# Use IP route to find the default gateway
DEFAULT_GATEWAY=$(ip route | grep default | awk '{print $3}')

USERNAME="user"
USER_PRIVATE_KEY_FILE="/etc/ssh/ssh_host_ed25519_key"
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

    SERIAL_NAMED_PIPE="/tmp/$VM_NAME-serial.pipe"

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

    if [ -e "$SERIAL_NAMED_PIPE" ]; then
        echo "Named pipe exists, deleting"
        rm -f "$SERIAL_NAMED_PIPE"
    fi
}

create_vm() {
    VM_NAME="$1"
    IP_ADDRESS="$2"
    IPv6_ADDRESS="$3"

    SERIAL_NAMED_PIPE="/tmp/$VM_NAME-serial.pipe"

    echo "Creating $VM_NAME"

    CLOUD_INIT="$PWD/$VM_NAME-cloud-init.yaml"
    IMAGE="/var/lib/libvirt/images/$VM_NAME.img"
    CLOUD_INIT_TEMPLATE="$PWD/cloud-init.yaml.j2"
    NETPLAN_PATH="/tmp/$VM_NAME.yaml"
    LVM_LV_NAME="$VM_NAME"
    VM_XML_FILENAME="$PWD/$VM_NAME.xml"
    
    echo $CLOUD_INIT_TEMPLATE
    /usr/bin/python3 utility/generate_cloud_init.py \
        --ssh_key "$USER_PUBLIC_KEY" \
        --template "$CLOUD_INIT_TEMPLATE" \
        --output "$CLOUD_INIT" \
        --vmname "$VM_NAME"

NETPLAN="network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      addresses: 
      - $IP_ADDRESS/$PREFIX_LENGTH
      - $IPv6_ADDRESS/64
      routes: 
      - to: default
        via: $DEFAULT_GATEWAY
      nameservers:
        addresses:
        - $DNS_SERVER
        search:
        - $DOMAIN_NAME
"

    echo "$NETPLAN"
    echo "$NETPLAN" > $NETPLAN_PATH

    lvcreate -L "$LVM_SIZE" -n "$LVM_LV_NAME" "$LVM_VG_NAME"
    lvchange -a y "$LVM_VG_NAME/$LVM_LV_NAME"

    qemu-img create -b  "$SOURCE_IMAGE" -f qcow2 -F qcow2 "$IMAGE" ${VM_DISK_SIZE}G

    # Create the serial named pipe
    if [ ! -p "$SERIAL_NAMED_PIPE" ]; then
        mkfifo "$SERIAL_NAMED_PIPE"
        chmod 666 "$SERIAL_NAMED_PIPE"
    fi

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
        --noautoconsole \
        --serial pty \
        --serial file,path="$SERIAL_NAMED_PIPE"    
}

if ! command -v dig &> /dev/null
then
    sudo apt-get install -y dnsutils
fi

function get_dns_server {
    # Run the resolvectl dns command and save its output
    output=$(resolvectl dns)

    # Split the output into lines
    IFS=$'\n' lines=($output)

    # Iterate over the lines
    for line in "${lines[@]}"; do
        # If the line does not start with "Global:", it's a DNS server connected to an interface
        if [[ $line != Global:* ]]; then
            # Split the line into link label and address
            IFS=':' read -ra parts <<< "$line"
            
            # Extract the DNS server address
            dns_server=${parts[1]}
            
            # If the DNS server address is not empty, print it and return
            if [[ ! -z "$dns_server" ]]; then
                echo $dns_server
                return 0
            fi
        fi
    done

    # If no DNS server was found, print an error message
    echo "No DNS server found connected to an interface."
    return 1
}

# Query and remove the serial device with device type "file" from a VM
remove_serial_device() {
    local vm_name="$1"
    local device_alias

    virsh dumpxml $vm_name > /tmp/$vm_name-serial.xml

    sed -i "/<serial type='file'>/,/<\/serial>/d" /tmp/$vm_name-serial.xml

    virsh define /tmp/$vm_name-serial.xml

    rm -f /tmp/$vm_name-serial.xml
}


# Get the DNS server address
DNS_SERVER=$(get_dns_server)
echo $DNS_SERVER

# If the DNS server address could not be found, exit the script
if [ $? -ne 0 ]; then
    exit 1
fi

nodes=("node1" "node2" "node3")

# Destroy VMs
for node in "${nodes[@]}"; do
    destroy_vm "$node"
done

# Create VMs
for node in "${nodes[@]}"; do
    ipv4_address=$(dig +short "$node.netbox.local")
    ipv6_address=$(nslookup -query=AAAA "$node.netbox.local" | grep '^Address: ' | cut -d ' ' -f 2)
    create_vm "$node" "$ipv4_address" "$ipv6_address"
    echo "VM $VM_NAME created with IP $ipv4_address and IPv6 $ipv6_address"
done

echo "Waiting for VMs to be ready..."
# Loop until the contents of the serial named pipes are all "READY"
for node in "${nodes[@]}"; do
    SERIAL_NAMED_PIPE="/tmp/$node-serial.pipe"
    NODE_READY="false"

    while [ "$NODE_READY" != "true" ]; do
        file_contents=$(<"$SERIAL_NAMED_PIPE")
        if echo "$file_contents" | grep -q "READY" ; then
            NODE_READY="true"
            echo "$node is ready."
        else
            sleep 1
        fi
    done
done

# Shutdown all vms and wait until they are all down
for node in "${nodes[@]}"; do
    virsh shutdown "$node"
done

for node in "${nodes[@]}"; do
    while virsh list --name | grep -q "$node"; do
        sleep 1
    done
done

echo "All VMs have been shut down."

# Using virsh remove the serial ports connected to the names pipes from the VMs
for node in "${nodes[@]}"; do
    SERIAL_NAMED_PIPE="/tmp/$node-serial.pipe"

    remove_serial_device "$node"

    rm -f "$SERIAL_NAMED_PIPE"
done

echo "All serial ports have been removed."

# Start all vms
for node in "${nodes[@]}"; do
    virsh start "$node"
done

echo "All VMs have been started."

# Wait for the VMs to be ready by attempting to log in via SSH using the private key
for node in "${nodes[@]}"; do
    echo "ssh -o \"StrictHostKeyChecking no\" -i \"$USER_PRIVATE_KEY_FILE\" \"$USERNAME@$node.$DOMAIN_NAME\" \"echo \\\"READY\\\"\""

    while ! ssh -o "StrictHostKeyChecking no" -i "$USER_PRIVATE_KEY_FILE" "$USERNAME@$node.$DOMAIN_NAME" "echo 'READY'" 2>/dev/null; do
        sleep 1
    done
    echo "$node is ready."
done