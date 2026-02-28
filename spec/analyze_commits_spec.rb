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

    def test_analyze_commits_same_commit_as_tag
      # for simplicity, these two actions are grouped together because they need to be run for every test,
      # but require different commits to be passed each time. So we can't use the "before :each" for this
      # this is the same as test_analyze_commits, but the last commit is the same as the last tag
      allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8')
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

    it "should recognize capitalized commit types" do
      commits = [
        "Fix: capitalized fix|",
        "Feat: capitalized feat|"
      ]
      test_analyze_commits(commits)

      expect(execute_lane_test(match: 'v*')).to eq(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.0")
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
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.8-1-g71ce4d8')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v1.0.8', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
      end

      it "should allow for user-defined hyphens" do
        commits = [
          "docs: ...|",
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('ios-v1.0.8-beta.1-1-g71ce4d8')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'ios-v1.0.8-beta.1', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
      end

      it "should handle tag without git describe suffix" do
        commits = [
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v5.7.0')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v5.7.0', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("5.7.1")
      end

      it "should handle hyphenated tag without git describe suffix" do
        commits = [
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.0-1-ios-beta')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v1.0.0-1-ios-beta', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.1")
      end

      it "should handle hyphenated tag with git describe suffix" do
        commits = [
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.0-1-ios-beta-3-gabc1234')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v1.0.0-1-ios-beta', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.1")
      end

      it "should handle prerelease tag (v1.0.0-beta) without git describe suffix" do
        commits = [
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.0-beta')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v1.0.0-beta', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
      end

      it "should handle prerelease tag with git describe suffix" do
        commits = [
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.0-beta-3-gabc1234')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v1.0.0-beta', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
      end

      it "should handle rc tag (v2.0.0-rc.1) with git describe suffix" do
        commits = [
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v2.0.0-rc.1-5-g1234abc')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v2.0.0-rc.1', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.1")
      end

      it "should handle release- prefix tag with git describe suffix" do
        commits = [
          "fix: ...|"
        ]
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('release-1.2.3-7-gdeadbeef')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'release-1.2.3', debug: false)
        expect(execute_lane_test(match: 'release-*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.2.4")
      end

      it "should not strip suffix-like parts from tag name" do
        commits = [
          "fix: ...|"
        ]
        # Tag v1.0.0-3-beta ends in -3-beta which looks like a suffix but isn't (beta is not g-prefixed hex)
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('v1.0.0-3-beta')
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(commits)

        expect(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag_hash).with(tag_name: 'v1.0.0-3-beta', debug: false)
        expect(execute_lane_test(match: 'v*')).to eq(true)
      end
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

    describe "bump_per_commit false" do
      it "should increment patch only once for multiple fixes" do
        commits = [
          "fix: first fix|",
          "fix: second fix|",
          "fix: third fix|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*', bump_per_commit: false)).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
      end

      it "should increment minor only once for feat + fixes" do
        commits = [
          "feat: new feature|",
          "fix: first fix|",
          "fix: second fix|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*', bump_per_commit: false)).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.0")
      end

      it "should increment minor only once for multiple feats" do
        commits = [
          "feat: feature one|",
          "feat: feature two|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*', bump_per_commit: false)).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.0")
      end

      it "should increment major only once for breaking + feat + fix" do
        commits = [
          "fix: ...|BREAKING CHANGE: something",
          "feat: ...|",
          "fix: ...|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*', bump_per_commit: false)).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
      end

      it "should return false when there is no releasable change" do
        commits = [
          "docs: update readme|",
          "chore: cleanup|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*', bump_per_commit: false)).to eq(false)
      end
    end

    describe "exclamation mark breaking change" do
      it "should trigger major bump with ! and no BREAKING CHANGE in body" do
        commits = [
          "feat!: a breaking feature|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
      end

      it "should trigger major bump with ! and scope" do
        commits = [
          "fix(core)!: a breaking fix|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
      end

      it "should trigger major bump with ! even when body also has BREAKING CHANGE" do
        commits = [
          "feat!: a breaking feature|BREAKING CHANGE: details here"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
      end
    end

    describe "revert commits" do
      it "should trigger patch bump for reverted fix" do
        commits = [
          'Revert "fix: crash on login"|'
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
      end

      it "should trigger minor bump for reverted feat" do
        commits = [
          'Revert "feat: add SSO support"|'
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.0")
      end

      it "should trigger major bump for reverted breaking feat" do
        commits = [
          'Revert "feat!: remove legacy API"|'
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("2.0.0")
      end

      it "should trigger minor bump for reverted scoped feat" do
        commits = [
          'Revert "feat(login): add SSO support"|'
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.1.0")
      end

      it "should not bump for reverted non-conventional commit" do
        commits = [
          'Revert "not a conventional commit"|'
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*')).to eq(false)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.8")
      end
    end

    describe "no tag found" do
      it "should use first commit as beginning when no tag exists" do
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_last_tag).and_return('')
        allow(Fastlane::Actions).to receive(:sh).with("git rev-list --max-parents=0 HEAD | tail -n 1", log: false).and_return("abc123\n")
        allow(Fastlane::Actions::AnalyzeCommitsAction).to receive(:get_commits_from_hash).and_return(
          ["feat: new feature|"]
        )

        expect(execute_lane_test(match: 'v*')).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_LAST_VERSION]).to eq("0.0.0")
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("0.1.0")
      end
    end

    describe "should_exclude_commit edge cases" do
      it "should not exclude commits with nil scope and empty ignore_scopes" do
        commits = [
          "fix: no scope commit|"
        ]
        test_analyze_commits(commits)

        expect(execute_lane_test(match: 'v*', ignore_scopes: [])).to eq(true)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION]).to eq("1.0.9")
      end
    end

    after do
    end
  end
end
