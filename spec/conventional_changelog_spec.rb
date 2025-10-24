require 'spec_helper'
require 'pry'

describe Fastlane::Actions::ConventionalChangelogAction do
  HASH_MARKDOWN = "([short_hash](/long_hash))"
  HASH_PLAIN = "(/long_hash)"
  HASH_SLACK = "(</long_hash|short_hash>)"

  def commit(type: nil, scope: nil, title: nil, body: '', author: "Jiri Otahal")
    if scope.nil?
      "#{type}: #{title}|#{body}|long_hash|short_hash|#{author}|time"
    else
      "#{type}(#{scope}): #{title}|#{body}|long_hash|short_hash|#{author}|time"
    end
  end

  describe "Conventional Changelog" do
    before do
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN] = Fastlane::Helper::SemanticReleaseHelper.format_patterns["default"]
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION] = '1.0.2'
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_ANALYZED] = true
    end

    def execute_lane_test(params = {})
      Fastlane::FastFile.new.parse("lane :test do conventional_changelog( #{params} ) end").runner.execute(:test)
    end

    def execute_lane_test_plain
      execute_lane_test(format: 'plain')
    end

    def execute_lane_test_slack
      execute_lane_test(format: 'slack')
    end

    def execute_lane_test_author
      execute_lane_test(display_author: true)
    end

    def execute_lane_test_no_header
      execute_lane_test(display_title: false)
    end

    def execute_lane_test_no_header_plain
      execute_lane_test(format: 'plain', display_title: false)
    end

    def execute_lane_test_no_header_slack
      execute_lane_test(format: 'slack', display_title: false)
    end

    def execute_lane_test_no_links
      execute_lane_test(display_links: false)
    end

    def execute_lane_test_no_links_slack
      execute_lane_test(format: 'slack', display_links: false)
    end

    describe 'section creation' do
      commits = [
        "docs: sub|body|long_hash|short_hash|Jiri Otahal|time",
        "fix: sub||long_hash|short_hash|Jiri Otahal|time"
      ]

      it 'should generate sections in markdown format' do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- sub ([short_hash](/long_hash))\n\n### Documentation\n- sub ([short_hash](/long_hash))"

        expect(execute_lane_test).to eq(result)
      end

      it "should create sections in plain format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "1.0.2 (2019-05-25)\n\nBug fixes:\n- sub (/long_hash)\n\nDocumentation:\n- sub (/long_hash)"

        expect(execute_lane_test_plain).to eq(result)
      end

      it "should create sections in Slack format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "*1.0.2 (2019-05-25)*\n\n*Bug fixes*\n- sub (</long_hash|short_hash>)\n\n*Documentation*\n- sub (</long_hash|short_hash>)"

        expect(execute_lane_test_slack).to eq(result)
      end
    end

    describe 'hiding headers if display_title is false' do
      commits = [
        "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should hide in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "### Bug fixes\n- sub ([short_hash](/long_hash))\n\n### BREAKING CHANGES\n- Test ([short_hash](/long_hash))"

        expect(execute_lane_test_no_header).to eq(result)
      end

      it "should hide in plain format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "Bug fixes:\n- sub (/long_hash)\n\nBREAKING CHANGES:\n- Test (/long_hash)"

        expect(execute_lane_test_no_header_plain).to eq(result)
      end

      it "should hide in slack format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "*Bug fixes*\n- sub (</long_hash|short_hash>)\n\n*BREAKING CHANGES*\n- Test (</long_hash|short_hash>)"

        expect(execute_lane_test_no_header_slack).to eq(result)
      end
    end

    describe 'showing the author if display_author is true' do
      commits = [
        "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should display in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- sub ([short_hash](/long_hash)) - Jiri Otahal\n\n### BREAKING CHANGES\n- Test ([short_hash](/long_hash)) - Jiri Otahal"

        expect(execute_lane_test_author).to eq(result)
      end
    end

    describe 'displaying a breaking change' do
      it "should display in markdown format" do
        commits = [
          "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- sub ([short_hash](/long_hash))\n\n### BREAKING CHANGES\n- Test ([short_hash](/long_hash))"

        expect(execute_lane_test).to eq(result)
      end

      it "should display in slack format" do
        commits = [
          "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "*1.0.2 (2019-05-25)*\n\n*Bug fixes*\n- sub (</long_hash|short_hash>)\n\n*BREAKING CHANGES*\n- Test (</long_hash|short_hash>)"

        expect(execute_lane_test_slack).to eq(result)
      end
    end

    describe 'displaying scopes' do
      commits = [
        "fix(test): sub||long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should display in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- **test:** sub ([short_hash](/long_hash))"

        expect(execute_lane_test).to eq(result)
      end

      it "should display in slack format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "*1.0.2 (2019-05-25)*\n\n*Bug fixes*\n- *test:* sub (</long_hash|short_hash>)"

        expect(execute_lane_test_slack).to eq(result)
      end
    end

    describe 'skipping ignore_scopes' do
      commits = [
        "Merge ...||long_hash|short_hash|Jiri Otahal|time",
        "Custom Merge...||long_hash|short_hash|Jiri Otahal|time",
        "fix(bump): sub||long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should skip in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Other work\n- Custom Merge... ([short_hash](/long_hash))"

        changelog = execute_lane_test(ignore_scopes: ['bump'])
        expect(changelog).to eq(result)
      end

      it "should skip nothing in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- **bump:** sub ([short_hash](/long_hash))\n\n### Other work\n- Custom Merge... ([short_hash](/long_hash))"

        changelog = execute_lane_test(ignore_scopes: ['not'])
        expect(changelog).to eq(result)
      end
    end

    describe 'skipping merge conflicts' do
      commits = [
        "Merge ...||long_hash|short_hash|Jiri Otahal|time",
        "Custom Merge...||long_hash|short_hash|Jiri Otahal|time",
        "fix(test): sub||long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should skip in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- **test:** sub ([short_hash](/long_hash))\n\n### Other work\n- Custom Merge... ([short_hash](/long_hash))"

        expect(execute_lane_test).to eq(result)
      end

      it "should skip in slack format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "*1.0.2 (2019-05-25)*\n\n*Bug fixes*\n- *test:* sub (</long_hash|short_hash>)\n\n*Other work*\n- Custom Merge... (</long_hash|short_hash>)"

        expect(execute_lane_test_slack).to eq(result)
      end
    end

    describe 'hiding links if display_links is false' do
      commits = [
        "docs: sub|body|long_hash|short_hash|Jiri Otahal|time",
        "fix: sub||long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should hide in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- sub\n\n### Documentation\n- sub"

        expect(execute_lane_test_no_links).to eq(result)
      end

      it "should hide in Slack format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "*1.0.2 (2019-05-25)*\n\n*Bug fixes*\n- sub\n\n*Documentation*\n- sub"

        expect(execute_lane_test_no_links_slack).to eq(result)
      end
    end

    describe "commit format" do
      format_pattern = /^prefix-(foo|bar|baz)(?:\.(.*))?(): (.*)/
      commits = [
        "prefix-foo: sub|body|long_hash|short_hash|Jiri Otahal|time",
        "prefix-bar: sub|body|long_hash|short_hash|Jiri Otahal|time",
        "prefix-baz.android: sub|body|long_hash|short_hash|Jiri Otahal|time",
        "prefix-qux: sub|body|long_hash|short_hash|Jiri Otahal|time"
      ]

      before do
        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN] = format_pattern
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
      end

      it "should use the commit format" do
        result = "# 1.0.2 (2019-05-25)\n\n### Bazz\n- **android:** sub ([short_hash](/long_hash))\n\n### Foo\n- sub ([short_hash](/long_hash))\n\n### Bar\n- sub ([short_hash](/long_hash))\n\n### Other\n- prefix-qux: sub ([short_hash](/long_hash))"

        changelog = execute_lane_test(
          order: ['baz', 'foo', 'bar', 'no_type'],
          sections: {
            foo: "Foo",
            bar: "Bar",
            baz: "Bazz",
            no_type: "Other"
          }
        )
        expect(changelog).to eq(result)
      end
    end

    after do
    end

    describe 'group messages if group_by_scope is true' do
      context "with scope" do
        before do
          commits = [
            commit(type: 'feat', scope: 'Scope 1', title: 'Add a new feature'),
            commit(type: 'feat', scope: 'Scope 1', title: 'Add another feature'),
            commit(type: 'feat', scope: 'Scope 2', title: 'Add one more feature')
          ]

          allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
          allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
        end

        it "should group in Scope 1 multiple commits in markdown format" do
          expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                            "### Features\n"\
                            "- **Scope 1:**\n"\
                            "   - Add a new feature #{HASH_MARKDOWN}\n"\
                            "   - Add another feature #{HASH_MARKDOWN}\n"\
                            "- **Scope 2:** Add one more feature #{HASH_MARKDOWN}"

          result = execute_lane_test(group_by_scope: true)

          expect(result).to eq(expected_result)
        end

        it "should group in Scope 1 multiple commits in plain format" do
          expected_result = "1.0.2 (2019-05-25)\n\n"\
                            "Features:\n"\
                            "- Scope 1:\n"\
                            "   - Add a new feature #{HASH_PLAIN}\n"\
                            "   - Add another feature #{HASH_PLAIN}\n"\
                            "- Scope 2: Add one more feature #{HASH_PLAIN}"

          result = execute_lane_test(group_by_scope: true, format: 'plain')

          expect(result).to eq(expected_result)
        end

        it "should group in Scope 1 multiple commits in slack format" do
          expected_result = "*1.0.2 (2019-05-25)*\n\n"\
                            "*Features*\n"\
                            "- *Scope 1:*\n"\
                            "    - Add a new feature #{HASH_SLACK}\n"\
                            "    - Add another feature #{HASH_SLACK}\n"\
                            "- *Scope 2:* Add one more feature #{HASH_SLACK}"

          result = execute_lane_test(group_by_scope: true, format: 'slack')

          expect(result).to eq(expected_result)
        end
      end

      context "having scopes and  multiple commits with different types" do
        before do
          commits = [
            commit(type: 'feat', scope: 'Scope 1', title: 'Add a new feature'),
            commit(type: 'feat', scope: 'Scope 1', title: 'Add another feature'),
            commit(type: 'feat', scope: 'Scope 2', title: 'Add one more feature'),
            commit(type: 'fix', scope: 'Scope 2', title: 'Add 1 more feature'),
            commit(type: 'fix', scope: 'Scope 1', title: 'Add 2 more feature'),
            commit(type: 'fix', scope: 'Scope 1', title: 'Add 3 more feature')
          ]

          allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
          allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
        end

        it "should group by type and then by scope, sorted alphabetically" do
          expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                            "### Features\n"\
                            "- **Scope 1:**\n"\
                            "   - Add a new feature #{HASH_MARKDOWN}\n"\
                            "   - Add another feature #{HASH_MARKDOWN}\n"\
                            "- **Scope 2:** Add one more feature #{HASH_MARKDOWN}\n"\
                            "### Bug fixes\n"\
                            "- **Scope 1:**\n"\
                            "   - Add 2 more feature #{HASH_MARKDOWN}\n"\
                            "   - Add 3 more feature #{HASH_MARKDOWN}\n"\
                            "- **Scope 2:** Add 1 more feature #{HASH_MARKDOWN}"


          result = execute_lane_test(group_by_scope: true)

          expect(result).to eq(expected_result)
        end
      end

      context "without scope" do
        before do
          commits = [
            commit(type: 'feat', scope: 'Same Scope', title: 'Add a new feature with scope'),
            commit(type: 'feat', title: 'Add a new feature 3'),
            commit(type: 'feat', scope: 'Same Scope', title: 'Add a new feature with scope 2'),
            commit(type: 'feat', title: 'Add another feature')
          ]

          allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
          allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
        end

        it "should group multiple commits without scope inside 'Other work' in markdown format" do
          expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                            "### Features\n"\
                            "- **Same Scope:**\n"\
                            "   - Add a new feature with scope #{HASH_MARKDOWN}\n"\
                            "   - Add a new feature with scope 2 #{HASH_MARKDOWN}\n"\
                            "- **Other work:**\n"\
                            "   - Add a new feature 3 #{HASH_MARKDOWN}\n"\
                            "   - Add another feature #{HASH_MARKDOWN}"

          result = execute_lane_test(group_by_scope: true)

          expect(result).to eq(expected_result)
        end

        it "should group in Scope 1 multiple commits in plain format" do
          expected_result = "1.0.2 (2019-05-25)\n\n"\
                            "Features:\n"\
                            "- Same Scope:\n"\
                            "   - Add a new feature with scope #{HASH_PLAIN}\n"\
                            "   - Add a new feature with scope 2 #{HASH_PLAIN}\n"\
                            "- Other work:\n"\
                            "   - Add a new feature 3 #{HASH_PLAIN}\n"\
                            "   - Add another feature #{HASH_PLAIN}"

          result = execute_lane_test(group_by_scope: true, format: 'plain')

          expect(result).to eq(expected_result)
        end

        it "should group in Scope 1 multiple commits in slack format" do
          expected_result = "*1.0.2 (2019-05-25)*\n\n"\
                            "*Features*\n"\
                            "- *Same Scope:*\n"\
                            "    - Add a new feature with scope #{HASH_SLACK}\n"\
                            "    - Add a new feature with scope 2 #{HASH_SLACK}\n"\
                            "- *Other work:*\n"\
                            "    - Add a new feature 3 #{HASH_SLACK}\n"\
                            "    - Add another feature #{HASH_SLACK}"

          result = execute_lane_test(group_by_scope: true, format: 'slack')

          expect(result).to eq(expected_result)
        end
      end

      # Edge case tests for grouping functionality
      context "edge cases for grouping" do
        describe "empty and whitespace scopes" do
          before do
            commits = [
              commit(type: 'feat', scope: '', title: 'Feature with empty scope'),
              commit(type: 'feat', scope: '   ', title: 'Feature with whitespace scope'),
              commit(type: 'feat', scope: 'ValidScope', title: 'Feature with valid scope'),
              commit(type: 'feat', title: 'Feature without scope')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should handle empty and whitespace scopes correctly in markdown format" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **ValidScope:** Feature with valid scope #{HASH_MARKDOWN}\n"\
                              "- **Other work:**\n"\
                              "   - Feature with empty scope #{HASH_MARKDOWN}\n"\
                              "   - Feature with whitespace scope #{HASH_MARKDOWN}\n"\
                              "   - Feature without scope #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end
        end

        describe "all merge commits in scope" do
          before do
            commits = [
              "Merge branch 'feature'||long_hash|short_hash|Jiri Otahal|time",
              "Merge pull request #123||long_hash|short_hash|Jiri Otahal|time",
              commit(type: 'feat', scope: 'ValidScope', title: 'Valid feature')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should not create empty scope groups when all commits are merge commits" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **ValidScope:** Valid feature #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end
        end

        describe "mixed merge and regular commits in same scope" do
          before do
            commits = [
              commit(type: 'feat', scope: 'MixedScope', title: 'First feature'),
              "Merge branch 'feature'||long_hash|short_hash|Jiri Otahal|time",
              commit(type: 'feat', scope: 'MixedScope', title: 'Second feature')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should filter out merge commits but keep regular commits in same scope" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **MixedScope:**\n"\
                              "   - First feature #{HASH_MARKDOWN}\n"\
                              "   - Second feature #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end
        end

        describe "scope with leading/trailing whitespace" do
          before do
            commits = [
              commit(type: 'feat', scope: '  TrimScope  ', title: 'Feature with padded scope'),
              commit(type: 'feat', scope: 'TrimScope', title: 'Feature with clean scope')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should group commits with trimmed scopes together" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **TrimScope:**\n"\
                              "   - Feature with padded scope #{HASH_MARKDOWN}\n"\
                              "   - Feature with clean scope #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end
        end

        describe "scope case normalization" do
          before do
            commits = [
              commit(type: 'feat', scope: 'cache', title: 'Feature with lowercase scope'),
              commit(type: 'feat', scope: 'OFFLINE', title: 'Feature with uppercase scope'),
              commit(type: 'feat', scope: 'Announcements', title: 'Feature with mixed case scope'),
              commit(type: 'feat', scope: '  Schedule  ', title: 'Feature with padded scope')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should group case-insensitive scopes together and sort alphabetically in markdown format" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **Announcements:** Feature with mixed case scope #{HASH_MARKDOWN}\n"\
                              "- **cache:** Feature with lowercase scope #{HASH_MARKDOWN}\n"\
                              "- **OFFLINE:** Feature with uppercase scope #{HASH_MARKDOWN}\n"\
                              "- **Schedule:** Feature with padded scope #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end

          it "should group case-insensitive scopes together and sort alphabetically in plain format" do
            expected_result = "1.0.2 (2019-05-25)\n\n"\
                              "Features:\n"\
                              "- Announcements: Feature with mixed case scope #{HASH_PLAIN}\n"\
                              "- cache: Feature with lowercase scope #{HASH_PLAIN}\n"\
                              "- OFFLINE: Feature with uppercase scope #{HASH_PLAIN}\n"\
                              "- Schedule: Feature with padded scope #{HASH_PLAIN}"

            result = execute_lane_test(group_by_scope: true, format: 'plain')
            expect(result).to eq(expected_result)
          end
        end

        describe "scope case normalization with duplicates" do
          before do
            commits = [
              commit(type: 'feat', scope: 'offline', title: 'First offline feature'),
              commit(type: 'feat', scope: 'OFFLINE', title: 'Second offline feature'),
              commit(type: 'feat', scope: 'Offline', title: 'Third offline feature'),
              commit(type: 'feat', scope: '  offline  ', title: 'Fourth offline feature')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should group all case variations of the same scope together" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **offline:**\n"\
                              "   - First offline feature #{HASH_MARKDOWN}\n"\
                              "   - Second offline feature #{HASH_MARKDOWN}\n"\
                              "   - Third offline feature #{HASH_MARKDOWN}\n"\
                              "   - Fourth offline feature #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end
        end

        describe "alphabetical scope sorting" do
          before do
            commits = [
              commit(type: 'feat', scope: 'Zebra', title: 'Feature Z'),
              commit(type: 'feat', scope: 'Apple', title: 'Feature A'),
              commit(type: 'feat', scope: 'Monkey', title: 'Feature M'),
              commit(type: 'feat', scope: 'Banana', title: 'Feature B')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should sort scopes alphabetically in markdown format" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **Apple:** Feature A #{HASH_MARKDOWN}\n"\
                              "- **Banana:** Feature B #{HASH_MARKDOWN}\n"\
                              "- **Monkey:** Feature M #{HASH_MARKDOWN}\n"\
                              "- **Zebra:** Feature Z #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end

          it "should sort scopes alphabetically in plain format" do
            expected_result = "1.0.2 (2019-05-25)\n\n"\
                              "Features:\n"\
                              "- Apple: Feature A #{HASH_PLAIN}\n"\
                              "- Banana: Feature B #{HASH_PLAIN}\n"\
                              "- Monkey: Feature M #{HASH_PLAIN}\n"\
                              "- Zebra: Feature Z #{HASH_PLAIN}"

            result = execute_lane_test(group_by_scope: true, format: 'plain')
            expect(result).to eq(expected_result)
          end
        end

        describe "alphabetical scope sorting with fallback scope" do
          before do
            commits = [
              commit(type: 'feat', scope: 'Zebra', title: 'Feature Z'),
              commit(type: 'feat', title: 'Feature without scope'),
              commit(type: 'feat', scope: 'Apple', title: 'Feature A')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should sort named scopes alphabetically and put fallback scope last" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **Apple:** Feature A #{HASH_MARKDOWN}\n"\
                              "- **Zebra:** Feature Z #{HASH_MARKDOWN}\n"\
                              "- **Other work:** Feature without scope #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end
        end

        describe "missing sections configuration" do
          before do
            commits = [
              commit(type: 'feat', scope: 'TestScope', title: 'Test feature')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should raise error when no_type section is missing" do
            # Test with sections that don't include no_type
            custom_sections = {
              feat: "Features",
              fix: "Bug fixes"
              # no_type is missing
            }

            expect do
              execute_lane_test(group_by_scope: true, sections: custom_sections)
            end.to raise_error(FastlaneCore::Interface::FastlaneError, /sections parameter must include a :no_type key/)
          end

        describe "semantic scope mapping" do
          before do
            commits = [
              commit(type: 'feat', scope: 'Refactor', title: 'Refactor authentication module'),
              commit(type: 'feat', scope: 'REFACTOR', title: 'Refactor database layer'),
              commit(type: 'feat', scope: 'Cleanup', title: 'Cleanup unused imports'),
              commit(type: 'feat', scope: 'CLEANUP', title: 'Cleanup test files'),
              commit(type: 'feat', scope: 'Any', title: 'Any other work'),
              commit(type: 'feat', scope: 'Cache', title: 'Cache optimization')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
            allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
          end

          it "should map Cleanup and Refactor to canonical 'refactor' scope" do
            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **any:** Any other work #{HASH_MARKDOWN}\n"\
                              "- **Cache:** Cache optimization #{HASH_MARKDOWN}\n"\
                              "- **refactor:**\n"\
                              "   - Refactor authentication module #{HASH_MARKDOWN}\n"\
                              "   - Refactor database layer #{HASH_MARKDOWN}\n"\
                              "   - Cleanup unused imports #{HASH_MARKDOWN}\n"\
                              "   - Cleanup test files #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end

          it "should handle mixed case variations of Cleanup and Refactor" do
            commits = [
              commit(type: 'feat', scope: 'refactor', title: 'Lowercase refactor'),
              commit(type: 'feat', scope: 'CLEANUP', title: 'Uppercase cleanup'),
              commit(type: 'feat', scope: 'Refactor', title: 'Mixed case refactor'),
              commit(type: 'feat', scope: 'cleanup', title: 'Lowercase cleanup')
            ]

            allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)

            expected_result = "# 1.0.2 (2019-05-25)\n\n"\
                              "### Features\n"\
                              "- **refactor:**\n"\
                              "   - Lowercase refactor #{HASH_MARKDOWN}\n"\
                              "   - Uppercase cleanup #{HASH_MARKDOWN}\n"\
                              "   - Mixed case refactor #{HASH_MARKDOWN}\n"\
                              "   - Lowercase cleanup #{HASH_MARKDOWN}"

            result = execute_lane_test(group_by_scope: true)
            expect(result).to eq(expected_result)
          end
        end


          it "should raise error when no_type section is empty" do
            # Test with empty no_type section
            custom_sections = {
              feat: "Features",
              fix: "Bug fixes",
              no_type: ""
            }

            expect do
              execute_lane_test(group_by_scope: true, sections: custom_sections)
            end.to raise_error(FastlaneCore::Interface::FastlaneError, /sections\[:no_type\] cannot be nil or empty/)
          end

          it "should raise error when sections is not a hash" do
            expect do
              execute_lane_test(group_by_scope: true, sections: "invalid")
            end.to raise_error(FastlaneCore::Interface::FastlaneError, /value must be a Hash/)
          end
        end
      end
    end
  end
end
