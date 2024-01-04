require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class SemanticReleaseHelper
      def self.format_patterns
        return {
          "default" => /^(docs|fix|feat|chore|style|refactor|perf|test)(?:\((.*)\))?(!?)\: (.*)/,
          "angular" => /^(\w*)(?:\((.*)\))?(): (.*)/
        }
      end

      # class methods that you define here become available in your action
      # as `Helper::SemanticReleaseHelper.your_method`
      #
      def self.git_log(params)
        command = "git log --pretty='#{params[:pretty]}' #{params[:recent_first] ? '' : '--reverse'} #{params[:start]}..HEAD"
        Actions.sh(command, log: params[:debug]).chomp
      end

      def self.should_exclude_commit(params)
        commit_scope = params[:commit_scope]
        scopes_to_include = params[:include_scopes]
        scopes_to_ignore = params[:ignore_scopes]

        unless scopes_to_include.empty?
          return !scopes_to_include.include?(commit_scope)
        end

        unless commit_scope.nil?
          return scopes_to_ignore.include?(commit_scope)
        end
      end

      def self.parse_commit(params)
        commit_hash = params[:commit_hash]
        commit_subject = params[:commit_subject].to_s.strip
        commit_body = params[:commit_body]
        releases = params[:releases]
        codepush_friendly = params[:codepush_friendly]
        pattern = params[:pattern]
        breaking_change_pattern = /BREAKING CHANGES?: (.*)/
        codepush_pattern = /codepush?: (.*)/

        matched = commit_subject.match(pattern)
        result = {
          hash: commit_hash,
          is_valid: false,
          subject: commit_subject,
          is_merge: !(commit_subject =~ /^Merge/).nil?,
          type: 'no_type'
        }

        unless matched.nil?
          type = matched[1]
          scope = matched[2]

          result[:is_valid] = true
          result[:type] = type
          result[:scope] = scope
          result[:has_exclamation_mark] = matched[3] == '!'
          result[:subject] = matched[4]

          unless releases.nil?
            result[:release] = releases[type.to_sym]
          end
          unless codepush_friendly.nil?
            result[:is_codepush_friendly] = codepush_friendly.include?(type)
          end

          unless commit_body.nil?
            breaking_change_matched = commit_body.match(breaking_change_pattern)
            codepush_matched = commit_body.match(codepush_pattern)

            unless breaking_change_matched.nil?
              result[:is_breaking_change] = true
              result[:breaking_change] = breaking_change_matched[1]
            end
            unless codepush_matched.nil?
              result[:is_codepush_friendly] = codepush_matched[1] == 'ok'
            end
          end
        end

        result
      end
    end
  end
end
