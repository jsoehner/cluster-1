#!/bin/bash
#
#set -x
#
# Add your variables below
#
# ON your management machine and with all nodes active
# and your docker configuration enabled for remote access
# Please be sure to setup your CA (consider mkcert)
#
# Globals
# -------
export CAROOT=ssl/
export HUB_IP=192.168.100.110
export HUB_NAME=master
export DOMAIN_NAME=jsigroup.local
export CTX_HUB_CLUSTER=kind-${HUB_NAME}
#
# TODO: Need to modify script for domain name
#
# ------------------------------
# Create a connection to the hub
# ------------------------------
#
export NODE_HOSTNAME=cluster1
#
# Assuming you have already installed your CA into a sub directory called
# 'ssl' this part creates a daemon cert and adds the rootCA, docker daemon
# cert and key onto the docker host
#
mkcert ${NODE_HOSTNAME}.${DOMAIN_NAME} ${HUB_IP}
scp ssl/rootCA.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1-key.pem jsoehner@${NODE_HOSTNAME}:~
#
# Create a new docker context
# and switch to the new context
#
docker context create ${NODE_HOSTNAME} --description "${NODE_HOSTNAME} context created" --docker "host=tcp://${HUB_IP}:2376,ca=ssl/rootCA.pem,cert=./Jeffs-MacBook+1-client.pem,key=./Jeffs-MacBook+1-client-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config
#
tee ssl/${NODE_HOSTNAME}-openssl.cnf <<EOF
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]   
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names
    
    [alt_names]
    DNS.1 = ${NODE_HOSTNAME}
    DNS.2 = ${NODE_HOSTNAME}.${DOMAIN_NAME}
    IP.1 = 127.0.0.1
    IP.2 = ${HUB_IP}
EOF
scp ssl/${NODE_HOSTNAME}-openssl.cnf jsoehner@${NODE_HOSTNAME}:openssl.cnf
ssh -t jsoehner@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json jsoehner@${NODE_HOSTNAME}:~
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
ssh jsoehner@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh jsoehner@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh jsoehner@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh jsoehner@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
#
cat <<EOF | kind create cluster --image=kindest/node:v1.26.0 --name ${HUB_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${HUB_IP}
  apiServerPort: 6443
EOF
#
# Initialize the management hub
#
clusteradm init --wait --context ${CTX_HUB_CLUSTER}
#
#export TOKEN=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep "token=" | cut -c 7-)
#
# --------------------------------
# Create a connection to the Node1
# --------------------------------
#
export NODE_HOSTNAME=node1
export NODE_IP=192.168.100.111
export CTX_MANAGED_CLUSTER=kind-${NODE_HOSTNAME}
#
# Assuming you have already installed your CA into a sub directory
# called 'ssl' this part creates a daemon cert and adds the rootCA,
# docker daemon cert and key onto the docker host
#
mkcert ${NODE_HOSTNAME}.${DOMAIN_NAME} ${NODE_IP}
scp ssl/rootCA.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1-key.pem jsoehner@${NODE_HOSTNAME}:~
#
# Create a new docker context
# and switch to the new context
#
docker context create ${NODE_HOSTNAME} --description "${NODE_HOSTNAME} context created" --docker "host=tcp://${NODE_IP}:2376,ca=ssl/rootCA.pem,cert=./Jeffs-MacBook+1-client.pem,key=./Jeffs-MacBook+1-client-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config
#
tee ssl/${NODE_HOSTNAME}-openssl.cnf <<EOF
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]   
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names
    
    [alt_names]
    DNS.1 = ${NODE_HOSTNAME}
    DNS.2 = ${NODE_HOSTNAME}.${DOMAIN_NAME}
    IP.1 = 127.0.0.1
    IP.2 = ${NODE_IP}
EOF
scp ssl/${NODE_HOSTNAME}-openssl.cnf jsoehner@${NODE_HOSTNAME}:openssl.cnf
ssh -t jsoehner@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json jsoehner@${NODE_HOSTNAME}:~
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
ssh jsoehner@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh jsoehner@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh jsoehner@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh jsoehner@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
#
cat <<EOF | kind create cluster --image=kindest/node:v1.26.0 --name ${NODE_HOSTNAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${NODE_IP}
  apiServerPort: 6443
EOF
#
# Join this cluster to the management hub
#
export TOKEN=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep "token=" | cut -c 7-)
clusteradm join --hub-token ${TOKEN} --hub-apiserver https://${HUB_IP}:6443 --wait --cluster-name ${NODE_HOSTNAME} --context ${CTX_MANAGED_CLUSTER}
clusteradm accept --clusters ${NODE_HOSTNAME} --context ${CTX_HUB_CLUSTER}
#
# ---------------------------------
# Create a connection to the Node 2
# ---------------------------------
#
export NODE_HOSTNAME=node2
export NODE_IP=192.168.100.112
export CTX_MANAGED_CLUSTER=kind-${NODE_HOSTNAME}
#
# Assuming you have already installed
# your CA into a sub directory called
# 'ssl' this part creates a daemon cert
# and adds the rootCA, docker daemon
# cert and key onto the docker host
#
mkcert ${NODE_HOSTNAME}.${DOMAIN_NAME} ${NODE_IP}
scp ssl/rootCA.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1-key.pem jsoehner@${NODE_HOSTNAME}:~
#
# Create a new docker context
# and switch to the new context
#
docker context create ${NODE_HOSTNAME} --description "${NODE_HOSTNAME} context created" --docker "host=tcp://${NODE_IP}:2376,ca=ssl/rootCA.pem,cert=./Jeffs-MacBook+1-client.pem,key=./Jeffs-MacBook+1-client-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config
#
tee ssl/${NODE_HOSTNAME}-openssl.cnf <<EOF
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]   
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names
    
    [alt_names]
    DNS.1 = ${NODE_HOSTNAME}
    DNS.2 = ${NODE_HOSTNAME}.${DOMAIN_NAME}
    IP.1 = 127.0.0.1
    IP.2 = ${NODE_IP}
