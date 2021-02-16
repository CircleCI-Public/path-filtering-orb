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
  base = subprocess.run(
    ['git', 'rev-parse', 'HEAD~1'],
    check=True,
    capture_output=True
  ).stdout.decode('utf-8').strip()
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

