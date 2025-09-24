#!/bin/bash

set -x

touch -a .nojekyll

# convert absolute symbolic links to relative symbolic links, otherwise gh pages can't deploy because of broken absolute symbolic links
find . -name .git -prune -o -type l -print0 | while IFS= read -r -d '' linkname; do
    target=$(readlink -f $linkname)
    filename=$(basename $linkname)
    pushd $(dirname $linkname)
    echo "linkname $linkname"
    rm $filename
    ln -sfr $target $filename
    popd
done

# generate a index.html files for each directory
find . -name .git -prune -o -type d -print0 | while IFS= read -r -d '' dirname; do
    echo "$dirname"
    pushd "$dirname"
    # with `-o index.html` instead of bash redirection: `tree: invalid filename 'index.html'`
    tree -a -I .git -I index.html --metafirst -h --du -F -D -L 1 -H '' > index.html
    popd
done
