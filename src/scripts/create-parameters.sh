#!/bin/bash
function mergeBase() {
  local merged_base
  merged_base=$(git merge-base "$1" "$2")
  echo "$merged_base"
}

function parentCommit() {
  local parent_commit
  parent_commit=$(git rev-parse HEAD~1)
  echo "$parent_commit"
}

function changedFiles() {
  local changed_files
  changed_files=$(git -c core.quotepath=false diff --name-only "$base" "$head")
  echo "$changed_files"
}

function createParameters() {
  base=$BASE_REVISION
  head=$CIRCLE_SHA1

  git checkout "$base"
  git checkout "$head"
  base=$(mergeBase "$base" "$head")

  if [[ "$head" == "$base" ]]; then
    # If building on the same branch as BASE_REVISION, we will get the
    # current commit as merge base. In that case try to go back to the
    # first parent, i.e. the last state of this branch before the
    # merge, and use that as the base.

    # This can fail if this is the first commit of the repo, so that
    # HEAD~1 actually doesn't resolve. In this case we can compare
    # against this magic SHA below, which is the empty tree. The diff
    # to that is just the first commit as patch.

    base=$(parentCommit) || "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
  fi

  echo "Comparing $base...$head"
  changed_files=$(changedFiles)

  echo "Changes files $changed_files"

  if [[ -f $MAPPING ]]; then
    echo "Found the mappin file: $MAPPING"

    jq -Rs --rawfile "$MAPPING"
  else
    echo "Use mapping provided in the parameter"

    echo "$MAPPING"
  fi

}

