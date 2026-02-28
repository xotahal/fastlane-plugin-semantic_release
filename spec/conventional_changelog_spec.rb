require 'spec_helper'

describe Fastlane::Actions::ConventionalChangelogAction do
  describe "Conventional Changelog" do
    before do
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::CONVENTIONAL_CHANGELOG_ACTION_FORMAT_PATTERN] = Fastlane::Helper::SemanticReleaseHelper.format_patterns["default"]
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_NEXT_VERSION] = '1.0.2'
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_ANALYZED] = true
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_IGNORE_BREAKING_CHANGES] = nil
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

    describe 'without prior analyze_commits' do
      it "should raise error when release has not been analyzed" do
        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_ANALYZED] = false

        expect do
          execute_lane_test
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /Release hasn't been analyzed yet/)
      end
    end

    describe 'include_scopes in changelog' do
      commits = [
        "fix(ios): ios fix||long_hash|short_hash|Jiri Otahal|time",
        "fix(android): android fix||long_hash|short_hash|Jiri Otahal|time",
        "fix(web): web fix||long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should only include specified scopes" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- **ios:** ios fix ([short_hash](/long_hash))"

        changelog = execute_lane_test(include_scopes: ['ios'])
        expect(changelog).to eq(result)
      end
    end

    describe 'grouping commits by scope' do
      commits = [
        "fix(map): search without country/state filters||long_hash|short_hash|Jiri Otahal|time",
        "fix(map): revert search without country/state filters||long_hash|short_hash|Jiri Otahal|time",
        "fix(auth): fix login crash||long_hash|short_hash|Jiri Otahal|time",
        "feat: add dark mode||long_hash|short_hash|Jiri Otahal|time",
        "feat(ui): new button component||long_hash|short_hash|Jiri Otahal|time",
        "feat(ui): new modal component||long_hash|short_hash|Jiri Otahal|time"
      ]

      it "should group same-scope commits in markdown format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = [
          "# 1.0.2 (2019-05-25)",
          "",
          "### Features",
          "- add dark mode ([short_hash](/long_hash))",
          "- **ui:**",
          "  - new button component ([short_hash](/long_hash))",
          "  - new modal component ([short_hash](/long_hash))",
          "",
          "### Bug fixes",
          "- **map:**",
          "  - search without country/state filters ([short_hash](/long_hash))",
          "  - revert search without country/state filters ([short_hash](/long_hash))",
          "- **auth:** fix login crash ([short_hash](/long_hash))"
        ].join("\n")

        expect(execute_lane_test).to eq(result)
      end

      it "should group same-scope commits in slack format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = [
          "*1.0.2 (2019-05-25)*",
          "",
          "*Features*",
          "- add dark mode (</long_hash|short_hash>)",
          "- *ui:*",
          "  - new button component (</long_hash|short_hash>)",
          "  - new modal component (</long_hash|short_hash>)",
          "",
          "*Bug fixes*",
          "- *map:*",
          "  - search without country/state filters (</long_hash|short_hash>)",
          "  - revert search without country/state filters (</long_hash|short_hash>)",
          "- *auth:* fix login crash (</long_hash|short_hash>)"
        ].join("\n")

        expect(execute_lane_test_slack).to eq(result)
      end

      it "should group same-scope commits in plain format" do
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = [
          "1.0.2 (2019-05-25)",
          "",
          "Features:",
          "- add dark mode (/long_hash)",
          "- ui:",
          "  - new button component (/long_hash)",
          "  - new modal component (/long_hash)",
          "",
          "Bug fixes:",
          "- map:",
          "  - search without country/state filters (/long_hash)",
          "  - revert search without country/state filters (/long_hash)",
          "- auth: fix login crash (/long_hash)"
        ].join("\n")

        expect(execute_lane_test_plain).to eq(result)
      end
    end

    describe 'revert commits in changelog' do
      it "should display reverted fix under Bug fixes section" do
        commits = [
          'Revert "fix(auth): crash on login"||long_hash|short_hash|Jiri Otahal|time'
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- **auth:** revert crash on login ([short_hash](/long_hash))"

        expect(execute_lane_test).to eq(result)
      end
    end

    describe 'ignore_breaking_changes' do
      it "should not display breaking changes section when ignore_breaking_changes is true" do
        commits = [
          "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- sub ([short_hash](/long_hash))"

        expect(execute_lane_test(ignore_breaking_changes: true)).to eq(result)
      end

      it "should not display breaking changes section from ! marker when ignore_breaking_changes is true" do
        commits = [
          "feat!: a breaking feature||long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Features\n- a breaking feature ([short_hash](/long_hash))"

        expect(execute_lane_test(ignore_breaking_changes: true)).to eq(result)
      end

      it "should read ignore_breaking_changes from lane_context when not passed as param" do
        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RELEASE_IGNORE_BREAKING_CHANGES] = true

        commits = [
          "fix: sub|BREAKING CHANGE: Test|long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Bug fixes\n- sub ([short_hash](/long_hash))"

        expect(execute_lane_test).to eq(result)
      end
    end

    describe 'custom commit types in changelog' do
      it "should display build and ci types under their sections" do
        commits = [
          "build: update webpack config||long_hash|short_hash|Jiri Otahal|time",
          "ci: add github actions||long_hash|short_hash|Jiri Otahal|time",
          "fix: a bug fix||long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = execute_lane_test(display_title: false, display_links: false)
        expect(result).to include("### Build system")
        expect(result).to include("### CI/CD")
        expect(result).to include("### Bug fixes")
      end

      it "should auto-add section keys to order" do
        commits = [
          "custom: something new||long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = execute_lane_test(
          display_title: false,
          display_links: false,
          sections: {
            feat: "Features",
            fix: "Bug fixes",
            custom: "Custom section",
            no_type: "Other work"
          }
        )
        expect(result).to include("### Custom section")
      end

      it "should use capitalized type name as fallback heading" do
        commits = [
          "update: something||long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = execute_lane_test(
          display_title: false,
          display_links: false,
          order: ["update", "no_type"]
        )
        expect(result).to include("### Update")
      end
    end

    describe 'displaying exclamation mark breaking change' do
      it "should display breaking change from ! marker in markdown" do
        commits = [
          "feat!: a breaking feature||long_hash|short_hash|Jiri Otahal|time"
        ]
        allow(Fastlane::Actions::ConventionalChangelogAction).to receive(:get_commits_from_hash).and_return(commits)
        allow(Date).to receive(:today).and_return(Date.new(2019, 5, 25))

        result = "# 1.0.2 (2019-05-25)\n\n### Features\n- a breaking feature ([short_hash](/long_hash))\n\n### BREAKING CHANGES\n- a breaking feature ([short_hash](/long_hash))"

        expect(execute_lane_test).to eq(result)
      end
    end

    after do
    end
  end
end
