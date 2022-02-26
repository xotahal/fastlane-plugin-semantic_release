require 'spec_helper'

describe Fastlane::Actions::ConventionalChangelogAction do
  def commit(type, scope, sub, body='', author="Jiri Otahal")
    "#{type}(#{scope}): #{sub}|#{body}|long_hash|short_hash|#{author}|time"
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
      before do
        commits = [
          commit('feat', 'Scope 1', 'Add a new feature'),
          commit('feat', 'Scope 1', 'Add another feature'),
          commit('feat', 'Scope 2', 'Add one more feature')
        ]

        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))
      end

      it "should hide in markdown format" do
        expected_result = """# 1.0.2 (2019-05-25)

### Features
**Scope 1:**
   - Add a new feature ([short_hash](/long_hash))
   - Add another feature ([short_hash](/long_hash))
**Scope 2:** Add one more feature ([short_hash](/long_hash))"""

        result = execute_lane_test(group_by_scope: true)

        expect(result).to eq(expected_result)
      end

      it "should hide in plain format" do
        expected_result = """# 1.0.2 (2019-05-25)

Features
**Scope 1:**
   - Add a new feature ([short_hash](/long_hash))
   - Add another feature ([short_hash](/long_hash))
**Scope 2:** Add one more feature ([short_hash](/long_hash))"""

        result = execute_lane_test(group_by_scope: true, format: 'plain')

        expect(result).to eq(expected_result)
      end

      it "should hide in slack format" do
        expected_result = """# 1.0.2 (2019-05-25)

* Features *
**Scope 1:**
   - Add a new feature ([short_hash](/long_hash))
   - Add another feature ([short_hash](/long_hash))
**Scope 2:** Add one more feature ([short_hash](/long_hash))"""

        result = execute_lane_test(group_by_scope: true, format: 'slack')

        expect(result).to eq(expected_result)
      end
    end
  end
end
