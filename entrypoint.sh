#!/bin/bash

# Configure git
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

# Checkout gh-pages in subdirectory
git init gh-pages
git config --local http.https://github.com/.extraheader AUTHORIZATION: basic $GITHUB_TOKEN
git -c protocol.version=2 fetch --no-tags --prune --progress --no-recurse-submodules --depth=1 origin +refs/heads/gh-pages*:refs/remotes/origin/gh-pages* +refs/tags/gh-pages*:refs/tags/gh-pages*
git checkout --force -B gh-pages refs/remotes/origin/gh-pages

# Start nginx
systemctl start fcgiwrap.service
systemctl start fcgiwrap.socket
systemctl reload-or-restart nginx.service
wait-for-it localhost:80

# Create OpenPGP key
# TODO: replace by a secret
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
gpg --armor --export noreply@example.com | tee /etc/csaf/openpgp_public.asc > /dev/null
gpg --armor --export-secret-keys noreply@example.com | tee /etc/csaf/openpgp_private.asc > /dev/null

# Configure csaf_provider
output_folder="$(pwd)/gh-pages/"
chgrp -R www-data $output_folder /var/lib/csaf/
chmod -R g+rw $output_folder /var/lib/csaf/
# make all parents of $output_folder accessable to www-data
i=$output_folder
while [[ $i != /home ]]; do chmod o+rx "$i"; i=$(dirname "$i"); done
sed -ri -e "s#^folder ?=.*#folder = \"$output_folder\"#" -e "s#^web ?=.*#web = \"$output_folder/html\"#" /etc/csaf/config.toml
sed -ri -e "s#^category ?=.*#category = \"${{ inputs.publisher_category }}\"#" \
    -e "s#^name ?=.*#name = \"${{ inputs.publisher_name }}\"#" \
    -e "s#^namespace ?=.*#namespace = \"${{ inputs.publisher_namespace }}\"#" \
    -e "s#^issuing_authority ?=.*#issuing_authority = \"${{ inputs.publisher_issuing_authority }}\"#" \
    -e "s#^contact_details ?=.*#contact_details = \"${{ inputs.publisher_contact_details }}\"#" \
    /etc/csaf/config.toml
curl -f http://127.0.0.1/cgi-bin/csaf_provider.go/api/create  -H 'X-Csaf-Provider-Auth: $2a$10$QL0Qy7CeOSdWDrdw6huw0uFk2szqxMssoihVn64BbZEPzqXwPThgu'
# has no proper exit codes currently: https://github.com/gocsaf/csaf/issues/669
# ./csaf-${{ inputs.csaf_version }}-gnulinux-amd64/bin-linux-amd64/csaf_uploader --action create --url http://127.0.0.1/cgi-bin/csaf_provider.go --password password

# Start secvisogram
pushd csaf-validator-service-* && \
nohup npm run dev < /dev/null &> secvisogram.log &
secvisogram_pid=$!
popd
echo $secvisogram_pid > secvisogram.pid
wait-for-it localhost:8082
popd

# Upload documents
find ${{ inputs.source_csaf_documents }} -type f -name '*.json' -print0 | while IFS= read -r -d $'\0' file; do
    echo "Uploading $file"
    ./csaf-${{ inputs.csaf_version }}-gnulinux-amd64/bin-linux-amd64/csaf_uploader --action upload --url http://127.0.0.1/cgi-bin/csaf_provider.go --password password "$file"
done

# Commit changes
# Use https://github.com/stefanzweifel/git-auto-commit-action for commit and push
# TODO
# uses: stefanzweifel/git-auto-commit-action@v6
# commit_message: Update CSAF advisories
# repository: gh-pages
# add_options: -A
