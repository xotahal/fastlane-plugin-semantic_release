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
        command = "git describe --tags --match=#{params[:match]}"
        Actions.sh(command, log: params[:debug])
      rescue StandardError
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

      def self.get_beginning_of_next_sprint(params)
        git_command = "git rev-list --max-parents=0 HEAD"
        tag = get_last_tag(match: params[:match], debug: params[:debug])

        if tag.empty?
          UI.message("It couldn't match tag for #{params[:match]}. Check if first commit can be taken as a beginning of next release")
          # Use tail -n 1 to handle repos with multiple root commits (e.g. merged histories)
          UI.message("First commit of the branch is taken as a beginning of next release")
          return {
            hash: Actions.sh("#{git_command} | tail -n 1", log: params[:debug]).chomp
          }
        end

        # Tag format is v2.3.4-5-g7685948 (see git describe man page)
        # Strip the git describe suffix (-<count>-g<hash>) to get the tag name
        tag_name = tag
        if tag.split('-').length >= 3
          tag_name = tag.split('-')[0...-2].join('-').strip
        end
        parsed_version = tag_name.match(params[:tag_version_match])

        if parsed_version.nil?
          UI.user_error!("Error while parsing version from tag #{tag_name} by using tag_version_match - #{params[:tag_version_match]}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
        end

        version = parsed_version[0]
        hash = get_last_tag_hash(tag_name: tag_name, debug: params[:debug])

        UI.message("Found a tag #{tag_name} associated with version #{version}")

        { hash: hash, version: version }
      end

      def self.bump_version(major, minor, patch, commit)
        if commit[:release] == "major" || commit[:is_breaking_change]
          [major + 1, 0, 0]
        elsif commit[:release] == "minor"
          [major, minor + 1, 0]
        elsif commit[:release] == "patch"
          [major, minor, patch + 1]
        else
          [major, minor, patch]
        end
      end

      def self.clamp_version(next_major, next_minor, next_patch, base_major, base_minor, base_patch)
        if next_major > base_major
          [base_major + 1, 0, 0]
        elsif next_minor > base_minor
          [next_major, base_minor + 1, 0]
        elsif next_patch > base_patch
          [next_major, next_minor, base_patch + 1]
        else
          [next_major, next_minor, next_patch]
        end
      end

      def self.is_releasable(params)
        beginning = get_beginning_of_next_sprint(params)

        unless beginning
          UI.error('It could not find a beginning of this sprint. How to fix this:')
          UI.error('-- ensure there is only one commit with --max-parents=0 (this command should return one line: "git rev-list --max-parents=0 HEAD")')
          UI.error('-- tell us explicitly where the release starts by adding tag like this: vX.Y.Z (where X.Y.Z is version from which it starts computing next version number)')
          return false
        end

        version = beginning[:version] || '0.0.0'
        hash = beginning[:hash] || 'HEAD'

        next_major, next_minor, next_patch = Helper::SemanticReleaseHelper.parse_semver(version)
        base_major = next_major
        base_minor = next_minor
        base_patch = next_patch

        is_next_version_compatible_with_codepush = true

        commits = get_commits_from_hash(hash: hash, debug: params[:debug])
        UI.message("Found #{commits.length} commits since last release")

        format_pattern = lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN]
        commits.each do |line|
          parts = line.split("|")
          subject = parts[0].to_s.strip

          commit = Helper::SemanticReleaseHelper.parse_commit(
            commit_subject: subject,
            commit_body: parts[1],
            releases: params[:releases],
            pattern: format_pattern
          )

          next if Helper::SemanticReleaseHelper.should_exclude_commit(
            commit_scope: commit[:scope],
            include_scopes: params[:include_scopes],
            ignore_scopes: params[:ignore_scopes]
          )

          next_major, next_minor, next_patch = bump_version(next_major, next_minor, next_patch, commit)
          is_next_version_compatible_with_codepush = false unless commit[:is_codepush_friendly]

          next_version = "#{next_major}.#{next_minor}.#{next_patch}"
          UI.message("#{next_version}: #{subject}") if params[:show_version_path]
        end

        unless params[:bump_per_commit]
          next_major, next_minor, next_patch = clamp_version(next_major, next_minor, next_patch, base_major, base_minor, base_patch)
        end

        next_version = "#{next_major}.#{next_minor}.#{next_patch}"
        is_next_version_releasable = Helper::SemanticReleaseHelper.semver_gt(next_version, version)

        Actions.lane_context[SharedValues::RELEASE_ANALYZED] = true
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_HIGHER] = is_next_version_releasable
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_COMPATIBLE_WITH_CODEPUSH] = is_next_version_compatible_with_codepush
        Actions.lane_context[SharedValues::RELEASE_LAST_TAG_HASH] = hash
        Actions.lane_context[SharedValues::RELEASE_LAST_VERSION] = version
        Actions.lane_context[SharedValues::RELEASE_NEXT_MAJOR_VERSION] = next_major
        Actions.lane_context[SharedValues::RELEASE_NEXT_MINOR_VERSION] = next_minor
        Actions.lane_context[SharedValues::RELEASE_NEXT_PATCH_VERSION] = next_patch
        Actions.lane_context[SharedValues::RELEASE_NEXT_VERSION] = next_version

        success_message = "Next version (#{next_version}) is higher than last version (#{version}). This version should be released."
        UI.success(success_message) if is_next_version_releasable

        is_next_version_releasable
      end

      def self.is_codepush_friendly(params)
        git_command = "git rev-list --max-parents=0 HEAD"
        # Use tail -n 1 to handle repos with multiple root commits (e.g. merged histories)
        hash = Actions.sh("#{git_command} | tail -n 1", log: params[:debug]).chomp
        next_major = 0
        next_minor = 0
        next_patch = 0
        base_major = 0
        base_minor = 0
        base_patch = 0
        last_incompatible_codepush_version = '0.0.0'

        commits = get_commits_from_hash(hash: hash, debug: params[:debug])

        format_pattern = lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN]
        commits.each do |line|
          parts = line.split("|")
          commit = Helper::SemanticReleaseHelper.parse_commit(
            commit_subject: parts[0],
            commit_body: parts[1],
            releases: params[:releases],
            pattern: format_pattern,
            codepush_friendly: params[:codepush_friendly]
          )

          next_major, next_minor, next_patch = bump_version(next_major, next_minor, next_patch, commit)

          unless commit[:is_codepush_friendly]
            last_incompatible_codepush_version = "#{next_major}.#{next_minor}.#{next_patch}"
          end
        end

        unless params[:bump_per_commit]
          next_major, next_minor, next_patch = clamp_version(next_major, next_minor, next_patch, base_major, base_minor, base_patch)
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
        "Finds a tag of last release and determines version of next release"
      end

      def self.details
        "This action will find a last release tag and analyze all commits since the tag. It uses conventional commits. Every time when commit is marked as fix or feat it will increase patch or minor number (you can setup this default behaviour). After all it will suggest if the version should be released or not."
      end

      def self.available_options
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
          ),
          FastlaneCore::ConfigItem.new(
            key: :bump_per_commit,
            description: "When true (default), each fix/feat commit increments the version. When false, only bump once per release (matching semantic-release behavior)",
            default_value: true,
            type: Boolean,
            optional: true
          )
        ]
      end

      def self.output
        [
          ['RELEASE_ANALYZED', 'True if commits were analyzed.'],
          ['RELEASE_IS_NEXT_VERSION_HIGHER', 'True if next version is higher than last version'],
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
        "Returns true if the next version is higher than the last version"
      end

      def self.authors
        ["xotahal"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
