#!/bin/bash

output_file="local_execution.sh"

echo -e '#!/bin/bash\n' >| "$output_file"

# environment variables
yq eval '.inputs | to_entries[] | .key + "=\"" + (.value.default | tostring) + "\""' action.yml >> "$output_file"

echo >> "$output_file"

yq -r '.runs.steps[].run' action.yml | grep -v '^null$' | sed -r 's/\$\{\{ *env\.([^ ]+) *\}\}/\$\1/g' >> "$output_file"

sed -ri \
    -e 's/\$\{\{ inputs\.([^ ]+) }}/\${\1}/g' \
    -e 's/\$\{\{ github.action_path }}/./' \
    -e 's/\$\{\{ steps.pagesurl.outputs\.([^ ]+) }}/\${outputs_\1}/g' \
    -e 's/\$\{?GITHUB_WORKSPACE\}?/./g' \
    -e 's/^publisher_name=""/publisher_name="Example Company"/' \
    -e 's#^publisher_namespace=""#publisher_namespace="https://example.com"#' \
    -e 's/^publisher_issuing_authority=""/publisher_issuing_authority="We at Example Company are responsible for publishing and maintaining Product Y."/' \
    -e 's#^publisher_contact_details=""#publisher_contact_details="Example Company can be reached at contact_us@example.com or via our website at https://www.example.com/contact."#' \
    -e 's#^source_csaf_documents="csaf_documents/"#source_csaf_documents="test/inputs/"#' \
    -e 's/echo "url=([^"]+)".*?"/outputs_url=\1/' \
    -e 's/^url=/rm -rf gh-pages\ngit clone -b gh-pages . gh-pages\n\nurl=/' \
    "$output_file"
