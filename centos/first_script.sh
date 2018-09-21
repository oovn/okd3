#!/bin/sh

#####################
# First Configuration
#####################

# Update OS
yum update -y

# Add Package Requirements
yum install -y cronie epel-release git nano setroubleshoot

# Set SELinux to "enforcing"
sed -i 's/SELINUX=permissive.*/SELINUX=enforcing/' /etc/selinux/config
touch /.autorelabel

# Set SELinux Rules if you have problem with SELinux (SSH & SystemD)
#ausearch -c 'systemd' --raw | audit2allow -M my-systemd
#semodule -i my-systemd.pp
#ausearch -c 'sshd' --raw | audit2allow -M my-sshd
#semodule -i my-sshd.pp

# Clone Repo Git for OpenShift Installation & get to workdir
git clone https://github.com/gshipley/installcentos.git
cd installcentos

reboot