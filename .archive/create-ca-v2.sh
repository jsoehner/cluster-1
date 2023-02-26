#!/bin/bash
#
set -x
# New TLS install
#
IP=192.168.100.110
NODE_NAME=cluster1
#
mkdir -p ssl
openssl genrsa -out ssl/ca-key.pem 4096
openssl req -x509 -new -nodes -key ssl/ca-key.pem -days 3650 -out ssl/ca.pem -subj '/CN=docker-CA'
#
# Create certs on each node to connect to cluster
openssl genrsa -out ssl/${NODE_NAME}-client-key.pem 2048
openssl req -new -key ssl/${NODE_NAME}-client-key.pem -subj '/CN=docker-client' -out ssl/${NODE_NAME}-client.csr
openssl x509 -req -days 365 -in ssl/${NODE_NAME}-client.csr -CA ssl/ca-cert.pem -CAkey ssl/ca-key.pem -CAcreateserial -extfile <(echo "extendedKeyUsage = clientAuth") -out ssl/${NODE_NAME}-client-cert.pem
#
mkdir -p /etc/docker/ssl
sudo tee /etc/docker/ssl/openssl.cnf <<EOF
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
#
scp ssl/ca.pem jsoehner@${NODE_NAME}:~/.docker/ca.pem
scp ssl/ca-key.pem jsoehner@${NODE_NAME}:~/.docker/ca-key.pem
#
ssh jsoehner@${NODE_NAME}
#
# Prepare docker daemon certs for each host
#
sudo openssl genrsa -out /etc/docker/ssl/${NODE_NAME}-daemon-key.pem 4096
sudo openssl req -new -key /etc/docker/ssl/${NODE_NAME}-daemon-key.pem -out /etc/docker/ssl/${NODE_NAME}-daemon-cert.csr -subj '/CN=docker-daemon' -config /etc/docker/ssl/openssl.cnf
sudo openssl x509 -req -in /etc/docker/ssl/${NODE_NAME}-daemon-cert.csr -CA /etc/docker/ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out /etc/docker/ssl/${NODE_NAME}-daemon-cert.pem -days 3650 -extensions v3_req -extfile /etc/docker/ssl/openssl.cnf
sudo chmod 600 /etc/docker/ssl/*

sudo tee /etc/docker/daemon.json <<EOF
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
EOF

# Patch systemd for flag error
sudo cp /lib/systemd/system/docker.service /etc/systemd/system/
sudo sed -i 's/\ -H\ fd:\/\///g' /etc/systemd/system/docker.service
sudo systemctl daemon-reload
sudo service docker restart
#
# Exit shell on node
exit
#
scp ssl/ca.pem jsoehner@${NODE_NAME}:~/.docker/ca.pem
scp ssl/${NODE_NAME}-client-key.pem jsoehner@${NODE_NAME}:~/.docker/key.pem
scp ssl/${NODE_NAME}-client-cert.pem jsoehner@${NODE_NAME}:~/.docker/cert.pem

# Additional settings
# Add additional AppArmor settings
#sudo tee /etc/apparmor.d/docker-server<<EOF
#    #include <tunables/global> 
#    
#    profile docker-labkey-myserver flags=(attach_disconnected,mediate_deleted) {
#
#        #include <abstractions/base>
#
#        network inet tcp,
#        network inet udp,
#        deny network inet icmp,
#        deny network raw,
#        deny network packet,
#        capability,
#        file,
#        umount,
#
#        deny @{PROC}/* w,   # deny write for all files directly in /proc (not in a subdir)
#        # deny write to files not in /proc/<number>/** or /proc/sys/**
#        deny @{PROC}/{[^1-9],[^1-9][^0-9],[^1-9s][^0-9y][^0-9s],[^1-9][^0-9][^0-9][^0-9]*}/** w,
#        deny @{PROC}/sys/[^k]** w,  # deny /proc/sys except /proc/sys/k* (effectively /proc/sys/kernel)
#        deny @{PROC}/sys/kernel/{?,??,[^s][^h][^m]**} w,  # deny everything except shm* in /proc/sys/kernel/
#        deny @{PROC}/sysrq-trigger rwklx,
#        deny @{PROC}/mem rwklx,
#        deny @{PROC}/kmem rwklx,
#        deny @{PROC}/kcore rwklx,
#
#        deny mount,
#
#        deny /sys/[^f]*/** wklx,
#        deny /sys/f[^s]*/** wklx,
#        deny /sys/fs/[^c]*/** wklx,
#        deny /sys/fs/c[^g]*/** wklx,
#        deny /sys/fs/cg[^r]*/** wklx,
#        deny /sys/firmware/efi/efivars/** rwklx,
#        deny /sys/kernel/security/** rwklx,
#
#        # suppress ptrace denials when using 'docker ps' or using 'ps' inside a container
#        ptrace (trace,read) peer=docker-labkey-myserver,
#
#        # Rules added by LabKey to deny running executables and accessing files
#        deny /bin/dash mrwklx,
#        deny /bin/bash mrwklx,
#        deny /bin/sh mrwklx,
#        deny /usr/bin/top mrwklx,
#        deny /usr/bin/apt* mrwklx,
#        deny /usr/bin/dpkg mrwklx,
#    
#        deny /bin/** wl,
#        deny /boot/** wl,
#        deny /dev/[^null]** wl,
#        deny /lib/** wl,
#        deny /lib64/** wl,
#        deny /media/** wl,
#        deny /mnt/** wl,
#        deny /opt/** wl,
#        deny /proc/** wl,
#        deny /root/** wl,
#        deny /sbin/** wl,
#        deny /srv/** wl,
#        deny /sys/** wl,
#        deny /usr/[^local]** wl,
#        deny /teamcity/** rwklx,
#        deny /labkey/** rwklx,
#        deny /share/files/** rwklx,    
#    }
#EOF

# apparmor_parser -r -W /etc/apparmor.d/docker-server

