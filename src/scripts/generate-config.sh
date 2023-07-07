#!/usr/bin/env bash

# GitHub's URL for the latest release, will redirect.
GITHUB_BASE_URL="https://github.com/cue-lang/cue"
LATEST_URL="${GITHUB_BASE_URL}/releases/latest/"
DESTDIR="${DESTDIR:-/usr/local/bin}"

function installCue() {
  echo "Checking For CUE + CURL"
  if command -v curl >/dev/null 2>&1 && ! command -v cue >/dev/null 2>&1; then
    if [ -z "$VERSION" ]; then
      VERSION=$(curl -sLI -o /dev/null -w '%{url_effective}' "$LATEST_URL" | cut -d "v" -f 2)
    fi

    echo "Installing CUE v${VERSION}"

    uname -a | grep Darwin > /dev/null 2>&1 && OS='darwin' || OS='linux'

    RELEASE_URL="${GITHUB_BASE_URL}/releases/download/v${VERSION}/cue_v${VERSION}_${OS}_amd64.tar.gz"

    # save the current checkout dir
    CHECKOUT_DIR=$(pwd)

    SCRATCH=$(mktemp -d || mktemp -d -t 'tmp')
    cd "$SCRATCH" || exit

    curl -sL --retry 3 "${RELEASE_URL}" | tar zx

    echo "Installing to $DESTDIR"
    sudo install cue "$DESTDIR"

    command -v cue >/dev/null 2>&1

    echo "Installation finished"
    # Delete the working directory when the install was successful.
    cd "$CHECKOUT_DIR" || exit
    rm -r "$SCRATCH"
    return $?
  else
    command -v curl >/dev/null 2>&1 || { echo >&2 "PATH-FILTERING ORB ERROR: CURL is required. Please install."; exit 1; }
    command -v cue >/dev/null 2>&1 || { echo >&2 "PATH-FILTERING ORB ERROR: CUE is required. Please install"; exit 1; }
    return $?
  fi
}

function generateConfig() {
  echo "Config list ==="

  cat "${PARAM_CONFIG_LIST_PATH}"

  echo
  echo "Generated YAML ==="

  touch "${PARAM_GENERATED_CONFIG_PATH}"

  < "${PARAM_CONFIG_LIST_PATH}" \
  awk 'NF {gsub(/"/, "\\\"", $0); printf "\"%s\" ", $0}' \
  | xargs -0 -I {} sh -c 'cue export {} --out yaml' \
  | tee "${PARAM_GENERATED_CONFIG_PATH}"
}

installCue
generateConfig
