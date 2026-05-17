BeforeAll {
    $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\PSKeepAChangelogTools.psd1'
    Import-Module -Name $script:ModuleManifestPath -Force

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

Describe 'PSKeepAChangelogTools public API' {
    It 'reads changelog sections from the current location by default' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        Push-Location $TestDrive
        try {
            $sections = Get-KeepAChangelogSections

            $sections.Count | Should -Be 4
            $sections[1].Version | Should -BeExactly '1.1.2'
        }
        finally {
            Pop-Location
        }
    }

    It 'reads changelog sections through the public command' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $sections = Get-KeepAChangelogSections -Path $changelogPath

        $sections.Count | Should -Be 4
        $sections[1].Version | Should -BeExactly '1.1.2'
    }

    It 'reads a changelog section through the public command' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $section = Get-KeepAChangelogSection -Path $changelogPath -Version '1.1.1'

        $section.Heading | Should -BeExactly '## [1.1.1] - 2023-03-06'
        $section.Body | Should -BeExactly (@(
                '### Added'
                ''
                'BBB'
            ) -join "`n")
    }

    It 'reads a changelog entry through the public command' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $entry = Get-KeepAChangelogEntry -Path $changelogPath -Version '1.1.0'

        $entry | Should -BeExactly (@(
                '### Added'
                ''
                'AAA'
            ) -join "`n")
    }

    It 'returns true when release metadata is valid' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        Test-KeepAChangelogReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag 'v1.1.2' |
            Should -BeTrue
    }

    It 'throws when release metadata is invalid' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Test-KeepAChangelogReleaseMetadata -Path $changelogPath -Version '1.1.2' -ReleaseTag 'v1.1.1'
        } | Should -Throw 'Release tag version does not match manifest version. Tag: 1.1.1, Manifest: 1.1.2'
    }
}

AfterAll {
    Remove-Module -Name 'PSKeepAChangelogTools' -Force -ErrorAction SilentlyContinue
}
