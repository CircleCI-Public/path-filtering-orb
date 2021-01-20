CHANGED_FILES=$(git diff --name-only "$BASE_REVISION" HEAD)
export CHANGED_FILES

python - <<EOF
import json
import os
import re

output_path = os.environ.get('OUTPUT_PATH')
changes = os.environ.get('CHANGED_FILES')
mappings = []

with open(os.environ.get('MAPPING'), 'r') as fp:
  for line in fp.readlines():
    mappings.append(line.split())

def check_mapping(m):
  if 3 != len(m):
    raise Exception("Invalid mapping")
  path, param, value = m
  regex = re.compile(path)
  for change in changes:
    if regex.match(change):
      return True
  return False

def convert_mapping(m):
  return [m[1], m[2]]

mappings = filter(check_mapping, mappings)
mappings = map(convert_mapping, mappings)
mappings = dict(mappings)

with open(output_path, 'w') as fp:
  fp.write(json.dumps(mappings))
EOF
