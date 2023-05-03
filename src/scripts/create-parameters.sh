#!/bin/sh

curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
python3 get-pip.py --user

python3 -m pip install --user virtualenv

echo "Create python virtual environment for path-filtering"

python3 -m venv path-filtering-venv
# shellcheck source=/dev/null
. path-filtering-venv/bin/activate

echo "Creating pipeline parameters"
python3 create-parameters.py

echo "Deactivate python virtual environment for path-filtering"
deactivate



