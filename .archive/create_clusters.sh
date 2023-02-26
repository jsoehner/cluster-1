#!/bin/bash
#
set -x
#
# Add your variables below
#
# ON your management machine and with all nodes active
# and your docker configuration enabled for remote access
#
# Create a connection to the hub
#
export NODE_NAME=cluster1
export HUB_NAME=master
export IP=192.168.100.110
export DOCKER_PORT=2376
export DOCKER_TLS_VERIFY=1
export DOCKER_HOST=tcp://${IP}:${DOCKER_PORT}
export CTX_HUB_CLUSTER=kind-${HUB_NAME}
#
# Make Certificate Authority
#
mkdir -p ssl
openssl genrsa -out ssl/ca-key.pem 4096
openssl req -x509 -new -nodes -key ssl/ca-key.pem -days 3650 -out ssl/ca.pem -subj '/CN=docker-CA'
#
# Create certs on each node to connect to cluster
openssl genrsa -out ssl/${NODE_NAME}-client-key.pem 2048
openssl req -new -key ssl/${NODE_NAME}-client-key.pem -subj '/CN=docker-client' -out ssl/${NODE_NAME}-client.csr
openssl x509 -req -days 365 -in ssl/${NODE_NAME}-client.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -extfile <(echo "extendedKeyUsage = clientAuth") -out ssl/${NODE_NAME}-client-cert.pem
#
# Shell to the new node and run the following
scp ssl/${NODE_NAME}-client-key.pem jsoehner@${NODE_NAME}:~
scp ssl/${NODE_NAME}-client-cert.pem jsoehner@${NODE_NAME}:~
#
# Make .dcoker directory and upload keys
ssh jsoehner@${NODE_NAME} 'mkdir -p ~/.docker'
scp ssl/ca.pem jsoehner@${NODE_NAME}:~/.docker/ca.pem
scp ssl/ca-key.pem jsoehner@${NODE_NAME}:~/.docker/ca-key.pem
#
# Prepare docker daemon certs for each host
#
ssh -t jsoehner@${NODE_NAME} 'sudo mkdir -p /etc/docker/ssl'
tee ssl/${NODE_NAME}-openssl.cnf <<EOF
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
    DNS.1 = ${NODE_NAME}
    DNS.2 = ${NODE_NAME}.jsigroup.local
    IP.1 = 127.0.0.1
    IP.2 = ${IP}
EOF
scp ssl/${NODE_NAME}-openssl.cnf jsoehner@${NODE_NAME}:openssl.cnf
ssh jsoehner@${NODE_NAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_NAME} 'sudo openssl genrsa -out /etc/docker/ssl/${NODE_NAME}-daemon-key.pem 4096'
ssh jsoehner@${NODE_NAME} 'sudo openssl req -new -key /etc/docker/ssl/${NODE_NAME}-daemon-key.pem -out /etc/docker/ssl/${NODE_NAME}-daemon-cert.csr -subj '/CN=docker-daemon' -config /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_NAME} 'sudo openssl x509 -req -in /etc/docker/ssl/${NODE_NAME}-daemon-cert.csr -CA /etc/docker/ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out /etc/docker/ssl/${NODE_NAME}-daemon-cert.pem -days 3650 -extensions v3_req -extfile /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_NAME} 'sudo chmod 600 /etc/docker/ssl/*'
ssh jsoehner@${NODE_NAME} 'sudo tee /etc/docker/daemon.json <<EOF
{
    "icc": false,
    "tls": true,
    "tlsverify": true,
    "tlscacert": "/etc/docker/ssl/ca.pem",
    "tlscert": "/etc/docker/ssl/${NODE_NAME}-daemon-cert.pem",
    "tlskey": "/etc/docker/ssl/${NODE_NAME}-daemon-key.pem",
    "userland-proxy": false,
    "default-ulimit": "nofile=50:100",
    "hosts": ["unix:///var/run/docker.sock", "tcp://${IP}:2376"]
  }
EOF'

