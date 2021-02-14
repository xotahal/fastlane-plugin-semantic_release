require 'fastlane/action'
require_relative '../helper/semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
      RELEASE_ANALYZED = :RELEASE_ANALYZED
      RELEASE_IS_NEXT_VERSION_HIGHER = :RELEASE_IS_NEXT_VERSION_HIGHER
      RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH = :RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH
      RELEASE_LAST_TAG_HASH = :RELEASE_LAST_TAG_HASH
      RELEASE_LAST_VERSION = :RELEASE_LAST_VERSION
      RELEASE_NEXT_MAJOR_VERSION = :RELEASE_NEXT_MAJOR_VERSION
      RELEASE_NEXT_MINOR_VERSION = :RELEASE_NEXT_MINOR_VERSION
      RELEASE_NEXT_PATCH_VERSION = :RELEASE_NEXT_PATCH_VERSION
      RELEASE_NEXT_VERSION = :RELEASE_NEXT_VERSION
      RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION = :RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION
      CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN = :CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN
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

      def self.get_commits_from_hash(params)
        commits = Helper::SemanticReleaseHelper.git_log(
          pretty: '%s|%b|>',
          start: params[:hash],
          debug: params[:debug]
        )
        commits.split("|>")
      end

      def self.is_releasable(params)
        # Hash of the commit where is the last version
        # If the tag is not found we are taking HEAD as reference
        hash = 'HEAD'
        # Default last version
        version = '0.0.0'

        tag = get_last_tag(
          match: params[:match],
          debug: params[:debug]
        )

        if tag.empty?
          UI.message("First commit of the branch is taken as a begining of next release")
          # If there is no tag found we taking the first commit of current branch
          hash = Actions.sh('git rev-list --max-parents=0 HEAD', log: params[:debug]).chomp
        else
          # Tag's format is v2.3.4-5-g7685948
          # See git describe man page for more info
          tag_name = tag.split('-')[0...-2].join('-').strip
          parsed_version = tag_name.match(params[:tag_version_match])

          if parsed_version.nil?
            UI.user_error!("Error while parsing version from tag #{tag_name} by using tag_version_match - #{params[:tag_version_match]}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
          end

          version = parsed_version[0]
          # Get a hash of last version tag
          hash = get_last_tag_hash(
            tag_name: tag_name,
            debug: params[:debug]
          )

          UI.message("Found a tag #{tag_name} associated with version #{version}")
        end

        # converts last version string to the int numbers
        next_major = (version.split('.')[0] || 0).to_i
        next_minor = (version.split('.')[1] || 0).to_i
        next_patch = (version.split('.')[2] || 0).to_i

        is_next_version_compatible_with_codepush = true

        # Get commits log between last version and head
        splitted = get_commits_from_hash(
          hash: hash,
          debug: params[:debug]
        )

        UI.message("Found #{splitted.length} commits since last release")
        releases = params[:releases]

        format_pattern = lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN]
        splitted.each do |line|
          parts = line.split("|")
          subject = parts[0].strip
          # conventional commits are in format
          # type: subject (fix: app crash - for example)
          commit = Helper::SemanticReleaseHelper.parse_commit(
            commit_subject: subject,
            commit_body: parts[1],
            releases: releases,
            pattern: format_pattern
          )

          unless commit[:scope].nil?
            # if this commit has a scope, then we need to inspect to see if that is one of the scopes we're trying to exclude
            scope = commit[:scope]
            scopes_to_ignore = params[:ignore_scopes]
            # if it is, we'll skip this commit when bumping versions
            next if scopes_to_ignore.include?(scope) #=> true
          end

          if commit[:release] == "major" || commit[:is_breaking_change]
            next_major += 1
            next_minor = 0
            next_patch = 0
          elsif commit[:release] == "minor"
            next_minor += 1
            next_patch = 0
          elsif commit[:release] == "patch"
            next_patch += 1
          end

          unless commit[:is_codepush_friendly]
            is_next_version_compatible_with_codepush = false
          end

          next_version = "#{next_major}.#{next_minor}.#{next_patch}"
          UI.message("#{next_version}: #{subject}") if params[:show_version_path]
        end

        next_version = "#{next_major}.#{next_minor}.#{next_patch}"

        is_next_version_releasable = Helper::SemanticReleaseHelper.semver_gt(next_version, version)

        Actions.lane_context[SharedValues::RELEASE_ANALYZED] = true
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_HIGHER] = is_next_version_releasable
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH] = is_next_version_compatible_with_codepush
        # Last release analysis
        Actions.lane_context[SharedValues::RELEASE_LAST_TAG_HASH] = hash
        Actions.lane_context[SharedValues::RELEASE_LAST_VERSION] = version
        # Next release analysis
        Actions.lane_context[SharedValues::RELEASE_NEXT_MAJOR_VERSION] = next_major
        Actions.lane_context[SharedValues::RELEASE_NEXT_MINOR_VERSION] = next_minor
        Actions.lane_context[SharedValues::RELEASE_NEXT_PATCH_VERSION] = next_patch
        Actions.lane_context[SharedValues::RELEASE_NEXT_VERSION] = next_version

        success_message = "Next version (#{next_version}) is higher than last version (#{version}). This version should be released."
        UI.success(success_message) if is_next_version_releasable

        is_next_version_releasable
      end

      def self.is_codepush_friendly(params)
        git_command = 'git rev-list --max-parents=0 HEAD'
        # Begining of the branch is taken for codepush analysis
        hash_lines = Actions.sh("#{git_command} | wc -l", log: params[:debug]).chomp
        hash = Actions.sh(git_command, log: params[:debug]).chomp
        next_major = 0
        next_minor = 0
        next_patch = 0
        last_incompatible_codepush_version = '0.0.0'

        if hash_lines.to_i > 1
          UI.error("#{git_command} resulted to more than 1 hash")
          UI.error('This usualy happens when you pull only part of a git history. Check out how you pull the repo! "git fetch" should be enough.')
          Actions.sh(git_command, log: true).chomp
          return false
        end

        # Get commits log between last version and head
        splitted = get_commits_from_hash(
          hash: hash,
          debug: params[:debug]
        )
        releases = params[:releases]
        codepush_friendly = params[:codepush_friendly]

        format_pattern = lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN]
        splitted.each do |line|
          # conventional commits are in format
          # type: subject (fix: app crash - for example)
          commit = Helper::SemanticReleaseHelper.parse_commit(
            commit_subject: line.split("|")[0],
            commit_body: line.split("|")[1],
            releases: releases,
            pattern: format_pattern,
            codepush_friendly: codepush_friendly
          )

          if commit[:release] == "major" || commit[:is_breaking_change]
            next_major += 1
            next_minor = 0
            next_patch = 0
          elsif commit[:release] == "minor"
            next_minor += 1
            next_patch = 0
          elsif commit[:release] == "patch"
            next_patch += 1
          end

          unless commit[:is_codepush_friendly]
            last_incompatible_codepush_version = "#{next_major}.#{next_minor}.#{next_patch}"
          end
        end

        Actions.lane_context[SharedValues::RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION] = last_incompatible_codepush_version
      end

      def self.run(params)
        is_next_version_releasable = is_releasable(params)
        is_codepush_friendly(params)

        is_next_version_releasable
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
            default_value: '\d+\.\d+\.\d+'
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
