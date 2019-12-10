# semantic_release plugin for `fastlane`

[![CircleCI](https://circleci.com/gh/xotahal/fastlane-plugin-semantic_release.svg?style=svg)](https://circleci.com/gh/xotahal/fastlane-plugin-semantic_release) [![License](https://img.shields.io/github/license/SiarheiFedartsou/fastlane-plugin-versioning.svg)](https://github.com/SiarheiFedartsou/fastlane-plugin-versioning/blob/master/LICENSE) [![Gem Version](https://badge.fury.io/rb/fastlane-plugin-semantic_release.svg)](https://badge.fury.io/rb/fastlane-plugin-semantic_release) [![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-versioning)

## Getting Started

```
fastlane add_plugin semantic_release
```

## About

Automated version managment and generator of release notes. Inspired by [semantic-release](https://github.com/semantic-release/semantic-release) for npm packages. Based on [conventional commits](https://www.conventionalcommits.org/).

### Articles

[Semantic Release for Fastlane](https://medium.com/@xotahal/semantic-release-for-fastlane-781df4cf5888?source=friends_link&sk=5c02e32daca7a68539e27e0e1bac1092) @ Medium - By Jiri Otahal

## Available Actions

### `conventional_changelog`

- parses all commits since last version
- groups those commits by their type (fix, feat, docs, refactor, chore, etc)
- and creates formated release notes either in markdown or in slack format

Available parameters:

- `format: 'slack|markdown|plain'` (defaults to `markdown`). This formats the changelog for the destination you need. If you're using this for TestFlight changelogs, we suggest using the `plain` option
- `title: 'My Title'` - is appended to the release notes title, "1.1.8 My Title (YYYY-MM-DD)"
- `display_title: true|false` (defaults to true) - allows you to hide the entire first line of the changelog
- `display_links: true|false` (defaults to true) - allows you to hide links to commits from your changelog
- `commit_url: 'https://github.com/username/repository/commit'` - prepended to the commit ID to build usable links
- View other options by searching for `available_options` in `conventional_changelog.rb`

Example:

```
notes = conventional_changelog(format: 'slack', title: 'Android Alpha')
```

<img src="https://raw.githubusercontent.com/xotahal/fastlane-plugin-semantic_release/master/docs/Changelog.png" />

### `analyze_commits`

- analyzes your git history
- finds last tag on current branch (for example ios/beta/1.3.2)
- parses the last version from tag (1.3.2)
- gets all commits since this tag
- analyzes subject of every single commit and increases version number if there is a need (check conventional commit rules)
- if next version number is higher then last version number it will recommend you to release this version

Options:

- `ignore_scopes: ['android','windows']`: allows you to ignore any commits which include a given scope, like this one: `feat(android): add functionality not relevant to the release we are producing`

Example usage:

```
isReleasable = analyze_commits(match: 'ios/beta*')
```

It provides these variables in `lane_context`.

```
['RELEASE_ANALYZED', 'True if commits were analyzed.'],
['RELEASE_IS_NEXT_VERSION_HIGHER', 'True if next version is higher then last version'],
['RELEASE_LAST_TAG_HASH', 'Hash of commit that is tagged as a last version'],
['RELEASE_LAST_VERSION', 'Last version number - parsed from last tag.'],
['RELEASE_NEXT_MAJOR_VERSION', 'Major number of the next version'],
['RELEASE_NEXT_MINOR_VERSION', 'Minor number of the next version'],
['RELEASE_NEXT_PATCH_VERSION', 'Patch number of the next version'],
['RELEASE_NEXT_VERSION', 'Next version string in format (major.minor.patch)'],
```

And you can access these like this:

`next_version = lane_context[SharedValues::RELEASE_NEXT_VERSION]`

<img src="https://raw.githubusercontent.com/xotahal/fastlane-plugin-semantic_release/master/docs/Analyze.png" />

## Tests

To run the test suite (contained in `./spec`), call `bundle exec rake`

## Questions

If you need anything ping us on [twitter](http://bit.ly/t-xotahal).

| Jiri Otahal                                                                                                                            |
| -------------------------------------------------------------------------------------------------------------------------------------- |
| [<img src="https://avatars3.githubusercontent.com/u/3531955?v=4" width="100px;" style="border-radius:50px"/>](http://bit.ly/t-xotahal) |
