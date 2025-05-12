#!/usr/bin/env bash

# GitHub's URL for the latest release, will redirect.
GITHUB_BASE_URL="https://github.com/mikefarah/yq"
DESTDIR="${DESTDIR:-/usr/local/bin}"
VERSION="4.34.1"

function installYq() {
  echo "Checking For yq + CURL"
  if command -v curl >/dev/null 2>&1 && ! command -v yq >/dev/null 2>&1; then
    echo "Installing yq v${VERSION}"

    uname -a | grep Darwin > /dev/null 2>&1 && OS='darwin' || OS='linux'
    PLATFORM=$(uname -m)
    RELEASE_URL="${GITHUB_BASE_URL}/releases/download/v${VERSION}/yq_${OS}_${PLATFORM}"

    # save the current checkout dir
    CHECKOUT_DIR=$(pwd)

    SCRATCH=$(mktemp -d || mktemp -d -t 'tmp')
    cd "$SCRATCH" || exit

    wget "${RELEASE_URL}" -O /usr/local/bin/yq &&\
    chmod +x /usr/local/bin/yq

    command -v yq >/dev/null 2>&1

    echo "Installation finished"
    # Delete the working directory when the install was successful.
    cd "$CHECKOUT_DIR" || exit
    rm -r "$SCRATCH"
    return $?
  else
    command -v curl >/dev/null 2>&1 || { echo >&2 "PATH-FILTERING ORB ERROR: CURL is required. Please install."; exit 1; }
    command -v yq >/dev/null 2>&1 || { echo >&2 "PATH-FILTERING ORB ERROR: yq is required. Please install"; exit 1; }
    return $?
  fi
}

function generateConfig() {
  echo "Config list ==="

  cat "${PARAM_CONFIG_LIST_PATH}"

  echo
  echo "Generated YAML ==="

  touch "${PARAM_GENERATED_CONFIG_PATH}"

  # shellcheck disable=SC2154,SC2016
  < "${PARAM_CONFIG_LIST_PATH}" \
  awk 'NF {$1=$1; printf "\"%s\" ", $0}' \
  | xargs yq eval-all 'explode(.) | . as $item ireduce ({}; . * $item )' \
  | tee "${PARAM_GENERATED_CONFIG_PATH}"
}

installYq
generateConfig
