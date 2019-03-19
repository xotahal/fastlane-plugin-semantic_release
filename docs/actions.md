## Actions

### analyze_commits

- analyzes your git history
- finds last tag on current branch (for example ios/beta/1.3.2)
- parses the last version from tag (1.3.2)
- gets all commits since this tag
- analyzes subject of every single commit and increases version number if there is a need (check conventional commit rules)
- if next version number is higher then last version number it will recommend you to release this version

Please run `fastlane action analyze_commits` to see all documentation in your command line.

```
isReleasable = analyze_commits(match: 'ios/beta*')
```

It leave these variables in lane_context. You can get them by `lane_context[SharedValues::RELEASE_NEXT_VERSION]` - for example.

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

### conventional_changelog

- parses all commits since last version
- group those commits by their type (fix, feat, docs, refactor, chore, etc)
- and creates formated release notes either in markdown or in slack format

```
notes = conventional_changelog(format: 'slack', title: 'Android Alpha')
```
