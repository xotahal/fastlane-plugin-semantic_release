require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class SemanticReleaseHelper
      # class methods that you define here become available in your action
      # as `Helper::SemanticReleaseHelper.your_method`
      #
      def self.git_log(pretty, start)
        command = "git log --pretty='#{pretty}' --reverse #{start}..HEAD"
        Actions.sh(command, log: false).chomp
      end
      def self.semver_gt(first, second)
        firstMajor = (first.split('.')[0] || 0).to_i
        firstMinor = (first.split('.')[1] || 0).to_i
        firstPatch = (first.split('.')[2] || 0).to_i

        secondMajor = (second.split('.')[0] || 0).to_i
        secondMinor = (second.split('.')[1] || 0).to_i
        secondPatch = (second.split('.')[2] || 0).to_i

        # Check if next version is higher then last version
        if firstMajor > secondMajor then
          return true
        elsif firstMajor == secondMajor then
          if firstMinor > secondMinor then
            return true
          elsif firstMinor == secondMinor then
            if firstPatch > secondPatch then
              return true
            end
          end
        end

        return false
      end
      def self.semver_lt(first, second)
        return !semver_gt(first,second)
      end
    end
  end
end
