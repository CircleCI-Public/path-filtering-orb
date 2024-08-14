#!/bin/sh
set -ex

# Workaround old docker images with incorrect $HOME
# check https://github.com/docker/docker/issues/2968 for details
if [ "${HOME}" = "/" ]; then
    ID_UN="$(id -un)"
    HOME="$(getent passwd "${ID_UN}" | cut -d: -f6)"
    export HOME
fi

# known_hosts / id_rsa
export SSH_CONFIG_DIR="${SSH_CONFIG_DIR:-"${HOME}/.ssh"}"
echo "Using SSH Config Dir '$SSH_CONFIG_DIR'"
git --version

mkdir -p "$SSH_CONFIG_DIR"
chmod 0700 "$SSH_CONFIG_DIR"

if [ -x "$(command -v ssh-keyscan)" ] && { [ "${KEYSCAN_GITHUB}" = "true" ] || [ "${KEYSCAN_BITBUCKET}" = "true" ]; }; then
    if [ "${KEYSCAN_GITHUB}" = "true" ]; then
    ssh-keyscan -H github.com >> "$SSH_CONFIG_DIR/known_hosts"
    fi
    if [ "${KEYSCAN_BITBUCKET}" = "true" ]; then
    ssh-keyscan -H bitbucket.org >> "$SSH_CONFIG_DIR/known_hosts"
    fi
fi

# see: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
if [ "${KEYSCAN_GITHUB}" != "true" ]; then
    echo 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
' >> "$SSH_CONFIG_DIR/known_hosts"
fi

# see: https://bitbucket.org/blog/ssh-host-key-changes
if [ "${KEYSCAN_BITBUCKET}" != "true" ]; then
    echo 'bitbucket.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPIQmuzMBuKdWeF4+a2sjSSpBK0iqitSQ+5BM9KhpexuGt20JpTVM7u5BDZngncgrqDMbWdxMWWOGtZ9UgbqgZE=
    bitbucket.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIazEu89wgQZ4bqs3d63QSMzYVa0MuJ2e2gKTKqu+UUO
    bitbucket.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDQeJzhupRu0u0cdegZIa8e86EG2qOCsIsD1Xw0xSeiPDlCr7kq97NLmMbpKTX6Esc30NuoqEEHCuc7yWtwp8dI76EEEB1VqY9QJq6vk+aySyboD5QF61I/1WeTwu+deCbgKMGbUijeXhtfbxSxm6JwGrXrhBdofTsbKRUsrN1WoNgUa8uqN1Vx6WAJw1JHPhglEGGHea6QICwJOAr/6mrui/oB7pkaWKHj3z7d1IC4KWLtY47elvjbaTlkN04Kc/5LFEirorGYVbt15kAUlqGM65pk6ZBxtaO3+30LVlORZkxOh+LKL/BvbZ/iRNhItLqNyieoQj/uh/7Iv4uyH/cV/0b4WDSd3DptigWq84lJubb9t/DnZlrJazxyDCulTmKdOR7vs9gMTo+uoIrPSb8ScTtvw65+odKAlBj59dhnVp9zd7QUojOpXlL62Aw56U4oO+FALuevvMjiWeavKhJqlR7i5n9srYcrNV7ttmDw7kf/97P5zauIhxcjX+xHv4M=
' >> "$SSH_CONFIG_DIR/known_hosts"
fi

echo 'gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
' >> "$SSH_CONFIG_DIR/known_hosts"
chmod 0600 "$SSH_CONFIG_DIR/known_hosts"

rm -f "$SSH_CONFIG_DIR/id_rsa"
(umask 077; touch "$SSH_CONFIG_DIR/id_rsa")
printf "%s" "$CHECKOUT_KEY" > "$SSH_CONFIG_DIR/id_rsa"
chmod 0600 "$SSH_CONFIG_DIR/id_rsa"
if (: "${CHECKOUT_KEY_PUBLIC?}") 2>/dev/null; then
    rm -f "$SSH_CONFIG_DIR/id_rsa.pub"
    printf "%s" "$CHECKOUT_KEY_PUBLIC" > "$SSH_CONFIG_DIR/id_rsa.pub"
fi

# shellcheck disable=SC2016
export GIT_SSH_COMMAND='ssh -i "$SSH_CONFIG_DIR/id_rsa" -o UserKnownHostsFile="$SSH_CONFIG_DIR/known_hosts"'

# use git+ssh instead of https
git config --global url."ssh://git@github.com".insteadOf "https://github.com" || true
git config --global gc.auto 0 || true

# Define Tag args
if [ -n "$CIRCLE_TAG" ]; then
    # only tags operation have default --tags. others will no tag options
    clone_tag_args=
    fetch_tag_args="--tags"
fi
if [ "${NO_TAGS}" = 'true' ]; then
    clone_tag_args="--no-tags"
    fetch_tag_args="--no-tags"
fi

# Replace "~" in `$CIRCLE_WORKING_DIRECTORY` to `$HOME`
working_directory=$(echo "$CIRCLE_WORKING_DIRECTORY" | sed -e "s|^~|$HOME|g")

# Checkout. SourceCaching? or not.
if [ -e "$working_directory/${REPO_PATH}/.git" ]; then
    echo 'Fetching into existing repository'
    cd "$working_directory/${REPO_PATH}"
    git remote set-url origin "$CIRCLE_REPOSITORY_URL" || true
else
    echo 'Cloning git repository'
    mkdir -p "$working_directory/${REPO_PATH}"
    cd "$working_directory/${REPO_PATH}"
    git clone ${clone_tag_args} --depth "${DEPTH}" "$CIRCLE_REPOSITORY_URL" .
fi

# NOTE: Original checkout fetch only if SourceCaching, but we fetch always for depth selection.
echo 'Fetching from remote repository'
if [ -n "$CIRCLE_TAG" ]; then
    git fetch ${fetch_tag_args} --depth "${FETCH_DEPTH}" --force --tags origin "+refs/tags/${CIRCLE_TAG}:refs/tags/${CIRCLE_TAG}"
elif echo "$CIRCLE_BRANCH" | grep -E '^pull\/[0-9]+/head$' > /dev/null; then
    # pull request called from api. Input should be `pull/123/head` see detail for https://github.com/guitarrapc/git-shallow-clone-orb/issues/34
    git fetch ${fetch_tag_args} --depth "${FETCH_DEPTH}" --force origin "+refs/${CIRCLE_BRANCH}:remotes/origin/${CIRCLE_BRANCH}"
else
    git fetch ${fetch_tag_args} --depth "${FETCH_DEPTH}" --force origin "+refs/heads/${CIRCLE_BRANCH}:refs/remotes/origin/${CIRCLE_BRANCH}"
fi

# Check the commit ID of the checked out code
if [ -n "$CIRCLE_TAG" ]; then
    echo 'Checking out tag'
    git checkout --force "$CIRCLE_TAG"
    git reset --hard "$CIRCLE_SHA1" # move to triggered SHA
elif [ -n "$CIRCLE_BRANCH" ] && [ "$CIRCLE_BRANCH" != 'HEAD' ]; then
    echo 'Checking out branch'
    git checkout --force -B "$CIRCLE_BRANCH"
    git reset --hard "$CIRCLE_SHA1" # move to triggered SHA
    git --no-pager log --no-color -n 1 --format='HEAD is now at %h %s'
fi
