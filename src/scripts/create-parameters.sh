#!/bin/bash 
set -e
set -o pipefail

if [ -f .python-version ]; then
    # Create a temp directory
    circleci_temp_dir="$(mktemp -d)"
    # Move .python-version out of the directory
    mv .python-version "$circleci_temp_dir"/.python-version
fi

curl "https://bootstrap.pypa.io/get-pip.py" -o "circleci_get_pip.py"
python3 circleci_get_pip.py --user

python3 -m pip install --user virtualenv

echo "Create python virtual environment for path-filtering"
virtualenv path-filtering-venv -p /usr/bin/python3

echo "Activate python virtual environment"
# shellcheck source=/dev/null
. path-filtering-venv/bin/activate

echo "${CREATE_PIPELINE_SCRIPT}" > circleci_create_parameters_script.py

echo "Creating pipeline parameters"
python3 circleci_create_parameters_script.py

if [ -f "$circleci_temp_dir"/.python-version ]; then
    # Move .python-version back
    mv "$circleci_temp_dir"/.python-version .python-version
fi

echo "Deactivate python virtual environment for path-filtering"
deactivate
