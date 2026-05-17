BeforeAll {
    $corePath = Join-Path $PSScriptRoot '../../src/KeepAChangelog.Core.ps1'
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

