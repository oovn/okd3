#!/bin/sh

#####################
# Set Constants
#####################
export DOMAIN=vn.lamit.win
#export USERNAME=myusername
#export PASSWORD=mypassword
export MAIL=amit@lamit.win


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

## Add Entries on your Host DNS Zone Editor
## Ex: 
##     Name: _acme-challenge.yourdomain.com | Type: TXT | Data: xjPMg-I6BokgUVOyIN3NJlIqbc9xGXUzyQE98dPdt1E
#####

# Add Cron Task to renew certificate
echo "@monthly  certbot renew --pre-hook=\"oc scale --replicas=0 dc router\" --post-hook=\"oc scale --replicas=1 dc router\"" > certbotcron
crontab certbotcron
rm certbotcron


#####################
# Install OpenShift
#####################
# Clone Repo Git for OpenShift Installation & get to workdir
#git clone https://github.com/oovn/oo311.git

# Replace install-openshift.sh
#mv -f install-openshift.sh installcentos/install-openshift.sh

# Install
#cd installcentos
chmod u+x install-openshift.sh
./install-openshift.sh


#####################
# Final Configuration
#####################

# Setup User
#adduser $USERNAME
#passwd $USERNAME
#usermod -aG wheel $USERNAME

# Add User to Docker Group
#groupadd docker
#gpasswd -a $USERNAME docker

# Configure SSH
#sed -i 's/#PermitRootLogin yes.*/PermitRootLogin no/' /etc/ssh/sshd_config
#echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config
#systemctl restart sshd

# Necessary for HTTPS to be functional
reboot
