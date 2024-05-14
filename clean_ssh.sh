#!/bin/bash

# For nodes node1.netbox.local, node2.netbox.local, node3.netbox.local remove all ssh known hosts
for i in 1 2 3
do
  ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "node$i.netbox.local"
done

# For the same nodes, get the new fingerprints and update the known hosts file
for i in 1 2 3
do
  ssh-keyscan -H "node$i.netbox.local" >> ${HOME}/.ssh/known_hosts
done