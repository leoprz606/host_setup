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
    echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" >> /root/.bashrc
else
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc
fi

# INITIAL SSH SETUP
sed -i 's/#PasswordAuthentication/PasswordAuthentication/g' /etc/ssh/sshd_config
systemctl restart ssh

# REMOTE WORKER NODE PRE ANSIBLE SETUP
useradd k8s  # No -m; we'll create the home dir manually
mkhomedir_helper k8s
chmod 755 /home/k8s
mkdir -m 700 /home/k8s/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCPDIvdriJ6SzP+F0v6xbvrfn1UmAqYS0j8E6EhYO847jOmNJa48afOiYonoH3Jnm/JVGkCepEmhIuMZmCLLfRlPFTRCv5n1WzTW1Zk9/zKqk/BNkeHS6bcG4x7Pr6QqxojWtgreMcMUGbS4ix7EqOimogN5VaQcntv8L/jh0RT0M6eNqiTB1OhvM9fiWIu9dYmz/Noe1OoEAbKn9suoQDEylWMsPRVpl/eM0JytcKuZ05ikcVLFgbYuFDWwdLp+DYIWuoNSahyDpufs770ZyrO99KuCvcLGbNv8PiCSyi59GIFmI2dG8tvmPMAJDU1XiWlyymJvswXdVoDcNokzLaF root@localhost.localdomain' >> /home/k8s/.ssh/authorized_keys
chown -R k8s:k8s /home/k8s  # Own entire home dir, including .ssh
chmod 600 /home/k8s/.ssh/authorized_keys
sed -i 's/#AllowTcpForwarding/AllowTcpForwarding/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication/#PasswordAuthentication/g' /etc/ssh/sshd_config
echo 'k8s     ALL=(ALL)       NOPASSWD: ALL' >> /etc/sudoers.d/k8s
chmod 440 /etc/sudoers.d/k8s
systemctl restart ssh

# LOCAL CONTROLLER PRE ANSIBLE SETUP
apt update -y
apt install -y telnet
apt install -y python3-pip
pip3 install ansible

echo 'alias k=kubectl' >> /root/.bashrc
echo 'cd /home/k8s/repositories' >> /root/.bashrc

# Reset unique identifiers

# Machine ID:
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id
systemd-machine-id-setup

# Update SSH Host Keys:
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
systemctl restart ssh

# Logs
truncate -s 0 /var/log/*.log
apt clean

reboot
