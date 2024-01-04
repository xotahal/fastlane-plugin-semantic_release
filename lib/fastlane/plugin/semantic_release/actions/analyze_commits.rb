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
      def self.get_last_tag(params)
        # Try to find the tag
        command = "git describe --tags --match=#{params[:match]}"
        Actions.sh(command, log: params[:debug])
      rescue
        UI.message("Tag was not found for match pattern - #{params[:match]}")
        ''
      end

      def self.get_last_tag_hash(params)
        command = "git rev-list -n 1 refs/tags/#{params[:tag_name]}"
        Actions.sh(command, log: params[:debug]).chomp
      end

      def self.get_commits_from_hash(start:, releases:, codepush_friendly:, include_scopes:, ignore_scopes:, debug:)
        commits = Helper::SemanticReleaseHelper.git_log(
          pretty: '%s|%b|%H|%h|>',
          start: start,
          debug: debug
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

      def self.get_beginning_of_next_sprint(params)
        # command to get first commit
        git_command = "git rev-list --max-parents=0 HEAD"

        tag = get_last_tag(match: params[:match], debug: params[:debug])

        # if tag doesn't exist it get's first commit or fallback tag (v*.*.*)
        if tag.empty?
          UI.message("It couldn't match tag for #{params[:match]}. Check if first commit can be taken as a beginning of next release")
          # If there is no tag found we taking the first commit of current branch
          hash_lines = Actions.sh("#{git_command} | wc -l", log: params[:debug]).chomp

          if hash_lines.to_i == 1
            UI.message("First commit of the branch is taken as a begining of next release")
            return {
              # here we know this command will return 1 line
              hash: Actions.sh(git_command, log: params[:debug]).chomp
            }
          end

          unless params[:prevent_tag_fallback]
            # neither matched tag and first hash could be used - as fallback we try vX.Y.Z
            UI.message("It couldn't match tag for #{params[:match]} and couldn't use first commit. Check if tag vX.Y.Z can be taken as a begining of next release")
            tag = get_last_tag(match: "v*", debug: params[:debug])
          end

          # even fallback tag doesn't work
          if tag.empty?
            return false
          end
        end

        # Tag's format is v2.3.4-5-g7685948
        # See git describe man page for more info
        # It can be also v2.3.4-5 if there is no commit after tag
        tag_name = tag
        if tag.split('-').length >= 3
          tag_name = tag.split('-')[0...-2].join('-').strip
        end
        parsed_version = tag_name.match(params[:tag_version_match])

        if parsed_version.nil?
          UI.user_error!("Error while parsing version from tag #{tag_name} by using tag_version_match - #{params[:tag_version_match]}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
        end

        version = parsed_version.nil? ? nil : VersionCode.new(
          parsed_version[:major].to_i,
          parsed_version[:minor].to_i,
          parsed_version[:patch].to_i
        )
        # Get a hash of last version tag
        hash = get_last_tag_hash(
          tag_name: tag_name,
          debug: params[:debug]
        )

        UI.message("Found a tag #{tag_name} associated with version #{version}")

        return {
          hash: hash,
          version: version
        }
      end

      def self.calculate_versions(params, beginning)
        # If the tag is not found we are taking HEAD as reference
        hash = beginning[:hash] || 'HEAD'
        last_version = beginning[:version] || VersionCode.new(0, 0, 0)
        next_version = last_version.clone()

        is_next_version_compatible_with_codepush = true

        # Get commits log between last version and head
        commits = get_commits_from_hash(
          start: hash,
          releases: params[:releases],
          codepush_friendly: params[:codepush_friendly],
          include_scopes: params[:include_scopes],
          ignore_scopes: params[:ignore_scopes],
          debug: params[:debug]
        ).to_a

        UI.message("Found #{commits.length} commits since last release")
        releases = params[:releases]

        format_pattern = lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN]
        commits.each do |commit|
          if commit[:release] == "major" || commit[:is_breaking_change]
            next_version.major += 1
            next_version.minor = 0
            next_version.patch = 0
          elsif commit[:release] == "minor"
            next_version.minor += 1
            next_version.patch = 0
          elsif commit[:release] == "patch"
            next_version.patch += 1
          end

          unless commit[:is_codepush_friendly]
            is_next_version_compatible_with_codepush = false
          end

          UI.message("#{next_version}: #{commit[:subject]}") if params[:show_version_path]
        end

        return last_version, next_version
      end

      def self.calculate_last_codepush_incompatible_version(params)
        git_command = "git rev-list --max-parents=0 HEAD"
        # Begining of the branch is taken for codepush analysis
        hash_lines = Actions.sh("#{git_command} | wc -l", log: params[:debug]).chomp
        hash = Actions.sh(git_command, log: params[:debug]).chomp
        next_version = VersionCode.new(0, 0, 0)
        incompatible_version = next_version

        if hash_lines.to_i > 1
          UI.error("#{git_command} resulted to more than 1 hash")
          UI.error('This usualy happens when you pull only part of a git history. Check out how you pull the repo! "git fetch" should be enough.')
          Actions.sh(git_command, log: true).chomp
          return false
        end

        # Get commits log between last version and head
        get_commits_from_hash(
          start: hash,
          releases: params[:releases],
          codepush_friendly: params[:codepush_friendly],
          include_scopes: params[:include_scopes],
          ignore_scopes: params[:ignore_scopes],
          debug: params[:debug]
        ).each do |commit|
          if commit[:release] == "major" || commit[:is_breaking_change]
            next_version.major += 1
            next_version.minor = 0
            next_version.patch = 0
          elsif commit[:release] == "minor"
            next_version.minor += 1
            next_version.patch = 0
          elsif commit[:release] == "patch"
            next_version.patch += 1
          end

          unless commit[:is_codepush_friendly]
            incompatible_version = next_version.clone()
          end
        end

        incompatible_version
      end

      def self.update_lane_context(beginning, last_version, next_version, last_codepush_incompatible_version)
        Actions.lane_context[SharedValues::RELEASE_ANALYZED] = true
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_HIGHER] = next_version > last_version
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH] = last_version >= last_codepush_incompatible_version
        
        # Last release analysis
        Actions.lane_context[SharedValues::RELEASE_LAST_TAG_HASH] = beginning[:hash] || "HEAD"
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
        beginning = get_beginning_of_next_sprint(params)
        unless beginning
          UI.error('It could not find a begining of this sprint. How to fix this:')
          UI.error('-- ensure there is only one commit with --max-parents=0 (this command should return one line: "git rev-list --max-parents=0 HEAD")')
          UI.error('-- tell us explicitely where the release starts by adding tag like this: vX.Y.Z (where X.Y.Z is version from which it starts computing next version number)')
          return false
        end

        last_version, next_version = calculate_versions(params, beginning)
        last_codepush_incompatible_version = calculate_last_codepush_incompatible_version(params)

        update_lane_context(beginning, last_version, next_version, last_codepush_incompatible_version)

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
