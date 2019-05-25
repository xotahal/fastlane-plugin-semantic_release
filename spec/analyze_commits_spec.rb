require 'spec_helper'

describe Fastlane::Actions::AnalyzeCommitsAction do
  describe "Analyze Commits" do
    before do
    end

    def execute_lane_test
      Fastlane::FastFile.new.parse("lane :test do analyze_commits( match: 'v*') end").runner.execute(:test)
    end

    it "should increment fix and return true" do
      commits = [
        "docs: ...|",
        "fix: ...|"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
    end

    it "should increment feat and fix and return true" do
      commits = [
        "docs: ...|",
        "feat: ...|",
        "fix: ...|"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.1")
    end

    it "should increment major change and return true" do
      commits = [
        "docs: ...|",
        "feat: ...|",
        "fix: ...|BREAKING CHANGE: Test"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
    end

    it "should correctly parse scopes" do
      commits = [
        "docs(scope): ...|",
        "feat(test): ...|",
        "fix(test): ...|"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.1")
    end

    it "should return false since there is no change that would increase version" do
      commits = [
        "docs: ...|",
        "chore: ...|",
        "refactor: ...|"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test).to eq(false)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.8")
    end

    it "should return false since there is no change that would increase version" do
      commits = [
        "Merge ...|",
        "Custom ...|"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test).to eq(false)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.8")
    end

    after do
    end
  end
end
