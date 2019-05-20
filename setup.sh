#!/bin/bash -v

apt-get update
apt-get install -y awscli jq python python-pip

wget https://download.elotl.co/milpa-installer-latest
chmod 755 milpa-installer-latest
./milpa-installer-latest

pip install yq
yq -y ".clusterName=\"${cluster_name}\" | .cloud.aws.accessKeyID=\"${aws_access_key_id}\" | .cloud.aws.secretAccessKey=\"${aws_secret_access_key}\" | .cloud.aws.vpcID=\"\" | .license.key=\"${license_key}\" | .license.id=\"${license_id}\" | .license.username=\"${license_username}\" | .license.password=\"${license_password}\"" /opt/milpa/etc/server.yml > /opt/milpa/etc/server.yml.new && mv /opt/milpa/etc/server.yml.new /opt/milpa/etc/server.yml

systemctl daemon-reload
systemctl restart milpa
