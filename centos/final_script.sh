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
cat <<EOT >> openshift_letsencrypt_install/inventory.ini

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

oc login https://console.$DOMAIN -u $USERNAME -p $PASSWORD
# Modify Openshift-infra for repair metrics problem
# More details for this issue and his solution here:
# https://github.com/openshift/origin-metrics/issues/429#issuecomment-418271287
#export HAWKULAR_CASSANDRA=$(oc get pods --all-namespaces --selector metrics-infra=hawkular-cassandra --no-headers -o custom-columns=name:.metadata.name)
#export HAWKULAR_METRICS=$(oc get pods --all-namespaces --selector metrics-infra=hawkular-metrics --no-headers -o custom-columns=name:.metadata.name)
#export HAWKULAR_METRICS_SCHEMA=$(oc get pods --all-namespaces --selector job-name=hawkular-metrics-schema --no-headers -o custom-columns=name:.metadata.name)
#export HEAPSTER=$(oc get pods --all-namespaces --selector metrics-infra=heapster --no-headers -o custom-columns=name:.metadata.name)
#export EDITOR=nano # Change by your favorite editor

# Replace all "docker.io/openshift/origin-metrics-cassandra:v3.10.0" values by
# "docker.io/openshift/origin-metrics-cassandra:v3.11.0" and save
#KUBE_EDITOR=$EDITOR oc edit pod/$HAWKULAR_CASSANDRA

# Replace all "docker.io/openshift/origin-metrics-hawkular-metrics:v3.10.0" values by
# "docker.io/openshift/origin-metrics-hawkular-metrics:v3.11.0" and save
#KUBE_EDITOR=$EDITOR oc edit pod/$HAWKULAR_METRICS

# Replace all "docker.io/openshift/origin-metrics-schema-installer:v3.10.0" values by
# "docker.io/alv91/origin-metrics-schema-installer:v3.10.0" and save
#KUBE_EDITOR=$EDITOR oc edit pod/$HAWKULAR_METRICS_SCHEMA

# Replace all "docker.io/openshift/origin-metrics-heapster:v3.10.0" values by
# "docker.io/openshift/origin-metrics-heapster:v3.11.0" and save
#KUBE_EDITOR=$EDITOR oc edit pod/$HEAPSTER


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
