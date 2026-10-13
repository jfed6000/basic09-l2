#!/bin/sh
# Export the NitrOS-9 main repositories into a build copy.
#
#   recipes/export-main.sh <main dir> <dest dir>
#
# <main dir> holds the pristine clones (nitros9, nitros9-languages,
# nitros9-apps, nitros9-games).  Each one's committed HEAD is written
# to <dest dir>/<repo> with "git archive", which only reads the clone,
# so builds never touch it.  A copy is replaced only when its HEAD has
# changed (the commit is kept in <dest dir>/<repo>.head).
set -e
main=$1
dest=$2
[ -n "$main" ] && [ -n "$dest" ] || { echo "usage: $0 <main dir> <dest dir>" >&2; exit 2; }
mkdir -p "$dest"
for repo in nitros9 nitros9-languages nitros9-apps nitros9-games; do
    src=$main/$repo
    [ -d "$src/.git" ] || { echo "$src: not a git clone" >&2; exit 1; }
    head=$(git -C "$src" rev-parse HEAD)
    if [ -n "$(git --no-optional-locks -C "$src" status --porcelain --untracked-files=no)" ]; then
        echo "warning: $src has uncommitted changes; exporting HEAD only" >&2
    fi
    if [ -d "$dest/$repo" ] && [ "$(cat "$dest/$repo.head" 2>/dev/null)" = "$head" ]; then
        continue
    fi
    echo "export $repo $(git -C "$src" log -1 --format='%h %ad %s' --date=short)"
    rm -rf "$dest/$repo" "$dest/$repo.head"
    mkdir "$dest/$repo"
    git -C "$src" archive --format=tar HEAD | tar -x -C "$dest/$repo"
    echo "$head" > "$dest/$repo.head"
done
