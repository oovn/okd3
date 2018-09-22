#!/bin/sh

#####################
# First Configuration
#####################

# Update OS
yum update -y

# Add Package Requirements
yum install -y cronie epel-release git nano setroubleshoot

# Set SELinux to "enforcing"
sed -i 's/SELINUX=disabled.*/SELINUX=enforcing/' /etc/selinux/config
touch /.autorelabel

sealert -a /var/log/audit/audit.log | cat 
# Set SELinux Rules if previous command get alert output

reboot
