import json
import os
import re
import subprocess
import sys
import urllib.request
import urllib.error
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


def get_github_org_from_url(git_url):
  """
  Extract GitHub organization name from a git URL

  :param git_url: Git URL in the format git@github.com:org/repo.git
  :return: Organization name
  """
  # Check if the URL is in the expected format
  if git_url.startswith('git@github.com:'):
    # Split by colon and get the second part
    parts = git_url.split(':')[1]
    # Split by slash and get the first part
    org_name = parts.split('/')[0]
    return org_name

  return None

def merge_base(base, head):
  return subprocess.run(
    ['git', 'merge-base', base, head],
    check=True,
    capture_output=True
  ).stdout.decode('utf-8').strip()

def extract_vcs_revision(json_data):
  """
  Parses JSON data and extracts the 'vcs_revision' from the first element
  if the data is a list, or directly if it's a dictionary.

  Args:
      json_data (str): A string containing the JSON response.

  Returns:
      str: The vcs_revision value, or None if not found or on error.
  """
  try:
    data = json.loads(json_data)

    # Check if the response is a list (like from the CircleCI builds endpoint)
    if isinstance(data, list):
      if data:  # Check if the list is not empty
        first_item = data[0]
        if isinstance(first_item, dict) and 'vcs_revision' in first_item:
          return first_item['vcs_revision']
        else:
          print("Error: First item in the list is not a dictionary or does not contain 'vcs_revision'.",
                file=sys.stderr)
          return None
      else:
        print("Error: JSON response is an empty list.", file=sys.stderr)
        return None
    # Check if the response is a dictionary itself
    elif isinstance(data, dict):
      if 'vcs_revision' in data:
        return data['vcs_revision']
      else:
        print("Error: JSON dictionary does not contain 'vcs_revision'.", file=sys.stderr)
        return None
    else:
      print("Error: Unexpected JSON structure.", file=sys.stderr)
      return None

  except json.JSONDecodeError as e:
    print(f"Error decoding JSON: {e}", file=sys.stderr)
    return None
  except Exception as e:
    print(f"An unexpected error occurred: {e}", file=sys.stderr)
    return None

def parent_commit(merge_queue_support):
  branch = os.environ.get('CIRCLE_BRANCH')
  repo_name = os.environ.get('CIRCLE_PROJECT_REPONAME')
  org_name = get_github_org_from_url(os.environ.get('CIRCLE_REPOSITORY_URL'))

  # If using GitHub's merge queue, several commits can be merged into the main branch
  # at once, but only one webhook is sent for the entire merge queue. In this case, we need to
  # use the CircleCI API to get the last commit that was built for the branch to ensure
  # we are using the correct commit as the base for our diff.
  if merge_queue_support and (branch == 'master' or branch == 'main'):
    print(f"Merge Queue support is enabled, using CircleCI API to get the previously built commit on {branch}")
    # make a request to CircleCI API to get the latest build for the branch, we'll use that as our base
    url = f'https://circleci.com/api/v1.1/project/github/{org_name}/{repo_name}/tree/{branch}?limit=1'

    req = urllib.request.Request(
      url,
      headers={'Accept': 'application/json', 'Circle-Token': os.environ.get('CIRCLECI_ACCESS_TOKEN')}
    )

    try:
      # Make the request and get the response
      with urllib.request.urlopen(req) as response:
        data = response.read().decode(response.headers.get_content_charset("utf-8"))
    except urllib.error.HTTPError as e:
      raise Exception(f"HTTP Error: {e.code} - {e.reason}")
    except urllib.error.URLError as e:
      raise Exception(f"URL Error: {e.reason}")

    previous_sha = extract_vcs_revision(data)
    print (f"Previous SHA: {previous_sha}")
    return previous_sha

  else:
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

filtered_config_list_file = "/tmp/filtered-config-list"

def write_filtered_config_list(config_files):
  with open(filtered_config_list_file, 'w') as fp:
    fp.writelines(config_files)

def write_mappings(mappings, output_path):
  with open(output_path, 'w') as fp:
    fp.write(json.dumps(mappings))

def write_parameters_from_mappings(mappings, changes, output_path, config_path):
  if not mappings:
    raise Exception("Mapping cannot be empty!")

  if not output_path:
    raise Exception("Output-path parameter is not found")

  element_count = len(mappings[0])

  # currently the supported format for each of the mapping parameter is either:
  # path-regex pipeline-parameter pipeline-parameter-value
  # OR
  # path-regex pipeline-parameter pipeline-parameter-value config-file
  if not (element_count == 3 or element_count == 4):
    raise Exception("Invalid mapping length of {}".format(element_count))

  filtered_mapping = []
  filtered_files = set()

  for m in mappings:
    if len(m) != element_count:
      raise Exception("Expected {} fields but found {}".format(element_count, len(m)))

    if element_count == 3:
      path, param, param_value = m
      config_file = None
    else:
      path, param, param_value, config_file = m

    try:
      decoded_param_value = json.loads(param_value)
    except ValueError:
      raise Exception("Cannot parse pipeline value {} from mapping".format(param_value))

    # type check pipeline parameters - should be one of integer, string, or boolean
    if not isinstance(decoded_param_value, (int, str, bool)):
      raise Exception("""
        Pipeline parameters can only be integer, string or boolean type.
        Found {} of type {}
        """.format(decoded_param_value, type(decoded_param_value)))

    regex = re.compile(r'^' + path + r'$')
    for change in changes:
      if regex.match(change):
        filtered_mapping.append([param, decoded_param_value])
        if config_file:
          filtered_files.add(config_file + "\n")
        break

  if not filtered_mapping:
    print("No change detected in the paths defined in the mapping parameter")

  write_mappings(dict(filtered_mapping), output_path)

  if not filtered_files:
    filtered_files.add(config_path)

  write_filtered_config_list(filtered_files)

def is_mapping_line(line: str) -> bool:
  is_empty_line = (line.strip() == "")
  is_comment_line = (line.strip().startswith("#"))
  return not (is_comment_line or is_empty_line)

def create_parameters(output_path, config_path, head, base, mapping, merge_queue_support):
  checkout(base)  # Checkout base revision to make sure it is available for comparison
  checkout(head)  # return to head commit
  base = merge_base(base, head)

  print(f"Merge Queue support: {merge_queue_support}")

  if head == base:
    try:
      # If building on the same branch as BASE_REVISION, we will get the
      # current commit as merge base. In that case try to go back to the
      # first parent, i.e. the last state of this branch before the
      # merge, and use that as the base.
      base = parent_commit(merge_queue_support)
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
        m.split() for m in f.read().splitlines() if is_mapping_line(m)
      ]
  else:
    mappings = [
      m.split() for m in
      mapping.splitlines() if is_mapping_line(m)
    ]

  write_parameters_from_mappings(mappings, changes, output_path, config_path)


if __name__ == "__main__":
  create_parameters(
    os.environ.get('OUTPUT_PATH'),
    os.environ.get('CONFIG_PATH'),
    os.environ.get('CIRCLE_SHA1'),
    os.environ.get('BASE_REVISION'),
    os.environ.get('MAPPING'),
    os.environ.get('MERGE_QUEUE_SUPPORT', 'False').lower() in ('true', '1', 't')
  )
