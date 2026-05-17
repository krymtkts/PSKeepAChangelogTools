BeforeAll {
    . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    $moduleRoot = Get-PSKeepAChangelogToolsTestModuleRoot

    $commonPath = Join-Path $moduleRoot 'src/KeepAChangelog.Common.ps1'
    $corePath = Join-Path $moduleRoot 'src/KeepAChangelog.Core.ps1'
    $manifestHelperPath = Join-Path $moduleRoot 'src/KeepAChangelog.ManifestReleaseNotes.ps1'
    . $commonPath
    . $corePath
    . $manifestHelperPath

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

Describe 'Get-KeepAChangelogManifestReleaseNotes' {
    It 'formats the target version and the next two older versions plus a full changelog link' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $content = Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -Version '1.1.2' -RecentCount 3 -FullChangelogUrl 'https://example.test/CHANGELOG.md'

        $content | Should -BeExactly (@(
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
                'Full CHANGELOG: https://example.test/CHANGELOG.md'
            ) -join "`n")
    }

    It 'uses only the available sections when there are fewer than the requested count' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $content = Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -Version '1.1.1' -RecentCount 3 -FullChangelogUrl 'https://example.test/CHANGELOG.md'

        $content | Should -BeExactly (@(
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
                'Full CHANGELOG: https://example.test/CHANGELOG.md'
            ) -join "`n")
    }

    It 'limits the output when RecentCount is smaller than the available section count' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        $content = Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -Version '1.1.2' -RecentCount 2 -FullChangelogUrl 'https://example.test/CHANGELOG.md'

        $content | Should -BeExactly (@(
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
                'Full CHANGELOG: https://example.test/CHANGELOG.md'
            ) -join "`n")
    }

    It 'requires an explicit version' {
        $changelogPath = Join-Path $TestDrive 'CHANGELOG.md'
        (& $script:NewTestChangelogContent) | Set-Content -LiteralPath $changelogPath -NoNewline

        {
            Get-KeepAChangelogManifestReleaseNotes -Path $changelogPath -ReleaseTag 'v1.1.2' -RecentCount 2 -FullChangelogUrl 'https://example.test/CHANGELOG.md'
        } | Should -Throw
    }
}

Describe 'Set-KeepAChangelogManifestReleaseNotes' {
    It 'writes a release notes here-string that Import-PowerShellDataFile can read' {
        $manifestPath = Join-Path $TestDrive 'test.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            "            # ReleaseNotes = ''"
            ''
            '            # Prerelease string of this module'
            "            Prerelease = 'alpha'"
            '        }'
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        $releaseNotes = @(
            '### Added'
            ''
            '- Add thing'
        ) -join "`n"

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $manifestText = Get-Content -LiteralPath $manifestPath -Raw

        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $releaseNotes
        $manifestText | Should -Not -Match "`r"
    }

    It 'replaces existing ReleaseNotes content instead of appending to it' {
        $manifestPath = Join-Path $TestDrive 'existing.psd1'
        @(
            '@{'
            '    PrivateData = @{'
            '        PSData = @{'
            '            # ReleaseNotes of this module'
            "            ReleaseNotes = @'"
            'old line'
            "'@"
            ''
            '            # Prerelease string of this module'
            "            Prerelease = 'alpha'"
            '        }'
            '    }'
            '}'
        ) -join "`n" | Set-Content -LiteralPath $manifestPath -NoNewline

        $releaseNotes = @(
            '### Added'
            ''
            '- New line'
        ) -join "`n"

        Set-KeepAChangelogManifestReleaseNotes -ManifestPath $manifestPath -ReleaseNotes $releaseNotes
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $manifestText = Get-Content -LiteralPath $manifestPath -Raw

        $manifest.PrivateData.PSData.ReleaseNotes | Should -BeExactly $releaseNotes
        $manifestText | Should -Not -Match 'old line'
    }
}
