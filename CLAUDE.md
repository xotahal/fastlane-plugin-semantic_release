# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all tests + linting (default rake task)
bundle exec rake

# Run only tests
bundle exec rake spec

# Run only linting
bundle exec rake rubocop

# Run a single test file
bundle exec rspec spec/analyze_commits_spec.rb

# Run a specific test by name
bundle exec rspec spec/analyze_commits_spec.rb -e "should increment fix and return true"

# Install dependencies
bundle install
```

## Architecture

This is a fastlane plugin that provides two actions for semantic versioning based on conventional commits:

### Actions (the two entry points)

1. **`AnalyzeCommitsAction`** (`lib/fastlane/plugin/semantic_release/actions/analyze_commits.rb`) — Analyzes git commits since the last tag and determines the next semantic version. Sets shared values in `lane_context` (e.g., `RELEASE_NEXT_VERSION`, `RELEASE_IS_NEXT_VERSION_HIGHER`) that downstream actions consume.

2. **`ConventionalChangelogAction`** (`lib/fastlane/plugin/semantic_release/actions/conventional_changelog.rb`) — Generates formatted release notes (markdown/slack/plain) from commits. **Must run after** `analyze_commits` since it reads `RELEASE_ANALYZED` and format pattern from `lane_context`.

### Helper

**`SemanticReleaseHelper`** (`lib/fastlane/plugin/semantic_release/helper/semantic_release_helper.rb`) — Shared utilities: commit parsing via regex, git log execution, scope filtering, semver comparison. Defines format patterns (`default` and `angular`) with 4 capture groups: type, scope, breaking indicator, subject.

### Data flow

`analyze_commits` → sets `lane_context` shared values → `conventional_changelog` reads them to generate notes. Actions communicate exclusively through `Fastlane::Actions::SharedValues` constants.

### Commit format

Follows conventional commits: `<type>(<scope>)<!>: <subject>`. Breaking changes detected via `!` suffix or `BREAKING CHANGE:` in body. Default type-to-bump mapping: `fix→patch`, `feat→minor`, breaking→major.

## Testing Patterns

Tests mock git commands rather than running real git operations:
```ruby
allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)
```

Lanes are executed in tests via `Fastlane::FastFile.new.parse()` and results checked through `lane_context` shared values.

## Code Style

- Rubocop enforced with `Style/MethodCallWithArgsParentheses` enabled (parentheses required on method calls, with exceptions for DSL methods like `require`, `describe`, `it`, etc.)
- Double negation (`!!`) is allowed
- No frozen string literal comments required
- Target Ruby version: 2.0
