# NetBox via Ansible and cloud-init

This code is a proof of concept to install NetBox into a kvm virtual machine entirely using cloud-init and Ansible.

There's still much work to do, but let's see where this takes us.


Creating a password hash for the cloud init

```bash
echo 'Whatever' | mkpasswd -m sha-512 -s
```