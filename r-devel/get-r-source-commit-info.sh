#!/usr/bin/env bash

# GitHub repo info
owner="wch"
repo="r-source"
ref="trunk"

output_file="$PWD/r-source-commit-info.txt"

set -ex

# ==============================================================================
# Clone repo if necessary, and update to latest commit
# ==============================================================================
# If r-source directory doesn't exist, clone the repo.
if [ ! -d "r-source" ]; then
    git clone --branch $ref --depth 1 https://github.com/$owner/$repo.git
fi

cd r-source
git checkout trunk
git pull

# ==============================================================================
# Get the commit information and write it all to a file.
# ==============================================================================
commit=$(git rev-parse HEAD)
echo "commit=$commit" > "$output_file"

commit_date=$(git log -1 --pretty=format:"%ad" --date=iso | cut -d' ' -f1)
echo "commit-date=$commit_date" >> "$output_file"

svn_id=$(
  git log --format=%B -n 1 \
  | grep "^git-svn-id" \
  | sed -E 's/^git-svn-id: https:\/\/svn.r-project.org\/R\/[^@]*@([0-9]+).*$/\1/'
)
echo "svn-id=$svn_id" >> "$output_file"

version_string=$(cat VERSION | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*$/\1/')
echo "version-string=$version_string" >> "$output_file"


# Get the sha-256 hash of the contents
git worktree add -f worktree_sha256
# Need to remove .git file to get correct hash
rm worktree_sha256/.git
sha256=$(nix hash path worktree_sha256)
echo "sha256=$sha256" >> "$output_file"
# Since we removed worktree_sha256/.git, this will prune it from the list of
# worktrees.
git worktree prune
rm -rf worktree_sha256
