require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class SemanticReleaseHelper
      FORMAT_PATTERNS = {
        "default" => /^(\w+)(?:\((.*)\))?(!?): (.*)/i,
        "angular" => /^(\w*)(?:\((.*)\))?(!?): (.*)/
      }.freeze

      def self.format_patterns
        FORMAT_PATTERNS
      end

      def self.parse_semver(version_string)
        parts = version_string.split('.')
        [(parts[0] || 0).to_i, (parts[1] || 0).to_i, (parts[2] || 0).to_i]
      end

      def self.git_log(params)
        command = "git log --pretty='#{params[:pretty]}' --reverse #{params[:start]}..HEAD"
        Actions.sh(command, log: params[:debug]).chomp
      end

      def self.should_exclude_commit(params)
        commit_scope = params[:commit_scope]&.downcase
        scopes_to_include = params[:include_scopes].map(&:downcase)
        scopes_to_ignore = params[:ignore_scopes].map(&:downcase)

        return !scopes_to_include.include?(commit_scope) unless scopes_to_include.empty?
        return scopes_to_ignore.include?(commit_scope) unless commit_scope.nil?

        false
      end

      def self.parse_commit(params)
        commit_subject = params[:commit_subject].to_s.strip
        commit_body = params[:commit_body]
        releases = params[:releases]
        codepush_friendly = params[:codepush_friendly]
        pattern = params[:pattern]

        # Detect revert commits: Revert "type(scope): subject"
        revert_match = commit_subject.match(/^Revert "(.+)"/i)
        if revert_match
          inner_subject = revert_match[1]
          matched = inner_subject.match(pattern)
        else
          matched = commit_subject.match(pattern)
        end

        result = {
          is_valid: false,
          subject: commit_subject,
          is_merge: !(commit_subject =~ /^Merge/).nil?,
          type: 'no_type'
        }

        return result if matched.nil?

        type = matched[1].downcase
        result[:is_valid] = true
        result[:is_revert] = !!revert_match
        result[:type] = type
        result[:scope] = matched[2]
        result[:has_exclamation_mark] = matched[3] == '!'
        result[:subject] = revert_match ? "revert #{matched[4]}" : matched[4]

        if result[:has_exclamation_mark]
          result[:is_breaking_change] = true
          result[:breaking_change] = matched[4]
        end

        result[:release] = releases[type.to_sym] unless releases.nil?
        result[:is_codepush_friendly] = codepush_friendly.include?(type) unless codepush_friendly.nil?

        unless commit_body.nil?
          breaking_match = commit_body.match(/BREAKING CHANGES?: (.*)/)
          codepush_match = commit_body.match(/codepush?: (.*)/)

          if breaking_match
            result[:is_breaking_change] = true
            result[:breaking_change] = breaking_match[1]
          end
          result[:is_codepush_friendly] = (codepush_match[1] == 'ok') if codepush_match
        end

        result
      end

      def self.derive_tag_prefix(tag_name, version)
        idx = tag_name.index(version)
        return '' if idx.nil?

        tag_name[0...idx]
      end

      def self.semver_gt(first, second)
        (parse_semver(first) <=> parse_semver(second)) == 1
      end

      def self.determine_bump_type(version, next_version)
        old_parts = parse_semver(version)
        new_parts = parse_semver(next_version)

        if new_parts[0] > old_parts[0]
          "major"
        elsif new_parts[1] > old_parts[1]
          "minor"
        elsif new_parts[2] > old_parts[2]
          "patch"
        else
          "none"
        end
      end

      def self.print_dry_run_summary(version, next_version, parsed_commits)
        bump_type = determine_bump_type(version, next_version)

        UI.important("--- DRY RUN: Release Analysis Summary ---")
        UI.message("Current version: #{version}")
        UI.message("Next version:    #{next_version} (#{bump_type})")

        type_counts = Hash.new(0)
        parsed_commits.each { |c| type_counts[c[:type]] += 1 }

        UI.message("Commits analyzed: #{parsed_commits.length}")
        type_counts.each { |type, count| UI.message("  #{type}: #{count}") }

        UI.message("Commits included in this release:")
        parsed_commits.each do |commit|
          scope_part = commit[:scope] ? "(#{commit[:scope]})" : ""
          UI.message("  - #{commit[:type]}#{scope_part}: #{commit[:subject]}")
        end

        UI.important("--- End of Dry Run ---")
      end
    end
  end
end
