require 'spec_helper'

describe Fastlane::Actions::AnalyzeCommitsAction do
  describe "Analyze Commits" do
    before do
    end

    def test_analyze_commits(commits)
      # for simplicity, these two actions are grouped together because they need to be run for every test,
      # but require different commits to be passed each time. So we can't use the "before :each" for this
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)
    end

    def execute_lane_test(params)
      Fastlane::FastFile.new.parse("lane :test do analyze_commits( #{params} ) end").runner.execute(:test)
    end

    it "should increment fix and return true" do
      commits = [
        "docs: ...|",
        "fix: ...|"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
    end

    it "should increment feat and fix and return true" do
      commits = [
        "docs: ...|",
        "feat: ...|",
        "fix: ...|"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.1")
    end

    it "should increment major change and return true" do
      commits = [
        "docs: ...|",
        "feat: ...|",
        "fix: ...|BREAKING CHANGE: Test"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
    end

    it "should increment major change and return true" do
      commits = [
        "docs: ...|",
        "feat: ...|",
        "fix!: ...|BREAKING CHANGE: Bump major version"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
    end

    describe "scopes" do
      commits = [
        "fix(scope): ...|",
        "feat(ios): ...|",
        "fix(ios): ...|",
        "feat(android): ...|",
        "fix(android): ...|"
      ]

      describe "parsing of scopes" do
        it "should correctly parse and output scopes" do
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*')).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.2.1")
        end
      end

      describe "filtering by scopes" do
        it "should accommodate an empty ignore_scopes array" do
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*', ignore_scopes: [])).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.2.1")
        end

        it "should skip a single scopes if it has been added to ignore_scopes" do
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*', ignore_scopes: ['android'])).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.1")
        end

        it "should skip multiple scopes if they have been added to ignore_scopes" do
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*', ignore_scopes: ['android', 'ios'])).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
        end

        it "should not pass analysis checks if all commits are caught by excluded scopes" do
          commits = [
            "fix(ios): ...|"
          ]
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*', ignore_scopes: ['ios'])).to eq(false)
        end
      end
    end

    it "should return false since there is no change that would increase version" do
      commits = [
        "docs: ...|",
        "chore: ...|",
        "refactor: ...|"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(false)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.8")
    end

    it "should return false since there is no change that would increase version" do
      commits = [
        "Merge ...|",
        "Custom ...|"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(false)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.8")
    end

    it "should deal with multiline comments" do
      commits = [
        "fix: add alpha deploy (#10)|* chore: test alpha build with CircleCI

        * chore: skip code check for now

        * chore: ignore gems dirs
        ",
        "chore: add alpha deploy triggered by alpha branch|",
        "fix: fix navigation after user logs in|"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.10")
    end

    it "should provide codepush last version" do
      commits = [
        "fix: ...|codepush: ok",
        "fix: ...|codepush: ok",
        "fix: ...|codepush: ok",
        "fix: ...|codepush: ok",
        "fix: ...|codepush: ok",
        "fix: ...",
        "fix: ...|codepush: ok",
        "docs: ...|codepush: ok",
        "feat: ...|codepush: ok",
        "fix: ...|codepush: ok"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v0.0.0-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("0.1.1")
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION]).to eq("0.0.6")
    end

    it "should accept only codepush: ok as codepush friendly commit" do
      commits = [
        "fix: ...|codepush: ok",
        "fix: ...|codepush: ok",
        "fix: ...|codepush: ok",
        "fix: ...|codepush",
        "fix: ...|codepush: ok",
        "docs: ...|codepush: ok",
        "feat: ...|codepush: ok",
        "fix: ...|codepush: ok"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v0.0.0-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("0.1.1")
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION]).to eq("0.0.4")
    end

    it "should docs, test, etc commits are codepush friendly automatically" do
      commits = [
        "fix: ...|codepush: ok",
        "fix: ...|codepush: ok",
        "fix: ...|codepush",
        "test: ...",
        "refactor: ...|codepush: ok",
        "feat: ...|codepush: ok",
        "perf: ...|codepush: ok",
        "chore: ...",
        "docs: ...",
        "feat: ...|codepush: ok",
        "fix: ...|codepush: ok"
      ]
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v0.0.0-1-g71ce4d8')
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("0.2.1")
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION]).to eq("0.0.3")
    end

    describe "commit_format" do
      describe "default" do
        it "should allow for certain types" do
          commits = [
            "docs: ...|",
            "fix: ...|",
            "feat: ...|",
            "chore: ...|",
            "style: ...|",
            "refactor: ...|",
            "perf: ...|",
            "test: ...|"
          ]
          test_analyze_commits(commits)

          is_releasable = execute_lane_test(
            match: 'v*',
            releases: {
              docs: "minor",
              fix: "minor",
              feat: "minor",
              chore: "minor",
              style: "minor",
              refactor: "minor",
              perf: "minor",
              test: "minor"
            }
          )
          expect(is_releasable).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.8.0")
        end

        it "should not allow for custom types" do
          commits = [
            "foo: ...|",
            "bar: ...|",
            "baz: ...|"
          ]
          test_analyze_commits(commits)

          is_releasable = execute_lane_test(
            match: 'v*',
            releases: {
              foo: "minor",
              bar: "minor",
              baz: "minor"
            }
          )
          expect(is_releasable).to eq(false)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.8")
        end
      end

      describe "angular" do
        it "should allow for default types" do
          commits = [
            "docs: ...|",
            "fix: ...|",
            "feat: ...|",
            "chore: ...|",
            "style: ...|",
            "refactor: ...|",
            "perf: ...|",
            "test: ...|"
          ]
          test_analyze_commits(commits)

          is_releasable = execute_lane_test(
            match: 'v*',
            commit_format: 'angular',
            releases: {
              docs: "minor",
              fix: "minor",
              feat: "minor",
              chore: "minor",
              style: "minor",
              refactor: "minor",
              perf: "minor",
              test: "minor"
            }
          )
          expect(is_releasable).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.8.0")
        end

        it "should allow for custom types" do
          commits = [
            "foo: ...|",
            "bar: ...|",
            "baz: ...|"
          ]
          test_analyze_commits(commits)

          is_releasable = execute_lane_test(
            match: 'v*',
            commit_format: 'angular',
            releases: {
              foo: "minor",
              bar: "minor",
              baz: "minor"
            }
          )
          expect(is_releasable).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.3.0")
        end
      end

      describe "custom" do
        format_pattern = /^prefix-(foo|bar|baz)(?:\.(.*))?(): (.*)/
        commits = [
          "prefix-foo.ios: ...|",
          "prefix-foo.android: ...|",
          "prefix-bar.ios: ...|",
          "prefix-bar.android: ...|",
          "prefix-baz.ios: ...|",
          "prefix-baz.android: ...|",
          "prefix-qux.ios: ...|",
          "prefix-qux.android: ...|"
        ]

        it "should allow for arbetrary formatting" do
          test_analyze_commits(commits)

          is_releasable = execute_lane_test(
            match: 'v*',
            commit_format: format_pattern,
            releases: {
              foo: "major",
              bar: "minor",
              baz: "patch"
            }
          )
          expect(is_releasable).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("3.2.2")
        end

        it "should allow for arbetrary formatting with scope" do
          test_analyze_commits(commits)

          is_releasable = execute_lane_test(
            match: 'v*',
            commit_format: format_pattern,
            releases: {
              foo: "major",
              bar: "minor",
              baz: "patch"
            },
            ignore_scopes: ['android']
          )
          expect(is_releasable).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.1.1")
        end
      end
    end

    after do
    end
  end
end
