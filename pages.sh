#!/bin/bash

set -x

touch -a .nojekyll
find . -exec ls -l {} \+

find . -name .git -prune -o -type d -print0 | while IFS= read -r -d '' dirname; do
    echo "$dirname"
    pushd "$dirname"
    # with `-o index.html` instead of bash redirection: `tree: invalid filename 'index.html'`
    tree -a -I .git -I index.html --metafirst -h --du -F -D -L 1 -H '' > index.html
    popd
done
