require 'fastlane/action'
require_relative '../helper/semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
      # CONVENTIONAL_CHANGELOG_CUSTOM_VALUE = :CONVENTIONAL_CHANGELOG_CUSTOM_VALUE
    end

    class ConventionalChangelogAction < Action
      def self.run(params)
        # Get next version number from shared values
        analyzed = lane_context[SharedValues::RELEASE_ANALYZED]

        # If analyze commits action was not run there will be no version in shared
        # values. We need to run the action to get next version number
        if !analyzed then
          UI.message("Release hasn't been analyzed yet. Running analyze_release action.")
          version = other_action.analyze_commits(match: params[:match])
        end

        lastTagHas = lane_context[SharedValues::RELEASE_LAST_TAG_HASH]
        version = lane_context[SharedValues::RELEASE_NEXT_VERSION]

        # Get commits log between last version and head
        commits = Helper::SemanticReleaseHelper.git_log('%s|%H|%h|%an|%at', lastTagHas)
        parsed = parseCommits(commits.split("\n"))


        repositoryUrl = params[:repository_url] || "https://#{params[:sc]}.com/#{params[:user_name]}/#{params[:project_name]}"
        commitUrl = params[:commit_url] || "#{repositoryUrl}/commit"

        if params[:format] == 'markdown' then
          result = markdown(parsed, version, commitUrl, params)
        elsif params[:format] == 'slack'
          result = slack(parsed, version, commitUrl, params)
        end

        result
      end

      def self.markdown(commits, version, commitUrl, params)
        sections = params[:sections]

        # Begining of release notes
        result = "# #{version} #{params[:title]}"
        result += "\n"
        result += "(#{Date.today})"

        for type in params[:order]
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

          commit = {
            type: subjectSplitted[0],
            subject: subjectSplitted[1].strip(),
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
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :match,
                                       description: "Match tag of last version. Uses for git describe as a match parameter. See git describe man for more info", # a short description of this parameter
                                       verify_block: proc do |value|
                                          UI.user_error!("No match for AnalyzeCommitsAction given, pass using `match: 'expr'`") unless (value and not value.empty?)
                                          # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :releases,
                                      description: "Map types of commit to release (major, minor, patch)",
                                      default_value: { fix: "patch", feat: "minor" },
                                      type: Hash
                                      ),
          FastlaneCore::ConfigItem.new(key: :format, description: "What format do you want to use?", default_value: "markdown", optional: true),
          FastlaneCore::ConfigItem.new(key: :display_author, description: "Display author of commit?", default_value: false, type: Boolean, optional: true),
          FastlaneCore::ConfigItem.new(key: :title, description: "Title of release notes", optional: true),
          FastlaneCore::ConfigItem.new(key: :sc, description: "Source Control Name", optional: true),
          FastlaneCore::ConfigItem.new(key: :user_name, description: "User name for source control", optional: true),
          FastlaneCore::ConfigItem.new(key: :project_name, description: "Project name for source control", optional: true),
          FastlaneCore::ConfigItem.new(key: :repository_url, description: "Use as a link to repository", optional: true),
          FastlaneCore::ConfigItem.new(key: :commit_url, description: "Use as a link to the commit", optional: true),
          FastlaneCore::ConfigItem.new(key: :order, description: "Order of types", default_value: ["feat", "fix"], type: Array, optional: true),
          FastlaneCore::ConfigItem.new(
            key: :sections,
            description: "Map type to section title",
            default_value: {feat: "Features", fix: "Bug fixes"},
            type: Hash,
            optional: true
          ),

        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['CONVENTIONAL_CHANGELOG_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
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
