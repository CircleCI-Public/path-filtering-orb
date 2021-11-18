#!/usr/bin/env python3

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
changes = subprocess.run(
  ['git', 'diff', '--name-only', base, head],
  check=True,
  capture_output=True
).stdout.decode('utf-8').splitlines()

mappings = [
  m.split() for m in
  os.environ.get('MAPPING').splitlines()
]

def check_mapping(m):
  if 2 > len(m):
    raise Exception("Invalid mapping")
  pattern, paths = m
  regex = re.compile(r'^' + pattern + r'$')
  for change in changes:
    if regex.match(change):
      return True
  return False

def get_paths(m):
  return m[1:len(m)]

def flatten_paths(t):
    return [item for sublist in t for item in sublist]

mappings = filter(check_mapping, mappings)
mappings = map(get_paths, mappings)
paths = list(set(flatten_paths(mappings)))

if 0 == len(paths):
  print('No YAML configs to merge.')

  halt_process = subprocess.run(["circleci-agent", "step",  "halt"])
else:
  print('YAML files to merge: ', paths)
  print(*paths, sep='\n')

  merge_yaml_process = subprocess.run(["xargs", paths, "yq", "-y", "-s", "reduce .[] as $item ({}; . * $item)"], capture_output=True)

  with open(output_path, 'w') as fp:
    fp.write(merge_yaml_process.stdout.decode('utf-8'))