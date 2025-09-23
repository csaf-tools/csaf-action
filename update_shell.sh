#!/bin/bash

echo -e '#!/bin/bash\n' >| commands.sh

# environment variables
yq -r '.env' action.yml | grep : | sed -r 's/^ *"?([a-zA-Z0-9_.-]+)"?: "?([^,"]+)"?,?/\1="\2"/' >> commands.sh

echo >> commands.sh

yq -r '.runs.steps[].run' action.yml | grep -v '^null$' | sed -r 's/\$\{\{ *env\.([^ ]+) *\}\}/\$\1/g' >> commands.sh