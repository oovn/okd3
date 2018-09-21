#!/bin/sh

#####################
# Set Constants
#####################
export DOMAIN=mydomain.com
export USERNAME=myusername
export PASSWORD=mypassword
export MAIL=myaddress@email.com
export VERSION=3.10
export API_PORT=8443
export IP=$(curl -s ipinfo.io/ip)


#####################
# SSL Setup
#####################
# Enabled EPEL Repo
sed -i '6 s/^.*$/enabled=1/' /etc/yum.repos.d/epel.repo

# Install CertBot
yum install -y certbot

# Configure Let's Encrypt certificate
certbot certonly --manual \
                 --preferred-challenges dns \
                 --email $MAIL \
                 --server https://acme-v02.api.letsencrypt.org/directory \
                 --agree-tos \
                 -d *.$DOMAIN \
                 -d $DOMAIN

# Add Entries on your Host DNS Zone Editor
# Ex: 
#     Name: _acme-challenge.yourdomain.com | Type: TXT | Data: xjPMg-I6BokgUVOyIN3NJlIqbc9xGXUzyQE98dPdt1E

# Modify inventory.ini
echo "openshift_master_overwrite_named_certificates=true" >> ./inventory.ini
echo "openshift_master_named_certificates=[{\"certfile\": \"/etc/letsencrypt/live/${DOMAIN}/fullchain.pem\", \"keyfile\": \"/etc/letsencrypt/live/${DOMAIN}/privkey.pem\", \"names\": [\"console.${DOMAIN}\"]}]" >> ./inventory.ini
echo "openshift_hosted_router_certificate={\"certfile\": \"/etc/letsencrypt/live/${DOMAIN}.com/cert.pem\", \"keyfile\": \"/etc/letsencrypt/live/${DOMAIN}/privkey.pem\"}" >> ./inventory.ini
# If you don't use a certificate without wildcards, you need to replace the last command by:
# echo "openshift_master_named_certificates=[{\"certfile\": \"/etc/letsencrypt/live/console.${DOMAIN}/cert.pem\", \"keyfile\": \"/etc/letsencrypt/live/console.${DOMAIN}/privkey.pem\", \"names\": [\"console.${DOMAIN}\"]}]" >> ./inventory.ini


# Add Cron Task to renew certificate
echo "@monthly  certbot renew --pre-hook=\"oc scale --replicas=0 dc router\" --post-hook=\"oc scale --replicas=1 dc router\"" > certbotcron
crontab certbotcron
rm certbotcron


#####################
# Install OpenShift
#####################
./install-openshift.sh


#####################
# Final Configuration
#####################

# Setup User
adduser $USERNAME
passwd $USERNAME
usermod -aG wheel $USERNAME

# Add User to Docker Group
groupadd docker
gpasswd -a $USERNAME docker

# Configure SSH
sed -i 's/#PermitRootLogin yes.*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config
systemctl restart sshd

reboot
