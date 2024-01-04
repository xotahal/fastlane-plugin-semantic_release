require 'spec_helper'

describe Fastlane::Actions::AnalyzeCommitsAction do
  describe "Analyze Commits" do
    before do
    end

    def test_analyze_commits(commits)
      # for simplicity, these two actions are grouped together because they need to be run for every test,
      # but require different commits to be passed each time. So we can't use the "before :each" for this
      allow(Fastlane::Actions).to receive(:sh).and_return('v1.0.8-1-g71ce4d8')
      allow(Fastlane::Helper::SemanticReleaseHelper).to receive(:git_log).and_return(commits.join("|>"))
    end

    def test_analyze_commits_same_commit_as_tag
      # for simplicity, these two actions are grouped together because they need to be run for every test,
      # but require different commits to be passed each time. So we can't use the "before :each" for this
      # this is the same as test_analyze_commits, but the last commit is the same as the last tag
      allow(Fastlane::Actions).to receive(:sh).and_return('v1.0.8')
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

        it "should accommodate an empty include_scopes array" do
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*', include_scopes: [])).to eq(true)
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

        it "should only include scopes specified in include_scopes array" do
          commits = [
            "fix(scope): ...|",
            "feat(ios): ...|",
            "fix(ios): ...|",
            "feat(android): ...|",
            "feat(web): ...|",
            "feat(mobile): ...|"
          ]
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*', include_scopes: ['android', 'ios', 'mobile'])).to eq(true)
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.3.0")
        end

        it "should not pass analysis checks if all commits are not in the included scopes" do
          commits = [
            "fix(ios): ...|"
          ]
          test_analyze_commits(commits)

          expect(execute_lane_test(match: 'v*', include_scopes: ['android'])).to eq(false)
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

    it "should return false when we are on the same commit as the last tag" do
      commits = [
        "Merge ...|",
        "Custom ...|"
      ]
      test_analyze_commits_same_commit_as_tag

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

    describe "tags" do
      it "should properly strip off git describe suffix" do
        commits = [
          "docs: ...|",
          "fix: ...|"
        ]
        allow(Fastlane::Actions).to receive(:sh).and_return('v1.0.8-1-g71ce4d8')
        allow(Fastlane::Helper::SemanticReleaseHelper).to receive(:git_log).and_return(commits.join("|>"))

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_hash_from_tag).exactly(2).times.with(tag: 'v1.0.8', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
      end

      it "should allow for user-defined hyphens" do
        commits = [
          "docs: ...|",
          "fix: ...|"
        ]
        allow(Fastlane::Actions).to receive(:sh).and_return('ios-v1.0.8-beta.1-1-g71ce4d8')
        allow(Fastlane::Helper::SemanticReleaseHelper).to receive(:git_log).and_return(commits.join("|>"))

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_hash_from_tag).exactly(2).times.with(tag: 'ios-v1.0.8-beta.1', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
      end
    end

    it "should provide codepush last version" do
      commits = [
        "fix: ...|codepush: ok|26eda271b6d3a41f070d24650eeaf6ecd8e95dac",
        "fix: ...|codepush: ok|faaf5a1b4e3a9d5f74a6792b01133f04a17f286a",
        "fix: ...|codepush: ok|6954ac0dde2712fddc226c8434d713b284455f87",
        "fix: ...|codepush: ok|f37c5c6589a55efad6d8dfdeb3005388731eaa93",
        "fix: ...|codepush: ok|b50baf913868da2b0f213c5650628acb01444866",
        "fix: ...||e538bbddf7fe93027e51e9c6966923430af0bd5d",
        "fix: ...|codepush: ok|c15cb2e1facf013d9c61a4e32d5c58e0422d7f79",
        "docs: ...|codepush: ok|ab52f733d114626dbd71a937764a421856e8b774",
        "feat: ...|codepush: ok|5056c49d0cf0657bdedb61484ac448c942d60e90",
        "fix: ...|codepush: ok|a6f81335ea071984ebeb4003f58a65ddb0baa5ca"
      ]
      allow(Fastlane::Actions).to receive(:sh).and_return('v0.0.0-1-g71ce4d8')
      allow(Fastlane::Helper::SemanticReleaseHelper).to receive(:git_log).and_return(commits.join("|>"))

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("0.1.1")
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION]).to eq("0.0.6")
    end

    it "should accept only codepush: ok as codepush friendly commit" do
      commits = [
        "fix: ...|codepush: ok|d24f23049de1cec26c902646aa92c3b1ceb539b8",
        "fix: ...|codepush: ok|c6c8a7f2405cb0c54038e55accb23038e4a84c6e",
        "fix: ...|codepush: ok|13fa07b69850fd5c3fcb2de3a93bd015886a0b0b",
        "fix: ...|codepush|2725ed2ee33b2d966167af31f4b41da3cc1d0914",
        "fix: ...|codepush: ok|b9ebf00ddcb9830ee16c8d7ca094978c36da3d95",
        "docs: ...|codepush: ok|2c783bfc8e1fdc5ed38aefe6dcb83a4944a17b72",
        "feat: ...|codepush: ok|bb980fcc3b3bca5fa28063ae1f54b9910e17e9d2",
        "fix: ...|codepush: ok|b656ecb5fc421f3435a4e2dd447a9da866d67fd8"
      ]
      allow(Fastlane::Actions).to receive(:sh).and_return('v0.0.0-1-g71ce4d8')
      allow(Fastlane::Helper::SemanticReleaseHelper).to receive(:git_log).and_return(commits.join("|>"))

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("0.1.1")
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_LAST_INCOMPATIBLE_CODEPUSH_VERSION]).to eq("0.0.4")
    end

    it "should docs, test, etc commits are codepush friendly automatically" do
      commits = [
        "fix: ...|codepush: ok|49c9f84734a31c0aab8720cf4117f85979d71e3f",
        "fix: ...|codepush: ok|1bfe2d7c968f08c55f91fffb06d4f3ce69a444fe",
        "fix: ...|codepush|05c4ba90ad6c113fd4e9fa427f1c339d82f7a453",
        "test: ...||969d1319e3707316e27a7de9116994fa6992e8fd",
        "refactor: ...|codepush: ok|0dbbaf8779b8992647cef73eaa4aff3e3abb85f0",
        "feat: ...|codepush: ok|a7310162011b3e2bbd27f467ab1b6ee03c3cb993",
        "perf: ...|codepush: ok|215dc4779ce1de707a77a8ff64c0db6af160a4a6",
        "chore: ...|722fa14a98ecfd3ff6cde3a6f8362d106d9722b7",
        "docs: ...|c9109a5944f511ded6881ff2da1d4641d7facb76",
        "feat: ...|codepush: ok|11e7590180c95fb922ae881aaacd63ec1c575ecd",
        "fix: ...|codepush: ok|3f8aad071ef0bd878d31035052bab60d83eddc75"
      ]
      allow(Fastlane::Actions).to receive(:sh).and_return('v0.0.0-1-g71ce4d8')
      allow(Fastlane::Helper::SemanticReleaseHelper).to receive(:git_log).and_return(commits.join("|>"))

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
