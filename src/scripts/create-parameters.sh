#!/bin/bash
set -e
set -o pipefail

# create-parameters.py uses only the Python standard library, so no pip /
# virtualenv bootstrap is required. We just need a python3 on PATH, which
# the cimg/python executor already provides.

echo "${CREATE_PIPELINE_SCRIPT}" > circleci_create_parameters_script.py

echo "Creating pipeline parameters"
python3 circleci_create_parameters_script.py
