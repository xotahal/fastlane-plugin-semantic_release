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
        commit_scope = params[:commit_scope]
        scopes_to_include = params[:include_scopes]
        scopes_to_ignore = params[:ignore_scopes]

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

      def self.semver_gt(first, second)
        (parse_semver(first) <=> parse_semver(second)) == 1
      end
    end
  end
end
