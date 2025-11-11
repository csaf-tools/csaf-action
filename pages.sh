#!/bin/bash

# SPDX-FileCopyrightText: 2025 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
#
# SPDX-License-Identifier: Apache-2.0

touch -a .nojekyll
set -euo pipefail

# Change all permissions from www-data to current user (runner), otherwise we can't write to all directories
sudo chown -R "$USER":"$USER" .

# resolve all (absolute) symbolic links
find . -name .git -prune -o -type l -print0 | while IFS= read -r -d '' linkname; do
    target="$(readlink -f "$linkname")"
    filename="$(basename "$linkname")"
    pushd "$(dirname "$linkname")" || exit
    echo "resolve link $linkname"
    rm "$filename"
    mkdir "$filename"
    # we can assume there are no hidden files to copy and all directories are non-empty
    cp -r "$target"/* "$filename/"
    popd || exit
done

if [[ "${generate_index_files:-false}" == "true" ]]; then
    # generate an index.html files for each directory
    find .well-known/csaf/ -name .git -prune -o -type d -print0 | while IFS= read -r -d '' dirname; do
        echo "$dirname"
        pushd "$dirname" || exit
        # tree version 2.1.1 (Ubuntu 24.04) requires -H '.', tree version 2.2.1 requires -H ''
        tree -a -I .git -I index.html -I .nojekyll -T "CSAF Advisories" --metafirst -h --du -F -D -L 1 -H '.' --houtro="${tree_outro_filename:-/dev/null}" -o index.html
        popd || exit
    done
fi
