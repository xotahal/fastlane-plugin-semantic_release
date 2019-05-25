require 'spec_helper'

describe Fastlane::Actions::ConventionalChangelogAction do
  describe "Conventional Changelog" do
    before do
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION] = '1.0.2'
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_ANALYZED] = true
    end

    def execute_lane_test
      Fastlane::FastFile.new.parse("lane :test do conventional_changelog end").runner.execute(:test)
    end

    def execute_lane_test_slack
      Fastlane::FastFile.new.parse("lane :test do conventional_changelog( format: 'slack' ) end").runner.execute(:test)
    end

    it "should create sections" do
      commits = [
        "docs: sub|body|long_hash|short_hash|Jiri Otahal|time",
        "fix: sub||long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "#1.0.2 (2019-05-25)\n\n\n### Bug fixes\n- sub ([short_hash](/long_hash))\n\n\n### Documentation\n- sub ([short_hash](/long_hash))\n"

      expect(execute_lane_test).to eq(result)
    end

    it "should dispaly breaking change" do
      commits = [
        "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "#1.0.2 (2019-05-25)\n\n\n### Bug fixes\n- sub ([short_hash](/long_hash))\n\n\n### BREAKING CHANGES\n- Test ([short_hash](/long_hash))\n"

      expect(execute_lane_test).to eq(result)
    end

    it "should display scopes" do
      commits = [
        "fix(test): sub||long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "#1.0.2 (2019-05-25)\n\n\n### Bug fixes\n- **test:** sub ([short_hash](/long_hash))\n"

      expect(execute_lane_test).to eq(result)
    end

    it "should skip merge" do
      commits = [
        "Merge ...||long_hash|short_hash|Jiri Otahal|time",
        "Custom Merge...||long_hash|short_hash|Jiri Otahal|time",
        "fix(test): sub||long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "#1.0.2 (2019-05-25)\n\n\n### Bug fixes\n- **test:** sub ([short_hash](/long_hash))\n\n\n### Rest work\n- Custom Merge... ([short_hash](/long_hash))\n"

      expect(execute_lane_test).to eq(result)
    end

    it "should create sections" do
      commits = [
        "docs: sub|body|long_hash|short_hash|Jiri Otahal|time",
        "fix: sub||long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "*1.0.2 * (2019-05-25)\n\n\n*Bug fixes*\n- sub (</long_hash|short_hash>)\n\n\n*Documentation*\n- sub (</long_hash|short_hash>)\n"

      expect(execute_lane_test_slack).to eq(result)
    end

    it "should dispaly breaking change" do
      commits = [
        "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "*1.0.2 * (2019-05-25)\n\n\n*Bug fixes*\n- sub (</long_hash|short_hash>)\n\n\n*BREAKING CHANGES*\n- Test (</long_hash|short_hash>)\n"

      expect(execute_lane_test_slack).to eq(result)
    end

    it "should display scopes" do
      commits = [
        "fix(test): sub||long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "*1.0.2 * (2019-05-25)\n\n\n*Bug fixes*\n- *test:* sub (</long_hash|short_hash>)\n"

      expect(execute_lane_test_slack).to eq(result)
    end

    it "should skip merge" do
      commits = [
        "Merge ...||long_hash|short_hash|Jiri Otahal|time",
        "Custom Merge...||long_hash|short_hash|Jiri Otahal|time",
        "fix: sub||long_hash|short_hash|Jiri Otahal|time"
      ]
      allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

      result = "*1.0.2 * (2019-05-25)\n\n\n*Bug fixes*\n- sub (</long_hash|short_hash>)\n\n\n*Rest work*\n- Custom Merge... (</long_hash|short_hash>)\n"

      expect(execute_lane_test_slack).to eq(result)
    end

    after do
    end
  end
end
