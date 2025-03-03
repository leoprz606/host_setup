#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Prompt user for hostname
read -p "Enter the new hostname: " new_hostname

# Validate input is not empty
if [ -z "$new_hostname" ]; then
    echo "Hostname cannot be empty. Aborting."
    exit 1
fi

# Set the hostname
hostnamectl set-hostname "$new_hostname"

# Add entry to /etc/hosts
echo "127.0.0.1   $new_hostname" >> /etc/hosts


# Check if "rke2" is in the hostname (case insensitive)
if echo "$new_hostname" | grep -iq "rke2"; then
    echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" >> /root/.bash_profile

else
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bash_profile
fi

# INTIAL SSH SETUP
sed -i 's/#PasswordAuthentication/PasswordAuthentication/g' /etc/ssh/sshd_config
systemctl restart sshd

# REMOTE WORKER NODE PRE ANSIBLE SETUP
useradd k8s
mkdir -m 400 /home/k8s/.ssh
chmod 755 /home/k8s
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCPDIvdriJ6SzP+F0v6xbvrfn1UmAqYS0j8E6EhYO847jOmNJa48afOiYonoH3Jnm/JVGkCepEmhIuMZmCLLfRlPFTRCv5n1WzTW1Zk9/zKqk/BNkeHS6bcG4x7Pr6QqxojWtgreMcMUGbS4ix7EqOimogN5VaQcntv8L/jh0RT0M6eNqiTB1OhvM9fiWIu9dYmz/Noe1OoEAbKn9suoQDEylWMsPRVpl/eM0JytcKuZ05ikcVLFgbYuFDWwdLp+DYIWuoNSahyDpufs770ZyrO99KuCvcLGbNv8PiCSyi59GIFmI2dG8tvmPMAJDU1XiWlyymJvswXdVoDcNokzLaF root@localhost.localdomain
' >> /home/k8s/.ssh/authorized_keys
chown -R k8s /home/k8s/.ssh
chmod 600 /home/k8s/.ssh/authorized_keys
chmod 700 /home/k8s/.ssh
sed -i 's/#AllowTcpForwarding/AllowTcpForwarding/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication/#PasswordAuthentication/g' /etc/ssh/sshd_config
#sed -i 's/# %wheel        ALL=(ALL)       NOPASSWD: ALL/%wheel        ALL=(ALL)       NOPASSWD: ALL/g' /etc/sudoers
echo 'k8s     ALL=(ALL)       NOPASSWD: ALL' >> /etc/sudoers
systemctl restart sshd
# LOCAL CONTROLLER PRE ANSIBLE SETUP
yum update -y
yum install telnet -y
yum install pip -y
pip install ansible

echo 'alias k=kubectl' >> /root/.bash_profile
echo 'cd /home/k8s/repositories' >> /root/.bash_profile

# Rest unique identifiers

# Machine ID:
rm -f /etc/machine-id
systemd-machine-id-setup

# Update SSH Host Keys::
rm /etc/ssh/ssh_host_*
ssh-keygen -A
systemctl restart sshd

# Logs
truncate -s 0 /var/log/*.log
dnf clean all

reboot