EOF
scp ssl/${NODE_HOSTNAME}-openssl.cnf jsoehner@${NODE_HOSTNAME}:openssl.cnf
ssh -t jsoehner@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json jsoehner@${NODE_HOSTNAME}:~
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
ssh jsoehner@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh jsoehner@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh jsoehner@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh jsoehner@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
#
cat <<EOF | kind create cluster --image=kindest/node:v1.26.0 --name ${NODE_HOSTNAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${NODE_IP}
  apiServerPort: 6443
EOF
#
# Join this cluster to the management hub
#
export TOKEN=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep "token=" | cut -c 7-)
clusteradm join --hub-token ${TOKEN} --hub-apiserver https://${HUB_IP}:6443 --wait --cluster-name ${NODE_HOSTNAME} --context ${CTX_MANAGED_CLUSTER}
clusteradm accept --clusters ${NODE_HOSTNAME} --context ${CTX_HUB_CLUSTER}
#
# --------------------------------
# Create a connection to the Node3
# --------------------------------
#
export NODE_HOSTNAME=node3
export NODE_IP=192.168.100.113
export CTX_MANAGED_CLUSTER=kind-${NODE_HOSTNAME}
#
# Assuming you have already installed
# your CA into a sub directory called
# 'ssl' this part creates a daemon cert
# and adds the rootCA, docker daemon
# cert and key onto the docker host
#
mkcert ${NODE_HOSTNAME}.${DOMAIN_NAME} ${NODE_IP}
scp ssl/rootCA.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1.pem jsoehner@${NODE_HOSTNAME}:~
scp ${NODE_HOSTNAME}.${DOMAIN_NAME}+1-key.pem jsoehner@${NODE_HOSTNAME}:~
#
# Create a new docker context
# and switch to the new context
#
docker context create ${NODE_HOSTNAME} --description "${NODE_HOSTNAME} context created" --docker "host=tcp://${NODE_IP}:2376,ca=ssl/rootCA.pem,cert=./Jeffs-MacBook+1-client.pem,key=./Jeffs-MacBook+1-client-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config
#
tee ssl/${NODE_HOSTNAME}-openssl.cnf <<EOF
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]   
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names
    
    [alt_names]
    DNS.1 = ${NODE_HOSTNAME}
    DNS.2 = ${NODE_HOSTNAME}.${DOMAIN_NAME}
    IP.1 = 127.0.0.1
    IP.2 = ${NODE_IP}
EOF
scp ssl/${NODE_HOSTNAME}-openssl.cnf jsoehner@${NODE_HOSTNAME}:openssl.cnf
ssh -t jsoehner@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh jsoehner@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json jsoehner@${NODE_HOSTNAME}:~
ssh jsoehner@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
ssh jsoehner@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh jsoehner@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh jsoehner@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh jsoehner@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
#
cat <<EOF | kind create cluster --image=kindest/node:v1.26.0 --name ${NODE_HOSTNAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${NODE_IP}
  apiServerPort: 6443
EOF
#
# Join this cluster to the management hub
#
export TOKEN=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep "token=" | cut -c 7-)
clusteradm join --hub-token ${TOKEN} --hub-apiserver https://${HUB_IP}:6443 --wait --cluster-name ${NODE_HOSTNAME} --context ${CTX_MANAGED_CLUSTER}
clusteradm accept --clusters ${NODE_HOSTNAME} --context ${CTX_HUB_CLUSTER}
#
# Add Application Management Addon
# --------------------------------
#
clusteradm install hub-addon --names application-manager --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names application-manager --clusters node1,node2,node3 --context ${CTX_HUB_CLUSTER}
#
# Set the deployment namespace
export HUB_NAMESPACE="open-cluster-management"
#
# Deploy the policy framework hub controllers
# -------------------------------------------
#
clusteradm install hub-addon --names governance-policy-framework --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names governance-policy-framework --clusters node1,node2,node3 --context ${CTX_HUB_CLUSTER}
#
# Deploy the configuration policy controller
# ------------------------------------------
#
clusteradm addon enable addon --names config-policy-controller --clusters node1,node2,node3 --context ${CTX_HUB_CLUSTER}
#
echo "Completed Successfully"
#
clusteradm get clusters --context ${CTX_HUB_CLUSTER}