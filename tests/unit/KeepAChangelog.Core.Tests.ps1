BeforeAll {
    . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    $moduleRoot = Get-PSKeepAChangelogToolsTestModuleRoot

    $commonPath = Join-Path $moduleRoot 'src/KeepAChangelog.Common.ps1'
    $corePath = Join-Path $moduleRoot 'src/KeepAChangelog.Core.ps1'
    . $commonPath
    . $corePath

    $script:NewTestChangelogContent = {
        @(
            '# Changelog'
            ''
            'This file records all notable changes to this project.'
            ''
            '## [Unreleased]'
            ''
            'aaaaa'
            ''
            '## [1.1.2] - 2023-03-07'
            ''
            '### Added'
            ''
            'CCC'
            ''
            '## [1.1.1] - 2023-03-06'
            ''
            '### Added'
            ''
            'BBB'
            ''
            '## [1.1.0] - 2023-03-05'
            ''
            '### Added'
            ''
            'AAA'
            ''
            '---'
            ''
            '[Unreleased]: https://github.com/krymtkts/pslrm/commits/main'
        ) -join "`n"
    }
}

Describe 'Read-KeepAChangelogSections' {
    It 'returns version sections with heading and body' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $sections = Read-KeepAChangelogSections -Path $changelogPath

        $sections.Count | Should -Be 4
        $sections[1].Version | Should -BeExactly '1.1.2'
        $sections[1].Heading | Should -BeExactly '## [1.1.2] - 2023-03-07'
        $sections[1].Body | Should -BeExactly (@(
                '### Added'
                ''
                'CCC'
            ) -join "`n")
    }

    It 'keeps horizontal rules inside section bodies when a terminal footer exists' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '### Changed'
            ''
            '- Before the rule'
            ''
            '---'
            ''
            '- After the rule'
            ''
            '## [1.0.0] - 2026-08-11'
            ''
            '### Added'
            ''
            '- Initial release'
            ''
            '---'
            ''
            '[Unreleased]: https://example.test/compare/v1.0.0...HEAD'
            '[1.0.0]: https://example.test/releases/v1.0.0'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        $sections = Read-KeepAChangelogSections -Path $changelogPath

        $sections[0].Body | Should -BeExactly (@(
                '### Changed'
                ''
                '- Before the rule'
                ''
                '---'
                ''
                '- After the rule'
            ) -join "`n")
        $sections[1].Body | Should -BeExactly (@(
                '### Added'
                ''
                '- Initial release'
            ) -join "`n")
    }

    It 'separates a terminal footer with CRLF line endings' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        $content = @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '### Added'
            ''
            '- Add thing'
            ''
            '---'
            ''
            '[Unreleased]: https://example.test/commits/main'
        ) -join "`r`n"
        [System.IO.File]::WriteAllText($changelogPath, $content)

        $section = Read-KeepAChangelogSections -Path $changelogPath

        $section.Body | Should -BeExactly (@(
                '### Added'
                ''
                '- Add thing'
            ) -join "`r`n")
    }

    It 'does not treat an indented link definition as a terminal footer' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '### Added'
            ''
            '- Add thing'
            ''
            '---'
            ''
            ' [Unreleased]: https://example.test/commits/main'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        $section = Read-KeepAChangelogSections -Path $changelogPath

        $section.Body | Should -BeExactly (@(
                '### Added'
                ''
                '- Add thing'
                ''
                '---'
                ''
                ' [Unreleased]: https://example.test/commits/main'
            ) -join "`n")
    }

    It 'rejects terminal general reference link definitions without a separator' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            'See [documentation] for details.'
            ''
            '[documentation]: https://example.test/docs'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        { Read-KeepAChangelogSections -Path $changelogPath } |
            Should -Throw 'Changelog footer link definitions require a preceding --- separator.'
    }

    It 'reads a changelog without footer links' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '### Added'
            ''
            '- Add thing'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        $section = Read-KeepAChangelogSections -Path $changelogPath

        $section.Body | Should -BeExactly (@(
                '### Added'
                ''
                '- Add thing'
            ) -join "`n")
    }

    It 'ignores headings inside backtick fenced code blocks' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '### Changed'
            ''
            '```markdown'
            '## [example] - 2026-08-12'
            '```'
            ''
            '- Keep parsing after the example.'
            ''
            '## [1.0.0] - 2026-08-12'
            ''
            '### Added'
            ''
            '- Initial release.'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        $sections = Read-KeepAChangelogSections -Path $changelogPath

        $sections.Count | Should -Be 2
        $sections[0].Body | Should -BeExactly (@(
                '### Changed'
                ''
                '```markdown'
                '## [example] - 2026-08-12'
                '```'
                ''
                '- Keep parsing after the example.'
            ) -join "`n")
        $sections[1].Version | Should -BeExactly '1.0.0'
    }

    It 'requires a matching tilde fence of at least the opening length' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        $content = @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '   ~~~~ markdown'
            '## [first-example]'
            '   ~~~'
            '   ```'
            '## [second-example]'
            '   ~~~~'
            ''
            '## [1.0.0] - 2026-08-12'
            ''
            '- Initial release.'
        ) -join "`r`n"
        [System.IO.File]::WriteAllText($changelogPath, $content)

        $sections = Read-KeepAChangelogSections -Path $changelogPath

        $sections.Count | Should -Be 2
        $sections[0].Body | Should -BeExactly (@(
                '   ~~~~ markdown'
                '## [first-example]'
                '   ~~~'
                '   ```'
                '## [second-example]'
                '   ~~~~'
            ) -join "`r`n")
        $sections[1].Version | Should -BeExactly '1.0.0'
    }

    It 'rejects an unclosed fenced code block' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '```powershell'
            '## [example]'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        { Read-KeepAChangelogSections -Path $changelogPath } |
            Should -Throw 'Unclosed changelog code fence starting at line 5.'
    }
}

Describe 'Find-KeepAChangelogSection' {
    It 'returns the target section without footer markers' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
            ''
            '### Added'
            ''
            '- Add thing'
            ''
            '### Notes'
            ''
            '- Note thing'
            ''
            '---'
            ''
            '[Unreleased]: https://example.test/commits/main'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        $section = Find-KeepAChangelogSection -Path $changelogPath -Version 'Unreleased'

        $section.Heading | Should -BeExactly '## [Unreleased]'
        $section.Body | Should -BeExactly (@(
                '### Added'
                ''
                '- Add thing'
                ''
                '### Notes'
                ''
                '- Note thing'
            ) -join "`n")
    }

    It 'fails when the requested version is missing' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        @(
            '# Changelog'
            ''
            '## [Unreleased]'
        ) -join "`n" | Set-Content -LiteralPath $changelogPath -NoNewline

        { Find-KeepAChangelogSection -Path $changelogPath -Version '0.0.1-alpha' } |
            Should -Throw 'Changelog entry not found for version: 0.0.1-alpha'
    }
}

Describe 'ConvertFrom-ReleaseTagToVersion' {
    It 'returns the version part from a version tag' {
        $version = ConvertFrom-ReleaseTagToVersion -ReleaseTag 'v1.1.2'

        $version | Should -BeExactly '1.1.2'
    }

    It 'accepts a refs/tags prefix' {
        $version = ConvertFrom-ReleaseTagToVersion -ReleaseTag 'refs/tags/v1.1.2'

        $version | Should -BeExactly '1.1.2'
    }

    It 'fails when the tag does not start with v' {
        { ConvertFrom-ReleaseTagToVersion -ReleaseTag '1.1.2' } |
            Should -Throw 'Release tag must use the form v<version>: 1.1.2'
    }
}
