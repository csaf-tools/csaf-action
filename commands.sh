#!/bin/bash

csaf_version="3.3.0"
secvisogram_version="2.0.7"
publisher_category="vendor"
publisher_name="Example Company"
publisher_namespace="https://example.com"
publisher_issuing_authority="We at Example Company are responsible for publishing and maintaining Product Y."
publisher_contact_details="Example Company can be reached at contact_us@example.com or via our website at https://www.example.com/contact."
source_csaf_documents="test/inputs/"

# inspired by https://github.com/ChristopherDavenport/create-ghpages-ifnotexists/blob/main/action.yml but with different committer
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
gh_pages_exists=$(git ls-remote --heads origin gh-pages)
if [[ -z "$gh_pages_exists" ]]; then
  echo "Create branch gh-pages"
  previous_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout --orphan gh-pages  # empty branch
  git reset --hard  # remove any files
  git commit --allow-empty --message "Create empty branch gh-pages"
  git push origin gh-pages
  git checkout "$previous_branch"
fi

DEBIAN_FRONTEND=noninteractive sudo -E apt-get update -qq
# npm and hunspell for secvisogram
DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y nginx fcgiwrap npm hunspell wait-for-it

sudo cp nginx/fcgiwrap.conf /etc/nginx/fcgiwrap.conf
sudo cp nginx/default.conf /etc/nginx/sites-enabled/default
sudo systemctl start fcgiwrap.service
sudo systemctl start fcgiwrap.socket
sudo systemctl reload-or-restart nginx.service
wait-for-it localhost:80

wget https://github.com/gocsaf/csaf/releases/download/v$csaf_version/csaf-$csaf_version-gnulinux-amd64.tar.gz
tar -xzf csaf-$csaf_version-gnulinux-amd64.tar.gz

wget https://github.com/secvisogram/csaf-validator-service/archive/refs/tags/v$secvisogram_version.tar.gz -O secvisogram-csaf-validator-service-$secvisogram_version.tar.gz
tar -xzf secvisogram-csaf-validator-service-$secvisogram_version.tar.gz

# based on https://serverfault.com/a/960673/217116
cat >keydetails <<EOF
    Key-Type: RSA
    Key-Length: 4096
    Subkey-Type: RSA
    Subkey-Length: 4096
    Name-Real: CSAF Advisory Test
    Name-Comment: CSAF Advisory Test
    Name-Email: noreply@example.com
    Expire-Date: 0
    %no-ask-passphrase
    %no-protection
    %commit
EOF
gpg --batch --gen-key keydetails
# check if the key works
echo foobar | gpg -e -a -r noreply@example.com
# save at expexted destinations
sudo mkdir -p /etc/csaf/
gpg --armor --export noreply@example.com | sudo tee /etc/csaf/openpgp_public.asc > /dev/null
gpg --armor --export-secret-keys noreply@example.com | sudo tee /etc/csaf/openpgp_private.asc > /dev/null

# for validations.db
sudo mkdir -p /var/lib/csaf/
sudo cp csaf_provider/config.toml /etc/csaf/config.toml
sudo chgrp www-data /etc/csaf/config.toml
sudo chmod g+r,o-rwx /etc/csaf/config.toml
output_folder="$(pwd)/gh-pages/"
sudo mkdir -p $output_folder
sudo chgrp -R www-data $output_folder /var/lib/csaf/
sudo chmod -R g+rw $output_folder /var/lib/csaf/
# make all parents of $output_folder accessable to www-data
i=$output_folder
while [[ $i != /home ]]; do sudo chmod o+rx "$i"; i=$(dirname "$i"); done
sudo sed -ri -e "s#^folder ?=.*#folder = \"$output_folder\"#" -e "s#^web ?=.*#web = \"$output_folder/html\"#" /etc/csaf/config.toml
sudo sed -ri -e "s#^category ?=.*#category = \"$publisher_category\"#" \
  -e "s#^name ?=.*#name = \"$publisher_name\"#" \
  -e "s#^namespace ?=.*#namespace = \"$publisher_namespace\"#" \
  -e "s#^issuing_authority ?=.*#issuing_authority = \"$publisher_issuing_authority\"#" \
  -e "s#^contact_details ?=.*#contact_details = \"$publisher_contact_details\"#" \
  /etc/csaf/config.toml
sudo mkdir -p /usr/lib/cgi-bin/
sudo cp csaf-$csaf_version-gnulinux-amd64/bin-linux-amd64/csaf_provider /usr/lib/cgi-bin/csaf_provider.go
curl -f http://127.0.0.1/cgi-bin/csaf_provider.go/api/create  -H 'X-Csaf-Provider-Auth: $2a$10$QL0Qy7CeOSdWDrdw6huw0uFk2szqxMssoihVn64BbZEPzqXwPThgu'
# has no proper exit codes currently: https://github.com/gocsaf/csaf/issues/669
# ./csaf-$csaf_version-gnulinux-amd64/bin-linux-amd64/csaf_uploader --action create --url http://127.0.0.1/cgi-bin/csaf_provider.go --password password

pushd csaf-validator-service-$secvisogram_version
npm ci
nohup npm run dev < /dev/null &> secvisogram.log &
secvisogram_pid=$!
popd
echo $secvisogram_pid > secvisogram.pid
wait-for-it localhost:8082

find $source_csaf_documents -type f -name '*.json' -print0 | while IFS= read -r -d $'\0' file; do
  echo "Uploading $file"
  ./csaf-$csaf_version-gnulinux-amd64/bin-linux-amd64/csaf_uploader --action upload --url http://127.0.0.1/cgi-bin/csaf_provider.go --password password "$file"
done

