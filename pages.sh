#!/bin/bash

touch -a .nojekyll
set -euo pipefail

# Change all permissions from www-data to runner, otherwise we can't write to all directories
sudo chown -R runner:runner .

# convert absolute symbolic links to relative symbolic links, otherwise gh pages can't deploy because of broken absolute symbolic links
find . -name .git -prune -o -type l -print0 | while IFS= read -r -d '' linkname; do
    target="$(readlink -f "$linkname")"
    filename="$(basename "$linkname")"
    pushd "$(dirname "$linkname")" || exit
    echo "rewrite link $linkname"
    rm "$filename"
    ln -sfr "$target" "$filename"
    popd || exit
done

# generate a index.html files for each directory
find . -name .git -prune -o -type d -print0 | while IFS= read -r -d '' dirname; do
    echo "$dirname"
    pushd "$dirname" || exit
    # tree version 2.1.1 (Ubuntu 24.04) requires -H '.', tree version 2.2.1 requires -H ''
    tree -a -I .git -I index.html -I .nojekyll -T "CSAF Advisories" --metafirst -h --du -F -D -L 1 -H '.' -o index.html
    popd || exit
done