# Patch systemd for flag error
ssh jsoehner@${NODE_NAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh jsoehner@${NODE_NAME} 'sudo sed -i 's/-H\ fd:\/\///g' /etc/systemd/system/docker.service'
ssh jsoehner@${NODE_NAME} 'sudo systemctl daemon-reload'
ssh jsoehner@${NODE_NAME} 'sudo service docker restart'
#
# Create a remote kind cluster on remote host
#
cat <<EOF | kind create cluster --image=kindest/node:v1.26.0 --name ${HUB_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${IP}
  apiServerPort: 6443
EOF
#
# Initialize the management hub
#
clusteradm init --wait --context ${CTX_HUB_CLUSTER}
#
# We will create a join command using these values below
# so don't worry about capturing this output for now
#
# OLD 
# [join-cluster-cmd=$( clusteradm get token | sed 's/^token\(.*\)//' | sed 's/<cluster_name>/\$\{CLUSTER\}/‘)]
#
export TOKEN=$(clusteradm get token | grep "token=" | cut -c 7-)
# 
#
# Create a connection to managed cluster 1
#
export NODE_NAME=node1
export IP=192.168.100.111
export DOCKER_PORT=2376
export DOCKER_HOST=tcp://${IP}:${DOCKER_PORT}
export CTX_MANAGED_CLUSTER=kind-${NODE_NAME}
#
# Create a standard kind cluster called node1
# (This will be your ‘managed’ cluster where
# you will place the workloads - add as many
# clusters as you would like by repeating this)
#
# Create certs on each node to connect to cluster
openssl genrsa -out ssl/${NODE_NAME}-client-key.pem 2048
openssl req -new -key ssl/${NODE_NAME}-client-key.pem -subj '/CN=docker-client' -out ssl/${NODE_NAME}-client.csr
openssl x509 -req -days 365 -in ssl/${NODE_NAME}-client.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -extfile <(echo "extendedKeyUsage = clientAuth") -out ssl/${NODE_NAME}-client-cert.pem
#
# Shell to the new node and run the following
scp ssl/${NODE_NAME}-client-key.pem jsoehner@${NODE_NAME}:~
scp ssl/${NODE_NAME}-client-cert.pem jsoehner@${NODE_NAME}:~
scp ssl/ca.pem jsoehner@${NODE_NAME}:~/.docker/ca.pem
scp ssl/ca-key.pem jsoehner@${NODE_NAME}:~/.docker/ca-key.pem
#
# Prepare docker daemon certs for each host
#
ssh jsoehner@${NODE_NAME} 'sudo openssl genrsa -out /etc/docker/ssl/${NODE_NAME}-daemon-key.pem 4096'
ssh jsoehner@${NODE_NAME} 'sudo openssl req -new -key /etc/docker/ssl/${NODE_NAME}-daemon-key.pem -out /etc/docker/ssl/${NODE_NAME}-daemon-cert.csr -subj '/CN=docker-daemon' -config /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_NAME} 'sudo openssl x509 -req -in /etc/docker/ssl/${NODE_NAME}-daemon-cert.csr -CA /etc/docker/ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out /etc/docker/ssl/${NODE_NAME}-daemon-cert.pem -days 3650 -extensions v3_req -extfile /etc/docker/ssl/openssl.cnf'
ssh jsoehner@${NODE_NAME} 'sudo chmod 600 /etc/docker/ssl/*'
ssh jsoehner@${NODE_NAME} 'sudo tee /etc/docker/daemon.json <<EOF
{
    "icc": false,
    "tls": true,
    "tlsverify": true,
    "tlscacert": "/etc/docker/ssl/ca.pem",
    "tlscert": "/etc/docker/ssl/${NODE_NAME}-daemon-cert.pem",
    "tlskey": "/etc/docker/ssl/${NODE_NAME}-daemon-key.pem",
    "userland-proxy": false,
    "default-ulimit": "nofile=50:100",
    "hosts": ["unix:///var/run/docker.sock", "tcp://${IP}:2376"]
  }
EOF'

# Patch systemd for flag error
ssh jsoehner@${NODE_NAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/'
ssh jsoehner@${NODE_NAME} 'sudo sed -i 's/-H\ fd:\/\///g' /etc/systemd/system/docker.service'
ssh jsoehner@${NODE_NAME} 'sudo systemctl daemon-reload'
ssh jsoehner@${NODE_NAME} 'sudo service docker restart'
ssh jsoehner@${NODE_NAME} 'sudo mkdir -p /etc/docker/ssl'
ssh jsoehner@${NODE_NAME} 'sudo tee /etc/docker/ssl/openssl.cnf <<EOF
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
    DNS.1 = ${NODE_NAME}
    DNS.2 = ${NODE_NAME}.jsigroup.local
    IP.1 = 127.0.0.1
    IP.2 = ${IP}
EOF'
#
cat <<EOF | kind create cluster --image=kindest/node:v1.26.0 --name ${NODE_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${IP}
  apiServerPort: 6443
EOF
#
# Join the cluster to your Hub
#
clusteradm join --hub-token ${TOKEN} --hub-apiserver https://192.168.100.110:6443 --wait --cluster-name ${NODE_NAME} --force-internal-endpoint-lookup --context ${CTX_MANAGED_CLUSTER}
#
# Go back and accept it on master
#
clusteradm config set-context ${HUB_NAME}
#
clusteradm accept --cluster ${NODE_NAME}
#
