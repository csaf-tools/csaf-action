#!/bin/bash

echo -e '#!/bin/bash\n' >| commands.sh

# environment variables
yq -r '.env' .github/workflows/run.yml | grep : | sed -r 's/^ *"?([a-zA-Z0-9_.-]+)"?: "?([^,"]+)"?,?/\1="\2"/' >> commands.sh

echo >> commands.sh

yq -r '.jobs.unittests.steps[].run' .github/workflows/run.yml | grep -v '^null$' | sed -r 's/\$\{\{ *env\.([^ ]+) *\}\}/\$\1/g' >> commands.sh