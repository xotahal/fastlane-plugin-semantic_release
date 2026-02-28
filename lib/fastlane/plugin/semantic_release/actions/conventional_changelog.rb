require 'fastlane/action'
require_relative '../helper/semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
    end

    class ConventionalChangelogAction < Action
      def self.get_commits_from_hash(params)
        commits = Helper::SemanticReleaseHelper.git_log(
          pretty: '%s|%b|%H|%h|%an|%at|>',
          start: params[:hash],
          debug: params[:debug]
        )
        commits.split("|>")
      end

      def self.run(params)
        analyzed = lane_context[SharedValues::RELEASE_ANALYZED]

        unless analyzed
          UI.user_error!("Release hasn't been analyzed yet. Run analyze_commits action first please.")
        end

        last_tag_hash = lane_context[SharedValues::RELEASE_LAST_TAG_HASH]
        version = lane_context[SharedValues::RELEASE_NEXT_VERSION]

        commits = get_commits_from_hash(hash: last_tag_hash, debug: params[:debug])
        parsed = parse_commits(commits, params)

        note_builder(params[:format], parsed, version, params[:commit_url], params)
      end

      def self.note_builder(format, commits, version, commit_url, params)
        sections = params[:sections]
        result = ""

        if params[:display_title] == true
          title = version
          title += " #{params[:title]}" if params[:title]
          title += " (#{Date.today})"

          result = "#{style_text(title, format, 'title')}\n\n"
        end

        params[:order].each do |type|
          type_commits = commits.select { |commit| commit[:type] == type && !commit[:is_merge] }
          next if type_commits.empty?

          result += "#{style_text(sections[type.to_sym], format, 'heading')}\n"
          result += build_scope_lines(type_commits, format, commit_url, params)
          result += "\n"
        end

        ignore_breaking = params[:ignore_breaking_changes] || lane_context[SharedValues::RELEASE_IGNORE_BREAKING_CHANGES]

        if !ignore_breaking && commits.any? { |commit| commit[:is_breaking_change] == true }
          result += "#{style_text('BREAKING CHANGES', format, 'heading')}\n"

          commits.each do |commit|
            next unless commit[:is_breaking_change]

            result += "- #{commit[:breaking_change]}"
            result += " (#{build_commit_link(commit, commit_url, format)})" if params[:display_links] == true
            result += " - #{commit[:author_name]}" if params[:display_author]
            result += "\n"
          end

          result += "\n"
        end

        result.rstrip!
      end

      def self.build_scope_lines(type_commits, format, commit_url, params)
        result = ""
        grouped = type_commits.group_by { |commit| commit[:scope] }

        grouped.each do |scope, scope_commits|
          if scope.nil? || scope_commits.length == 1
            scope_commits.each do |commit|
              result += build_commit_line("-", commit, format, commit_url, params, include_scope: true)
            end
          else
            result += "- #{style_text("#{scope}:", format, 'bold')}\n"
            scope_commits.each do |commit|
              result += build_commit_line("  -", commit, format, commit_url, params, include_scope: false)
            end
          end
        end

        result
      end

      def self.build_commit_line(prefix, commit, format, commit_url, params, include_scope: true)
        line = prefix
        line += " #{style_text("#{commit[:scope]}:", format, 'bold')}" if include_scope && !commit[:scope].nil?
        line += " #{commit[:subject]}"
        line += " (#{build_commit_link(commit, commit_url, format)})" if params[:display_links] == true
        line += " - #{commit[:author_name]}" if params[:display_author]
        "#{line}\n"
      end

      def self.style_text(text, format, style)
        case style
        when "title"
          case format
          when "markdown" then "# #{text}"
          when "slack" then "*#{text}*"
          else text
          end
        when "heading"
          case format
          when "markdown" then "### #{text}"
          when "slack" then "*#{text}*"
          else "#{text}:"
          end
        when "bold"
          case format
          when "markdown" then "**#{text}**"
          when "slack" then "*#{text}*"
          else text
          end
        else
          text
        end
      end

      def self.build_commit_link(commit, commit_url, format)
        short_hash = commit[:short_hash]
        url = "#{commit_url}/#{commit[:hash]}"

        case format
        when "slack" then "<#{url}|#{short_hash}>"
        when "markdown" then "[#{short_hash}](#{url})"
        else url
        end
      end

      def self.parse_commits(commits, params)
        parsed = []
        format_pattern = lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN]

        commits.each do |line|
          parts = line.split("|")

          commit = Helper::SemanticReleaseHelper.parse_commit(
            commit_subject: parts[0],
            commit_body: parts[1],
            pattern: format_pattern
          )

          next if Helper::SemanticReleaseHelper.should_exclude_commit(
            commit_scope: commit[:scope],
            include_scopes: params[:include_scopes],
            ignore_scopes: params[:ignore_scopes]
          )

          commit[:hash] = parts[2]
          commit[:short_hash] = parts[3]
          commit[:author_name] = parts[4]
          commit[:commit_date] = parts[5]

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
        [
          FastlaneCore::ConfigItem.new(
            key: :format,
            description: "You can use either markdown, slack or plain",
            default_value: "markdown",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :title,
            description: "Title for release notes",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :commit_url,
            description: "Uses as a link to the commit",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :order,
            description: "You can change the order of groups in release notes",
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
              perf: "Performance improvements",
              chore: "Building system",
              test: "Testing",
              docs: "Documentation",
              no_type: "Other work"
            },
            type: Hash,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_author,
            description: "Whether you want to show the author of the commit",
            default_value: false,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_title,
            description: "Whether you want to hide the title/header with the version details at the top of the changelog",
            default_value: true,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_links,
            description: "Whether you want to display the links to commit IDs",
            default_value: true,
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
            key: :debug,
            description: "True if you want to log out a debug info",
            default_value: false,
            type: Boolean,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :ignore_breaking_changes,
            description: "When true, breaking changes section will not appear in the changelog",
            default_value: false,
            type: Boolean,
            optional: true
          )
        ]
      end

      def self.output
        []
      end

      def self.return_value
        "Returns generated release notes as a string"
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
