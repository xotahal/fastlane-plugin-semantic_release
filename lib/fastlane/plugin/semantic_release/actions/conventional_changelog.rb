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
        # Get next version number from shared values
        analyzed = lane_context[SharedValues::RELEASE_ANALYZED]

        # If analyze commits action was not run there will be no version in shared
        # values. We need to run the action to get next version number
        unless analyzed
          UI.user_error!("Release hasn't been analyzed yet. Run analyze_commits action first please.")
          # version = other_action.analyze_commits(match: params[:match])
        end

        last_tag_hash = lane_context[SharedValues::RELEASE_LAST_TAG_HASH]
        version = lane_context[SharedValues::RELEASE_NEXT_VERSION]

        # Get commits log between last version and head
        commits = get_commits_from_hash(
          hash: last_tag_hash,
          debug: params[:debug]
        )
        parsed = parse_commits(commits, params)

        commit_url = params[:commit_url]
        format = params[:format]

        result = note_builder(format, parsed, version, commit_url, params)

        result
      end

      def self.note_builder(format, commits, version, commit_url, params)
        if(params[:group_by_scope])
          note_builder_grouped(format, commits, version, commit_url, params)
        else
          note_builder_ungrouped(format, commits, version, commit_url, params)
        end
      end

      def self.note_builder_ungrouped(format, commits, version, commit_url, params)
        sections = params[:sections]

        result = ""

        # Begining of release notes
        if params[:display_title] == true
          title = version
          title += " #{params[:title]}" if params[:title]
          title += " (#{Date.today})"

          result = style_text(title, format, "title").to_s
          result += "\n\n"
        end

        params[:order].each do |type|
          # write section only if there is at least one commit
          next if commits.none? { |commit| commit[:type] == type }

          result += style_text(sections[type.to_sym], format, "heading").to_s
          result += "\n"

          commits.each do |commit|
            next if commit[:type] != type || commit[:is_merge]

            result += "-"

            unless commit[:scope].nil?
              formatted_text = style_text("#{commit[:scope]}:", format, "bold").to_s
              result += " #{formatted_text}"
            end

            result += " #{commit[:subject]}"

            if params[:display_links] == true
              styled_link = build_commit_link(commit, commit_url, format).to_s
              result += " (#{styled_link})"
            end

            if params[:display_author]
              result += " - #{commit[:author_name]}"
            end

            result += "\n"
          end
          result += "\n"
        end

        if commits.any? { |commit| commit[:is_breaking_change] == true }
          result += style_text("BREAKING CHANGES", format, "heading").to_s
          result += "\n"

          commits.each do |commit|
            next unless commit[:is_breaking_change]
            result += "- #{commit[:breaking_change]}" # This is the only unique part of this loop

            if params[:display_links] == true
              styled_link = build_commit_link(commit, commit_url, format).to_s
              result += " (#{styled_link})"
            end

            if params[:display_author]
              result += " - #{commit[:author_name]}"
            end

            result += "\n"
          end

          result += "\n"
        end

        # Trim any trailing newlines
        result = result.rstrip!

        result
      end

      def self.validate_sections(sections)
        # Ensure sections is a hash
        unless sections.is_a?(Hash)
          UI.user_error!("sections parameter must be a Hash, got #{sections.class}")
        end

        # Ensure no_type section exists as it's used as fallback for commits without scope
        unless sections.key?(:no_type)
          UI.user_error!("sections parameter must include a :no_type key for commits without scope. " \
                         "Add 'no_type: \"Other work\"' to your sections configuration.")
        end

        # Ensure no_type value is not nil or empty
        if sections[:no_type].nil? || sections[:no_type].to_s.strip.empty?
          UI.user_error!("sections[:no_type] cannot be nil or empty. " \
                         "Provide a meaningful section name like 'Other work'.")
        end
      end

      def self.normalize_scope(scope, fallback_scope)
        # Normalize scope by trimming whitespace and handling empty/nil values
        normalized = scope.nil? ? nil : scope.strip
        if normalized.nil? || normalized.empty?
          fallback_scope
        else
          normalized
        end
      end

      def self.normalize_scope_for_grouping(scope)
        # Normalize scope to lowercase for consistent grouping
        # This ensures "cache", "Cache", and "CACHE" all group together
        return nil if scope.nil?

        normalized = scope.downcase

        # Map semantically related scopes to a canonical form
        # "Cleanup" and "Refactor" are grouped together as "refactor"
        case normalized
        when /^cleanup/
          'refactor'
        when /^refactor/
          'refactor'
        when /^any/
          'any'
        else
          normalized
        end
      end

      def self.is_semantic_mapping?(scope)
        # Check if a scope has a semantic mapping (e.g., Cleanup -> refactor)
        return false if scope.nil?
        normalized = scope.downcase
        case normalized
        when /^cleanup/, /^refactor/, /^any/
          true
        else
          false
        end
      end

      def self.capitalize_scope(scope)
        # Capitalize the first letter of the scope for display
        # Examples: "offline" -> "Offline", "OFFLINE" -> "Offline", "PlaylistRepository" -> "PlaylistRepository"
        return nil if scope.nil?
        return scope if scope.empty?

        # If the scope is all uppercase (like "OFFLINE"), convert to title case
        if scope == scope.upcase && scope.length > 1
          scope[0].upcase + scope[1..-1].downcase
        else
          # Otherwise, just ensure first letter is uppercase
          scope[0].upcase + scope[1..-1]
        end
      end

      def self.note_builder_grouped(format, commits, version, commit_url, params)
        sections = params[:sections]
        validate_sections(sections)
        lines = []

        if params[:display_title] == true
          lines << build_title(version, params)
          lines << ""
        end

        commits_by_type = commits.group_by { |c| c[:type] }
        params[:order].each do |type|
          commits_in_type = commits_by_type[type]
          next if commits_in_type.nil? || commits_in_type.size == 0

          # Filter out merge commits at the type level first
          non_merge_commits_in_type = commits_in_type.reject { |commit| commit[:is_merge] }
          next if non_merge_commits_in_type.empty?

          type_text = style_text_grouped(sections[type.to_sym], format, "heading").to_s
          lines << type_text

          # Group commits by normalized scope (lowercase) for consistent grouping
          # but preserve the original scope for display (unless it's a semantic mapping)
          commits_by_normalized_scope = non_merge_commits_in_type.group_by do |c|
            normalized = normalize_scope(c[:scope], sections[:no_type])
            normalize_scope_for_grouping(normalized)
          end

          # Build a map of normalized scope -> display scope
          # For semantic mappings (Cleanup->refactor, Refactor->refactor), use the canonical form
          # For other scopes, use the original scope
          normalized_to_display = {}
          non_merge_commits_in_type.each do |commit|
            normalized = normalize_scope(commit[:scope], sections[:no_type])
            normalized_for_grouping = normalize_scope_for_grouping(normalized)

            # Determine display scope
            if is_semantic_mapping?(normalized)
              # This is a semantic mapping (e.g., Cleanup -> refactor)
              display_scope = normalized_for_grouping
            else
              # Use the original scope for display
              display_scope = normalized
            end

            normalized_to_display[normalized_for_grouping] ||= display_scope
          end

          # Sort scopes alphabetically, but put fallback scope last
          sorted_normalized_scopes = commits_by_normalized_scope.keys.sort do |a, b|
            fallback_normalized = normalize_scope_for_grouping(sections[:no_type])
            if a == fallback_normalized && b != fallback_normalized
              1  # fallback scope comes last
            elsif a != fallback_normalized && b == fallback_normalized
              -1  # named scope comes first
            else
              a.casecmp(b)  # alphabetical sort (case-insensitive)
            end
          end

          sorted_normalized_scopes.each do |normalized_scope|
            commits_in_scope = commits_by_normalized_scope[normalized_scope]
            # Use the canonical display scope (from normalize_scope_for_grouping)
            display_scope = normalized_to_display[normalized_scope]
            # Capitalize the first letter of the scope for display
            capitalized_scope = capitalize_scope(display_scope)
            scope = style_text_grouped("#{capitalized_scope}:", format, "bold").to_s

            is_single_commit = commits_in_scope.size == 1
            if is_single_commit
              commit = commits_in_scope.first
              commit_text = build_commit_grouped(params, commit, is_single_commit)
              lines << "#{scope} #{commit_text}"
            else
              lines << scope

              commits_in_scope.each do |commit|
                commit_text = build_commit_grouped(params, commit, is_single_commit)
                lines << commit_text
              end
            end
          end
        end

        lines.join("\n")
      end

      def self.build_commit(params, commit, is_single_commit)
        result = ""
        format = params[:format]

        if is_single_commit
          result += " #{commit[:subject]}"
        else
          result += "   - #{commit[:subject]}"
        end

        if params[:display_links] == true
          commit_url = params[:commit_url]

          styled_link = build_commit_link(commit, commit_url, format).to_s

          result += " (#{styled_link})"
        end

        if params[:display_author]
          result += " - #{commit[:author_name]}"
        end

        result
      end

      def self.build_commit_grouped(params, commit, is_single_commit)
        result = ""
        format = params[:format]

        sanitized_subject = commit[:subject].strip

        if is_single_commit
          result += sanitized_subject
        else
          if format == "slack"
            result += "    - #{sanitized_subject}"
          else
            result += "   - #{sanitized_subject}"
          end
        end

        if params[:display_links] == true
          commit_url = params[:commit_url]

          styled_link = build_commit_link(commit, commit_url, format).to_s

          result += " (#{styled_link})"
        end

        if params[:display_author]
          result += " - #{commit[:author_name]}"
        end

        result
      end

      def self.style_text(text, format, style)
        # formats the text according to the style we're looking to use

        # Skips all styling
        case style
        when "title"
          if format == "markdown"
            "# #{text}"
          elsif format == "slack"
            "*#{text}*"
          else
            text
          end
        when "heading"
          if format == "markdown"
            "### #{text}"
          elsif format == "slack"
            "*#{text}*"
          else
            "#{text}:"
          end
        when "bold"
          if format == "markdown"
            "**#{text}**"
          elsif format == "slack"
            "*#{text}*"
          else
            text
          end
        else
          text # catchall, shouldn't be needed
        end
      end

      def self.style_text_grouped(text, format, style)
        # formats the text according to the style we're looking to use
        case style
        when "title"
          if format == "markdown"
            "# #{text}"
          elsif format == "slack"
            "*#{text}*"
          else
            text
          end
        when "heading"
          if format == "markdown"
            "### #{text}"
          elsif format == "slack"
            "*#{text}*"
          else
            "#{text}:"
          end
        when "bold"
          if format == "markdown"
            "- **#{text}**"
          elsif format == "slack"
            "- *#{text}*"
          else
            "- #{text}"
          end
        else
          text # catchall, shouldn't be needed
        end
      end

      def self.build_commit_link(commit, commit_url, format)
        # formats the link according to the output format we need
        short_hash = commit[:short_hash]
        hash = commit[:hash]
        url = "#{commit_url}/#{hash}"

        case format
        when "slack"
          "<#{url}|#{short_hash}>"
        when "markdown"
          "[#{short_hash}](#{url})"
        else
          url
        end
      end

      def self.build_title(version, params)
        title = version
        title += " #{params[:title]}" if params[:title]
        title += " (#{Date.today})"

        format = params[:format]
        style_text(title, format, "title").to_s
      end

      def self.parse_commits(commits, params)
        parsed = []
        # %s|%b|%H|%h|%an|%at
        format_pattern = lane_context[SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN]
        commits.each do |line|
          splitted = line.split("|")

          commit = Helper::SemanticReleaseHelper.parse_commit(
            commit_subject: splitted[0],
            commit_body: splitted[1],
            pattern: format_pattern
          )

          next if Helper::SemanticReleaseHelper.should_exclude_commit(
            commit_scope: commit[:scope],
            include_scopes: params[:include_scopes],
            ignore_scopes: params[:ignore_scopes]
          )

          commit[:hash] = splitted[2]
          commit[:short_hash] = splitted[3]
          commit[:author_name] = splitted[4]
          commit[:commit_date] = splitted[5]

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
            key: :group_by_scope,
            description: "True if you want to group multiple changes by scope name",
            default_value: false,
            type: Boolean,
            optional: true
          ),
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        []
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
