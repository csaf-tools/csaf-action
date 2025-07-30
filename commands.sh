#!/bin/bash

csaf_version=3.3.0
secvisogram_version=2.0.7

DEBIAN_FRONTEND=noninteractive sudo -E apt-get update -qq
# npm and hunspell for secvisogram
DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y nginx fcgiwrap npm hunspell wait-for-it

sudo cp nginx/fcgiwrap.conf /etc/nginx/fcgiwrap.conf
sudo cp nginx/default.conf /etc/nginx/sites-enabled/default
sudo chgrp -R www-data /var/www/
sudo chmod -R g+w /var/www/
sudo systemctl start fcgiwrap.service
sudo systemctl start fcgiwrap.socket
sudo systemctl reload-or-restart nginx.service
wait-for-it localhost:80

wget https://github.com/gocsaf/csaf/releases/download/v$csaf_version/csaf-$csaf_version-gnulinux-amd64.tar.gz
tar -xzf csaf-$csaf_version-gnulinux-amd64.tar.gz

wget https://github.com/secvisogram/csaf-validator-service/archive/refs/tags/v$secvisogram_version.tar.gz -O secvisogram-csaf-validator-service-$secvisogram_version.tar.gz
tar -xzf secvisogram-csaf-validator-service-$secvisogram_version.tar.gz

sudo mkdir /etc/csaf/
sudo cp csaf_provider/config.toml /etc/csaf/config.toml
sudo chgrp www-data /etc/csaf/config.toml
sudo chmod g+r,o-rwx /etc/csaf/config.toml
sudo mkdir -p /usr/lib/cgi-bin/
sudo cp csaf-$csaf_version-gnulinux-amd64/bin-linux-amd64/csaf_provider /usr/lib/cgi-bin/csaf_provider.go
./csaf-$csaf_version-gnulinux-amd64/bin-linux-amd64/csaf_uploader --action create --url http://127.0.0.1/cgi-bin/csaf_provider.go --password password

pushd csaf-validator-service-$secvisogram_version
npm ci
nohup npm run dev < /dev/null &> secvisogram.log &
secvisogram_pid=$!
popd
echo $secvisogram_pid > secvisogram.pid
wait-for-it localhost:8082
