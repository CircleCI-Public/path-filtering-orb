# Path Filtering Orb
[![CircleCI Build Status](https://circleci.com/gh/CircleCI-Public/path-filtering-orb.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/affinity/path-filtering-orb) [![CircleCI Orb Version](https://badges.circleci.com/orbs/affinity/path-filtering.svg)](https://circleci.com/developer/orbs/orb/affinity/path-filtering) [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/affinity/path-filtering-orb/master/LICENSE) [![CircleCI Community](https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg)](https://discuss.circleci.com/c/ecosystem/orbs)

Additional READMEs are available in each directory.

**Meta**: This repository is open for contributions! Feel free to open a pull request with your changes. Due to the nature of this repository, it is not built on CircleCI. The Resources and How to Contribute sections relate to an orb created with this template, rather than the template itself.

## Resources

[Dynamic Config](https://circleci.com/docs/2.0/dynamic-config) - CircleCI functionality that the path-filtering-orb contributes to

[Setup Workflows Documentation](https://github.com/CircleCI-Public/api-preview-docs/blob/master/docs/setup-workflows.md#concepts) - Doc explaining a special type of workflow used in dynamic config

[CircleCI Orb Registry Page](https://circleci.com/developer/orbs/orb/circleci/path-filtering) - The official registry page of this orb for all versions, executors, commands, and jobs described.

[CircleCI Orb Docs](https://circleci.com/docs/2.0/orb-intro/#section=configuration) - Docs for using, creating, and publishing CircleCI Orbs.

### How to Contribute

We welcome [issues](https://github.com/CircleCI-Public/path-filtering-orb/issues) to and [pull requests](https://github.com/CircleCI-Public/path-filtering-orb/pulls) against this repository!

### Development

To develop this orb, you can use the `circleci orb pack src > /tmp/orb.yml` command to generate and validate the orb.yml file.
Publish a dev version with:
```shell
circleci orb publish /tmp/orb.yml affinity/path-filtering@dev:first
```

Test it out in your CircleCI workflow by adding the following to your `.circleci/config.yml`:
```yaml
orbs:
  path-filtering: affinity/path-filtering@dev:first
```

Publish it for use with:
```shell
  circleci orb publish /tmp/orb.yml affinity/path-filtering@<version tag created below>
```

### How to Publish An New Release
1. Merge pull requests with desired changes to the main branch.
    - For the best experience, squash-and-merge and use [Conventional Commit Messages](https://conventionalcommits.org/).
2. Find the current version of the orb.
    - You can run `circleci orb info circleci/path-filtering | grep "Latest"` to see the current version.
3. Create a [new Release](https://github.com/CircleCI-Public/path-filtering-orb/releases/new) on GitHub.
    - Click "Choose a tag" and _create_ a new [semantically versioned](http://semver.org/) tag. (ex: v1.0.0)
      - We will have an opportunity to change this before we publish if needed after the next step.
4.  Click _"+ Auto-generate release notes"_.
    - This will create a summary of all of the merged pull requests since the previous release.
    - If you have used _[Conventional Commit Messages](https://conventionalcommits.org/)_ it will be easy to determine what types of changes were made, allowing you to ensure the correct version tag is being published.
5. Now ensure the version tag selected is semantically accurate based on the changes included.
6. Click _"Publish Release"_.
