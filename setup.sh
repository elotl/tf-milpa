#!/bin/bash -v

apt-get update
apt-get install -y awscli jq python python-pip

# This is the last supported version for standalone Milpa.
wget -O milpa-installer https://download.elotl.co/milpa-v1.2.9
chmod 755 milpa-installer
./milpa-installer

pip install yq

# Pin the version of itzo and the AMI.
yq -y ".clusterName=\"${cluster_name}\" | .cloud.aws.accessKeyID=\"${aws_access_key_id}\" | .cloud.aws.secretAccessKey=\"${aws_secret_access_key}\" | .cloud.aws.vpcID=\"\" | .license.key=\"${license_key}\" | .license.id=\"${license_id}\" | .license.username=\"${license_username}\" | .license.password=\"${license_password}\" | .nodes.bootImageTags.version=\"449\" | .nodes.itzo.version=\"v1.0.7\"" /opt/milpa/etc/server.yml > /opt/milpa/etc/server.yml.new && mv /opt/milpa/etc/server.yml.new /opt/milpa/etc/server.yml

systemctl daemon-reload
systemctl restart milpa
