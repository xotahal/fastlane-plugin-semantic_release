require 'fastlane/action'
require_relative '../helper/semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
      RELEASE_ANALYZED = :RELEASE_ANALYZED
      RELEASE_IS_NEXT_VERSION_HIGHER = :RELEASE_IS_NEXT_VERSION_HIGHER
      RELEASE_LAST_TAG_HASH = :RELEASE_LAST_TAG_HASH
      RELEASE_LAST_VERSION = :RELEASE_LAST_VERSION
      RELEASE_NEXT_MAJOR_VERSION = :RELEASE_NEXT_MAJOR_VERSION
      RELEASE_NEXT_MINOR_VERSION = :RELEASE_NEXT_MINOR_VERSION
      RELEASE_NEXT_PATCH_VERSION = :RELEASE_NEXT_PATCH_VERSION
      RELEASE_NEXT_VERSION = :RELEASE_NEXT_VERSION
    end

    class AnalyzeCommitsAction < Action
      def self.run(params)
        # Last version tag name
        tag = ""
        # Hash of the commit where is the last version
        # If the tag is not found we are taking HEAD as reference
        hash = 'HEAD'
        # Default last version
        version = '0.0.0'

        begin
          # Try to find the tag
          command = "git describe --tags --match=#{params[:match]}"
          tag = Actions.sh(command, log: false)
        rescue
          UI.message("Tag was not found for match pattern - #{params[:match]}")
        end

        if tag.empty?
          UI.message("First commit of the branch is taken as a begining of next release")
          # If there is no tag found we taking the first commit of current branch
          hash = Actions.sh('git rev-list --max-parents=0 HEAD', log: false).chomp
        else
          # Tag's format is v2.3.4-5-g7685948
          # See git describe man page for more info
          tag_name = tag.split('-')[0].strip
          parsed_version = tag_name.match(params[:tag_version_match])

          if parsed_version.nil?
            UI.user_error!("Error while parsing version from tag #{tag_name} by using tag_version_match - #{params[:tag_version_match]}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
          end

          version = parsed_version[0]
          # Get a hash of last version tag
          command = "git rev-list -n 1 #{tag_name}"
          hash = Actions.sh(command, log: false).chomp

          UI.message("Found a tag #{tag_name} associated with version #{version}")
        end

        # converts last version string to the int numbers
        next_major = (version.split('.')[0] || 0).to_i
        next_minor = (version.split('.')[1] || 0).to_i
        next_patch = (version.split('.')[2] || 0).to_i

        # Get commits log between last version and head
        commits = Helper::SemanticReleaseHelper.git_log('%s', hash)
        splitted = commits.split("\n")

        UI.message("Found #{splitted.length} commits since last release")
        releases = params[:releases]

        splitted.each do |line|
          # conventional commits are in format
          # type: subject (fix: app crash - for example)
          type = line.split(":")[0]
          release = releases[type.to_sym]

          if release == "patch"
            next_patch += 1
          elsif release == "minor"
            next_minor += 1
            next_patch = 0
          elsif release == "major"
            next_major += 1
            next_minor = 0
            next_patch = 0
          end

          next_version = "#{next_major}.#{next_minor}.#{next_patch}"
          UI.message("#{next_version}: #{line}")
        end

        next_version = "#{next_major}.#{next_minor}.#{next_patch}"

        is_releasable = Helper::SemanticReleaseHelper.semver_gt(next_version, version)

        Actions.lane_context[SharedValues::RELEASE_ANALYZED] = true
        Actions.lane_context[SharedValues::RELEASE_IS_NEXT_VERSION_HIGHER] = is_releasable
        # Last release analysis
        Actions.lane_context[SharedValues::RELEASE_LAST_TAG_HASH] = hash
        Actions.lane_context[SharedValues::RELEASE_LAST_VERSION] = version
        # Next release analysis
        Actions.lane_context[SharedValues::RELEASE_NEXT_MAJOR_VERSION] = next_major
        Actions.lane_context[SharedValues::RELEASE_NEXT_MINOR_VERSION] = next_minor
        Actions.lane_context[SharedValues::RELEASE_NEXT_PATCH_VERSION] = next_patch
        Actions.lane_context[SharedValues::RELEASE_NEXT_VERSION] = next_version

        success_message = "Next version (#{next_version}) is higher than last version (#{version}). This version should be released."
        UI.success(success_message) if is_releasable

        is_releasable
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
            key: :releases,
            description: "Map types of commit to release (major, minor, patch)",
            default_value: { fix: "patch", feat: "minor" },
            type: Hash
          ),
          FastlaneCore::ConfigItem.new(
            key: :tag_version_match,
            description: "To parse version number from tag name",
            default_value: '\d+\.\d+\.\d+'
          )
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['RELEASE_ANALYZED', 'True if commits were analyzed.'],
          ['RELEASE_IS_NEXT_VERSION_HIGHER', 'True if next version is higher then last version'],
          ['RELEASE_LAST_TAG_HASH', 'Hash of commit that is tagged as a last version'],
          ['RELEASE_LAST_VERSION', 'Last version number - parsed from last tag.'],
          ['RELEASE_NEXT_MAJOR_VERSION', 'Major number of the next version'],
          ['RELEASE_NEXT_MINOR_VERSION', 'Minor number of the next version'],
          ['RELEASE_NEXT_PATCH_VERSION', 'Patch number of the next version'],
          ['RELEASE_NEXT_VERSION', 'Next version string in format (major.minor.patch)']
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
