#!/usr/bin/env python3

import json
import os
import re
import subprocess
import shutil
from functools import partial

def checkout(revision):
  """
  Helper function for checking out a branch

  :param revision: The revision to checkout
  :type revision: str
  """
  subprocess.run(
    ['git', 'checkout', revision],
    check=True
  )

def merge_base(base, head):
  return subprocess.run(
    ['git', 'merge-base', base, head],
    check=True,
    capture_output=True
  ).stdout.decode('utf-8').strip()

def parent_commit():
  return subprocess.run(
    ['git', 'rev-parse', 'HEAD~1'],
    check=True,
    capture_output=True
  ).stdout.decode('utf-8').strip()

def changed_files(base, head):
  return subprocess.run(
    ['git', '-c', 'core.quotepath=false', 'diff', '--name-only', base, head],
    check=True,
    capture_output=True
  ).stdout.decode('utf-8').splitlines()

def check_mapping(changes, m):
  if len(m) !=3 or len(m) !=4:
    raise Exception("Invalid mapping")
  path, _param, _value = m
  regex = re.compile(r'^' + path + r'$')
  for change in changes:
    if regex.match(change):
      return True
  return False

def convert_mapping(m):
  return [m[1], json.loads(m[2])]

def write_config_list(mappings, config_file):
  files_used = set()
  for m in mappings:
    if len(m) == 3:
      f = config_file
    elif len(m) == 4:
      f = m[3]

    if f not in files_used:
      files_used.add(f)

  with open("/tmp/config-list", 'w') as fp:
    for line in files_used:
      fp.write(line)
      fp.write(b"\n")


def write_mappings(mappings, output_path):
  with open(output_path, 'w') as fp:
    fp.write(json.dumps(mappings))

def create_parameters(output_path, head, base, mapping):
  checkout(base)  # Checkout base revision to make sure it is available for comparison
  checkout(head)  # return to head commit
  base = merge_base(base, head)

  if head == base:
    try:
      # If building on the same branch as BASE_REVISION, we will get the
      # current commit as merge base. In that case try to go back to the
      # first parent, i.e. the last state of this branch before the
      # merge, and use that as the base.
      base = parent_commit()
    except:
      # This can fail if this is the first commit of the repo, so that
      # HEAD~1 actually doesn't resolve. In this case we can compare
      # against this magic SHA below, which is the empty tree. The diff
      # to that is just the first commit as patch.
      base = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

  print('Comparing {}...{}'.format(base, head))
  changes = changed_files(base, head)

  if os.path.exists(mapping):
    with open(mapping) as f:
      mappings = [
        m.split() for m in f.read().splitlines()
      ]
  else:
    mappings = [
      m.split() for m in
      mapping.splitlines()
    ]
  mappings = filter(partial(check_mapping, changes), mappings)
  # output a merged continue-config.yml if mappings have a fourth parameter,
  # which is a config path
  write_merged_config_files(mappings, output_path)

  mappings = map(convert_mapping, mappings)
  mappings = dict(mappings)
  write_mappings(mappings, output_path)

create_parameters(
  os.environ.get('OUTPUT_PATH'),
  os.environ.get('CIRCLE_SHA1'),
  os.environ.get('BASE_REVISION'),
  os.environ.get('MAPPING')
)
