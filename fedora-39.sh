###!/bin/bash
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
export USER=jsoehner
export CAROOT=ssl/
export CLIENT_CERT=Jeffs-MacBook+1-client
export HUB_IP=192.168.100.80
export NODE_HOSTNAME=cluster9
export DOMAIN_NAME=jsigroup.local
#
# Assuming you have already installed your CA into a sub directory called
# 'ssl' this part creates a daemon cert and adds the rootCA, docker daemon
# cert and key onto the docker host
#
mkcert ${NODE_HOSTNAME}.${DOMAIN_NAME} ${HUB_IP} >/dev/null 2>&1
mv ${NODE_HOSTNAME}.${DOMAIN_NAME}*.pem ssl/ >/dev/null 2>&1
scp ssl/rootCA.pem ${USER}@${NODE_HOSTNAME}:~ >/dev/null 2>&1
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?.pem ${USER}@${NODE_HOSTNAME}:~ >/dev/null 2>&1
scp ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}+?-key.pem ${USER}@${NODE_HOSTNAME}:~ >/dev/null 2>&1
#
# Create a new docker context and switch to the new context
# ---------------------------------------------------------
#
docker context rm ${NODE_HOSTNAME} -f >/dev/null 2>&1
docker context create ${NODE_HOSTNAME}\
  --description "${NODE_HOSTNAME} context created"\
  --docker "host=tcp://${HUB_IP}:2376,ca=ssl/rootCA.pem,cert=ssl/${CLIENT_CERT}.pem,key=ssl/${CLIENT_CERT}-key.pem" >/dev/null 2>&1
docker context use ${NODE_HOSTNAME} >/dev/null 2>&1
#
# Create OpenSSL config
# ---------------------
#
tee ssl/${NODE_HOSTNAME}-openssl.cnf <<EOF >/dev/null 2>&1
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
scp ssl/${NODE_HOSTNAME}-openssl.cnf ${USER}@${NODE_HOSTNAME}:openssl.cnf >/dev/null 2>&1
ssh -t ${USER}@${NODE_HOSTNAME} 'sudo mkdir -p /etc/docker/ssl' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/openssl.cnf /etc/docker/ssl/openssl.cnf' >/dev/null 2>&1
#
# Remove and re-install new Trusted Root CA
#
ssh ${USER}@${NODE_HOSTNAME} 'sudo rm -f /etc/pki/ca-trust/source/anchors/docker-root-ca.crt' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo cp -f ~/rootCA.pem  /etc/pki/ca-trust/source/anchors/docker-root-ca.crt' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo update-ca-trust' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/rootCA.pem /etc/docker/ssl/rootCA.pem' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1.pem /etc/docker/ssl/daemon-cert.pem' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/*.jsigroup.local+1-key.pem /etc/docker/ssl/daemon-key.pem' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo chmod 600 /etc/docker/ssl/*' >/dev/null 2>&1
scp ssl/daemon.json ${USER}@${NODE_HOSTNAME}:~ >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo mv ~/daemon.json /etc/docker/daemon.json' >/dev/null 2>&1
#
# Patch systemd for flag error
# ----------------------------
ssh ${USER}@${NODE_HOSTNAME} 'sudo cp /lib/systemd/system/docker.service /etc/systemd/system/' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo sed -i "s/\-H fd:\/\///" /etc/systemd/system/docker.service' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo systemctl daemon-reload' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo service docker restart' >/dev/null 2>&1
#
# Remove any stale clusters
# -------------------------
kind delete cluster --name $(kind get clusters 2>/dev/null) >/dev/null 2>&1
#
# Setup Kubevela
# --------------
ssh ${USER}@${NODE_HOSTNAME} 'sudo dnf install -y https://github.com/k3s-io/k3s-selinux/releases/download/v1.4.stable.1/k3s-selinux-1.4-1.el8.noarch.rpm' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo curl -fsSl https://kubevela.io/script/install-velad.sh | bash' >/dev/null 2>&1
ssh ${USER}@${NODE_HOSTNAME} 'sudo velad uninstall' >/dev/null 2>&1
#
# [Remove existing KubeVela cluster if it exists otherwise continue]
(($? != 1)) && { printf '%s\n' "*** Existing Kubevela was removed this time - PLEASE rerun to install once again ***"; exit 0; }
#
ssh ${USER}@${NODE_HOSTNAME} 'sudo velad install --bind-ip=${HUB_IP}'
ssh ${USER}@${NODE_HOSTNAME} 'sudo cat /etc/rancher/k3s/k3s.yaml | sed "s/127\.0\.0\.1/192\.168\.100\.80/g"' > ./"${NODE_HOSTNAME}"-kubeconfig.yaml
export KUBERNETES_MASTER=./"${NODE_HOSTNAME}"-kubeconfig.yaml
#
# Enable Add-ons
# --------------
#
vela addon enable vela-workflow
#vela addon enable kube-state-metrics
#vela addon enable node-exporter
#vela addon enable vela-prism
#vela addon enable o11y-definitions
#vela addon enable prometheus-server
#vela addon enable loki
#vela addon enable ocm-hub-control-plane
#
# Setup velaux using external SSL & configure
#tee ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.ext <<EOF
#    authorityKeyIdentifier = keyid,issuer
#    basicConstraints = CA:FALSE
#    keyUsage = nonRepudiation, digitalSignature, keyEncipherment, dataEncipherment
#    subjectAltName = @alt_names
#
#    [alt_names]
#    DNS.1 = ${NODE_HOSTNAME}
#    DNS.2 = ${NODE_HOSTNAME}.${DOMAIN_NAME}
#    IP.1 = 127.0.0.1
#    IP.2 = ${HUB_IP}
#EOF
#
# Create Key pair for SSL Cert for Velaux
# ---------------------------------------
#
#openssl genrsa -out ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.key 2048
#openssl req -new -key ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.key -out ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.csr
#openssl x509 -req -in ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.csr -CA ssl/rootCA.pem -CAkey ssl/rootCA-key.pem \
# -CAcreateserial -out ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.crt -days 398 -sha256 \
# -extfile ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.ext
#export CERT_BASE64=$(openssl base64 -in ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.crt | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')
#export KEY_BASE64=$(openssl base64 -in ssl/${NODE_HOSTNAME}.${DOMAIN_NAME}.key | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')
#
# Prepare kubernetes secret
# -------------------------
#
#tee ssl/velaux-cert.yaml << EOF
#apiVersion: core.oam.dev/v1beta1
#kind: Application
#metadata:
#  annotations:
#    config.oam.dev/alias: "VelaUX SSL Certificate"
#  labels:
#    app.oam.dev/source-of-truth: from-inner-system
#    config.oam.dev/catalog: velacore-config
#    config.oam.dev/type: config-tls-certificate
#  name: velaux-cert
#  namespace: vela-system
#spec:
#  components:
#  - name: velaux
#    properties:
#      cert: ${CERT_BASE64}
#      key: ${KEY_BASE64}
#    type: config-tls-certificate
#EOF
#kubectl apply -f ssl/velaux-cert.yaml
#vela addon enable velaux domain=${NODE_HOSTNAME}.${DOMAIN_NAME} gatewayDriver=traefik secretName=velaux-cert
