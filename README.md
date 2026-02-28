# semantic_release plugin for `fastlane`

[![CI](https://github.com/xotahal/fastlane-plugin-semantic_release/actions/workflows/ci.yml/badge.svg)](https://github.com/xotahal/fastlane-plugin-semantic_release/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-semantic_release.svg)](https://badge.fury.io/rb/fastlane-plugin-semantic_release)
[![License](https://img.shields.io/github/license/xotahal/fastlane-plugin-semantic_release.svg)](https://github.com/xotahal/fastlane-plugin-semantic_release/blob/master/LICENSE)
[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-semantic_release)

## Table of Contents

- [Getting Started](#getting-started)
- [About](#about)
- [Commit Format](#commit-format)
- [Quick Start](#quick-start)
- [Available Actions](#available-actions)
  - [analyze_commits](#analyze_commits)
  - [conventional_changelog](#conventional_changelog)
- [Examples](#examples)
- [Development](#development)
- [Questions](#questions)

## Getting Started

```bash
fastlane add_plugin semantic_release
```

## About

Automated version management and generator of release notes. Inspired by [semantic-release](https://github.com/semantic-release/semantic-release) for npm packages. Based on [conventional commits](https://www.conventionalcommits.org/).

<img src="https://raw.githubusercontent.com/xotahal/fastlane-plugin-semantic_release/master/docs/Analyze.png" />

### Articles

[Semantic Release for Fastlane](https://medium.com/@xotahal/semantic-release-for-fastlane-781df4cf5888?source=friends_link&sk=5c02e32daca7a68539e27e0e1bac1092) @ Medium - By Jiri Otahal

## Commit Format

This plugin expects commits to follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>
```

Examples:

```
fix(auth): resolve login crash on Android
feat: add dark mode support
feat(api)!: change response format
docs: update installation guide
```

**Breaking changes** are detected in two ways:
- Adding `!` after the type/scope: `feat(api)!: change response format`
- Including `BREAKING CHANGE:` in the commit body

### Default type-to-bump mapping

| Type | Version Bump |
|------|-------------|
| `fix` | patch |
| `feat` | minor |
| Breaking change | major |

Other types (`docs`, `chore`, `refactor`, `perf`, `test`, `style`) do not trigger a version bump by default, but will appear in the changelog. You can customize this mapping with the `releases` parameter.

### Format patterns

Two built-in commit format patterns are available via the `commit_format` parameter:

- **`default`** — Matches: `docs`, `fix`, `feat`, `chore`, `style`, `refactor`, `perf`, `test`
- **`angular`** — Matches any word as a type (more permissive)

You can also pass a custom `Regexp` with 4 capture groups: type, scope, breaking indicator (`!`), and subject.

## Quick Start

Here is a minimal Fastfile showing the typical workflow — analyze commits, then generate a changelog:

```ruby
lane :release do
  # 1. Analyze commits to determine next version
  is_releasable = analyze_commits(match: 'v*')

  if is_releasable
    next_version = lane_context[SharedValues::RELEASE_NEXT_VERSION]

    # 2. Generate changelog from commits
    notes = conventional_changelog(
      format: 'markdown',
      commit_url: 'https://github.com/user/repo/commit'
    )

    # 3. Use the version and notes however you need
    # For example: tag, push, create GitHub release, etc.
    add_git_tag(tag: "v#{next_version}")
    push_git_tags

    set_github_release(
      repository_name: 'user/repo',
      tag_name: "v#{next_version}",
      description: notes
    )
  end
end
```

## Available Actions

### `analyze_commits`

Analyzes your git history since the last matching tag, determines the next semantic version, and returns `true` if a release is recommended.

How it works:
1. Finds the last tag matching your pattern (e.g., `v*`, `ios/beta*`)
2. Parses the version number from that tag
3. Gets all commits since the tag
4. Analyzes each commit subject against conventional commit rules
5. Calculates the next version based on commit types
6. Returns `true` if the next version is higher than the last

Example:

```ruby
is_releasable = analyze_commits(match: 'ios/beta*')
```

#### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `match` | **Required.** Match pattern for `git describe` to find the last tag (e.g., `'v*'`, `'ios/beta*'`) | — |
| `commit_format` | Commit format preset (`'default'` or `'angular'`) or a custom `Regexp` with 4 capture groups | `'default'` |
| `releases` | Hash mapping commit types to release levels | `{ fix: 'patch', feat: 'minor' }` |
| `bump_per_commit` | When `true`, each matching commit increments the version. When `false`, only bump once per release type (matching semantic-release behavior) | `true` |
| `ignore_scopes` | Array of scopes to exclude from analysis | `[]` |
| `include_scopes` | Array of scopes to exclusively include (overrides `ignore_scopes`) | `[]` |
| `tag_version_match` | Regex to extract the version number from a tag name | `'\d+\.\d+\.\d+'` |
| `prevent_tag_fallback` | When `true`, don't fall back to `vX.Y.Z` tags if no match is found | `false` |
| `codepush_friendly` | Commit types considered CodePush-compatible | `['chore', 'test', 'docs']` |
| `ignore_breaking_changes` | When `true`, breaking changes will not trigger a major version bump | `false` |
| `show_version_path` | Print the calculated version for each commit | `true` |
| `debug` | Enable verbose debug logging | `false` |

#### Shared values (lane_context)

After running, the following values are available via `lane_context[SharedValues::KEY]`:

| Key | Description |
|-----|-------------|
| `RELEASE_ANALYZED` | `true` if commits were analyzed |
| `RELEASE_IS_NEXT_VERSION_HIGHER` | `true` if next version is higher than last version |
| `RELEASE_LAST_TAG_HASH` | Hash of the commit tagged as the last version |
| `RELEASE_LAST_VERSION` | Last version number parsed from the tag |
| `RELEASE_NEXT_VERSION` | Next version string (e.g., `'1.2.3'`) |
| `RELEASE_NEXT_MAJOR_VERSION` | Major number of the next version |
| `RELEASE_NEXT_MINOR_VERSION` | Minor number of the next version |
| `RELEASE_NEXT_PATCH_VERSION` | Patch number of the next version |
| `RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH` | `true` if the next version is CodePush-compatible |
| `RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION` | Last version containing CodePush-incompatible changes |

Access them like this:

```ruby
next_version = lane_context[SharedValues::RELEASE_NEXT_VERSION]
```

### `conventional_changelog`

Generates formatted release notes from commits since the last version. **Must run after `analyze_commits`.**

- Parses all commits since the last version
- Groups commits by type (feat, fix, docs, refactor, etc.)
- Creates formatted release notes in markdown, slack, or plain text

<img src="https://raw.githubusercontent.com/xotahal/fastlane-plugin-semantic_release/master/docs/Changelog.png" />

Example:

```ruby
notes = conventional_changelog(format: 'slack', title: 'Android Alpha')
```

#### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `format` | Output format: `'markdown'`, `'slack'`, or `'plain'` | `'markdown'` |
| `title` | Text appended to the version in the title (e.g., `'Android Alpha'` produces `'1.2.3 Android Alpha (2025-01-15)'`) | — |
| `commit_url` | Base URL for commit links (e.g., `'https://github.com/user/repo/commit'`) | — |
| `order` | Array controlling the order of sections in the output | `['feat', 'fix', 'refactor', 'perf', 'chore', 'test', 'docs', 'no_type']` |
| `sections` | Hash mapping commit types to section titles | `{ feat: 'Features', fix: 'Bug fixes', ... }` |
| `display_title` | Show the title/header line with version and date | `true` |
| `display_links` | Show links to individual commits | `true` |
| `display_author` | Show the author name for each commit | `false` |
| `ignore_scopes` | Array of scopes to exclude | `[]` |
| `include_scopes` | Array of scopes to exclusively include | `[]` |
| `ignore_breaking_changes` | When `true`, the breaking changes section will not appear in the changelog. Also reads from `lane_context` if set by `analyze_commits` | `false` |
| `debug` | Enable verbose debug logging | `false` |

## Examples

### Scope filtering

Build separate changelogs for different platforms:

```ruby
# Only analyze iOS-scoped commits
analyze_commits(match: 'ios/v*', include_scopes: ['ios'])

# Ignore Android-specific commits
analyze_commits(match: 'v*', ignore_scopes: ['android', 'windows'])
```

### Custom release mapping

Map additional commit types to version bumps:

```ruby
analyze_commits(
  match: 'v*',
  releases: { fix: 'patch', feat: 'minor', refactor: 'patch' }
)
```

### Ignoring breaking changes

Prevent breaking change markers from triggering major version bumps. The `!` suffix and `BREAKING CHANGE:` in the commit body will be ignored for both version bumping and changelog output:

```ruby
analyze_commits(match: 'v*', ignore_breaking_changes: true)
notes = conventional_changelog(format: 'markdown')
```

### Plain text changelog for TestFlight

```ruby
notes = conventional_changelog(format: 'plain', display_links: false)
upload_to_testflight(changelog: notes)
```

## Development

### Running tests

```bash
# Run all tests and linting
bundle exec rake

# Run only tests
bundle exec rake spec

# Run only linting
bundle exec rake rubocop
```

## Questions

If you have any issues or feature requests, please [open an issue](https://github.com/xotahal/fastlane-plugin-semantic_release/issues) on GitHub.

| Jiri Otahal |
| --- |
| [<img src="https://avatars3.githubusercontent.com/u/3531955?v=4" width="100px;" style="border-radius:50px"/>](https://github.com/xotahal) |
