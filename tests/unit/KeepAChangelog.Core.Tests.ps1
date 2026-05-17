BeforeAll {
    $corePath = Join-Path $PSScriptRoot '..\..\src\KeepAChangelog.Core.ps1'
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

Describe 'Get-ChangelogSections' {
    It 'returns version sections with heading and body' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $sections = Get-ChangelogSections -Path $changelogPath

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

Describe 'Get-ChangelogEntry' {
    It 'returns the target section body without footer markers' {
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

        $entry = Get-ChangelogEntry -Path $changelogPath -Version 'Unreleased'

        $entry | Should -BeExactly (@(
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

        { Get-ChangelogEntry -Path $changelogPath -Version '0.0.1-alpha' } |
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

Describe 'Assert-ReleaseMetadata' {
    It 'passes when the changelog section exists and the release tag matches the version' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        { Assert-ReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag 'v1.1.2' } |
            Should -Not -Throw
    }

    It 'passes when the changelog section exists and no release tag is supplied' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        { Assert-ReleaseMetadata -Path $changelogPath -Version '1.1.2' } |
            Should -Not -Throw
    }

    It 'fails when the changelog section is missing' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        { Assert-ReleaseMetadata -Path $changelogPath -Version '2.0.0' -ReleaseTag 'v2.0.0' } |
            Should -Throw 'Changelog entry not found for version: 2.0.0'
    }

    It 'fails when the release tag version does not match the manifest version' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        { Assert-ReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag 'v1.1.1' } |
            Should -Throw 'Release tag version does not match manifest version. Tag: 1.1.1, Manifest: 1.1.2'
    }
}
