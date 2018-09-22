#!/bin/sh

#####################
# Set Constants
#####################
export DOMAIN=mydomain.com
export USERNAME=myusername
export PASSWORD=mypassword
export MAIL=myaddress@email.com


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
                 -d $DOMAIN \
                 -d *.$DOMAIN \
                 -d *.apps.$DOMAIN \

## Add Entries on your Host DNS Zone Editor
## Ex: 
##     Name: _acme-challenge.yourdomain.com | Type: TXT | Data: xjPMg-I6BokgUVOyIN3NJlIqbc9xGXUzyQE98dPdt1E
#####

## Modify inventory.ini 
# Declare usage of Custom Certificate
# Configure Custom Certificates for the Web Console or CLI => Doesn't Work for CLI
# Configure a Custom Master Host Certificate
# Configure a Custom Wildcard Certificate for the Default Router => Doesn't Work
# Configure a Custom Certificate for the Image Registry 
## See here for more explanation: https://docs.okd.io/latest/install_config/certificate_customization.html
cat <<EOT >> inventory.ini

openshift_master_overwrite_named_certificates=true

openshift_master_cluster_hostname=console-internal.${DOMAIN}
openshift_master_cluster_public_hostname=console.${DOMAIN}

openshift_master_named_certificates=[{"certfile": "/etc/letsencrypt/live/${DOMAIN}/cert.pem", "keyfile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem", "names": ["console.${DOMAIN}"]}]

openshift_hosted_router_certificate={"certfile": "/etc/letsencrypt/live/${DOMAIN}/cert.pem", "keyfile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem", "cafile": "/etc/letsencrypt/live/${DOMAIN}/chain.pem"}

openshift_hosted_registry_routehost=registry.apps.${DOMAIN}
openshift_hosted_registry_routecertificates={"certfile": "/etc/letsencrypt/live/${DOMAIN}/cert.pem", "keyfile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem", "cafile": "/etc/letsencrypt/live/${DOMAIN}/chain.pem"}
openshift_hosted_registry_routetermination=reencrypt
EOT

# Add Cron Task to renew certificate
echo "@monthly  certbot renew --pre-hook=\"oc scale --replicas=0 dc router\" --post-hook=\"oc scale --replicas=1 dc router\"" > certbotcron
crontab certbotcron
rm certbotcron


#####################
# Install OpenShift
#####################
# Clone Repo Git for OpenShift Installation & get to workdir
git clone https://github.com/gshipley/installcentos.git
cd installcentos
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
