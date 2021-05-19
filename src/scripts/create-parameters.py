#!/usr/bin/env python3

import json
import os
import re
import subprocess

output_path = os.environ.get('OUTPUT_PATH')
head = os.environ.get('CIRCLE_SHA1')
base = subprocess.run(
  ['git', 'merge-base', os.environ.get('BASE_REVISION'), head],
  check=True,
  capture_output=True
).stdout.decode('utf-8').strip()

if head == base:
  try:
    # If building on the same branch as BASE_REVISION, we will get the
    # current commit as merge base. In that case try to go back to the
    # first parent, i.e. the last state of this branch before the
    # merge, and use that as the base.
    base = subprocess.run(
      ['git', 'rev-parse', 'HEAD~1'], # FIXME this breaks on the first commit, fallback to something
      check=True,
      capture_output=True
    ).stdout.decode('utf-8').strip()
  except:
    # This can fail if this is the first commit of the repo, so that
    # HEAD~1 actually doesn't resolve. In this case we can compare
    # against this magic SHA below, which is the empty tree. The diff
    # to that is just the first commit as patch.
    base = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

print('Comparing {}...{}'.format(base, head))
# Get all of the commit hashes, subjects, and bodies between base and head
commits = subprocess.run(
  ['git', 'log', '--format=%H,%s,%b', f'{base}...{head}'],
  check=True,
  capture_output=True
).stdout.decode('utf-8').splitlines()

# Filter the commits list so it doesn't contain any that include '[skip ci]' or '[ci skip]'
commits = list(filter(lambda commit: '[skip ci]' not in commit and '[ci skip]' not in commit, commits))

changes = []

# Get the list of changed files for each commit and put them in a list
for commit in commits:
  commit_hash = commit.split(',', maxsplit=1)[0]
  change = subprocess.run(
    [f'git log --name-only -1 --format=\'\' {commit_hash}'],
    check=True,
    shell=True,
    capture_output=True
  ).stdout.decode('utf-8').splitlines()
  changes += change

# Remove any duplicate values from the list
changes = list(dict.fromkeys(changes))

mappings = [
  m.split() for m in
  os.environ.get('MAPPING').splitlines()
]

def check_mapping(m):
  if 3 != len(m):
    raise Exception("Invalid mapping")
  path, param, value = m
  regex = re.compile(r'^' + path + r'$')
  for change in changes:
    if regex.match(change):
      return True
  return False

def convert_mapping(m):
  return [m[1], json.loads(m[2])]

mappings = filter(check_mapping, mappings)
mappings = map(convert_mapping, mappings)
mappings = dict(mappings)

with open(output_path, 'w') as fp:
  fp.write(json.dumps(mappings))

