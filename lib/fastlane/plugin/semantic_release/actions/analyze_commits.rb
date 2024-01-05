require 'fastlane/action'
require_relative '../helper/semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
      RELEASE_ANALYZED = :RELEASE_ANALYZED
      RELEASE_IS_NEXT_VERSION_HIGHER = :RELEASE_IS_NEXT_VERSION_HIGHER
      RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH = :RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH
      RELEASE_LAST_TAG_HASH = :RELEASE_LAST_TAG_HASH
      RELEASE_LAST_MAJOR_VERSION = :RELEASE_LAST_MAJOR_VERSION
      RELEASE_LAST_MINOR_VERSION = :RELEASE_LAST_MINOR_VERSION
      RELEASE_LAST_PATCH_VERSION = :RELEASE_LAST_PATCH_VERSION
      RELEASE_LAST_VERSION = :RELEASE_LAST_VERSION
      RELEASE_NEXT_MAJOR_VERSION = :RELEASE_NEXT_MAJOR_VERSION
      RELEASE_NEXT_MINOR_VERSION = :RELEASE_NEXT_MINOR_VERSION
      RELEASE_NEXT_PATCH_VERSION = :RELEASE_NEXT_PATCH_VERSION
      RELEASE_NEXT_VERSION = :RELEASE_NEXT_VERSION
      RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION = :RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION
      CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN = :CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN
    end

    class VersionCode < Struct.new(:major, :minor, :patch)
      def == (obj)
        obj != nil && self.major == obj.major && self.minor == obj.minor && self.patch == obj.patch
      end

      def >(obj)
        self.major > obj.major ||
          self.major == obj.major && (
            self.minor > obj.minor ||
              self.minor == obj.minor && self.patch > obj.patch
          )
      end

      def >=(obj)
        self == obj || self > obj
      end

      def <(obj)
        obj > self
      end

      def <=(obj)
        self == obj || obj > self
      end

      def clone
        VersionCode.new(self.major, self.minor, self.patch)
      end

      def to_s
        "#{major}.#{minor}.#{patch}"
      end
    end

    class AnalyzeCommitsAction < Action
      def self.get_previous_tag_from_commitish(
        commitish:,
        match:,
        debug:
      )
        # Try to find the tag
        command = "git describe --tags --match=#{match} #{commitish}"
        described_tag = Actions.sh(command, log: debug)

        # Tag's format is v2.3.4-5-g7685948
        # See git describe man page for more info
        # It can be also v2.3.4-5 if there is no commit after tag
        tag = described_tag
        if described_tag.split('-').length >= 3
          tag = described_tag.split('-')[0...-2].join('-').strip
        end
        return tag.chomp
      rescue
        UI.message("Tag was not found for match pattern - #{match}")
        ''
      end

      def self.get_hash_from_tag(tag:, debug:)
        if tag.nil? || tag.empty?
          return nil
        end

        command = "git rev-list -n 1 refs/tags/#{tag}"
        Actions.sh(command, log: debug).chomp
      end

      def self.get_version_from_tag(tag:, tag_version_match:)
        if tag.nil? || tag.empty?
          return nil
        end

        parsed_version = tag.match(tag_version_match)

        if parsed_version.nil?
          UI.user_error!("Error while parsing version from tag #{tag} by using tag_version_match - #{tag_version_match}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
        end

        return parsed_version.nil? ? nil : VersionCode.new(
          parsed_version[:major].to_i,
          parsed_version[:minor].to_i,
          parsed_version[:patch].to_i
        )
      end

      def self.get_commits_from_hash(start:, recent_first:, releases:, codepush_friendly:, include_scopes:, ignore_scopes:, debug:)
        commits = Helper::SemanticReleaseHelper.git_log(
          pretty: '%s|%b|%H|%h|>',
          start: start,
          debug: debug,
          recent_first: recent_first
        )
        commits.split("|>")
          .lazy
          .map do |line|
            parts = line.split("|")
            # conventional commits are in format
            # type: subject (fix: app crash - for example)
            Helper::SemanticReleaseHelper.parse_commit(
              commit_hash: parts[2],
              commit_subject: parts[0],
              commit_body: parts[1],
              releases: releases,
              pattern: lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN],
              codepush_friendly: codepush_friendly
            )
          end.select do |commit|
            !Helper::SemanticReleaseHelper.should_exclude_commit(
              commit_scope: commit[:scope],
              include_scopes: include_scopes,
              ignore_scopes: ignore_scopes
            )
          end
      end

      def self.get_root_hash(debug:)
        git_command = "git rev-list --max-parents=0 HEAD"
        hash_lines = Actions.sh("#{git_command} | wc -l", log: debug).chomp
        hash = Actions.sh(git_command, log: debug).chomp

        if hash_lines.to_i > 1
          UI.error("#{git_command} resulted to more than 1 hash")
          UI.error('This usualy happens when you pull only part of a git history. Check out how you pull the repo! "git fetch" should be enough.')
          Actions.sh(git_command, log: true).chomp
          return nil
        end

        hash
      end

      def self.get_head_hash(debug:)
        Actions.sh("git rev-parse HEAD", log: debug).chomp
      end

      def self.get_most_recent_version(
        commitish:,
        tag_version_match:,
        match:,
        prevent_tag_fallback:,
        debug:
      )
        # command to get first commit
        git_command = "git rev-list --max-parents=0 HEAD"

        tag = get_previous_tag_from_commitish(
          commitish: commitish,
          match: match,
          debug: debug
        )

        # if tag doesn't exist it get's first commit or fallback tag (v*.*.*)
        if tag.empty?
          UI.message("It couldn't match tag for #{match}. Check if first commit can be taken as a beginning of next release")
          # If there is no tag found we taking the first commit of current branch
          hash_lines = Actions.sh("#{git_command} | wc -l", log: debug).chomp

          if hash_lines.to_i == 1
            UI.message("First commit of the branch is taken as a begining of next release")
            return {
              # here we know this command will return 1 line
              hash: Actions.sh(git_command, log: debug).chomp
            }
          end

          unless prevent_tag_fallback
            # neither matched tag and first hash could be used - as fallback we try vX.Y.Z
            UI.message("It couldn't match tag for #{match} and couldn't use first commit. Check if tag vX.Y.Z can be taken as a begining of next release")
            tag = get_previous_tag_from_commitish(
              commitish: commitish,
              match: "v*",
              debug: debug
            )
          end

          # even fallback tag doesn't work
          if tag.empty?
            return nil, nil
          end
        end
        
        version = get_version_from_tag(
          tag: tag,
          tag_version_match: tag_version_match
        )
        # Get a hash of last version tag
        hash = get_hash_from_tag(
          tag: tag,
          debug: debug
        )

        return version, hash
      end

      def self.calculate_commit_version(
        commit_hash:,
        fold:,
        tag_version_match:,
        match:,
        prevent_tag_fallback:,
        releases:,
        codepush_friendly:,
        include_scopes:,
        ignore_scopes:,
        print_version_for_each_commit:,
        debug:
      )
        previous_version, previous_version_hash = get_most_recent_version(
          commitish: commit_hash,
          tag_version_match: tag_version_match,
          match: match,
          prevent_tag_fallback: prevent_tag_fallback,
          debug: debug
        ) || [Version.new(0, 0, 0), get_root_hash(debug)]

        commit_version = previous_version.clone()

        commits = get_commits_from_hash(
          start: previous_version_hash,
          recent_first: false,
          releases: releases,
          codepush_friendly: codepush_friendly,
          include_scopes: include_scopes,
          ignore_scopes: ignore_scopes,
          debug: debug,
        )
          .map do |commit|
            if commit[:release] == "major" || commit[:is_breaking_change]
              commit_version.major += 1
              commit_version.minor = 0
              commit_version.patch = 0
            elsif commit[:release] == "minor"
              commit_version.minor += 1
              commit_version.patch = 0
            elsif commit[:release] == "patch"
              commit_version.patch += 1
            end

            if print_version_for_each_commit && !fold
              UI.message("#{commit_version}: #{commit[:subject]}")
                          end

            commit

          # Note that selecting _after_ mapping will cause the enumerator to
          # be driven the extra step needed to match the requested commit hash.
          end.take_while do |commit| 
            commit[:hash] != commit_hash
          end.to_a

        if fold
          if commit_version.major != previous_version.major
            commit_version.major = previous_version.major + 1
            commit_version.minor = 0
            commit_version.patch = 0
          elsif commit_version.minor != previous_version.minor
            commit_version.minor = previous_version.minor + 1
            commit_version.patch = 0
          elsif commit_version.patch != previous_version.patch
            commit_version.patch = previous_version.patch + 1
          end
        end

        if print_version_for_each_commit && fold
          commits.each do |commit|
            UI.message("#{commit_version}: #{commit[:subject]}")
          end
        end

        return commit_version
      end

      def self.calculate_next_version(
        fold:,
        tag_version_match:,
        match:,
        prevent_tag_fallback:,
        releases:,
        codepush_friendly:,
        include_scopes:,
        ignore_scopes:,
        print_version_for_each_commit:,
        debug:
      )
        calculate_commit_version(
          commit_hash: get_head_hash(debug: debug),
          fold: fold,
          tag_version_match: tag_version_match,
          match: match, 
          prevent_tag_fallback: prevent_tag_fallback,
          releases: releases,
          codepush_friendly: codepush_friendly,
          include_scopes: include_scopes,
          ignore_scopes: ignore_scopes,
          print_version_for_each_commit: print_version_for_each_commit,
          debug: debug
        )
      end

      def self.calculate_last_codepush_incompatible_version(
        fold:,
        tag_version_match:,
        match:,
        prevent_tag_fallback:,
        releases:,
        codepush_friendly:,
        include_scopes:,
        ignore_scopes:,
        debug:
      )
        hash = get_root_hash(debug: debug)
        if hash.nil?
          return false
        end

        incompatible_hash = nil

        get_commits_from_hash(
          start: hash,
          recent_first: true,
          releases: releases,
          codepush_friendly: codepush_friendly,
          include_scopes: include_scopes,
          ignore_scopes: ignore_scopes,
          debug: debug
        ).each do |commit|
          if !commit[:is_codepush_friendly]
            incompatible_hash = commit[:hash]
            break
          end
        end

        if incompatible_hash.nil?
          return VersionCode.new(0, 0, 0)
        end

        calculate_commit_version(
          commit_hash: incompatible_hash,
          fold: fold,
          tag_version_match: tag_version_match,
          match: match, 
          prevent_tag_fallback: prevent_tag_fallback,
          releases: releases,
          codepush_friendly: codepush_friendly,
          include_scopes: include_scopes,
          ignore_scopes: ignore_scopes,
          print_version_for_each_commit: false,
          debug: debug
        ) || false
      end

      def self.update_lane_context(last_version, last_version_hash, next_version, last_codepush_incompatible_version)
        Actions.lane_context[SharedValues::RELEASE_ANALYZED] = true
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_HIGHER] = next_version > last_version
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH] = last_version >= last_codepush_incompatible_version
        
        # Last release analysis
        Actions.lane_context[SharedValues::RELEASE_LAST_TAG_HASH] = last_version_hash
        Actions.lane_context[SharedValues::RELEASE_LAST_MAJOR_VERSION] = last_version.major
        Actions.lane_context[SharedValues::RELEASE_LAST_MINOR_VERSION] = last_version.minor
        Actions.lane_context[SharedValues::RELEASE_LAST_PATCH_VERSION] = last_version.patch
        Actions.lane_context[SharedValues::RELEASE_LAST_VERSION] = last_version.to_s
        
        # Next release analysis
        Actions.lane_context[SharedValues::RELEASE_NEXT_MAJOR_VERSION] = next_version.major
        Actions.lane_context[SharedValues::RELEASE_NEXT_MINOR_VERSION] = next_version.minor
        Actions.lane_context[SharedValues::RELEASE_NEXT_PATCH_VERSION] = next_version.patch
        Actions.lane_context[SharedValues::RELEASE_NEXT_VERSION] = next_version.to_s

        Actions.lane_context[SharedValues::RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION] = last_codepush_incompatible_version.to_s
      end

      def self.run(params)
        last_version, last_version_hash = get_most_recent_version(
          commitish: "HEAD",
          tag_version_match: params[:tag_version_match],
          match: params[:match],
          prevent_tag_fallback: params[:prevent_tag_fallback],
          debug: params[:debug]
        )
        UI.message("Last version: #{last_version}")

        next_version = calculate_next_version(
          fold: params[:fold],
          tag_version_match: params[:tag_version_match],
          match: params[:match],
          prevent_tag_fallback: params[:prevent_tag_fallback],
          releases: params[:releases],
          codepush_friendly: params[:codepush_friendly],
          include_scopes: params[:include_scopes],
          ignore_scopes: params[:ignore_scopes],
          print_version_for_each_commit: params[:show_version_path],
          debug: params[:debug]
        )
        UI.message("Next version: #{next_version}")

        last_codepush_incompatible_version = calculate_last_codepush_incompatible_version(
          fold: params[:fold],
          tag_version_match: params[:tag_version_match],
          match: params[:match],
          prevent_tag_fallback: params[:prevent_tag_fallback],
          releases: params[:releases],
          codepush_friendly: params[:codepush_friendly],
          include_scopes: params[:include_scopes],
          ignore_scopes: params[:ignore_scopes],
          debug: params[:debug]
        )

        update_lane_context(last_version, last_version_hash, next_version, last_codepush_incompatible_version)

        if next_version > last_version
          UI.success("Next version (#{next_version}) is higher than last version (#{last_version}). This version should be released.")
        end

        next_version > last_version
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Finds a tag of last release and determinates version of next release"
      end

      def self.details
        "This action will find a last release tag and analyze all commits since the tag. It uses conventional commits. Every time when commit is marked as fix or feat it will increase patch or minor number (you can setup this default behaviour). After all it will suggest if the version should be released or not."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(
            key: :match,
            description: "Match parameter of git describe. See man page of git describe for more info",
            verify_block: proc do |value|
              UI.user_error!("No match for analyze_commits action given, pass using `match: 'expr'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :commit_format,
            description: "The commit format to apply. Presets are 'default' or 'angular', or you can provide your own Regexp. Note: the supplied regex _must_ have 4 capture groups, in order: type, scope, has_exclamation_mark, and subject",
            default_value: "default",
            is_string: false,
            verify_block: proc do |value|
              case value
              when String
                unless Helper::SemanticReleaseHelper.format_patterns.key?(value)
                  UI.user_error!("Invalid format preset: #{value}")
                end

                pattern = Helper::SemanticReleaseHelper.format_patterns[value]
              when Regexp
                pattern = value
              else
                UI.user_error!("Invalid option type: #{value.inspect}")
              end
              Actions.lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN] = pattern
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :releases,
            description: "Map types of commit to release (major, minor, patch)",
            default_value: { fix: "patch", feat: "minor" },
            type: Hash
          ),
          FastlaneCore::ConfigItem.new(
            key: :codepush_friendly,
            description: "These types are consider as codepush friendly automatically",
            default_value: ["chore", "test", "docs"],
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :tag_version_match,
            description: "To parse version number from tag name",
            default_value: '(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)'
          ),
          FastlaneCore::ConfigItem.new(
            key: :prevent_tag_fallback,
            description: "Prevent tag from falling back to vX.Y.Z when there is no match",
            default_value: false,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_scopes,
            description: "To only include certain scopes when calculating releases",
            default_value: [],
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :ignore_scopes,
            description: "To ignore certain scopes when calculating releases",
            default_value: [],
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :fold,
            description: "Whether to fold multiple version changes into one (i.e. increment from e.g. v1.2.3 to v2.0.0 rather than v8.5.2)",
            default_value: false,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :show_version_path,
            description: "True if you want to print out the version calculated for each commit",
            default_value: true,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :debug,
            description: "True if you want to log out a debug info",
            default_value: false,
            type: Boolean,
            optional: true
          )
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['RELEASE_ANALYZED', 'True if commits were analyzed.'],
          ['RELEASE_IS_NEXT_VERSION_HIGHER', 'True if next version is higher then last version'],
          ['RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH', 'True if next version is compatible with codepush'],
          ['RELEASE_LAST_TAG_HASH', 'Hash of commit that is tagged as a last version'],
          ['RELEASE_LAST_MAJOR_VERSION', 'Major number of the last version'],
          ['RELEASE_LAST_MINOR_VERSION', 'Minor number of the last version'],
          ['RELEASE_LAST_PATCH_VERSION', 'Patch number of the last version'],
          ['RELEASE_LAST_VERSION', 'Last version number - parsed from last tag.'],
          ['RELEASE_NEXT_MAJOR_VERSION', 'Major number of the next version'],
          ['RELEASE_NEXT_MINOR_VERSION', 'Minor number of the next version'],
          ['RELEASE_NEXT_PATCH_VERSION', 'Patch number of the next version'],
          ['RELEASE_NEXT_VERSION', 'Next version string in format (major.minor.patch)'],
          ['RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION', 'Last commit without codepush'],
          ['CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN', 'The format pattern Regexp used to match commits (mainly for internal use)']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns true if the next version is higher then the last version"
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["xotahal"]
      end

      def self.is_supported?(platform)
        # you can do things like
        true
      end
    end
  end
end
