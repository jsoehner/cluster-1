#!/bin/bash
#
# Uncomment to see where the variables may fail
# ---------------------------------------------
#set -x
#
# Add your variables below
# ------------------------
# ON your management machine and with all nodes active
# and your docker configuration enabled for remote access
# Please be sure to setup your CA (consider mkcert --install)
#
# Globals
# -------
export NODE_VERSION=v1.26.0
export USER=jsoehner
export CAROOT=ssl/
export CLIENT_CERT=Jeffs-MacBook+1-client
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
mv ${NODE_HOSTNAME}.${DOMAIN_NAME}*.pem ssl/
scp ssl/rootCA.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?-key.pem ${USER}@${NODE_HOSTNAME}:~
rm -rf ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?*
#
# Create a new docker context and switch to the new context
# ---------------------------------------------------------
#
docker context create ${NODE_HOSTNAME}\
 --description "${NODE_HOSTNAME} context created"\
 --docker "host=tcp://${HUB_IP}:2376,ca=ssl/rootCA.pem,\
cert=ssl/${CLIENT_CERT}.pem,key=ssl/${CLIENT_CERT}-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config
# ---------------------
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
#
# Move files into position on node
# --------------------------------
#
scp ssl/${NODE_HOSTNAME}-openssl.cnf ${USER}@${NODE_HOSTNAME}:openssl.cnf
ssh -t ${USER}@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json ${USER}@${NODE_HOSTNAME}:~
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
# ----------------------------
ssh ${USER}@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh ${USER}@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh ${USER}@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh ${USER}@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
# -------------------------
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
# -------------------------------------------
#
cat <<EOF | kind create cluster --image=kindest/node:${NODE_VERSION} --name ${HUB_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${HUB_IP}
  apiServerPort: 6443
EOF
#
# Initialize the management hub
# -----------------------------
#
clusteradm init --wait --context ${CTX_HUB_CLUSTER}
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
mv -f ${NODE_HOSTNAME}.${DOMAIN_NAME}*.pem ssl/
scp ssl/rootCA.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?-key.pem ${USER}@${NODE_HOSTNAME}:~
rm -rf ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?*
#
# Create a new docker context and switch to the new context
# ---------------------------------------------------------
#
docker context create ${NODE_HOSTNAME}\
 --description "${NODE_HOSTNAME} context created"\
 --docker "host=tcp://${NODE_IP}:2376,ca=ssl/rootCA.pem,\
cert=ssl/${CLIENT_CERT}.pem,key=ssl/${CLIENT_CERT}-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config
# ---------------------
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
#
# Move files into position on node
# --------------------------------
#
scp ssl/${NODE_HOSTNAME}-openssl.cnf ${USER}@${NODE_HOSTNAME}:openssl.cnf
ssh -t ${USER}@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json ${USER}@${NODE_HOSTNAME}:~
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
# ----------------------------
#
ssh ${USER}@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh ${USER}@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh ${USER}@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh ${USER}@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
# -------------------------
#
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
# -------------------------------------------
#
cat <<EOF | kind create cluster --image=kindest/node:${NODE_VERSION} --name ${NODE_HOSTNAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${NODE_IP}
  apiServerPort: 6443
EOF
#
# Join this cluster to the management hub
# ---------------------------------------
#
export TOKEN=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep "token=" | cut -c 7-)
clusteradm join --hub-token ${TOKEN}\
 --hub-apiserver https://${HUB_IP}:6443 --wait\
 --cluster-name ${NODE_HOSTNAME} --context ${CTX_MANAGED_CLUSTER}
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
# Assuming you have already installed your CA into a sub directory called
# 'ssl' this part creates a daemon cert and adds the rootCA, docker daemon
# cert and key onto the docker host
#
mkcert ${NODE_HOSTNAME}.${DOMAIN_NAME} ${NODE_IP}
mv ${NODE_HOSTNAME}.${DOMAIN_NAME}*.pem ssl/
scp ssl/rootCA.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?-key.pem ${USER}@${NODE_HOSTNAME}:~
rm -rf ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?*
#
# Create a new docker context and switch to the new context
# ---------------------------------------------------------
#
docker context create ${NODE_HOSTNAME}\
 --description "${NODE_HOSTNAME} context created"\
 --docker "host=tcp://${NODE_IP}:2376,ca=ssl/rootCA.pem,\
cert=ssl/${CLIENT_CERT}.pem,key=ssl/${CLIENT_CERT}-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config for the node
# ----------------------------------
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
#
# Move files into position on node
# --------------------------------
#
scp ssl/${NODE_HOSTNAME}-openssl.cnf ${USER}@${NODE_HOSTNAME}:openssl.cnf
ssh -t ${USER}@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json ${USER}@${NODE_HOSTNAME}:~
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
# ----------------------------
#
ssh ${USER}@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh ${USER}@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh ${USER}@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh ${USER}@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
# -------------------------
#
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
# -------------------------------------------
#
cat <<EOF | kind create cluster --image=kindest/node:${NODE_VERSION} --name ${NODE_HOSTNAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${NODE_IP}
  apiServerPort: 6443
EOF
#
# Join this cluster to the management hub
# ---------------------------------------
#
export TOKEN=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep "token=" | cut -c 7-)
clusteradm join --hub-token ${TOKEN}\
 --hub-apiserver https://${HUB_IP}:6443 --wait\
 --cluster-name ${NODE_HOSTNAME} --context ${CTX_MANAGED_CLUSTER}
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
# Assuming you have already installed your CA into a sub directory called
# 'ssl' this part creates a daemon cert and adds the rootCA, docker daemon
# cert and key onto the docker host
#
mkcert ${NODE_HOSTNAME}.${DOMAIN_NAME} ${NODE_IP}
mv ${NODE_HOSTNAME}.${DOMAIN_NAME}*.pem ssl/
scp ssl/rootCA.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?.pem ${USER}@${NODE_HOSTNAME}:~
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?-key.pem ${USER}@${NODE_HOSTNAME}:~
rm -rf ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?*
#
# Create a new docker context and switch to the new context
# ---------------------------------------------------------
#
docker context create ${NODE_HOSTNAME}\
 --description "${NODE_HOSTNAME} context created"\
 --docker "host=tcp://${NODE_IP}:2376,ca=ssl/rootCA.pem,\
cert=ssl/${CLIENT_CERT}.pem,key=ssl/${CLIENT_CERT}-key.pem"
docker context use ${NODE_HOSTNAME}
#
# Create OpenSSL config
# ---------------------
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
#
# Move files into position on node
# --------------------------------
#
scp ssl/${NODE_HOSTNAME}-openssl.cnf ${USER}@${NODE_HOSTNAME}:openssl.cnf
ssh -t ${USER}@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem'
ssh ${USER}@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*'
scp ssl/daemon.json ${USER}@${NODE_HOSTNAME}:~
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json'
#
# Patch systemd for flag error
# ----------------------------
#
ssh ${USER}@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh ${USER}@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service'
ssh ${USER}@${NODE_HOSTNAME} 'sudo systemctl daemon-reload'
ssh ${USER}@${NODE_HOSTNAME} 'sudo service docker restart'
#
# Remove any stale clusters
# -------------------------
#
kind delete cluster --name $(kind get clusters 2>/dev/null)
#
# Create a remote kind cluster on remote host
# -------------------------------------------
#
cat <<EOF | kind create cluster --image=kindest/node:${NODE_VERSION} --name ${NODE_HOSTNAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${NODE_IP}
  apiServerPort: 6443
EOF
#
# Join this cluster to the management hub
# ---------------------------------------
#
export TOKEN=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep "token=" | cut -c 7-)
clusteradm join --hub-token ${TOKEN}\
 --hub-apiserver https://${HUB_IP}:6443 --wait\
 --cluster-name ${NODE_HOSTNAME} --context ${CTX_MANAGED_CLUSTER}
clusteradm accept --clusters ${NODE_HOSTNAME} --context ${CTX_HUB_CLUSTER}
#
# --------------------------------
# Add Application Management Addon
# --------------------------------
#
clusteradm install hub-addon --names application-manager --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names application-manager --clusters node1 --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names application-manager --clusters node2 --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names application-manager --clusters node3 --context ${CTX_HUB_CLUSTER}
#
# Set the deployment namespace
# ----------------------------
#
export HUB_NAMESPACE="open-cluster-management"
#
# Deploy the policy framework hub controllers
# -------------------------------------------
#
clusteradm install hub-addon --names governance-policy-framework --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names governance-policy-framework --clusters node1 --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names governance-policy-framework --clusters node2 --context ${CTX_HUB_CLUSTER}
clusteradm addon enable --names governance-policy-framework --clusters node3 --context ${CTX_HUB_CLUSTER}
#
# Deploy the configuration policy controller
# ------------------------------------------
#
clusteradm addon enable addon --names config-policy-controller --clusters node1 --context ${CTX_HUB_CLUSTER}
clusteradm addon enable addon --names config-policy-controller --clusters node2 --context ${CTX_HUB_CLUSTER}
clusteradm addon enable addon --names config-policy-controller --clusters node3 --context ${CTX_HUB_CLUSTER}
#
# Change to the Hub context
# -------------------------
#
kubectl config use-context ${CTX_HUB_CLUSTER}
kubectl apply -n default -f https://raw.githubusercontent.com/stolostron/policy-collection/main/community/CM-Configuration-Management/policy-pod-placement.yaml
kubectl patch -n default placement.cluster.open-cluster-management.io/placement-policy-pod --type=merge -p "{\"spec\":{\"predicates\":[{\"requiredClusterSelector\":{\"labelSelector\":{\"matchExpressions\":[]}}}]}}"
#
echo "Completed Successfully - please wait while the components are activated..."
#
sleep 100
clusteradm get addon --context ${CTX_HUB_CLUSTER}
