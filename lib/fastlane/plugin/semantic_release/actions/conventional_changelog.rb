require 'fastlane/action'
require_relative '../helper/semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
      CONVENTIONAL_CHANGELOG = :CONVENTIONAL_CHANGELOG
    end

    class ConventionalChangelogAction < Action
      def self.run(params)
        # Get next version number from shared values
        analyzed = lane_context[SharedValues::RELEASE_ANALYZED]

        # If analyze commits action was not run there will be no version in shared
        # values. We need to run the action to get next version number
        if !analyzed then
          UI.user_error!("Release hasn't been analyzed yet. Run analyze_commits action first please.")
          # version = other_action.analyze_commits(match: params[:match])
        end

        lastTagHas = lane_context[SharedValues::RELEASE_LAST_TAG_HASH]
        version = lane_context[SharedValues::RELEASE_NEXT_VERSION]

        # Get commits log between last version and head
        commits = Helper::SemanticReleaseHelper.git_log('%s|%H|%h|%an|%at', lastTagHas)
        parsed = parseCommits(commits.split("\n"))


        commitUrl = params[:commit_url]

        if params[:format] == 'markdown' then
          result = markdown(parsed, version, commitUrl, params)
        elsif params[:format] == 'slack'
          result = slack(parsed, version, commitUrl, params)
        end

        Actions.lane_context[SharedValues::CONVENTIONAL_CHANGELOG] = result

        result
      end

      def self.markdown(commits, version, commitUrl, params)
        sections = params[:sections]

        # Begining of release notes
        result = "# #{version} #{params[:title]}"
        result += "\n"
        result += "(#{Date.today})"

        for type in params[:order]
          # write section only if there is at least one commit
          next if !commits.any? { |commit| commit[:type] == type }

          result += "\n\n"
          result += "### #{sections[type.to_sym]}"
          result += "\n"

          for commit in commits
            if commit[:type] == type then
              authorName = commit[:authorName]
              shortHash = commit[:shortHash]
              hash = commit[:hash]
              link = "#{commitUrl}/#{hash}"

              result += "- #{commit[:subject]} ([#{shortHash}](#{link}))"

              if params[:display_author] then
                result += "- #{authorName}"
              end

              result += "\n"
            end
          end
        end


        result
      end

      def self.slack(commits, version, commitUrl, params)
        sections = params[:sections]

        # Begining of release notes
        result = "*#{version} #{params[:title]}* (#{Date.today})"
        result += "\n"

        for type in params[:order]
          # write section only if there is at least one commit
          next if !commits.any? { |commit| commit[:type] == type }

          result += "\n\n"
          result += "*#{sections[type.to_sym]}*"
          result += "\n"

          for commit in commits
            if commit[:type] == type then
              authorName = commit[:authorName]
              shortHash = commit[:shortHash]
              hash = commit[:hash]
              link = "#{commitUrl}/#{hash}"

              result += "- #{commit[:subject]} (<#{link}|#{shortHash}>)"

              if params[:display_author] then
                result += "- #{authorName}"
              end

              result += "\n"
            end
          end
        end


        result
      end

      def self.parseCommits(commits)
        parsed = []
        # %s|%H|%h|%an|%at
        for line in commits
          splitted = line.split("|")

          subjectSplitted = splitted[0].split(":")

          if subjectSplitted.length > 1 then
            type = subjectSplitted[0]
            subject = subjectSplitted[1]
          else
            type = 'no_type'
            subject = subjectSplitted[0]
          end

          commit = {
            type: type.strip(),
            subject: subject.strip(),
            hash: splitted[1],
            shortHash: splitted[2],
            authorName: splitted[3],
            commitDate: splitted[4],
          }

          parsed.push(commit)
        end

        parsed
      end


      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Get commits since last version and generates release notes"
      end

      def self.details
        "Uses conventional commits. It groups commits by their types and generates release notes in markdown or slack format."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(
            key: :format,
            description: "You can use either markdown or slack",
            default_value: "markdown",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :title,
            description: "Title of release notes",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :commit_url,
            description: "Uses as a link to the commit",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :order,
            description: "You can change order of groups in release notes",
            default_value: ["feat", "fix", "refactor", "perf", "chore", "test", "docs", "no_type"],
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :sections,
            description: "Map type to section title",
            default_value: {
              feat: "Features",
              fix: "Bug fixes",
              refactor: "Code refactoring",
              perf: "Performance improving",
              chore: "Building system",
              test: "Testing",
              docs: "Documentation",
              no_type: "Rest work",
            },
            type: Hash,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_author,
            description: "Wheter or not you want to display author of commit",
            default_value: false,
            type: Boolean,
            optional: true
          ),
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['CONVENTIONAL_CHANGELOG', 'Generated conventional changelog']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns generated release notes as a string"
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
