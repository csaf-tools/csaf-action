#!/bin/bash

csaf_version="3.3.0"
secvisogram_version="2.0.7"
publisher_category="vendor"
publisher_name="Example Company"
publisher_namespace="https://example.com"
publisher_issuing_authority="We at Example Company are responsible for publishing and maintaining Product Y."
publisher_contact_details="Example Company can be reached at contact_us@example.com or via our website at https://www.example.com/contact."
source_csaf_documents="test/inputs/"
openpgp_key_email_address="csaf@example.invalid"
openpgp_key_real_name="Example CSAF Publisher"
openpgp_key_type="RSA"
openpgp_key_length="4096"
openpgp_secret_key=""
openpgp_key=""
generate_index_files="false"
target_branch="gh-pages"

cd "./source" || exit
# inspired by https://github.com/ChristopherDavenport/create-ghpages-ifnotexists/blob/main/action.yml but with different committer
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
gh_pages_exists=$(git ls-remote --heads origin "${target_branch}")
if [[ -z "$gh_pages_exists" ]]; then
  echo "Create branch ${target_branch}"
  previous_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout --orphan "${target_branch}"  # empty branch
  git reset --hard  # remove any files
  git commit --allow-empty --message "Create empty branch ${target_branch}"
  git push origin "${target_branch}"
  git checkout "$previous_branch"
fi

rm -rf gh-pages
git clone -b gh-pages . gh-pages

url=$(gh api "repos/$GITHUB_REPOSITORY/pages" --jq '.html_url')
echo "$url"
# remove the trailing slash to prevent urls containing '//' in provider-metadata.json
outputs_url=${url%/}

DEBIAN_FRONTEND=noninteractive sudo -E apt-get update -qq
# npm and hunspell for secvisogram, tree for pages.sh
DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y nginx fcgiwrap npm hunspell wait-for-it tree

sudo cp "./nginx/fcgiwrap.conf" /etc/nginx/fcgiwrap.conf
sudo cp "./nginx/default.conf" /etc/nginx/sites-enabled/default
sudo systemctl start fcgiwrap.service
sudo systemctl start fcgiwrap.socket
sudo systemctl reload-or-restart nginx.service
wait-for-it localhost:80

wget "https://github.com/gocsaf/csaf/releases/download/v${csaf_version}/csaf-${csaf_version}-gnulinux-amd64.tar.gz"
tar -xzf "csaf-${csaf_version}-gnulinux-amd64.tar.gz"

wget "https://github.com/secvisogram/csaf-validator-service/archive/refs/tags/v${secvisogram_version}.tar.gz" -O "secvisogram-csaf-validator-service-${secvisogram_version}.tar.gz"
tar -xzf "secvisogram-csaf-validator-service-${secvisogram_version}.tar.gz"

sudo mkdir -p /etc/csaf/
if [[ -z "${openpgp_key}" || -z "${openpgp_secret_key}" ]]; then
  # based on https://serverfault.com/a/960673/217116
  cat >keydetails <<EOF
      Key-Type: ${openpgp_key_type}
      Key-Length: ${openpgp_key_length}
      Subkey-Type: ${openpgp_key_type}
      Subkey-Length: ${openpgp_key_length}
      Name-Real: ${openpgp_key_real_name}
      Name-Email: ${openpgp_key_email_address}
      Expire-Date: 0
      %no-ask-passphrase
      %no-protection
      %commit
EOF
  gpg --batch --gen-key keydetails
  # check if the key works
  echo foobar | gpg -e -a -r "${openpgp_key_email_address}"
  # save at expected destinations
  gpg --armor --export "${openpgp_key_email_address}" | sudo tee /etc/csaf/openpgp_public.asc > /dev/null
  gpg --armor --export-secret-keys "${openpgp_key_email_address}" | sudo tee /etc/csaf/openpgp_private.asc > /dev/null
else
  echo "${openpgp_key}" | sudo tee /etc/csaf/openpgp_public.asc > /dev/null
  echo "${openpgp_secret_key}" | sudo tee /etc/csaf/openpgp_private.asc > /dev/null
fi

set -x
# for validations.db
sudo mkdir -p /var/lib/csaf/
sudo cp "./csaf_provider/config.toml" /etc/csaf/config.toml
sudo chgrp www-data /etc/csaf/config.toml
sudo chmod g+r,o-rwx /etc/csaf/config.toml
web_folder="./target"
internal_output=$(mktemp -d)
mkdir -p "$web_folder"
# remove all previous existing data, prepare for a new csaf_provider structure
rm -rf "${web_folder}/.well-known/csaf/"
sudo chgrp -R www-data "$web_folder" "$internal_output" /var/lib/csaf/
sudo chmod -R g+rw "$web_folder" "$internal_output" /var/lib/csaf/
sudo chmod +x "$internal_output"
# make all parents of $web_folder accessible to www-data
i="$web_folder"
while [[ "$i" != /home ]]; do sudo chmod o+rx "$i"; i="$(dirname "$i")"; done
# make all parents of $internal_output accessible to www-data
i="$internal_output"
while [[ "$i" != /tmp ]]; do sudo chmod o+rx "$i"; i="$(dirname "$i")"; done
sudo sed -ri \
  -e "s#^folder *=.*#folder = \"$internal_output\"#" \
  -e "s#^web *=.*#web = \"$web_folder\"#" \
  -e "s#^category *=.*#category = \"${publisher_category}\"#" \
  -e "s#^name *=.*#name = \"${publisher_name}\"#" \
  -e "s#^namespace *=.*#namespace = \"${publisher_namespace}\"#" \
  -e "s#^issuing_authority *=.*#issuing_authority = \"${publisher_issuing_authority}\"#" \
  -e "s#^contact_details *=.*#contact_details = \"${publisher_contact_details}\"#" \
  -e "s#^\#?canonical_url_prefix *=.*#canonical_url_prefix = \"${outputs_url}\"#" \
  /etc/csaf/config.toml
sudo cat /etc/csaf/config.toml
sudo mkdir -p /usr/lib/cgi-bin/
sudo cp "csaf-${csaf_version}-gnulinux-amd64/bin-linux-amd64/csaf_provider" /usr/lib/cgi-bin/csaf_provider.go
curl -f http://127.0.0.1/cgi-bin/csaf_provider.go/api/create  -H 'X-Csaf-Provider-Auth: $2a$10$QL0Qy7CeOSdWDrdw6huw0uFk2szqxMssoihVn64BbZEPzqXwPThgu'
# has no proper exit codes currently: https://github.com/gocsaf/csaf/issues/669
# "./csaf-${csaf_version}-gnulinux-amd64/bin-linux-amd64/csaf_uploader" --action create --url http://127.0.0.1/cgi-bin/csaf_provider.go --password password

pushd "csaf-validator-service-${secvisogram_version}" || exit
npm ci
nohup npm run dev < /dev/null &> secvisogram.log &
secvisogram_pid=$!
popd || exit
echo $secvisogram_pid > secvisogram.pid
wait-for-it localhost:8082

find "./source/${source_csaf_documents}" -type f -name '*.json' -print0 | while IFS= read -r -d $'\0' file; do
  echo "Uploading $file"
  "./csaf-${csaf_version}-gnulinux-amd64/bin-linux-amd64/csaf_uploader" --action upload --url http://127.0.0.1/cgi-bin/csaf_provider.go --password password "$file"
done
pushd "./target" || exit
generate_index_files=${generate_index_files} "./pages.sh"
popd || exit

