module Fastlane
  module Actions
    module SharedValues
      RELEASE_ANALYZED = :RELEASE_ANALYZED
      RELEASE_LAST_TAG_HASH = :RELEASE_LAST_TAG_HASH
      RELEASE_LAST_VERSION = :RELEASE_LAST_VERSION
      RELEASE_NEXT_MAJOR_VERSION = :RELEASE_NEXT_MAJOR_VERSION
      RELEASE_NEXT_MINOR_VERSION = :RELEASE_NEXT_MINOR_VERSION
      RELEASE_NEXT_PATCH_VERSION = :RELEASE_NEXT_PATCH_VERSION
      RELEASE_NEXT_VERSION = :RELEASE_NEXT_VERSION
    end


    class AnalyzeCommitsAction < Action
      def self.run(params)
        UI.error("Test")
        # Last version tag name
        tag = ""
        # Hash of the commit where is the last version
        # If the tag is not found we are taking HEAD as reference
        hash = 'HEAD'
        # Default last version
        version = '0.0.0'

        begin
          #Try to find the tag
          command = "git describe --tags --match=#{params[:match]}"
          tag = Actions.sh(command, log: false)
        rescue
          UI.message("Tag was not found for match pattern - #{params[:match]}")
        end

        if tag.empty? then
          UI.message("First commit of the branch is taken as a begining of next release")
          # If there is no tag found we taking the first commit of current branch
          hash = Actions.sh('git rev-list --max-parents=0 HEAD', log: false).chomp
        else
          # Tag's format is v2.3.4-5-g7685948
          # See git describe man page for more info
          tagName = tag.split('-')[0].strip()
          version = tagName.split('/')[2];
          # Get a hash of last version tag
          command = "git rev-list -n 1 #{tagName}"
          hash = Actions.sh(command, log: false).chomp

          UI.message("Found a tag #{tagName} associated with version #{version}")
        end

        # converts last version string to the int numbers
        major = (version.split('.')[0] || 0).to_i
        minor = (version.split('.')[1] || 0).to_i
        patch = (version.split('.')[2] || 0).to_i

        nextMajor = major
        nextMinor = minor
        nextPatch = patch

        # Get commits log between last version and head
        command = "git log --pretty='%s' --reverse #{hash}..HEAD"
        commits = Actions.sh(command, log: false).chomp
        splitted = commits.split("\n");

        UI.message("Found #{splitted.length} commits since last release")
        releases = params[:releases]

        for line in splitted
          # conventional commits are in format
          # type: subject (fix: app crash - for example)
          type = line.split(":")[0]
          release = releases[type.to_sym]

          if release == "patch" then
            nextPatch = nextPatch + 1
          elsif release == "minor" then
            nextMinor = nextMinor + 1
            nextPatch = 0
          elsif release == "major" then
            nextMajor = nextMajor + 1
            nextMinor = 0
            nextPatch = 0
          end

          nextVersion = "#{nextMajor}.#{nextMinor}.#{nextPatch}"
          UI.message("#{nextVersion}: #{line}")
        end

        lastVersion = "#{major}.#{minor}.#{patch}";
        nextVersion = "#{nextMajor}.#{nextMinor}.#{nextPatch}"

        isReleaseable = false

        # Check if next version is higher then last version
        if nextMajor > major then
          isReleaseable = true
        elsif nextMajor == major then
          if nextMinor > minor then
            isReleaseable = true
          elsif nextMinor == minor then
            if nextPatch > patch then
              isReleaseable = true
            end
          end
        end

        if isReleaseable then
          UI.success("Next version (#{nextVersion}) is higher than last version (#{lastVersion}). This version should be released.")
        else
          UI.test_failure!('There are no commit that would change next version since last release')
        end

        Actions.lane_context[SharedValues::RELEASE_ANALYZED] = true
        # Last release analysis
        Actions.lane_context[SharedValues::RELEASE_LAST_TAG_HASH] = hash
        Actions.lane_context[SharedValues::RELEASE_LAST_VERSION] = lastVersion
        # Next release analysis
        Actions.lane_context[SharedValues::RELEASE_NEXT_MAJOR_VERSION] = nextMajor
        Actions.lane_context[SharedValues::RELEASE_NEXT_MINOR_VERSION] = nextMinor
        Actions.lane_context[SharedValues::RELEASE_NEXT_PATCH_VERSION] = nextPatch
        Actions.lane_context[SharedValues::RELEASE_NEXT_VERSION] = nextVersion

        nextVersion
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
                UI.user_error!("No match for analyze_commits action given, pass using `match: 'expr'`") unless (value and not value.empty?)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :releases,
            description: "Map types of commit to release (major, minor, patch)",
            default_value: { fix: "patch", feat: "minor" },
            type: Hash,
          ),

        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['RELEASE_ANALYZED', 'True if commits were analyzed.'],
          ['RELEASE_LAST_TAG_HASH', 'Hash of commit that is tagged as a last version'],
          ['RELEASE_LAST_VERSION', 'Last version number - parsed from last tag.'],
          ['RELEASE_NEXT_MAJOR_VERSION', 'Major number of the next version'],
          ['RELEASE_NEXT_MINOR_VERSION', 'Minor number of the next version'],
          ['RELEASE_NEXT_PATCH_VERSION', 'Patch number of the next version'],
          ['RELEASE_NEXT_VERSION', 'Next version string in format (major.minor.patch)'],
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns next version string"
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
