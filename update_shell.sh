#!/bin/bash

echo -e '#!/bin/bash\n' >| commands.sh

# environment variables
yq eval '.inputs | to_entries[] | .key + "=\"" + (.value.default | tostring) + "\""' action.yml >> commands.sh

echo >> commands.sh

yq -r '.runs.steps[].run' action.yml | grep -v '^null$' | sed -r 's/\$\{\{ *env\.([^ ]+) *\}\}/\$\1/g' >> commands.sh

sed -ri \
    -e 's/\$\{\{ inputs\.([^ ]+) }}/\${\1}/g' \
    -e 's/\$\{\{ github.action_path }}/./' \
    -e 's/\$\{\{ steps.pagesurl.outputs\.([^ ]+) }}/\${outputs_\1}/g' \
    -e 's/^publisher_name=""/publisher_name="Example Company"/' \
    -e 's#^publisher_namespace=""#publisher_namespace="https://example.com"#' \
    -e 's/^publisher_issuing_authority=""/publisher_issuing_authority="We at Example Company are responsible for publishing and maintaining Product Y."/' \
    -e 's#^publisher_contact_details=""#publisher_contact_details="Example Company can be reached at contact_us@example.com or via our website at https://www.example.com/contact."#' \
    -e 's#^source_csaf_documents="csaf_documents/"#source_csaf_documents="test/inputs/"#' \
    -e 's/echo "url=([^"]+)".*?"/outputs_url=\1/' \
    commands.sh
